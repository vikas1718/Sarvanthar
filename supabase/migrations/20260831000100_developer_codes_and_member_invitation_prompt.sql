-- Developer-controlled organisation creation and explicit email invitation decisions.
-- Promote the first developer with the Supabase SQL editor, for example:
-- update public.profiles set is_developer = true where id = '<auth-user-id>';

alter table public.profiles
  add column if not exists is_developer boolean not null default false;

create table if not exists public.developer_codes (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9]{8,20}$'),
  created_by uuid not null references public.profiles(id) on delete restrict,
  used_by uuid references public.profiles(id) on delete set null,
  used_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  check ((used_by is null) = (used_at is null))
);

create index if not exists developer_codes_available_idx
  on public.developer_codes (code) where used_at is null;

alter table public.developer_codes enable row level security;

create function private.is_current_developer()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and is_developer = true
  );
$$;

create function public.is_current_developer()
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_current_developer();
$$;

create policy developer_codes_select_developer on public.developer_codes
  for select to authenticated using ((select private.is_current_developer()));

create function public.create_developer_code(p_expires_in interval default interval '30 days')
returns public.developer_codes language plpgsql security definer set search_path = '' as $$
declare v_code text;
declare v_row public.developer_codes;
begin
  if not (select private.is_current_developer()) then
    raise exception 'Developer access is required';
  end if;
  if p_expires_in <= interval '0 seconds' or p_expires_in > interval '365 days' then
    raise exception 'Expiry must be between 1 second and 365 days';
  end if;
  loop
    v_code := upper(substr(encode(extensions.gen_random_bytes(10), 'hex'), 1, 12));
    begin
      insert into public.developer_codes (code, created_by, expires_at)
      values (v_code, (select auth.uid()), now() + p_expires_in)
      returning * into v_row;
      return v_row;
    exception when unique_violation then
      -- Extremely unlikely collision; generate another opaque code.
    end;
  end loop;
end;
$$;

drop function if exists public.create_business(text, public.business_type, text, text);
create function public.create_business(
  p_name text,
  p_type public.business_type,
  p_business_code text,
  p_slug text default null,
  p_developer_code text default null
)
returns public.businesses language plpgsql security definer set search_path = '' as $$
declare v_business public.businesses;
declare v_code_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select id into v_code_id
  from public.developer_codes
  where code = upper(trim(coalesce(p_developer_code, '')))
    and used_at is null and (expires_at is null or expires_at > now())
  for update;
  if not found then raise exception 'A valid unused developer code is required to create an organization'; end if;

  insert into public.businesses (name, type, business_code, slug, created_by)
  values (p_name, p_type, p_business_code, p_slug, (select auth.uid())) returning * into v_business;
  insert into public.business_memberships (business_id, user_id, role, status, assigned_by)
  values (v_business.id, (select auth.uid()), 'owner', 'active', (select auth.uid()));
  update public.developer_codes set used_by = (select auth.uid()), used_at = now() where id = v_code_id;
  return v_business;
end;
$$;

create function public.get_my_pending_email_invitation()
returns table (invitation_id uuid, business_name text, role public.app_role, stall_name text)
language sql security definer set search_path = '' as $$
  select i.id, b.name, i.role, s.name
  from public.staff_invitations i
  join public.businesses b on b.id = i.business_id
  left join public.stalls s on s.id = i.stall_id
  where i.status = 'invited' and i.accepted_at is null and i.expires_at > now()
    and i.recipient_email is not null
    and lower(i.recipient_email::text) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  order by i.created_at desc limit 1;
$$;

create function public.decide_my_email_invitation(p_invitation_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_invitation public.staff_invitations;
declare v_email text := (select auth.jwt() ->> 'email');
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select * into v_invitation from public.staff_invitations
  where id = p_invitation_id and status = 'invited' and accepted_at is null and expires_at > now()
    and recipient_email is not null and lower(recipient_email::text) = lower(coalesce(v_email, ''))
  for update;
  if not found then raise exception 'Invitation is unavailable'; end if;
  if p_accept then
    if v_invitation.stall_id is null then
      insert into public.business_memberships (business_id, user_id, role, status, assigned_by)
      values (v_invitation.business_id, (select auth.uid()), v_invitation.role, 'active', v_invitation.invited_by)
      on conflict (business_id, user_id) do update set role = excluded.role, status = 'active', assigned_by = excluded.assigned_by;
    else
      insert into public.stall_memberships (business_id, stall_id, user_id, role, status, assigned_by)
      values (v_invitation.business_id, v_invitation.stall_id, (select auth.uid()), v_invitation.role, 'active', v_invitation.invited_by)
      on conflict (stall_id, user_id) do update set role = excluded.role, status = 'active', assigned_by = excluded.assigned_by;
    end if;
    update public.staff_invitations set status = 'disabled', accepted_at = now(), accepted_by = (select auth.uid()) where id = v_invitation.id;
  else
    update public.staff_invitations set status = 'disabled' where id = v_invitation.id;
  end if;
end;
$$;

revoke all on public.developer_codes from public, anon, authenticated;
grant select on public.developer_codes to authenticated;
revoke all on function public.is_current_developer() from public, anon;
revoke all on function public.create_developer_code(interval) from public, anon;
revoke all on function public.create_business(text, public.business_type, text, text, text) from public, anon;
revoke all on function public.get_my_pending_email_invitation() from public, anon;
revoke all on function public.decide_my_email_invitation(uuid, boolean) from public, anon;
grant execute on function public.is_current_developer(), public.create_developer_code(interval), public.create_business(text, public.business_type, text, text, text), public.get_my_pending_email_invitation(), public.decide_my_email_invitation(uuid, boolean) to authenticated;
