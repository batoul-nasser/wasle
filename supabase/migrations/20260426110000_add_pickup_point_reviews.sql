create table if not exists "public"."pickup_point_reviews" (
  "id" uuid not null default gen_random_uuid(),
  "pickup_point_id" uuid not null,
  "customer_profile_id" uuid not null,
  "rating" integer not null,
  "comment" text,
  "created_at" timestamp with time zone not null default now(),
  "updated_at" timestamp with time zone not null default now()
);

alter table "public"."pickup_point_reviews"
  add constraint "pickup_point_reviews_pkey" primary key ("id");

alter table "public"."pickup_point_reviews"
  add constraint "pickup_point_reviews_pickup_point_id_fkey"
  foreign key ("pickup_point_id") references "public"."pickup_points"("id") on delete cascade;

alter table "public"."pickup_point_reviews"
  add constraint "pickup_point_reviews_customer_profile_id_fkey"
  foreign key ("customer_profile_id") references "public"."profiles"("id") on delete cascade;

alter table "public"."pickup_point_reviews"
  add constraint "pickup_point_reviews_rating_check"
  check ("rating" >= 1 and "rating" <= 5);

create unique index if not exists "pickup_point_reviews_pickup_customer_key"
  on "public"."pickup_point_reviews" using btree ("pickup_point_id", "customer_profile_id");

create index if not exists "pickup_point_reviews_pickup_point_id_idx"
  on "public"."pickup_point_reviews" using btree ("pickup_point_id");

grant select, insert, update, delete on table "public"."pickup_point_reviews" to "authenticated";
grant select, insert, update, delete on table "public"."pickup_point_reviews" to "service_role";
