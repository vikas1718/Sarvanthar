-- Shared, business-scoped dining table management.

create type public.dining_table_status as enum ('active', 'inactive');
create type public.dining_table_type as enum ('indoor', 'outdoor');

create table public.dining_tables (
  id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  table_number text not null check (char_length(trim(table_number)) between 1 and 40),
  capacity integer not null check (capacity between 1 and 100),
  status public.dining_table_status not null default 'active',
  type public.dining_table_type not null default 'indoor',
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index dining_tables_active_number_key
  on public.dining_tables (business_id, lower(table_number))
  where archived_at is null;

create index dining_tables_business_idx
  on public.dining_tables (business_id, status, created_at)
  where archived_at is null;

create trigger dining_tables_updated
before update on public.dining_tables
for each row execute procedure private.set_updated_at();

create function private.can_manage_tables(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_business_owner(p_business_id)
    or exists (
      select 1
      from public.business_memberships
      where business_id = p_business_id
        and user_id = (select auth.uid())
        and role = 'manager'
        and status = 'active'
    )
    or exists (
      select 1
      from public.stall_memberships
      where business_id = p_business_id
        and user_id = (select auth.uid())
        and role = 'manager'
        and status = 'active'
    );
$$;

alter table public.dining_tables enable row level security;

create policy dining_tables_read
on public.dining_tables
for select
to authenticated
using (private.has_business_access(business_id));

grant select on public.dining_tables to authenticated;

create function public.create_dining_table(
  p_business_id uuid,
  p_table_number text,
  p_capacity integer,
  p_type public.dining_table_type
)
returns public.dining_tables
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table public.dining_tables;
begin
  if not private.can_manage_tables(p_business_id) then
    raise exception 'Table management requires owner or manager access';
  end if;

  insert into public.dining_tables (business_id, table_number, capacity, type)
  values (p_business_id, trim(p_table_number), p_capacity, p_type)
  returning * into v_table;

  return v_table;
end;
$$;

create function public.update_dining_table(
  p_business_id uuid,
  p_table_id uuid,
  p_table_number text,
  p_capacity integer,
  p_type public.dining_table_type
)
returns public.dining_tables
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table public.dining_tables;
begin
  if not private.can_manage_tables(p_business_id) then
    raise exception 'Table management requires owner or manager access';
  end if;

  update public.dining_tables
     set table_number = trim(p_table_number),
         capacity = p_capacity,
         type = p_type
   where id = p_table_id
     and business_id = p_business_id
     and archived_at is null
  returning * into v_table;

  if not found then
    raise exception 'Table not found or archived';
  end if;

  return v_table;
end;
$$;

create function public.set_dining_table_status(
  p_business_id uuid,
  p_table_id uuid,
  p_status public.dining_table_status
)
returns public.dining_tables
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table public.dining_tables;
begin
  if not private.can_manage_tables(p_business_id) then
    raise exception 'Table management requires owner or manager access';
  end if;

  update public.dining_tables
     set status = p_status
   where id = p_table_id
     and business_id = p_business_id
     and archived_at is null
  returning * into v_table;

  if not found then
    raise exception 'Table not found or archived';
  end if;

  return v_table;
end;
$$;

create function public.archive_dining_table(
  p_business_id uuid,
  p_table_id uuid
)
returns public.dining_tables
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table public.dining_tables;
begin
  if not private.can_manage_tables(p_business_id) then
    raise exception 'Table management requires owner or manager access';
  end if;

  update public.dining_tables
     set status = 'inactive',
         archived_at = now()
   where id = p_table_id
     and business_id = p_business_id
     and archived_at is null
  returning * into v_table;

  if not found then
    raise exception 'Table not found or already archived';
  end if;

  return v_table;
end;
$$;

revoke all on function private.can_manage_tables(uuid) from public, anon;
revoke all on function public.create_dining_table(uuid, text, integer, public.dining_table_type) from public, anon;
revoke all on function public.update_dining_table(uuid, uuid, text, integer, public.dining_table_type) from public, anon;
revoke all on function public.set_dining_table_status(uuid, uuid, public.dining_table_status) from public, anon;
revoke all on function public.archive_dining_table(uuid, uuid) from public, anon;

grant execute on function public.create_dining_table(uuid, text, integer, public.dining_table_type) to authenticated;
grant execute on function public.update_dining_table(uuid, uuid, text, integer, public.dining_table_type) to authenticated;
grant execute on function public.set_dining_table_status(uuid, uuid, public.dining_table_status) to authenticated;
grant execute on function public.archive_dining_table(uuid, uuid) to authenticated;
