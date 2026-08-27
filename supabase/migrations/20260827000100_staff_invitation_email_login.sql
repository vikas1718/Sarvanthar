-- Email-based staff login: apply a pending invitation to the currently
-- authenticated user by matching their verified email address.
--
-- An owner invites a teammate by email; the app emails them a secure sign-in
-- link (Supabase magic link / OTP). When that teammate signs in, the client
-- calls this RPC, which grants the role the invitation carries -- without the
-- teammate needing to paste an invitation token.
--
-- Security: the caller is only ever granted an invitation addressed to their
-- own verified email (the login proves control of that inbox), so this exposes
-- nothing a token-based redemption did not already allow. It fails soft --
-- returning without error when no matching invitation exists -- so it is safe
-- to call on every sign-in.

create function public.redeem_current_staff_invitation()
returns void language plpgsql security definer set search_path = '' as $$
declare v_invitation public.staff_invitations;
declare v_email text := (select auth.jwt() ->> 'email');
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  if v_email is null then return; end if;
  select * into v_invitation from public.staff_invitations
  where status = 'invited' and accepted_at is null and expires_at > now()
    and recipient_email is not null
    and lower(recipient_email::text) = lower(v_email)
  order by created_at desc
  limit 1 for update;
  if not found then return; end if;
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

revoke all on function public.redeem_current_staff_invitation() from public, anon;
grant execute on function public.redeem_current_staff_invitation() to authenticated;
