import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Delete rows; returns error message or null. Ignores missing optional tables. */
async function deleteRows(
  admin: SupabaseClient,
  table: string,
  column: string,
  value: string | string[],
  optional = false,
): Promise<string | null> {
  if (Array.isArray(value) && value.length === 0) return null;

  let query = admin.from(table).delete();
  query = Array.isArray(value)
    ? query.in(column, value)
    : query.eq(column, value);

  const { error } = await query;
  if (!error) return null;

  const message = error.message ?? String(error);
  if (optional && message.includes("does not exist")) {
    console.warn(`[delete-account] Optional table ${table} not found, skipping`);
    return null;
  }

  console.error(`[delete-account] Failed to delete from ${table}:`, message);
  return message;
}

async function deleteCustomerData(
  admin: SupabaseClient,
  customerId: string,
): Promise<string | null> {
  const { data: orders, error: ordersLookupError } = await admin
    .from("delivery_orders")
    .select("id")
    .eq("customer_id", customerId);

  if (ordersLookupError) {
    return ordersLookupError.message ?? String(ordersLookupError);
  }

  const orderIds = (orders ?? []).map((o) => o.id as string);

  let err = await deleteRows(admin, "delivery_order_messages", "order_id", orderIds, true);
  if (err) return err;

  err = await deleteRows(admin, "delivery_order_ratings", "order_id", orderIds, true);
  if (err) return err;

  err = await deleteRows(admin, "delivery_ratings", "order_id", orderIds, true);
  if (err) return err;

  err = await deleteRows(admin, "delivery_ratings", "customer_id", customerId, true);
  if (err) return err;

  err = await deleteRows(admin, "delivery_order_ratings", "customer_id", customerId, true);
  if (err) return err;

  err = await deleteRows(admin, "delivery_orders", "customer_id", customerId);
  if (err) return err;

  // customer_addresses has ON DELETE CASCADE, but explicit delete is safer
  err = await deleteRows(admin, "customer_addresses", "customer_id", customerId, true);
  if (err) return err;

  return deleteRows(admin, "customers", "id", customerId);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Unauthorized", details: "Missing Authorization header" }, 401);
    }

    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) {
      return jsonResponse({ error: "Unauthorized", details: "Missing JWT in Authorization header" }, 401);
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(jwt);

    if (userError || !user) {
      console.error("[delete-account] Auth error:", userError?.message ?? userError);
      return jsonResponse({
        error: "Unauthorized",
        details: userError?.message ?? "No user found in token",
      }, 401);
    }

    const userId = user.id;
    console.log("[delete-account] User authenticated:", userId);

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!serviceRoleKey) {
      return jsonResponse({
        error: "Server misconfiguration",
        details: "SUPABASE_SERVICE_ROLE_KEY not set",
      }, 500);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRoleKey,
    );

    console.log(`[delete-account] Start deletion for user ${userId}`);

    // Resolve customers linked to this auth user
    const { data: customers, error: customersLookupError } = await supabaseAdmin
      .from("customers")
      .select("id")
      .eq("user_id", userId);

    if (customersLookupError) {
      return jsonResponse({
        error: "Failed to lookup customer profile",
        details: customersLookupError.message ?? String(customersLookupError),
      }, 500);
    }

    for (const customer of customers ?? []) {
      const err = await deleteCustomerData(supabaseAdmin, customer.id as string);
      if (err) {
        return jsonResponse({
          error: "Failed to delete customer data",
          details: err,
        }, 500);
      }
    }

    // App-specific data tied directly to auth.users
    let err = await deleteRows(supabaseAdmin, "user_fcm_tokens", "user_id", userId, true);
    if (err) return jsonResponse({ error: "Failed to delete push tokens", details: err }, 500);

    err = await deleteRows(supabaseAdmin, "favorites", "user_id", userId, true);
    if (err) return jsonResponse({ error: "Failed to delete favorites", details: err }, 500);

    err = await deleteRows(supabaseAdmin, "cart_drafts", "user_id", userId, true);
    if (err) return jsonResponse({ error: "Failed to delete cart drafts", details: err }, 500);

    // Detach shared addresses instead of deleting them
    const { error: addressesError } = await supabaseAdmin
      .from("addresses")
      .update({ created_by: null })
      .eq("created_by", userId);
    if (addressesError && !addressesError.message?.includes("does not exist")) {
      return jsonResponse({
        error: "Failed to detach addresses",
        details: addressesError.message ?? String(addressesError),
      }, 500);
    }

    err = await deleteRows(supabaseAdmin, "user_profiles", "id", userId);
    if (err) {
      return jsonResponse({ error: "Failed to delete user profile", details: err }, 500);
    }

    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (deleteError) {
      return jsonResponse({
        error: "Failed to delete auth user",
        details: deleteError.message ?? String(deleteError),
      }, 500);
    }

    console.log(`[delete-account] Successfully deleted user ${userId}`);
    return jsonResponse({ success: true }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[delete-account] Unexpected error:", message);
    return jsonResponse({ error: message }, 500);
  }
});
