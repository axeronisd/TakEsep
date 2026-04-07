-- ═══════════════════════════════════════════════════════════════
-- 021: Accounting & Financial Ledger
-- Courier earnings view + warehouse debt tracking
-- Run in Supabase SQL Editor AFTER 020
-- ═══════════════════════════════════════════════════════════════


-- ─── 1. Courier Earnings View ─────────────────────────────────
-- Fast aggregate for courier's income screen

CREATE OR REPLACE VIEW courier_earnings AS
SELECT
  d.courier_id,
  d.id             AS order_id,
  d.order_number,
  d.warehouse_id,
  w.name           AS warehouse_name,
  d.delivery_type,
  d.delivery_fee,
  d.courier_earning,
  d.platform_earning,
  d.items_total,
  d.delivered_at,
  d.created_at
FROM delivery_orders d
LEFT JOIN warehouses w ON w.id = d.warehouse_id
WHERE d.status = 'delivered'
  AND d.courier_id IS NOT NULL;


-- ─── 2. Warehouse Delivery Ledger View ────────────────────────
-- Financial summary for TakEsep analytics

CREATE OR REPLACE VIEW warehouse_delivery_ledger AS
SELECT
  d.warehouse_id,
  d.id              AS order_id,
  d.order_number,
  d.delivery_type,
  d.delivery_fee,
  d.platform_earning,
  d.courier_earning,
  d.items_total,
  d.total,
  d.payment_method,
  d.status,
  d.delivered_at,
  d.created_at,
  c.name            AS courier_name,
  CASE d.delivery_type
    WHEN 'store'     THEN 'Штатный'
    WHEN 'freelance' THEN 'Фриланс'
    ELSE d.delivery_type
  END AS delivery_type_label,
  -- Debt: for cash orders, store collects total but owes platform_earning to AkJol
  CASE
    WHEN d.payment_method = 'cash' AND d.status = 'delivered'
    THEN d.platform_earning
    ELSE 0
  END AS debt_to_platform
FROM delivery_orders d
LEFT JOIN couriers c ON c.id = d.courier_id;


-- ─── 3. RPC: courier daily/weekly summary ─────────────────────

CREATE OR REPLACE FUNCTION rpc_courier_earnings_summary(
  p_courier_id UUID,
  p_days INT DEFAULT 7
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_earned', COALESCE(SUM(courier_earning), 0),
    'total_deliveries', COUNT(*),
    'today_earned', COALESCE(SUM(
      CASE WHEN delivered_at >= date_trunc('day', now())
           THEN courier_earning ELSE 0 END
    ), 0),
    'today_deliveries', COUNT(
      CASE WHEN delivered_at >= date_trunc('day', now()) THEN 1 END
    ),
    'avg_per_delivery', CASE
      WHEN COUNT(*) > 0 THEN ROUND(SUM(courier_earning) / COUNT(*), 0)
      ELSE 0
    END,
    'by_day', (
      SELECT COALESCE(jsonb_agg(day_data ORDER BY day), '[]'::jsonb)
      FROM (
        SELECT
          date_trunc('day', delivered_at)::date AS day,
          jsonb_build_object(
            'date', date_trunc('day', delivered_at)::date,
            'earned', SUM(courier_earning),
            'count', COUNT(*)
          ) AS day_data
        FROM delivery_orders
        WHERE courier_id = p_courier_id
          AND status = 'delivered'
          AND delivered_at >= now() - (p_days || ' days')::interval
        GROUP BY date_trunc('day', delivered_at)::date
      ) daily
    )
  )
  INTO v_result
  FROM delivery_orders
  WHERE courier_id = p_courier_id
    AND status = 'delivered'
    AND delivered_at >= now() - (p_days || ' days')::interval;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 4. RPC: warehouse debt summary ───────────────────────────

CREATE OR REPLACE FUNCTION rpc_warehouse_debt_summary(
  p_warehouse_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    -- Total debt for cash orders (platform_earning the store owes)
    'total_debt', COALESCE(SUM(
      CASE WHEN payment_method = 'cash' THEN platform_earning ELSE 0 END
    ), 0),
    -- Total deliveries
    'total_deliveries', COUNT(*),
    -- Revenue from delivery orders
    'total_items_revenue', COALESCE(SUM(items_total), 0),
    -- Total delivery fees paid
    'total_delivery_fees', COALESCE(SUM(delivery_fee), 0),
    -- Platform earnings breakdown
    'store_courier_commission', COALESCE(SUM(
      CASE WHEN delivery_type = 'store' THEN platform_earning ELSE 0 END
    ), 0),
    'freelance_courier_commission', COALESCE(SUM(
      CASE WHEN delivery_type = 'freelance' THEN platform_earning ELSE 0 END
    ), 0),
    -- This week's debt
    'week_debt', COALESCE(SUM(
      CASE WHEN payment_method = 'cash'
                AND delivered_at >= date_trunc('week', now())
           THEN platform_earning ELSE 0 END
    ), 0),
    -- This month
    'month_debt', COALESCE(SUM(
      CASE WHEN payment_method = 'cash'
                AND delivered_at >= date_trunc('month', now())
           THEN platform_earning ELSE 0 END
    ), 0)
  )
  INTO v_result
  FROM delivery_orders
  WHERE warehouse_id = p_warehouse_id
    AND status = 'delivered';

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 5. Update trigger: link delivered order to sales record ──

-- When order reaches 'delivered', update the matching sales record
-- with courier_id and finalized amounts
-- (The sales record was created when status='ready' in trigger 019)

CREATE OR REPLACE FUNCTION trigger_link_delivery_to_sale()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    UPDATE sales
      SET notes = 'AkJol заказ ' || NEW.order_number
                  || ' | Курьер: ' || COALESCE(
                    (SELECT name FROM couriers WHERE id = NEW.courier_id),
                    'N/A'
                  )
                  || ' | Комиссия: ' || NEW.platform_earning::text || ' сом',
          updated_at = now()
    WHERE warehouse_id = NEW.warehouse_id
      AND notes LIKE 'AkJol заказ ' || NEW.order_number || '%';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_link_delivery_to_sale ON delivery_orders;

CREATE TRIGGER trg_link_delivery_to_sale
  AFTER UPDATE ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_link_delivery_to_sale();
