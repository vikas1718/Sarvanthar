-- REVIEW ONLY: do not apply until explicitly approved.
-- Once approved, move this file to supabase/migrations/20260823000200_qr_token_resolve_messages.sql unchanged.
--
-- Corrective follow-up to 20260823000100_qr_tokens.sql. That migration stays as
-- applied; this one replaces public.resolve_qr_token only.
--
-- ============================================================================
-- WHAT CHANGES AND WHY
--
-- As applied, the token lookup filtered `status = 'active'`, so a token revoked by
-- regeneration fell into the not-found branch and reported 'QR code is not valid' --
-- the same message as a malformed or entirely fictional token. The intended
-- three-way split did not exist: the only real distinction was
-- active-token-with-dead-target vs. everything else.
--
-- After this migration the messages partition as intended:
--
--   'QR code is not valid'        -> malformed, null, or no such token ever existed
--   'QR code has been replaced'  -> token existed and was superseded by regeneration
--   'QR code is no longer active'-> token is live, but its business / stall / table
--                                   is archived or deactivated
--
-- Operationally this is the point of the change: "I printed this QR last month and
-- it stopped working" now reports something different from "someone typed the URL
-- wrong", so support can tell a reissued code from a bad one without database access.
--
-- ============================================================================
-- SECURITY NOTE -- this deliberately widens the oracle. Please read.
--
-- Before: a revoked token was byte-for-byte indistinguishable from a random one.
-- After:  'QR code has been replaced' confirms that the presented token genuinely
--         existed in this system at some point.
--
-- That is a real, if small, information disclosure, and it is the accepted tradeoff
-- for the debugging value above -- flagging it because 20260823000100 documented the
-- opposite property and a future reviewer should not be misled by that comment block.
--
-- Why it stays acceptable:
--   * A token is 128 bits of CSPRNG output. An attacker cannot reach this branch by
--     guessing, so in practice the message is only ever seen by someone holding a
--     real QR that was reissued -- a guest at the table, not an adversary.
--   * The branch still returns no data. It leaks one bit ("this existed"), not the
--     business, stall, table, or any identifier.
--   * The value of that bit to an attacker is close to nil: knowing a token was once
--     valid grants nothing, since the replacement token is independently random and
--     unrelated.
--
-- Unchanged by this migration: the anon execute grant, the argument type, the return
-- columns, and every fail-closed check on archived or deactivated targets.
-- ============================================================================

-- create or replace preserves existing privileges, so the anon grant from
-- 20260823000100 survives. Re-asserted at the bottom anyway, to keep the intended
-- end state readable in one place rather than implied across two migrations.
create or replace function public.resolve_qr_token(p_token text)
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

  -- No status filter: the row is needed in order to tell "never existed" apart from
  -- "existed and was replaced". token carries a unique index, so this is still a
  -- single index lookup.
  select * into v_token
  from public.qr_tokens
  where token = p_token;

  if not found then
    raise exception 'QR code is not valid';
  end if;

  -- Tested as <> 'active' rather than = 'revoked' so that any status added later
  -- fails closed instead of falling through to a successful resolve. If a third
  -- status ever appears, revisit this message rather than this comparison.
  if v_token.status <> 'active' then
    raise exception 'QR code has been replaced';
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

revoke all on function public.resolve_qr_token(text) from public;

-- >>> STILL THE ONE PUBLIC/ANON GRANT IN THIS PROJECT. Unchanged by this migration;
-- >>> re-asserted only because create or replace makes the grant easy to lose track of.
grant execute on function public.resolve_qr_token(text) to anon, authenticated;
