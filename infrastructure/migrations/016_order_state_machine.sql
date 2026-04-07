-- ═══════════════════════════════════════════════════════════════
-- 016: Order State Machine
-- Adds delivery_type, status_history, CHECK constraints,
-- and a BEFORE UPDATE trigger for automated status processing
-- Run in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════


-- ─── 1. New columns ───────────────────────────────────────────

ALTER TABLE delivery_orders
  ADD COLUMN IF NOT EXISTS delivery_type TEXT NOT NULL DEFAULT 'freelance',
  ADD COLUMN IF NOT EXISTS status_history JSONB NOT NULL DEFAULT '[]'::jsonb;


-- ─── 2. CHECK constraints ────────────────────────────────────

-- Delivery type: freelance (фрилансер AkJol) or store (штатный курьер)
ALTER TABLE delivery_orders
  ADD CONSTRAINT chk_delivery_type
  CHECK (delivery_type IN ('freelance', 'store'));

-- Status: all valid states from our State Machine
ALTER TABLE delivery_orders
  ADD CONSTRAINT chk_order_status
  CHECK (status IN (
    'pending',                  -- Клиент оформил, ждём магазин
    'confirmed',                -- Магазин принял
    'assembling',               -- Магазин собирает
    'ready',                    -- Собран, ищем курьера
    'courier_assigned',         -- Курьер принял заказ
    'picked_up',                -- Курьер забрал с магазина
    'delivered',                -- Доставлено клиенту ✅
    'cancelled_by_customer',    -- Клиент отменил (до picked_up)
    'cancelled_by_customer_late', -- Клиент отменил ПОСЛЕ picked_up (штраф)
    'cancelled_by_store',       -- Магазин отменил (нет товара и т.д.)
    'cancelled_by_courier',     -- Курьер отказался (ищем другого)
    'cancelled_no_courier'      -- Таймаут — нет свободных курьеров
  ));


-- ─── 3. Seed initial status_history for existing rows ─────────
-- Чтобы старые заказы (если есть) имели хотя бы первую запись

UPDATE delivery_orders
SET status_history = jsonb_build_array(
  jsonb_build_object(
    'status', status,
    'timestamp', COALESCE(created_at, now())
  )
)
WHERE status_history = '[]'::jsonb;


-- ─── 4. Trigger function: State Machine ──────────────────────

CREATE OR REPLACE FUNCTION trigger_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- ═══ Only fire when status actually changes ═══
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- ═══ Validate transitions ═══
  -- Each status can only move to specific next states.
  -- Invalid transitions are rejected with an exception.

  CASE OLD.status
    WHEN 'pending' THEN
      IF NEW.status NOT IN ('confirmed', 'cancelled_by_customer', 'cancelled_by_store') THEN
        RAISE EXCEPTION 'Invalid transition: pending → %', NEW.status;
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

    -- cancelled_by_courier is special: goes back to 'ready' (find another)
    WHEN 'cancelled_by_courier' THEN
      IF NEW.status NOT IN ('ready', 'cancelled_no_courier') THEN
        RAISE EXCEPTION 'Invalid transition: cancelled_by_courier → %', NEW.status;
      END IF;

    -- Terminal states: no transitions allowed
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
      -- No timestamp action needed for other statuses
      NULL;
  END CASE;

  -- ═══ Financial calculation on delivery ═══
  IF NEW.status = 'delivered' THEN
    IF NEW.delivery_type = 'freelance' THEN
      -- Фрилансер: 90% курьеру, 10% AkJol
      NEW.platform_earning := ROUND(NEW.delivery_fee * 0.10, 2);
      NEW.courier_earning  := ROUND(NEW.delivery_fee * 0.90, 2);
    ELSIF NEW.delivery_type = 'store' THEN
      -- Штатный: 15% AkJol (с платформенного баланса), 0 курьеру (магазин сам)
      NEW.platform_earning := ROUND(NEW.delivery_fee * 0.15, 2);
      NEW.courier_earning  := 0;
    END IF;

    -- Пересчитываем total на случай если delivery_fee менялось
    NEW.total := NEW.items_total + NEW.delivery_fee;
  END IF;

  -- ═══ Compensation on late cancellation ═══
  IF NEW.status = 'cancelled_by_customer_late' THEN
    -- Курьер получает 100% delivery_fee как компенсацию
    NEW.courier_earning  := NEW.delivery_fee;
    NEW.platform_earning := 0;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─── 5. Attach the trigger ───────────────────────────────────

DROP TRIGGER IF EXISTS trg_order_status_change ON delivery_orders;

CREATE TRIGGER trg_order_status_change
  BEFORE UPDATE ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_order_status_change();


-- ─── 6. Also seed status_history on INSERT ───────────────────

CREATE OR REPLACE FUNCTION trigger_order_status_init()
RETURNS TRIGGER AS $$
BEGIN
  -- On INSERT, initialize status_history with the first status entry
  NEW.status_history := jsonb_build_array(
    jsonb_build_object(
      'status', NEW.status,
      'timestamp', now()::text
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_status_init ON delivery_orders;

CREATE TRIGGER trg_order_status_init
  BEFORE INSERT ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_order_status_init();


-- ═══════════════════════════════════════════════════════════════
-- Verification: Test the state machine
-- ═══════════════════════════════════════════════════════════════
-- Uncomment to test after running the migration:
--
-- INSERT INTO delivery_orders (
--   order_number, customer_id, warehouse_id, 
--   requested_transport, delivery_address, delivery_lat, delivery_lng
-- ) VALUES (
--   'TEST-SM-001', 
--   (SELECT id FROM customers LIMIT 1),
--   (SELECT id FROM warehouses LIMIT 1),
--   'bicycle', 'Test Address', 42.87, 74.59
-- );
--
-- -- Should succeed: pending → confirmed
-- UPDATE delivery_orders SET status = 'confirmed' WHERE order_number = 'TEST-SM-001';
--
-- -- Should FAIL: confirmed → delivered (skipping steps)
-- UPDATE delivery_orders SET status = 'delivered' WHERE order_number = 'TEST-SM-001';
-- ERROR: Invalid transition: confirmed → delivered
--
-- -- Cleanup:
-- DELETE FROM delivery_orders WHERE order_number = 'TEST-SM-001';
