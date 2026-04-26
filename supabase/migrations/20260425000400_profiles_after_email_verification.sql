create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $function$
begin
  if new.email_confirmed_at is null then
    return new;
  end if;

  insert into public.profiles (id, role, full_name, status, created_at)
  values (
    new.id,
    'customer',
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    'active',
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$function$;

create or replace function public.handle_confirmed_user()
returns trigger
language plpgsql
security definer
as $function$
begin
  if old.email_confirmed_at is not null or new.email_confirmed_at is null then
    return new;
  end if;

  insert into public.profiles (id, role, full_name, status, created_at)
  values (
    new.id,
    'customer',
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    'active',
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$function$;

drop trigger if exists on_auth_user_confirmed on auth.users;

create trigger on_auth_user_confirmed
after update of email_confirmed_at on auth.users
for each row
execute function public.handle_confirmed_user();
