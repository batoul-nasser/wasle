alter type public.order_status add value if not exists 'pending';
alter type public.order_status add value if not exists 'ready_for_driver_pickup';
alter type public.order_status add value if not exists 'pending_driver_receipt';
alter type public.order_status add value if not exists 'driver_received_order';
alter type public.order_status add value if not exists 'rescheduled';

alter table public.orders
  add column if not exists delivery_company_id uuid references public.delivery_companies(id),
  add column if not exists customer_name text,
  add column if not exists customer_phone text,
  add column if not exists customer_address_text text,
  add column if not exists dropoff_type text not null default 'home',
  add column if not exists item_count integer not null default 1,
  add column if not exists estimated_weight double precision not null default 1,
  add column if not exists estimated_volume double precision not null default 500,
  add column if not exists priority integer not null default 0,
  add column if not exists time_window_start timestamp with time zone,
  add column if not exists time_window_end timestamp with time zone;

alter table public.drivers
  add column if not exists profile_id uuid references public.profiles(id),
  add column if not exists vehicle_type text not null default 'motorcycle',
  add column if not exists capacity_weight double precision not null default 15,
  add column if not exists capacity_volume double precision not null default 40000,
  add column if not exists capacity_item_count integer not null default 5,
  add column if not exists availability_status text not null default 'available',
  add column if not exists shift_start_at timestamp with time zone,
  add column if not exists shift_end_at timestamp with time zone;

update public.drivers
set
  capacity_weight = 15,
  capacity_volume = 40000,
  capacity_item_count = 5
where lower(coalesce(vehicle_type, 'motorcycle')) = 'motorcycle';

update public.drivers
set
  capacity_weight = 60,
  capacity_volume = 200000,
  capacity_item_count = 20
where lower(vehicle_type) = 'car';

update public.drivers
set
  capacity_weight = 300,
  capacity_volume = 1000000,
  capacity_item_count = 80
where lower(vehicle_type) = 'van';

create table if not exists public.driver_routes (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id),
  company_id uuid not null references public.delivery_companies(id),
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create table if not exists public.driver_route_stops (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.driver_routes(id) on delete cascade,
  driver_id uuid not null references public.drivers(id),
  company_id uuid not null references public.delivery_companies(id),
  order_id uuid not null references public.orders(id),
  stop_type text not null,
  sequence_index integer not null,
  location_name text not null,
  location_address text,
  lat double precision,
  lng double precision,
  service_seconds integer not null default 300,
  eta_at timestamp with time zone,
  earliest_arrival_at timestamp with time zone,
  latest_arrival_at timestamp with time zone,
  completed_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists orders_delivery_company_id_idx
  on public.orders(delivery_company_id);

create index if not exists drivers_company_availability_idx
  on public.drivers(company_id, verification_status, availability_status);

create index if not exists driver_routes_driver_status_idx
  on public.driver_routes(driver_id, status);

create index if not exists driver_route_stops_route_sequence_idx
  on public.driver_route_stops(route_id, sequence_index);

create index if not exists driver_route_stops_order_idx
  on public.driver_route_stops(order_id);

grant select, insert, update, delete on table public.driver_routes to authenticated;
grant select, insert, update, delete on table public.driver_route_stops to authenticated;
grant select, insert, update, delete on table public.driver_routes to service_role;
grant select, insert, update, delete on table public.driver_route_stops to service_role;
