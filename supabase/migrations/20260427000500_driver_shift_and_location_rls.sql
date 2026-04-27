alter table public.drivers enable row level security;

drop policy if exists drivers_self_update on public.drivers;
create policy drivers_self_update
on public.drivers
for update
to authenticated
using (profile_id = auth.uid() or id = auth.uid())
with check (profile_id = auth.uid() or id = auth.uid());

drop policy if exists drivers_self_select on public.drivers;
create policy drivers_self_select
on public.drivers
for select
to authenticated
using (profile_id = auth.uid() or id = auth.uid());

alter table public.driver_locations enable row level security;

drop policy if exists driver_locations_self_select on public.driver_locations;
create policy driver_locations_self_select
on public.driver_locations
for select
to authenticated
using (
  exists (
    select 1
    from public.drivers d
    where d.id = driver_locations.driver_id
      and (d.profile_id = auth.uid() or d.id = auth.uid())
  )
);

drop policy if exists driver_locations_self_insert on public.driver_locations;
create policy driver_locations_self_insert
on public.driver_locations
for insert
to authenticated
with check (
  exists (
    select 1
    from public.drivers d
    where d.id = driver_locations.driver_id
      and (d.profile_id = auth.uid() or d.id = auth.uid())
  )
);

drop policy if exists driver_locations_self_update on public.driver_locations;
create policy driver_locations_self_update
on public.driver_locations
for update
to authenticated
using (
  exists (
    select 1
    from public.drivers d
    where d.id = driver_locations.driver_id
      and (d.profile_id = auth.uid() or d.id = auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.drivers d
    where d.id = driver_locations.driver_id
      and (d.profile_id = auth.uid() or d.id = auth.uid())
  )
);
