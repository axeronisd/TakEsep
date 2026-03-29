-- ═══════════════════════════════════════════════════════════════
-- AkJol Delivery — Database Schema
-- Run in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ─── Transport Types ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS transport_types (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT,
  max_weight_kg DECIMAL NOT NULL DEFAULT 10,
  day_price DECIMAL NOT NULL DEFAULT 100,
  night_price DECIMAL NOT NULL DEFAULT 150
);

INSERT INTO transport_types (id, name, icon, max_weight_kg, day_price, night_price) VALUES
  ('bicycle',    'Велосипед',  'pedal_bike',        10,  100, 150),
  ('motorcycle', 'Мотоцикл',   'two_wheeler',       20,  100, 150),
  ('truck',      'Грузовой',   'local_shipping',   200,  150, 250)
ON CONFLICT (id) DO NOTHING;

-- ─── Delivery Settings (per warehouse/business) ────────────
CREATE TABLE IF NOT EXISTS delivery_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT false,
  delivery_radius_km DECIMAL NOT NULL DEFAULT 3,
  min_order_amount DECIMAL NOT NULL DEFAULT 0,
  address TEXT,
  latitude DECIMAL,
  longitude DECIMAL,
  available_transports TEXT[] DEFAULT ARRAY['bicycle'],
  night_starts_at TIME DEFAULT '21:00',
  working_hours JSONB DEFAULT '{"mon":["09:00","21:00"],"tue":["09:00","21:00"],"wed":["09:00","21:00"],"thu":["09:00","21:00"],"fri":["09:00","21:00"],"sat":["09:00","21:00"],"sun":["10:00","20:00"]}',
  description TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(warehouse_id)
);

-- ─── Customers ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  phone TEXT NOT NULL UNIQUE,
  name TEXT,
  default_address TEXT,
  default_lat DECIMAL,
  default_lng DECIMAL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── Customer Addresses ────────────────────────────────────
CREATE TABLE IF NOT EXISTS customer_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  label TEXT DEFAULT 'Дом',
  address TEXT NOT NULL,
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── Couriers ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS couriers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  transport_type TEXT NOT NULL REFERENCES transport_types(id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_online BOOLEAN NOT NULL DEFAULT false,
  current_lat DECIMAL,
  current_lng DECIMAL,
  bank_balance DECIMAL NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── Delivery Orders ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS delivery_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT NOT NULL UNIQUE,
  customer_id UUID NOT NULL REFERENCES customers(id),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  courier_id UUID REFERENCES couriers(id),
  
  -- Status
  status TEXT NOT NULL DEFAULT 'pending',
  
  -- Transport negotiation
  requested_transport TEXT NOT NULL REFERENCES transport_types(id),
  approved_transport TEXT REFERENCES transport_types(id),
  transport_comment TEXT,
  
  -- Pickup (business location)
  pickup_address TEXT,
  pickup_lat DECIMAL,
  pickup_lng DECIMAL,
  
  -- Delivery (customer location)
  delivery_address TEXT NOT NULL,
  delivery_lat DECIMAL NOT NULL,
  delivery_lng DECIMAL NOT NULL,
  
  -- Money
  items_total DECIMAL NOT NULL DEFAULT 0,
  delivery_fee DECIMAL NOT NULL DEFAULT 0,
  courier_earning DECIMAL NOT NULL DEFAULT 0,
  platform_earning DECIMAL NOT NULL DEFAULT 0,
  total DECIMAL NOT NULL DEFAULT 0,
  
  -- Payment
  payment_method TEXT NOT NULL DEFAULT 'cash',
  is_paid BOOLEAN NOT NULL DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  
  estimated_minutes INT,
  customer_note TEXT,
  cancel_reason TEXT
);

-- ─── Order Items ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS delivery_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES delivery_orders(id) ON DELETE CASCADE,
  product_id UUID,
  name TEXT NOT NULL,
  quantity DECIMAL NOT NULL DEFAULT 1,
  unit_price DECIMAL NOT NULL DEFAULT 0,
  total DECIMAL NOT NULL DEFAULT 0
);

-- ─── Courier Shifts ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS courier_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID NOT NULL REFERENCES couriers(id),
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ,
  start_bank DECIMAL NOT NULL DEFAULT 0,
  total_collected DECIMAL NOT NULL DEFAULT 0,
  total_orders INT NOT NULL DEFAULT 0,
  courier_earning DECIMAL NOT NULL DEFAULT 0,
  platform_earning DECIMAL NOT NULL DEFAULT 0,
  amount_to_return DECIMAL NOT NULL DEFAULT 0,
  is_settled BOOLEAN NOT NULL DEFAULT false
);

-- ─── Business Settlements ──────────────────────────────────
CREATE TABLE IF NOT EXISTS business_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_orders INT NOT NULL DEFAULT 0,
  total_items_amount DECIMAL NOT NULL DEFAULT 0,
  is_paid BOOLEAN NOT NULL DEFAULT false,
  paid_at TIMESTAMPTZ
);

-- ─── Delivery Ratings ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS delivery_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES delivery_orders(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id),
  courier_rating INT CHECK (courier_rating BETWEEN 1 AND 5),
  store_rating INT CHECK (store_rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════
-- RLS Policies
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE transport_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE couriers ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE courier_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_ratings ENABLE ROW LEVEL SECURITY;

-- Transport types: readable by all authenticated
CREATE POLICY "transport_types_read" ON transport_types FOR SELECT TO authenticated USING (true);

-- Delivery settings: readable by all, writable by owner
CREATE POLICY "delivery_settings_read" ON delivery_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "delivery_settings_write" ON delivery_settings FOR ALL TO authenticated USING (true);

-- Customers: read/write own data
CREATE POLICY "customers_all" ON customers FOR ALL TO authenticated USING (true);

-- Customer addresses
CREATE POLICY "customer_addresses_all" ON customer_addresses FOR ALL TO authenticated USING (true);

-- Couriers
CREATE POLICY "couriers_all" ON couriers FOR ALL TO authenticated USING (true);

-- Delivery orders
CREATE POLICY "delivery_orders_all" ON delivery_orders FOR ALL TO authenticated USING (true);

-- Order items
CREATE POLICY "delivery_order_items_all" ON delivery_order_items FOR ALL TO authenticated USING (true);

-- Courier shifts
CREATE POLICY "courier_shifts_all" ON courier_shifts FOR ALL TO authenticated USING (true);

-- Business settlements
CREATE POLICY "business_settlements_all" ON business_settlements FOR ALL TO authenticated USING (true);

-- Delivery ratings
CREATE POLICY "delivery_ratings_all" ON delivery_ratings FOR ALL TO authenticated USING (true);

-- ═══════════════════════════════════════════════════════════════
-- Realtime subscriptions for order status changes
-- ═══════════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE delivery_orders;
ALTER PUBLICATION supabase_realtime ADD TABLE couriers;
