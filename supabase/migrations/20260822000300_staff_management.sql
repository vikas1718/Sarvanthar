-- Staff listing, invitation management, and fail-closed redemption.

create or replace function public.redeem_staff_invitation(p_token text)
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
  if (v_invitation.recipient_email is not null and
      (v_email is null or lower(v_email) <> lower(v_invitation.recipient_email::text)))
     or (v_invitation.recipient_phone is not null and
      (v_phone is null or v_phone <> v_invitation.recipient_phone)) then
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

create function public.get_staff_invitation(p_token text)
returns table (invitation_id uuid, business_id uuid, business_name text, stall_id uuid, stall_name text, role public.app_role, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare v_invitation public.staff_invitations;
declare v_email text := (select auth.jwt() ->> 'email');
declare v_phone text := (select auth.jwt() ->> 'phone');
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select * into v_invitation from public.staff_invitations i
  where i.status = 'invited' and i.accepted_at is null and i.expires_at > now()
    and extensions.crypt(p_token, i.token_hash) = i.token_hash limit 1;
  if not found then raise exception 'Invitation is invalid, expired, or already used'; end if;
  if (v_invitation.recipient_email is not null and
      (v_email is null or lower(v_email) <> lower(v_invitation.recipient_email::text)))
     or (v_invitation.recipient_phone is not null and
      (v_phone is null or v_phone <> v_invitation.recipient_phone)) then
    raise exception 'Invitation recipient does not match authenticated user';
  end if;
  return query select v_invitation.id, b.id, b.name, s.id, s.name, v_invitation.role, v_invitation.expires_at
  from public.businesses b left join public.stalls s on s.id = v_invitation.stall_id where b.id = v_invitation.business_id;
end;
$$;

create function public.list_business_staff(p_business_id uuid)
returns table (membership_type text, membership_id uuid, user_id uuid, full_name text, email text, phone text, role public.app_role, status public.membership_status, stall_id uuid, stall_name text)
language plpgsql security definer set search_path = '' as $$
begin
  if not (select private.is_business_owner(p_business_id)) then raise exception 'Only the business owner can manage staff'; end if;
  return query
  select 'business'::text, bm.id, bm.user_id, p.full_name, u.email::text, coalesce(p.phone, u.phone), bm.role, bm.status, null::uuid, null::text
  from public.business_memberships bm join public.profiles p on p.id = bm.user_id join auth.users u on u.id = bm.user_id
  where bm.business_id = p_business_id and bm.role <> 'owner'
  union all
  select 'stall'::text, sm.id, sm.user_id, p.full_name, u.email::text, coalesce(p.phone, u.phone), sm.role, sm.status, s.id, s.name
  from public.stall_memberships sm join public.profiles p on p.id = sm.user_id join auth.users u on u.id = sm.user_id join public.stalls s on s.id = sm.stall_id
  where sm.business_id = p_business_id;
end;
$$;

create function public.revoke_staff_invitation(p_business_id uuid, p_invitation_id uuid)
returns public.staff_invitations language plpgsql security definer set search_path = '' as $$
declare v_invitation public.staff_invitations;
begin
  if not (select private.is_business_owner(p_business_id)) then raise exception 'Only the business owner can manage staff'; end if;
  update public.staff_invitations set status = 'disabled'
  where id = p_invitation_id and business_id = p_business_id and status = 'invited' and accepted_at is null
  returning * into v_invitation;
  if not found then raise exception 'Pending invitation not found'; end if;
  return v_invitation;
end;
$$;

create function public.disable_business_staff(p_business_id uuid, p_user_id uuid)
returns public.business_memberships language plpgsql security definer set search_path = '' as $$
declare v_membership public.business_memberships;
begin
  if not (select private.is_business_owner(p_business_id)) then raise exception 'Only the business owner can manage staff'; end if;
  update public.business_memberships set status = 'disabled'
  where business_id = p_business_id and user_id = p_user_id and role <> 'owner'
  returning * into v_membership;
  if not found then raise exception 'Staff membership not found'; end if;
  return v_membership;
end;
$$;

create function public.disable_stall_staff(p_business_id uuid, p_stall_id uuid, p_user_id uuid)
returns public.stall_memberships language plpgsql security definer set search_path = '' as $$
declare v_membership public.stall_memberships;
begin
  if not (select private.is_business_owner(p_business_id)) then raise exception 'Only the business owner can manage staff'; end if;
  update public.stall_memberships set status = 'disabled'
  where business_id = p_business_id and stall_id = p_stall_id and user_id = p_user_id
  returning * into v_membership;
  if not found then raise exception 'Staff membership not found'; end if;
  return v_membership;
end;
$$;

revoke all on function public.get_staff_invitation(text) from public, anon;
revoke all on function public.list_business_staff(uuid) from public, anon;
revoke all on function public.revoke_staff_invitation(uuid, uuid) from public, anon;
revoke all on function public.disable_business_staff(uuid, uuid) from public, anon;
revoke all on function public.disable_stall_staff(uuid, uuid, uuid) from public, anon;
grant execute on function public.get_staff_invitation(text) to authenticated;
grant execute on function public.list_business_staff(uuid) to authenticated;
grant execute on function public.revoke_staff_invitation(uuid, uuid) to authenticated;
grant execute on function public.disable_business_staff(uuid, uuid) to authenticated;
grant execute on function public.disable_stall_staff(uuid, uuid, uuid) to authenticated;
