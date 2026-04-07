-- =============================================
-- AkJol — Ход №16: Атомарное создание заказа
-- RPC функция для клиентского приложения
-- =============================================

-- ─── 1. Обновить find_businesses_near: добавить zone_id ──────

CREATE OR REPLACE FUNCTION find_businesses_near(
  p_lat DECIMAL,
  p_lng DECIMAL
)
RETURNS SETOF JSONB AS $$
BEGIN
  -- Зоны типа radius: проверяем расстояние
  RETURN QUERY
  SELECT jsonb_build_object(
    'zone_id', dz.id,
    'warehouse_id', dz.warehouse_id,
    'company_id', dz.company_id,
    'zone_name', dz.name,
    'zone_type', dz.zone_type,
    'delivery_fee', dz.delivery_fee,
    'free_delivery_from', dz.free_delivery_from,
    'fee_per_km', dz.fee_per_km,
    'min_order_amount', dz.min_order_amount,
    'estimated_minutes', dz.estimated_minutes,
    'distance_km', ROUND(
      (6371 * acos(
        cos(radians(p_lat)) * cos(radians(dz.center_lat)) *
        cos(radians(dz.center_lng) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(dz.center_lat))
      ))::numeric, 1
    )
  )
  FROM delivery_zones dz
  WHERE dz.is_active = true
    AND dz.zone_type = 'radius'
    AND (6371 * acos(
      cos(radians(p_lat)) * cos(radians(dz.center_lat)) *
      cos(radians(dz.center_lng) - radians(p_lng)) +
      sin(radians(p_lat)) * sin(radians(dz.center_lat))
    )) <= dz.radius_km

  UNION ALL

  -- Зоны типа country: всегда доступны
  SELECT jsonb_build_object(
    'zone_id', dz.id,
    'warehouse_id', dz.warehouse_id,
    'company_id', dz.company_id,
    'zone_name', dz.name,
    'zone_type', dz.zone_type,
    'delivery_fee', dz.delivery_fee,
    'free_delivery_from', dz.free_delivery_from,
    'fee_per_km', dz.fee_per_km,
    'min_order_amount', dz.min_order_amount,
    'estimated_minutes', dz.estimated_minutes,
    'distance_km', 0
  )
  FROM delivery_zones dz
  WHERE dz.is_active = true
    AND dz.zone_type = 'country'

  UNION ALL

  -- Зоны типа city: ищем ближайший город
  SELECT jsonb_build_object(
    'zone_id', dz.id,
    'warehouse_id', dz.warehouse_id,
    'company_id', dz.company_id,
    'zone_name', dz.name,
    'zone_type', dz.zone_type,
    'delivery_fee', dz.delivery_fee,
    'free_delivery_from', dz.free_delivery_from,
    'fee_per_km', dz.fee_per_km,
    'min_order_amount', dz.min_order_amount,
    'estimated_minutes', dz.estimated_minutes,
    'distance_km', ROUND(
      (6371 * acos(
        cos(radians(p_lat)) * cos(radians(c.lat)) *
        cos(radians(c.lng) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(c.lat))
      ))::numeric, 1
    )
  )
  FROM delivery_zones dz
  JOIN kg_cities c ON c.name = dz.geo_name OR c.id = dz.geo_name
  WHERE dz.is_active = true
    AND dz.zone_type = 'city'
    AND (6371 * acos(
      cos(radians(p_lat)) * cos(radians(c.lat)) *
      cos(radians(c.lng) - radians(p_lng)) +
      sin(radians(p_lat)) * sin(radians(c.lat))
    )) <= 15

  ORDER BY distance_km;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 2. Атомарная RPC: create_customer_order ─────────────────
--     Создаёт delivery_order + items + item_modifiers
--     в одной транзакции

CREATE OR REPLACE FUNCTION create_customer_order(
  p_warehouse_id UUID,
  p_customer_id UUID,
  p_requested_transport TEXT,
  p_delivery_address TEXT,
  p_delivery_lat DECIMAL,
  p_delivery_lng DECIMAL,
  p_payment_method TEXT DEFAULT 'cash',
  p_customer_note TEXT DEFAULT NULL,
  p_items JSONB DEFAULT '[]'::jsonb
  -- items format: [{ 
  --   "product_id": "uuid", "name": "...", "quantity": 1, 
  --   "unit_price": 250, "total": 250,
  --   "modifiers": [{"modifier_id": "uuid", "group_name": "...", "modifier_name": "...", "price_delta": 50}]
  -- }]
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

  -- ── Calculate earnings (85% courier / 15% platform) ──
  v_courier_earning := ROUND(v_delivery_fee * 0.85, 2);
  v_platform_earning := ROUND(v_delivery_fee * 0.15, 2);
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

-- ─── 3. Grant execute ────────────────────────────────────────

GRANT EXECUTE ON FUNCTION create_customer_order TO authenticated;
GRANT EXECUTE ON FUNCTION create_customer_order TO anon;
