drop policy if exists "payments: pickup point" on public.payments;
drop policy if exists "payments: pickup point update" on public.payments;
drop policy if exists pickup_operator_mark_paid on public.payments;
drop policy if exists pickup_operator_read_payments on public.payments;
drop policy if exists pickup_operator_read_relevant_payments on public.payments;
drop policy if exists pickup_operator_update_destination_cash_payments on public.payments;

create policy pickup_operator_read_relevant_payments
on public.payments
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.pickup_point_operators ppo
      on (
        ppo.pickup_point_id = o.pickup_point_id
        or ppo.pickup_point_id = o.destination_pickup_point_id
      )
    where o.id = payments.order_id
      and ppo.profile_id = auth.uid()
  )
);

create policy pickup_operator_update_destination_cash_payments
on public.payments
for update
to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.pickup_point_operators ppo
      on ppo.pickup_point_id = o.destination_pickup_point_id
    where o.id = payments.order_id
      and ppo.profile_id = auth.uid()
      and payments.method::text = 'cash_at_pickup'
      and payments.status::text = 'pending'
      and (
        o.dropoff_type = 'pickup_point_specific'
        or o.status::text in (
          'pending_pickup_point_delivery',
          'dropped_at_pickup_point',
          'ready_for_customer_pickup'
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.orders o
    join public.pickup_point_operators ppo
      on ppo.pickup_point_id = o.destination_pickup_point_id
    where o.id = payments.order_id
      and ppo.profile_id = auth.uid()
      and payments.method::text = 'cash_at_pickup'
      and (
        o.dropoff_type = 'pickup_point_specific'
        or o.status::text in (
          'pending_pickup_point_delivery',
          'dropped_at_pickup_point',
          'ready_for_customer_pickup'
        )
      )
  )
);

drop policy if exists pickup_operator_insert_events on public.order_events;
drop policy if exists pickup_operator_select_events on public.order_events;

create policy pickup_operator_select_events
on public.order_events
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.pickup_point_operators ppo
      on (
        ppo.pickup_point_id = o.pickup_point_id
        or ppo.pickup_point_id = o.destination_pickup_point_id
      )
    where o.id = order_events.order_id
      and ppo.profile_id = auth.uid()
  )
);

create policy pickup_operator_insert_events
on public.order_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.orders o
    join public.pickup_point_operators ppo
      on (
        ppo.pickup_point_id = o.pickup_point_id
        or ppo.pickup_point_id = o.destination_pickup_point_id
      )
    where o.id = order_events.order_id
      and ppo.profile_id = auth.uid()
  )
);

drop policy if exists pickup_operator_read_agent_collections on public.agent_collections;
drop policy if exists pickup_operator_confirm_agent_collection on public.agent_collections;

create policy pickup_operator_read_agent_collections
on public.agent_collections
for select
to authenticated
using (
  exists (
    select 1
    from public.pickup_point_operators ppo
    where ppo.pickup_point_id = agent_collections.pickup_point_id
      and ppo.profile_id = auth.uid()
  )
);

create policy pickup_operator_confirm_agent_collection
on public.agent_collections
for update
to authenticated
using (
  exists (
    select 1
    from public.pickup_point_operators ppo
    where ppo.pickup_point_id = agent_collections.pickup_point_id
      and ppo.profile_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.pickup_point_operators ppo
    where ppo.pickup_point_id = agent_collections.pickup_point_id
      and ppo.profile_id = auth.uid()
  )
);
