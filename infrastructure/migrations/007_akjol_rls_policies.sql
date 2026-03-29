-- =============================================
-- AkJol Delivery RLS Policies
-- Run AFTER 006_akjol_delivery.sql
-- =============================================

-- Enable RLS on all delivery tables
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE couriers ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE courier_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE courier_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_negotiation_log ENABLE ROW LEVEL SECURITY;

-- ─── CUSTOMERS ────────────────────────────────
-- Customers can read and update their own record
CREATE POLICY "customers_own_select" ON customers
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "customers_own_update" ON customers
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "customers_insert_self" ON customers
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Businesses can see customers who ordered from them
CREATE POLICY "customers_business_select" ON customers
  FOR SELECT USING (
    id IN (
      SELECT customer_id FROM delivery_orders
      WHERE warehouse_id IN (
        SELECT id FROM warehouses WHERE organization_id IN (
          SELECT company_id FROM employees WHERE id = auth.uid()
        )
      )
    )
  );

-- ─── DELIVERY SETTINGS ───────────────────────
-- Anyone can see active delivery settings (public storefront)
CREATE POLICY "delivery_settings_public_read" ON delivery_settings
  FOR SELECT USING (is_active = true);

-- Business owners can manage their own settings
CREATE POLICY "delivery_settings_owner_all" ON delivery_settings
  FOR ALL USING (
    warehouse_id IN (
      SELECT id FROM warehouses WHERE organization_id IN (
        SELECT company_id FROM employees WHERE id = auth.uid()
      )
    )
  );

-- ─── COURIERS ─────────────────────────────────
-- Couriers can see their own profile
CREATE POLICY "couriers_own_select" ON couriers
  FOR SELECT USING (user_id = auth.uid());

-- Business owners can manage their couriers
CREATE POLICY "couriers_business_all" ON couriers
  FOR ALL USING (
    warehouse_id IN (
      SELECT id FROM warehouses WHERE organization_id IN (
        SELECT company_id FROM employees WHERE id = auth.uid()
      )
    )
  );

-- Couriers can update their own status (online, location)
CREATE POLICY "couriers_self_update" ON couriers
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ─── DELIVERY ORDERS ─────────────────────────
-- Customers can see their own orders
CREATE POLICY "orders_customer_select" ON delivery_orders
  FOR SELECT USING (customer_id = auth.uid());

-- Customers can create orders
CREATE POLICY "orders_customer_insert" ON delivery_orders
  FOR INSERT WITH CHECK (customer_id = auth.uid());

-- Customers can update their orders (cancel, accept transport)
CREATE POLICY "orders_customer_update" ON delivery_orders
  FOR UPDATE USING (customer_id = auth.uid());

-- Business owners can see orders for their warehouse
CREATE POLICY "orders_business_select" ON delivery_orders
  FOR SELECT USING (
    warehouse_id IN (
      SELECT id FROM warehouses WHERE organization_id IN (
        SELECT company_id FROM employees WHERE id = auth.uid()
      )
    )
  );

-- Business owners can update orders (accept, reject, assign courier)
CREATE POLICY "orders_business_update" ON delivery_orders
  FOR UPDATE USING (
    warehouse_id IN (
      SELECT id FROM warehouses WHERE organization_id IN (
        SELECT company_id FROM employees WHERE id = auth.uid()
      )
    )
  );

-- Couriers can see accepted orders (available for pickup)
CREATE POLICY "orders_courier_available" ON delivery_orders
  FOR SELECT USING (
    status = 'accepted'
    OR courier_id IN (
      SELECT id FROM couriers WHERE user_id = auth.uid()
    )
  );

-- Couriers can update their assigned orders
CREATE POLICY "orders_courier_update" ON delivery_orders
  FOR UPDATE USING (
    courier_id IN (
      SELECT id FROM couriers WHERE user_id = auth.uid()
    )
  );

-- ─── DELIVERY ORDER ITEMS ────────────────────
-- Readable by order participants
CREATE POLICY "order_items_read" ON delivery_order_items
  FOR SELECT USING (
    order_id IN (
      SELECT id FROM delivery_orders WHERE
        customer_id = auth.uid()
        OR courier_id IN (SELECT id FROM couriers WHERE user_id = auth.uid())
        OR warehouse_id IN (
          SELECT id FROM warehouses WHERE organization_id IN (
            SELECT company_id FROM employees WHERE id = auth.uid()
          )
        )
    )
  );

-- Customers can insert items (when creating order)
CREATE POLICY "order_items_customer_insert" ON delivery_order_items
  FOR INSERT WITH CHECK (
    order_id IN (
      SELECT id FROM delivery_orders WHERE customer_id = auth.uid()
    )
  );

-- ─── COURIER SHIFTS ──────────────────────────
-- Couriers can manage their own shifts
CREATE POLICY "shifts_courier_all" ON courier_shifts
  FOR ALL USING (
    courier_id IN (
      SELECT id FROM couriers WHERE user_id = auth.uid()
    )
  );

-- Business can see shifts for their couriers
CREATE POLICY "shifts_business_select" ON courier_shifts
  FOR SELECT USING (
    courier_id IN (
      SELECT id FROM couriers WHERE warehouse_id IN (
        SELECT id FROM warehouses WHERE organization_id IN (
          SELECT company_id FROM employees WHERE id = auth.uid()
        )
      )
    )
  );

-- ─── COURIER SETTLEMENTS ─────────────────────
-- Couriers can see their settlements
CREATE POLICY "settlements_courier_select" ON courier_settlements
  FOR SELECT USING (
    courier_id IN (
      SELECT id FROM couriers WHERE user_id = auth.uid()
    )
  );

-- Business can manage settlements
CREATE POLICY "settlements_business_all" ON courier_settlements
  FOR ALL USING (
    courier_id IN (
      SELECT id FROM couriers WHERE warehouse_id IN (
        SELECT id FROM warehouses WHERE organization_id IN (
          SELECT company_id FROM employees WHERE id = auth.uid()
        )
      )
    )
  );

-- ─── DELIVERY REVIEWS ────────────────────────
-- Anyone can read reviews
CREATE POLICY "reviews_public_read" ON delivery_reviews
  FOR SELECT USING (true);

-- Customers can write reviews for their orders
CREATE POLICY "reviews_customer_insert" ON delivery_reviews
  FOR INSERT WITH CHECK (
    order_id IN (
      SELECT id FROM delivery_orders WHERE customer_id = auth.uid()
    )
  );

-- ─── TRANSPORT NEGOTIATION LOG ───────────────
-- Readable by order participants
CREATE POLICY "negotiation_read" ON transport_negotiation_log
  FOR SELECT USING (
    order_id IN (
      SELECT id FROM delivery_orders WHERE
        customer_id = auth.uid()
        OR warehouse_id IN (
          SELECT id FROM warehouses WHERE organization_id IN (
            SELECT company_id FROM employees WHERE id = auth.uid()
          )
        )
    )
  );

-- Business can insert negotiation entries
CREATE POLICY "negotiation_business_insert" ON transport_negotiation_log
  FOR INSERT WITH CHECK (
    order_id IN (
      SELECT id FROM delivery_orders WHERE
        warehouse_id IN (
          SELECT id FROM warehouses WHERE organization_id IN (
            SELECT company_id FROM employees WHERE id = auth.uid()
          )
        )
    )
  );

-- ─── REALTIME SUBSCRIPTIONS ──────────────────
-- Enable realtime for delivery_orders so all apps get updates
ALTER PUBLICATION supabase_realtime ADD TABLE delivery_orders;
ALTER PUBLICATION supabase_realtime ADD TABLE couriers;

-- ─── INDEXES FOR PERFORMANCE ─────────────────
CREATE INDEX IF NOT EXISTS idx_delivery_orders_customer ON delivery_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_warehouse ON delivery_orders(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_courier ON delivery_orders(courier_id);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_status ON delivery_orders(status);
CREATE INDEX IF NOT EXISTS idx_couriers_warehouse ON couriers(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_couriers_user ON couriers(user_id);
CREATE INDEX IF NOT EXISTS idx_courier_shifts_courier ON courier_shifts(courier_id);
