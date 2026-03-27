-- ═══════════════════════════════════════════════════════════════════
-- Migration 008: Create ALL missing tables & columns in Supabase
-- This ensures PowerSync local schema ↔ Supabase PostgreSQL are in sync.
-- Run this in Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. ROLES (управление ролями сотрудников)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  name TEXT NOT NULL,
  permissions TEXT DEFAULT '',
  pin_code TEXT DEFAULT '',
  is_system BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 2. WAREHOUSE_GROUPS (группы складов)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouse_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 3. CATEGORIES (категории товаров)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  name TEXT NOT NULL,
  parent_id UUID,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 4. SALE_ITEMS (позиции в продажах)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sale_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id UUID,
  product_name TEXT,
  quantity INTEGER DEFAULT 0,
  selling_price REAL DEFAULT 0,
  cost_price REAL DEFAULT 0,
  discount_amount REAL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 5. ARRIVALS (приход товаров)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS arrivals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  employee_id UUID,
  warehouse_id UUID REFERENCES warehouses(id),
  supplier TEXT,
  status TEXT DEFAULT 'completed',
  total_amount REAL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 6. ARRIVAL_ITEMS (позиции в приходе)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS arrival_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  arrival_id UUID NOT NULL REFERENCES arrivals(id) ON DELETE CASCADE,
  product_id UUID,
  product_name TEXT,
  quantity INTEGER DEFAULT 0,
  cost_price REAL DEFAULT 0,
  selling_price REAL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 7. TRANSFERS (перемещения между складами)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  from_warehouse_id UUID,
  to_warehouse_id UUID,
  from_warehouse_name TEXT,
  to_warehouse_name TEXT,
  sender_employee_id UUID,
  sender_employee_name TEXT,
  receiver_employee_id UUID,
  receiver_employee_name TEXT,
  status TEXT DEFAULT 'pending',
  total_amount REAL DEFAULT 0,
  sender_notes TEXT,
  receiver_notes TEXT,
  sender_photos TEXT,
  receiver_photos TEXT,
  pricing_mode TEXT DEFAULT 'cost',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 8. TRANSFER_ITEMS (позиции в перемещении)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transfer_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id UUID NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
  product_id UUID,
  product_name TEXT,
  product_sku TEXT,
  product_barcode TEXT,
  quantity_sent INTEGER DEFAULT 0,
  quantity_received INTEGER DEFAULT 0,
  cost_price REAL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 9. AUDITS (ревизии)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  warehouse_id UUID,
  warehouse_name TEXT,
  employee_id UUID,
  employee_name TEXT,
  type TEXT DEFAULT 'full',
  status TEXT DEFAULT 'in_progress',
  category_id UUID,
  category_name TEXT,
  notes TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 10. AUDIT_ITEMS (позиции в ревизии)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id UUID NOT NULL REFERENCES audits(id) ON DELETE CASCADE,
  product_id UUID,
  product_name TEXT,
  product_sku TEXT,
  product_barcode TEXT,
  snapshot_quantity INTEGER DEFAULT 0,
  movements_during_audit INTEGER DEFAULT 0,
  actual_quantity INTEGER DEFAULT 0,
  cost_price REAL DEFAULT 0,
  is_checked BOOLEAN DEFAULT FALSE,
  comment TEXT,
  photos TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 11. ADD MISSING COLUMNS TO EXISTING TABLES
-- ─────────────────────────────────────────────────────────────

-- warehouses: add group_id if missing
ALTER TABLE warehouses ADD COLUMN IF NOT EXISTS group_id UUID;

-- employees: ensure all columns exist
ALTER TABLE employees ADD COLUMN IF NOT EXISTS role_id UUID;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS allowed_warehouses TEXT;

-- products: ensure newer columns exist
ALTER TABLE products ADD COLUMN IF NOT EXISTS sold_last_30_days INTEGER DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS days_of_stock_left REAL;
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_zone TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS last_sold_at TIMESTAMPTZ;
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE;

-- sales: ensure all columns
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_amount REAL DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS notes TEXT;

-- transfers: pricing_mode
-- (already part of CREATE TABLE above, but in case table existed without it)

-- ─────────────────────────────────────────────────────────────
-- 12. ENABLE RLS ON ALL NEW TABLES
-- ─────────────────────────────────────────────────────────────
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE arrivals ENABLE ROW LEVEL SECURITY;
ALTER TABLE arrival_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE audits ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_items ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────
-- 13. RLS POLICIES: allow anon full access (PowerSync sync)
-- ─────────────────────────────────────────────────────────────
DO $$ 
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY[
    'roles', 'warehouse_groups', 'categories',
    'sale_items', 'arrivals', 'arrival_items',
    'transfers', 'transfer_items', 'audits', 'audit_items'
  ])
  LOOP
    -- SELECT
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY anon_read_%I ON %I FOR SELECT TO anon USING (true)', tbl, tbl);
    END IF;
    -- INSERT
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY anon_insert_%I ON %I FOR INSERT TO anon WITH CHECK (true)', tbl, tbl);
    END IF;
    -- UPDATE
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY anon_update_%I ON %I FOR UPDATE TO anon USING (true) WITH CHECK (true)', tbl, tbl);
    END IF;
    -- DELETE
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY anon_delete_%I ON %I FOR DELETE TO anon USING (true)', tbl, tbl);
    END IF;
  END LOOP;
END $$;

-- Add read policy for roles (needed for login)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_roles' AND tablename = 'roles') THEN
    CREATE POLICY anon_read_roles ON roles FOR SELECT TO anon USING (true);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- DONE! All PowerSync tables are now mirrored in Supabase.
-- ─────────────────────────────────────────────────────────────
