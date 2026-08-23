-- REVIEW ONLY: do not apply until explicitly approved.
-- Once approved, move this file to supabase/migrations/20260823000100_qr_tokens.sql unchanged.
--
-- Opaque QR tokens for dine-in tables, food-court stalls, and restaurant counters.
--
-- ############################################################################
-- ## ATTENTION REVIEWER: this migration contains the FIRST anon-executable  ##
-- ## function in the project.                                               ##
-- ##                                                                        ##
-- ##   grant execute on function public.resolve_qr_token(text) to anon;     ##
-- ##                                                                        ##
-- ## Every other RPC in this schema is revoked from public/anon. This one    ##
-- ## must be callable without a session because an anonymous customer who    ##
-- ## scans a printed QR has no account yet and must be told where they are   ##
-- ## before anything else can happen. It is READ-ONLY, takes only a 128-bit  ##
-- ## random token, and returns nothing unless that exact token is active.    ##
-- ## See the notes above the function body for the full threat analysis.     ##
-- ############################################################################
--
-- WARNING FOR FUTURE MIGRATIONS: 20260822000400_menu_management.sql line 79 runs
--   revoke all on all functions in schema public from public, anon;
-- Any future migration repeating that blanket revoke will silently strip the anon
-- grant below and break every customer QR scan. Re-grant it explicitly if you do.

create type public.qr_token_scope as enum ('table', 'stall', 'business');
create type public.qr_token_status as enum ('active', 'revoked');

-- Tokens are stored in PLAINTEXT, deliberately unlike staff_invitations.token_hash.
--   1. An owner must be able to re-display and re-print an existing QR at any time,
--      which is impossible from a bcrypt hash.
--   2. Resolution happens on every customer scan; the invitation pattern's
--      crypt()-compare-every-row full scan does not survive that traffic.
-- A QR token is not a privilege credential. It grants no rights, identifies only a
-- physical location, and is printed on a table in public view. 128 bits of entropy
-- makes guessing infeasible; the unique index makes lookup a single index probe.
create table public.qr_tokens (
  id uuid primary key default extensions.gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  stall_id uuid,
  dining_table_id uuid references public.dining_tables(id) on delete cascade,
  scope public.qr_token_scope not null,
  token text not null unique check (token ~ '^[a-f0-9]{32}$'),
  status public.qr_token_status not null default 'active',
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  regenerated_at timestamptz,
  revoked_at timestamptz,
  replaced_by uuid references public.qr_tokens(id) on delete set null,
  -- stalls carries unique (id, business_id), so a real composite FK is available here.
  -- dining_tables does not, and altering it is out of scope, so the trigger below
  -- enforces the equivalent invariant for table-scoped tokens.
  foreign key (stall_id, business_id) references public.stalls(id, business_id) on delete cascade,
  constraint qr_tokens_scope_target_check check (
    (scope = 'table' and dining_table_id is not null and stall_id is null)
    or (scope = 'stall' and stall_id is not null and dining_table_id is null)
    or (scope = 'business' and stall_id is null and dining_table_id is null)
  ),
  constraint qr_tokens_revocation_check check (
    (status = 'active' and revoked_at is null)
    or (status = 'revoked' and revoked_at is not null)
  )
);

-- Exactly one active token per physical target. Revoked history rows are unconstrained,
-- so every QR ever printed stays on record with the token that was on it.
create unique index qr_tokens_active_table_key
  on public.qr_tokens (dining_table_id)
  where status = 'active' and scope = 'table';

create unique index qr_tokens_active_stall_key
  on public.qr_tokens (stall_id)
  where status = 'active' and scope = 'stall';

create unique index qr_tokens_active_business_key
  on public.qr_tokens (business_id)
  where status = 'active' and scope = 'business';

create index qr_tokens_business_scope_idx
  on public.qr_tokens (business_id, scope, status);

create function private.enforce_qr_token_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type public.business_type;
  v_table_business uuid;
begin
  select type into v_type from public.businesses where id = new.business_id;
  if not found then
    raise exception 'Business does not exist';
  end if;

  if new.scope = 'stall' and v_type is distinct from 'food_court' then
    raise exception 'Stall QR codes exist only under food court businesses';
  end if;

  if new.scope = 'table' then
    select business_id into v_table_business
    from public.dining_tables
    where id = new.dining_table_id and archived_at is null;

    if not found then
      raise exception 'Dining table not found or archived';
    end if;

    if v_table_business <> new.business_id then
      raise exception 'Dining table belongs to a different business';
    end if;
  end if;

  return new;
end;
$$;

-- Scoped to target columns only: revoking a token whose table was later archived
-- must still succeed, so plain status updates skip this validation.
create trigger qr_tokens_scope
before insert or update of business_id, stall_id, dining_table_id, scope
on public.qr_tokens
for each row execute procedure private.enforce_qr_token_scope();

create trigger qr_tokens_updated
before update on public.qr_tokens
for each row execute procedure private.set_updated_at();

-- No new permission surface: each scope delegates to the helper that already governs
-- the thing being represented, so QR rights track Table and Menu rights exactly.
--   table    -> private.can_manage_tables  (owner | business manager | any stall manager)
--   stall    -> private.can_manage_menu    (owner | that stall's manager)
--   business -> private.can_manage_menu    (owner | business manager)
create function private.can_manage_qr_tokens(
  p_business_id uuid,
  p_scope public.qr_token_scope,
  p_stall_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_scope
    when 'table' then private.can_manage_tables(p_business_id)
    when 'stall' then private.can_manage_menu(p_business_id, p_stall_id)
    when 'business' then private.can_manage_menu(p_business_id, null)
  end;
$$;

alter table public.qr_tokens enable row level security;

create policy qr_tokens_read
on public.qr_tokens
for select
to authenticated
using (private.can_manage_qr_tokens(business_id, scope, stall_id));

-- Supabase's `alter default privileges` grants new public-schema tables to anon, and
-- the blanket revoke in 20260818000200 predates this table, so revoke explicitly.
-- anon reaches token data only through resolve_qr_token below, never the table.
revoke all on public.qr_tokens from anon, public;
grant select on public.qr_tokens to authenticated;

create function public.generate_qr_token(
  p_business_id uuid,
  p_scope public.qr_token_scope,
  p_stall_id uuid default null,
  p_dining_table_id uuid default null
)
returns public.qr_tokens
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.qr_tokens;
  v_token public.qr_tokens;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if not private.can_manage_qr_tokens(p_business_id, p_scope, p_stall_id) then
    raise exception 'QR code management requires owner or manager access';
  end if;

  -- Lock the outgoing token so two managers pressing Regenerate at once serialise
  -- instead of racing the partial unique index.
  select * into v_existing
  from public.qr_tokens
  where business_id = p_business_id
    and scope = p_scope
    and status = 'active'
    and stall_id is not distinct from p_stall_id
    and dining_table_id is not distinct from p_dining_table_id
  for update;

  -- Revoke before inserting: the partial unique index permits only one active token
  -- per target, so the old row must step down first. The old token stops resolving
  -- the instant this commits.
  if v_existing.id is not null then
    update public.qr_tokens
       set status = 'revoked',
           revoked_at = now()
     where id = v_existing.id;
  end if;

  begin
    insert into public.qr_tokens (
      business_id, stall_id, dining_table_id, scope, token, created_by, regenerated_at
    )
    values (
      p_business_id,
      p_stall_id,
      p_dining_table_id,
      p_scope,
      encode(extensions.gen_random_bytes(16), 'hex'),
      (select auth.uid()),
      case when v_existing.id is null then null else now() end
    )
    returning * into v_token;
  exception when unique_violation then
    raise exception 'Another QR code for this target was just created. Reload and try again.';
  end;

  if v_existing.id is not null then
    update public.qr_tokens
       set replaced_by = v_token.id
     where id = v_existing.id;
  end if;

  return v_token;
end;
$$;

-- ============================================================================
-- PUBLIC / ANON RPC -- the one function in this project executable without a session.
--
-- Why it must be anon: a customer scanning a printed QR is anonymous by definition.
-- Before they can be shown a menu they have to be told which business, stall, and
-- table they are sitting at, and that answer is what turns an opaque token into a
-- location. There is no session to authenticate, and config.toml keeps
-- enable_anonymous_sign_ins = false, so a throwaway signup is not an option either.
--
-- Why it is safe to expose:
--   * Read-only. It writes nothing and reveals no membership, staff, or order data.
--   * The only input is a 128-bit random token. Not enumerable, and not derived from
--     any database id, so possession of one token tells you nothing about any other.
--   * Fails closed on format, on unknown/revoked tokens, and on archived or
--     deactivated businesses, stalls, and tables.
--   * Returns only what a customer holding that physical QR can already see: the
--     business name and branding, their stall, their table number.
--   * security definer, so anon still holds zero direct privileges on public.qr_tokens.
--
-- Residual exposure the reviewer should weigh:
--   * It hands back raw business/stall/table uuids, per the agreed design, because
--     the customer app needs them to fetch a menu. The QR *url* stays opaque; the
--     ids are disclosed only to whoever already holds a valid token.
--   * 'QR code is no longer active' distinguishes a real-but-disabled token from a
--     bogus one. That is intentional UX (tell the guest to ask staff for a new QR)
--     and costs nothing against an unguessable token.
--   * No rate limiting here. Consider a Supabase edge rate limit on this endpoint
--     before launch, as it is the only unauthenticated entry point in the system.
-- ============================================================================
create function public.resolve_qr_token(p_token text)
returns table (
  scope public.qr_token_scope,
  business_id uuid,
  business_name text,
  business_type public.business_type,
  currency text,
  tax_percentage numeric,
  logo_url text,
  stall_id uuid,
  stall_name text,
  dining_table_id uuid,
  table_number text,
  table_capacity integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token public.qr_tokens;
  v_business public.businesses;
  v_stall public.stalls;
  v_table public.dining_tables;
begin
  if p_token is null or p_token !~ '^[a-f0-9]{32}$' then
    raise exception 'QR code is not valid';
  end if;

  select * into v_token
  from public.qr_tokens
  where token = p_token and status = 'active';

  if not found then
    raise exception 'QR code is not valid';
  end if;

  select * into v_business
  from public.businesses
  where id = v_token.business_id and archived_at is null;

  if not found then
    raise exception 'QR code is no longer active';
  end if;

  if v_token.scope = 'stall' then
    select * into v_stall
    from public.stalls
    where id = v_token.stall_id and archived_at is null and status = 'active';

    if not found then
      raise exception 'QR code is no longer active';
    end if;
  end if;

  if v_token.scope = 'table' then
    select * into v_table
    from public.dining_tables
    where id = v_token.dining_table_id and archived_at is null and status = 'active';

    if not found then
      raise exception 'QR code is no longer active';
    end if;
  end if;

  return query
  select
    v_token.scope,
    v_business.id,
    v_business.name,
    v_business.type,
    v_business.currency,
    v_business.tax_percentage,
    v_business.logo_url,
    v_stall.id,
    v_stall.name,
    v_table.id,
    v_table.table_number,
    v_table.capacity;
end;
$$;

revoke all on function private.enforce_qr_token_scope() from public, anon;
revoke all on function private.can_manage_qr_tokens(uuid, public.qr_token_scope, uuid) from public, anon;
revoke all on function public.generate_qr_token(uuid, public.qr_token_scope, uuid, uuid) from public, anon;
revoke all on function public.resolve_qr_token(text) from public;

grant execute on function public.generate_qr_token(uuid, public.qr_token_scope, uuid, uuid) to authenticated;

-- The qr_tokens_read policy calls this helper, and RLS expressions are evaluated
-- with the querying role's privileges -- so authenticated needs execute or every
-- select on qr_tokens fails with "permission denied for function".
-- 20260822000700 can revoke private.can_manage_tables outright because it is only
-- ever called from inside security definer bodies; the dining_tables policy uses
-- private.has_business_access, which keeps its default privileges.
grant execute on function private.can_manage_qr_tokens(uuid, public.qr_token_scope, uuid) to authenticated;

-- >>> THE ONE PUBLIC/ANON GRANT IN THIS PROJECT. Reviewed above. <<<
grant execute on function public.resolve_qr_token(text) to anon, authenticated;
