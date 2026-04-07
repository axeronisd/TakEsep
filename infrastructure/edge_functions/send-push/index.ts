// ═══════════════════════════════════════════════════════════════
// Supabase Edge Function: send-push
//
// Receives delivery_orders webhook events and dispatches
// Firebase Cloud Messaging notifications to relevant users.
//
// DEPLOY:
//   supabase functions deploy send-push --project-ref YOUR_REF
//
// WEBHOOK SETUP (Supabase Dashboard → Database → Webhooks):
//   Table: delivery_orders
//   Events: INSERT, UPDATE
//   Type: Supabase Edge Function
//   Function: send-push
//
// ENV VARS (set in Supabase Dashboard → Edge Functions → send-push):
//   FIREBASE_SERVICE_ACCOUNT_KEY: {...} (JSON string)
//   SUPABASE_SERVICE_ROLE_KEY: auto-injected
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Google OAuth2 for FCM HTTP v1 API
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "akjol-delivery";

serve(async (req: Request) => {
  try {
    const payload = await req.json();
    const { type, table, record, old_record } = payload;

    // Only process delivery_orders changes
    if (table !== "delivery_orders") {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const newStatus = record?.status;
    const oldStatus = old_record?.status;
    const orderId = record?.id;

    // Determine event type based on status transition
    let event: string | null = null;

    if (type === "INSERT" && newStatus === "pending") {
      event = "new_order";
    } else if (type === "UPDATE" && newStatus !== oldStatus) {
      switch (newStatus) {
        case "ready":
          event = "courier_needed";
          break;
        case "courier_assigned":
          event = "courier_found";
          break;
        case "picked_up":
          event = "picked_up";
          break;
        case "delivered":
          event = "delivered";
          break;
      }
    }

    if (!event || !orderId) {
      return new Response(JSON.stringify({ skipped: true, reason: "no_event" }), {
        status: 200,
      });
    }

    // Get push targets from DB
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: targets, error } = await supabase.rpc("rpc_get_push_targets", {
      p_order_id: orderId,
      p_event: event,
    });

    if (error) {
      console.error("RPC error:", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    const tokens = targets?.tokens ?? [];

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, event }), { status: 200 });
    }

    // Send FCM notifications
    // NOTE: For production, use Google OAuth2 service account token
    // For now, use legacy FCM key (simpler setup)
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

    if (!fcmServerKey) {
      console.warn("FCM_SERVER_KEY not set, logging notifications:");
      for (const t of tokens) {
        console.log(`  → [${event}] ${t.title}: ${t.body}`);
      }
      return new Response(
        JSON.stringify({ event, would_send: tokens.length }),
        { status: 200 }
      );
    }

    let sent = 0;
    for (const t of tokens) {
      try {
        const res = await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `key=${fcmServerKey}`,
          },
          body: JSON.stringify({
            to: t.token,
            notification: {
              title: t.title,
              body: t.body,
              sound: "default",
            },
            data: {
              order_id: orderId,
              event: event,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          }),
        });

        if (res.ok) sent++;
        else console.error(`FCM error for token ${t.token}:`, await res.text());
      } catch (e) {
        console.error(`Failed to send to ${t.token}:`, e);
      }
    }

    return new Response(
      JSON.stringify({ event, sent, total: tokens.length }),
      { status: 200 }
    );
  } catch (err) {
    console.error("Edge function error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
