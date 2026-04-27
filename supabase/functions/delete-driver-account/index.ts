import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
  throw new Error("Missing Supabase environment configuration");
}

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function jsonResponse(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: JSON_HEADERS,
  });
}

function bearerTokenFrom(req: Request): string | null {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) return null;
  const token = authHeader.slice(7).trim();
  return token.length > 0 ? token : null;
}

serve(async (req) => {
  if (req.method != "POST") {
    return jsonResponse(
      { success: false, error: "Method not allowed. Use POST." },
      405,
    );
  }

  try {
    const token = bearerTokenFrom(req);
    if (!token) {
      return jsonResponse(
        { success: false, error: "Missing authorization token." },
        401,
      );
    }

    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const { data: authData, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !authData.user) {
      return jsonResponse(
        { success: false, error: "Unauthorized request." },
        401,
      );
    }

    const userId = authData.user.id;

    const { data: driverRow, error: driverError } = await supabaseAdmin
      .from("drivers")
      .select("id")
      .eq("profile_id", userId)
      .maybeSingle();
    if (driverError) throw driverError;

    const driverId = driverRow?.id?.toString();
    if (driverId && driverId.length > 0) {
      await supabaseAdmin.from("driver_locations").delete().eq("driver_id", driverId);

      // Keep historical assignment rows but detach the deleted driver.
      await supabaseAdmin
        .from("assignments")
        .update({
          driver_id: null,
          accepted_at: null,
          completed_at: null,
        })
        .eq("driver_id", driverId);

      await supabaseAdmin
        .from("orders")
        .update({
          assigned_driver_id: null,
          assignment_status: "needs_manual_assignment",
          assignment_failure_reason: "Driver account deleted",
          updated_at: new Date().toISOString(),
        })
        .eq("assigned_driver_id", driverId);
    }

    await supabaseAdmin
      .from("driver_company_requests")
      .delete()
      .eq("driver_profile_id", userId);

    await supabaseAdmin.from("drivers").delete().eq("profile_id", userId);
    await supabaseAdmin.from("profiles").delete().eq("id", userId);

    const { error: deleteUserError } = await supabaseAdmin.auth.admin.deleteUser(
      userId,
      true,
    );
    if (deleteUserError) throw deleteUserError;

    return jsonResponse({ success: true });
  } catch (error) {
    console.error("delete-driver-account failed", error);
    const message = error instanceof Error ? error.message : "Unknown error";
    return jsonResponse({ success: false, error: message }, 500);
  }
});
