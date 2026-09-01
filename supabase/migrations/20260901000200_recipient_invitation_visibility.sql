-- Allow an invited user to securely read only invitations addressed to their
-- authenticated email. This supports the in-app Accept / Reject notification.
drop policy if exists invitations_select_recipient on public.staff_invitations;
create policy invitations_select_recipient on public.staff_invitations
for select to authenticated
using (
  recipient_email is not null
  and lower(recipient_email::text) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
);

-- Recreate this lookup independently of any legacy invitation-code flow.
drop function if exists public.get_my_pending_email_invitation();
create function public.get_my_pending_email_invitation()
returns table (
  invitation_id uuid,
  business_name text,
  owner_name text,
  role public.app_role,
  stall_name text
)
language sql security definer set search_path = '' as $$
  select
    i.id,
    b.name,
    coalesce(nullif(p.full_name, ''), nullif(b.owner_name, ''), 'The restaurant owner'),
    i.role,
    s.name
  from public.staff_invitations i
  join public.businesses b on b.id = i.business_id
  left join public.profiles p on p.id = i.invited_by
  left join public.stalls s on s.id = i.stall_id
  where i.status = 'invited'
    and i.accepted_at is null
    and i.expires_at > now()
    and i.recipient_email is not null
    and lower(i.recipient_email::text) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  order by i.created_at desc
  limit 1;
$$;

revoke all on function public.get_my_pending_email_invitation() from public, anon;
grant execute on function public.get_my_pending_email_invitation() to authenticated;
