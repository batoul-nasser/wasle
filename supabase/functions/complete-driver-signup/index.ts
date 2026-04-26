import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };
const OTP_LENGTH = 8;
const OTP_EXPIRY_MINUTES = 10;
const OTP_PURPOSE = "driver_signup";
const VERIFIED_COMPLETION_WINDOW_MINUTES = 15;
const VEHICLE_CAPACITY = {
  motorcycle: {
    weight: 15,
    volume: 40000,
    itemCount: 5,
  },
  car: {
    weight: 60,
    volume: 200000,
    itemCount: 20,
  },
  van: {
    weight: 300,
    volume: 1000000,
    itemCount: 80,
  },
} as const;

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const resendApiKey = Deno.env.get("RESEND_API_KEY");
const otpFromEmail = Deno.env.get("OTP_FROM_EMAIL");

const supabaseAdmin =
  supabaseUrl && supabaseServiceRoleKey
    ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    : null;

type VehicleType = keyof typeof VEHICLE_CAPACITY;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}

function normalizeEmail(value: unknown) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function normalizeText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizePurpose(value: unknown) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function normalizeCode(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeAction(value: unknown) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function normalizeVehicleType(value: unknown): VehicleType | null {
  const normalized = normalizeText(value).toLowerCase();
  if (
    normalized === "motorcycle" || normalized === "car" ||
    normalized === "van"
  ) {
    return normalized;
  }
  return null;
}

function isValidEmail(email: string) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
}

function serializeError(error: unknown) {
  if (typeof error === "string") {
    return error;
  }

  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message;
  }

  if (error && typeof error === "object") {
    try {
      const rawJson = JSON.stringify(error);
      if (rawJson && rawJson !== "{}") {
        return rawJson;
      }
    } catch (_) {
      // Fall through to field extraction.
    }

    const details: Record<string, unknown> = {};
    for (const key of ["message", "code", "details", "hint", "name"]) {
      const value = Reflect.get(error, key);
      if (value == null) continue;
      const text = String(value).trim();
      if (text.length === 0) continue;
      details[key] = value;
    }

    for (const key of Object.getOwnPropertyNames(error)) {
      if (key in details) continue;
      const value = Reflect.get(error, key);
      if (value == null) continue;
      const text = String(value).trim();
      if (text.length === 0) continue;
      details[key] = value;
    }

    if (Object.keys(details).length > 0) {
      try {
        return JSON.stringify(details);
      } catch (_) {
        // Fall through to String(error)
      }
    }
  }

  return String(error);
}

function generateNumericCode() {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  const value = (array[0] % 90000000) + 10000000;
  return value.toString();
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function isEmailRegistered(email: string) {
  if (!supabaseAdmin) {
    throw new Error("Missing Supabase admin configuration");
  }

  const { data, error } = await supabaseAdmin.rpc("is_email_registered", {
    lookup_email: email,
  });
  if (error) throw error;
  return Boolean(data);
}

async function invalidatePreviousCodes(email: string, purpose: string) {
  if (!supabaseAdmin) {
    throw new Error("Missing Supabase admin configuration");
  }

  const { error } = await supabaseAdmin
    .from("email_verification_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("email", email)
    .eq("purpose", purpose)
    .is("used_at", null);

  if (error) throw error;
}

async function storeCode(email: string, purpose: string, codeHash: string) {
  if (!supabaseAdmin) {
    throw new Error("Missing Supabase admin configuration");
  }

  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000)
    .toISOString();

  const { error } = await supabaseAdmin.from("email_verification_codes").insert({
    email,
    purpose,
    code_hash: codeHash,
    expires_at: expiresAt,
  });

  if (error) throw error;
}

async function sendOtpEmail(email: string, code: string) {
  if (!resendApiKey || !otpFromEmail) {
    throw new Error("Missing RESEND_API_KEY or OTP_FROM_EMAIL");
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: otpFromEmail,
      to: [email],
      subject: "Your Wasle verification code",
      text: code,
      html:
        `<div style="font-family:Arial,sans-serif;font-size:32px;font-weight:700;letter-spacing:6px;">${code}</div>`,
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Resend API error ${response.status}: ${errorBody}`);
  }
}

async function fetchLatestCode(email: string, purpose: string) {
  if (!supabaseAdmin) {
    throw new Error("Missing Supabase admin configuration");
  }

  const { data, error } = await supabaseAdmin
    .from("email_verification_codes")
    .select("id, code_hash, expires_at, used_at, created_at")
    .eq("email", email)
    .eq("purpose", purpose)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data;
}

async function hasFreshVerifiedOtp(email: string) {
  if (!supabaseAdmin) {
    throw new Error("Missing Supabase admin configuration");
  }

  const { data, error } = await supabaseAdmin
    .from("email_verification_codes")
    .select("used_at")
    .eq("email", email)
    .eq("purpose", OTP_PURPOSE)
    .not("used_at", "is", null)
    .order("used_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  if (!data?.used_at) return false;

  const usedAt = new Date(data.used_at);
  if (Number.isNaN(usedAt.getTime())) return false;

  const maxAgeMs = VERIFIED_COMPLETION_WINDOW_MINUTES * 60 * 1000;
  return Date.now() - usedAt.getTime() <= maxAgeMs;
}

async function cleanupUser(userId: string) {
  if (!supabaseAdmin) return;

  try {
    const { data: driverRow } = await supabaseAdmin
      .from("drivers")
      .select("id")
      .eq("profile_id", userId)
      .maybeSingle();

    const driverId = driverRow?.id?.toString();
    if (driverId && driverId.length > 0) {
      await supabaseAdmin.from("driver_locations").delete().eq("driver_id", driverId);
    }

    await supabaseAdmin.from("drivers").delete().eq("profile_id", userId);
    await supabaseAdmin.from("profiles").delete().eq("id", userId);
    const { error: deleteUserError } = await supabaseAdmin.auth.admin.deleteUser(
      userId,
    );
    if (deleteUserError) {
      throw deleteUserError;
    }
  } catch (cleanupError) {
    console.error("complete-driver-signup cleanup failed", cleanupError);
  }
}

async function handleRequestOtp(body: Record<string, unknown>) {
  const email = normalizeEmail(body.email);
  const purpose = normalizePurpose(body.purpose);

  if (!isValidEmail(email)) {
    return jsonResponse(
      { code: "invalid_email", error: "Please enter a valid email address." },
      400,
    );
  }

  if (purpose !== OTP_PURPOSE) {
    return jsonResponse(
      { code: "invalid_purpose", error: "Unsupported OTP purpose." },
      400,
    );
  }

  if (await isEmailRegistered(email)) {
    return jsonResponse(
      {
        code: "email_exists",
        error: "This email is already registered. Please log in.",
      },
      409,
    );
  }

  const code = generateNumericCode();
  const codeHash = await sha256(code);

  try {
    await invalidatePreviousCodes(email, purpose);
    await storeCode(email, purpose, codeHash);
    await sendOtpEmail(email, code);
  } catch (error) {
    console.error("complete-driver-signup request_otp failed", error);
    const message = serializeError(error);
    const deliveryCheck = message.toLowerCase();
    const isDeliveryFailure = deliveryCheck.includes("resend_api_key") ||
      deliveryCheck.includes("otp_from_email") ||
      deliveryCheck.includes("resend api error");

    return jsonResponse(
      {
        code: isDeliveryFailure ? "email_delivery_failed" : "otp_request_failed",
        error: isDeliveryFailure
          ? "We couldn't send a code right now. Please try again."
          : "Unable to create a verification code right now.",
        reason: message,
      },
      500,
    );
  }

  return jsonResponse({
    sent: true,
    purpose,
    otpLength: OTP_LENGTH,
    expiresInSeconds: OTP_EXPIRY_MINUTES * 60,
  });
}

async function handleVerifyOtp(body: Record<string, unknown>) {
  const email = normalizeEmail(body.email);
  const purpose = normalizePurpose(body.purpose);
  const code = normalizeCode(body.code);

  if (!isValidEmail(email)) {
    return jsonResponse(
      { code: "invalid_email", error: "Please enter a valid email address." },
      400,
    );
  }

  if (purpose !== OTP_PURPOSE) {
    return jsonResponse(
      { code: "invalid_purpose", error: "Unsupported OTP purpose." },
      400,
    );
  }

  if (!/^\d{8}$/.test(code) || code.length !== OTP_LENGTH) {
    return jsonResponse(
      { code: "invalid_otp", error: "The code you entered is incorrect." },
      400,
    );
  }

  const latestCode = await fetchLatestCode(email, purpose);
  if (!latestCode) {
    return jsonResponse(
      { code: "invalid_otp", error: "The code you entered is incorrect." },
      400,
    );
  }

  if (latestCode.used_at) {
    return jsonResponse(
      { code: "invalid_otp", error: "The code you entered is incorrect." },
      400,
    );
  }

  const expiresAt = new Date(latestCode.expires_at);
  if (
    Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() <= Date.now()
  ) {
    return jsonResponse(
      {
        code: "otp_expired",
        error: "This code has expired. Please request a new one.",
      },
      400,
    );
  }

  const codeHash = await sha256(code);
  if (codeHash !== latestCode.code_hash) {
    return jsonResponse(
      { code: "invalid_otp", error: "The code you entered is incorrect." },
      400,
    );
  }

  const { error: updateError } = await supabaseAdmin!
    .from("email_verification_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("id", latestCode.id)
    .is("used_at", null);

  if (updateError) {
    throw updateError;
  }

  return jsonResponse({
    verified: true,
    purpose,
  });
}

async function handleCompleteSignup(body: Record<string, unknown>) {
  const email = normalizeEmail(body.email);
  const password = normalizeText(body.password);
  const fullName = normalizeText(body.full_name);
  const phone = normalizeText(body.phone);
  const city = normalizeText(body.city);
  const vehicleType = normalizeVehicleType(body.vehicle_type);
  let createdUserId: string | null = null;

  try {
    if (!isValidEmail(email)) {
      return jsonResponse(
        { code: "invalid_email", error: "Please enter a valid email address." },
        400,
      );
    }

    if (password.length < 8) {
      return jsonResponse(
        {
          code: "invalid_password",
          error: "Password must be at least 8 characters long.",
        },
        400,
      );
    }

    if (!fullName || !phone || !city || !vehicleType) {
      return jsonResponse(
        {
          code: "invalid_signup_payload",
          error: "Signup details are incomplete. Please start again.",
        },
        400,
      );
    }

    if (await isEmailRegistered(email)) {
      return jsonResponse(
        {
          code: "email_exists",
          error: "This email is already registered. Please log in.",
        },
        409,
      );
    }

    if (!(await hasFreshVerifiedOtp(email))) {
      return jsonResponse(
        {
          code: "otp_not_verified",
          error: "Please verify your code before completing signup.",
        },
        403,
      );
    }

    const { data: createData, error: createError } = await supabaseAdmin!.auth
      .admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name: fullName,
        },
      });
    if (createError) throw createError;

    const userId = createData.user?.id;
    if (!userId) {
      throw new Error("Auth user creation did not return a user id.");
    }
    createdUserId = userId;

    const capacity = VEHICLE_CAPACITY[vehicleType];

    const { error: profileError } = await supabaseAdmin!
      .from("profiles")
      .upsert({
        id: userId,
        role: "driver",
        full_name: fullName,
        phone,
        status: "active",
      }, { onConflict: "id" });
    if (profileError) throw profileError;

    const { data: existingDriver, error: driverLookupError } = await supabaseAdmin!
      .from("drivers")
      .select("id")
      .eq("profile_id", userId)
      .maybeSingle();
    if (driverLookupError) throw driverLookupError;

    const driverId = existingDriver?.id?.toString() ?? crypto.randomUUID();

    const { error: driverError } = await supabaseAdmin!
      .from("drivers")
      .upsert({
        id: driverId,
        profile_id: userId,
        company_id: null,
        verification_status: "pending",
        vehicle_type: vehicleType,
        capacity_weight: capacity.weight,
        capacity_volume: capacity.volume,
        capacity_item_count: capacity.itemCount,
      }, { onConflict: "profile_id" });
    if (driverError) throw driverError;

    const { error: locationError } = await supabaseAdmin!
      .from("driver_locations")
      .upsert({
        driver_id: driverId,
        city: city || null,
        updated_at: new Date().toISOString(),
      }, { onConflict: "driver_id" });
    if (locationError) throw locationError;

    return jsonResponse({
      completed: true,
      userId,
      driverId,
    });
  } catch (error) {
    console.error("complete-driver-signup complete_signup failed", error);

    if (createdUserId) {
      await cleanupUser(createdUserId);
    }

    const message = serializeError(error);
    return jsonResponse(
      {
        code: "driver_signup_failed",
        error: message.length > 0
          ? message
          : "Unable to complete driver signup right now.",
        reason: message,
      },
      500,
    );
  }
}

serve(async (req) => {
  try {
    if (!supabaseAdmin) {
      return jsonResponse(
        {
          code: "server_misconfigured",
          error: "Signup service is not configured correctly.",
          reason: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY",
        },
        500,
      );
    }

    const body = await req.json();
    const action = normalizeAction(body.action);

    switch (action) {
      case "request_otp":
        return await handleRequestOtp(body);
      case "verify_otp":
        return await handleVerifyOtp(body);
      case "complete_signup":
        return await handleCompleteSignup(body);
      default:
        return jsonResponse(
          {
            code: "invalid_action",
            error: "Unsupported signup action.",
          },
          400,
        );
    }
  } catch (error) {
    console.error("complete-driver-signup failed", error);

    const message = serializeError(error);
    return jsonResponse(
      {
        code: "driver_signup_failed",
        error: "Unable to complete driver signup right now.",
        reason: message,
      },
      500,
    );
  }
});
