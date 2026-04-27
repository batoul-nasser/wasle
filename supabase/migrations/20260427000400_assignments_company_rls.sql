alter table public.assignments enable row level security;

drop policy if exists assignments_company_select on public.assignments;
create policy assignments_company_select
on public.assignments
for select
to authenticated
using (
  company_id = auth.uid()
  or exists (
    select 1
    from public.company_users cu
    where cu.profile_id = auth.uid()
      and cu.company_id = assignments.company_id
  )
);

drop policy if exists assignments_company_insert on public.assignments;
create policy assignments_company_insert
on public.assignments
for insert
to authenticated
with check (
  company_id = auth.uid()
  or exists (
    select 1
    from public.company_users cu
    where cu.profile_id = auth.uid()
      and cu.company_id = assignments.company_id
  )
);

drop policy if exists assignments_company_update on public.assignments;
create policy assignments_company_update
on public.assignments
for update
to authenticated
using (
  company_id = auth.uid()
  or exists (
    select 1
    from public.company_users cu
    where cu.profile_id = auth.uid()
      and cu.company_id = assignments.company_id
  )
)
with check (
  company_id = auth.uid()
  or exists (
    select 1
    from public.company_users cu
    where cu.profile_id = auth.uid()
      and cu.company_id = assignments.company_id
  )
);

drop policy if exists assignments_company_delete on public.assignments;
create policy assignments_company_delete
on public.assignments
for delete
to authenticated
using (
  company_id = auth.uid()
  or exists (
    select 1
    from public.company_users cu
    where cu.profile_id = auth.uid()
      and cu.company_id = assignments.company_id
  )
);

alter table public.order_events enable row level security;

drop policy if exists order_events_company_insert on public.order_events;
create policy order_events_company_insert
on public.order_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.orders o
    where o.id = order_events.order_id
      and (
        o.delivery_company_id = auth.uid()
        or o.company_id = auth.uid()
        or exists (
          select 1
          from public.company_users cu
          where cu.profile_id = auth.uid()
            and cu.company_id in (o.delivery_company_id, o.company_id)
        )
      )
  )
);
