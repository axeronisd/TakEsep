-- ==============================================================
-- 032: Add price_per_km to transport_types and rewrite triggers
-- ==============================================================

-- 1. Add column to transport_types
ALTER TABLE transport_types ADD COLUMN IF NOT EXISTS price_per_km DECIMAL NOT NULL DEFAULT 50;

-- 1b. Create system_settings table for global configurations
CREATE TABLE IF NOT EXISTS system_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  courier_earning_rate DECIMAL NOT NULL DEFAULT 0.90
);

INSERT INTO system_settings (id, courier_earning_rate)
VALUES ('default', 0.90)
ON CONFLICT (id) DO NOTHING;

-- 2. Seed transport types
INSERT INTO transport_types (id, name, icon, max_weight_kg, day_price, night_price, price_per_km)
VALUES
  ('bicycle',    'Электровелосипед',  'pedal_bike',        10,  100, 150, 50),
  ('scooter',    'Муравей (трицикл)',  'two_wheeler',       20,  150, 200, 75),
  ('motorcycle', 'Мотоцикл',          'two_wheeler',       20,  100, 150, 50),
  ('truck',      'Грузовой',          'local_shipping',   200,  150, 250, 100)
ON CONFLICT (id) DO UPDATE SET
  price_per_km = EXCLUDED.price_per_km,
  name = EXCLUDED.name,
  icon = EXCLUDED.icon;

-- 3. Rewrite calculate_delivery_fee() trigger function to use Haversine formula and courier rate
CREATE OR REPLACE FUNCTION calculate_delivery_fee()
RETURNS TRIGGER AS $$
DECLARE
  v_lat1 DOUBLE PRECISION;
  v_lng1 DOUBLE PRECISION;
  v_lat2 DOUBLE PRECISION;
  v_lng2 DOUBLE PRECISION;
  v_distance_km DOUBLE PRECISION;
  v_price_per_km NUMERIC;
  v_min_price NUMERIC := 50;
  v_earning_rate NUMERIC;
  base_fee NUMERIC;
BEGIN
  -- Get warehouse coordinates if pickup coordinates are null
  IF NEW.pickup_lat IS NULL OR NEW.pickup_lng IS NULL THEN
    SELECT latitude, longitude INTO NEW.pickup_lat, NEW.pickup_lng
    FROM warehouses
    WHERE id = NEW.warehouse_id;
  END IF;

  -- If still null, try from delivery_settings
  IF NEW.pickup_lat IS NULL OR NEW.pickup_lng IS NULL THEN
    SELECT latitude, longitude INTO NEW.pickup_lat, NEW.pickup_lng
    FROM delivery_settings
    WHERE warehouse_id = NEW.warehouse_id
    LIMIT 1;
  END IF;

  -- Set inputs for distance calculation
  v_lat1 := radians(NEW.pickup_lat::double precision);
  v_lng1 := radians(NEW.pickup_lng::double precision);
  v_lat2 := radians(NEW.delivery_lat::double precision);
  v_lng2 := radians(NEW.delivery_lng::double precision);

  -- Distance via Haversine formula
  IF v_lat1 IS NOT NULL AND v_lng1 IS NOT NULL AND v_lat2 IS NOT NULL AND v_lng2 IS NOT NULL THEN
    DECLARE
      v_acos_val DOUBLE PRECISION;
    BEGIN
      v_acos_val := cos(v_lat1) * cos(v_lat2) * cos(v_lng2 - v_lng1) + sin(v_lat1) * sin(v_lat2);
      -- Bound acos input to avoid precision errors
      IF v_acos_val > 1.0 THEN
        v_acos_val := 1.0;
      ELSIF v_acos_val < -1.0 THEN
        v_acos_val := -1.0;
      END IF;
      v_distance_km := 6371.0 * acos(v_acos_val);
    EXCEPTION WHEN OTHERS THEN
      v_distance_km := 0.0;
    END;
  ELSE
    v_distance_km := 0.0;
  END IF;

  -- Fetch price_per_km
  SELECT price_per_km INTO v_price_per_km
  FROM transport_types
  WHERE id = NEW.requested_transport;

  IF v_price_per_km IS NULL THEN
    v_price_per_km := 50; -- Default fallback
  END IF;

  -- Calculate base delivery fee (price * km, min 50 som)
  base_fee := GREATEST(v_min_price, ROUND((v_distance_km * v_price_per_km)::numeric));

  -- Fetch global courier earning rate from system_settings
  BEGIN
    SELECT COALESCE(courier_earning_rate, 0.90) INTO v_earning_rate
    FROM system_settings
    WHERE id = 'default';
  EXCEPTION WHEN OTHERS THEN
    v_earning_rate := 0.90;
  END;

  IF v_earning_rate IS NULL THEN
    v_earning_rate := 0.90;
  END IF;

  NEW.courier_earning := ROUND(base_fee * v_earning_rate);
  NEW.platform_earning := base_fee - NEW.courier_earning;
  NEW.total := COALESCE(NEW.items_total, 0) + base_fee;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Rewrite recalculate_on_transport_change() trigger function
CREATE OR REPLACE FUNCTION recalculate_on_transport_change()
RETURNS TRIGGER AS $$
DECLARE
  v_lat1 DOUBLE PRECISION;
  v_lng1 DOUBLE PRECISION;
  v_lat2 DOUBLE PRECISION;
  v_lng2 DOUBLE PRECISION;
  v_distance_km DOUBLE PRECISION;
  v_price_per_km NUMERIC;
  v_min_price NUMERIC := 50;
  v_earning_rate NUMERIC;
  base_fee NUMERIC;
BEGIN
  -- 1. Recalculate distance and base delivery fee when approved_transport changes or is unset
  IF (NEW.approved_transport IS NOT NULL AND 
     (OLD.approved_transport IS NULL OR NEW.approved_transport != OLD.approved_transport)) OR
     (NEW.delivery_fee IS NULL) THEN

     -- Ensure coordinates are loaded
     IF NEW.pickup_lat IS NULL OR NEW.pickup_lng IS NULL THEN
       SELECT latitude, longitude INTO NEW.pickup_lat, NEW.pickup_lng
       FROM warehouses
       WHERE id = NEW.warehouse_id;
     END IF;

     IF NEW.pickup_lat IS NULL OR NEW.pickup_lng IS NULL THEN
       SELECT latitude, longitude INTO NEW.pickup_lat, NEW.pickup_lng
       FROM delivery_settings
       WHERE warehouse_id = NEW.warehouse_id
       LIMIT 1;
     END IF;

     -- Calculate inputs
     v_lat1 := radians(NEW.pickup_lat::double precision);
     v_lng1 := radians(NEW.pickup_lng::double precision);
     v_lat2 := radians(NEW.delivery_lat::double precision);
     v_lng2 := radians(NEW.delivery_lng::double precision);

     -- Distance via Haversine formula
     IF v_lat1 IS NOT NULL AND v_lng1 IS NOT NULL AND v_lat2 IS NOT NULL AND v_lng2 IS NOT NULL THEN
       DECLARE
         v_acos_val DOUBLE PRECISION;
       BEGIN
         v_acos_val := cos(v_lat1) * cos(v_lat2) * cos(v_lng2 - v_lng1) + sin(v_lat1) * sin(v_lat2);
         IF v_acos_val > 1.0 THEN
           v_acos_val := 1.0;
         ELSIF v_acos_val < -1.0 THEN
           v_acos_val := -1.0;
         END IF;
         v_distance_km := 6371.0 * acos(v_acos_val);
       EXCEPTION WHEN OTHERS THEN
         v_distance_km := 0.0;
       END;
     ELSE
       v_distance_km := 0.0;
     END IF;

     -- Fetch price_per_km
     SELECT price_per_km INTO v_price_per_km
     FROM transport_types
     WHERE id = NEW.approved_transport;

     IF v_price_per_km IS NULL THEN
       v_price_per_km := 50;
     END IF;

     -- Calculate base delivery fee (price * km, min 50 som)
     base_fee := GREATEST(v_min_price, ROUND((v_distance_km * v_price_per_km)::numeric));
     NEW.delivery_fee := base_fee;
     NEW.total := COALESCE(NEW.items_total, 0) + base_fee;
  END IF;

  -- 2. Always recalculate courier_earning and platform_earning based on global system rate
  BEGIN
    SELECT COALESCE(courier_earning_rate, 0.90) INTO v_earning_rate
    FROM system_settings
    WHERE id = 'default';
  EXCEPTION WHEN OTHERS THEN
    v_earning_rate := 0.90;
  END;

  IF v_earning_rate IS NULL THEN
    v_earning_rate := 0.90;
  END IF;

  NEW.courier_earning := ROUND(NEW.delivery_fee * v_earning_rate);
  NEW.platform_earning := NEW.delivery_fee - NEW.courier_earning;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Rewrite rpc_get_push_targets() to return app_type and platform for sound-mapping
CREATE OR REPLACE FUNCTION rpc_get_push_targets(
  p_order_id UUID,
  p_event TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_result JSONB;
BEGIN
  -- Load order
  SELECT * INTO v_order
  FROM delivery_orders
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('tokens', '[]'::jsonb, 'error', 'order_not_found');
  END IF;

  CASE p_event
    -- New order → notify warehouse staff
    WHEN 'new_order' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '🛒 Новый заказ!',
          'body', 'Заказ ' || v_order.order_number || ' ожидает подтверждения',
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      WHERE t.app_type = 'warehouse';

    -- Order ready → notify couriers
    WHEN 'courier_needed' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '📦 Заказ ждёт курьера!',
          'body', 'Заказ ' || v_order.order_number || ' готов к доставке',
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      WHERE t.app_type = 'courier';

    -- Courier assigned → notify customer
    WHEN 'courier_found' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '🚴 Курьер найден!',
          'body', 'Курьер скоро заберёт ваш заказ ' || v_order.order_number,
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    -- Picked up → notify customer
    WHEN 'picked_up' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '🚚 Заказ в пути!',
          'body', 'Курьер забрал ваш заказ и едет к вам',
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    -- Delivered → notify customer
    WHEN 'delivered' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '✅ Доставлено!',
          'body', 'Заказ ' || v_order.order_number || ' доставлен. Приятного аппетита!',
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    ELSE
      v_result := jsonb_build_object('tokens', '[]'::jsonb, 'error', 'unknown_event');
  END CASE;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Rewrite create_customer_order RPC to accept optional p_delivery_fee and load final values from the inserted row
CREATE OR REPLACE FUNCTION create_customer_order(
  p_warehouse_id UUID,
  p_customer_id UUID,
  p_requested_transport TEXT,
  p_delivery_address TEXT,
  p_delivery_lat DECIMAL,
  p_delivery_lng DECIMAL,
  p_payment_method TEXT DEFAULT 'cash',
  p_customer_note TEXT DEFAULT NULL,
  p_items JSONB DEFAULT '[]'::jsonb,
  p_delivery_fee DECIMAL DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_order_id UUID;
  v_order_number TEXT;
  v_items_total DECIMAL := 0;
  v_delivery_fee DECIMAL := 0;
  v_free_delivery_from DECIMAL := 0;
  v_estimated_minutes INT := 60;
  v_courier_earning DECIMAL;
  v_platform_earning DECIMAL;
  v_total DECIMAL;
  v_pickup_address TEXT;
  v_pickup_lat DECIMAL;
  v_pickup_lng DECIMAL;
  v_item JSONB;
  v_item_id UUID;
  v_modifier JSONB;
BEGIN
  -- ── Validate warehouse ──
  IF NOT EXISTS (SELECT 1 FROM warehouses WHERE id = p_warehouse_id) THEN
    RAISE EXCEPTION 'Warehouse not found: %', p_warehouse_id;
  END IF;

  -- ── Get pickup address from delivery_settings ──
  SELECT ds.address, ds.latitude, ds.longitude
  INTO v_pickup_address, v_pickup_lat, v_pickup_lng
  FROM delivery_settings ds
  WHERE ds.warehouse_id = p_warehouse_id
  LIMIT 1;

  -- ── Get delivery fee from zone (server-verified) ──
  -- Find the best zone for customer location
  SELECT dz.delivery_fee, dz.free_delivery_from, dz.estimated_minutes
  INTO v_delivery_fee, v_free_delivery_from, v_estimated_minutes
  FROM delivery_zones dz
  WHERE dz.warehouse_id = p_warehouse_id
    AND dz.is_active = true
    AND (
      (dz.zone_type = 'radius' AND (6371 * acos(
        cos(radians(p_delivery_lat)) * cos(radians(dz.center_lat)) *
        cos(radians(dz.center_lng) - radians(p_delivery_lng)) +
        sin(radians(p_delivery_lat)) * sin(radians(dz.center_lat))
      )) <= dz.radius_km)
      OR dz.zone_type = 'country'
      OR dz.zone_type = 'city'
    )
  ORDER BY dz.priority DESC, dz.delivery_fee ASC
  LIMIT 1;

  -- Default if no zone found
  v_delivery_fee := COALESCE(v_delivery_fee, 100);
  v_estimated_minutes := COALESCE(v_estimated_minutes, 60);

  -- ── Calculate items_total from items array (server-verified) ──
  SELECT COALESCE(SUM(
    (item->>'quantity')::decimal * (item->>'unit_price')::decimal
  ), 0) INTO v_items_total
  FROM jsonb_array_elements(p_items) AS item;

  -- ── Apply free delivery threshold ──
  IF v_free_delivery_from > 0 AND v_items_total >= v_free_delivery_from THEN
    v_delivery_fee := 0;
  END IF;

  -- ── Calculate earnings (default 90% courier / 10% platform fallback) ──
  v_courier_earning := ROUND(v_delivery_fee * 0.90, 2);
  v_platform_earning := ROUND(v_delivery_fee * 0.10, 2);
  v_total := v_items_total + v_delivery_fee;

  -- ── Generate order number ──
  v_order_number := 'AJ-' || to_char(now(), 'YYYYMMDD') || '-' ||
    lpad(floor(random() * 100000)::text, 5, '0');

  -- ── INSERT delivery_order ──
  INSERT INTO delivery_orders (
    order_number, customer_id, warehouse_id, status,
    requested_transport,
    pickup_address, pickup_lat, pickup_lng,
    delivery_address, delivery_lat, delivery_lng,
    items_total, delivery_fee, courier_earning, platform_earning, total,
    payment_method, customer_note, estimated_minutes
  ) VALUES (
    v_order_number, p_customer_id, p_warehouse_id, 'pending',
    p_requested_transport,
    v_pickup_address, v_pickup_lat, v_pickup_lng,
    p_delivery_address, p_delivery_lat, p_delivery_lng,
    v_items_total, v_delivery_fee, v_courier_earning, v_platform_earning, v_total,
    p_payment_method, p_customer_note, v_estimated_minutes
  )
  RETURNING id INTO v_order_id;

  -- ── INSERT delivery_order_items ──
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO delivery_order_items (
      order_id, product_id, name, quantity, unit_price, total
    ) VALUES (
      v_order_id,
      (v_item->>'product_id')::uuid,
      v_item->>'name',
      (v_item->>'quantity')::decimal,
      (v_item->>'unit_price')::decimal,
      (v_item->>'quantity')::decimal * (v_item->>'unit_price')::decimal
    )
    RETURNING id INTO v_item_id;

    -- ── INSERT delivery_order_item_modifiers ──
    IF v_item ? 'modifiers' AND jsonb_array_length(v_item->'modifiers') > 0 THEN
      FOR v_modifier IN SELECT * FROM jsonb_array_elements(v_item->'modifiers')
      LOOP
        INSERT INTO delivery_order_item_modifiers (
          order_item_id, modifier_id, group_name, modifier_name, price_delta
        ) VALUES (
          v_item_id,
          (v_modifier->>'modifier_id')::uuid,
          v_modifier->>'group_name',
          v_modifier->>'modifier_name',
          COALESCE((v_modifier->>'price_delta')::decimal, 0)
        );
      END LOOP;
    END IF;
  END LOOP;

  -- ── Load finalized values from the inserted row (which triggers calculated) ──
  SELECT delivery_fee, total, courier_earning, platform_earning
  INTO v_delivery_fee, v_total, v_courier_earning, v_platform_earning
  FROM delivery_orders
  WHERE id = v_order_id;

  -- ── Return order summary ──
  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'items_total', v_items_total,
    'delivery_fee', v_delivery_fee,
    'total', v_total,
    'estimated_minutes', v_estimated_minutes,
    'status', 'pending'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION create_customer_order TO authenticated;
GRANT EXECUTE ON FUNCTION create_customer_order TO anon;
