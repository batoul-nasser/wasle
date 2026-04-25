-- Align driver onboarding and automated assignment schema with strict vehicle
-- selection, stored capacities, and driver-company request flow.

alter table public.drivers
  alter column company_id drop not null;

alter table public.drivers
  add column if not exists profile_id uuid,
  add column if not exists vehicle_type text,
  add column if not exists capacity_weight double precision,
  add column if not exists capacity_volume double precision,
  add column if not exists capacity_item_count integer;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.drivers'::regclass
      and conname = 'drivers_profile_id_fkey'
  ) then
    alter table public.drivers
      add constraint drivers_profile_id_fkey
      foreign key (profile_id)
      references public.profiles(id)
      not valid;
  end if;
end
$$;

update public.drivers
set vehicle_type = case lower(coalesce(vehicle_type, 'motorcycle'))
  when 'motorcycle' then 'motorcycle'
  when 'car' then 'car'
  when 'van' then 'van'
  else 'motorcycle'
end
where vehicle_type is null
   or lower(vehicle_type) not in ('motorcycle', 'car', 'van')
   or vehicle_type <> lower(vehicle_type);

update public.drivers
set
  capacity_weight = case lower(coalesce(vehicle_type, 'motorcycle'))
    when 'car' then 60
    when 'van' then 300
    else 15
  end,
  capacity_volume = case lower(coalesce(vehicle_type, 'motorcycle'))
    when 'car' then 200000
    when 'van' then 1000000
    else 40000
  end,
  capacity_item_count = case lower(coalesce(vehicle_type, 'motorcycle'))
    when 'car' then 20
    when 'van' then 80
    else 5
  end
where capacity_weight is null
   or capacity_volume is null
   or capacity_item_count is null
   or capacity_weight <= 0
   or capacity_volume <= 0
   or capacity_item_count <= 0;

alter table public.drivers
  alter column vehicle_type set default 'motorcycle',
  alter column capacity_weight set default 15,
  alter column capacity_volume set default 40000,
  alter column capacity_item_count set default 5;

alter table public.drivers
  alter column vehicle_type set not null,
  alter column capacity_weight set not null,
  alter column capacity_volume set not null,
  alter column capacity_item_count set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.drivers'::regclass
      and conname = 'drivers_vehicle_type_check'
  ) then
    alter table public.drivers
      add constraint drivers_vehicle_type_check
      check (vehicle_type in ('motorcycle', 'car', 'van'))
      not valid;
  end if;
end
$$;

alter table public.drivers
  validate constraint drivers_vehicle_type_check;

do $$
begin
  if exists (
    select 1
    from public.drivers
    where profile_id is not null
    group by profile_id
    having count(*) > 1
  ) then
    raise exception
      'Cannot add unique index on public.drivers(profile_id): duplicate non-null profile_id values exist.';
  end if;
end
$$;

create unique index if not exists drivers_profile_id_key
  on public.drivers(profile_id);

create table if not exists public.driver_company_requests (
  id uuid primary key default gen_random_uuid(),
  driver_profile_id uuid not null,
  company_id uuid not null,
  request_status text not null default 'pending',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

alter table public.driver_company_requests
  add column if not exists driver_profile_id uuid,
  add column if not exists company_id uuid,
  add column if not exists request_status text,
  add column if not exists created_at timestamp with time zone not null default now(),
  add column if not exists updated_at timestamp with time zone not null default now();

update public.driver_company_requests
set request_status = case lower(coalesce(request_status, 'pending'))
  when 'approved' then 'approved'
  when 'rejected' then 'rejected'
  else 'pending'
end
where request_status is null
   or lower(request_status) not in ('pending', 'approved', 'rejected')
   or request_status <> lower(request_status);

alter table public.driver_company_requests
  alter column request_status set default 'pending',
  alter column request_status set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.driver_company_requests'::regclass
      and conname = 'driver_company_requests_driver_profile_id_fkey'
  ) then
    alter table public.driver_company_requests
      add constraint driver_company_requests_driver_profile_id_fkey
      foreign key (driver_profile_id)
      references public.profiles(id)
      not valid;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.driver_company_requests'::regclass
      and conname = 'driver_company_requests_company_id_fkey'
  ) then
    alter table public.driver_company_requests
      add constraint driver_company_requests_company_id_fkey
      foreign key (company_id)
      references public.delivery_companies(id)
      not valid;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.driver_company_requests'::regclass
      and conname = 'driver_company_requests_request_status_check'
  ) then
    alter table public.driver_company_requests
      add constraint driver_company_requests_request_status_check
      check (request_status in ('pending', 'approved', 'rejected'))
      not valid;
  end if;
end
$$;

alter table public.driver_company_requests
  validate constraint driver_company_requests_request_status_check;

create index if not exists driver_company_requests_company_id_idx
  on public.driver_company_requests(company_id);

create index if not exists driver_company_requests_driver_profile_id_idx
  on public.driver_company_requests(driver_profile_id);

create index if not exists driver_company_requests_request_status_idx
  on public.driver_company_requests(request_status);

grant select, insert, update, delete on table public.driver_company_requests to authenticated;
grant select, insert, update, delete on table public.driver_company_requests to service_role;
