-- Replace developer-code onboarding with self-service restaurant trials.

drop function if exists public.create_business(text, public.business_type, text, text, text);
drop function if exists public.create_developer_code(interval);
drop function if exists public.is_current_developer();
drop function if exists private.is_current_developer();
drop function if exists public.redeem_current_staff_invitation(text);
drop table if exists public.developer_codes;

alter table public.profiles rename column is_developer to is_platform_admin;
alter table public.businesses drop column business_code;
alter table public.businesses
  add column trial_started_at timestamptz not null default now(),
  add column trial_expires_at timestamptz not null default (now() + interval '7 days'),
  add column subscription_status text not null default 'trial'
    check (subscription_status in ('trial', 'pro', 'expired')),
  add column subscription_expires_at timestamptz,
  add column owner_name text,
  add column is_deleted boolean not null default false;

create function private.is_platform_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = (select auth.uid()) and is_platform_admin = true);
$$;

create function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_platform_admin();
$$;

create function public.business_access_status(p_business_id uuid)
returns table (is_active boolean, plan text, trial_expires_at timestamptz, subscription_expires_at timestamptz)
language sql security definer set search_path = '' as $$
  select (
    not b.is_deleted and (
      (b.subscription_status = 'pro' and b.subscription_expires_at > now())
      or (b.subscription_status = 'trial' and b.trial_expires_at > now())
    )
  ),
  case when b.subscription_status = 'pro' and b.subscription_expires_at > now() then 'pro'
       when b.subscription_status = 'trial' and b.trial_expires_at > now() then 'trial'
       else 'expired' end,
  b.trial_expires_at, b.subscription_expires_at
  from public.businesses b
  where b.id = p_business_id and (private.has_business_access(b.id) or private.is_platform_admin());
$$;

create function public.create_business(
  p_name text, p_type public.business_type, p_phone text, p_email text default null,
  p_address text default null, p_owner_name text default null, p_logo_url text default null
) returns public.businesses language plpgsql security definer set search_path = '' as $$
declare v_business public.businesses;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  if nullif(trim(p_phone), '') is null then raise exception 'Mobile number is required'; end if;
  insert into public.businesses (name, type, phone, email, address, owner_name, logo_url, created_by)
  values (trim(p_name), p_type, trim(p_phone), nullif(trim(p_email), ''), nullif(trim(p_address), ''), nullif(trim(p_owner_name), ''), nullif(trim(p_logo_url), ''), (select auth.uid()))
  returning * into v_business;
  insert into public.business_memberships (business_id, user_id, role, status, assigned_by)
  values (v_business.id, (select auth.uid()), 'owner', 'active', (select auth.uid()));
  return v_business;
end;
$$;

create function public.list_platform_restaurants()
returns table (id uuid, name text, phone text, email text, owner_name text, created_at timestamptz, plan text, expires_at timestamptz, is_active boolean)
language sql security definer set search_path = '' as $$
  select b.id, b.name, b.phone, b.email, b.owner_name, b.created_at,
    case when b.subscription_status = 'pro' and b.subscription_expires_at > now() then 'pro'
         when b.subscription_status = 'trial' and b.trial_expires_at > now() then 'trial' else 'expired' end,
    case when b.subscription_status = 'pro' then b.subscription_expires_at else b.trial_expires_at end,
    not b.is_deleted and ((b.subscription_status = 'pro' and b.subscription_expires_at > now()) or (b.subscription_status = 'trial' and b.trial_expires_at > now()))
  from public.businesses b where not b.is_deleted and private.is_platform_admin() order by b.created_at desc;
$$;

create function public.delete_platform_restaurant(p_business_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_platform_admin() then raise exception 'Platform admin access is required'; end if;
  update public.businesses set is_deleted = true, archived_at = now() where id = p_business_id;
end;
$$;

revoke all on function public.is_platform_admin(), public.business_access_status(uuid), public.create_business(text, public.business_type, text, text, text, text, text), public.list_platform_restaurants(), public.delete_platform_restaurant(uuid) from public, anon;
grant execute on function public.is_platform_admin(), public.business_access_status(uuid), public.create_business(text, public.business_type, text, text, text, text, text), public.list_platform_restaurants(), public.delete_platform_restaurant(uuid) to authenticated;
