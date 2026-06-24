ALTER TABLE delivery_orders ADD COLUMN IF NOT EXISTS courier_safety_accepted BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN delivery_orders.courier_safety_accepted IS 'Tracks whether the courier has accepted the safety warning and liability agreement for this order.';
