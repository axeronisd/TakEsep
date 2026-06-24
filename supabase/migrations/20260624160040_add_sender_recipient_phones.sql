ALTER TABLE delivery_orders ADD COLUMN IF NOT EXISTS sender_phone TEXT;
ALTER TABLE delivery_orders ADD COLUMN IF NOT EXISTS recipient_phone TEXT;

COMMENT ON COLUMN delivery_orders.sender_phone IS 'Phone number of the person sending the package. Required for security tracking.';
COMMENT ON COLUMN delivery_orders.recipient_phone IS 'Phone number of the person receiving the package. Required for security tracking.';
