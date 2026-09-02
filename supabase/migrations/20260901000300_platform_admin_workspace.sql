-- Platform-admin reporting, controlled account management, announcements, and audit trail.
create table if not exists public.platform_announcements (
  id uuid primary key default extensions.gen_random_uuid(),
  title text not null check (char_length(trim(title)) between 1 and 120),
  message text not null check (char_length(trim(message)) between 1 and 2000),
  business_id uuid references public.businesses(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete restrict,
  published_at timestamptz not null default now()
);
create table if not exists public.platform_audit_logs (
  id uuid primary key default extensions.gen_random_uuid(),
  action text not null,
  business_id uuid references public.businesses(id) on delete set null,
  admin_id uuid not null references public.profiles(id) on delete restrict,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.platform_announcements enable row level security;
alter table public.platform_audit_logs enable row level security;
create policy announcements_admin_only on public.platform_announcements for all to authenticated using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy audit_admin_only on public.platform_audit_logs for select to authenticated using (private.is_platform_admin());

create or replace function public.platform_admin_overview()
returns table(total_restaurants bigint, active_restaurants bigint, trial_restaurants bigint, pro_restaurants bigint, expired_restaurants bigint, locked_restaurants bigint, total_tables bigint, total_qr_codes bigint, total_orders bigint, todays_orders bigint)
language sql security definer set search_path='' as $$
 select
  (select count(*) from public.businesses where not is_deleted),
  (select count(*) from public.businesses where not is_deleted and ((subscription_status='trial' and trial_expires_at>now()) or (subscription_status='pro' and subscription_expires_at>now()))),
  (select count(*) from public.businesses where not is_deleted and subscription_status='trial' and trial_expires_at>now()),
  (select count(*) from public.businesses where not is_deleted and subscription_status='pro' and subscription_expires_at>now()),
  (select count(*) from public.businesses where not is_deleted and subscription_status='trial' and trial_expires_at<=now()),
  (select count(*) from public.businesses where is_deleted or subscription_status='expired' or (subscription_status='pro' and coalesce(subscription_expires_at, now())<=now())),
  (select count(*) from public.dining_tables), (select count(*) from public.qr_tokens), (select count(*) from public.orders),
  (select count(*) from public.orders where created_at >= date_trunc('day', now()))
 where private.is_platform_admin();
$$;

create or replace function public.platform_admin_set_restaurant(p_business_id uuid, p_action text, p_days integer default 7)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.is_platform_admin() then raise exception 'Platform admin access is required'; end if;
 if p_action='lock' then update public.businesses set subscription_status='expired' where id=p_business_id;
 elsif p_action='unlock_trial' then update public.businesses set subscription_status='trial', trial_expires_at=now()+make_interval(days=>greatest(p_days,1)) where id=p_business_id;
 elsif p_action='pro' then update public.businesses set subscription_status='pro', subscription_expires_at=now()+make_interval(days=>greatest(p_days,1)) where id=p_business_id;
 elsif p_action='extend_trial' then update public.businesses set subscription_status='trial', trial_expires_at=greatest(trial_expires_at,now())+make_interval(days=>greatest(p_days,1)) where id=p_business_id;
 else raise exception 'Unknown account action'; end if;
 insert into public.platform_audit_logs(action,business_id,admin_id,details) values(p_action,p_business_id,auth.uid(),jsonb_build_object('days',p_days));
end; $$;
create or replace function public.platform_admin_restaurant_usage(p_business_id uuid)
returns table(tables bigint, active_tables bigint, qr_codes bigint, active_qr_codes bigint, menu_categories bigint, menu_items bigint, orders bigint, last_activity timestamptz)
language sql security definer set search_path='' as $$
 select (select count(*) from public.dining_tables where business_id=p_business_id), (select count(*) from public.dining_tables where business_id=p_business_id and status='active'), (select count(*) from public.qr_tokens where business_id=p_business_id), (select count(*) from public.qr_tokens where business_id=p_business_id and status='active'), (select count(*) from public.menu_categories where business_id=p_business_id and archived_at is null), (select count(*) from public.menu_items where business_id=p_business_id and archived_at is null), (select count(*) from public.orders where business_id=p_business_id), (select max(created_at) from public.orders where business_id=p_business_id) where private.is_platform_admin();
$$;
revoke all on function public.platform_admin_overview(), public.platform_admin_set_restaurant(uuid,text,integer), public.platform_admin_restaurant_usage(uuid) from public, anon;
grant execute on function public.platform_admin_overview(), public.platform_admin_set_restaurant(uuid,text,integer), public.platform_admin_restaurant_usage(uuid) to authenticated;
