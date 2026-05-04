-- ═══════════════════════════════════════════════════════════════
-- 027: Add sale_type column to distinguish POS sales from AkJol delivery sales
-- This prevents double-counting revenue in the dashboard.
-- ═══════════════════════════════════════════════════════════════

-- Add sale_type column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sales' AND column_name = 'sale_type'
  ) THEN
    ALTER TABLE sales ADD COLUMN sale_type TEXT DEFAULT 'pos';
  END IF;
END $$;

-- Backfill existing records: AkJol delivery sales have notes starting with 'AkJol заказ'
UPDATE sales
SET sale_type = 'delivery'
WHERE notes LIKE 'AkJol заказ%';

-- Mark remaining as POS
UPDATE sales
SET sale_type = 'pos'
WHERE sale_type IS NULL;
