-- Fix create_menu_option's PL/pgSQL record/table-alias name collision.

create or replace function public.create_menu_option(
  p_group_id uuid,
  p_name text,
  p_price_delta numeric,
  p_sort_order integer default 0
)
returns public.menu_options
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.menu_items;
  v_option public.menu_options;
begin
  select menu_item.*
    into v_item
    from public.menu_option_groups as option_group
    join public.menu_items as menu_item
      on menu_item.id = option_group.menu_item_id
   where option_group.id = p_group_id
     and option_group.archived_at is null;

  if not found
     or not private.can_manage_menu(v_item.business_id, v_item.stall_id) then
    raise exception 'Menu management requires owner or manager access';
  end if;

  insert into public.menu_options (
    option_group_id,
    name,
    price_delta,
    sort_order
  )
  values (
    p_group_id,
    trim(p_name),
    p_price_delta,
    p_sort_order
  )
  returning * into v_option;

  return v_option;
end;
$$;

revoke all on function public.create_menu_option(uuid, text, numeric, integer)
  from public, anon;
grant execute on function public.create_menu_option(uuid, text, numeric, integer)
  to authenticated;
