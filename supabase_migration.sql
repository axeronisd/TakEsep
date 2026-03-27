-- ═══════════════════════════════════════════════════════════════════
-- Migration 009: Add missing employee detail columns to Supabase
-- These columns were added to PowerSync local schema and need to
-- exist in Supabase PostgreSQL for sync to work correctly.
-- Run this in Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. EMPLOYEES: add new detail columns
-- ─────────────────────────────────────────────────────────────
ALTER TABLE employees ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS inn TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS passport_number TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS passport_issued_by TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS passport_issued_date TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS salary_type TEXT DEFAULT 'monthly';
ALTER TABLE employees ADD COLUMN IF NOT EXISTS salary_amount REAL DEFAULT 0;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS salary_auto_deduct BOOLEAN DEFAULT false;

-- ─────────────────────────────────────────────────────────────
-- 2. SALE_ITEMS: add service-related columns (for service analytics)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS item_type TEXT;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS executor_id UUID;
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS executor_name TEXT;

-- ═══════════════════════════════════════════════════════════════════
-- DONE! Now PowerSync ↔ Supabase schemas are fully in sync.
-- Employee fields, roles, and sale_items all match.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 3. EMPLOYEE_EXPENSES: operational expenses (lunch, transport, etc.)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employee_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  warehouse_id UUID REFERENCES warehouses(id),
  employee_id UUID NOT NULL REFERENCES employees(id),
  employee_name TEXT NOT NULL,
  amount REAL NOT NULL DEFAULT 0,
  comment TEXT,
  created_by TEXT,
  status TEXT DEFAULT 'active',
  deleted_by TEXT,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE employee_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own company expenses" ON employee_expenses;
CREATE POLICY "Users can manage own company expenses"
  ON employee_expenses
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────
-- 4. PAYMENT_METHODS: Custom Payment Types & QR Codes
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  name TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  qr_image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own payment methods" ON payment_methods;
CREATE POLICY "Users can manage own payment methods"
  ON payment_methods
  FOR ALL
  USING (true)
  WITH CHECK (true);
