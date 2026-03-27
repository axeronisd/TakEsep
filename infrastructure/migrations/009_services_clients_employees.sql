-- ═══════════════════════════════════════════════════════════════════
-- Migration 009: Services, Clients, and Employee extensions
-- Run this in Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. SERVICES (каталог услуг)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  name TEXT NOT NULL,
  category TEXT,
  description TEXT,
  price REAL DEFAULT 0,
  duration_minutes INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 2. CLIENTS (клиенты / CRM)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  type TEXT DEFAULT 'retail', -- retail, wholesale, vip
  total_spent REAL DEFAULT 0,
  debt REAL DEFAULT 0,
  purchases_count INTEGER DEFAULT 0,
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 3. EMPLOYEE EXTENSIONS (паспорт + зарплата)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE employees ADD COLUMN IF NOT EXISTS inn TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS passport_number TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS passport_issued_by TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS passport_issued_date TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS photo_url TEXT;

ALTER TABLE employees ADD COLUMN IF NOT EXISTS salary_type TEXT DEFAULT 'monthly'; -- hourly, daily, weekly, monthly, percent_sales, percent_services
ALTER TABLE employees ADD COLUMN IF NOT EXISTS salary_amount REAL DEFAULT 0;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS salary_auto_deduct BOOLEAN DEFAULT FALSE;

-- ─────────────────────────────────────────────────────────────
-- 4. ENABLE RLS
-- ─────────────────────────────────────────────────────────────
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────
-- 5. RLS POLICIES
-- ─────────────────────────────────────────────────────────────
DO $$ 
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY['services', 'clients'])
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY anon_read_%I ON %I FOR SELECT TO anon USING (true)', tbl, tbl);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY anon_insert_%I ON %I FOR INSERT TO anon WITH CHECK (true)', tbl, tbl);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY anon_update_%I ON %I FOR UPDATE TO anon USING (true) WITH CHECK (true)', tbl, tbl);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY anon_delete_%I ON %I FOR DELETE TO anon USING (true)', tbl, tbl);
    END IF;
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- DONE! Services, Clients tables created. Employee fields extended.
-- ═══════════════════════════════════════════════════════════════════
