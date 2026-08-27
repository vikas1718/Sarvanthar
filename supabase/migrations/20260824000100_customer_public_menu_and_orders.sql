-- 20260824000100_customer_public_menu_and_orders.sql
--
-- Customer-facing (anon) ordering surface. Two concerns:
--   1. Public read access to menu data, which until now was authenticated-only.
--   2. Order storage + a single anon-callable RPC to place an order.
--
-- Conventions followed from the existing schema:
--   * private.* helpers are STABLE SECURITY DEFINER with search_path=''. RLS
--     policies call them instead of reading businesses/stalls inline, because
--     anon holds no grant on those tables and an inline read would fail.
--   * All writes go through SECURITY DEFINER RPCs. No write policies exist
--     anywhere in this schema and none are added here.
--   * Every function gets an explicit REVOKE then GRANT. This is required, not
--     cosmetic: Supabase's default ACL on this project grants anon EXECUTE on
--     every new function in public, and full DML on every new table in public.
--     Anything not explicitly revoked is exposed to anon by default.

-- ---------------------------------------------------------------------------
-- 1. Public menu visibility helpers
-- ---------------------------------------------------------------------------
-- Mirror of private.has_business_access / has_stall_access, but expressing
-- "is this publicly visible to a customer" rather than "is this caller a
-- member". Kept as SECURITY DEFINER so the anon policies below never need a
-- grant on businesses or stalls.

create or replace function private.menu_business_is_public(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1 from public.businesses b
    where b.id = p_business_id
      and b.archived_at is null
  );
$function$;

create or replace function private.menu_stall_is_public(p_stall_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.stalls s
    join public.businesses b on b.id = s.business_id
    where s.id = p_stall_id
      and s.archived_at is null
      and s.status = 'active'
      and b.archived_at is null
  );
$function$;

-- These helpers are invoked from the anon SELECT policies below. RLS policy
-- expressions run AS THE CALLING ROLE, so anon must hold EXECUTE here --
-- SECURITY DEFINER governs what the body may read, not who may call it. This
-- matches private.has_business_access / has_stall_access, which the staff
-- policies call the same way. PUBLIC and authenticated do not need it (no
-- policy TO those roles references these), so they are revoked.
revoke all on function private.menu_business_is_public(uuid) from public, authenticated;
revoke all on function private.menu_stall_is_public(uuid) from public, authenticated;
grant execute on function private.menu_business_is_public(uuid) to anon;
grant execute on function private.menu_stall_is_public(uuid) to anon;

-- ---------------------------------------------------------------------------
-- 2. Public read policies on menu tables
-- ---------------------------------------------------------------------------
-- Added as new policies TO anon. The existing *_read policies are TO
-- authenticated and are left untouched; permissive policies OR together, so
-- staff behaviour in the Flutter app is unchanged.
--
-- Archived rows are excluded at every level. Nothing staff-only is reachable:
-- these four tables contain only customer-facing menu data, and anon still has
-- no grant on businesses, stalls, qr_tokens, profiles, memberships or
-- invitations.
--
-- NOTE: is_available is deliberately NOT filtered here. The column is exposed
-- so the customer UI can render sold-out items as disabled rather than having
-- them silently vanish; place_order re-checks availability server-side and
-- rejects unavailable items. If you'd rather sold-out items be invisible
-- entirely, add "and is_available" to the menu_items policy and
-- "and is_available" to menu_options.

create policy menu_categories_public_read
  on public.menu_categories
  for select
  to anon
  using (
    archived_at is null
    and private.menu_business_is_public(business_id)
    and (stall_id is null or private.menu_stall_is_public(stall_id))
  );

create policy menu_items_public_read
  on public.menu_items
  for select
  to anon
  using (
    archived_at is null
    and private.menu_business_is_public(business_id)
    and (stall_id is null or private.menu_stall_is_public(stall_id))
  );

create policy menu_groups_public_read
  on public.menu_option_groups
  for select
  to anon
  using (
    archived_at is null
    and exists (
      select 1
      from public.menu_items i
      where i.id = menu_option_groups.menu_item_id
        and i.archived_at is null
        and private.menu_business_is_public(i.business_id)
        and (i.stall_id is null or private.menu_stall_is_public(i.stall_id))
    )
  );

create policy menu_options_public_read
  on public.menu_options
  for select
  to anon
  using (
    exists (
      select 1
      from public.menu_option_groups g
      join public.menu_items i on i.id = g.menu_item_id
      where g.id = menu_options.option_group_id
        and g.archived_at is null
        and i.archived_at is null
        and private.menu_business_is_public(i.business_id)
        and (i.stall_id is null or private.menu_stall_is_public(i.stall_id))
    )
  );

-- anon already holds SELECT on these four via the project's default ACL.
-- Restated explicitly so the customer app's read path does not depend on a
-- default that may change.
grant select on public.menu_categories   to anon;
grant select on public.menu_items        to anon;
grant select on public.menu_option_groups to anon;
grant select on public.menu_options      to anon;

-- ---------------------------------------------------------------------------
-- 3. Orders
-- ---------------------------------------------------------------------------

create type public.order_status as enum ('received', 'preparing', 'ready', 'completed', 'cancelled');

create table public.orders (
  id              uuid primary key default extensions.gen_random_uuid(),

  -- Resolved from the QR token server-side, never from the client.
  business_id     uuid not null references public.businesses(id),
  stall_id        uuid references public.stalls(id),
  dining_table_id uuid references public.dining_tables(id),
  qr_token_id     uuid not null references public.qr_tokens(id),
  scope           public.qr_token_scope not null,

  status          public.order_status not null default 'received',

  -- Snapshots. Same reasoning as the line-item prices below: a dining table's
  -- number is only unique among non-archived rows
  -- (dining_tables_active_number_key), so a number can be reused after the
  -- table is archived. A live join would then mislabel this order.
  table_number    text,
  stall_name      text,
  currency        text,
  tax_percentage  numeric(5,2),

  subtotal_amount numeric(12,2) not null,
  tax_amount      numeric(12,2) not null default 0,
  total_amount    numeric(12,2) not null,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint orders_amounts_check check (
    subtotal_amount >= 0 and tax_amount >= 0 and total_amount >= 0
  ),
  -- Mirrors qr_tokens_scope_target_check so an order can never claim a
  -- scope/target combination the QR system cannot produce.
  constraint orders_scope_target_check check (
    (scope = 'table'    and dining_table_id is not null and stall_id is null)
    or (scope = 'stall' and stall_id is not null and dining_table_id is null)
    or (scope = 'business' and stall_id is null and dining_table_id is null)
  )
);

create table public.order_items (
  id            uuid primary key default extensions.gen_random_uuid(),
  order_id      uuid not null references public.orders(id) on delete cascade,

  -- Reference kept for reporting. Menu items are soft-archived, never deleted.
  menu_item_id  uuid not null references public.menu_items(id),

  -- Price and name snapshot at order time. Deliberately duplicated rather than
  -- joined: editing a menu item's price or name must not retroactively change
  -- what an existing order says the customer agreed to.
  item_name     text not null,
  unit_price    numeric(12,2) not null,
  options_total numeric(12,2) not null default 0,
  quantity      integer not null,
  line_total    numeric(12,2) not null,

  created_at    timestamptz not null default now(),

  constraint order_items_quantity_check check (quantity >= 1 and quantity <= 99),
  constraint order_items_amounts_check check (
    unit_price >= 0 and options_total >= 0 and line_total >= 0
  )
);

create table public.order_item_options (
  id              uuid primary key default extensions.gen_random_uuid(),
  order_item_id   uuid not null references public.order_items(id) on delete cascade,

  menu_option_id  uuid not null references public.menu_options(id),
  option_group_id uuid not null references public.menu_option_groups(id),

  -- Snapshot, for the same reason as order_items.
  group_name      text not null,
  option_name     text not null,
  price_delta     numeric(12,2) not null,

  created_at      timestamptz not null default now()
);

create index orders_business_idx
  on public.orders (business_id, status, created_at desc);
create index orders_stall_idx
  on public.orders (stall_id, status, created_at desc)
  where stall_id is not null;
create index orders_table_idx
  on public.orders (dining_table_id, created_at desc)
  where dining_table_id is not null;
create index order_items_order_idx
  on public.order_items (order_id);
create index order_item_options_item_idx
  on public.order_item_options (order_item_id);

create trigger orders_updated
  before update on public.orders
  for each row execute function private.set_updated_at();

-- RLS on with no policies at all: nobody reads or writes these tables
-- directly. place_order is SECURITY DEFINER so it is unaffected, and
-- service_role bypasses RLS. Staff read access belongs to the Kitchen phase,
-- which should add a policy TO authenticated using private.has_business_access
-- / private.has_stall_access, matching the other tables.
alter table public.orders             enable row level security;
alter table public.order_items        enable row level security;
alter table public.order_item_options enable row level security;

-- Required: the default ACL on this project would otherwise hand anon and
-- authenticated full INSERT/UPDATE/DELETE on these three new tables.
revoke all on public.orders             from anon, authenticated;
revoke all on public.order_items        from anon, authenticated;
revoke all on public.order_item_options from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. place_order  --  SECOND anon-callable RPC in this project
-- ---------------------------------------------------------------------------
-- resolve_qr_token was the first. Safeguards, in the same spirit:
--
--   * The token is re-validated server-side by calling resolve_qr_token
--     itself, so the "not valid" / "has been replaced" / "no longer active"
--     rules cannot drift apart between the two RPCs. The client's claimed
--     business / stall / table is never read from the payload; every one of
--     those columns is stamped from the resolved token.
--   * The payload carries no prices. Not "prices are re-validated" -- there is
--     no price field to submit. unit_price and price_delta are read from
--     menu_items / menu_options at insert time, so a tampered client cannot
--     express a price at all.
--   * Every referenced item is re-checked for archived_at, is_available, and
--     scope match against the resolved token, so a token for business A cannot
--     order items belonging to business B or another stall.
--   * Options must belong to a non-archived option group of that same item and
--     be available; per-group min_select / max_select are enforced, so
--     required variants cannot be skipped.
--   * Line-item and quantity caps bound the cost of a single unauthenticated
--     call.
--   * Inserts are the only effect. It cannot read or modify anything a
--     customer should not see.
--
-- Deviation from convention: p_items is jsonb. Every other RPC here takes
-- typed scalars, but a cart is variable-length and nested. The payload is
-- treated as untrusted input and every field is validated above.

create or replace function public.place_order(p_token text, p_items jsonb)
returns table (
  order_id        uuid,
  status          public.order_status,
  currency        text,
  subtotal_amount numeric,
  tax_amount      numeric,
  total_amount    numeric,
  business_name   text,
  stall_name      text,
  table_number    text,
  items           jsonb
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_ctx         record;
  v_token_id    uuid;
  v_order       public.orders;
  v_line        jsonb;
  v_item        public.menu_items;
  v_order_item  public.order_items;
  v_group       record;
  v_qty         integer;
  v_opt_ids     uuid[];
  v_opt_delta   numeric(12,2);
  v_line_total  numeric(12,2);
  v_subtotal    numeric(12,2) := 0;
  v_tax         numeric(12,2) := 0;
  v_sel_count   integer;
  v_total_qty   integer := 0;
  c_max_lines     constant integer := 50;
  c_max_qty_line  constant integer := 99;
  c_max_total_qty constant integer := 200;
begin
  -- Re-validate the token. Raises the same three messages as resolve_qr_token.
  select * into v_ctx from public.resolve_qr_token(p_token);

  -- Provenance. Safe to read directly: resolve_qr_token has already proven the
  -- token exists and is active, and token carries a unique index.
  select id into v_token_id
  from public.qr_tokens
  where token = p_token;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Order must contain at least one item';
  end if;

  if jsonb_array_length(p_items) > c_max_lines then
    raise exception 'Order has too many items';
  end if;

  insert into public.orders (
    business_id, stall_id, dining_table_id, qr_token_id, scope,
    status, table_number, stall_name, currency, tax_percentage,
    subtotal_amount, tax_amount, total_amount
  )
  values (
    v_ctx.business_id, v_ctx.stall_id, v_ctx.dining_table_id, v_token_id, v_ctx.scope,
    'received', v_ctx.table_number, v_ctx.stall_name, v_ctx.currency, v_ctx.tax_percentage,
    0, 0, 0
  )
  returning * into v_order;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_qty := coalesce((v_line ->> 'quantity')::integer, 1);
    if v_qty < 1 or v_qty > c_max_qty_line then
      raise exception 'Invalid quantity in order';
    end if;

    v_total_qty := v_total_qty + v_qty;
    if v_total_qty > c_max_total_qty then
      raise exception 'Order quantity exceeds the allowed maximum';
    end if;

    -- Availability, archival and scope are all re-checked here. stall_id is
    -- compared against the resolved token: a restaurant token (stall_id null)
    -- only reaches stall_id-null items, and a stall token only reaches that
    -- stall's items. A food-court business/table token resolves stall_id null
    -- and therefore matches nothing, which is correct -- ordering in a food
    -- court requires a stall-scoped QR.
    select mi.* into v_item
    from public.menu_items mi
    where mi.id = (v_line ->> 'menu_item_id')::uuid
      and mi.archived_at is null
      and mi.is_available
      and mi.business_id = v_ctx.business_id
      and mi.stall_id is not distinct from v_ctx.stall_id;

    if not found then
      raise exception 'A selected item is no longer available';
    end if;

    v_opt_ids := coalesce(
      (
        select array_agg(e::uuid)
        from jsonb_array_elements_text(coalesce(v_line -> 'option_ids', '[]'::jsonb)) as e
      ),
      '{}'::uuid[]
    );

    -- Reject anything that is not an available option of a live group on this
    -- exact item. Counting matched rows also rejects ids that do not exist.
    if cardinality(v_opt_ids) > 0 then
      select coalesce(sum(mo.price_delta), 0), count(*)
        into v_opt_delta, v_sel_count
      from public.menu_options mo
      join public.menu_option_groups g on g.id = mo.option_group_id
      where mo.id = any(v_opt_ids)
        and mo.is_available
        and g.archived_at is null
        and g.menu_item_id = v_item.id;

      if v_sel_count <> cardinality(v_opt_ids) then
        raise exception 'A selected option is not available for "%"', v_item.name;
      end if;
    else
      v_opt_delta := 0;
    end if;

    -- min_select / max_select per group, so required variants cannot be
    -- skipped and multi-select groups cannot be overfilled.
    for v_group in
      select g.id, g.name, g.min_select, g.max_select
      from public.menu_option_groups g
      where g.menu_item_id = v_item.id
        and g.archived_at is null
    loop
      select count(*) into v_sel_count
      from public.menu_options mo
      where mo.id = any(v_opt_ids)
        and mo.option_group_id = v_group.id;

      if v_sel_count < v_group.min_select then
        raise exception 'Choose an option for "%" on "%"', v_group.name, v_item.name;
      end if;
      if v_sel_count > v_group.max_select then
        raise exception 'Too many options chosen for "%" on "%"', v_group.name, v_item.name;
      end if;
    end loop;

    v_line_total := round((v_item.price + v_opt_delta) * v_qty, 2);
    v_subtotal   := v_subtotal + v_line_total;

    insert into public.order_items (
      order_id, menu_item_id, item_name, unit_price, options_total, quantity, line_total
    )
    values (
      v_order.id, v_item.id, v_item.name, v_item.price, v_opt_delta, v_qty, v_line_total
    )
    returning * into v_order_item;

    if cardinality(v_opt_ids) > 0 then
      insert into public.order_item_options (
        order_item_id, menu_option_id, option_group_id, group_name, option_name, price_delta
      )
      select v_order_item.id, mo.id, g.id, g.name, mo.name, mo.price_delta
      from public.menu_options mo
      join public.menu_option_groups g on g.id = mo.option_group_id
      where mo.id = any(v_opt_ids)
        and g.menu_item_id = v_item.id;
    end if;
  end loop;

  v_tax := case
             when v_ctx.tax_percentage is null then 0
             else round(v_subtotal * v_ctx.tax_percentage / 100.0, 2)
           end;

  update public.orders
  set subtotal_amount = v_subtotal,
      tax_amount      = v_tax,
      total_amount    = v_subtotal + v_tax
  where id = v_order.id
  returning * into v_order;

  -- The customer app has no read access to these tables, so this return value
  -- is the order confirmation.
  return query
  select
    v_order.id,
    v_order.status,
    v_order.currency,
    v_order.subtotal_amount,
    v_order.tax_amount,
    v_order.total_amount,
    v_ctx.business_name,
    v_order.stall_name,
    v_order.table_number,
    (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'item_name',  oi.item_name,
            'quantity',   oi.quantity,
            'unit_price', oi.unit_price,
            'line_total', oi.line_total,
            'options', (
              select coalesce(
                jsonb_agg(
                  jsonb_build_object(
                    'group_name',  oio.group_name,
                    'option_name', oio.option_name,
                    'price_delta', oio.price_delta
                  )
                  order by oio.group_name, oio.option_name
                ),
                '[]'::jsonb
              )
              from public.order_item_options oio
              where oio.order_item_id = oi.id
            )
          )
          order by oi.created_at
        ),
        '[]'::jsonb
      )
      from public.order_items oi
      where oi.order_id = v_order.id
    );
end;
$function$;

-- Explicit revoke before grant: the default ACL would already have granted
-- anon EXECUTE. Restated so the anon exposure is intentional and visible.
revoke all on function public.place_order(text, jsonb) from public, anon, authenticated;
grant execute on function public.place_order(text, jsonb) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Rollback (for review; Supabase migrations are forward-only)
-- ---------------------------------------------------------------------------
-- drop function if exists public.place_order(text, jsonb);
-- drop table if exists public.order_item_options;
-- drop table if exists public.order_items;
-- drop table if exists public.orders;
-- drop type if exists public.order_status;
-- drop policy if exists menu_options_public_read     on public.menu_options;
-- drop policy if exists menu_groups_public_read      on public.menu_option_groups;
-- drop policy if exists menu_items_public_read       on public.menu_items;
-- drop policy if exists menu_categories_public_read  on public.menu_categories;
-- drop function if exists private.menu_stall_is_public(uuid);
-- drop function if exists private.menu_business_is_public(uuid);
