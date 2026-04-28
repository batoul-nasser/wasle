-- Backfill legacy missing structured coordinates without overwriting existing values.

update public.orders o
set
  pickup_location_lat = pp.lat,
  pickup_location_lng = pp.lng
from public.pickup_points pp
where o.pickup_source_type = 'pickup_point'
  and o.pickup_point_id = pp.id
  and (o.pickup_location_lat is null or o.pickup_location_lng is null)
  and pp.lat is not null
  and pp.lng is not null;

update public.orders o
set
  pickup_location_lat = mb.lat,
  pickup_location_lng = mb.lng
from public.merchant_branches mb
where o.pickup_source_type = 'store'
  and o.branch_id = mb.id
  and (o.pickup_location_lat is null or o.pickup_location_lng is null)
  and mb.lat is not null
  and mb.lng is not null;

update public.orders
set
  dropoff_location_lat = customer_lat,
  dropoff_location_lng = customer_lng
where dropoff_type = 'home'
  and (dropoff_location_lat is null or dropoff_location_lng is null)
  and customer_lat is not null
  and customer_lng is not null;

update public.orders o
set
  dropoff_location_lat = pp.lat,
  dropoff_location_lng = pp.lng
from public.pickup_points pp
where o.dropoff_type = 'pickup_point_specific'
  and o.destination_pickup_point_id = pp.id
  and (o.dropoff_location_lat is null or o.dropoff_location_lng is null)
  and pp.lat is not null
  and pp.lng is not null;
