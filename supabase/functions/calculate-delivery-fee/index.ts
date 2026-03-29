// supabase/functions/calculate-delivery-fee/index.ts
// Calculates delivery fee based on transport type and time of day
// Deploy: supabase functions deploy calculate-delivery-fee

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const TARIFFS: Record<string, { day: number; night: number }> = {
  bicycle: { day: 100, night: 150 },
  motorcycle: { day: 100, night: 150 },
  truck: { day: 150, night: 250 },
}

const PLATFORM_COMMISSION = 0.15 // 15% goes to AkJol platform
const NIGHT_START = 21 // 21:00
const NIGHT_END = 7   // 07:00

function isNightTime(): boolean {
  const hour = new Date().getHours()
  return hour >= NIGHT_START || hour < NIGHT_END
}

serve(async (req) => {
  try {
    const { transport_type, items_total } = await req.json()

    if (!transport_type || !TARIFFS[transport_type]) {
      return new Response(
        JSON.stringify({ error: 'Invalid transport type' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const tariff = TARIFFS[transport_type]
    const isNight = isNightTime()
    const deliveryFee = isNight ? tariff.night : tariff.day
    const platformEarning = Math.round(deliveryFee * PLATFORM_COMMISSION)
    const courierEarning = deliveryFee - platformEarning
    const total = (items_total || 0) + deliveryFee

    return new Response(
      JSON.stringify({
        delivery_fee: deliveryFee,
        courier_earning: courierEarning,
        platform_earning: platformEarning,
        is_night_tariff: isNight,
        total: total,
        tariff_label: isNight ? 'Ночной тариф' : 'Дневной тариф',
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
