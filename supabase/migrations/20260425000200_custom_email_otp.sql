create table if not exists public.email_verification_codes (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  purpose text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.email_verification_codes
  add column if not exists email text,
  add column if not exists purpose text,
  add column if not exists code_hash text,
  add column if not exists expires_at timestamptz,
  add column if not exists used_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

update public.email_verification_codes
set email = lower(trim(email))
where email is not null
  and email <> lower(trim(email));

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.email_verification_codes'::regclass
      and conname = 'email_verification_codes_purpose_check'
  ) then
    alter table public.email_verification_codes
      add constraint email_verification_codes_purpose_check
      check (
        purpose in (
          'driver_signup',
          'company_signup',
          'customer_signup',
          'merchant_signup'
        )
      ) not valid;
  end if;
end
$$;

alter table public.email_verification_codes
  validate constraint email_verification_codes_purpose_check;

alter table public.email_verification_codes
  alter column email set not null,
  alter column purpose set not null,
  alter column code_hash set not null,
  alter column expires_at set not null,
  alter column created_at set not null;

create index if not exists email_verification_codes_lookup_idx
  on public.email_verification_codes(email, purpose, created_at desc);

create index if not exists email_verification_codes_active_idx
  on public.email_verification_codes(email, purpose, used_at, expires_at);

alter table public.email_verification_codes enable row level security;

revoke all on public.email_verification_codes from public;
revoke all on public.email_verification_codes from anon;
revoke all on public.email_verification_codes from authenticated;

grant select, insert, update, delete on public.email_verification_codes to service_role;
