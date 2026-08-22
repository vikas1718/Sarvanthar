-- Business Profile fields and owner-only update RPC.

alter table public.businesses
  add column logo_url text,
  add column phone text,
  add column email extensions.citext,
  add column address text,
  add column currency text default 'INR',
  add column tax_percentage numeric(5, 2);

alter table public.businesses
  add constraint businesses_currency_format_check
    check (
      currency is null
      or currency ~ '^[A-Z]{3}$'
    ),
  add constraint businesses_tax_percentage_check
    check (
      tax_percentage is null
      or tax_percentage between 0 and 100
    );

create function public.update_business_profile(
  p_business_id uuid,
  p_logo_url text,
  p_phone text,
  p_email extensions.citext,
  p_address text,
  p_currency text,
  p_tax_percentage numeric
)
returns public.businesses
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business public.businesses;
  v_currency text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if not (select private.is_business_owner(p_business_id)) then
    raise exception 'Only the business owner can update the business profile';
  end if;

  v_currency := nullif(upper(trim(p_currency)), '');

  if v_currency is not null and v_currency !~ '^[A-Z]{3}$' then
    raise exception 'Currency must be a three-letter code';
  end if;

  if p_tax_percentage is not null
     and (p_tax_percentage < 0 or p_tax_percentage > 100) then
    raise exception 'Tax percentage must be between 0 and 100';
  end if;

  update public.businesses
  set
    logo_url = nullif(trim(p_logo_url), ''),
    phone = nullif(trim(p_phone), ''),
    email = nullif(trim(p_email::text), '')::extensions.citext,
    address = nullif(trim(p_address), ''),
    currency = v_currency,
    tax_percentage = p_tax_percentage
  where id = p_business_id
  returning * into v_business;

  if not found then
    raise exception 'Business not found';
  end if;

  return v_business;
end;
$$;

-- New functions receive PUBLIC execution by default, so revoke it explicitly.
revoke all on function public.update_business_profile(
  uuid,
  text,
  text,
  extensions.citext,
  text,
  text,
  numeric
) from public, anon;

grant execute on function public.update_business_profile(
  uuid,
  text,
  text,
  extensions.citext,
  text,
  text,
  numeric
) to authenticated;
