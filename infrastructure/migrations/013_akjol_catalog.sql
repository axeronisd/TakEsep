-- ═══════════════════════════════════════════════════════════════════
-- Migration 013: AkJol Catalog Sync Enhancements
-- Adds: product_images table, b2c_description, categories.image_url
-- Run in Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. PRODUCT_IMAGES — несколько фото на один товар
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- 2. PRODUCTS — отдельное описание для AkJol
-- ─────────────────────────────────────────────────────────────
ALTER TABLE products ADD COLUMN IF NOT EXISTS b2c_description TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS b2c_price REAL;

-- ─────────────────────────────────────────────────────────────
-- 3. CATEGORIES — изображение категории для AkJol каталога
-- ─────────────────────────────────────────────────────────────
ALTER TABLE categories ADD COLUMN IF NOT EXISTS image_url TEXT;

-- ─────────────────────────────────────────────────────────────
-- 4. RLS — product_images
-- ─────────────────────────────────────────────────────────────
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_product_images' AND tablename = 'product_images') THEN
    CREATE POLICY anon_read_product_images ON product_images FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_product_images' AND tablename = 'product_images') THEN
    CREATE POLICY anon_insert_product_images ON product_images FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_product_images' AND tablename = 'product_images') THEN
    CREATE POLICY anon_update_product_images ON product_images FOR UPDATE TO anon USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_product_images' AND tablename = 'product_images') THEN
    CREATE POLICY anon_delete_product_images ON product_images FOR DELETE TO anon USING (true);
  END IF;
END $$;

-- Authenticated users (AkJol customer app) — read-only для product_images, products, categories
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auth_read_product_images' AND tablename = 'product_images') THEN
    CREATE POLICY auth_read_product_images ON product_images FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auth_read_products' AND tablename = 'products') THEN
    CREATE POLICY auth_read_products ON products FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auth_read_categories' AND tablename = 'categories') THEN
    CREATE POLICY auth_read_categories ON categories FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auth_read_warehouses' AND tablename = 'warehouses') THEN
    CREATE POLICY auth_read_warehouses ON warehouses FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 5. PowerSync sync rules for product_images
-- ─────────────────────────────────────────────────────────────
-- Note: Add to PowerSync sync rules in Dashboard:
-- product_images:
--   data_queries:
--     - SELECT * FROM product_images

-- ═══════════════════════════════════════════════════════════════════
-- DONE! Run this in Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════
