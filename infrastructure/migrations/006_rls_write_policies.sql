-- RLS write policies for warehouse app tables
-- Allows anon INSERT/UPDATE/DELETE on tables needed by the warehouse app
-- Run this in Supabase SQL Editor

DO $$ BEGIN
  -- ═══ PRODUCTS ═══
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_products' AND tablename = 'products') THEN
    CREATE POLICY anon_insert_products ON products FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_products' AND tablename = 'products') THEN
    CREATE POLICY anon_update_products ON products FOR UPDATE TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_products' AND tablename = 'products') THEN
    CREATE POLICY anon_delete_products ON products FOR DELETE TO anon USING (true);
  END IF;

  -- ═══ EMPLOYEES ═══
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_employees' AND tablename = 'employees') THEN
    CREATE POLICY anon_insert_employees ON employees FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_employees' AND tablename = 'employees') THEN
    CREATE POLICY anon_update_employees ON employees FOR UPDATE TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_employees' AND tablename = 'employees') THEN
    CREATE POLICY anon_delete_employees ON employees FOR DELETE TO anon USING (true);
  END IF;

  -- ═══ WAREHOUSES ═══
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_warehouses' AND tablename = 'warehouses') THEN
    CREATE POLICY anon_insert_warehouses ON warehouses FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_warehouses' AND tablename = 'warehouses') THEN
    CREATE POLICY anon_update_warehouses ON warehouses FOR UPDATE TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_warehouses' AND tablename = 'warehouses') THEN
    CREATE POLICY anon_delete_warehouses ON warehouses FOR DELETE TO anon USING (true);
  END IF;

  -- ═══ SALES ═══
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_sales' AND tablename = 'sales') THEN
    CREATE POLICY anon_insert_sales ON sales FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_sales' AND tablename = 'sales') THEN
    CREATE POLICY anon_update_sales ON sales FOR UPDATE TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_sales' AND tablename = 'sales') THEN
    CREATE POLICY anon_read_sales ON sales FOR SELECT TO anon USING (true);
  END IF;

  -- ═══ COMPANIES (write for admin) ═══
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_companies' AND tablename = 'companies') THEN
    CREATE POLICY anon_insert_companies ON companies FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_companies' AND tablename = 'companies') THEN
    CREATE POLICY anon_update_companies ON companies FOR UPDATE TO anon USING (true) WITH CHECK (true);
  END IF;
END $$;
