-- ═══════════════════════════════════════════════════════════════
-- 017: Courier Auth RPC
-- Function to identify courier type on login
-- Returns courier profile + warehouse binding in one call
-- Run in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION rpc_courier_login(p_phone TEXT)
RETURNS JSONB AS $$
DECLARE
  v_courier RECORD;
  v_warehouses JSONB;
BEGIN
  -- 1. Find courier by phone
  SELECT id, user_id, name, phone, courier_type, transport_type,
         is_active, is_online, bank_balance
    INTO v_courier
    FROM couriers
    WHERE phone = p_phone AND is_active = true
    LIMIT 1;

  -- Not found → return null (login screen shows error)
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'found', false,
      'error', 'NOT_REGISTERED'
    );
  END IF;

  -- 2. Get warehouse bindings (штатные привязки)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'warehouse_id', cw.warehouse_id,
      'warehouse_name', w.name,
      'warehouse_address', w.address,
      'warehouse_lat', w.latitude,
      'warehouse_lng', w.longitude,
      'joined_at', cw.joined_at
    )
  ), '[]'::jsonb)
  INTO v_warehouses
  FROM courier_warehouse cw
  JOIN warehouses w ON w.id = cw.warehouse_id
  WHERE cw.courier_id = v_courier.id
    AND cw.is_active = true;

  -- 3. Return full profile
  RETURN jsonb_build_object(
    'found', true,
    'courier', jsonb_build_object(
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
    'is_store_courier', jsonb_array_length(v_warehouses) > 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
