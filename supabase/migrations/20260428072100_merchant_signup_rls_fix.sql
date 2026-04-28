alter table public.merchant_businesses enable row level security;
alter table public.merchant_users enable row level security;
alter table public.merchant_branches enable row level security;

drop policy if exists merchant_users_insert_own on public.merchant_users;
create policy merchant_users_insert_own
on public.merchant_users
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists merchant_users_select_own on public.merchant_users;
create policy merchant_users_select_own
on public.merchant_users
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists merchant_users_update_own on public.merchant_users;
create policy merchant_users_update_own
on public.merchant_users
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists merchant_branches_insert_own_merchant on public.merchant_branches;
create policy merchant_branches_insert_own_merchant
on public.merchant_branches
for insert
to authenticated
with check (
  exists (
    select 1
    from public.merchant_users mu
    where mu.merchant_id = merchant_branches.merchant_id
      and mu.profile_id = auth.uid()
  )
);

drop policy if exists merchant_branches_select_own_merchant on public.merchant_branches;
create policy merchant_branches_select_own_merchant
on public.merchant_branches
for select
to authenticated
using (
  exists (
    select 1
    from public.merchant_users mu
    where mu.merchant_id = merchant_branches.merchant_id
      and mu.profile_id = auth.uid()
  )
);

drop policy if exists merchant_branches_update_own_merchant on public.merchant_branches;
create policy merchant_branches_update_own_merchant
on public.merchant_branches
for update
to authenticated
using (
  exists (
    select 1
    from public.merchant_users mu
    where mu.merchant_id = merchant_branches.merchant_id
      and mu.profile_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.merchant_users mu
    where mu.merchant_id = merchant_branches.merchant_id
      and mu.profile_id = auth.uid()
  )
);

drop policy if exists merchant_businesses_select_own on public.merchant_businesses;
create policy merchant_businesses_select_own
on public.merchant_businesses
for select
to authenticated
using (
  exists (
    select 1
    from public.merchant_users mu
    where mu.merchant_id = merchant_businesses.id
      and mu.profile_id = auth.uid()
  )
);
