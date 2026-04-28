alter table public.order_addresses enable row level security;

drop policy if exists order_addresses_select_by_order_access on public.order_addresses;
create policy order_addresses_select_by_order_access
on public.order_addresses
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_addresses.order_id
      and (
        o.merchant_id in (
          select mu.merchant_id
          from public.merchant_users mu
          where mu.profile_id = auth.uid()
        )
        or o.delivery_company_id in (
          select cu.company_id
          from public.company_users cu
          where cu.profile_id = auth.uid()
        )
        or o.company_id in (
          select cu.company_id
          from public.company_users cu
          where cu.profile_id = auth.uid()
        )
        or o.assigned_driver_id in (
          select d.id from public.drivers d
          where d.profile_id = auth.uid() or d.id = auth.uid()
        )
        or o.id in (
          select a.order_id
          from public.assignments a
          join public.drivers d on d.id = a.driver_id
          where d.profile_id = auth.uid() or d.id = auth.uid()
        )
        or o.pickup_point_id in (
          select ppo.pickup_point_id
          from public.pickup_point_operators ppo
          where ppo.profile_id = auth.uid()
        )
        or o.destination_pickup_point_id in (
          select ppo.pickup_point_id
          from public.pickup_point_operators ppo
          where ppo.profile_id = auth.uid()
        )
      )
  )
);

drop policy if exists order_addresses_upsert_by_order_access on public.order_addresses;
create policy order_addresses_upsert_by_order_access
on public.order_addresses
for all
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_addresses.order_id
      and (
        o.merchant_id in (
          select mu.merchant_id
          from public.merchant_users mu
          where mu.profile_id = auth.uid()
        )
        or o.delivery_company_id in (
          select cu.company_id
          from public.company_users cu
          where cu.profile_id = auth.uid()
        )
        or o.company_id in (
          select cu.company_id
          from public.company_users cu
          where cu.profile_id = auth.uid()
        )
        or o.assigned_driver_id in (
          select d.id from public.drivers d
          where d.profile_id = auth.uid() or d.id = auth.uid()
        )
        or o.id in (
          select a.order_id
          from public.assignments a
          join public.drivers d on d.id = a.driver_id
          where d.profile_id = auth.uid() or d.id = auth.uid()
        )
        or o.pickup_point_id in (
          select ppo.pickup_point_id
          from public.pickup_point_operators ppo
          where ppo.profile_id = auth.uid()
        )
        or o.destination_pickup_point_id in (
          select ppo.pickup_point_id
          from public.pickup_point_operators ppo
          where ppo.profile_id = auth.uid()
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_addresses.order_id
      and (
        o.merchant_id in (
          select mu.merchant_id
          from public.merchant_users mu
          where mu.profile_id = auth.uid()
        )
        or o.delivery_company_id in (
          select cu.company_id
          from public.company_users cu
          where cu.profile_id = auth.uid()
        )
        or o.company_id in (
          select cu.company_id
          from public.company_users cu
          where cu.profile_id = auth.uid()
        )
        or o.assigned_driver_id in (
          select d.id from public.drivers d
          where d.profile_id = auth.uid() or d.id = auth.uid()
        )
        or o.id in (
          select a.order_id
          from public.assignments a
          join public.drivers d on d.id = a.driver_id
          where d.profile_id = auth.uid() or d.id = auth.uid()
        )
        or o.pickup_point_id in (
          select ppo.pickup_point_id
          from public.pickup_point_operators ppo
          where ppo.profile_id = auth.uid()
        )
        or o.destination_pickup_point_id in (
          select ppo.pickup_point_id
          from public.pickup_point_operators ppo
          where ppo.profile_id = auth.uid()
        )
      )
  )
);
