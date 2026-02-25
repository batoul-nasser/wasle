drop extension if exists "pg_net";

create type "public"."company_role" as enum ('owner', 'admin', 'dispatcher', 'staff');

create type "public"."company_status" as enum ('pending', 'approved', 'rejected');

create type "public"."driver_status" as enum ('pending', 'approved', 'rejected', 'suspended');

create type "public"."merchant_role" as enum ('owner', 'admin', 'staff');

create type "public"."order_event_type" as enum ('order_created', 'assigned_to_company', 'assigned_to_driver', 'picked_up', 'in_transit', 'delivered', 'delivery_failed', 'dropped_at_pickup_point', 'returning_to_store', 'returned_to_store', 'cancelled', 'note_added');

create type "public"."order_status" as enum ('created', 'assigned', 'picked_up', 'in_transit', 'delivered', 'failed', 'dropped_at_pickup_point', 'returning_to_store', 'returned_to_store', 'cancelled');

create type "public"."payment_method" as enum ('cod', 'card');

create type "public"."payment_status" as enum ('pending', 'paid', 'failed', 'refunded');

create type "public"."profile_status" as enum ('active', 'suspended', 'banned', 'deleted');

create type "public"."user_role" as enum ('customer', 'merchant', 'driver', 'company_admin', 'platform_admin');


  create table "public"."app_categories" (
    "id" uuid not null,
    "name" character varying not null,
    "slug" character varying not null,
    "parent_id" uuid,
    "icon_url" character varying,
    "sort_order" integer,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."assignments" (
    "id" uuid not null default gen_random_uuid(),
    "order_id" uuid not null,
    "company_id" uuid not null,
    "driver_id" uuid,
    "assigned_at" timestamp with time zone not null default now(),
    "accepted_at" timestamp with time zone,
    "completed_at" timestamp with time zone
      );



  create table "public"."company_users" (
    "id" uuid not null default gen_random_uuid(),
    "profile_id" uuid not null,
    "company_id" uuid not null,
    "role" public.company_role not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."customer_addresses" (
    "id" uuid not null default gen_random_uuid(),
    "customer_id" uuid not null,
    "label" character varying,
    "address_text" text not null,
    "lat" double precision,
    "lng" double precision,
    "is_default" boolean not null default false,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."customers" (
    "id" uuid not null,
    "loyalty_points" integer not null default 0,
    "marketing_opt_in" boolean not null default false,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."delivery_companies" (
    "id" uuid not null,
    "name" character varying not null,
    "verification_status" public.company_status not null default 'pending'::public.company_status,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."driver_locations" (
    "id" uuid not null default gen_random_uuid(),
    "driver_id" uuid not null,
    "lat" double precision not null,
    "lng" double precision not null,
    "updated_at" timestamp with time zone not null default now()
      );



  create table "public"."drivers" (
    "id" uuid not null,
    "company_id" uuid not null,
    "verification_status" public.driver_status not null default 'pending'::public.driver_status,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."item_tags" (
    "id" uuid not null default gen_random_uuid(),
    "item_id" uuid not null,
    "tag_id" uuid not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_branch_images" (
    "id" uuid not null default gen_random_uuid(),
    "branch_id" uuid not null,
    "image_url" character varying not null,
    "sort_order" integer,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_branches" (
    "id" uuid not null default gen_random_uuid(),
    "merchant_id" uuid not null,
    "created_by" uuid,
    "name" character varying not null,
    "address_text" text not null,
    "lat" double precision not null,
    "lng" double precision not null,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_business_images" (
    "id" uuid not null,
    "merchant_id" uuid not null,
    "image_url" character varying not null,
    "sort_order" integer,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_businesses" (
    "id" uuid not null default gen_random_uuid(),
    "name" character varying not null,
    "description" text,
    "phone" character varying,
    "logo_url" character varying,
    "cover_url" character varying,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_categories" (
    "id" uuid not null,
    "merchant_id" uuid not null,
    "category_id" uuid not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_item_images" (
    "id" uuid not null default gen_random_uuid(),
    "item_id" uuid not null,
    "image_url" character varying not null,
    "sort_order" integer,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_items" (
    "id" uuid not null,
    "merchant_id" uuid not null,
    "menu_category_id" uuid,
    "name" character varying not null,
    "description" text,
    "price" numeric(10,2) not null,
    "main_image_url" character varying,
    "is_available" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_menu_categories" (
    "id" uuid not null,
    "merchant_id" uuid not null,
    "name" character varying not null,
    "image_url" character varying,
    "sort_order" integer,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_tags" (
    "id" uuid not null default gen_random_uuid(),
    "merchant_id" uuid not null,
    "tag_id" uuid not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."merchant_users" (
    "id" uuid not null default gen_random_uuid(),
    "profile_id" uuid not null,
    "merchant_id" uuid not null,
    "role" public.merchant_role not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."order_addresses" (
    "id" uuid not null,
    "order_id" uuid not null,
    "pickup_address_text" text not null,
    "pickup_lat" double precision,
    "pickup_lng" double precision,
    "dropoff_address_text" text not null,
    "dropoff_lat" double precision,
    "dropoff_lng" double precision,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."order_events" (
    "id" uuid not null default gen_random_uuid(),
    "order_id" uuid not null,
    "event_type" public.order_event_type not null,
    "created_by" uuid,
    "note" text,
    "metadata" json,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."orders" (
    "id" uuid not null default gen_random_uuid(),
    "merchant_id" uuid not null,
    "branch_id" uuid,
    "customer_profile_id" uuid,
    "tracking_code" character varying not null,
    "status" public.order_status not null default 'created'::public.order_status,
    "pickup_point_id" uuid,
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone
      );



  create table "public"."payments" (
    "id" uuid not null default gen_random_uuid(),
    "order_id" uuid not null,
    "method" public.payment_method not null default 'cod'::public.payment_method,
    "status" public.payment_status not null default 'pending'::public.payment_status,
    "amount" numeric(10,2) not null,
    "transaction_ref" character varying,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone
      );



  create table "public"."pickup_points" (
    "id" uuid not null default gen_random_uuid(),
    "merchant_id" uuid,
    "branch_id" uuid,
    "created_by" uuid,
    "name" character varying not null,
    "address_text" text not null,
    "lat" double precision,
    "lng" double precision,
    "image_url" character varying,
    "opening_hours" text,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."profiles" (
    "id" uuid not null,
    "role" public.user_role not null,
    "full_name" character varying,
    "phone" character varying,
    "status" public.profile_status not null default 'active'::public.profile_status,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."tags" (
    "id" uuid not null,
    "name" character varying not null,
    "created_at" timestamp with time zone not null default now()
      );


CREATE INDEX app_categories_is_active_idx ON public.app_categories USING btree (is_active);

CREATE INDEX app_categories_parent_id_idx ON public.app_categories USING btree (parent_id);

CREATE UNIQUE INDEX app_categories_pkey ON public.app_categories USING btree (id);

CREATE UNIQUE INDEX app_categories_slug_key ON public.app_categories USING btree (slug);

CREATE INDEX app_categories_sort_order_idx ON public.app_categories USING btree (sort_order);

CREATE INDEX assignments_company_id_idx ON public.assignments USING btree (company_id);

CREATE INDEX assignments_driver_id_idx ON public.assignments USING btree (driver_id);

CREATE UNIQUE INDEX assignments_order_id_key ON public.assignments USING btree (order_id);

CREATE UNIQUE INDEX assignments_pkey ON public.assignments USING btree (id);

CREATE INDEX company_users_company_id_idx ON public.company_users USING btree (company_id);

CREATE UNIQUE INDEX company_users_pkey ON public.company_users USING btree (id);

CREATE UNIQUE INDEX company_users_profile_id_company_id_idx ON public.company_users USING btree (profile_id, company_id);

CREATE INDEX customer_addresses_customer_id_idx ON public.customer_addresses USING btree (customer_id);

CREATE INDEX customer_addresses_customer_id_is_default_idx ON public.customer_addresses USING btree (customer_id, is_default);

CREATE UNIQUE INDEX customer_addresses_pkey ON public.customer_addresses USING btree (id);

CREATE UNIQUE INDEX customers_pkey ON public.customers USING btree (id);

CREATE INDEX delivery_companies_name_idx ON public.delivery_companies USING btree (name);

CREATE UNIQUE INDEX delivery_companies_pkey ON public.delivery_companies USING btree (id);

CREATE INDEX delivery_companies_verification_status_idx ON public.delivery_companies USING btree (verification_status);

CREATE UNIQUE INDEX driver_locations_driver_id_key ON public.driver_locations USING btree (driver_id);

CREATE UNIQUE INDEX driver_locations_pkey ON public.driver_locations USING btree (id);

CREATE INDEX driver_locations_updated_at_idx ON public.driver_locations USING btree (updated_at);

CREATE INDEX drivers_company_id_idx ON public.drivers USING btree (company_id);

CREATE UNIQUE INDEX drivers_pkey ON public.drivers USING btree (id);

CREATE INDEX drivers_verification_status_idx ON public.drivers USING btree (verification_status);

CREATE INDEX idx_assignments_driver ON public.assignments USING btree (driver_id);

CREATE INDEX idx_order_events_order ON public.order_events USING btree (order_id);

CREATE INDEX idx_orders_customer ON public.orders USING btree (customer_profile_id);

CREATE INDEX idx_orders_merchant_status ON public.orders USING btree (merchant_id, status);

CREATE INDEX item_tags_item_id_idx ON public.item_tags USING btree (item_id);

CREATE UNIQUE INDEX item_tags_item_id_tag_id_idx ON public.item_tags USING btree (item_id, tag_id);

CREATE UNIQUE INDEX item_tags_pkey ON public.item_tags USING btree (id);

CREATE INDEX item_tags_tag_id_idx ON public.item_tags USING btree (tag_id);

CREATE INDEX merchant_branch_images_branch_id_idx ON public.merchant_branch_images USING btree (branch_id);

CREATE INDEX merchant_branch_images_branch_id_sort_order_idx ON public.merchant_branch_images USING btree (branch_id, sort_order);

CREATE UNIQUE INDEX merchant_branch_images_pkey ON public.merchant_branch_images USING btree (id);

CREATE INDEX merchant_branches_created_by_idx ON public.merchant_branches USING btree (created_by);

CREATE INDEX merchant_branches_is_active_idx ON public.merchant_branches USING btree (is_active);

CREATE INDEX merchant_branches_merchant_id_idx ON public.merchant_branches USING btree (merchant_id);

CREATE UNIQUE INDEX merchant_branches_pkey ON public.merchant_branches USING btree (id);

CREATE INDEX merchant_business_images_merchant_id_idx ON public.merchant_business_images USING btree (merchant_id);

CREATE INDEX merchant_business_images_merchant_id_sort_order_idx ON public.merchant_business_images USING btree (merchant_id, sort_order);

CREATE UNIQUE INDEX merchant_business_images_pkey ON public.merchant_business_images USING btree (id);

CREATE INDEX merchant_businesses_is_active_idx ON public.merchant_businesses USING btree (is_active);

CREATE INDEX merchant_businesses_name_idx ON public.merchant_businesses USING btree (name);

CREATE UNIQUE INDEX merchant_businesses_pkey ON public.merchant_businesses USING btree (id);

CREATE INDEX merchant_categories_category_id_idx ON public.merchant_categories USING btree (category_id);

CREATE UNIQUE INDEX merchant_categories_merchant_id_category_id_idx ON public.merchant_categories USING btree (merchant_id, category_id);

CREATE INDEX merchant_categories_merchant_id_idx ON public.merchant_categories USING btree (merchant_id);

CREATE UNIQUE INDEX merchant_categories_pkey ON public.merchant_categories USING btree (id);

CREATE INDEX merchant_item_images_item_id_idx ON public.merchant_item_images USING btree (item_id);

CREATE INDEX merchant_item_images_item_id_sort_order_idx ON public.merchant_item_images USING btree (item_id, sort_order);

CREATE UNIQUE INDEX merchant_item_images_pkey ON public.merchant_item_images USING btree (id);

CREATE INDEX merchant_items_is_available_idx ON public.merchant_items USING btree (is_available);

CREATE INDEX merchant_items_menu_category_id_idx ON public.merchant_items USING btree (menu_category_id);

CREATE INDEX merchant_items_merchant_id_idx ON public.merchant_items USING btree (merchant_id);

CREATE UNIQUE INDEX merchant_items_pkey ON public.merchant_items USING btree (id);

CREATE INDEX merchant_items_price_idx ON public.merchant_items USING btree (price);

CREATE INDEX merchant_menu_categories_is_active_idx ON public.merchant_menu_categories USING btree (is_active);

CREATE INDEX merchant_menu_categories_merchant_id_idx ON public.merchant_menu_categories USING btree (merchant_id);

CREATE INDEX merchant_menu_categories_merchant_id_sort_order_idx ON public.merchant_menu_categories USING btree (merchant_id, sort_order);

CREATE UNIQUE INDEX merchant_menu_categories_pkey ON public.merchant_menu_categories USING btree (id);

CREATE INDEX merchant_tags_merchant_id_idx ON public.merchant_tags USING btree (merchant_id);

CREATE UNIQUE INDEX merchant_tags_merchant_id_tag_id_idx ON public.merchant_tags USING btree (merchant_id, tag_id);

CREATE UNIQUE INDEX merchant_tags_pkey ON public.merchant_tags USING btree (id);

CREATE INDEX merchant_tags_tag_id_idx ON public.merchant_tags USING btree (tag_id);

CREATE INDEX merchant_users_merchant_id_idx ON public.merchant_users USING btree (merchant_id);

CREATE UNIQUE INDEX merchant_users_pkey ON public.merchant_users USING btree (id);

CREATE UNIQUE INDEX merchant_users_profile_id_merchant_id_idx ON public.merchant_users USING btree (profile_id, merchant_id);

CREATE UNIQUE INDEX order_addresses_order_id_key ON public.order_addresses USING btree (order_id);

CREATE UNIQUE INDEX order_addresses_pkey ON public.order_addresses USING btree (id);

CREATE INDEX order_events_created_at_idx ON public.order_events USING btree (created_at);

CREATE INDEX order_events_event_type_idx ON public.order_events USING btree (event_type);

CREATE INDEX order_events_order_id_idx ON public.order_events USING btree (order_id);

CREATE UNIQUE INDEX order_events_pkey ON public.order_events USING btree (id);

CREATE INDEX orders_branch_id_idx ON public.orders USING btree (branch_id);

CREATE INDEX orders_created_at_idx ON public.orders USING btree (created_at);

CREATE INDEX orders_customer_profile_id_idx ON public.orders USING btree (customer_profile_id);

CREATE INDEX orders_merchant_id_idx ON public.orders USING btree (merchant_id);

CREATE INDEX orders_pickup_point_id_idx ON public.orders USING btree (pickup_point_id);

CREATE UNIQUE INDEX orders_pkey ON public.orders USING btree (id);

CREATE INDEX orders_status_idx ON public.orders USING btree (status);

CREATE UNIQUE INDEX orders_tracking_code_key ON public.orders USING btree (tracking_code);

CREATE INDEX payments_method_idx ON public.payments USING btree (method);

CREATE UNIQUE INDEX payments_order_id_key ON public.payments USING btree (order_id);

CREATE UNIQUE INDEX payments_pkey ON public.payments USING btree (id);

CREATE INDEX payments_status_idx ON public.payments USING btree (status);

CREATE INDEX pickup_points_branch_id_idx ON public.pickup_points USING btree (branch_id);

CREATE INDEX pickup_points_is_active_idx ON public.pickup_points USING btree (is_active);

CREATE INDEX pickup_points_merchant_id_idx ON public.pickup_points USING btree (merchant_id);

CREATE UNIQUE INDEX pickup_points_pkey ON public.pickup_points USING btree (id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE INDEX profiles_role_idx ON public.profiles USING btree (role);

CREATE INDEX profiles_status_idx ON public.profiles USING btree (status);

CREATE UNIQUE INDEX tags_name_key ON public.tags USING btree (name);

CREATE UNIQUE INDEX tags_pkey ON public.tags USING btree (id);

CREATE UNIQUE INDEX ux_customer_one_default_address ON public.customer_addresses USING btree (customer_id) WHERE (is_default = true);

alter table "public"."app_categories" add constraint "app_categories_pkey" PRIMARY KEY using index "app_categories_pkey";

alter table "public"."assignments" add constraint "assignments_pkey" PRIMARY KEY using index "assignments_pkey";

alter table "public"."company_users" add constraint "company_users_pkey" PRIMARY KEY using index "company_users_pkey";

alter table "public"."customer_addresses" add constraint "customer_addresses_pkey" PRIMARY KEY using index "customer_addresses_pkey";

alter table "public"."customers" add constraint "customers_pkey" PRIMARY KEY using index "customers_pkey";

alter table "public"."delivery_companies" add constraint "delivery_companies_pkey" PRIMARY KEY using index "delivery_companies_pkey";

alter table "public"."driver_locations" add constraint "driver_locations_pkey" PRIMARY KEY using index "driver_locations_pkey";

alter table "public"."drivers" add constraint "drivers_pkey" PRIMARY KEY using index "drivers_pkey";

alter table "public"."item_tags" add constraint "item_tags_pkey" PRIMARY KEY using index "item_tags_pkey";

alter table "public"."merchant_branch_images" add constraint "merchant_branch_images_pkey" PRIMARY KEY using index "merchant_branch_images_pkey";

alter table "public"."merchant_branches" add constraint "merchant_branches_pkey" PRIMARY KEY using index "merchant_branches_pkey";

alter table "public"."merchant_business_images" add constraint "merchant_business_images_pkey" PRIMARY KEY using index "merchant_business_images_pkey";

alter table "public"."merchant_businesses" add constraint "merchant_businesses_pkey" PRIMARY KEY using index "merchant_businesses_pkey";

alter table "public"."merchant_categories" add constraint "merchant_categories_pkey" PRIMARY KEY using index "merchant_categories_pkey";

alter table "public"."merchant_item_images" add constraint "merchant_item_images_pkey" PRIMARY KEY using index "merchant_item_images_pkey";

alter table "public"."merchant_items" add constraint "merchant_items_pkey" PRIMARY KEY using index "merchant_items_pkey";

alter table "public"."merchant_menu_categories" add constraint "merchant_menu_categories_pkey" PRIMARY KEY using index "merchant_menu_categories_pkey";

alter table "public"."merchant_tags" add constraint "merchant_tags_pkey" PRIMARY KEY using index "merchant_tags_pkey";

alter table "public"."merchant_users" add constraint "merchant_users_pkey" PRIMARY KEY using index "merchant_users_pkey";

alter table "public"."order_addresses" add constraint "order_addresses_pkey" PRIMARY KEY using index "order_addresses_pkey";

alter table "public"."order_events" add constraint "order_events_pkey" PRIMARY KEY using index "order_events_pkey";

alter table "public"."orders" add constraint "orders_pkey" PRIMARY KEY using index "orders_pkey";

alter table "public"."payments" add constraint "payments_pkey" PRIMARY KEY using index "payments_pkey";

alter table "public"."pickup_points" add constraint "pickup_points_pkey" PRIMARY KEY using index "pickup_points_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."tags" add constraint "tags_pkey" PRIMARY KEY using index "tags_pkey";

alter table "public"."app_categories" add constraint "app_categories_parent_id_fkey" FOREIGN KEY (parent_id) REFERENCES public.app_categories(id) not valid;

alter table "public"."app_categories" validate constraint "app_categories_parent_id_fkey";

alter table "public"."app_categories" add constraint "app_categories_slug_key" UNIQUE using index "app_categories_slug_key";

alter table "public"."assignments" add constraint "assignments_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.delivery_companies(id) not valid;

alter table "public"."assignments" validate constraint "assignments_company_id_fkey";

alter table "public"."assignments" add constraint "assignments_driver_id_fkey" FOREIGN KEY (driver_id) REFERENCES public.drivers(id) not valid;

alter table "public"."assignments" validate constraint "assignments_driver_id_fkey";

alter table "public"."assignments" add constraint "assignments_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) not valid;

alter table "public"."assignments" validate constraint "assignments_order_id_fkey";

alter table "public"."assignments" add constraint "assignments_order_id_key" UNIQUE using index "assignments_order_id_key";

alter table "public"."company_users" add constraint "company_users_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.delivery_companies(id) not valid;

alter table "public"."company_users" validate constraint "company_users_company_id_fkey";

alter table "public"."company_users" add constraint "company_users_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES public.profiles(id) not valid;

alter table "public"."company_users" validate constraint "company_users_profile_id_fkey";

alter table "public"."customer_addresses" add constraint "customer_addresses_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES public.customers(id) not valid;

alter table "public"."customer_addresses" validate constraint "customer_addresses_customer_id_fkey";

alter table "public"."driver_locations" add constraint "driver_locations_driver_id_fkey" FOREIGN KEY (driver_id) REFERENCES public.drivers(id) not valid;

alter table "public"."driver_locations" validate constraint "driver_locations_driver_id_fkey";

alter table "public"."driver_locations" add constraint "driver_locations_driver_id_key" UNIQUE using index "driver_locations_driver_id_key";

alter table "public"."drivers" add constraint "drivers_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.delivery_companies(id) not valid;

alter table "public"."drivers" validate constraint "drivers_company_id_fkey";

alter table "public"."item_tags" add constraint "item_tags_item_id_fkey" FOREIGN KEY (item_id) REFERENCES public.merchant_items(id) not valid;

alter table "public"."item_tags" validate constraint "item_tags_item_id_fkey";

alter table "public"."item_tags" add constraint "item_tags_tag_id_fkey" FOREIGN KEY (tag_id) REFERENCES public.tags(id) not valid;

alter table "public"."item_tags" validate constraint "item_tags_tag_id_fkey";

alter table "public"."merchant_branch_images" add constraint "merchant_branch_images_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES public.merchant_branches(id) not valid;

alter table "public"."merchant_branch_images" validate constraint "merchant_branch_images_branch_id_fkey";

alter table "public"."merchant_branches" add constraint "merchant_branches_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id) not valid;

alter table "public"."merchant_branches" validate constraint "merchant_branches_created_by_fkey";

alter table "public"."merchant_branches" add constraint "merchant_branches_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."merchant_branches" validate constraint "merchant_branches_merchant_id_fkey";

alter table "public"."merchant_business_images" add constraint "merchant_business_images_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."merchant_business_images" validate constraint "merchant_business_images_merchant_id_fkey";

alter table "public"."merchant_categories" add constraint "merchant_categories_category_id_fkey" FOREIGN KEY (category_id) REFERENCES public.app_categories(id) not valid;

alter table "public"."merchant_categories" validate constraint "merchant_categories_category_id_fkey";

alter table "public"."merchant_categories" add constraint "merchant_categories_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."merchant_categories" validate constraint "merchant_categories_merchant_id_fkey";

alter table "public"."merchant_item_images" add constraint "merchant_item_images_item_id_fkey" FOREIGN KEY (item_id) REFERENCES public.merchant_items(id) not valid;

alter table "public"."merchant_item_images" validate constraint "merchant_item_images_item_id_fkey";

alter table "public"."merchant_items" add constraint "merchant_items_menu_category_id_fkey" FOREIGN KEY (menu_category_id) REFERENCES public.merchant_menu_categories(id) not valid;

alter table "public"."merchant_items" validate constraint "merchant_items_menu_category_id_fkey";

alter table "public"."merchant_items" add constraint "merchant_items_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."merchant_items" validate constraint "merchant_items_merchant_id_fkey";

alter table "public"."merchant_menu_categories" add constraint "merchant_menu_categories_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."merchant_menu_categories" validate constraint "merchant_menu_categories_merchant_id_fkey";

alter table "public"."merchant_tags" add constraint "merchant_tags_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."merchant_tags" validate constraint "merchant_tags_merchant_id_fkey";

alter table "public"."merchant_tags" add constraint "merchant_tags_tag_id_fkey" FOREIGN KEY (tag_id) REFERENCES public.tags(id) not valid;

alter table "public"."merchant_tags" validate constraint "merchant_tags_tag_id_fkey";

alter table "public"."merchant_users" add constraint "merchant_users_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."merchant_users" validate constraint "merchant_users_merchant_id_fkey";

alter table "public"."merchant_users" add constraint "merchant_users_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES public.profiles(id) not valid;

alter table "public"."merchant_users" validate constraint "merchant_users_profile_id_fkey";

alter table "public"."order_addresses" add constraint "order_addresses_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) not valid;

alter table "public"."order_addresses" validate constraint "order_addresses_order_id_fkey";

alter table "public"."order_addresses" add constraint "order_addresses_order_id_key" UNIQUE using index "order_addresses_order_id_key";

alter table "public"."order_events" add constraint "order_events_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id) not valid;

alter table "public"."order_events" validate constraint "order_events_created_by_fkey";

alter table "public"."order_events" add constraint "order_events_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) not valid;

alter table "public"."order_events" validate constraint "order_events_order_id_fkey";

alter table "public"."orders" add constraint "orders_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES public.merchant_branches(id) not valid;

alter table "public"."orders" validate constraint "orders_branch_id_fkey";

alter table "public"."orders" add constraint "orders_customer_profile_id_fkey" FOREIGN KEY (customer_profile_id) REFERENCES public.profiles(id) not valid;

alter table "public"."orders" validate constraint "orders_customer_profile_id_fkey";

alter table "public"."orders" add constraint "orders_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."orders" validate constraint "orders_merchant_id_fkey";

alter table "public"."orders" add constraint "orders_pickup_point_id_fkey" FOREIGN KEY (pickup_point_id) REFERENCES public.pickup_points(id) not valid;

alter table "public"."orders" validate constraint "orders_pickup_point_id_fkey";

alter table "public"."orders" add constraint "orders_tracking_code_key" UNIQUE using index "orders_tracking_code_key";

alter table "public"."payments" add constraint "payments_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) not valid;

alter table "public"."payments" validate constraint "payments_order_id_fkey";

alter table "public"."payments" add constraint "payments_order_id_key" UNIQUE using index "payments_order_id_key";

alter table "public"."pickup_points" add constraint "pickup_points_branch_id_fkey" FOREIGN KEY (branch_id) REFERENCES public.merchant_branches(id) not valid;

alter table "public"."pickup_points" validate constraint "pickup_points_branch_id_fkey";

alter table "public"."pickup_points" add constraint "pickup_points_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id) not valid;

alter table "public"."pickup_points" validate constraint "pickup_points_created_by_fkey";

alter table "public"."pickup_points" add constraint "pickup_points_merchant_id_fkey" FOREIGN KEY (merchant_id) REFERENCES public.merchant_businesses(id) not valid;

alter table "public"."pickup_points" validate constraint "pickup_points_merchant_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES public.customers(id) not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey1" FOREIGN KEY (id) REFERENCES public.drivers(id) not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey1";

alter table "public"."tags" add constraint "tags_name_key" UNIQUE using index "tags_name_key";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.create_order_created_event()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  insert into public.order_events (order_id, event_type, created_at)
  values (new.id, 'order_created', now());

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.enforce_pickup_point_branch_merchant()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_branch_merchant uuid;
begin
  if new.branch_id is not null then
    select merchant_id into v_branch_merchant
    from public.merchant_branches
    where id = new.branch_id;

    if v_branch_merchant is null then
      raise exception 'Invalid branch_id';
    end if;

    if new.merchant_id is null then
      new.merchant_id := v_branch_merchant;
    elsif new.merchant_id <> v_branch_merchant then
      raise exception 'pickup_points.merchant_id must match merchant_branches.merchant_id';
    end if;
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  insert into public.profiles (id, role, full_name, status, created_at)
  values (new.id, 'customer', coalesce(new.raw_user_meta_data->>'full_name', new.email), 'active', now());
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

grant delete on table "public"."app_categories" to "anon";

grant insert on table "public"."app_categories" to "anon";

grant references on table "public"."app_categories" to "anon";

grant select on table "public"."app_categories" to "anon";

grant trigger on table "public"."app_categories" to "anon";

grant truncate on table "public"."app_categories" to "anon";

grant update on table "public"."app_categories" to "anon";

grant delete on table "public"."app_categories" to "authenticated";

grant insert on table "public"."app_categories" to "authenticated";

grant references on table "public"."app_categories" to "authenticated";

grant select on table "public"."app_categories" to "authenticated";

grant trigger on table "public"."app_categories" to "authenticated";

grant truncate on table "public"."app_categories" to "authenticated";

grant update on table "public"."app_categories" to "authenticated";

grant delete on table "public"."app_categories" to "service_role";

grant insert on table "public"."app_categories" to "service_role";

grant references on table "public"."app_categories" to "service_role";

grant select on table "public"."app_categories" to "service_role";

grant trigger on table "public"."app_categories" to "service_role";

grant truncate on table "public"."app_categories" to "service_role";

grant update on table "public"."app_categories" to "service_role";

grant delete on table "public"."assignments" to "anon";

grant insert on table "public"."assignments" to "anon";

grant references on table "public"."assignments" to "anon";

grant select on table "public"."assignments" to "anon";

grant trigger on table "public"."assignments" to "anon";

grant truncate on table "public"."assignments" to "anon";

grant update on table "public"."assignments" to "anon";

grant delete on table "public"."assignments" to "authenticated";

grant insert on table "public"."assignments" to "authenticated";

grant references on table "public"."assignments" to "authenticated";

grant select on table "public"."assignments" to "authenticated";

grant trigger on table "public"."assignments" to "authenticated";

grant truncate on table "public"."assignments" to "authenticated";

grant update on table "public"."assignments" to "authenticated";

grant delete on table "public"."assignments" to "service_role";

grant insert on table "public"."assignments" to "service_role";

grant references on table "public"."assignments" to "service_role";

grant select on table "public"."assignments" to "service_role";

grant trigger on table "public"."assignments" to "service_role";

grant truncate on table "public"."assignments" to "service_role";

grant update on table "public"."assignments" to "service_role";

grant delete on table "public"."company_users" to "anon";

grant insert on table "public"."company_users" to "anon";

grant references on table "public"."company_users" to "anon";

grant select on table "public"."company_users" to "anon";

grant trigger on table "public"."company_users" to "anon";

grant truncate on table "public"."company_users" to "anon";

grant update on table "public"."company_users" to "anon";

grant delete on table "public"."company_users" to "authenticated";

grant insert on table "public"."company_users" to "authenticated";

grant references on table "public"."company_users" to "authenticated";

grant select on table "public"."company_users" to "authenticated";

grant trigger on table "public"."company_users" to "authenticated";

grant truncate on table "public"."company_users" to "authenticated";

grant update on table "public"."company_users" to "authenticated";

grant delete on table "public"."company_users" to "service_role";

grant insert on table "public"."company_users" to "service_role";

grant references on table "public"."company_users" to "service_role";

grant select on table "public"."company_users" to "service_role";

grant trigger on table "public"."company_users" to "service_role";

grant truncate on table "public"."company_users" to "service_role";

grant update on table "public"."company_users" to "service_role";

grant delete on table "public"."customer_addresses" to "anon";

grant insert on table "public"."customer_addresses" to "anon";

grant references on table "public"."customer_addresses" to "anon";

grant select on table "public"."customer_addresses" to "anon";

grant trigger on table "public"."customer_addresses" to "anon";

grant truncate on table "public"."customer_addresses" to "anon";

grant update on table "public"."customer_addresses" to "anon";

grant delete on table "public"."customer_addresses" to "authenticated";

grant insert on table "public"."customer_addresses" to "authenticated";

grant references on table "public"."customer_addresses" to "authenticated";

grant select on table "public"."customer_addresses" to "authenticated";

grant trigger on table "public"."customer_addresses" to "authenticated";

grant truncate on table "public"."customer_addresses" to "authenticated";

grant update on table "public"."customer_addresses" to "authenticated";

grant delete on table "public"."customer_addresses" to "service_role";

grant insert on table "public"."customer_addresses" to "service_role";

grant references on table "public"."customer_addresses" to "service_role";

grant select on table "public"."customer_addresses" to "service_role";

grant trigger on table "public"."customer_addresses" to "service_role";

grant truncate on table "public"."customer_addresses" to "service_role";

grant update on table "public"."customer_addresses" to "service_role";

grant delete on table "public"."customers" to "anon";

grant insert on table "public"."customers" to "anon";

grant references on table "public"."customers" to "anon";

grant select on table "public"."customers" to "anon";

grant trigger on table "public"."customers" to "anon";

grant truncate on table "public"."customers" to "anon";

grant update on table "public"."customers" to "anon";

grant delete on table "public"."customers" to "authenticated";

grant insert on table "public"."customers" to "authenticated";

grant references on table "public"."customers" to "authenticated";

grant select on table "public"."customers" to "authenticated";

grant trigger on table "public"."customers" to "authenticated";

grant truncate on table "public"."customers" to "authenticated";

grant update on table "public"."customers" to "authenticated";

grant delete on table "public"."customers" to "service_role";

grant insert on table "public"."customers" to "service_role";

grant references on table "public"."customers" to "service_role";

grant select on table "public"."customers" to "service_role";

grant trigger on table "public"."customers" to "service_role";

grant truncate on table "public"."customers" to "service_role";

grant update on table "public"."customers" to "service_role";

grant delete on table "public"."delivery_companies" to "anon";

grant insert on table "public"."delivery_companies" to "anon";

grant references on table "public"."delivery_companies" to "anon";

grant select on table "public"."delivery_companies" to "anon";

grant trigger on table "public"."delivery_companies" to "anon";

grant truncate on table "public"."delivery_companies" to "anon";

grant update on table "public"."delivery_companies" to "anon";

grant delete on table "public"."delivery_companies" to "authenticated";

grant insert on table "public"."delivery_companies" to "authenticated";

grant references on table "public"."delivery_companies" to "authenticated";

grant select on table "public"."delivery_companies" to "authenticated";

grant trigger on table "public"."delivery_companies" to "authenticated";

grant truncate on table "public"."delivery_companies" to "authenticated";

grant update on table "public"."delivery_companies" to "authenticated";

grant delete on table "public"."delivery_companies" to "service_role";

grant insert on table "public"."delivery_companies" to "service_role";

grant references on table "public"."delivery_companies" to "service_role";

grant select on table "public"."delivery_companies" to "service_role";

grant trigger on table "public"."delivery_companies" to "service_role";

grant truncate on table "public"."delivery_companies" to "service_role";

grant update on table "public"."delivery_companies" to "service_role";

grant delete on table "public"."driver_locations" to "anon";

grant insert on table "public"."driver_locations" to "anon";

grant references on table "public"."driver_locations" to "anon";

grant select on table "public"."driver_locations" to "anon";

grant trigger on table "public"."driver_locations" to "anon";

grant truncate on table "public"."driver_locations" to "anon";

grant update on table "public"."driver_locations" to "anon";

grant delete on table "public"."driver_locations" to "authenticated";

grant insert on table "public"."driver_locations" to "authenticated";

grant references on table "public"."driver_locations" to "authenticated";

grant select on table "public"."driver_locations" to "authenticated";

grant trigger on table "public"."driver_locations" to "authenticated";

grant truncate on table "public"."driver_locations" to "authenticated";

grant update on table "public"."driver_locations" to "authenticated";

grant delete on table "public"."driver_locations" to "service_role";

grant insert on table "public"."driver_locations" to "service_role";

grant references on table "public"."driver_locations" to "service_role";

grant select on table "public"."driver_locations" to "service_role";

grant trigger on table "public"."driver_locations" to "service_role";

grant truncate on table "public"."driver_locations" to "service_role";

grant update on table "public"."driver_locations" to "service_role";

grant delete on table "public"."drivers" to "anon";

grant insert on table "public"."drivers" to "anon";

grant references on table "public"."drivers" to "anon";

grant select on table "public"."drivers" to "anon";

grant trigger on table "public"."drivers" to "anon";

grant truncate on table "public"."drivers" to "anon";

grant update on table "public"."drivers" to "anon";

grant delete on table "public"."drivers" to "authenticated";

grant insert on table "public"."drivers" to "authenticated";

grant references on table "public"."drivers" to "authenticated";

grant select on table "public"."drivers" to "authenticated";

grant trigger on table "public"."drivers" to "authenticated";

grant truncate on table "public"."drivers" to "authenticated";

grant update on table "public"."drivers" to "authenticated";

grant delete on table "public"."drivers" to "service_role";

grant insert on table "public"."drivers" to "service_role";

grant references on table "public"."drivers" to "service_role";

grant select on table "public"."drivers" to "service_role";

grant trigger on table "public"."drivers" to "service_role";

grant truncate on table "public"."drivers" to "service_role";

grant update on table "public"."drivers" to "service_role";

grant delete on table "public"."item_tags" to "anon";

grant insert on table "public"."item_tags" to "anon";

grant references on table "public"."item_tags" to "anon";

grant select on table "public"."item_tags" to "anon";

grant trigger on table "public"."item_tags" to "anon";

grant truncate on table "public"."item_tags" to "anon";

grant update on table "public"."item_tags" to "anon";

grant delete on table "public"."item_tags" to "authenticated";

grant insert on table "public"."item_tags" to "authenticated";

grant references on table "public"."item_tags" to "authenticated";

grant select on table "public"."item_tags" to "authenticated";

grant trigger on table "public"."item_tags" to "authenticated";

grant truncate on table "public"."item_tags" to "authenticated";

grant update on table "public"."item_tags" to "authenticated";

grant delete on table "public"."item_tags" to "service_role";

grant insert on table "public"."item_tags" to "service_role";

grant references on table "public"."item_tags" to "service_role";

grant select on table "public"."item_tags" to "service_role";

grant trigger on table "public"."item_tags" to "service_role";

grant truncate on table "public"."item_tags" to "service_role";

grant update on table "public"."item_tags" to "service_role";

grant delete on table "public"."merchant_branch_images" to "anon";

grant insert on table "public"."merchant_branch_images" to "anon";

grant references on table "public"."merchant_branch_images" to "anon";

grant select on table "public"."merchant_branch_images" to "anon";

grant trigger on table "public"."merchant_branch_images" to "anon";

grant truncate on table "public"."merchant_branch_images" to "anon";

grant update on table "public"."merchant_branch_images" to "anon";

grant delete on table "public"."merchant_branch_images" to "authenticated";

grant insert on table "public"."merchant_branch_images" to "authenticated";

grant references on table "public"."merchant_branch_images" to "authenticated";

grant select on table "public"."merchant_branch_images" to "authenticated";

grant trigger on table "public"."merchant_branch_images" to "authenticated";

grant truncate on table "public"."merchant_branch_images" to "authenticated";

grant update on table "public"."merchant_branch_images" to "authenticated";

grant delete on table "public"."merchant_branch_images" to "service_role";

grant insert on table "public"."merchant_branch_images" to "service_role";

grant references on table "public"."merchant_branch_images" to "service_role";

grant select on table "public"."merchant_branch_images" to "service_role";

grant trigger on table "public"."merchant_branch_images" to "service_role";

grant truncate on table "public"."merchant_branch_images" to "service_role";

grant update on table "public"."merchant_branch_images" to "service_role";

grant delete on table "public"."merchant_branches" to "anon";

grant insert on table "public"."merchant_branches" to "anon";

grant references on table "public"."merchant_branches" to "anon";

grant select on table "public"."merchant_branches" to "anon";

grant trigger on table "public"."merchant_branches" to "anon";

grant truncate on table "public"."merchant_branches" to "anon";

grant update on table "public"."merchant_branches" to "anon";

grant delete on table "public"."merchant_branches" to "authenticated";

grant insert on table "public"."merchant_branches" to "authenticated";

grant references on table "public"."merchant_branches" to "authenticated";

grant select on table "public"."merchant_branches" to "authenticated";

grant trigger on table "public"."merchant_branches" to "authenticated";

grant truncate on table "public"."merchant_branches" to "authenticated";

grant update on table "public"."merchant_branches" to "authenticated";

grant delete on table "public"."merchant_branches" to "service_role";

grant insert on table "public"."merchant_branches" to "service_role";

grant references on table "public"."merchant_branches" to "service_role";

grant select on table "public"."merchant_branches" to "service_role";

grant trigger on table "public"."merchant_branches" to "service_role";

grant truncate on table "public"."merchant_branches" to "service_role";

grant update on table "public"."merchant_branches" to "service_role";

grant delete on table "public"."merchant_business_images" to "anon";

grant insert on table "public"."merchant_business_images" to "anon";

grant references on table "public"."merchant_business_images" to "anon";

grant select on table "public"."merchant_business_images" to "anon";

grant trigger on table "public"."merchant_business_images" to "anon";

grant truncate on table "public"."merchant_business_images" to "anon";

grant update on table "public"."merchant_business_images" to "anon";

grant delete on table "public"."merchant_business_images" to "authenticated";

grant insert on table "public"."merchant_business_images" to "authenticated";

grant references on table "public"."merchant_business_images" to "authenticated";

grant select on table "public"."merchant_business_images" to "authenticated";

grant trigger on table "public"."merchant_business_images" to "authenticated";

grant truncate on table "public"."merchant_business_images" to "authenticated";

grant update on table "public"."merchant_business_images" to "authenticated";

grant delete on table "public"."merchant_business_images" to "service_role";

grant insert on table "public"."merchant_business_images" to "service_role";

grant references on table "public"."merchant_business_images" to "service_role";

grant select on table "public"."merchant_business_images" to "service_role";

grant trigger on table "public"."merchant_business_images" to "service_role";

grant truncate on table "public"."merchant_business_images" to "service_role";

grant update on table "public"."merchant_business_images" to "service_role";

grant delete on table "public"."merchant_businesses" to "anon";

grant insert on table "public"."merchant_businesses" to "anon";

grant references on table "public"."merchant_businesses" to "anon";

grant select on table "public"."merchant_businesses" to "anon";

grant trigger on table "public"."merchant_businesses" to "anon";

grant truncate on table "public"."merchant_businesses" to "anon";

grant update on table "public"."merchant_businesses" to "anon";

grant delete on table "public"."merchant_businesses" to "authenticated";

grant insert on table "public"."merchant_businesses" to "authenticated";

grant references on table "public"."merchant_businesses" to "authenticated";

grant select on table "public"."merchant_businesses" to "authenticated";

grant trigger on table "public"."merchant_businesses" to "authenticated";

grant truncate on table "public"."merchant_businesses" to "authenticated";

grant update on table "public"."merchant_businesses" to "authenticated";

grant delete on table "public"."merchant_businesses" to "service_role";

grant insert on table "public"."merchant_businesses" to "service_role";

grant references on table "public"."merchant_businesses" to "service_role";

grant select on table "public"."merchant_businesses" to "service_role";

grant trigger on table "public"."merchant_businesses" to "service_role";

grant truncate on table "public"."merchant_businesses" to "service_role";

grant update on table "public"."merchant_businesses" to "service_role";

grant delete on table "public"."merchant_categories" to "anon";

grant insert on table "public"."merchant_categories" to "anon";

grant references on table "public"."merchant_categories" to "anon";

grant select on table "public"."merchant_categories" to "anon";

grant trigger on table "public"."merchant_categories" to "anon";

grant truncate on table "public"."merchant_categories" to "anon";

grant update on table "public"."merchant_categories" to "anon";

grant delete on table "public"."merchant_categories" to "authenticated";

grant insert on table "public"."merchant_categories" to "authenticated";

grant references on table "public"."merchant_categories" to "authenticated";

grant select on table "public"."merchant_categories" to "authenticated";

grant trigger on table "public"."merchant_categories" to "authenticated";

grant truncate on table "public"."merchant_categories" to "authenticated";

grant update on table "public"."merchant_categories" to "authenticated";

grant delete on table "public"."merchant_categories" to "service_role";

grant insert on table "public"."merchant_categories" to "service_role";

grant references on table "public"."merchant_categories" to "service_role";

grant select on table "public"."merchant_categories" to "service_role";

grant trigger on table "public"."merchant_categories" to "service_role";

grant truncate on table "public"."merchant_categories" to "service_role";

grant update on table "public"."merchant_categories" to "service_role";

grant delete on table "public"."merchant_item_images" to "anon";

grant insert on table "public"."merchant_item_images" to "anon";

grant references on table "public"."merchant_item_images" to "anon";

grant select on table "public"."merchant_item_images" to "anon";

grant trigger on table "public"."merchant_item_images" to "anon";

grant truncate on table "public"."merchant_item_images" to "anon";

grant update on table "public"."merchant_item_images" to "anon";

grant delete on table "public"."merchant_item_images" to "authenticated";

grant insert on table "public"."merchant_item_images" to "authenticated";

grant references on table "public"."merchant_item_images" to "authenticated";

grant select on table "public"."merchant_item_images" to "authenticated";

grant trigger on table "public"."merchant_item_images" to "authenticated";

grant truncate on table "public"."merchant_item_images" to "authenticated";

grant update on table "public"."merchant_item_images" to "authenticated";

grant delete on table "public"."merchant_item_images" to "service_role";

grant insert on table "public"."merchant_item_images" to "service_role";

grant references on table "public"."merchant_item_images" to "service_role";

grant select on table "public"."merchant_item_images" to "service_role";

grant trigger on table "public"."merchant_item_images" to "service_role";

grant truncate on table "public"."merchant_item_images" to "service_role";

grant update on table "public"."merchant_item_images" to "service_role";

grant delete on table "public"."merchant_items" to "anon";

grant insert on table "public"."merchant_items" to "anon";

grant references on table "public"."merchant_items" to "anon";

grant select on table "public"."merchant_items" to "anon";

grant trigger on table "public"."merchant_items" to "anon";

grant truncate on table "public"."merchant_items" to "anon";

grant update on table "public"."merchant_items" to "anon";

grant delete on table "public"."merchant_items" to "authenticated";

grant insert on table "public"."merchant_items" to "authenticated";

grant references on table "public"."merchant_items" to "authenticated";

grant select on table "public"."merchant_items" to "authenticated";

grant trigger on table "public"."merchant_items" to "authenticated";

grant truncate on table "public"."merchant_items" to "authenticated";

grant update on table "public"."merchant_items" to "authenticated";

grant delete on table "public"."merchant_items" to "service_role";

grant insert on table "public"."merchant_items" to "service_role";

grant references on table "public"."merchant_items" to "service_role";

grant select on table "public"."merchant_items" to "service_role";

grant trigger on table "public"."merchant_items" to "service_role";

grant truncate on table "public"."merchant_items" to "service_role";

grant update on table "public"."merchant_items" to "service_role";

grant delete on table "public"."merchant_menu_categories" to "anon";

grant insert on table "public"."merchant_menu_categories" to "anon";

grant references on table "public"."merchant_menu_categories" to "anon";

grant select on table "public"."merchant_menu_categories" to "anon";

grant trigger on table "public"."merchant_menu_categories" to "anon";

grant truncate on table "public"."merchant_menu_categories" to "anon";

grant update on table "public"."merchant_menu_categories" to "anon";

grant delete on table "public"."merchant_menu_categories" to "authenticated";

grant insert on table "public"."merchant_menu_categories" to "authenticated";

grant references on table "public"."merchant_menu_categories" to "authenticated";

grant select on table "public"."merchant_menu_categories" to "authenticated";

grant trigger on table "public"."merchant_menu_categories" to "authenticated";

grant truncate on table "public"."merchant_menu_categories" to "authenticated";

grant update on table "public"."merchant_menu_categories" to "authenticated";

grant delete on table "public"."merchant_menu_categories" to "service_role";

grant insert on table "public"."merchant_menu_categories" to "service_role";

grant references on table "public"."merchant_menu_categories" to "service_role";

grant select on table "public"."merchant_menu_categories" to "service_role";

grant trigger on table "public"."merchant_menu_categories" to "service_role";

grant truncate on table "public"."merchant_menu_categories" to "service_role";

grant update on table "public"."merchant_menu_categories" to "service_role";

grant delete on table "public"."merchant_tags" to "anon";

grant insert on table "public"."merchant_tags" to "anon";

grant references on table "public"."merchant_tags" to "anon";

grant select on table "public"."merchant_tags" to "anon";

grant trigger on table "public"."merchant_tags" to "anon";

grant truncate on table "public"."merchant_tags" to "anon";

grant update on table "public"."merchant_tags" to "anon";

grant delete on table "public"."merchant_tags" to "authenticated";

grant insert on table "public"."merchant_tags" to "authenticated";

grant references on table "public"."merchant_tags" to "authenticated";

grant select on table "public"."merchant_tags" to "authenticated";

grant trigger on table "public"."merchant_tags" to "authenticated";

grant truncate on table "public"."merchant_tags" to "authenticated";

grant update on table "public"."merchant_tags" to "authenticated";

grant delete on table "public"."merchant_tags" to "service_role";

grant insert on table "public"."merchant_tags" to "service_role";

grant references on table "public"."merchant_tags" to "service_role";

grant select on table "public"."merchant_tags" to "service_role";

grant trigger on table "public"."merchant_tags" to "service_role";

grant truncate on table "public"."merchant_tags" to "service_role";

grant update on table "public"."merchant_tags" to "service_role";

grant delete on table "public"."merchant_users" to "anon";

grant insert on table "public"."merchant_users" to "anon";

grant references on table "public"."merchant_users" to "anon";

grant select on table "public"."merchant_users" to "anon";

grant trigger on table "public"."merchant_users" to "anon";

grant truncate on table "public"."merchant_users" to "anon";

grant update on table "public"."merchant_users" to "anon";

grant delete on table "public"."merchant_users" to "authenticated";

grant insert on table "public"."merchant_users" to "authenticated";

grant references on table "public"."merchant_users" to "authenticated";

grant select on table "public"."merchant_users" to "authenticated";

grant trigger on table "public"."merchant_users" to "authenticated";

grant truncate on table "public"."merchant_users" to "authenticated";

grant update on table "public"."merchant_users" to "authenticated";

grant delete on table "public"."merchant_users" to "service_role";

grant insert on table "public"."merchant_users" to "service_role";

grant references on table "public"."merchant_users" to "service_role";

grant select on table "public"."merchant_users" to "service_role";

grant trigger on table "public"."merchant_users" to "service_role";

grant truncate on table "public"."merchant_users" to "service_role";

grant update on table "public"."merchant_users" to "service_role";

grant delete on table "public"."order_addresses" to "anon";

grant insert on table "public"."order_addresses" to "anon";

grant references on table "public"."order_addresses" to "anon";

grant select on table "public"."order_addresses" to "anon";

grant trigger on table "public"."order_addresses" to "anon";

grant truncate on table "public"."order_addresses" to "anon";

grant update on table "public"."order_addresses" to "anon";

grant delete on table "public"."order_addresses" to "authenticated";

grant insert on table "public"."order_addresses" to "authenticated";

grant references on table "public"."order_addresses" to "authenticated";

grant select on table "public"."order_addresses" to "authenticated";

grant trigger on table "public"."order_addresses" to "authenticated";

grant truncate on table "public"."order_addresses" to "authenticated";

grant update on table "public"."order_addresses" to "authenticated";

grant delete on table "public"."order_addresses" to "service_role";

grant insert on table "public"."order_addresses" to "service_role";

grant references on table "public"."order_addresses" to "service_role";

grant select on table "public"."order_addresses" to "service_role";

grant trigger on table "public"."order_addresses" to "service_role";

grant truncate on table "public"."order_addresses" to "service_role";

grant update on table "public"."order_addresses" to "service_role";

grant delete on table "public"."order_events" to "anon";

grant insert on table "public"."order_events" to "anon";

grant references on table "public"."order_events" to "anon";

grant select on table "public"."order_events" to "anon";

grant trigger on table "public"."order_events" to "anon";

grant truncate on table "public"."order_events" to "anon";

grant update on table "public"."order_events" to "anon";

grant delete on table "public"."order_events" to "authenticated";

grant insert on table "public"."order_events" to "authenticated";

grant references on table "public"."order_events" to "authenticated";

grant select on table "public"."order_events" to "authenticated";

grant trigger on table "public"."order_events" to "authenticated";

grant truncate on table "public"."order_events" to "authenticated";

grant update on table "public"."order_events" to "authenticated";

grant delete on table "public"."order_events" to "service_role";

grant insert on table "public"."order_events" to "service_role";

grant references on table "public"."order_events" to "service_role";

grant select on table "public"."order_events" to "service_role";

grant trigger on table "public"."order_events" to "service_role";

grant truncate on table "public"."order_events" to "service_role";

grant update on table "public"."order_events" to "service_role";

grant delete on table "public"."orders" to "anon";

grant insert on table "public"."orders" to "anon";

grant references on table "public"."orders" to "anon";

grant select on table "public"."orders" to "anon";

grant trigger on table "public"."orders" to "anon";

grant truncate on table "public"."orders" to "anon";

grant update on table "public"."orders" to "anon";

grant delete on table "public"."orders" to "authenticated";

grant insert on table "public"."orders" to "authenticated";

grant references on table "public"."orders" to "authenticated";

grant select on table "public"."orders" to "authenticated";

grant trigger on table "public"."orders" to "authenticated";

grant truncate on table "public"."orders" to "authenticated";

grant update on table "public"."orders" to "authenticated";

grant delete on table "public"."orders" to "service_role";

grant insert on table "public"."orders" to "service_role";

grant references on table "public"."orders" to "service_role";

grant select on table "public"."orders" to "service_role";

grant trigger on table "public"."orders" to "service_role";

grant truncate on table "public"."orders" to "service_role";

grant update on table "public"."orders" to "service_role";

grant delete on table "public"."payments" to "anon";

grant insert on table "public"."payments" to "anon";

grant references on table "public"."payments" to "anon";

grant select on table "public"."payments" to "anon";

grant trigger on table "public"."payments" to "anon";

grant truncate on table "public"."payments" to "anon";

grant update on table "public"."payments" to "anon";

grant delete on table "public"."payments" to "authenticated";

grant insert on table "public"."payments" to "authenticated";

grant references on table "public"."payments" to "authenticated";

grant select on table "public"."payments" to "authenticated";

grant trigger on table "public"."payments" to "authenticated";

grant truncate on table "public"."payments" to "authenticated";

grant update on table "public"."payments" to "authenticated";

grant delete on table "public"."payments" to "service_role";

grant insert on table "public"."payments" to "service_role";

grant references on table "public"."payments" to "service_role";

grant select on table "public"."payments" to "service_role";

grant trigger on table "public"."payments" to "service_role";

grant truncate on table "public"."payments" to "service_role";

grant update on table "public"."payments" to "service_role";

grant delete on table "public"."pickup_points" to "anon";

grant insert on table "public"."pickup_points" to "anon";

grant references on table "public"."pickup_points" to "anon";

grant select on table "public"."pickup_points" to "anon";

grant trigger on table "public"."pickup_points" to "anon";

grant truncate on table "public"."pickup_points" to "anon";

grant update on table "public"."pickup_points" to "anon";

grant delete on table "public"."pickup_points" to "authenticated";

grant insert on table "public"."pickup_points" to "authenticated";

grant references on table "public"."pickup_points" to "authenticated";

grant select on table "public"."pickup_points" to "authenticated";

grant trigger on table "public"."pickup_points" to "authenticated";

grant truncate on table "public"."pickup_points" to "authenticated";

grant update on table "public"."pickup_points" to "authenticated";

grant delete on table "public"."pickup_points" to "service_role";

grant insert on table "public"."pickup_points" to "service_role";

grant references on table "public"."pickup_points" to "service_role";

grant select on table "public"."pickup_points" to "service_role";

grant trigger on table "public"."pickup_points" to "service_role";

grant truncate on table "public"."pickup_points" to "service_role";

grant update on table "public"."pickup_points" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."tags" to "anon";

grant insert on table "public"."tags" to "anon";

grant references on table "public"."tags" to "anon";

grant select on table "public"."tags" to "anon";

grant trigger on table "public"."tags" to "anon";

grant truncate on table "public"."tags" to "anon";

grant update on table "public"."tags" to "anon";

grant delete on table "public"."tags" to "authenticated";

grant insert on table "public"."tags" to "authenticated";

grant references on table "public"."tags" to "authenticated";

grant select on table "public"."tags" to "authenticated";

grant trigger on table "public"."tags" to "authenticated";

grant truncate on table "public"."tags" to "authenticated";

grant update on table "public"."tags" to "authenticated";

grant delete on table "public"."tags" to "service_role";

grant insert on table "public"."tags" to "service_role";

grant references on table "public"."tags" to "service_role";

grant select on table "public"."tags" to "service_role";

grant trigger on table "public"."tags" to "service_role";

grant truncate on table "public"."tags" to "service_role";

grant update on table "public"."tags" to "service_role";

CREATE TRIGGER trg_order_created_event AFTER INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.create_order_created_event();

CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_pickup_points_enforce BEFORE INSERT OR UPDATE ON public.pickup_points FOR EACH ROW EXECUTE FUNCTION public.enforce_pickup_point_branch_merchant();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


