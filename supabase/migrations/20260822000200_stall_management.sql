-- Owner-managed stall editing, status changes, and soft deletion.

alter table public.stalls
  add column archived_at timestamptz;

create index stalls_business_archived_idx
  on public.stalls (business_id, archived_at, created_at);

create function public.update_stall(
  p_business_id uuid,
  p_stall_id uuid,
  p_name text,
  p_slug text default null
)
returns public.stalls
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stall public.stalls;
begin
  if not (select private.is_business_owner(p_business_id)) then
    raise exception 'Only the business owner can manage stalls';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'Stall name is required';
  end if;

  update public.stalls
  set
    name = trim(p_name),
    slug = nullif(trim(p_slug), '')
  where id = p_stall_id
    and business_id = p_business_id
    and archived_at is null
  returning * into v_stall;

  if not found then
    raise exception 'Stall not found or archived';
  end if;

  return v_stall;
end;
$$;

create function public.set_stall_status(
  p_business_id uuid,
  p_stall_id uuid,
  p_status text
)
returns public.stalls
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stall public.stalls;
begin
  if not (select private.is_business_owner(p_business_id)) then
    raise exception 'Only the business owner can manage stalls';
  end if;

  if p_status not in ('active', 'inactive') then
    raise exception 'Stall status must be active or inactive';
  end if;

  update public.stalls
  set status = p_status
  where id = p_stall_id
    and business_id = p_business_id
    and archived_at is null
  returning * into v_stall;

  if not found then
    raise exception 'Stall not found or archived';
  end if;

  return v_stall;
end;
$$;

create function public.archive_stall(
  p_business_id uuid,
  p_stall_id uuid
)
returns public.stalls
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stall public.stalls;
begin
  if not (select private.is_business_owner(p_business_id)) then
    raise exception 'Only the business owner can manage stalls';
  end if;

  update public.stalls
  set
    status = 'inactive',
    archived_at = now()
  where id = p_stall_id
    and business_id = p_business_id
    and archived_at is null
  returning * into v_stall;

  if not found then
    raise exception 'Stall not found or already archived';
  end if;

  update public.stall_memberships
  set status = 'disabled'
  where stall_id = p_stall_id
    and business_id = p_business_id
    and status <> 'disabled';

  update public.staff_invitations
  set status = 'disabled'
  where stall_id = p_stall_id
    and business_id = p_business_id
    and status = 'invited';

  return v_stall;
end;
$$;

revoke all on function public.update_stall(
  uuid, uuid, text, text
) from public, anon;

revoke all on function public.set_stall_status(
  uuid, uuid, text
) from public, anon;

revoke all on function public.archive_stall(
  uuid, uuid
) from public, anon;

grant execute on function public.update_stall(
  uuid, uuid, text, text
) to authenticated;

grant execute on function public.set_stall_status(
  uuid, uuid, text
) to authenticated;

grant execute on function public.archive_stall(
  uuid, uuid
) to authenticated;
