-- ═══════════════════════════════════════════════════
-- 008: AkJol Maps — База адресов
-- ═══════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;

CREATE TABLE addresses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  street TEXT NOT NULL,
  house_number TEXT,
  building_name TEXT,
  city TEXT DEFAULT 'Бишкек',
  district TEXT,
  entrance TEXT,
  floor_count INT,
  category TEXT,
  verified BOOLEAN DEFAULT false,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_addresses_geo ON addresses USING gist (
  ST_SetSRID(ST_MakePoint(lng, lat), 4326)
);
CREATE INDEX idx_addresses_street ON addresses(street);
CREATE INDEX idx_addresses_city ON addresses(city);
CREATE INDEX idx_addresses_verified ON addresses(verified);

-- RLS
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;

-- Все могут читать верифицированные адреса
CREATE POLICY "addresses_select" ON addresses
  FOR SELECT USING (verified = true);

-- Авторизованные могут добавлять
CREATE POLICY "addresses_insert" ON addresses
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Функция: найти ближайшие адреса
CREATE OR REPLACE FUNCTION nearby_addresses(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_m INT DEFAULT 500
)
RETURNS SETOF addresses
LANGUAGE sql STABLE
AS $$
  SELECT *
  FROM addresses
  WHERE verified = true
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_m
    )
  ORDER BY ST_Distance(
    ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  )
  LIMIT 50;
$$;
