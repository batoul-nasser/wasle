import { createClient } from "@supabase/supabase-js";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

type Coordinate = {
  lat: number;
  lng: number;
};

type CacheRow = {
  origin_lat: number;
  origin_lng: number;
  destination_lat: number;
  destination_lng: number;
  vehicle_type: string;
  time_bucket: string;
  duration_seconds: number;
  distance_meters: number;
  source: string;
};

type CacheKey = Pick<
  CacheRow,
  | "origin_lat"
  | "origin_lng"
  | "destination_lat"
  | "destination_lng"
  | "vehicle_type"
  | "time_bucket"
>;

const JSON_HEADERS = { "Content-Type": "application/json" };
const COORDINATE_PRECISION = 4;
const TIME_BUCKET_MINUTES = 15;

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const cacheClient =
  supabaseUrl && supabaseServiceRoleKey
    ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    : null;

function haversine(lat1: number, lon1: number, lat2: number, lon2: number) {
  const earthRadiusKm = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) *
      Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) ** 2;

  return earthRadiusKm * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

function roundCoordinate(value: number) {
  return Number(value.toFixed(COORDINATE_PRECISION));
}

function normalizeCoordinate(input: Coordinate): Coordinate {
  return {
    lat: roundCoordinate(input.lat),
    lng: roundCoordinate(input.lng),
  };
}

function normalizeVehicleType(vehicleType: unknown) {
  const normalized = typeof vehicleType === "string"
    ? vehicleType.trim().toLowerCase()
    : "";

  switch (normalized) {
    case "motorcycle":
    case "van":
      return normalized;
    case "car":
    default:
      return "car";
  }
}

function buildTimeBucket(now = new Date()) {
  const bucket = new Date(now);
  bucket.setUTCSeconds(0, 0);
  const minute = bucket.getUTCMinutes();
  bucket.setUTCMinutes(minute - (minute % TIME_BUCKET_MINUTES));
  return bucket.toISOString().slice(0, 16) + "Z";
}

function toCacheRow(
  origin: Coordinate,
  destination: Coordinate,
  vehicleType: string,
  timeBucket: string,
  durationSeconds: number,
  distanceMeters: number,
  source: string,
): CacheRow {
  return {
    origin_lat: origin.lat,
    origin_lng: origin.lng,
    destination_lat: destination.lat,
    destination_lng: destination.lng,
    vehicle_type: vehicleType,
    time_bucket: timeBucket,
    duration_seconds: durationSeconds,
    distance_meters: distanceMeters,
    source,
  };
}

async function lookupCache(row: CacheKey) {
  if (!cacheClient) {
    console.warn("Routing cache disabled: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
    return null;
  }

  const { data, error } = await cacheClient
    .from("routing_cache")
    .select("duration_seconds, distance_meters")
    .match(row)
    .maybeSingle();

  if (error) {
    console.error("Routing cache lookup failed", error);
    return null;
  }

  return data;
}

async function storeCache(row: CacheRow) {
  if (!cacheClient) {
    return;
  }

  const { error } = await cacheClient
    .from("routing_cache")
    .upsert(row, {
      onConflict:
        "origin_lat,origin_lng,destination_lat,destination_lng,vehicle_type,time_bucket",
    });

  if (error) {
    console.error("Routing cache write failed", error);
  }
}

async function fetchGoogleEstimate(origin: Coordinate, destination: Coordinate) {
  const googleKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
  if (!googleKey) {
    throw new Error("Missing GOOGLE_MAPS_API_KEY");
  }

  const url = new URL("https://maps.googleapis.com/maps/api/distancematrix/json");
  url.searchParams.set("origins", `${origin.lat},${origin.lng}`);
  url.searchParams.set("destinations", `${destination.lat},${destination.lng}`);
  url.searchParams.set("mode", "driving");
  url.searchParams.set("departure_time", "now");
  url.searchParams.set("key", googleKey);

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Google API HTTP ${response.status}`);
  }

  const data = await response.json();
  const element = data.rows?.[0]?.elements?.[0];

  if (!element || element.status !== "OK") {
    throw new Error(`Google API failed: ${JSON.stringify(data)}`);
  }

  const durationSeconds = Number(
    element.duration_in_traffic?.value ?? element.duration?.value,
  );
  const distanceMeters = Number(element.distance?.value);
  if (!Number.isFinite(durationSeconds) || !Number.isFinite(distanceMeters)) {
    throw new Error(`Google API returned invalid route metrics: ${JSON.stringify(element)}`);
  }

  return {
    durationSeconds,
    distanceMeters,
  };
}

serve(async (req) => {
  let origin: Coordinate | null = null;
  let destination: Coordinate | null = null;
  let vehicleType = "car";

  try {
    const body = await req.json();
    origin = body.origin;
    destination = body.destination;
    vehicleType = normalizeVehicleType(body.vehicleType);

    if (
      !origin || !destination ||
      typeof origin.lat !== "number" ||
      typeof origin.lng !== "number" ||
      typeof destination.lat !== "number" ||
      typeof destination.lng !== "number"
    ) {
      return new Response(JSON.stringify({ error: "Invalid coordinates" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    const roundedOrigin = normalizeCoordinate(origin);
    const roundedDestination = normalizeCoordinate(destination);
    const timeBucket = buildTimeBucket();

    const cacheKey = {
      origin_lat: roundedOrigin.lat,
      origin_lng: roundedOrigin.lng,
      destination_lat: roundedDestination.lat,
      destination_lng: roundedDestination.lng,
      vehicle_type: vehicleType,
      time_bucket: timeBucket,
    };

    const cached = await lookupCache(cacheKey);
    if (cached) {
      return new Response(
        JSON.stringify({
          durationSeconds: cached.duration_seconds,
          distanceMeters: cached.distance_meters,
          source: "cache",
        }),
        { headers: JSON_HEADERS },
      );
    }

    const googleEstimate = await fetchGoogleEstimate(
      roundedOrigin,
      roundedDestination,
    );

    await storeCache(
      toCacheRow(
        roundedOrigin,
        roundedDestination,
        vehicleType,
        timeBucket,
        googleEstimate.durationSeconds,
        googleEstimate.distanceMeters,
        "google",
      ),
    );

    return new Response(
      JSON.stringify({
        durationSeconds: googleEstimate.durationSeconds,
        distanceMeters: googleEstimate.distanceMeters,
        source: "google",
      }),
      { headers: JSON_HEADERS },
    );
  } catch (err) {
    if (!origin || !destination) {
      return new Response(
        JSON.stringify({
          error: String(err),
          source: "function_error",
        }),
        { status: 500, headers: JSON_HEADERS },
      );
    }

    const distanceKm = haversine(
      origin.lat,
      origin.lng,
      destination.lat,
      destination.lng,
    );

    let speedKmh = 45;
    if (vehicleType === "motorcycle") speedKmh = 35;
    if (vehicleType === "van") speedKmh = 40;

    return new Response(
      JSON.stringify({
        durationSeconds: Math.max(60, Math.round((distanceKm / speedKmh) * 3600)),
        distanceMeters: Math.round(distanceKm * 1000),
        source: "haversine_fallback",
        error: String(err),
      }),
      { headers: JSON_HEADERS },
    );
  }
});
