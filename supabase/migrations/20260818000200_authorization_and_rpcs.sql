-- RLS and the only mutation paths exposed to authenticated clients.

create function private.is_business_owner(p_business_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.business_memberships bm
    where bm.business_id = p_business_id
      and bm.user_id = (select auth.uid())
      and bm.role = 'owner' and bm.status = 'active'
  );
$$;

create function private.has_business_access(p_business_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.business_memberships bm
    where bm.business_id = p_business_id and bm.user_id = (select auth.uid()) and bm.status = 'active'
    union all
    select 1 from public.stall_memberships sm
    where sm.business_id = p_business_id and sm.user_id = (select auth.uid()) and sm.status = 'active'
  );
$$;

create function private.has_stall_access(p_stall_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.stalls s
    where s.id = p_stall_id and (
      (select private.is_business_owner(s.business_id))
      or exists (select 1 from public.stall_memberships sm where sm.stall_id = s.id and sm.user_id = (select auth.uid()) and sm.status = 'active')
    )
  );
$$;

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_memberships enable row level security;
alter table public.stalls enable row level security;
alter table public.stall_memberships enable row level security;
alter table public.staff_invitations enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy businesses_select_accessible on public.businesses for select to authenticated using ((select private.has_business_access(id)));
create policy memberships_select_owner_or_self on public.business_memberships for select to authenticated using (user_id = (select auth.uid()) or (select private.is_business_owner(business_id)));
create policy stalls_select_accessible on public.stalls for select to authenticated using ((select private.has_stall_access(id)));
create policy stall_memberships_select_owner_or_self on public.stall_memberships for select to authenticated using (user_id = (select auth.uid()) or (select private.is_business_owner(business_id)));
create policy invitations_select_owner on public.staff_invitations for select to authenticated using ((select private.is_business_owner(business_id)));

create function public.create_business(p_name text, p_type public.business_type, p_business_code text, p_slug text default null)
returns public.businesses language plpgsql security definer set search_path = '' as $$
declare v_business public.businesses;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  insert into public.businesses (name, type, business_code, slug, created_by)
  values (p_name, p_type, p_business_code, p_slug, (select auth.uid())) returning * into v_business;
  insert into public.business_memberships (business_id, user_id, role, status, assigned_by)
  values (v_business.id, (select auth.uid()), 'owner', 'active', (select auth.uid()));
  return v_business;
end;
$$;

create function public.create_stall(p_business_id uuid, p_name text, p_slug text default null)
returns public.stalls language plpgsql security definer set search_path = '' as $$
declare v_stall public.stalls;
begin
  if not (select private.is_business_owner(p_business_id)) then raise exception 'Only the business owner can manage stalls'; end if;
  insert into public.stalls (business_id, name, slug, created_by)
  values (p_business_id, p_name, p_slug, (select auth.uid())) returning * into v_stall;
  return v_stall;
end;
$$;

create function public.assign_restaurant_staff(p_business_id uuid, p_user_id uuid, p_role public.app_role)
returns public.business_memberships language plpgsql security definer set search_path = '' as $$
declare v_membership public.business_memberships;
begin
  if not (select private.is_business_owner(p_business_id)) then raise exception 'Only the business owner can manage staff'; end if;
  if p_role = 'owner' then raise exception 'Users cannot be assigned owner role'; end if;
  insert into public.business_memberships (business_id, user_id, role, status, assigned_by)
  values (p_business_id, p_user_id, p_role, 'active', (select auth.uid()))
  on conflict (business_id, user_id) do update set role = excluded.role, status = 'active', assigned_by = excluded.assigned_by
  returning * into v_membership;
  return v_membership;
end;
$$;

create function public.assign_stall_staff(p_business_id uuid, p_stall_id uuid, p_user_id uuid, p_role public.app_role)
returns public.stall_memberships language plpgsql security definer set search_path = '' as $$
declare v_membership public.stall_memberships;
begin
  if not (select private.is_business_owner(p_business_id)) then raise exception 'Only the business owner can manage staff'; end if;
  if p_role = 'owner' then raise exception 'Users cannot be assigned owner role'; end if;
  insert into public.stall_memberships (business_id, stall_id, user_id, role, status, assigned_by)
  values (p_business_id, p_stall_id, p_user_id, p_role, 'active', (select auth.uid()))
  on conflict (stall_id, user_id) do update set role = excluded.role, status = 'active', assigned_by = excluded.assigned_by
  returning * into v_membership;
  return v_membership;
end;
$$;

create function public.create_staff_invitation(p_business_id uuid, p_stall_id uuid, p_role public.app_role, p_email extensions.citext default null, p_phone text default null, p_expires_in interval default interval '7 days')
returns table (invitation_id uuid, token text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare v_token text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  if not (select private.is_business_owner(p_business_id)) then raise exception 'Only the business owner can invite staff'; end if;
  if p_role = 'owner' then raise exception 'Users cannot be invited as owners'; end if;
  if p_expires_in <= interval '0 seconds' or p_expires_in > interval '30 days' then raise exception 'Invitation expiry must be between 1 second and 30 days'; end if;
  return query
  insert into public.staff_invitations (business_id, stall_id, recipient_email, recipient_phone, role, token_hash, invited_by, expires_at)
  values (p_business_id, p_stall_id, p_email, p_phone, p_role, extensions.crypt(v_token, extensions.gen_salt('bf')), (select auth.uid()), now() + p_expires_in)
  returning id, v_token, staff_invitations.expires_at;
end;
$$;

create function public.redeem_staff_invitation(p_token text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_invitation public.staff_invitations;
declare v_email text := (select auth.jwt() ->> 'email');
declare v_phone text := (select auth.jwt() ->> 'phone');
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select * into v_invitation from public.staff_invitations
  where status = 'invited' and accepted_at is null and expires_at > now()
    and extensions.crypt(p_token, token_hash) = token_hash
  limit 1 for update;
  if not found then raise exception 'Invitation is invalid, expired, or already used'; end if;
  if (v_invitation.recipient_email is not null and lower(v_email) <> lower(v_invitation.recipient_email::text))
     or (v_invitation.recipient_phone is not null and v_phone <> v_invitation.recipient_phone) then
    raise exception 'Invitation recipient does not match authenticated user';
  end if;
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
end;
$$;

revoke all on all tables in schema public from anon;
revoke insert, update, delete on public.profiles, public.businesses, public.business_memberships, public.stalls, public.stall_memberships, public.staff_invitations from authenticated;
grant select on public.profiles, public.businesses, public.business_memberships, public.stalls, public.stall_memberships, public.staff_invitations to authenticated;
revoke all on all functions in schema public from public, anon;
grant execute on function public.create_business(text, public.business_type, text, text) to authenticated;
grant execute on function public.create_stall(uuid, text, text) to authenticated;
grant execute on function public.assign_restaurant_staff(uuid, uuid, public.app_role) to authenticated;
grant execute on function public.assign_stall_staff(uuid, uuid, uuid, public.app_role) to authenticated;
grant execute on function public.create_staff_invitation(uuid, uuid, public.app_role, extensions.citext, text, interval) to authenticated;
grant execute on function public.redeem_staff_invitation(text) to authenticated;
