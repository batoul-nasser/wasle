import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };
const OTP_LENGTH = 8;
const OTP_EXPIRY_MINUTES = 10;
const ALLOWED_PURPOSES = new Set([
  "driver_signup",
  "company_signup",
  "customer_signup",
  "merchant_signup",
]);

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

function isValidEmail(email: string) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
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

async function emailExists(email: string) {
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

serve(async (req) => {
  try {
    if (!supabaseAdmin) {
      return jsonResponse(
        {
          code: "server_misconfigured",
          error: "OTP service is not configured correctly.",
        },
        500,
      );
    }

    const body = await req.json();
    const email = normalizeEmail(body.email);
    const purpose = normalizePurpose(body.purpose);

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

    if (await emailExists(email)) {
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

    await invalidatePreviousCodes(email, purpose);
    await storeCode(email, purpose, codeHash);
    await sendOtpEmail(email, code);

    return jsonResponse({
      sent: true,
      purpose,
      otpLength: OTP_LENGTH,
      expiresInSeconds: OTP_EXPIRY_MINUTES * 60,
    });
  } catch (error) {
    console.error("request-email-otp failed", error);

    const message = error instanceof Error ? error.message : String(error);
    const isDeliveryFailure =
      message.includes("RESEND_API_KEY") ||
      message.includes("OTP_FROM_EMAIL") ||
      message.includes("Resend API error");

    return jsonResponse(
      {
        code: isDeliveryFailure ? "email_delivery_failed" : "otp_request_failed",
        error: isDeliveryFailure
          ? "We couldn't send a code right now. Please try again."
          : "Unable to create a verification code right now.",
      },
      500,
    );
  }
});
