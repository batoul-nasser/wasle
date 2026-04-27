alter table public.drivers enable row level security;

drop policy if exists drivers_select_own_or_company on public.drivers;
create policy drivers_select_own_or_company
on public.drivers
for select
to authenticated
using (
  profile_id = auth.uid()
  or company_id = auth.uid()
  or exists (
    select 1
    from public.company_users cu
    where cu.profile_id = auth.uid()
      and cu.company_id = drivers.company_id
  )
  or exists (
    select 1
    from public.driver_company_requests dcr
    where dcr.driver_profile_id = coalesce(drivers.profile_id, drivers.id)
      and dcr.request_status in ('pending', 'approved')
      and (
        dcr.company_id = auth.uid()
        or exists (
          select 1
          from public.company_users cu2
          where cu2.profile_id = auth.uid()
            and cu2.company_id = dcr.company_id
        )
      )
  )
);
