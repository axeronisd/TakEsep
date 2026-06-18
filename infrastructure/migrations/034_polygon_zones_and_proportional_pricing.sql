-- ==============================================================
-- 034: Polygon zones, nearest-5 dispatch, and proportional pricing
-- ==============================================================

-- 1. Add polygon_points column to zones
ALTER TABLE delivery_zones ADD COLUMN IF NOT EXISTS polygon_points JSONB;
ALTER TABLE ecosystem_zones ADD COLUMN IF NOT EXISTS polygon_points JSONB;

-- 2. Ray-casting point in polygon checker
CREATE OR REPLACE FUNCTION is_point_in_polygon(
  p_lat double precision,
  p_lng double precision,
  p_polygon jsonb
)
RETURNS boolean AS $$
DECLARE
  v_poly_str text;
  v_item jsonb;
  v_point point;
BEGIN
  IF p_polygon IS NULL OR jsonb_array_length(p_polygon) < 3 THEN
    RETURN false;
  END IF;
  
  v_poly_str := '(';
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_polygon) LOOP
    -- Coordinates stored as [latitude, longitude] in JSONB
    -- Longitude is X (item->>1), Latitude is Y (item->>0)
    v_poly_str := v_poly_str || '(' || (v_item->>1)::text || ',' || (v_item->>0)::text || '),';
  END LOOP;
  v_poly_str := rtrim(v_poly_str, ',') || ')';
  
  v_point := point(p_lng, p_lat);
  RETURN v_point <@ v_poly_str::polygon;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 3. Update find_businesses_near to support polygon zones
CREATE OR REPLACE FUNCTION find_businesses_near(
  p_lat DECIMAL,
  p_lng DECIMAL
)
RETURNS SETOF JSONB AS $$
BEGIN
  -- 3a. Radius zones
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

  -- 3b. Polygon zones (Distance is measured to the warehouse/store center)
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
        cos(radians(p_lat)) * cos(radians(w.latitude)) *
        cos(radians(w.longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(w.latitude))
      ))::numeric, 1
    )
  )
  FROM delivery_zones dz
  JOIN warehouses w ON w.id = dz.warehouse_id
  WHERE dz.is_active = true
    AND dz.zone_type = 'polygon'
    AND is_point_in_polygon(p_lat::double precision, p_lng::double precision, dz.polygon_points)

  UNION ALL

  -- 3c. Country zones
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

  -- 3d. City zones
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

-- 4. Update rpc_get_push_targets to notify top 5 nearest online couriers
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

    -- Order ready → notify nearest 5 online couriers
    WHEN 'courier_needed' THEN
      WITH nearest_couriers AS (
        SELECT t.fcm_token, t.app_type, t.device_platform,
          (6371.0 * acos(
            cos(radians(v_order.pickup_lat::double precision)) * cos(radians(c.latitude::double precision)) *
            cos(radians(c.longitude::double precision) - radians(v_order.pickup_lng::double precision)) +
            sin(radians(v_order.pickup_lat::double precision)) * sin(radians(c.latitude::double precision))
          )) as distance
        FROM user_fcm_tokens t
        JOIN couriers c ON c.user_id = t.user_id
        WHERE t.app_type = 'courier'
          AND c.is_online = true
          AND c.latitude IS NOT NULL
          AND c.longitude IS NOT NULL
        ORDER BY distance ASC
        LIMIT 5
      ),
      all_online AS (
        SELECT t.fcm_token, t.app_type, t.device_platform
        FROM user_fcm_tokens t
        JOIN couriers c ON c.user_id = t.user_id
        WHERE t.app_type = 'courier'
          AND c.is_online = true
      )
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', r.fcm_token,
          'title', '📦 Заказ ждёт курьера!',
          'body', 'Заказ ' || v_order.order_number || ' готов к доставке',
          'app_type', r.app_type,
          'device_platform', r.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM (
        SELECT fcm_token, app_type, device_platform FROM nearest_couriers
        UNION
        -- Fallback if no nearest couriers found
        SELECT fcm_token, app_type, device_platform FROM all_online
        WHERE NOT EXISTS (SELECT 1 FROM nearest_couriers)
        LIMIT 5
      ) r;

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

-- 5. Create rpc_get_available_orders_for_courier to implement nearest 5 cascading dispatch
CREATE OR REPLACE FUNCTION rpc_get_available_orders_for_courier(
  p_courier_id UUID
)
RETURNS SETOF JSONB AS $$
DECLARE
  v_courier RECORD;
BEGIN
  -- Get courier info
  SELECT * INTO v_courier FROM couriers WHERE id = p_courier_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH order_ranks AS (
    -- For each pending order, rank all online couriers by distance
    SELECT 
      o.id as order_id,
      c.id as courier_id,
      ROW_NUMBER() OVER (
        PARTITION BY o.id 
        ORDER BY (
          6371.0 * acos(
            cos(radians(o.pickup_lat::double precision)) * cos(radians(c.latitude::double precision)) *
            cos(radians(c.longitude::double precision) - radians(o.pickup_lng::double precision)) +
            sin(radians(o.pickup_lat::double precision)) * sin(radians(c.latitude::double precision))
          )
        ) ASC
      ) as courier_rank,
      EXTRACT(EPOCH FROM (now() - o.created_at))::double precision as elapsed_seconds
    FROM delivery_orders o
    CROSS JOIN couriers c
    WHERE o.status = 'pending'
      AND (o.courier_id IS NULL OR o.courier_id = p_courier_id)
      AND c.is_online = true
      AND c.latitude IS NOT NULL
      AND c.longitude IS NOT NULL
  )
  SELECT row_to_json(r)::jsonb
  FROM (
    SELECT 
      o.*,
      -- Embed customers and warehouses details to match standard select joins format
      json_build_object('name', cust.name, 'phone', cust.phone) as customers,
      json_build_object('name', w.name, 'address', w.address, 'latitude', w.latitude, 'longitude', w.longitude) as warehouses,
      COALESCE(
        (
          SELECT json_agg(item) 
          FROM delivery_order_items item 
          WHERE item.delivery_order_id = o.id
        ), 
        '[]'::json
      ) as delivery_order_items
    FROM delivery_orders o
    LEFT JOIN customers cust ON cust.id = o.customer_id
    LEFT JOIN warehouses w ON w.id = o.warehouse_id
    LEFT JOIN order_ranks r ON r.order_id = o.id AND r.courier_id = p_courier_id
    WHERE o.status = 'pending'
      AND (
        -- 1. Specifically assigned to this courier
        o.courier_id = p_courier_id
        OR
        -- 2. Unassigned, but courier is eligible based on distance rank and elapsed time T
        (
          o.courier_id IS NULL 
          AND (
            -- If no coordinates for courier, show after 90 seconds
            r.courier_rank IS NULL AND EXTRACT(EPOCH FROM (now() - o.created_at)) >= 90
            OR
            -- Otherwise check dynamic time windows
            r.courier_rank <= 5 -- first 5 nearest see immediately
            OR (r.courier_rank <= 10 AND r.elapsed_seconds >= 30) -- next 5 see after 30s
            OR (r.courier_rank <= 15 AND r.elapsed_seconds >= 60) -- next 5 see after 60s
            OR (r.elapsed_seconds >= 90) -- all see after 90s
          )
        )
      )
      -- Match transport types if courier has specific restrictions
      AND (
        v_courier.transport_types IS NULL 
        OR jsonb_array_length(v_courier.transport_types) = 0
        OR o.requested_transport::text = ANY(
          SELECT jsonb_array_elements_text(v_courier.transport_types)
        )
      )
    ORDER BY o.created_at DESC
  ) r;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
