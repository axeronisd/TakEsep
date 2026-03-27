-- RLS SELECT policies for Supabase
-- Run this in Supabase SQL Editor

DO $$ BEGIN
  -- Companies (needed for license key verification)
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_companies' AND tablename = 'companies') THEN
    CREATE POLICY anon_read_companies ON companies FOR SELECT TO anon USING (true);
  END IF;

  -- Employees (needed for password login)
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_employees' AND tablename = 'employees') THEN
    CREATE POLICY anon_read_employees ON employees FOR SELECT TO anon USING (true);
  END IF;

  -- Warehouses
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_warehouses' AND tablename = 'warehouses') THEN
    CREATE POLICY anon_read_warehouses ON warehouses FOR SELECT TO anon USING (true);
  END IF;
END $$;
