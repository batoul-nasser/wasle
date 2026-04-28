alter table public.pickup_points enable row level security;

drop policy if exists drivers_select_assigned_pickup_points on public.pickup_points;
create policy drivers_select_assigned_pickup_points
on public.pickup_points
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    left join public.assignments a on a.order_id = o.id
    left join public.drivers d1 on d1.id = a.driver_id
    left join public.drivers d2 on d2.id = o.assigned_driver_id
    where (o.pickup_point_id = pickup_points.id or o.destination_pickup_point_id = pickup_points.id)
      and (
        d1.profile_id = auth.uid()
        or d1.id = auth.uid()
        or d2.profile_id = auth.uid()
        or d2.id = auth.uid()
      )
  )
);
