-- ==============================================================
-- 036: Validate delivery zones in create_customer_order RPC
-- ==============================================================

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
  -- Find the best zone for customer location (supporting radius, polygon, city, country)
  SELECT dz.delivery_fee, dz.free_delivery_from, dz.estimated_minutes, true
  INTO v_delivery_fee, v_free_delivery_from, v_estimated_minutes, v_zone_found
  FROM delivery_zones dz
  LEFT JOIN kg_cities c ON dz.zone_type = 'city' AND (c.name = dz.geo_name OR c.id = dz.geo_name)
  WHERE dz.warehouse_id = p_warehouse_id
    AND dz.is_active = true
    AND (
      (dz.zone_type = 'radius' AND (6371 * acos(
        cos(radians(p_delivery_lat)) * cos(radians(dz.center_lat)) *
        cos(radians(dz.center_lng) - radians(p_delivery_lng)) +
        sin(radians(p_delivery_lat)) * sin(radians(dz.center_lat))
      )) <= dz.radius_km)
      OR (dz.zone_type = 'polygon' AND is_point_in_polygon(p_delivery_lat::double precision, p_delivery_lng::double precision, dz.polygon_points))
      OR dz.zone_type = 'country'
      OR (dz.zone_type = 'city' AND c.id IS NOT NULL AND (6371 * acos(
        cos(radians(p_delivery_lat)) * cos(radians(c.lat)) *
        cos(radians(c.lng) - radians(p_delivery_lng)) +
        sin(radians(p_delivery_lat)) * sin(radians(c.lat))
      )) <= 15)
    )
  ORDER BY dz.priority DESC, dz.delivery_fee ASC
  LIMIT 1;

  -- Throw exception if no zone found
  IF NOT COALESCE(v_zone_found, false) THEN
    RAISE EXCEPTION 'Адрес находится вне зоны доставки магазина';
  END IF;

  -- ── Calculate items_total from items array (server-verified) ──
  SELECT COALESCE(SUM(
    (item->>'quantity')::decimal * (item->>'unit_price')::decimal
  ), 0) INTO v_items_total
  FROM jsonb_array_elements(p_items) AS item;

  -- ── Apply free delivery threshold ──
  IF v_free_delivery_from > 0 AND v_items_total >= v_free_delivery_from THEN
    v_delivery_fee := 0;
  END IF;

  -- ── Use client-passed delivery fee if available (e.g. for transport types other than default) ──
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
    p_payment_method, p_customer_note, v_estimated_minutes, p_distance_km
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
