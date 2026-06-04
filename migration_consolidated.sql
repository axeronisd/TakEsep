-- ═══════════════════════════════════════════════════════════════════
-- CONSOLIDATED SQL MIGRATION FOR TAKESEP WAREHOUSE SYNC
-- Run this entire script in your Supabase Dashboard → SQL Editor.
-- This script fixes sync failures on both Sales (clients columns)
-- and Dashboard sync (missing write_offs tables).
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- SECTION 1: CLIENTS & DEBT TRACKING COLUMNS (SALES & CLIENTS)
-- ─────────────────────────────────────────────────────────────

-- 1. Add columns to 'sales' table for client assignment and partial payments
ALTER TABLE sales ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS client_name TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS received_amount DECIMAL;

-- 2. Add properties to 'clients' table to track debt and lifetime metrics
ALTER TABLE clients ADD COLUMN IF NOT EXISTS total_spent DECIMAL DEFAULT 0;
ALTER TABLE clients ADD COLUMN IF NOT EXISTS debt DECIMAL DEFAULT 0;
ALTER TABLE clients ADD COLUMN IF NOT EXISTS purchases_count INT DEFAULT 0;


-- ─────────────────────────────────────────────────────────────
-- SECTION 2: CREATE WRITE-OFFS TABLES
-- ─────────────────────────────────────────────────────────────

-- 1. Create write_offs table
CREATE TABLE IF NOT EXISTS write_offs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE SET NULL,
  employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  employee_name TEXT,
  total_cost NUMERIC DEFAULT 0,
  items_count INT DEFAULT 0,
  status TEXT DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create write_off_items table
CREATE TABLE IF NOT EXISTS write_off_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  write_off_id UUID NOT NULL REFERENCES write_offs(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  quantity INT DEFAULT 1,
  cost_price NUMERIC DEFAULT 0,
  reason TEXT,
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE write_offs ENABLE ROW LEVEL SECURITY;
ALTER TABLE write_off_items ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies for anonymous access (matching other tables)
DROP POLICY IF EXISTS anon_select_write_offs ON write_offs;
CREATE POLICY anon_select_write_offs ON write_offs FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS anon_insert_write_offs ON write_offs;
CREATE POLICY anon_insert_write_offs ON write_offs FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS anon_update_write_offs ON write_offs;
CREATE POLICY anon_update_write_offs ON write_offs FOR UPDATE TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS anon_select_write_off_items ON write_off_items;
CREATE POLICY anon_select_write_off_items ON write_off_items FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS anon_insert_write_off_items ON write_off_items;
CREATE POLICY anon_insert_write_off_items ON write_off_items FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS anon_update_write_off_items ON write_off_items;
CREATE POLICY anon_update_write_off_items ON write_off_items FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- 5. Add tables to Supabase Realtime publication (if replication is enabled)
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE write_offs;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE write_off_items;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- 6. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_write_offs_company_warehouse ON write_offs(company_id, warehouse_id);
CREATE INDEX IF NOT EXISTS idx_write_off_items_write_off ON write_off_items(write_off_id);
