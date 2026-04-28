drop policy if exists driver_update_assigned_orders on public.orders;

create policy driver_update_assigned_orders
on public.orders
for update
to authenticated
using (
  exists (
    select 1
    from public.assignments a
    left join public.drivers d on d.id = a.driver_id
    where a.order_id = orders.id
      and (
        a.driver_id::text = auth.uid()::text
        or d.profile_id::text = auth.uid()::text
        or d.id::text = auth.uid()::text
      )
  )
  or exists (
    select 1
    from public.drivers d
    where d.id = orders.assigned_driver_id
      and (
        d.profile_id::text = auth.uid()::text
        or d.id::text = auth.uid()::text
      )
  )
  or orders.assigned_driver_id::text = auth.uid()::text
)
with check (
  (
    exists (
      select 1
      from public.assignments a
      left join public.drivers d on d.id = a.driver_id
      where a.order_id = orders.id
        and (
          a.driver_id::text = auth.uid()::text
          or d.profile_id::text = auth.uid()::text
          or d.id::text = auth.uid()::text
        )
    )
    or exists (
      select 1
      from public.drivers d
      where d.id = orders.assigned_driver_id
        and (
          d.profile_id::text = auth.uid()::text
          or d.id::text = auth.uid()::text
        )
    )
    or orders.assigned_driver_id::text = auth.uid()::text
  )
  and (status::text = any (array[
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
  ]))
);

drop policy if exists driver_select_order_events on public.order_events;
create policy driver_select_order_events
on public.order_events
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    left join public.assignments a on a.order_id = o.id
    left join public.drivers d1 on d1.id = a.driver_id
    left join public.drivers d2 on d2.id = o.assigned_driver_id
    where o.id = order_events.order_id
      and (
        a.driver_id::text = auth.uid()::text
        or d1.profile_id::text = auth.uid()::text
        or d1.id::text = auth.uid()::text
        or d2.profile_id::text = auth.uid()::text
        or d2.id::text = auth.uid()::text
        or o.assigned_driver_id::text = auth.uid()::text
      )
  )
);

drop policy if exists driver_insert_order_events on public.order_events;
create policy driver_insert_order_events
on public.order_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.orders o
    left join public.assignments a on a.order_id = o.id
    left join public.drivers d1 on d1.id = a.driver_id
    left join public.drivers d2 on d2.id = o.assigned_driver_id
    where o.id = order_events.order_id
      and (
        a.driver_id::text = auth.uid()::text
        or d1.profile_id::text = auth.uid()::text
        or d1.id::text = auth.uid()::text
        or d2.profile_id::text = auth.uid()::text
        or d2.id::text = auth.uid()::text
        or o.assigned_driver_id::text = auth.uid()::text
      )
  )
);
