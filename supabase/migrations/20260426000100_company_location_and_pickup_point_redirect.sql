alter table public.delivery_companies
  add column if not exists location text,
  add column if not exists address_text text,
  add column if not exists lat double precision,
  add column if not exists lng double precision;

update public.delivery_companies
set address_text = coalesce(address_text, location)
where address_text is null
  and location is not null;

update public.delivery_companies
set location = coalesce(location, address_text)
where location is null
  and address_text is not null;

alter table public.pickup_points
  add column if not exists company_id uuid references public.delivery_companies(id);

create index if not exists pickup_points_company_active_idx
  on public.pickup_points(company_id, is_active);

alter type public.order_status
  add value if not exists 'pending_pickup_point_delivery';
