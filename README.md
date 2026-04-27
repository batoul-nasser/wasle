# Wasle Delivery Assignment System

Wasle is a Flutter and Supabase delivery platform for merchants, delivery
companies, drivers, pickup points, and customers. The current assignment model
is built for a multi-company fleet: every order is assigned inside its delivery
company only, and the normal merchant flow runs automated driver assignment
instead of asking the merchant to choose a driver.

## Driver Lifecycle

Drivers sign up with full name, phone, email/auth details, city or service area,
selected delivery company, and a mandatory vehicle type. Supported vehicle
types are `motorcycle`, `car`, and `van`; the app derives capacity values from
that choice and stores weight, volume, and item-count capacity on the driver.

New drivers start with `verification_status = pending` through a
`driver_company_requests` row. The company approves or rejects the request. A
driver linked to an approved company is not shown the request-company flow again.
Rejected drivers are routed to the rejected status screen.

## Company Signup

Delivery company signup collects the company name, admin name, phone, email,
exact address, city, area, latitude, and longitude. The exact coordinates are
stored on `delivery_companies` and can be used as the company hub when no
dedicated hub record exists.

## Shift And Location Behavior

Drivers are not assignment candidates just because they are logged in. An
approved driver must press `Available / Start Shift`.

Starting a shift:

- starts location permission/location service checks
- sends an immediate location ping
- sets `availability_status = available`
- sets `is_available = true`
- sets `is_active_shift = true`
- stores `shift_started_at`

Ending a shift:

- stops the periodic location timer
- sets `availability_status = unavailable`
- sets `is_available = false`
- sets `is_active_shift = false`
- stores `shift_ended_at`

There is no separate send-location button in the active driver flow. Location
pings run only while the driver is available and on an active shift. Pings run
every 60 seconds and avoid coordinate rewrites when movement is below the
configured threshold, while still refreshing the ping timestamp.

## Automated Assignment Flow

When a merchant creates an order, the app saves assignment-critical fields and
immediately calls `OrderAssignmentService.autoAssignOrder`.

The assignment service:

1. Loads the order, company, pickup, dropoff, demand, time window, and priority.
2. Filters drivers by same `company_id`, approval, availability, active shift,
   recent location ping, and vehicle capacity.
3. Builds the driver's current route from persisted route stops and active
   assignments.
4. Simulates insertion of pickup and dropoff stops while preserving pickup
   before dropoff.
5. Scores feasible insertions using travel time, service time, lateness
   penalty, priority bonus, and workload-balance penalty.
6. Assigns the order to the lowest-cost feasible driver.
7. Updates the assignment, order assignment status, and driver route stops.

The hard same-company rule is enforced in candidate queries, automatic
assignment, manual fallback assignment, and company order loading.

## Capacity, Service Time, And Priority

Orders must include item count, estimated weight, and estimated volume. Merchant
order creation validates these fields because capacity checks depend on them.

Default service-time modeling:

- pickup stop: 5 minutes
- home delivery dropoff: 10 minutes
- pickup-point dropoff: 4 minutes

Home delivery receives a higher base priority than pickup-point delivery, but
priority only affects scoring after feasibility checks pass.

## Google Maps And Cache Strategy

Route scoring uses the `route-estimate` Supabase Edge Function. The function
rounds coordinates, groups requests into 15-minute time buckets, checks
`routing_cache`, calls Google Distance Matrix only on cache miss, and stores a
30-minute cache expiry.

Driver GPS pings never call Google Maps. They only keep driver state fresh for
later assignment scoring.

## Manual Fallback

Manual assignment is a fallback path for delivery companies/admins. Orders that
automation cannot assign are marked with `assignment_status =
assignment_failed` and an `assignment_failure_reason`. Company fallback screens
show these orders for manual assignment, while still restricting the selectable
drivers to the same company and approved driver records.

## Database Fields Added

Main migration: `supabase/migrations/20260427000100_shift_and_assignment_hardening.sql`

Key additions include:

- `drivers`: `is_available`, `is_active_shift`, `shift_started_at`,
  `shift_ended_at`, `current_location_lat`, `current_location_lng`,
  `last_location_ping_at`, `current_load_weight`, `current_load_volume`,
  `current_load_item_count`, `city`, `service_area`
- `driver_locations`: `city`, `address_text`, `heading`, `speed`,
  `last_location_ping_at`
- `delivery_companies`: `phone`, `email`, `exact_address`, `city`, `area`,
  `lat`, `lng`, `latitude`, `longitude`
- `orders`: `company_id`, `pickup_source_type`,
  `destination_pickup_point_id`, pickup/dropoff coordinates,
  `assignment_status`, `assigned_driver_id`, `assignment_failure_reason`
- `routing_cache`: `expires_at`

## Testing Checklist

- Driver signs up, selects a company, selects vehicle type, and capacity is
  stored automatically.
- Driver appears as pending approval for the selected company.
- Company approves the driver.
- Approved driver sees company info and no request-company action.
- Driver starts shift; location tracking starts and driver becomes assignable.
- Driver ends shift; location tracking stops and driver is removed from
  assignment candidates.
- Merchant creates an order with pickup/dropoff coordinates, item count, weight,
  volume, and company.
- Automatic assignment ignores unavailable, pending, rejected, stale-location,
  inactive-shift, over-capacity, and other-company drivers.
- If no nearby driver is feasible, assignment still evaluates all feasible
  same-company active drivers.
- If no feasible driver exists, the order gets `assignment_failed` and a clear
  reason for manual fallback.
- Repeated route estimates use `routing_cache`; GPS pings do not call Google
  Maps.

## Edge Cases

- Missing location permission prevents shift start.
- Missing order demand or coordinates fails automation and records a fallback
  reason.
- Stale driver location pings exclude the driver from automation.
- Manual fallback cannot assign a driver from another company.
- Capacity is checked across weight, volume, and item count.
