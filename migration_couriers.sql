-- ═══════════════════════════════════════════════════════════════════
-- Migration: Courier Management System for Ak Jol
-- Run this in Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. COURIERS TABLE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS couriers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  access_key TEXT,                          -- 6-digit key from admin
  courier_type TEXT DEFAULT 'freelance',    -- 'freelance' or 'store'
  transport_type TEXT DEFAULT 'bicycle',    -- 'bicycle', 'motorcycle', 'truck'
  is_active BOOLEAN DEFAULT true,
  is_online BOOLEAN DEFAULT false,
  bank_balance REAL DEFAULT 0,
  current_lat DOUBLE PRECISION,
  current_lng DOUBLE PRECISION,
  location_updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add access_key column if table already exists
ALTER TABLE couriers ADD COLUMN IF NOT EXISTS access_key TEXT;

-- Index for phone + key lookup
CREATE INDEX IF NOT EXISTS idx_couriers_phone ON couriers(phone);
CREATE INDEX IF NOT EXISTS idx_couriers_access_key ON couriers(access_key);

ALTER TABLE couriers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Couriers full access" ON couriers;
CREATE POLICY "Couriers full access"
  ON couriers FOR ALL
  USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────
-- 2. COURIER_WAREHOUSE (linking couriers to warehouses)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS courier_warehouse (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID NOT NULL REFERENCES couriers(id) ON DELETE CASCADE,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT true,
  left_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(courier_id, warehouse_id)
);

ALTER TABLE courier_warehouse ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Courier warehouse full access" ON courier_warehouse;
CREATE POLICY "Courier warehouse full access"
  ON courier_warehouse FOR ALL
  USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────
-- 3. COURIER_SHIFTS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS courier_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID NOT NULL REFERENCES couriers(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ,
  start_bank REAL DEFAULT 0,
  total_collected REAL DEFAULT 0,
  total_orders INTEGER DEFAULT 0,
  courier_earning REAL DEFAULT 0,
  platform_earning REAL DEFAULT 0,
  amount_to_return REAL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE courier_shifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Courier shifts full access" ON courier_shifts;
CREATE POLICY "Courier shifts full access"
  ON courier_shifts FOR ALL
  USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────
-- 4. RPC: Courier key login
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION rpc_courier_key_login(p_phone TEXT, p_key TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_courier RECORD;
  v_warehouses JSON;
BEGIN
  -- Find courier by phone + key
  SELECT * INTO v_courier
  FROM couriers
  WHERE phone = p_phone
    AND access_key = p_key
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('found', false);
  END IF;

  -- Get linked warehouses
  SELECT COALESCE(json_agg(json_build_object(
    'warehouse_id', cw.warehouse_id,
    'warehouse_name', w.name,
    'warehouse_address', w.address,
    'warehouse_lat', w.latitude,
    'warehouse_lng', w.longitude
  )), '[]'::json) INTO v_warehouses
  FROM courier_warehouse cw
  JOIN warehouses w ON w.id = cw.warehouse_id
  WHERE cw.courier_id = v_courier.id
    AND cw.is_active = true;

  RETURN json_build_object(
    'found', true,
    'courier', json_build_object(
      'id', v_courier.id,
      'user_id', v_courier.user_id,
      'name', v_courier.name,
      'phone', v_courier.phone,
      'courier_type', v_courier.courier_type,
      'transport_type', v_courier.transport_type,
      'is_online', v_courier.is_online,
      'bank_balance', v_courier.bank_balance
    ),
    'warehouses', v_warehouses,
    'is_store_courier', (SELECT COUNT(*) > 0 FROM courier_warehouse WHERE courier_id = v_courier.id AND is_active = true)
  );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- DONE! Run this in Supabase SQL Editor, then:
-- 1. Add couriers via Admin app
-- 2. Couriers login with phone + 6-digit key
-- ═══════════════════════════════════════════════════════════════════
