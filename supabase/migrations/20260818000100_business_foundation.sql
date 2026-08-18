-- ServeFlow business, membership, and invitation foundation.
-- This migration intentionally contains no ordering, payment, menu, or QR tables.

create schema if not exists private;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;

create type public.business_type as enum ('restaurant', 'food_court');
create type public.app_role as enum ('owner', 'manager', 'kitchen', 'cashier', 'staff');
create type public.membership_status as enum ('active', 'invited', 'disabled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.businesses (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 160),
  type public.business_type not null,
  business_code text not null unique check (business_code ~ '^[A-Z0-9]{6,20}$'),
  slug text unique check (slug is null or slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create table public.business_memberships (
  id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null,
  status public.membership_status not null default 'active',
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, user_id)
);

create unique index business_memberships_one_owner_per_business
  on public.business_memberships (business_id)
  where role = 'owner' and status <> 'disabled';

create table public.stalls (
  id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 160),
  slug text,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, name),
  unique (business_id, slug),
  unique (id, business_id)
);

create table public.stall_memberships (
  id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null,
  stall_id uuid not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null check (role <> 'owner'),
  status public.membership_status not null default 'active',
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (stall_id, business_id) references public.stalls(id, business_id) on delete cascade,
  unique (stall_id, user_id)
);

create table public.staff_invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  stall_id uuid,
  recipient_email extensions.citext,
  recipient_phone text,
  role public.app_role not null check (role <> 'owner'),
  token_hash text not null,
  status public.membership_status not null default 'invited' check (status = 'invited' or status = 'disabled'),
  invited_by uuid not null references public.profiles(id) on delete restrict,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (recipient_email is not null or recipient_phone is not null),
  check (accepted_at is null or (accepted_by is not null and status = 'disabled')),
  foreign key (stall_id, business_id) references public.stalls(id, business_id) on delete cascade
);

create index businesses_created_by_idx on public.businesses (created_by);
create index business_memberships_active_user_business_idx on public.business_memberships (user_id, business_id) where status = 'active';
create index business_memberships_active_business_idx on public.business_memberships (business_id) where status = 'active';
create index stalls_active_business_idx on public.stalls (business_id) where status = 'active';
create index stall_memberships_active_user_business_idx on public.stall_memberships (user_id, business_id) where status = 'active';
create index stall_memberships_active_user_stall_idx on public.stall_memberships (user_id, stall_id) where status = 'active';
create index staff_invitations_business_status_idx on public.staff_invitations (business_id, status);
create index staff_invitations_open_expiry_idx on public.staff_invitations (expires_at) where status = 'invited';

create function private.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create function private.create_profile_for_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (new.id, nullif(new.raw_user_meta_data ->> 'full_name', ''), nullif(new.phone, ''));
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute procedure private.create_profile_for_auth_user();

create function private.enforce_business_membership_rules()
returns trigger language plpgsql set search_path = '' as $$
declare v_type public.business_type;
begin
  select type into v_type from public.businesses where id = new.business_id;
  if not found then raise exception 'Business does not exist'; end if;
  if v_type = 'food_court' and new.role <> 'owner' then
    raise exception 'Food court non-owner staff must use stall_memberships';
  end if;
  if v_type = 'food_court' and new.role = 'owner' and new.status = 'invited' then
    raise exception 'Food court owner memberships cannot be invitations';
  end if;
  if v_type = 'restaurant' and exists (
    select 1 from public.stall_memberships sm
    where sm.business_id = new.business_id and sm.user_id = new.user_id
  ) then raise exception 'Restaurant staff cannot have stall memberships'; end if;
  return new;
end;
$$;

create function private.enforce_stall_rules()
returns trigger language plpgsql set search_path = '' as $$
declare v_type public.business_type;
begin
  select type into v_type from public.businesses where id = new.business_id;
  if v_type is distinct from 'food_court' then
    raise exception 'Stalls can exist only under food court businesses';
  end if;
  return new;
end;
$$;

create function private.enforce_stall_membership_rules()
returns trigger language plpgsql set search_path = '' as $$
declare v_type public.business_type;
begin
  select type into v_type from public.businesses where id = new.business_id;
  if v_type is distinct from 'food_court' then raise exception 'Restaurant staff cannot receive stall memberships'; end if;
  if new.role = 'owner' then raise exception 'Owner access is business-wide, not stall-level'; end if;
  if exists (select 1 from public.business_memberships bm where bm.business_id = new.business_id and bm.user_id = new.user_id and bm.status = 'active') then
    raise exception 'Food court staff memberships must be stall-level; only owners use business_memberships';
  end if;
  return new;
end;
$$;

create function private.enforce_invitation_rules()
returns trigger language plpgsql set search_path = '' as $$
declare v_type public.business_type;
begin
  select type into v_type from public.businesses where id = new.business_id;
  if v_type = 'restaurant' and new.stall_id is not null then raise exception 'Restaurant invitations cannot include a stall'; end if;
  if v_type = 'food_court' and new.stall_id is null then raise exception 'Food court staff invitations require a stall'; end if;
  if new.role = 'owner' then raise exception 'Owners cannot be invited through staff invitations'; end if;
  return new;
end;
$$;

create trigger businesses_set_updated_at before update on public.businesses for each row execute procedure private.set_updated_at();
create trigger profiles_set_updated_at before update on public.profiles for each row execute procedure private.set_updated_at();
create trigger business_memberships_set_updated_at before update on public.business_memberships for each row execute procedure private.set_updated_at();
create trigger stalls_set_updated_at before update on public.stalls for each row execute procedure private.set_updated_at();
create trigger stall_memberships_set_updated_at before update on public.stall_memberships for each row execute procedure private.set_updated_at();
create trigger business_memberships_enforce before insert or update on public.business_memberships for each row execute procedure private.enforce_business_membership_rules();
create trigger stalls_enforce before insert or update on public.stalls for each row execute procedure private.enforce_stall_rules();
create trigger stall_memberships_enforce before insert or update on public.stall_memberships for each row execute procedure private.enforce_stall_membership_rules();
create trigger staff_invitations_enforce before insert or update on public.staff_invitations for each row execute procedure private.enforce_invitation_rules();
