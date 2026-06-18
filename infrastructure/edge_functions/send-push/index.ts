// ═══════════════════════════════════════════════════════════════
// Supabase Edge Function: send-push
//
// Receives delivery_orders webhook events and dispatches
// Firebase Cloud Messaging notifications to relevant users.
// Supports both FCM HTTP v1 API and Legacy API fallback.
//
// DEPLOY:
//   supabase functions deploy send-push --project-ref YOUR_REF
//
// ENV VARS (set in Supabase Dashboard → Edge Functions → send-push):
//   FIREBASE_SERVICE_ACCOUNT_KEY: {...} (JSON string from firebase credentials)
//   FIREBASE_PROJECT_ID: your-firebase-project-id (if not using service account default)
//   FCM_SERVER_KEY: Legacy FCM key (only if Legacy API is enabled)
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
let FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "akjol-delivery";

async function getAccessToken(serviceAccountKeyJson: string): Promise<string> {
  const credentials = JSON.parse(serviceAccountKeyJson);
  if (credentials.project_id) {
    FIREBASE_PROJECT_ID = credentials.project_id;
  }
  const client = new JWT({
    email: credentials.client_email,
    key: credentials.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const token = await client.getAccessToken();
  if (!token.token) {
    throw new Error("Failed to get Google OAuth2 token");
  }
  return token.token;
}

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

    // Check credentials
    const serviceAccountKey = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

    let accessToken: string | null = null;
    let useHttpV1 = false;

    if (serviceAccountKey) {
      try {
        accessToken = await getAccessToken(serviceAccountKey);
        useHttpV1 = true;
        console.log("Using FCM HTTP v1 API with Service Account Token");
      } catch (err) {
        console.error("Failed to generate Google OAuth2 token, falling back to legacy:", err);
      }
    }

    if (!useHttpV1 && !fcmServerKey) {
      console.warn("Neither FIREBASE_SERVICE_ACCOUNT_KEY nor FCM_SERVER_KEY is set. Logging notification data:");
      for (const t of tokens) {
        console.log(`  → [${event}] ${t.title}: ${t.body} (App: ${t.app_type}, Platform: ${t.device_platform})`);
      }
      return new Response(
        JSON.stringify({ event, would_send: tokens.length }),
        { status: 200 }
      );
    }

    let sent = 0;
    for (const t of tokens) {
      try {
        let res: Response;
        if (useHttpV1) {
          // Format custom sound name per application/platform for background alerts
          let androidSound: string | undefined = undefined;
          let apnsSound: string | undefined = undefined;

          if (t.app_type === "warehouse") {
            androidSound = "warehouse_order";
            apnsSound = "warehouse_order.mp3";
          } else if (t.app_type === "courier") {
            androidSound = "akjol_courier";
            apnsSound = "akjol_courier.mp3";
          }

          const messageBody = {
            message: {
              token: t.token,
              notification: {
                title: t.title,
                body: t.body,
              },
              data: {
                order_id: orderId,
                event: event,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              android: androidSound ? {
                notification: {
                  sound: androidSound,
                  channel_id: t.app_type === "warehouse" ? "delivery_orders" : (event === "courier_needed" ? "new_orders" : "order_status"),
                }
              } : undefined,
              apns: apnsSound ? {
                payload: {
                  aps: {
                    sound: apnsSound,
                  }
                }
              } : undefined,
            }
          };

          res = await fetch(
            `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${accessToken}`,
              },
              body: JSON.stringify(messageBody),
            }
          );
        } else {
          // Legacy API fallback
          res = await fetch("https://fcm.googleapis.com/fcm/send", {
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
        }

        if (res.ok) {
          sent++;
        } else {
          console.error(`FCM error for token ${t.token}:`, await res.text());
        }
      } catch (e) {
        console.error(`Failed to send to ${t.token}:`, e);
      }
    }

    return new Response(
      JSON.stringify({ event, sent, total: tokens.length, api: useHttpV1 ? "v1" : "legacy" }),
      { status: 200 }
    );
  } catch (err) {
    console.error("Edge function error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
