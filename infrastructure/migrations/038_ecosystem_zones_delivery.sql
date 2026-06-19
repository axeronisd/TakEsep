-- ==============================================================
-- 038: Ecosystem zones delivery validation and routing
-- ==============================================================

-- 1. Update find_businesses_near to validate customer address against active ecosystem zones
--    and calculate distance from active warehouse points directly.
CREATE OR REPLACE FUNCTION find_businesses_near(
  p_lat DECIMAL,
  p_lng DECIMAL
)
RETURNS SETOF JSONB AS $$
BEGIN
  -- Check if the coordinates are inside any active ecosystem polygon zone
  IF NOT EXISTS (
    SELECT 1 FROM ecosystem_zones ez
    WHERE ez.is_active = true
      AND is_point_in_polygon(p_lat::double precision, p_lng::double precision, ez.polygon_points)
  ) THEN
    RETURN; -- Return empty set if outside ecosystem zones
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'zone_id', ds.id,
    'warehouse_id', ds.warehouse_id,
    'company_id', w.organization_id,
    'zone_name', 'Ecosystem Polygon Zone',
    'zone_type', 'polygon',
    'delivery_fee', 50, -- default fallback, client calculates dynamically
    'free_delivery_from', 0,
    'fee_per_km', 50,
    'min_order_amount', ds.min_order_amount,
    'estimated_minutes', 60,
    'distance_km', ROUND(
      (6371 * acos(
        cos(radians(p_lat)) * cos(radians(ds.latitude)) *
        cos(radians(ds.longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(ds.latitude))
      ))::numeric, 1
    )
  )
  FROM delivery_settings ds
  JOIN warehouses w ON w.id = ds.warehouse_id
  WHERE ds.is_active = true
    AND ds.latitude IS NOT NULL 
    AND ds.longitude IS NOT NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;


-- 2. Update create_customer_order to restrict orders strictly to active ecosystem polygon zones
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
  p_delivery_fee DECIMAL DEFAULT NULL,
  p_distance_km DECIMAL DEFAULT NULL
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
  v_zone_found BOOLEAN := false;
  v_price_per_km NUMERIC;
  v_distance_km DOUBLE PRECISION;
BEGIN
  -- ── Validate warehouse ──
  IF NOT EXISTS (SELECT 1 FROM warehouses WHERE id = p_warehouse_id) THEN
    RAISE EXCEPTION 'Warehouse not found: %', p_warehouse_id;
  END IF;

  -- ── Check if customer is inside any active ecosystem polygon zone ──
  SELECT EXISTS (
    SELECT 1 FROM ecosystem_zones ez
    WHERE ez.is_active = true
      AND is_point_in_polygon(p_delivery_lat::double precision, p_delivery_lng::double precision, ez.polygon_points)
  ) INTO v_zone_found;

  IF NOT COALESCE(v_zone_found, false) THEN
    RAISE EXCEPTION 'Адрес находится вне зоны доставки магазина';
  END IF;

  -- ── Get pickup address from delivery_settings ──
  SELECT ds.address, ds.latitude, ds.longitude
  INTO v_pickup_address, v_pickup_lat, v_pickup_lng
  FROM delivery_settings ds
  WHERE ds.warehouse_id = p_warehouse_id
  LIMIT 1;

  -- ── Calculate distance ──
  IF p_distance_km IS NULL THEN
    DECLARE
      v_lat1 DOUBLE PRECISION;
      v_lng1 DOUBLE PRECISION;
      v_lat2 DOUBLE PRECISION;
      v_lng2 DOUBLE PRECISION;
      v_acos_val DOUBLE PRECISION;
    BEGIN
      v_lat1 := radians(v_pickup_lat::double precision);
      v_lng1 := radians(v_pickup_lng::double precision);
      v_lat2 := radians(p_delivery_lat::double precision);
      v_lng2 := radians(p_delivery_lng::double precision);

      IF v_lat1 IS NOT NULL AND v_lng1 IS NOT NULL AND v_lat2 IS NOT NULL AND v_lng2 IS NOT NULL THEN
        v_acos_val := cos(v_lat1) * cos(v_lat2) * cos(v_lng2 - v_lng1) + sin(v_lat1) * sin(v_lat2);
        IF v_acos_val > 1.0 THEN
          v_acos_val := 1.0;
        ELSIF v_acos_val < -1.0 THEN
          v_acos_val := -1.0;
        END IF;
        v_distance_km := 6371.0 * acos(v_acos_val);
      ELSE
        v_distance_km := 0.0;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_distance_km := 0.0;
    END;
  ELSE
    v_distance_km := p_distance_km;
  END IF;

  -- ── Fetch price_per_km ──
  SELECT price_per_km INTO v_price_per_km
  FROM transport_types
  WHERE id = p_requested_transport;

  IF v_price_per_km IS NULL THEN
    v_price_per_km := 50; -- Default fallback
  END IF;

  -- ── Calculate base delivery fee (price * km, min 50 som) ──
  v_delivery_fee := GREATEST(50, ROUND((v_distance_km * v_price_per_km)::numeric));

  -- ── Calculate items_total from items array ──
  SELECT COALESCE(SUM(
    (item->>'quantity')::decimal * (item->>'unit_price')::decimal
  ), 0) INTO v_items_total
  FROM jsonb_array_elements(p_items) AS item;

  -- ── Apply client-passed delivery fee if available ──
  IF p_delivery_fee IS NOT NULL THEN
    v_delivery_fee := p_delivery_fee;
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
    payment_method, customer_note, estimated_minutes, distance_km
  ) VALUES (
    v_order_number, p_customer_id, p_warehouse_id, 'pending',
    p_requested_transport,
    v_pickup_address, v_pickup_lat, v_pickup_lng,
    p_delivery_address, p_delivery_lat, p_delivery_lng,
    v_items_total, v_delivery_fee, v_courier_earning, v_platform_earning, v_total,
    p_payment_method, p_customer_note, v_estimated_minutes, v_distance_km
  )
  RETURNING id INTO v_order_id;

  -- ── INSERT delivery_order_items ──
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO delivery_order_items (
      order_id, product_id, name, quantity, unit_price, total, image_url
    ) VALUES (
      v_order_id,
      (v_item->>'product_id')::uuid,
      v_item->>'name',
      (v_item->>'quantity')::int,
      (v_item->>'unit_price')::decimal,
      (v_item->>'total')::decimal,
      v_item->>'image_url'
    ) RETURNING id INTO v_item_id;

    -- Insert modifiers if they exist
    IF v_item ? 'modifiers' AND jsonb_typeof(v_item->'modifiers') = 'array' THEN
      FOR v_modifier IN SELECT * FROM jsonb_array_elements(v_item->'modifiers')
      LOOP
        INSERT INTO delivery_order_item_modifiers (
          order_item_id, modifier_id, name, price, quantity
        ) VALUES (
          v_item_id,
          (v_modifier->>'modifier_id')::uuid,
          v_modifier->>'name',
          (v_modifier->>'price')::decimal,
          (v_modifier->>'quantity')::int
        );
      END LOOP;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'total', v_total,
    'delivery_fee', v_delivery_fee
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
