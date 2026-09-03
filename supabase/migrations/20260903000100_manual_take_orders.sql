-- Manual staff orders reuse the existing orders/KOT tables. QR orders remain unchanged.
alter table public.orders
  alter column qr_token_id drop not null,
  add column if not exists source text not null default 'qr',
  add column if not exists client_request_id uuid,
  add column if not exists kot_number bigint;

alter table public.orders drop constraint if exists orders_source_check;
alter table public.orders add constraint orders_source_check
  check (source in ('qr', 'manual'));

alter table public.orders drop constraint if exists orders_scope_target_check;
alter table public.orders add constraint orders_scope_target_check check (
  (scope = 'table' and dining_table_id is not null)
  or (scope = 'stall' and stall_id is not null and dining_table_id is null)
  or (scope = 'business' and stall_id is null and dining_table_id is null)
);

create unique index if not exists orders_manual_request_unique
  on public.orders (business_id, client_request_id)
  where source = 'manual';

create table if not exists public.business_kot_sequences (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  last_kot_number bigint not null default 0
);

create or replace function private.assign_kot_number()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.kot_number is null then
    insert into public.business_kot_sequences (business_id, last_kot_number)
    values (new.business_id, 1)
    on conflict (business_id) do update
      set last_kot_number = public.business_kot_sequences.last_kot_number + 1
    returning last_kot_number into new.kot_number;
  end if;
  return new;
end;
$$;

drop trigger if exists assign_kot_number on public.orders;
create trigger assign_kot_number before insert on public.orders
for each row execute function private.assign_kot_number();

create or replace function public.create_manual_order(
  p_table_id uuid,
  p_stall_id uuid,
  p_client_request_id uuid,
  p_items jsonb
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_table public.dining_tables;
  v_order public.orders;
  v_order_item public.order_items;
  v_menu_item public.menu_items;
  v_line jsonb;
  v_quantity integer;
  v_subtotal numeric(12,2) := 0;
  v_line_total numeric(12,2);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Select at least one item';
  end if;

  select * into v_table from public.dining_tables
  where id = p_table_id and archived_at is null and status = 'active';
  if not found then raise exception 'Table is unavailable'; end if;

  if not private.can_read_order(v_table.business_id, p_stall_id) then
    raise exception 'Manual order permission denied';
  end if;

  select * into v_order from public.orders
  where business_id = v_table.business_id and source = 'manual'
    and client_request_id = p_client_request_id;
  if found then return v_order.id; end if;

  insert into public.orders (
    business_id, stall_id, dining_table_id, scope, source, client_request_id,
    status, table_number, currency, tax_percentage,
    subtotal_amount, tax_amount, total_amount
  ) values (
    v_table.business_id, p_stall_id, v_table.id, 'table', 'manual', p_client_request_id,
    'received', v_table.table_number, 'INR', 0, 0, 0, 0
  ) returning * into v_order;

  for v_line in select value from jsonb_array_elements(p_items) loop
    v_quantity := coalesce((v_line ->> 'quantity')::integer, 0);
    if v_quantity < 1 or v_quantity > 99 then raise exception 'Invalid item quantity'; end if;
    select * into v_menu_item from public.menu_items
    where id = (v_line ->> 'menu_item_id')::uuid
      and business_id = v_order.business_id
      and stall_id is not distinct from v_order.stall_id
      and archived_at is null and is_available;
    if not found then raise exception 'A selected menu item is unavailable'; end if;
    v_line_total := round(v_menu_item.price * v_quantity, 2);
    v_subtotal := v_subtotal + v_line_total;
    insert into public.order_items (order_id, menu_item_id, item_name, unit_price, options_total, quantity, line_total)
    values (v_order.id, v_menu_item.id, v_menu_item.name, v_menu_item.price, 0, v_quantity, v_line_total);
  end loop;

  update public.orders set subtotal_amount = v_subtotal, tax_amount = 0, total_amount = v_subtotal
  where id = v_order.id;
  return v_order.id;
end;
$$;

revoke all on function public.create_manual_order(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.create_manual_order(uuid, uuid, uuid, jsonb) to authenticated;

create or replace function public.save_kot_order(p_order_id uuid, p_items jsonb)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_order public.orders;
  v_order_item public.order_items;
  v_menu_item public.menu_items;
  v_line jsonb;
  v_quantity integer;
  v_subtotal numeric(12,2) := 0;
  v_line_total numeric(12,2);
  v_option_ids uuid[];
  v_options_total numeric(12,2);
  v_option_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if v_order.status in ('completed', 'cancelled') then
    raise exception 'Completed or cancelled KOTs cannot be edited';
  end if;
  if not private.can_read_order(v_order.business_id, v_order.stall_id) then
    raise exception 'KOT edit is not permitted';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'An order needs at least one item';
  end if;

  delete from public.order_items where order_id = v_order.id;
  for v_line in select value from jsonb_array_elements(p_items) loop
    v_quantity := coalesce((v_line ->> 'quantity')::integer, 0);
    if v_quantity < 1 or v_quantity > 99 then raise exception 'Invalid item quantity'; end if;
    select * into v_menu_item from public.menu_items
    where id = (v_line ->> 'menu_item_id')::uuid
      and business_id = v_order.business_id
      and stall_id is not distinct from v_order.stall_id
      and archived_at is null;
    if not found then raise exception 'A selected menu item is unavailable'; end if;
    v_option_ids := coalesce(
      (select array_agg(value::uuid) from jsonb_array_elements_text(coalesce(v_line -> 'option_ids', '[]'::jsonb))),
      '{}'::uuid[]
    );
    select coalesce(sum(mo.price_delta), 0), count(*) into v_options_total, v_option_count
    from public.menu_options mo
    join public.menu_option_groups g on g.id = mo.option_group_id
    where mo.id = any(v_option_ids) and mo.is_available and g.archived_at is null
      and g.menu_item_id = v_menu_item.id;
    if v_option_count <> cardinality(v_option_ids) then raise exception 'An item option is unavailable'; end if;
    v_line_total := round((v_menu_item.price + v_options_total) * v_quantity, 2);
    v_subtotal := v_subtotal + v_line_total;
    insert into public.order_items (order_id, menu_item_id, item_name, unit_price, options_total, quantity, line_total)
    values (v_order.id, v_menu_item.id, v_menu_item.name, v_menu_item.price, v_options_total, v_quantity, v_line_total)
    returning * into v_order_item;
    insert into public.order_item_options (order_item_id, menu_option_id, option_group_id, group_name, option_name, price_delta)
    select v_order_item.id, mo.id, g.id, g.name, mo.name, mo.price_delta
    from public.menu_options mo join public.menu_option_groups g on g.id = mo.option_group_id
    where mo.id = any(v_option_ids);
  end loop;
  update public.orders set subtotal_amount = v_subtotal, tax_amount = 0, total_amount = v_subtotal
  where id = v_order.id;
end;
$$;

revoke all on function public.save_kot_order(uuid, jsonb) from public, anon;
grant execute on function public.save_kot_order(uuid, jsonb) to authenticated;
