// @ts-nocheck
// ═══════════════════════════════════════════════════════════════
// TakEsep Push Notification Edge Function v2
//
// Two modes:
//   1. Direct call (POST with title/body/user_id) — existing API
//   2. Database Webhook (POST with type/table/record) — automatic
//
// Deploy: supabase functions deploy send-push
//
// Required secrets:
//   FIREBASE_PROJECT_ID=akjol-f479a
//   FIREBASE_SERVICE_ACCOUNT=<JSON string of service account key>
//
// This file runs in Deno (Supabase Edge Functions), not Node.js.
// ═══════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

// ── JWT for FCM v1 ──

async function getAccessToken(): Promise<string> {
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")
  if (!serviceAccountJson) throw new Error("FIREBASE_SERVICE_ACCOUNT not set")

  const sa = JSON.parse(serviceAccountJson)
  const now = Math.floor(Date.now() / 1000)

  const encode = (obj: any) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "")

  const header = encode({ alg: "RS256", typ: "JWT" })
  const claim = encode({
    iss: sa.client_email,
    sub: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })

  const pemBody = sa.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "")

  const binaryKey = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0))
  const key = await crypto.subtle.importKey(
    "pkcs8", binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"]
  )

  const toSign = new TextEncoder().encode(`${header}.${claim}`)
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, toSign)
  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")

  const jwt = `${header}.${claim}.${sig}`

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const data = await res.json()
  if (!data.access_token) throw new Error(`Token error: ${JSON.stringify(data)}`)
  return data.access_token
}

// ── Logging ──

async function logNotification(
  userId: string | null,
  appType: string,
  title: string,
  body: string,
  data: Record<string, string>,
  status: string,
  error?: string
) {
  try {
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
    await sb.from("push_notification_log").insert({
      user_id: userId,
      app_type: appType,
      title,
      body,
      data,
      status,
      error: error || null,
    })
  } catch (e) {
    console.error("[log] Failed to log notification:", e)
  }
}

// ── Send FCM ──

async function sendToToken(
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  channelId: string,
  soundName: string,
  data: Record<string, string> = {},
  userId?: string,
  appType?: string
) {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "akjol-f479a"
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
        android: {
          priority: "high",
          notification: {
            channel_id: channelId,
            sound: soundName,
            default_vibrate_timings: true,
            notification_priority: "PRIORITY_HIGH",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              "mutable-content": 1,
            },
          },
        },
        data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
      },
    }),
  })

  if (!resp.ok) {
    const err = await resp.text()
    console.error(`FCM error [${fcmToken.substring(0, 15)}...]: ${err}`)
    await logNotification(userId || null, appType || "unknown", title, body, data, "failed", err)
    // Clean up invalid tokens
    if (err.includes("UNREGISTERED") || err.includes("NOT_FOUND")) {
      const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
      await sb.from("user_fcm_tokens").delete().eq("fcm_token", fcmToken)
      console.log("Removed stale token")
    }
    return false
  }

  await logNotification(userId || null, appType || "unknown", title, body, data, "sent")
  return true
}

async function sendToUser(
  accessToken: string,
  userId: string,
  appType: string,
  title: string,
  body: string,
  channelId: string,
  soundName: string,
  data: Record<string, string> = {}
) {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
  const { data: tokens } = await sb
    .from("user_fcm_tokens")
    .select("fcm_token")
    .eq("user_id", userId)
    .eq("app_type", appType)

  if (!tokens || tokens.length === 0) {
    console.log(`No tokens for user ${userId} (${appType})`)
    return 0
  }

  let sent = 0
  for (const t of tokens) {
    const ok = await sendToToken(accessToken, t.fcm_token, title, body, channelId, soundName, data, userId, appType)
    if (ok) sent++
  }
  return sent
}

async function sendToAllOfType(
  accessToken: string,
  appType: string,
  title: string,
  body: string,
  channelId: string,
  soundName: string,
  data: Record<string, string> = {}
) {
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
  const { data: tokens } = await sb
    .from("user_fcm_tokens")
    .select("fcm_token, user_id")
    .eq("app_type", appType)

  if (!tokens || tokens.length === 0) return 0

  let sent = 0
  for (const t of tokens) {
    const ok = await sendToToken(accessToken, t.fcm_token, title, body, channelId, soundName, data, t.user_id, appType)
    if (ok) sent++
  }
  console.log(`Sent to ${sent}/${tokens.length} ${appType} devices`)
  return sent
}

// ── Main Handler ──

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const payload = await req.json()

    // Detect mode: webhook vs direct call
    const isWebhook = payload.type && payload.table && payload.record

    let accessToken: string
    try {
      accessToken = await getAccessToken()
    } catch (e) {
      console.error("FCM auth error:", e)
      return new Response(
        JSON.stringify({ error: "Firebase auth failed" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (isWebhook) {
      // ═══ DATABASE WEBHOOK MODE ═══
      return await handleWebhook(accessToken, payload)
    } else {
      // ═══ DIRECT CALL MODE (existing API) ═══
      return await handleDirectCall(accessToken, payload)
    }
  } catch (e) {
    console.error("send-push error:", e)
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})

// ── Webhook Handler ──

async function handleWebhook(accessToken: string, payload: any) {
  const { type, table, record, old_record } = payload
  console.log(`[webhook] ${type} on ${table}`)

  const orderNum = (id: string) => (id || "").substring(0, 8).toUpperCase()

  // ═══ delivery_orders ═══
  if (table === "delivery_orders") {
    // INSERT: new order → notify all couriers + warehouse
    if (type === "INSERT" && record.status === "pending") {
      const num = orderNum(record.id)
      const results: string[] = []

      const courierSent = await sendToAllOfType(
        accessToken, "courier",
        "Новый заказ",
        `#${num} — ${record.delivery_address || "ожидает курьера"}`,
        "new_orders", "new_order_alert",
        { order_id: record.id, type: "new_order" }
      )
      results.push(`courier:${courierSent}`)

      if (record.warehouse_id) {
        const whSent = await sendToAllOfType(
          accessToken, "warehouse",
          "Новый заказ",
          `#${num} — поступил новый заказ`,
          "delivery_orders", "new_order_alert",
          { order_id: record.id, type: "new_order" }
        )
        results.push(`warehouse:${whSent}`)
      }

      return jsonOk({ processed: true, results })
    }

    // UPDATE: status changed
    if (type === "UPDATE" && record.status !== old_record?.status) {
      const num = orderNum(record.id)
      const status = record.status
      const results: string[] = []

      // → Notify CUSTOMER about status changes
      if (record.customer_id) {
        const templates: Record<string, { title: string; body: string; sound: string }> = {
          accepted: {
            title: "Курьер принял заказ",
            body: `Заказ #${num} взят в работу`,
            sound: "order_accepted",
          },
          picked_up: {
            title: "Заказ забран",
            body: `Курьер забрал #${num} и уже в пути`,
            sound: "order_pickup",
          },
          delivered: {
            title: "Заказ доставлен",
            body: `#${num} — доставка завершена`,
            sound: "order_delivered",
          },
          cancelled: {
            title: "Заказ отменён",
            body: `#${num} — заказ отменён`,
            sound: "order_cancelled",
          },
        }

        const tmpl = templates[status]
        if (tmpl) {
          const sent = await sendToUser(
            accessToken, record.customer_id, "customer",
            tmpl.title, tmpl.body, "order_status", tmpl.sound,
            { order_id: record.id, type: "order_status", status }
          )
          results.push(`customer:${sent}`)
        }
      }

      // → Notify COURIER if order cancelled by customer
      if (status === "cancelled" && record.courier_id) {
        const sent = await sendToUser(
          accessToken, record.courier_id, "courier",
          "Заказ отменён",
          `#${num} — клиент отменил заказ`,
          "order_status", "order_cancelled",
          { order_id: record.id, type: "order_cancelled" }
        )
        results.push(`courier_cancel:${sent}`)
      }

      // → Notify WAREHOUSE if order cancelled
      if (status === "cancelled" && record.warehouse_id) {
        const sent = await sendToAllOfType(
          accessToken, "warehouse",
          "Заказ отменён",
          `#${num} — заказ отменён клиентом`,
          "delivery_orders", "order_cancelled",
          { order_id: record.id, type: "order_cancelled" }
        )
        results.push(`warehouse_cancel:${sent}`)
      }

      // → Notify COURIER if assigned directly
      if (
        record.courier_id &&
        record.courier_id !== old_record?.courier_id
      ) {
        const sent = await sendToUser(
          accessToken, record.courier_id, "courier",
          "Заказ назначен вам",
          `#${num} — проверьте детали`,
          "new_orders", "new_order_alert",
          { order_id: record.id, type: "order_assigned" }
        )
        results.push(`courier_assign:${sent}`)
      }

      return jsonOk({ processed: true, results })
    }
  }

  // ═══ delivery_order_messages ═══
  if (table === "delivery_order_messages" && type === "INSERT") {
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
    const { data: order } = await sb
      .from("delivery_orders")
      .select("customer_id, courier_id")
      .eq("id", record.order_id)
      .single()

    if (order) {
      const senderId = record.sender_id
      const isFromCustomer = senderId === order.customer_id
      const recipientId = isFromCustomer ? order.courier_id : order.customer_id
      const recipientApp = isFromCustomer ? "courier" : "customer"
      const senderLabel = isFromCustomer ? "Клиент" : "Курьер"

      if (recipientId) {
        const msgPreview = (record.content || "").substring(0, 50)
        const sent = await sendToUser(
          accessToken, recipientId, recipientApp,
          `Сообщение от ${senderLabel.toLowerCase()}а`,
          msgPreview || "Новое сообщение",
          "chat_messages", "chat_message",
          { order_id: record.order_id, type: "chat_message" }
        )
        return jsonOk({ processed: true, chat_sent: sent })
      }
    }
    return jsonOk({ processed: true, chat_sent: 0 })
  }

  return jsonOk({ processed: false, reason: "unhandled table/type" })
}

// ── Direct Call Handler (backward compatible) ──

async function handleDirectCall(accessToken: string, payload: any) {
  const { user_id, fcm_token, title, body, data, app_type } = payload

  let token = fcm_token
  if (!token && user_id) {
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

    // Try user_fcm_tokens table first
    const { data: tokens } = await sb
      .from("user_fcm_tokens")
      .select("fcm_token")
      .eq("user_id", user_id)
      .limit(1)

    if (tokens && tokens.length > 0) {
      token = tokens[0].fcm_token
    } else {
      // Fallback: try customers/couriers tables
      const { data: customer } = await sb
        .from("customers")
        .select("fcm_token")
        .eq("user_id", user_id)
        .maybeSingle()

      if (customer?.fcm_token) {
        token = customer.fcm_token
      } else {
        const { data: courier } = await sb
          .from("couriers")
          .select("fcm_token")
          .eq("user_id", user_id)
          .maybeSingle()
        token = courier?.fcm_token
      }
    }
  }

  if (!token) {
    return new Response(
      JSON.stringify({ error: "No FCM token found", sent: false }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }

  const ok = await sendToToken(
    accessToken, token,
    title || "AkJol", body || "",
    data?.channel_id || "general",
    data?.sound || "default",
    data || {}
  )

  return new Response(
    JSON.stringify({ sent: ok }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  )
}

function jsonOk(data: any) {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}
