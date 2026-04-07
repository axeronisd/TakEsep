-- ═══════════════════════════════════════════════════════════════════
-- Migration 025: Storefront Enhancements — Birth of the Marketplace
-- 
-- Adds: store categories, product modifiers, storefront fields,
--       rating/orders aggregation triggers
-- Run in Supabase Dashboard → SQL Editor AFTER 024
-- ═══════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────
--  1. STORE CATEGORIES — глобальный справочник категорий магазинов
--     Используется на главной странице AkJol для фильтрации
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS store_categories (
  id TEXT PRIMARY KEY,              -- 'food', 'pharmacy', 'flowers'
  name TEXT NOT NULL,               -- 'Еда'
  name_kg TEXT,                     -- 'Тамак' (кыргызский)
  icon TEXT NOT NULL,               -- Material icon name
  color TEXT,                       -- Hex цвет для UI: '#FF5722'
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Предустановленные категории магазинов
INSERT INTO store_categories (id, name, name_kg, icon, color, sort_order) VALUES
  ('food',       'Еда',           'Тамак',         'restaurant',           '#FF5722', 1),
  ('grocery',    'Продукты',      'Азык-түлүк',    'shopping_basket',      '#4CAF50', 2),
  ('pharmacy',   'Аптеки',        'Дарыканалар',   'local_pharmacy',       '#E91E63', 3),
  ('flowers',    'Цветы',         'Гүлдөр',        'local_florist',        '#9C27B0', 4),
  ('electronics','Электроника',   'Электроника',   'devices',              '#2196F3', 5),
  ('clothing',   'Одежда',        'Кийим',         'checkroom',            '#FF9800', 6),
  ('beauty',     'Красота',       'Сулуулук',      'spa',                  '#F06292', 7),
  ('pets',       'Зоотовары',     'Жаныбарлар',    'pets',                 '#795548', 8),
  ('household',  'Дом и быт',     'Үй жана турмуш','home',                '#607D8B', 9),
  ('gifts',      'Подарки',       'Белектер',      'card_giftcard',        '#E040FB', 10),
  ('sports',     'Спорт',         'Спорт',         'fitness_center',       '#00BCD4', 11),
  ('books',      'Книги',         'Китептер',      'menu_book',            '#3F51B5', 12)
ON CONFLICT (id) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────
--  2. СВЯЗЬ: Магазин ↔ Категории (многие-ко-многим)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS warehouse_store_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  store_category_id TEXT NOT NULL REFERENCES store_categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(warehouse_id, store_category_id)
);

CREATE INDEX IF NOT EXISTS idx_wsc_warehouse ON warehouse_store_categories(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_wsc_category ON warehouse_store_categories(store_category_id);


-- ─────────────────────────────────────────────────────────────────
--  3. ВИТРИНА — новые поля в delivery_settings
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE delivery_settings
  ADD COLUMN IF NOT EXISTS banner_url TEXT,
  ADD COLUMN IF NOT EXISTS total_orders_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS avg_rating DECIMAL(3,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_ratings INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN delivery_settings.banner_url IS 'Hero banner image for the store page in AkJol';
COMMENT ON COLUMN delivery_settings.total_orders_count IS 'Total delivered orders (auto-incremented by trigger)';
COMMENT ON COLUMN delivery_settings.avg_rating IS 'Average store rating from customer reviews';
COMMENT ON COLUMN delivery_settings.total_ratings IS 'Number of store ratings received';


-- ─────────────────────────────────────────────────────────────────
--  4. PRODUCT MODIFIER GROUPS — группы модификаторов товара
--     Пример: "Выберите размер", "Добавки", "Тип теста"
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS product_modifier_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,                               -- "Выберите размер"
  type TEXT NOT NULL DEFAULT 'required_one',
  -- 'required_one'  = Обязательный выбор одного (размер пиццы)
  -- 'optional_many' = Необязательный множественный (топпинги)
  -- 'required_many' = Обязательный множественный (минимум 1 соус)
  min_selections INT DEFAULT 0,                     -- Минимум выборов (для required_many)
  max_selections INT DEFAULT 0,                     -- Максимум выборов (0 = без лимита)
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- CHECK constraint for type
ALTER TABLE product_modifier_groups
  ADD CONSTRAINT chk_modifier_group_type
  CHECK (type IN ('required_one', 'optional_many', 'required_many'));


-- ─────────────────────────────────────────────────────────────────
--  5. PRODUCT MODIFIERS — конкретные опции внутри группы
--     Пример: "30 см" (+0 сом), "40 см" (+200 сом)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS product_modifiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES product_modifier_groups(id) ON DELETE CASCADE,
  name TEXT NOT NULL,                               -- "30 см", "+Сыр", "Халапеньо"
  price_delta DECIMAL NOT NULL DEFAULT 0,           -- Доплата (может быть 0 или отрицательной)
  is_default BOOLEAN DEFAULT false,                 -- Выбран по умолчанию
  is_available BOOLEAN DEFAULT true,                -- Временно недоступен (кончился ингредиент)
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pmg_product ON product_modifier_groups(product_id);
CREATE INDEX IF NOT EXISTS idx_pm_group ON product_modifiers(group_id);


-- ─────────────────────────────────────────────────────────────────
--  6. DELIVERY ORDER ITEM MODIFIERS — выбранные модификаторы в заказе
--     Связь: delivery_order_items ↔ product_modifiers
--     Хранит, что именно клиент выбрал при оформлении заказа
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS delivery_order_item_modifiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_item_id UUID NOT NULL REFERENCES delivery_order_items(id) ON DELETE CASCADE,
  modifier_id UUID REFERENCES product_modifiers(id) ON DELETE SET NULL,
  modifier_name TEXT NOT NULL,                      -- "40 см" (сохраняем на момент заказа)
  group_name TEXT NOT NULL,                         -- "Выберите размер"
  price_delta DECIMAL NOT NULL DEFAULT 0,           -- Доплата на момент заказа
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_doim_order_item ON delivery_order_item_modifiers(order_item_id);


-- ─────────────────────────────────────────────────────────────────
--  7. ТРИГГЕР: Обновление рейтинга магазина
--     Аналогичен trigger_update_courier_rating из 024
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION trigger_update_store_rating()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.store_rating IS NOT NULL
     AND (OLD.store_rating IS NULL OR OLD.store_rating != NEW.store_rating) THEN

    UPDATE delivery_settings SET
      avg_rating = sub.avg_r,
      total_ratings = sub.cnt
    FROM (
      SELECT
        AVG(store_rating)::DECIMAL(3,2) AS avg_r,
        COUNT(*) AS cnt
      FROM delivery_orders
      WHERE warehouse_id = NEW.warehouse_id
        AND store_rating IS NOT NULL
    ) sub
    WHERE delivery_settings.warehouse_id = NEW.warehouse_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_store_rating ON delivery_orders;

CREATE TRIGGER trg_update_store_rating
  AFTER UPDATE ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_store_rating();


-- ─────────────────────────────────────────────────────────────────
--  8. ТРИГГЕР: Счётчик доставленных заказов
--     +1 при переходе в 'delivered'
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION trigger_increment_orders_count()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'delivered'
     AND (OLD.status IS DISTINCT FROM 'delivered') THEN

    UPDATE delivery_settings
    SET total_orders_count = total_orders_count + 1
    WHERE warehouse_id = NEW.warehouse_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_increment_orders_count ON delivery_orders;

CREATE TRIGGER trg_increment_orders_count
  AFTER UPDATE ON delivery_orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_increment_orders_count();


-- ─────────────────────────────────────────────────────────────────
--  9. RLS POLICIES
-- ─────────────────────────────────────────────────────────────────

-- Store categories: readable by all (анонимные тоже, для главной AkJol)
ALTER TABLE store_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "store_categories_read" ON store_categories
  FOR SELECT TO anon, authenticated USING (true);

-- Warehouse store categories: read all, write by owner
ALTER TABLE warehouse_store_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "wsc_read" ON warehouse_store_categories
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "wsc_write" ON warehouse_store_categories
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- Product modifier groups: read all, write by owner
ALTER TABLE product_modifier_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pmg_read" ON product_modifier_groups
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "pmg_write" ON product_modifier_groups
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- Product modifiers: read all, write by owner
ALTER TABLE product_modifiers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pm_read" ON product_modifiers
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "pm_write" ON product_modifiers
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- Delivery order item modifiers: read all, write by authenticated
ALTER TABLE delivery_order_item_modifiers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "doim_read" ON delivery_order_item_modifiers
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "doim_write" ON delivery_order_item_modifiers
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);


-- ─────────────────────────────────────────────────────────────────
-- 10. CATEGORIES — гарантируем наличие image_url
--     (уже добавлено в 013, но для безопасности)
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE categories ADD COLUMN IF NOT EXISTS image_url TEXT;


-- ─────────────────────────────────────────────────────────────────
-- 11. Backfill: пересчёт существующих рейтингов и счётчиков
-- ─────────────────────────────────────────────────────────────────

-- Пересчитать avg_rating для всех магазинов, у которых есть рейтинги
UPDATE delivery_settings ds SET
  avg_rating = sub.avg_r,
  total_ratings = sub.cnt
FROM (
  SELECT
    warehouse_id,
    AVG(store_rating)::DECIMAL(3,2) AS avg_r,
    COUNT(*) AS cnt
  FROM delivery_orders
  WHERE store_rating IS NOT NULL
  GROUP BY warehouse_id
) sub
WHERE ds.warehouse_id = sub.warehouse_id;

-- Пересчитать total_orders_count
UPDATE delivery_settings ds SET
  total_orders_count = sub.cnt
FROM (
  SELECT
    warehouse_id,
    COUNT(*) AS cnt
  FROM delivery_orders
  WHERE status = 'delivered'
  GROUP BY warehouse_id
) sub
WHERE ds.warehouse_id = sub.warehouse_id;


-- ═══════════════════════════════════════════════════════════════════
-- DONE! Run this in Supabase SQL Editor.
-- New tables: store_categories, warehouse_store_categories,
--             product_modifier_groups, product_modifiers,
--             delivery_order_item_modifiers
-- New columns: delivery_settings (banner_url, total_orders_count,
--              avg_rating, total_ratings)
-- New triggers: trg_update_store_rating, trg_increment_orders_count
-- ═══════════════════════════════════════════════════════════════════
