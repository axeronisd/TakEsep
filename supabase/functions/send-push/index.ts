// supabase/functions/send-push/index.ts
// Sends push notifications via FCM v1 HTTP API
// Deploy: supabase functions deploy send-push
//
// Required env vars (set in Supabase Dashboard > Edge Functions > Secrets):
//   FIREBASE_PROJECT_ID      - Firebase project ID
//   FIREBASE_SERVICE_ACCOUNT - JSON string of Firebase service account key
//
// Expected payload:
// {
//   "user_id": "uuid",         — looks up fcm_token from customers/couriers
//   "fcm_token": "...",        — OR provide token directly
//   "title": "Новый заказ!",
//   "body": "Заказ AJ-20260407-123 ожидает подтверждения",
//   "data": { "order_id": "...", "type": "new_order" }
// }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ─── JWT for FCM v1 ─────────────────────────────────────────
async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "RS256", typ: "JWT" }
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }

  const encode = (obj: any) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "")

  const unsignedToken = `${encode(header)}.${encode(payload)}`

  // Import private key
  const pemBody = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "")

  const binaryKey = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0))

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedToken)
  )

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")

  const jwt = `${unsignedToken}.${sig}`

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const tokenData = await tokenRes.json()
  if (!tokenData.access_token) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`)
  }
  return tokenData.access_token
}

// ─── Main handler ────────────────────────────────────────────
serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { user_id, fcm_token, title, body, data } = await req.json()

    // Resolve FCM token
    let token = fcm_token
    if (!token && user_id) {
      // Try customers table first, then couriers
      const supabase = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
      )

      const { data: customer } = await supabase
        .from("customers")
        .select("fcm_token")
        .eq("user_id", user_id)
        .maybeSingle()

      if (customer?.fcm_token) {
        token = customer.fcm_token
      } else {
        const { data: courier } = await supabase
          .from("couriers")
          .select("fcm_token")
          .eq("user_id", user_id)
          .maybeSingle()

        token = courier?.fcm_token
      }
    }

    if (!token) {
      return new Response(
        JSON.stringify({ error: "No FCM token found", sent: false }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Get Firebase credentials
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID")
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")

    if (!projectId || !serviceAccountJson) {
      return new Response(
        JSON.stringify({ error: "Firebase not configured", sent: false }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    const accessToken = await getAccessToken(serviceAccount)

    // Send via FCM v1 HTTP API
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: title || "AkJol",
              body: body || "",
            },
            data: data || {},
            android: {
              priority: "high",
              notification: {
                channel_id: "orders",
                sound: "default",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          },
        }),
      }
    )

    const fcmData = await fcmRes.json()

    if (!fcmRes.ok) {
      console.error("FCM error:", JSON.stringify(fcmData))
      return new Response(
        JSON.stringify({ error: fcmData.error?.message || "FCM error", sent: false }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    return new Response(
      JSON.stringify({ sent: true, message_id: fcmData.name }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (e) {
    console.error("send-push error:", e)
    return new Response(
      JSON.stringify({ error: e.message, sent: false }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
