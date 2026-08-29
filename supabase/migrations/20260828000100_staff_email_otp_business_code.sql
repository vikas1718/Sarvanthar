-- Staff may redeem an email invitation only after Supabase has verified the
-- email by OTP and the submitted business code matches the invitation's
-- business. Roles and business IDs remain entirely server-side.

drop function if exists public.redeem_current_staff_invitation();

create function public.redeem_current_staff_invitation(p_business_code text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_invitation public.staff_invitations;
declare v_email text := (select auth.jwt() ->> 'email');
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  if v_email is null then raise exception 'Verified email is required'; end if;
  if nullif(trim(p_business_code), '') is null then
    raise exception 'Business code is required';
  end if;

  select i.* into v_invitation
  from public.staff_invitations i
  join public.businesses b on b.id = i.business_id
  where i.status = 'invited' and i.accepted_at is null and i.expires_at > now()
    and i.recipient_email is not null
    and lower(i.recipient_email::text) = lower(v_email)
    and upper(b.business_code) = upper(trim(p_business_code))
  order by i.created_at desc
  limit 1 for update of i;

  if not found then
    raise exception 'No active invitation matches this email and business code';
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

  update public.staff_invitations
  set status = 'disabled', accepted_at = now(), accepted_by = (select auth.uid())
  where id = v_invitation.id;
end;
$$;

revoke all on function public.redeem_current_staff_invitation(text) from public, anon;
grant execute on function public.redeem_current_staff_invitation(text) to authenticated;
