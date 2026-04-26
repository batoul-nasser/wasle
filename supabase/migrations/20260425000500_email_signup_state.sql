create or replace function public.get_email_signup_state(lookup_email text)
returns text
language plpgsql
security definer
set search_path = auth, public
as $$
declare
  normalized_email text := lower(trim(coalesce(lookup_email, '')));
begin
  if normalized_email = '' then
    return 'available';
  end if;

  if exists (
    select 1
    from auth.users u
    where lower(coalesce(u.email, '')) = normalized_email
      and u.email_confirmed_at is not null
  ) then
    return 'confirmed';
  end if;

  if exists (
    select 1
    from auth.users u
    where lower(coalesce(u.email, '')) = normalized_email
  ) then
    return 'pending';
  end if;

  return 'available';
end;
$$;

revoke all on function public.get_email_signup_state(text) from public;
grant execute on function public.get_email_signup_state(text) to anon;
grant execute on function public.get_email_signup_state(text) to authenticated;
grant execute on function public.get_email_signup_state(text) to service_role;

create or replace function public.is_email_registered(lookup_email text)
returns boolean
language plpgsql
security definer
set search_path = auth, public
as $$
begin
  return public.get_email_signup_state(lookup_email) = 'confirmed';
end;
$$;

revoke all on function public.is_email_registered(text) from public;
grant execute on function public.is_email_registered(text) to anon;
grant execute on function public.is_email_registered(text) to authenticated;
grant execute on function public.is_email_registered(text) to service_role;
