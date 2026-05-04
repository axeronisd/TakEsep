-- ═══════════════════════════════════════════════════════════════
-- 016b: Stock deduction on order assembly (ready status)
-- Adds atomic stock deduction + sales record creation
-- to the order state machine trigger.
-- Run in Supabase SQL Editor AFTER 016_order_state_machine.sql
-- ═══════════════════════════════════════════════════════════════


-- Replace the trigger function with the enhanced version
CREATE OR REPLACE FUNCTION trigger_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
  v_item RECORD;
  v_sale_id UUID;
  v_company_id UUID;
BEGIN
  -- ═══ Only fire when status actually changes ═══
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- ═══ Validate transitions ═══
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
  -- STOCK DEDUCTION + SALES RECORD on 'ready'
  -- When cashier marks order as assembled, atomically:
  -- 1) Deduct product quantities
  -- 2) Create a sale record (type = 'delivery') for analytics
  -- ═══════════════════════════════════════════════════════════
  IF NEW.status = 'ready' THEN

    -- Get the company_id from the warehouse
    SELECT w.organization_id INTO v_company_id
      FROM warehouses w
      WHERE w.id = NEW.warehouse_id;

    -- 1) Deduct stock for each order item that has a product_id
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

    -- 2) Create a sales record for accounting/analytics
    v_sale_id := gen_random_uuid();

    INSERT INTO sales (
      id, company_id, warehouse_id, employee_id,
      total_amount, discount_amount, received_amount,
      payment_method, status, notes, sale_type, created_at, updated_at
    ) VALUES (
      v_sale_id,
      v_company_id,
      NEW.warehouse_id,
      NULL,                        -- no specific employee
      NEW.items_total,
      0,
      CASE WHEN NEW.payment_method = 'cash' THEN 0    -- will collect on delivery
           ELSE NEW.items_total END,                    -- online = already paid
      NEW.payment_method,
      'completed',
      'AkJol заказ ' || NEW.order_number,
      'delivery',
      now(), now()
    );

    -- 3) Copy order items into sale_items
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
  -- If order was cancelled after stock was deducted (status was 'ready' or later)
  IF NEW.status IN ('cancelled_by_customer', 'cancelled_no_courier',
                     'cancelled_by_customer_late') THEN
    -- Check if stock was already deducted (order passed through 'ready')
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
