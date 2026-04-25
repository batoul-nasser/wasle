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
    from auth.users
    where lower(coalesce(email, '')) = normalized_email
      and deleted_at is null
  );
end;
$$;

revoke all on function public.is_email_registered(text) from public;
grant execute on function public.is_email_registered(text) to anon;
grant execute on function public.is_email_registered(text) to authenticated;
grant execute on function public.is_email_registered(text) to service_role;
