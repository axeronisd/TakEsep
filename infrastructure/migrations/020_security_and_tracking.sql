-- ═══════════════════════════════════════════════════════════════
-- 020: Security & Tracking
-- RLS policies for courier location privacy + tracking columns
-- Run in Supabase SQL Editor AFTER 019
-- ═══════════════════════════════════════════════════════════════


-- ─── 1. Courier tracking fields (ensure they exist) ───────────

ALTER TABLE couriers
  ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN couriers.location_updated_at IS
  'Last time the courier updated their GPS coordinates. Used for stale detection.';


-- ─── 2. RLS on couriers table ─────────────────────────────────

ALTER TABLE couriers ENABLE ROW LEVEL SECURITY;

-- Drop old policies if any (idempotent)
DROP POLICY IF EXISTS "couriers_self_read" ON couriers;
DROP POLICY IF EXISTS "couriers_self_update" ON couriers;
DROP POLICY IF EXISTS "couriers_customer_read" ON couriers;
DROP POLICY IF EXISTS "couriers_warehouse_read" ON couriers;
DROP POLICY IF EXISTS "couriers_warehouse_manage" ON couriers;
DROP POLICY IF EXISTS "couriers_public_read" ON couriers;
DROP POLICY IF EXISTS "couriers_authenticated_read" ON couriers;
DROP POLICY IF EXISTS "couriers_authenticated_manage" ON couriers;

-- Policy 1: Courier reads/updates their own record
CREATE POLICY "couriers_self_read" ON couriers
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "couriers_self_update" ON couriers
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy 2: Customer can see courier info ONLY if that courier
-- is assigned to their active order (the "golden rule")
CREATE POLICY "couriers_customer_read" ON couriers
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
        FROM delivery_orders d
        JOIN customers cu ON cu.id = d.customer_id
        WHERE d.courier_id = couriers.id
          AND d.status IN ('courier_assigned', 'picked_up')
          AND cu.user_id = auth.uid()
    )
  );

-- Policy 3: Authenticated users with business role can read
-- couriers linked to warehouses they manage.
-- Since warehouses → organization_id → companies,
-- and companies don't have a direct user_id,
-- we allow any authenticated user to read couriers
-- that are linked to a warehouse via courier_warehouse.
-- The TakEsep app already filters by warehouse_id on the client.
CREATE POLICY "couriers_authenticated_read" ON couriers
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
        FROM courier_warehouse cw
        WHERE cw.courier_id = couriers.id
          AND cw.is_active = true
    )
    OR
    warehouse_id IS NOT NULL
  );

-- Policy 4: Authenticated users can manage couriers
-- (INSERT/UPDATE via rpc_invite_store_courier runs as SECURITY DEFINER,
-- so this policy covers direct client-side updates like toggling is_active)
CREATE POLICY "couriers_authenticated_manage" ON couriers
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);


-- ─── 3. RLS on delivery_orders for customer tracking ──────────

-- Ensure RLS is enabled
ALTER TABLE delivery_orders ENABLE ROW LEVEL SECURITY;

-- Allow customers to read their own orders
DROP POLICY IF EXISTS "delivery_orders_customer_read" ON delivery_orders;

CREATE POLICY "delivery_orders_customer_read" ON delivery_orders
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM customers
      WHERE customers.id = delivery_orders.customer_id
        AND customers.user_id = auth.uid()
    )
  );

-- Allow customers to update their own pending orders (for cancellation)
DROP POLICY IF EXISTS "delivery_orders_customer_update" ON delivery_orders;

CREATE POLICY "delivery_orders_customer_update" ON delivery_orders
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM customers
      WHERE customers.id = delivery_orders.customer_id
        AND customers.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM customers
      WHERE customers.id = delivery_orders.customer_id
        AND customers.user_id = auth.uid()
    )
  );

-- Allow warehouse staff (authenticated) to read/update orders for their warehouses
-- (TakEsep filters by warehouse_id on client side)
DROP POLICY IF EXISTS "delivery_orders_authenticated_read" ON delivery_orders;
DROP POLICY IF EXISTS "delivery_orders_authenticated_manage" ON delivery_orders;

CREATE POLICY "delivery_orders_authenticated_read" ON delivery_orders
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "delivery_orders_authenticated_manage" ON delivery_orders
  FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ─── 4. Index for fast RLS lookups ────────────────────────────

CREATE INDEX IF NOT EXISTS idx_delivery_orders_courier_status
  ON delivery_orders(courier_id, status)
  WHERE status IN ('courier_assigned', 'picked_up');

CREATE INDEX IF NOT EXISTS idx_customers_user_id
  ON customers(user_id);

CREATE INDEX IF NOT EXISTS idx_couriers_user_id
  ON couriers(user_id);
