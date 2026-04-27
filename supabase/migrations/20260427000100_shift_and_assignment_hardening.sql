alter table public.delivery_companies
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists exact_address text,
  add column if not exists address_text text,
  add column if not exists city text,
  add column if not exists area text,
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

update public.delivery_companies
set
  exact_address = coalesce(exact_address, address_text, location),
  address_text = coalesce(address_text, exact_address, location),
  latitude = coalesce(latitude, lat),
  longitude = coalesce(longitude, lng),
  lat = coalesce(lat, latitude),
  lng = coalesce(lng, longitude);

alter table public.drivers
  add column if not exists is_available boolean not null default false,
  add column if not exists is_active_shift boolean not null default false,
  add column if not exists shift_started_at timestamp with time zone,
  add column if not exists shift_ended_at timestamp with time zone,
  add column if not exists current_location_lat double precision,
  add column if not exists current_location_lng double precision,
  add column if not exists last_location_ping_at timestamp with time zone,
  add column if not exists city text,
  add column if not exists service_area text,
  add column if not exists current_load_weight double precision not null default 0,
  add column if not exists current_load_volume double precision not null default 0,
  add column if not exists current_load_item_count integer not null default 0,
  add column if not exists updated_at timestamp with time zone not null default now();

update public.drivers
set
  availability_status = 'unavailable',
  is_available = false,
  is_active_shift = false
where coalesce(is_active_shift, false) = false;

update public.drivers d
set
  current_location_lat = coalesce(d.current_location_lat, dl.lat),
  current_location_lng = coalesce(d.current_location_lng, dl.lng),
  last_location_ping_at = coalesce(d.last_location_ping_at, dl.updated_at)
from public.driver_locations dl
where dl.driver_id = d.id;

alter table public.driver_locations
  add column if not exists city text,
  add column if not exists address_text text,
  add column if not exists heading double precision,
  add column if not exists speed double precision,
  add column if not exists last_location_ping_at timestamp with time zone;

update public.driver_locations
set last_location_ping_at = coalesce(last_location_ping_at, updated_at);

alter table public.orders
  add column if not exists company_id uuid references public.delivery_companies(id),
  add column if not exists pickup_source_type text,
  add column if not exists destination_pickup_point_id uuid references public.pickup_points(id),
  add column if not exists pickup_location_lat double precision,
  add column if not exists pickup_location_lng double precision,
  add column if not exists dropoff_location_lat double precision,
  add column if not exists dropoff_location_lng double precision,
  add column if not exists customer_lat double precision,
  add column if not exists customer_lng double precision,
  add column if not exists parcel_description text,
  add column if not exists assignment_status text not null default 'pending_assignment',
  add column if not exists assigned_driver_id uuid references public.drivers(id),
  add column if not exists assignment_failure_reason text;

update public.orders
set company_id = coalesce(company_id, delivery_company_id)
where company_id is null
  and delivery_company_id is not null;

update public.orders
set assignment_status = case
  when assigned_driver_id is not null or status::text = 'assigned' then 'assigned'
  when assignment_status is null then 'pending_assignment'
  else assignment_status
end;

alter table public.routing_cache
  add column if not exists expires_at timestamp with time zone;

update public.routing_cache
set expires_at = coalesce(expires_at, created_at + interval '30 minutes');

create index if not exists drivers_assignment_candidate_idx
  on public.drivers (
    company_id,
    verification_status,
    availability_status,
    is_active_shift,
    last_location_ping_at
  );

create index if not exists orders_assignment_status_idx
  on public.orders(delivery_company_id, assignment_status);

create index if not exists orders_company_id_idx
  on public.orders(company_id);

create index if not exists driver_locations_last_ping_idx
  on public.driver_locations(last_location_ping_at desc);

create index if not exists routing_cache_expires_at_idx
  on public.routing_cache(expires_at);
