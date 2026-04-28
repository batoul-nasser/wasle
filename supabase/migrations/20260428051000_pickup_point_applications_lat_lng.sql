alter table if exists public.pickup_point_applications
  add column if not exists lat double precision,
  add column if not exists lng double precision;

comment on column public.pickup_point_applications.lat is
  'Pickup point location latitude captured during signup.';
comment on column public.pickup_point_applications.lng is
  'Pickup point location longitude captured during signup.';
