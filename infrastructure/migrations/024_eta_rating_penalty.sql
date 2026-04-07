-- ═══════════════════════════════════════════════════════════════
-- 024: ETA, Rating & Late Cancel
-- Adds rating columns, ETA calculation, and avg rating trigger
-- Run in Supabase SQL Editor AFTER 023
-- ═══════════════════════════════════════════════════════════════


-- ─── 1. Add rating columns to delivery_orders ────────────────

ALTER TABLE delivery_orders
  ADD COLUMN IF NOT EXISTS courier_rating INT CHECK (courier_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS store_rating   INT CHECK (store_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS rating_comment TEXT;

-- Add avg_rating to couriers table
ALTER TABLE couriers
  ADD COLUMN IF NOT EXISTS avg_rating DECIMAL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ratings INT DEFAULT 0;


-- ─── 2. Trigger: recalculate courier avg_rating ──────────────

CREATE OR REPLACE FUNCTION trigger_update_courier_rating()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.courier_rating IS NOT NULL
     AND NEW.courier_id IS NOT NULL
     AND (OLD.courier_rating IS NULL OR OLD.courier_rating != NEW.courier_rating) THEN

    UPDATE couriers SET
      avg_rating = sub.avg_r,
      total_ratings = sub.cnt
    FROM (
      SELECT
        AVG(courier_rating)::DECIMAL(3,2) AS avg_r,
        COUNT(*) AS cnt
      FROM delivery_orders
      WHERE courier_id = NEW.courier_id
        AND courier_rating IS NOT NULL
    ) sub
    WHERE couriers.id = NEW.courier_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_courier_rating ON delivery_orders;

CREATE TRIGGER trg_update_courier_rating
  AFTER UPDATE ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_courier_rating();


-- ─── 3. ETA calculation on INSERT ─────────────────────────────

CREATE OR REPLACE FUNCTION trigger_set_estimated_delivery()
RETURNS TRIGGER AS $$
DECLARE
  v_distance_km DECIMAL;
  v_zone_minutes INT;
  v_assembly_minutes INT := 15; -- base assembly time
  v_per_km_minutes INT := 5;   -- minutes per km
BEGIN
  -- Only set on INSERT if estimated_minutes is not already set
  IF TG_OP = 'INSERT' AND (NEW.estimated_minutes IS NULL OR NEW.estimated_minutes = 0) THEN

    -- Try to get zone-based estimate
    SELECT dz.estimated_minutes INTO v_zone_minutes
    FROM delivery_zones dz
    WHERE dz.warehouse_id = NEW.warehouse_id
      AND dz.is_active = true
    ORDER BY dz.priority DESC
    LIMIT 1;

    IF v_zone_minutes IS NOT NULL THEN
      -- Use zone's pre-configured estimate
      NEW.estimated_minutes := v_zone_minutes;
    ELSE
      -- Calculate from distance (Haversine approximation)
      IF NEW.pickup_lat IS NOT NULL AND NEW.delivery_lat IS NOT NULL THEN
        v_distance_km := (
          6371 * acos(
            cos(radians(NEW.pickup_lat)) * cos(radians(NEW.delivery_lat))
            * cos(radians(NEW.delivery_lng) - radians(NEW.pickup_lng))
            + sin(radians(NEW.pickup_lat)) * sin(radians(NEW.delivery_lat))
          )
        );
        NEW.estimated_minutes := v_assembly_minutes + CEIL(v_distance_km * v_per_km_minutes);
      ELSE
        -- Fallback: default 40 minutes
        NEW.estimated_minutes := 40;
      END IF;
    END IF;

    -- Set estimated_delivery_at
    NEW.estimated_delivery_at := NEW.created_at + (NEW.estimated_minutes || ' minutes')::interval;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_estimated_delivery ON delivery_orders;

CREATE TRIGGER trg_set_estimated_delivery
  BEFORE INSERT ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_estimated_delivery();


-- ─── 4. Add estimated_delivery_at column ──────────────────────

ALTER TABLE delivery_orders
  ADD COLUMN IF NOT EXISTS estimated_delivery_at TIMESTAMPTZ;

-- Backfill existing orders (if any)
UPDATE delivery_orders
SET estimated_delivery_at = created_at + (COALESCE(estimated_minutes, 40) || ' minutes')::interval
WHERE estimated_delivery_at IS NULL
  AND status NOT IN ('delivered', 'cancelled_by_customer', 'cancelled_by_store',
                     'cancelled_by_courier', 'cancelled_no_courier');


-- ─── 5. RPC: Submit rating ────────────────────────────────────

CREATE OR REPLACE FUNCTION rpc_submit_order_rating(
  p_order_id UUID,
  p_courier_rating INT DEFAULT NULL,
  p_store_rating INT DEFAULT NULL,
  p_comment TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  -- Verify ownership
  SELECT * INTO v_order
  FROM delivery_orders d
  JOIN customers c ON c.id = d.customer_id
  WHERE d.id = p_order_id
    AND c.user_id = auth.uid()
    AND d.status = 'delivered';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'order_not_found_or_not_delivered');
  END IF;

  -- Check not already rated
  IF v_order.courier_rating IS NOT NULL THEN
    RETURN jsonb_build_object('error', 'already_rated');
  END IF;

  -- Update
  UPDATE delivery_orders SET
    courier_rating = p_courier_rating,
    store_rating = p_store_rating,
    rating_comment = p_comment
  WHERE id = p_order_id;

  RETURN jsonb_build_object('status', 'ok');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
