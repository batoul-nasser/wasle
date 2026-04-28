-- Ensure Option 2 redirect status exists before any policy checks.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_enum e on e.enumtypid = t.oid
    where t.typnamespace = 'public'::regnamespace
      and t.typname = 'order_status'
      and e.enumlabel = 'pending_pickup_point_delivery'
  ) then
    alter type public.order_status add value 'pending_pickup_point_delivery';
  end if;
end
$$;

alter table public.orders enable row level security;
alter table public.order_events enable row level security;

-- 1) Recreate driver order-update policy to allow Option 2 redirect transition.
drop policy if exists driver_update_assigned_orders on public.orders;

create policy driver_update_assigned_orders
on public.orders
for update
to authenticated
using (
  exists (
    select 1
    from public.assignments a
    join public.drivers d on d.id = a.driver_id
    where a.order_id = orders.id
      and d.profile_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.assignments a
    join public.drivers d on d.id = a.driver_id
    where a.order_id = orders.id
      and d.profile_id = auth.uid()
  )
  and status::text = any (
    array[
      'pending_driver_receipt',
      'driver_received_order',
      'picked_up',
      'in_transit',
      'delivered',
      'failed',
      'rescheduled',
      'pending_pickup_point_delivery',
      'dropped_at_pickup_point',
      'returning_to_store',
      'returned_to_store'
    ]
  )
);

-- 2) Allow assigned drivers to read order timeline events.
drop policy if exists driver_select_order_events on public.order_events;
create policy driver_select_order_events
on public.order_events
for select
to authenticated
using (
  exists (
    select 1
    from public.assignments a
    join public.drivers d on d.id = a.driver_id
    where a.order_id = order_events.order_id
      and d.profile_id = auth.uid()
  )
);

-- 3) Allow assigned drivers to insert timeline events.
drop policy if exists driver_insert_order_events on public.order_events;
create policy driver_insert_order_events
on public.order_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.assignments a
    join public.drivers d on d.id = a.driver_id
    where a.order_id = order_events.order_id
      and d.profile_id = auth.uid()
  )
);
