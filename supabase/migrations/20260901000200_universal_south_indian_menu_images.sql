-- Attach direct Unsplash images to the Universal South Indian menu.
-- Existing custom menus are never expanded: inserts run only for completely empty scopes.

create temporary table _south_indian_menu_seed (
  dietary_type text not null check (dietary_type in ('veg', 'non_veg')),
  category_name text not null,
  category_order integer not null,
  item_name text not null,
  item_order integer not null,
  image_url text not null check (image_url ~ '^https://images\.unsplash\.com/'),
  primary key (dietary_type, category_name, item_name)
) on commit drop;

insert into _south_indian_menu_seed
  (dietary_type, category_name, category_order, item_name, item_order, image_url)
with categories(dietary_type, category_name, category_order, item_names) as (
  values
    ('veg', 'Breakfast / Tiffin', 0, array['Idli','Vada','Idli Vada','Plain Dosa','Masala Dosa','Set Dosa','Rava Dosa','Onion Dosa','Mysore Masala Dosa','Uttapam','Poori Masala','Pongal','Upma']),
    ('veg', 'South Indian Specialties', 1, array['Bisi Bele Bath','Lemon Rice','Tamarind Rice','Curd Rice','Tomato Rice','Coconut Rice','Vegetable Pulav']),
    ('veg', 'Starters / Snacks', 2, array['Gobi 65','Paneer 65','Baby Corn Manchurian','Gobi Manchurian','Paneer Manchurian','Veg Cutlet','French Fries']),
    ('veg', 'Main Course', 3, array['South Indian Meals','North Indian Meals','Veg Thali','Dal Tadka','Sambar Rice','Rasam Rice','Veg Kurma','Mixed Vegetable Curry','Paneer Butter Masala','Kadai Paneer','Palak Paneer']),
    ('veg', 'Breads', 4, array['Chapati','Parotta','Kerala Parotta','Butter Naan','Plain Naan','Tandoori Roti']),
    ('veg', 'Rice & Biryani', 5, array['Veg Biryani','Paneer Biryani','Mushroom Biryani','Veg Fried Rice','Paneer Fried Rice','Ghee Rice']),
    ('veg', 'Beverages', 6, array['Filter Coffee','Tea','Masala Tea','Fresh Lime Soda','Buttermilk','Fresh Lime Juice','Cold Coffee','Mango Lassi','Sweet Lassi']),
    ('veg', 'Desserts', 7, array['Gulab Jamun','Rasmalai','Payasam','Kesari Bath','Ice Cream','Brownie']),
    ('non_veg', 'Non-Veg Starters', 0, array['Chicken 65','Chicken Lollipop','Chicken Kebab','Chicken Tikka','Pepper Chicken','Chilli Chicken','Mutton Kebab','Fish Fry','Prawn Fry','Fish 65']),
    ('non_veg', 'Tandoor / Grill', 1, array['Tandoori Chicken','Chicken Tikka','Chicken Seekh Kebab','Tandoori Fish','Chicken Kebab']),
    ('non_veg', 'Chicken', 2, array['Chicken Curry','Chicken Masala','Chicken Butter Masala','Kadai Chicken','Chicken Chettinad','Pepper Chicken','Chilli Chicken']),
    ('non_veg', 'Mutton', 3, array['Mutton Curry','Mutton Masala','Mutton Pepper Fry','Mutton Chukka','Mutton Biryani']),
    ('non_veg', 'Fish & Seafood', 4, array['Fish Curry','Fish Fry','Fish Masala','Prawn Masala','Prawn Fry']),
    ('non_veg', 'Egg', 5, array['Egg Curry','Egg Masala','Egg Bhurji','Egg Dosa','Egg Fried Rice']),
    ('non_veg', 'Non-Veg Rice & Biryani', 6, array['Chicken Biryani','Mutton Biryani','Egg Biryani','Chicken Fried Rice','Chicken Schezwan Fried Rice','Chicken Noodles']),
    ('non_veg', 'Non-Veg Main Course', 7, array['Chicken Meals','Mutton Meals','Fish Meals','Chicken Chettinad','Mutton Curry'])
)
select c.dietary_type, c.category_name, c.category_order, item, item_order - 1,
  case
    when item in ('Idli','Idli Vada','Set Dosa') then 'https://images.unsplash.com/photo-1743517894265-c86ab035adef?auto=format&fit=crop&w=900&q=80'
    when item in ('Vada','Veg Cutlet') then 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=900&q=80'
    when item in ('Plain Dosa','Masala Dosa','Rava Dosa','Onion Dosa','Mysore Masala Dosa','Uttapam','Egg Dosa') then 'https://images.unsplash.com/photo-1743615467363-250466982515?auto=format&fit=crop&w=900&q=80'
    when item in ('Poori Masala','Pongal','Upma') then 'https://images.unsplash.com/photo-1665660710687-b44c50751054?auto=format&fit=crop&w=900&q=80'
    when item = 'Vegetable Pulav' or item in ('Veg Biryani','Paneer Biryani','Mushroom Biryani','Ghee Rice','Mutton Biryani','Chicken Biryani','Egg Biryani') then 'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?auto=format&fit=crop&w=900&q=80'
    when item in ('Veg Fried Rice','Paneer Fried Rice','Egg Fried Rice','Chicken Fried Rice','Chicken Schezwan Fried Rice') then 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=900&q=80'
    when item = 'French Fries' then 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=900&q=80'
    when c.category_name = 'Breads' or item in ('Chicken Lollipop','Chicken Kebab','Chicken Tikka','Mutton Kebab','Tandoori Chicken','Chicken Seekh Kebab','Mutton Pepper Fry','Mutton Chukka') then 'https://images.unsplash.com/photo-1775211578178-61f06027adf3?auto=format&fit=crop&w=900&q=80'
    when item in ('Fish Fry','Prawn Fry','Fish 65','Tandoori Fish','Fish Curry','Fish Masala','Prawn Masala','Fish Meals') then 'https://images.unsplash.com/photo-1786222084052-fb6f27bfb135?auto=format&fit=crop&w=900&q=80'
    when item = 'Chicken Noodles' then 'https://images.unsplash.com/photo-1585032226651-759b368d7246?auto=format&fit=crop&w=900&q=80'
    when c.dietary_type = 'non_veg' then 'https://images.unsplash.com/photo-1764304733301-3a9f335f0c67?auto=format&fit=crop&w=900&q=80'
    else 'https://images.unsplash.com/photo-1665660710687-b44c50751054?auto=format&fit=crop&w=900&q=80'
  end
from categories c cross join lateral unnest(c.item_names) with ordinality as u(item, item_order);

do $$
begin
  if exists (select 1 from _south_indian_menu_seed where image_url is null or image_url !~ '^https://images\.unsplash\.com/') then
    raise exception 'Every Universal South Indian menu item must have a direct Unsplash image URL';
  end if;
  if exists (select 1 from _south_indian_menu_seed group by dietary_type, category_name, item_name having count(*) > 1) then
    raise exception 'Duplicate Universal South Indian menu seed item';
  end if;
end;
$$;

-- Update matching pre-built items without changing their IDs, prices, non-empty
-- descriptions, availability, or any records outside the intended categories.
update public.menu_items item
set image_path = seed.image_url,
    dietary_type = seed.dietary_type,
    description = coalesce(item.description, 'A freshly prepared house speciality.')
from public.menu_categories category
join _south_indian_menu_seed seed
  on seed.category_name = category.name
 and seed.dietary_type = category.dietary_type
where item.category_id = category.id
  and item.business_id = category.business_id
  and item.stall_id is not distinct from category.stall_id
  and item.name = seed.item_name
  and item.archived_at is null;

-- A scope with any existing category or item is considered customised/existing.
-- Only truly empty restaurant scopes and food-court stalls receive new records.
create temporary table _south_indian_empty_scopes (
  business_id uuid not null,
  stall_id uuid
) on commit drop;

insert into _south_indian_empty_scopes (business_id, stall_id)
select business.id, null
from public.businesses business
where business.type = 'restaurant'
  and not exists (select 1 from public.menu_categories c where c.business_id = business.id and c.stall_id is null)
  and not exists (select 1 from public.menu_items i where i.business_id = business.id and i.stall_id is null)
union all
select stall.business_id, stall.id
from public.stalls stall
where not exists (select 1 from public.menu_categories c where c.business_id = stall.business_id and c.stall_id = stall.id)
  and not exists (select 1 from public.menu_items i where i.business_id = stall.business_id and i.stall_id = stall.id);

create temporary table _south_indian_created_categories (
  id uuid not null,
  business_id uuid not null,
  stall_id uuid,
  name text not null,
  dietary_type text not null
) on commit drop;

with inserted_categories as (
  insert into public.menu_categories (business_id, stall_id, name, sort_order, dietary_type)
  select scope.business_id, scope.stall_id, seed.category_name, seed.category_order, seed.dietary_type
  from _south_indian_empty_scopes scope
  join (select distinct dietary_type, category_name, category_order from _south_indian_menu_seed) seed on true
  returning id, business_id, stall_id, name, dietary_type
)
insert into _south_indian_created_categories (id, business_id, stall_id, name, dietary_type)
select id, business_id, stall_id, name, dietary_type from inserted_categories;

insert into public.menu_items (business_id, stall_id, category_id, name, description, price, image_path, is_available, sort_order, dietary_type)
select category.business_id, category.stall_id, category.id, seed.item_name,
  'A freshly prepared house speciality.',
  case when seed.category_name = 'Beverages' then 45 + (seed.item_order + 1) * 10
       when seed.category_name = 'Desserts' then 80 + (seed.item_order + 1) * 15
       when seed.category_name = 'Breads' then 25 + (seed.item_order + 1) * 10
       when seed.dietary_type = 'veg' then 100 + (seed.item_order + 1) * 15
       else 190 + (seed.item_order + 1) * 20 end,
  seed.image_url, true, seed.item_order, seed.dietary_type
from _south_indian_created_categories category
join _south_indian_menu_seed seed
  on seed.category_name = category.name and seed.dietary_type = category.dietary_type;

do $$
begin
  if exists (
    select 1
    from public.menu_items i
    join public.menu_categories c on c.id = i.category_id
    join _south_indian_menu_seed s
      on s.dietary_type = c.dietary_type
     and s.category_name = c.name
     and s.item_name = i.name
    where i.archived_at is null and c.archived_at is null
      and (i.dietary_type <> s.dietary_type or i.image_path is null)
  ) then raise exception 'Menu item dietary type must match its category'; end if;
end;
$$;
