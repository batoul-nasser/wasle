import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };
const OTP_LENGTH = 8;
const ALLOWED_PURPOSES = new Set([
  "driver_signup",
  "company_signup",
  "customer_signup",
  "merchant_signup",
]);

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const supabaseAdmin =
  supabaseUrl && supabaseServiceRoleKey
    ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    : null;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}

function normalizeEmail(value: unknown) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function normalizePurpose(value: unknown) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function normalizeCode(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function isValidEmail(email: string) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  try {
    if (!supabaseAdmin) {
      return jsonResponse(
        {
          code: "server_misconfigured",
          error: "OTP verification service is not configured correctly.",
        },
        500,
      );
    }

    const body = await req.json();
    const email = normalizeEmail(body.email);
    const purpose = normalizePurpose(body.purpose);
    const code = normalizeCode(body.code);

    if (!isValidEmail(email)) {
      return jsonResponse(
        { code: "invalid_email", error: "Please enter a valid email address." },
        400,
      );
    }

    if (!ALLOWED_PURPOSES.has(purpose)) {
      return jsonResponse(
        { code: "invalid_purpose", error: "Unsupported OTP purpose." },
        400,
      );
    }

    if (!/^\d{8}$/.test(code) || code.length != OTP_LENGTH) {
      return jsonResponse(
        { code: "invalid_otp", error: "The code you entered is incorrect." },
        400,
      );
    }

    const { data, error } = await supabaseAdmin
      .from("email_verification_codes")
      .select("id, code_hash, expires_at, used_at, created_at")
      .eq("email", email)
      .eq("purpose", purpose)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      return jsonResponse(
        { code: "invalid_otp", error: "The code you entered is incorrect." },
        400,
      );
    }

    if (data.used_at) {
      return jsonResponse(
        { code: "invalid_otp", error: "The code you entered is incorrect." },
        400,
      );
    }

    const expiresAt = new Date(data.expires_at);
    if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() <= Date.now()) {
      return jsonResponse(
        {
          code: "otp_expired",
          error: "This code has expired. Please request a new one.",
        },
        400,
      );
    }

    const codeHash = await sha256(code);
    if (codeHash !== data.code_hash) {
      return jsonResponse(
        { code: "invalid_otp", error: "The code you entered is incorrect." },
        400,
      );
    }

    const { error: updateError } = await supabaseAdmin
      .from("email_verification_codes")
      .update({ used_at: new Date().toISOString() })
      .eq("id", data.id)
      .is("used_at", null);

    if (updateError) {
      throw updateError;
    }

    return jsonResponse({
      verified: true,
      purpose,
    });
  } catch (error) {
    console.error("verify-email-otp failed", error);
    return jsonResponse(
      {
        code: "otp_verification_failed",
        error: "We couldn't verify this code. Please try again.",
      },
      500,
    );
  }
});
