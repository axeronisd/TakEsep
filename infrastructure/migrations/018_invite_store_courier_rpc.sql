-- ═══════════════════════════════════════════════════════════════
-- 018: Invite Store Courier RPC
-- Atomic function for TakEsep warehouse owners to add couriers.
-- Handles both new and existing couriers in one call.
-- Run in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION rpc_invite_store_courier(
  p_phone TEXT,
  p_name TEXT,
  p_warehouse_id UUID,
  p_transport_type TEXT DEFAULT 'bicycle'
)
RETURNS JSONB AS $$
DECLARE
  v_courier_id UUID;
  v_courier RECORD;
  v_existing_link RECORD;
  v_result TEXT;
BEGIN

  -- ═══ 1. Find or Create Courier ═══
  SELECT id, name, courier_type
    INTO v_courier
    FROM couriers
    WHERE phone = p_phone AND is_active = true
    LIMIT 1;

  IF FOUND THEN
    -- Courier already exists in system
    v_courier_id := v_courier.id;

    -- Update type to 'store' if was freelance
    -- (courier can be both; no harm in marking as store)
    IF v_courier.courier_type = 'freelance' THEN
      UPDATE couriers SET courier_type = 'store' WHERE id = v_courier_id;
    END IF;

    v_result := 'EXISTING_COURIER';
  ELSE
    -- Brand new courier — create record
    v_courier_id := gen_random_uuid();

    INSERT INTO couriers (
      id, name, phone, transport_type, courier_type,
      is_active, is_online, bank_balance, created_at
    ) VALUES (
      v_courier_id,
      COALESCE(NULLIF(p_name, ''), 'Курьер'),
      p_phone,
      p_transport_type,
      'store',
      true,
      false,
      0,
      now()
    );

    v_result := 'NEW_COURIER';
  END IF;

  -- ═══ 2. Create or Reactivate Warehouse Binding ═══
  SELECT id, is_active
    INTO v_existing_link
    FROM courier_warehouse
    WHERE courier_id = v_courier_id
      AND warehouse_id = p_warehouse_id
    LIMIT 1;

  IF FOUND THEN
    IF v_existing_link.is_active THEN
      -- Already linked and active
      RETURN jsonb_build_object(
        'success', true,
        'action', 'ALREADY_LINKED',
        'courier_id', v_courier_id,
        'courier_name', COALESCE(v_courier.name, p_name)
      );
    ELSE
      -- Reactivate old link
      UPDATE courier_warehouse
        SET is_active = true, left_at = null, joined_at = now()
        WHERE id = v_existing_link.id;

      v_result := v_result || '_REACTIVATED';
    END IF;
  ELSE
    -- Create new link
    INSERT INTO courier_warehouse (
      courier_id, warehouse_id, is_active, joined_at
    ) VALUES (
      v_courier_id, p_warehouse_id, true, now()
    );
  END IF;

  -- ═══ 3. Mark invitation as accepted (if exists) ═══
  UPDATE courier_invitations
    SET status = 'accepted',
        courier_id = v_courier_id,
        responded_at = now()
    WHERE phone = p_phone
      AND warehouse_id = p_warehouse_id
      AND status = 'pending';

  -- ═══ 4. Return result ═══
  RETURN jsonb_build_object(
    'success', true,
    'action', v_result,
    'courier_id', v_courier_id,
    'courier_name', COALESCE(
      (SELECT name FROM couriers WHERE id = v_courier_id),
      p_name
    )
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
