-- =============================================
-- AkJol — Зоны доставки
-- Бизнес настраивает района/радиус/всю страну
-- Клиенты AkJol видят бизнес только в своей зоне
-- =============================================

-- ─── Таблица зон доставки ─────────────────────
CREATE TABLE IF NOT EXISTS delivery_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  
  -- Тип зоны
  zone_type TEXT NOT NULL DEFAULT 'radius',
  -- 'radius'   = Круг (center + radius_km)
  -- 'city'     = Весь город
  -- 'district' = Район города
  -- 'region'   = Область
  -- 'country'  = Вся страна
  
  -- Название зоны (для отображения)
  name TEXT NOT NULL,
  
  -- Для type='radius': центр и радиус
  center_lat DECIMAL,
  center_lng DECIMAL,
  radius_km DECIMAL,
  
  -- Для type='city'/'district'/'region': географическое название
  geo_name TEXT,
  -- Бишкек, Ош, Джалал-Абад, Чуйская область и т.д.
  
  -- Для вложенных: parent_zone
  parent_zone_id UUID REFERENCES delivery_zones(id),
  
  -- Стоимость доставки в этой зоне
  delivery_fee DECIMAL DEFAULT 0,          -- Фиксированная стоимость
  free_delivery_from DECIMAL DEFAULT 0,    -- Бесплатная доставка от суммы
  fee_per_km DECIMAL DEFAULT 0,            -- Цена за км (для radius)
  min_order_amount DECIMAL DEFAULT 0,      -- Мин. заказ в зоне
  
  -- Время доставки
  estimated_minutes INT DEFAULT 60,        -- Ориентировочное время
  
  -- Приоритет (выше = ближе зона)
  priority INT DEFAULT 0,
  
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── RLS ──────────────────────────────────────
ALTER TABLE delivery_zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "delivery_zones_read" ON delivery_zones
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "delivery_zones_write" ON delivery_zones
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- ─── Предустановленные города Кыргызстана ─────
CREATE TABLE IF NOT EXISTS kg_cities (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  name_kg TEXT,           -- На кыргызском
  region TEXT NOT NULL,   -- Область
  lat DECIMAL NOT NULL,
  lng DECIMAL NOT NULL,
  population INT
);

-- Заполнить города КР
INSERT INTO kg_cities (id, name, name_kg, region, lat, lng, population) VALUES
  ('bishkek',      'Бишкек',        'Бишкек',        'Бишкек',            42.8746, 74.5698, 1074075),
  ('osh',          'Ош',            'Ош',             'Ош',                40.5333, 72.8000, 322164),
  ('jalal_abad',   'Джалал-Абад',   'Жалал-Абад',    'Джалал-Абадская',   40.9333, 73.0000, 122490),
  ('karakol',      'Каракол',       'Каракол',        'Иссык-Кульская',    42.4903, 78.3936, 82690),
  ('tokmok',       'Токмок',        'Токмок',         'Чуйская',           42.7667, 75.3000, 71000),
  ('balykchy',     'Балыкчы',       'Балыкчы',        'Иссык-Кульская',    42.4600, 76.1900, 47100),
  ('kara_balta',   'Кара-Балта',    'Кара-Балта',     'Чуйская',           42.8167, 73.8500, 55100),
  ('uzgen',        'Узген',         'Өзгөн',          'Ошская',            40.7700, 73.3000, 68600),
  ('naryn',        'Нарын',         'Нарын',          'Нарынская',         41.4300, 76.0000, 41000),
  ('talas',        'Талас',         'Талас',          'Таласская',         42.5200, 72.2400, 38000),
  ('batken',       'Баткен',        'Баткен',         'Баткенская',        40.0600, 70.8200, 29800),
  ('cholpon_ata',  'Чолпон-Ата',    'Чолпон-Ата',    'Иссык-Кульская',    42.6531, 77.0861, 15400),
  ('kyzyl_kiya',   'Кызыл-Кия',    'Кызыл-Кыя',     'Баткенская',        40.2600, 72.1300, 45500),
  ('kant',         'Кант',          'Кант',           'Чуйская',           42.8917, 74.8514, 25000),
  ('mailuu_suu',   'Майлуу-Суу',    'Майлуу-Суу',    'Джалал-Абадская',   41.2800, 72.4500, 22000)
ON CONFLICT (id) DO NOTHING;

-- ─── Области Кыргызстана ──────────────────────
CREATE TABLE IF NOT EXISTS kg_regions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  name_kg TEXT
);

INSERT INTO kg_regions (id, name, name_kg) VALUES
  ('bishkek',     'г. Бишкек',           'Бишкек шаары'),
  ('osh_city',    'г. Ош',               'Ош шаары'),
  ('chui',        'Чуйская область',     'Чүй облусу'),
  ('issyk_kul',   'Иссык-Кульская обл.', 'Ысык-Көл облусу'),
  ('naryn',       'Нарынская область',    'Нарын облусу'),
  ('talas',       'Таласская область',    'Талас облусу'),
  ('jalal_abad',  'Джалал-Абадская обл.', 'Жалал-Абад облусу'),
  ('osh',         'Ошская область',       'Ош облусу'),
  ('batken',      'Баткенская область',   'Баткен облусу')
ON CONFLICT (id) DO NOTHING;

-- ─── Индексы ──────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_delivery_zones_warehouse ON delivery_zones(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_delivery_zones_company ON delivery_zones(company_id);
CREATE INDEX IF NOT EXISTS idx_delivery_zones_type ON delivery_zones(zone_type);
CREATE INDEX IF NOT EXISTS idx_delivery_zones_active ON delivery_zones(is_active);

-- ─── RPC: Найти доступные бизнесы для клиента ─
CREATE OR REPLACE FUNCTION find_businesses_near(
  p_lat DECIMAL,
  p_lng DECIMAL
)
RETURNS SETOF JSONB AS $$
BEGIN
  -- Зоны типа radius: проверяем расстояние
  RETURN QUERY
  SELECT jsonb_build_object(
    'warehouse_id', dz.warehouse_id,
    'company_id', dz.company_id,
    'zone_name', dz.name,
    'zone_type', dz.zone_type,
    'delivery_fee', dz.delivery_fee,
    'free_delivery_from', dz.free_delivery_from,
    'fee_per_km', dz.fee_per_km,
    'min_order_amount', dz.min_order_amount,
    'estimated_minutes', dz.estimated_minutes,
    'distance_km', ROUND(
      (6371 * acos(
        cos(radians(p_lat)) * cos(radians(dz.center_lat)) *
        cos(radians(dz.center_lng) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(dz.center_lat))
      ))::numeric, 1
    )
  )
  FROM delivery_zones dz
  WHERE dz.is_active = true
    AND dz.zone_type = 'radius'
    AND (6371 * acos(
      cos(radians(p_lat)) * cos(radians(dz.center_lat)) *
      cos(radians(dz.center_lng) - radians(p_lng)) +
      sin(radians(p_lat)) * sin(radians(dz.center_lat))
    )) <= dz.radius_km

  UNION ALL

  -- Зоны типа country: всегда доступны
  SELECT jsonb_build_object(
    'warehouse_id', dz.warehouse_id,
    'company_id', dz.company_id,
    'zone_name', dz.name,
    'zone_type', dz.zone_type,
    'delivery_fee', dz.delivery_fee,
    'free_delivery_from', dz.free_delivery_from,
    'fee_per_km', dz.fee_per_km,
    'min_order_amount', dz.min_order_amount,
    'estimated_minutes', dz.estimated_minutes,
    'distance_km', 0
  )
  FROM delivery_zones dz
  WHERE dz.is_active = true
    AND dz.zone_type = 'country'

  UNION ALL

  -- Зоны типа city: ищем ближайший город
  SELECT jsonb_build_object(
    'warehouse_id', dz.warehouse_id,
    'company_id', dz.company_id,
    'zone_name', dz.name,
    'zone_type', dz.zone_type,
    'delivery_fee', dz.delivery_fee,
    'free_delivery_from', dz.free_delivery_from,
    'fee_per_km', dz.fee_per_km,
    'min_order_amount', dz.min_order_amount,
    'estimated_minutes', dz.estimated_minutes,
    'distance_km', ROUND(
      (6371 * acos(
        cos(radians(p_lat)) * cos(radians(c.lat)) *
        cos(radians(c.lng) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(c.lat))
      ))::numeric, 1
    )
  )
  FROM delivery_zones dz
  JOIN kg_cities c ON c.name = dz.geo_name OR c.id = dz.geo_name
  WHERE dz.is_active = true
    AND dz.zone_type = 'city'
    AND (6371 * acos(
      cos(radians(p_lat)) * cos(radians(c.lat)) *
      cos(radians(c.lng) - radians(p_lng)) +
      sin(radians(p_lat)) * sin(radians(c.lat))
    )) <= 15  -- в пределах 15 км от города

  ORDER BY distance_km;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE delivery_zones;
