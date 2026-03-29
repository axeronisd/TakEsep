-- =============================================
-- AkJol Delivery Triggers & Functions
-- Run AFTER 006_akjol_delivery.sql
-- =============================================

-- ─── Auto-generate order number ──────────────
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
DECLARE
  today_count INTEGER;
  date_prefix TEXT;
BEGIN
  date_prefix := to_char(NOW(), 'YYMMDD');
  
  SELECT COUNT(*) + 1 INTO today_count
  FROM delivery_orders
  WHERE created_at::date = NOW()::date;
  
  NEW.order_number := 'AJ-' || date_prefix || '-' || LPAD(today_count::TEXT, 3, '0');
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_number
  BEFORE INSERT ON delivery_orders
  FOR EACH ROW
  WHEN (NEW.order_number IS NULL)
  EXECUTE FUNCTION generate_order_number();

-- ─── Auto-calculate delivery fee ─────────────
CREATE OR REPLACE FUNCTION calculate_delivery_fee()
RETURNS TRIGGER AS $$
DECLARE
  current_hour INTEGER;
  is_night BOOLEAN;
  base_fee NUMERIC;
BEGIN
  current_hour := EXTRACT(HOUR FROM NOW());
  is_night := (current_hour >= 21 OR current_hour < 7);
  
  -- Set delivery fee based on transport type
  CASE NEW.requested_transport
    WHEN 'bicycle' THEN
      base_fee := CASE WHEN is_night THEN 150 ELSE 100 END;
    WHEN 'motorcycle' THEN
      base_fee := CASE WHEN is_night THEN 150 ELSE 100 END;
    WHEN 'truck' THEN
      base_fee := CASE WHEN is_night THEN 250 ELSE 150 END;
    ELSE
      base_fee := CASE WHEN is_night THEN 150 ELSE 100 END;
  END CASE;
  
  NEW.delivery_fee := base_fee;
  NEW.is_night_tariff := is_night;
  NEW.courier_earning := ROUND(base_fee * 0.85);  -- 85% for courier
  NEW.platform_earning := base_fee - ROUND(base_fee * 0.85);  -- 15% for platform
  NEW.total := COALESCE(NEW.items_total, 0) + base_fee;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_delivery_fee
  BEFORE INSERT ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION calculate_delivery_fee();

-- ─── Recalculate on transport change ─────────
CREATE OR REPLACE FUNCTION recalculate_on_transport_change()
RETURNS TRIGGER AS $$
DECLARE
  current_hour INTEGER;
  is_night BOOLEAN;
  transport TEXT;
  base_fee NUMERIC;
BEGIN
  -- Only recalculate when approved_transport changes
  IF NEW.approved_transport IS NOT NULL AND 
     NEW.approved_transport != OLD.approved_transport THEN
    
    transport := NEW.approved_transport;
    current_hour := EXTRACT(HOUR FROM NOW());
    is_night := (current_hour >= 21 OR current_hour < 7);
    
    CASE transport
      WHEN 'bicycle' THEN
        base_fee := CASE WHEN is_night THEN 150 ELSE 100 END;
      WHEN 'motorcycle' THEN
        base_fee := CASE WHEN is_night THEN 150 ELSE 100 END;
      WHEN 'truck' THEN
        base_fee := CASE WHEN is_night THEN 250 ELSE 150 END;
      ELSE
        base_fee := CASE WHEN is_night THEN 150 ELSE 100 END;
    END CASE;
    
    NEW.delivery_fee := base_fee;
    NEW.courier_earning := ROUND(base_fee * 0.85);
    NEW.platform_earning := base_fee - ROUND(base_fee * 0.85);
    NEW.total := COALESCE(NEW.items_total, 0) + base_fee;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalc_transport
  BEFORE UPDATE ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION recalculate_on_transport_change();

-- ─── Auto-update courier stats ───────────────
CREATE OR REPLACE FUNCTION update_courier_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- When order is delivered, increment courier's count
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    UPDATE couriers
    SET total_deliveries = COALESCE(total_deliveries, 0) + 1,
        total_earned = COALESCE(total_earned, 0) + COALESCE(NEW.courier_earning, 0)
    WHERE id = NEW.courier_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add stats columns to couriers if not exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'couriers' AND column_name = 'total_deliveries') THEN
    ALTER TABLE couriers ADD COLUMN total_deliveries INTEGER DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'couriers' AND column_name = 'total_earned') THEN
    ALTER TABLE couriers ADD COLUMN total_earned NUMERIC(12,2) DEFAULT 0;
  END IF;
END $$;

CREATE TRIGGER trg_courier_stats
  AFTER UPDATE ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION update_courier_stats();

-- ─── Auto-set pickup address from warehouse ──
CREATE OR REPLACE FUNCTION set_pickup_address()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.pickup_address IS NULL THEN
    SELECT address INTO NEW.pickup_address
    FROM warehouses
    WHERE id = NEW.warehouse_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pickup_address
  BEFORE INSERT ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION set_pickup_address();
