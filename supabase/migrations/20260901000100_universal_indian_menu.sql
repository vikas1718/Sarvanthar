-- Universal Indian menu sections, safe category deletion, and one-time seeds.

alter table public.menu_categories
  add column dietary_type text not null default 'veg'
    check (dietary_type in ('veg', 'non_veg'));
alter table public.menu_items
  add column dietary_type text not null default 'veg'
    check (dietary_type in ('veg', 'non_veg'));

create index menu_categories_dietary_scope_idx
  on public.menu_categories (business_id, stall_id, dietary_type, sort_order)
  where archived_at is null;

create or replace function private.enforce_menu_scope()
returns trigger language plpgsql set search_path = '' as $$
declare v_type public.business_type; declare v_category public.menu_categories;
begin
  select type into v_type from public.businesses where id = new.business_id;
  if not found then raise exception 'Business does not exist'; end if;
  if (v_type = 'restaurant' and new.stall_id is not null)
    or (v_type = 'food_court' and new.stall_id is null) then
    raise exception 'Menu scope does not match business type';
  end if;
  if tg_table_name = 'menu_items' then
    select * into v_category from public.menu_categories
      where id = new.category_id and archived_at is null;
    if not found or v_category.business_id <> new.business_id
      or v_category.stall_id is distinct from new.stall_id
      or v_category.dietary_type <> new.dietary_type then
      raise exception 'Category, dietary type, and item scope must match';
    end if;
  end if;
  return new;
end;
$$;

create function public.create_menu_category(
  p_business_id uuid, p_stall_id uuid, p_name text, p_sort_order integer,
  p_dietary_type text
) returns public.menu_categories language plpgsql security definer set search_path = '' as $$
declare v public.menu_categories; declare v_order integer;
begin
  if p_dietary_type not in ('veg', 'non_veg') then raise exception 'Invalid dietary type'; end if;
  if not private.can_manage_menu(p_business_id, p_stall_id) then
    raise exception 'Menu management requires owner or manager access';
  end if;
  select coalesce(max(sort_order), -1) + 1 into v_order from public.menu_categories
    where business_id = p_business_id and stall_id is not distinct from p_stall_id
      and dietary_type = p_dietary_type and archived_at is null;
  insert into public.menu_categories (business_id, stall_id, name, sort_order, dietary_type)
  values (p_business_id, p_stall_id, trim(p_name), case when coalesce(p_sort_order, 0) > 0 then p_sort_order else v_order end, p_dietary_type)
  returning * into v;
  return v;
end;
$$;

create function public.update_menu_category(
  p_category_id uuid, p_name text, p_sort_order integer, p_dietary_type text
) returns public.menu_categories language plpgsql security definer set search_path = '' as $$
declare v public.menu_categories;
begin
  select * into v from public.menu_categories where id = p_category_id and archived_at is null;
  if not found or not private.can_manage_menu(v.business_id, v.stall_id) then
    raise exception 'Menu management requires owner or manager access';
  end if;
  if p_dietary_type not in ('veg', 'non_veg') then raise exception 'Invalid dietary type'; end if;
  if p_dietary_type <> v.dietary_type and exists (
    select 1 from public.menu_items where category_id = p_category_id and archived_at is null
  ) then raise exception 'Move or archive this category''s items before changing its menu section'; end if;
  update public.menu_categories set name = trim(p_name), sort_order = p_sort_order,
    dietary_type = p_dietary_type where id = p_category_id returning * into v;
  return v;
end;
$$;

create or replace function public.archive_menu_category(p_category_id uuid)
returns public.menu_categories language plpgsql security definer set search_path = '' as $$
declare v public.menu_categories;
begin
  select * into v from public.menu_categories where id = p_category_id and archived_at is null;
  if not found or not private.can_manage_menu(v.business_id, v.stall_id) then
    raise exception 'Menu management requires owner or manager access';
  end if;
  if exists (select 1 from public.menu_items where category_id = p_category_id and archived_at is null) then
    raise exception 'Archive or move this category''s items before deleting it';
  end if;
  update public.menu_categories set archived_at = now() where id = p_category_id returning * into v;
  return v;
end;
$$;

create function public.create_menu_item(
  p_business_id uuid, p_stall_id uuid, p_category_id uuid, p_name text,
  p_description text, p_price numeric, p_image_path text, p_sort_order integer,
  p_dietary_type text, p_is_available boolean default true
) returns public.menu_items language plpgsql security definer set search_path = '' as $$
declare v public.menu_items; declare v_order integer;
begin
  if p_dietary_type not in ('veg', 'non_veg') then raise exception 'Invalid dietary type'; end if;
  if not private.can_manage_menu(p_business_id, p_stall_id) then
    raise exception 'Menu management requires owner or manager access';
  end if;
  select coalesce(max(sort_order), -1) + 1 into v_order from public.menu_items
    where category_id = p_category_id and archived_at is null;
  insert into public.menu_items (business_id, stall_id, category_id, name, description,
    price, image_path, sort_order, dietary_type, is_available)
  values (p_business_id, p_stall_id, p_category_id, trim(p_name), nullif(trim(p_description), ''),
    p_price, nullif(trim(p_image_path), ''), case when coalesce(p_sort_order, 0) > 0 then p_sort_order else v_order end, p_dietary_type,
    coalesce(p_is_available, true)) returning * into v;
  return v;
end;
$$;

create function public.update_menu_item(
  p_item_id uuid, p_category_id uuid, p_name text, p_description text,
  p_price numeric, p_image_path text, p_sort_order integer, p_dietary_type text,
  p_is_available boolean
) returns public.menu_items language plpgsql security definer set search_path = '' as $$
declare v public.menu_items;
begin
  select * into v from public.menu_items where id = p_item_id and archived_at is null;
  if not found or not private.can_manage_menu(v.business_id, v.stall_id) then
    raise exception 'Menu management requires owner or manager access';
  end if;
  if p_dietary_type not in ('veg', 'non_veg') then raise exception 'Invalid dietary type'; end if;
  update public.menu_items set category_id = p_category_id, name = trim(p_name),
    description = nullif(trim(p_description), ''), price = p_price,
    image_path = nullif(trim(p_image_path), ''), sort_order = p_sort_order,
    dietary_type = p_dietary_type, is_available = p_is_available
  where id = p_item_id returning * into v;
  return v;
end;
$$;

create or replace function public.seed_default_indian_menu(p_business_id uuid, p_stall_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare c record; v_category_id uuid;
begin
  if not private.can_manage_menu(p_business_id, p_stall_id) then
    raise exception 'Menu management requires owner or manager access';
  end if;
  if exists (select 1 from public.menu_categories where business_id = p_business_id and stall_id is not distinct from p_stall_id)
    or exists (select 1 from public.menu_items where business_id = p_business_id and stall_id is not distinct from p_stall_id) then
    return false;
  end if;
  for c in select * from (values
    ('veg','Breakfast / Tiffin', array['Idli','Vada','Idli Vada','Plain Dosa','Masala Dosa','Set Dosa','Rava Dosa','Onion Dosa','Mysore Masala Dosa','Uttapam','Poori Masala','Pongal','Upma']),
    ('veg','South Indian Specialties', array['Bisi Bele Bath','Lemon Rice','Tamarind Rice','Curd Rice','Tomato Rice','Coconut Rice','Vegetable Pulav']),
    ('veg','Starters / Snacks', array['Gobi 65','Paneer 65','Baby Corn Manchurian','Gobi Manchurian','Paneer Manchurian','Veg Cutlet','French Fries']),
    ('veg','Main Course', array['South Indian Meals','North Indian Meals','Veg Thali','Dal Tadka','Sambar Rice','Rasam Rice','Veg Kurma','Mixed Vegetable Curry','Paneer Butter Masala','Kadai Paneer','Palak Paneer']),
    ('veg','Breads', array['Chapati','Parotta','Kerala Parotta','Butter Naan','Plain Naan','Tandoori Roti']),
    ('veg','Rice & Biryani', array['Veg Biryani','Paneer Biryani','Mushroom Biryani','Veg Fried Rice','Paneer Fried Rice','Ghee Rice']),
    ('veg','Beverages', array['Filter Coffee','Tea','Masala Tea','Fresh Lime Soda','Buttermilk','Fresh Lime Juice','Cold Coffee','Mango Lassi','Sweet Lassi']),
    ('veg','Desserts', array['Gulab Jamun','Rasmalai','Payasam','Kesari Bath','Ice Cream','Brownie']),
    ('non_veg','Non-Veg Starters', array['Chicken 65','Chicken Lollipop','Chicken Kebab','Chicken Tikka','Pepper Chicken','Chilli Chicken','Mutton Kebab','Fish Fry','Prawn Fry','Fish 65']),
    ('non_veg','Tandoor / Grill', array['Tandoori Chicken','Chicken Tikka','Chicken Seekh Kebab','Tandoori Fish','Chicken Kebab']),
    ('non_veg','Chicken', array['Chicken Curry','Chicken Masala','Chicken Butter Masala','Kadai Chicken','Chicken Chettinad','Pepper Chicken','Chilli Chicken']),
    ('non_veg','Mutton', array['Mutton Curry','Mutton Masala','Mutton Pepper Fry','Mutton Chukka','Mutton Biryani']),
    ('non_veg','Fish & Seafood', array['Fish Curry','Fish Fry','Fish Masala','Prawn Masala','Prawn Fry']),
    ('non_veg','Egg', array['Egg Curry','Egg Masala','Egg Bhurji','Egg Dosa','Egg Fried Rice']),
    ('non_veg','Non-Veg Rice & Biryani', array['Chicken Biryani','Mutton Biryani','Egg Biryani','Chicken Fried Rice','Chicken Schezwan Fried Rice','Chicken Noodles']),
    ('non_veg','Non-Veg Main Course', array['Chicken Meals','Mutton Meals','Fish Meals','Chicken Chettinad','Mutton Curry'])
  ) as v(dietary_type, name, menu_items) loop
    insert into public.menu_categories (business_id, stall_id, name, sort_order, dietary_type)
    values (p_business_id, p_stall_id, c.name,
      (select count(*) from public.menu_categories mc where mc.business_id = p_business_id and mc.stall_id is not distinct from p_stall_id and mc.dietary_type = c.dietary_type), c.dietary_type)
    returning id into v_category_id;
    insert into public.menu_items (business_id, stall_id, category_id, name, description, price, sort_order, dietary_type)
    select p_business_id, p_stall_id, v_category_id, item,
      case
        when c.name = 'Breakfast / Tiffin' then 'Freshly prepared South Indian breakfast favourite.'
        when c.name = 'Beverages' then 'A refreshing house-made beverage.'
        when c.name = 'Desserts' then 'A sweet finish made for sharing.'
        when c.name like '%Biryani%' then 'Fragrant rice prepared with aromatic spices.'
        when c.name in ('Fish & Seafood', 'Non-Veg Starters', 'Tandoor / Grill') then 'Freshly prepared with bold South Indian spices.'
        else 'A freshly prepared house speciality.'
      end,
      case
        when c.name = 'Beverages' then 45 + ordinality * 10
        when c.name = 'Desserts' then 80 + ordinality * 15
        when c.name = 'Breads' then 25 + ordinality * 10
        when c.dietary_type = 'veg' then 100 + ordinality * 15
        else 190 + ordinality * 20
      end,
      ordinality - 1, c.dietary_type
    from unnest(c.menu_items) with ordinality as u(item, ordinality);
  end loop;
  return true;
end;
$$;

revoke all on function public.create_menu_category(uuid,uuid,text,integer,text), public.update_menu_category(uuid,text,integer,text), public.create_menu_item(uuid,uuid,uuid,text,text,numeric,text,integer,text,boolean), public.update_menu_item(uuid,uuid,text,text,numeric,text,integer,text,boolean), public.seed_default_indian_menu(uuid,uuid) from public, anon;
grant execute on function public.create_menu_category(uuid,uuid,text,integer,text), public.update_menu_category(uuid,text,integer,text), public.create_menu_item(uuid,uuid,uuid,text,text,numeric,text,integer,text,boolean), public.update_menu_item(uuid,uuid,text,text,numeric,text,integer,text,boolean), public.seed_default_indian_menu(uuid,uuid) to authenticated;
