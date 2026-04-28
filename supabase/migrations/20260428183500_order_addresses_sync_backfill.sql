insert into public.order_addresses (
  order_id,
  pickup_address_text,
  pickup_lat,
  pickup_lng,
  dropoff_address_text,
  dropoff_lat,
  dropoff_lng
)
select
  o.id as order_id,
  coalesce(
    oa.pickup_address_text,
    spp.address_text,
    mb.address_text,
    o.pickup_address_text
  ) as pickup_address_text,
  o.pickup_location_lat as pickup_lat,
  o.pickup_location_lng as pickup_lng,
  coalesce(
    case
      when o.status in ('pending_pickup_point_delivery', 'dropped_at_pickup_point') then dpp.address_text
      when o.dropoff_type = 'pickup_point_specific' then dpp.address_text
      else o.customer_address_text
    end,
    oa.dropoff_address_text,
    o.dropoff_address_text
  ) as dropoff_address_text,
  o.dropoff_location_lat as dropoff_lat,
  o.dropoff_location_lng as dropoff_lng
from public.orders o
left join public.order_addresses oa on oa.order_id = o.id
left join public.pickup_points spp on spp.id = o.pickup_point_id
left join public.pickup_points dpp on dpp.id = o.destination_pickup_point_id
left join public.merchant_branches mb on mb.id = o.branch_id
where
  o.pickup_location_lat is not null
  and o.pickup_location_lng is not null
  and o.dropoff_location_lat is not null
  and o.dropoff_location_lng is not null
on conflict (order_id) do update
set
  pickup_address_text = coalesce(excluded.pickup_address_text, public.order_addresses.pickup_address_text),
  pickup_lat = coalesce(excluded.pickup_lat, public.order_addresses.pickup_lat),
  pickup_lng = coalesce(excluded.pickup_lng, public.order_addresses.pickup_lng),
  dropoff_address_text = coalesce(excluded.dropoff_address_text, public.order_addresses.dropoff_address_text),
  dropoff_lat = coalesce(excluded.dropoff_lat, public.order_addresses.dropoff_lat),
  dropoff_lng = coalesce(excluded.dropoff_lng, public.order_addresses.dropoff_lng);
