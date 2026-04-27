-- Automation test pack for assignment / routing / fallback verification
--
-- Default live IDs below match the current shared testing DB:
--   delivery company: sari33
--   company_id      : 4f7f8b7d-753f-4038-98bb-bdc617452caf
--   merchant login  : ali.abouchakrai5@gmail.com
--   merchant_id     : 152a5607-dccb-4acd-82a0-e1b03f10b67e
--   real driver     : omarserhal8@gmail.com
--   driver profile  : fd964518-585e-40b1-9878-37e596039b96
--
-- What this script does:
-- 1) Removes previous AUTO-TST test rows
-- 2) Creates one test branch + one test pickup point
-- 3) Creates 3 approved drivers:
--      - 2 ready with fresh live locations
--      - 1 stale on purpose
-- 4) Creates 4 orders:
--      - 2 should auto-assign
--      - 1 should fail because it is overweight
--      - 1 should fail because coordinates are intentionally missing
--
-- How to use:
-- 1) Run this whole script in Supabase SQL Editor
-- 2) Open the delivery company "Manual Fallback Assign" screen
-- 3) The app backfill will auto-attempt these created orders
-- 4) Use the verification queries at the bottom

begin;

-- ---------------------------------------------------------------------------
-- Fixed IDs so the script is idempotent and easy to inspect
-- ---------------------------------------------------------------------------

-- Profiles
-- DRIVER 1 uses the real auth/profile account:
--   omarserhal8@gmail.com
--   profile_id = fd964518-585e-40b1-9878-37e596039b96
-- DRIVER 2 / 3 remain synthetic support drivers.

-- Company / merchant already exist in the shared DB.

-- Test branch and pickup point
--   branch:       71000000-0000-0000-0000-000000000001
--   pickup point: 72000000-0000-0000-0000-000000000001

-- Drivers
--   d1: fd964518-585e-40b1-9878-37e596039b96
--   d2: 73000000-0000-0000-0000-000000000002
--   d3: 73000000-0000-0000-0000-000000000003

-- Orders
--   HOME success:   74000000-0000-0000-0000-000000000001
--   PICKUP success: 74000000-0000-0000-0000-000000000002
--   HEAVY fail:     74000000-0000-0000-0000-000000000003
--   BROKEN fail:    74000000-0000-0000-0000-000000000004

-- ---------------------------------------------------------------------------
-- Cleanup previous AUTO-TST rows
-- ---------------------------------------------------------------------------

delete from public.order_events
where order_id in (
  '74000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000002',
  '74000000-0000-0000-0000-000000000003',
  '74000000-0000-0000-0000-000000000004'
);

delete from public.driver_route_stops
where order_id in (
  '74000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000002',
  '74000000-0000-0000-0000-000000000003',
  '74000000-0000-0000-0000-000000000004'
)
or driver_id in (
  'fd964518-585e-40b1-9878-37e596039b96',
  '73000000-0000-0000-0000-000000000002',
  '73000000-0000-0000-0000-000000000003'
);

delete from public.driver_routes
where driver_id in (
  'fd964518-585e-40b1-9878-37e596039b96',
  '73000000-0000-0000-0000-000000000002',
  '73000000-0000-0000-0000-000000000003'
);

delete from public.assignments
where order_id in (
  '74000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000002',
  '74000000-0000-0000-0000-000000000003',
  '74000000-0000-0000-0000-000000000004'
);

delete from public.order_addresses
where order_id in (
  '74000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000002',
  '74000000-0000-0000-0000-000000000003',
  '74000000-0000-0000-0000-000000000004'
);

delete from public.payments
where order_id in (
  '74000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000002',
  '74000000-0000-0000-0000-000000000003',
  '74000000-0000-0000-0000-000000000004'
);

delete from public.orders
where id in (
  '74000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000002',
  '74000000-0000-0000-0000-000000000003',
  '74000000-0000-0000-0000-000000000004'
)
or tracking_code like 'AUTO-TST-%';

delete from public.driver_locations
where driver_id in (
  'fd964518-585e-40b1-9878-37e596039b96',
  '73000000-0000-0000-0000-000000000002',
  '73000000-0000-0000-0000-000000000003'
);

delete from public.drivers
where id in (
  'fd964518-585e-40b1-9878-37e596039b96',
  '73000000-0000-0000-0000-000000000002',
  '73000000-0000-0000-0000-000000000003'
);

delete from public.profiles
where id in (
  '70000000-0000-0000-0000-000000000002',
  '70000000-0000-0000-0000-000000000003'
);

delete from public.pickup_points
where id = '72000000-0000-0000-0000-000000000001';

delete from public.merchant_branches
where id = '71000000-0000-0000-0000-000000000001';

-- ---------------------------------------------------------------------------
-- Test branch + pickup point
-- ---------------------------------------------------------------------------

insert into public.merchant_branches (
  id,
  merchant_id,
  name,
  address_text,
  lat,
  lng,
  is_active,
  created_at
) values (
  '71000000-0000-0000-0000-000000000001',
  '152a5607-dccb-4acd-82a0-e1b03f10b67e',
  'AUTO-TST Main Branch',
  'Hamra Street, Beirut',
  33.893800,
  35.501800,
  true,
  now()
)
on conflict (id) do update set
  merchant_id = excluded.merchant_id,
  name = excluded.name,
  address_text = excluded.address_text,
  lat = excluded.lat,
  lng = excluded.lng,
  is_active = excluded.is_active;

insert into public.pickup_points (
  id,
  merchant_id,
  branch_id,
  name,
  address_text,
  lat,
  lng,
  is_active,
  company_id,
  created_at
) values (
  '72000000-0000-0000-0000-000000000001',
  '152a5607-dccb-4acd-82a0-e1b03f10b67e',
  '71000000-0000-0000-0000-000000000001',
  'AUTO-TST Pickup Hub',
  'Hamra Pickup Hub, Beirut',
  33.893800,
  35.501800,
  true,
  '4f7f8b7d-753f-4038-98bb-bdc617452caf',
  now()
)
on conflict (id) do update set
  merchant_id = excluded.merchant_id,
  branch_id = excluded.branch_id,
  name = excluded.name,
  address_text = excluded.address_text,
  lat = excluded.lat,
  lng = excluded.lng,
  is_active = excluded.is_active,
  company_id = excluded.company_id;

-- ---------------------------------------------------------------------------
-- Driver profiles + drivers
-- ---------------------------------------------------------------------------

insert into public.profiles (id, role, full_name, phone, status, created_at)
values
  (
    'fd964518-585e-40b1-9878-37e596039b96',
    'driver',
    'Omar Serhal Driver',
    '+96170000111',
    'active',
    now()
  ),
  (
    '70000000-0000-0000-0000-000000000002',
    'driver',
    'AUTO-TST Driver Two',
    '+96170000222',
    'active',
    now()
  ),
  (
    '70000000-0000-0000-0000-000000000003',
    'driver',
    'AUTO-TST Driver Three',
    '+96170000333',
    'active',
    now()
  )
on conflict (id) do update set
  role = excluded.role,
  full_name = excluded.full_name,
  phone = excluded.phone,
  status = excluded.status;

insert into public.drivers (
  id,
  profile_id,
  company_id,
  verification_status,
  vehicle_type,
  capacity_weight,
  capacity_volume,
  capacity_item_count,
  availability_status,
  created_at
) values
  (
    'fd964518-585e-40b1-9878-37e596039b96',
    'fd964518-585e-40b1-9878-37e596039b96',
    '4f7f8b7d-753f-4038-98bb-bdc617452caf',
    'approved',
    'motorcycle',
    15,
    40000,
    5,
    'available',
    now()
  ),
  (
    '73000000-0000-0000-0000-000000000002',
    '70000000-0000-0000-0000-000000000002',
    '4f7f8b7d-753f-4038-98bb-bdc617452caf',
    'approved',
    'car',
    60,
    200000,
    20,
    'available',
    now()
  ),
  (
    '73000000-0000-0000-0000-000000000003',
    '70000000-0000-0000-0000-000000000003',
    '4f7f8b7d-753f-4038-98bb-bdc617452caf',
    'approved',
    'van',
    300,
    1000000,
    80,
    'available',
    now()
  )
on conflict (id) do update set
  profile_id = excluded.profile_id,
  company_id = excluded.company_id,
  verification_status = excluded.verification_status,
  vehicle_type = excluded.vehicle_type,
  capacity_weight = excluded.capacity_weight,
  capacity_volume = excluded.capacity_volume,
  capacity_item_count = excluded.capacity_item_count,
  availability_status = excluded.availability_status;

insert into public.driver_locations (
  id,
  driver_id,
  lat,
  lng,
  updated_at
) values
  (
    '73100000-0000-0000-0000-000000000001',
    'fd964518-585e-40b1-9878-37e596039b96',
    33.893950,
    35.501650,
    now()
  ),
  (
    '73100000-0000-0000-0000-000000000002',
    '73000000-0000-0000-0000-000000000002',
    33.892900,
    35.483700,
    now()
  ),
  (
    '73100000-0000-0000-0000-000000000003',
    '73000000-0000-0000-0000-000000000003',
    33.900100,
    35.510400,
    now() - interval '20 minutes'
  )
on conflict (driver_id) do update set
  lat = excluded.lat,
  lng = excluded.lng,
  updated_at = excluded.updated_at;

-- ---------------------------------------------------------------------------
-- Orders to test auto-assignment behavior
-- ---------------------------------------------------------------------------

insert into public.orders (
  id,
  merchant_id,
  branch_id,
  customer_profile_id,
  tracking_code,
  status,
  pickup_point_id,
  notes,
  created_at,
  updated_at,
  delivery_company_id,
  customer_name,
  customer_phone,
  customer_address_text,
  dropoff_type,
  item_count,
  estimated_weight,
  estimated_volume,
  priority
) values
  (
    '74000000-0000-0000-0000-000000000001',
    '152a5607-dccb-4acd-82a0-e1b03f10b67e',
    '71000000-0000-0000-0000-000000000001',
    null,
    'AUTO-TST-HOME-1',
    'created',
    null,
    'AUTO TEST home delivery expected to assign',
    now(),
    now(),
    '4f7f8b7d-753f-4038-98bb-bdc617452caf',
    'AUTO Home Customer',
    '+96171111111',
    'Verdun, Beirut',
    'home',
    1,
    2.0,
    12000,
    10
  ),
  (
    '74000000-0000-0000-0000-000000000002',
    '152a5607-dccb-4acd-82a0-e1b03f10b67e',
    '71000000-0000-0000-0000-000000000001',
    null,
    'AUTO-TST-PICKUP-1',
    'created',
    '72000000-0000-0000-0000-000000000001',
    'AUTO TEST pickup-point dropoff expected to assign',
    now(),
    now(),
    '4f7f8b7d-753f-4038-98bb-bdc617452caf',
    'AUTO Pickup Customer',
    '+96172222222',
    'Achrafieh, Beirut',
    'pickup_point',
    1,
    1.5,
    8000,
    5
  ),
  (
    '74000000-0000-0000-0000-000000000003',
    '152a5607-dccb-4acd-82a0-e1b03f10b67e',
    '71000000-0000-0000-0000-000000000001',
    null,
    'AUTO-TST-HEAVY-1',
    'created',
    null,
    'AUTO TEST overweight order expected to fail route capacity checks',
    now(),
    now(),
    '4f7f8b7d-753f-4038-98bb-bdc617452caf',
    'AUTO Heavy Customer',
    '+96173333333',
    'Jnah, Beirut',
    'home',
    12,
    500.0,
    1500000,
    15
  ),
  (
    '74000000-0000-0000-0000-000000000004',
    '152a5607-dccb-4acd-82a0-e1b03f10b67e',
    '71000000-0000-0000-0000-000000000001',
    null,
    'AUTO-TST-BROKEN-1',
    'created',
    null,
    'AUTO TEST broken order expected to fail because routing coordinates are missing',
    now(),
    now(),
    '4f7f8b7d-753f-4038-98bb-bdc617452caf',
    'AUTO Broken Customer',
    '+96174444444',
    'Unknown customer address',
    'home',
    1,
    2.0,
    10000,
    1
  )
on conflict (id) do update set
  merchant_id = excluded.merchant_id,
  branch_id = excluded.branch_id,
  tracking_code = excluded.tracking_code,
  status = excluded.status,
  pickup_point_id = excluded.pickup_point_id,
  notes = excluded.notes,
  updated_at = excluded.updated_at,
  delivery_company_id = excluded.delivery_company_id,
  customer_name = excluded.customer_name,
  customer_phone = excluded.customer_phone,
  customer_address_text = excluded.customer_address_text,
  dropoff_type = excluded.dropoff_type,
  item_count = excluded.item_count,
  estimated_weight = excluded.estimated_weight,
  estimated_volume = excluded.estimated_volume,
  priority = excluded.priority;

insert into public.order_addresses (
  id,
  order_id,
  pickup_address_text,
  pickup_lat,
  pickup_lng,
  dropoff_address_text,
  dropoff_lat,
  dropoff_lng,
  created_at
) values
  (
    '74000000-0000-0000-0000-000000000001',
    '74000000-0000-0000-0000-000000000001',
    'Hamra Street, Beirut',
    33.893800,
    35.501800,
    'Verdun, Beirut',
    33.885500,
    35.478600,
    now()
  ),
  (
    '74000000-0000-0000-0000-000000000002',
    '74000000-0000-0000-0000-000000000002',
    'Hamra Street, Beirut',
    33.893800,
    35.501800,
    'Achrafieh, Beirut',
    33.888100,
    35.520300,
    now()
  ),
  (
    '74000000-0000-0000-0000-000000000003',
    '74000000-0000-0000-0000-000000000003',
    'Hamra Street, Beirut',
    33.893800,
    35.501800,
    'Jnah, Beirut',
    33.874600,
    35.483000,
    now()
  )
on conflict (order_id) do update set
  id = excluded.id,
  pickup_address_text = excluded.pickup_address_text,
  pickup_lat = excluded.pickup_lat,
  pickup_lng = excluded.pickup_lng,
  dropoff_address_text = excluded.dropoff_address_text,
  dropoff_lat = excluded.dropoff_lat,
  dropoff_lng = excluded.dropoff_lng;

insert into public.order_events (
  id,
  order_id,
  event_type,
  note,
  created_at
) values
  (
    gen_random_uuid(),
    '74000000-0000-0000-0000-000000000001',
    'order_created',
    'AUTO TEST seed order created',
    now()
  ),
  (
    gen_random_uuid(),
    '74000000-0000-0000-0000-000000000002',
    'order_created',
    'AUTO TEST seed order created',
    now()
  ),
  (
    gen_random_uuid(),
    '74000000-0000-0000-0000-000000000003',
    'order_created',
    'AUTO TEST seed order created',
    now()
  ),
  (
    gen_random_uuid(),
    '74000000-0000-0000-0000-000000000004',
    'order_created',
    'AUTO TEST seed order created',
    now()
  );

commit;

-- ---------------------------------------------------------------------------
-- Verification queries
-- ---------------------------------------------------------------------------

-- 1) See the seeded drivers and whether they are ready
select
  d.id as driver_id,
  p.full_name,
  d.vehicle_type,
  d.availability_status,
  dl.lat,
  dl.lng,
  dl.updated_at
from public.drivers d
left join public.profiles p on p.id = d.profile_id
left join public.driver_locations dl on dl.driver_id = d.id
where d.id in (
  'fd964518-585e-40b1-9878-37e596039b96',
  '73000000-0000-0000-0000-000000000002',
  '73000000-0000-0000-0000-000000000003'
)
order by p.full_name;

-- 2) See the seeded orders before / after auto-attempt
select
  id,
  tracking_code,
  status,
  delivery_company_id,
  estimated_weight,
  estimated_volume,
  item_count
from public.orders
where tracking_code like 'AUTO-TST-%'
order by tracking_code;

-- 3) Check routing coordinates
select
  order_id,
  pickup_address_text,
  pickup_lat,
  pickup_lng,
  dropoff_address_text,
  dropoff_lat,
  dropoff_lng
from public.order_addresses
where order_id in (
  '74000000-0000-0000-0000-000000000001',
  '74000000-0000-0000-0000-000000000002',
  '74000000-0000-0000-0000-000000000003',
  '74000000-0000-0000-0000-000000000004'
)
order by order_id;

-- 4) Check assignment result
select
  a.order_id,
  o.tracking_code,
  a.driver_id,
  a.company_id,
  a.assigned_at,
  a.accepted_at,
  a.completed_at
from public.assignments a
join public.orders o on o.id = a.order_id
where o.tracking_code like 'AUTO-TST-%'
order by a.assigned_at desc;

-- 5) Check route stops written by the optimizer
select
  rs.driver_id,
  rs.order_id,
  o.tracking_code,
  rs.stop_type,
  rs.sequence_index,
  rs.location_name,
  rs.location_address,
  rs.eta_at
from public.driver_route_stops rs
join public.orders o on o.id = rs.order_id
where o.tracking_code like 'AUTO-TST-%'
order by rs.driver_id, rs.sequence_index;

-- 6) Check auto-assignment failure reasons
select
  oe.order_id,
  o.tracking_code,
  oe.event_type,
  oe.note,
  oe.metadata,
  oe.created_at
from public.order_events oe
join public.orders o on o.id = oe.order_id
where o.tracking_code like 'AUTO-TST-%'
order by oe.created_at desc;
