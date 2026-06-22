-- ═══════════════════════════════════════════════════════════════
-- 20260622203000: Freelance notifications exclude warehouse
-- ═══════════════════════════════════════════════════════════════

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
    -- New order → notify warehouse staff (unless freelance)
    WHEN 'new_order' THEN
      IF v_order.delivery_type = 'freelance' AND v_order.items_total = 0 THEN
        v_result := jsonb_build_object('tokens', '[]'::jsonb);
      ELSE
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
      END IF;

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
        JOIN couriers c ON c.user_id::text = t.user_id
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
        JOIN couriers c ON c.user_id::text = t.user_id
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
      JOIN customers c ON c.user_id::text = t.user_id
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
      JOIN customers c ON c.user_id::text = t.user_id
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
      JOIN customers c ON c.user_id::text = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    ELSE
      v_result := jsonb_build_object('tokens', '[]'::jsonb, 'error', 'unknown_event');
  END CASE;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Redefine state machine to prevent freelance type overrides and fix transitions
CREATE OR REPLACE FUNCTION trigger_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_item RECORD;
  v_sale_id UUID;
  v_company_id UUID;
  v_has_online_store_couriers BOOLEAN;
  v_use_akjol BOOLEAN;
  v_priority_minutes INT;
BEGIN
  -- ═══ Only fire when status actually changes ═══
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- ═══ Validate transitions ═══
  CASE OLD.status
    WHEN 'pending' THEN
      IF NEW.status NOT IN ('confirmed', 'cancelled_by_customer', 'cancelled_by_store') THEN
        -- Allow pending → courier_assigned for freelance orders
        IF NEW.delivery_type = 'freelance' AND NEW.status = 'courier_assigned' THEN
          NULL;
        ELSE
          RAISE EXCEPTION 'Invalid transition: pending → %', NEW.status;
        END IF;
      END IF;

    WHEN 'confirmed' THEN
      IF NEW.status NOT IN ('assembling', 'cancelled_by_customer', 'cancelled_by_store') THEN
        RAISE EXCEPTION 'Invalid transition: confirmed → %', NEW.status;
      END IF;

    WHEN 'assembling' THEN
      IF NEW.status NOT IN ('ready', 'cancelled_by_store') THEN
        RAISE EXCEPTION 'Invalid transition: assembling → %', NEW.status;
      END IF;

    WHEN 'ready' THEN
      IF NEW.status NOT IN ('courier_assigned', 'cancelled_no_courier', 'cancelled_by_customer') THEN
        RAISE EXCEPTION 'Invalid transition: ready → %', NEW.status;
      END IF;

    WHEN 'courier_assigned' THEN
      IF NEW.status NOT IN ('picked_up', 'cancelled_by_courier', 'cancelled_by_customer') THEN
        RAISE EXCEPTION 'Invalid transition: courier_assigned → %', NEW.status;
      END IF;

    WHEN 'picked_up' THEN
      IF NEW.status NOT IN ('delivered', 'cancelled_by_customer_late') THEN
        RAISE EXCEPTION 'Invalid transition: picked_up → %', NEW.status;
      END IF;

    WHEN 'cancelled_by_courier' THEN
      IF NEW.status NOT IN ('ready', 'cancelled_no_courier') THEN
        RAISE EXCEPTION 'Invalid transition: cancelled_by_courier → %', NEW.status;
      END IF;

    WHEN 'delivered', 'cancelled_by_customer', 'cancelled_by_customer_late',
         'cancelled_by_store', 'cancelled_no_courier' THEN
      RAISE EXCEPTION 'Cannot transition from terminal status: %', OLD.status;

    ELSE
      RAISE EXCEPTION 'Unknown status: %', OLD.status;
  END CASE;

  -- ═══ Append to status_history ═══
  NEW.status_history := COALESCE(OLD.status_history, '[]'::jsonb) || jsonb_build_array(
    jsonb_build_object(
      'status', NEW.status,
      'timestamp', now()::text,
      'prev_status', OLD.status
    )
  );

  -- ═══ Auto-timestamps ═══
  CASE NEW.status
    WHEN 'courier_assigned' THEN
      NEW.accepted_at := now();
    WHEN 'picked_up' THEN
      NEW.picked_up_at := now();
    WHEN 'delivered' THEN
      NEW.delivered_at := now();
    WHEN 'cancelled_by_customer', 'cancelled_by_customer_late',
         'cancelled_by_store', 'cancelled_by_courier', 'cancelled_no_courier' THEN
      NEW.cancelled_at := now();
    ELSE
      NULL;
  END CASE;

  -- ═══════════════════════════════════════════════════════════
  -- CASCADING ROUTING on 'ready'
  -- Determines when freelancers can see this order.
  -- ═══════════════════════════════════════════════════════════
  IF NEW.status = 'ready' THEN

    -- Check: does this warehouse have any online store couriers?
    SELECT EXISTS (
      SELECT 1
        FROM courier_warehouse cw
        JOIN couriers c ON c.id = cw.courier_id
        WHERE cw.warehouse_id = NEW.warehouse_id
          AND cw.is_active = true
          AND c.is_active = true
          AND c.is_online = true
    ) INTO v_has_online_store_couriers;

    -- Get warehouse settings
    SELECT
      COALESCE(ds.use_akjol_couriers, true),
      COALESCE(ds.store_courier_priority_minutes, 2)
    INTO v_use_akjol, v_priority_minutes
    FROM delivery_settings ds
    WHERE ds.warehouse_id = NEW.warehouse_id;

    -- Default if no settings row exists
    IF NOT FOUND THEN
      v_use_akjol := true;
      v_priority_minutes := 2;
    END IF;

    -- Routing decision
    IF v_has_online_store_couriers THEN
      -- Store couriers are online → give them priority
      IF v_use_akjol THEN
        -- After delay, broadcast to freelancers too
        NEW.freelance_broadcast_at := now() + (v_priority_minutes || ' minutes')::interval;
      ELSE
        -- Store-only mode: never broadcast to freelancers
        NEW.freelance_broadcast_at := NULL;
      END IF;

      -- Auto-detect delivery type
      NEW.delivery_type := 'store';

    ELSE
      -- No store couriers online
      IF v_use_akjol THEN
        -- Broadcast to freelancers immediately
        NEW.freelance_broadcast_at := now();
        NEW.delivery_type := 'freelance';
      ELSE
        -- Store-only but nobody online → still set future time
        -- so the order waits for store couriers to come online
        NEW.freelance_broadcast_at := NULL;
        NEW.delivery_type := 'store';
      END IF;
    END IF;

  END IF;

  -- ═══════════════════════════════════════════════════════════
  -- STOCK DEDUCTION + SALES RECORD on 'ready'
  -- ═══════════════════════════════════════════════════════════
  IF NEW.status = 'ready' THEN

    SELECT w.organization_id INTO v_company_id
      FROM warehouses w
      WHERE w.id = NEW.warehouse_id;

    -- 1) Deduct stock
    FOR v_item IN
      SELECT doi.product_id, doi.quantity, doi.name
        FROM delivery_order_items doi
        WHERE doi.order_id = NEW.id
          AND doi.product_id IS NOT NULL
    LOOP
      UPDATE products
        SET quantity = GREATEST(quantity - v_item.quantity, 0),
            last_sold_at = now(),
            updated_at = now()
        WHERE id = v_item.product_id;
    END LOOP;

    -- 2) Create sales record
    v_sale_id := gen_random_uuid();

    INSERT INTO sales (
      id, company_id, warehouse_id, employee_id,
      total_amount, discount_amount, received_amount,
      payment_method, status, notes, sale_type, created_at, updated_at
    ) VALUES (
      v_sale_id,
      v_company_id,
      NEW.warehouse_id,
      NULL,
      NEW.items_total,
      0,
      CASE WHEN NEW.payment_method = 'cash' THEN 0
           ELSE NEW.items_total END,
      NEW.payment_method,
      'completed',
      'AkJol заказ ' || NEW.order_number,
      'delivery',
      now(), now()
    );

    -- 3) Copy items to sale_items
    INSERT INTO sale_items (
      id, sale_id, product_id, product_name,
      quantity, selling_price, cost_price, discount_amount,
      item_type, created_at
    )
    SELECT
      gen_random_uuid(),
      v_sale_id,
      doi.product_id,
      doi.name,
      doi.quantity::integer,
      doi.unit_price::real,
      COALESCE(p.cost_price, 0)::real,
      0,
      'delivery',
      now()
    FROM delivery_order_items doi
    LEFT JOIN products p ON p.id = doi.product_id
    WHERE doi.order_id = NEW.id;

  END IF;

  -- ═══ Update delivery_type when courier accepts (except for custom freelance orders) ═══
  IF NEW.status = 'courier_assigned' AND NEW.courier_id IS NOT NULL AND NEW.items_total > 0 THEN
    -- Check if this courier is a store courier for this warehouse
    IF EXISTS (
      SELECT 1 FROM courier_warehouse
      WHERE courier_id = NEW.courier_id
        AND warehouse_id = NEW.warehouse_id
        AND is_active = true
    ) THEN
      NEW.delivery_type := 'store';
    ELSE
      NEW.delivery_type := 'freelance';
    END IF;
  END IF;

  -- ═══ Financial calculation on delivery ═══
  IF NEW.status = 'delivered' THEN
    IF NEW.delivery_type = 'freelance' THEN
      NEW.platform_earning := ROUND(NEW.delivery_fee * 0.10, 2);
      NEW.courier_earning  := ROUND(NEW.delivery_fee * 0.90, 2);
    ELSIF NEW.delivery_type = 'store' THEN
      NEW.platform_earning := ROUND(NEW.delivery_fee * 0.15, 2);
      NEW.courier_earning  := 0;
    END IF;
    NEW.total := NEW.items_total + NEW.delivery_fee;
  END IF;

  -- ═══ Compensation on late cancellation ═══
  IF NEW.status = 'cancelled_by_customer_late' THEN
    NEW.courier_earning  := NEW.delivery_fee;
    NEW.platform_earning := 0;
  END IF;

  -- ═══ Stock restoration on cancellation after ready ═══
  IF NEW.status IN ('cancelled_by_customer', 'cancelled_no_courier',
                     'cancelled_by_customer_late') THEN
    IF OLD.status IN ('ready', 'courier_assigned', 'picked_up') THEN
      FOR v_item IN
        SELECT doi.product_id, doi.quantity
          FROM delivery_order_items doi
          WHERE doi.order_id = NEW.id
            AND doi.product_id IS NOT NULL
      LOOP
        UPDATE products
          SET quantity = quantity + v_item.quantity,
              updated_at = now()
          WHERE id = v_item.product_id;
      END LOOP;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Repair existing store orders that defaulted to 'freelance'
UPDATE delivery_orders
SET delivery_type = 'store'
WHERE delivery_type = 'freelance'
  AND items_total > 0;
