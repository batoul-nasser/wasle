create table if not exists public.routing_cache (
  id uuid primary key default gen_random_uuid(),
  origin_lat numeric not null,
  origin_lng numeric not null,
  destination_lat numeric not null,
  destination_lng numeric not null,
  vehicle_type text not null,
  time_bucket text not null,
  duration_seconds integer not null,
  distance_meters integer not null,
  source text not null,
  created_at timestamp with time zone not null default now()
);

alter table public.routing_cache
  add column if not exists origin_lat numeric,
  add column if not exists origin_lng numeric,
  add column if not exists destination_lat numeric,
  add column if not exists destination_lng numeric,
  add column if not exists vehicle_type text,
  add column if not exists time_bucket text,
  add column if not exists duration_seconds integer,
  add column if not exists distance_meters integer,
  add column if not exists source text,
  add column if not exists created_at timestamp with time zone not null default now();

delete from public.routing_cache a
using public.routing_cache b
where a.id < b.id
  and a.origin_lat = b.origin_lat
  and a.origin_lng = b.origin_lng
  and a.destination_lat = b.destination_lat
  and a.destination_lng = b.destination_lng
  and a.vehicle_type = b.vehicle_type
  and a.time_bucket = b.time_bucket;

alter table public.routing_cache
  alter column origin_lat set not null,
  alter column origin_lng set not null,
  alter column destination_lat set not null,
  alter column destination_lng set not null,
  alter column vehicle_type set not null,
  alter column time_bucket set not null,
  alter column duration_seconds set not null,
  alter column distance_meters set not null,
  alter column source set not null,
  alter column created_at set default now(),
  alter column created_at set not null;

create unique index if not exists routing_cache_lookup_key
  on public.routing_cache (
    origin_lat,
    origin_lng,
    destination_lat,
    destination_lng,
    vehicle_type,
    time_bucket
  );

create index if not exists routing_cache_created_at_idx
  on public.routing_cache(created_at desc);

grant select, insert, update, delete on table public.routing_cache to service_role;

alter table public.routing_cache enable row level security;
