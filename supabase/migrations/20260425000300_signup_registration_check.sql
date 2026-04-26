create or replace function public.is_email_registered(lookup_email text)
returns boolean
language plpgsql
security definer
set search_path = auth, public
as $$
declare
  normalized_email text := lower(trim(coalesce(lookup_email, '')));
begin
  if normalized_email = '' then
    return false;
  end if;

  return exists (
    select 1
    from auth.users u
    where lower(coalesce(u.email, '')) = normalized_email
  ) or exists (
    select 1
    from public.profiles p
    join auth.users u
      on u.id = p.id
    where lower(coalesce(u.email, '')) = normalized_email
  );
end;
$$;

revoke all on function public.is_email_registered(text) from public;
grant execute on function public.is_email_registered(text) to anon;
grant execute on function public.is_email_registered(text) to authenticated;
grant execute on function public.is_email_registered(text) to service_role;
