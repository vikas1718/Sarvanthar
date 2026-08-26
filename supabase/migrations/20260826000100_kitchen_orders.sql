-- Kitchen order read access, status workflow, and Realtime publication.
-- Depends on the order tables and public.order_status created by the Customer
-- repository's already-applied 20260824000100 migration.
--
-- Scope rules:
--   * Restaurant orders have stall_id IS NULL. Active business-level Owner,
--     Manager, Kitchen, and Cashier memberships may read them.
--   * Food Court orders require a non-null stall_id. Owner is business-wide;
--     Manager, Kitchen, and Cashier require an active membership for the exact
--     order stall.
--   * The generic app_role value "staff" receives no order access.
--   * Direct updates remain unavailable; status changes only use the
--     permission-checked SECURITY DEFINER RPC below.

create function private.can_read_order(
  p_business_id uuid,
  p_stall_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.businesses b
    where b.id = p_business_id
      and b.archived_at is null
      and (
        (
          b.type = 'restaurant'
          and p_stall_id is null
          and exists (
            select 1
            from public.business_memberships bm
            where bm.business_id = b.id
              and bm.user_id = (select auth.uid())
              and bm.status = 'active'
              and bm.role in ('owner', 'manager', 'kitchen', 'cashier')
          )
        )
        or
        (
          b.type = 'food_court'
          and p_stall_id is not null
          and exists (
            select 1
            from public.stalls s
            where s.id = p_stall_id
              and s.business_id = b.id
              and s.archived_at is null
          )
          and (
            exists (
              select 1
              from public.business_memberships bm
              where bm.business_id = b.id
                and bm.user_id = (select auth.uid())
                and bm.status = 'active'
                and bm.role = 'owner'
            )
            or exists (
              select 1
              from public.stall_memberships sm
              where sm.business_id = b.id
                and sm.stall_id = p_stall_id
                and sm.user_id = (select auth.uid())
                and sm.status = 'active'
                and sm.role in ('manager', 'kitchen', 'cashier')
            )
          )
        )
      )
  );
$function$;

revoke all on function private.can_read_order(uuid, uuid)
  from public, anon;
grant execute on function private.can_read_order(uuid, uuid)
  to authenticated;

create policy orders_staff_read
on public.orders
for select
to authenticated
using (private.can_read_order(business_id, stall_id));

create policy order_items_staff_read
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and private.can_read_order(o.business_id, o.stall_id)
  )
);

create policy order_item_options_staff_read
on public.order_item_options
for select
to authenticated
using (
  exists (
    select 1
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.id = order_item_options.order_item_id
      and private.can_read_order(o.business_id, o.stall_id)
  )
);

grant select on public.orders, public.order_items, public.order_item_options
  to authenticated;

-- Explicit 15-row role-transition table:
--
--   received  -> preparing : owner, manager, kitchen
--   preparing -> ready     : owner, manager, kitchen
--   ready     -> completed : owner, manager, cashier
--   received  -> cancelled : owner, manager, cashier
--   preparing -> cancelled : owner, manager, cashier
--
-- No other tuple is valid. This makes completed/cancelled terminal, prevents
-- forward skips and backward movement, and prevents cancellation after ready.
-- Owner/Manager force authority means every valid edge, not bypassing the graph.
create function public.update_order_status(
  p_order_id uuid,
  p_new_status public.order_status
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_order public.orders;
  v_allowed boolean;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  -- Serialize competing updates so validation uses the committed status.
  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found';
  end if;

  if not private.can_read_order(v_order.business_id, v_order.stall_id) then
    raise exception 'Order status update is not permitted';
  end if;

  with allowed_transitions(from_status, to_status, allowed_role) as (
    values
      ('received'::public.order_status,  'preparing'::public.order_status, 'owner'::public.app_role),
      ('received'::public.order_status,  'preparing'::public.order_status, 'manager'::public.app_role),
      ('received'::public.order_status,  'preparing'::public.order_status, 'kitchen'::public.app_role),
      ('preparing'::public.order_status, 'ready'::public.order_status,     'owner'::public.app_role),
      ('preparing'::public.order_status, 'ready'::public.order_status,     'manager'::public.app_role),
      ('preparing'::public.order_status, 'ready'::public.order_status,     'kitchen'::public.app_role),
      ('ready'::public.order_status,     'completed'::public.order_status, 'owner'::public.app_role),
      ('ready'::public.order_status,     'completed'::public.order_status, 'manager'::public.app_role),
      ('ready'::public.order_status,     'completed'::public.order_status, 'cashier'::public.app_role),
      ('received'::public.order_status,  'cancelled'::public.order_status, 'owner'::public.app_role),
      ('received'::public.order_status,  'cancelled'::public.order_status, 'manager'::public.app_role),
      ('received'::public.order_status,  'cancelled'::public.order_status, 'cashier'::public.app_role),
      ('preparing'::public.order_status, 'cancelled'::public.order_status, 'owner'::public.app_role),
      ('preparing'::public.order_status, 'cancelled'::public.order_status, 'manager'::public.app_role),
      ('preparing'::public.order_status, 'cancelled'::public.order_status, 'cashier'::public.app_role)
  ), effective_roles(role) as (
    -- Restaurant roles and the Food Court owner are business memberships.
    select bm.role
    from public.business_memberships bm
    where bm.business_id = v_order.business_id
      and bm.user_id = (select auth.uid())
      and bm.status = 'active'
      and (
        (v_order.stall_id is null and bm.role in ('owner', 'manager', 'kitchen', 'cashier'))
        or (v_order.stall_id is not null and bm.role = 'owner')
      )

    union

    -- Every non-owner Food Court role must match the order's stall.
    select sm.role
    from public.stall_memberships sm
    where sm.business_id = v_order.business_id
      and sm.stall_id = v_order.stall_id
      and sm.user_id = (select auth.uid())
      and sm.status = 'active'
      and sm.role in ('manager', 'kitchen', 'cashier')
  )
  select exists (
    select 1
    from allowed_transitions t
    join effective_roles r on r.role = t.allowed_role
    where t.from_status = v_order.status
      and t.to_status = p_new_status
  )
  into v_allowed;

  if not v_allowed then
    raise exception 'Transition from % to % is not permitted for this role',
      v_order.status, p_new_status;
  end if;

  update public.orders
  set status = p_new_status
  where id = v_order.id
  returning * into v_order;

  return v_order;
end;
$function$;

revoke all on function public.update_order_status(uuid, public.order_status)
  from public, anon;
grant execute on function public.update_order_status(uuid, public.order_status)
  to authenticated;

-- The app uses the parent row as an invalidation signal and re-fetches the
-- complete order/items/options graph after INSERT or UPDATE.
do $block$
begin
  if not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
end;
$block$;
