-- =============================================
-- AkJol Ecosystem — Единый профиль пользователя
-- Яндекс-стиль: один аккаунт = все сервисы
-- Run AFTER 006_akjol_delivery.sql
-- =============================================

-- ─── Единый профиль ──────────────────────────
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone TEXT NOT NULL UNIQUE,
  name TEXT,
  avatar_url TEXT,
  bio TEXT,
  
  -- Роли (один аккаунт может быть всем)
  is_customer BOOLEAN NOT NULL DEFAULT true,
  is_courier BOOLEAN NOT NULL DEFAULT false,
  is_driver BOOLEAN NOT NULL DEFAULT false,
  is_business_owner BOOLEAN NOT NULL DEFAULT false,
  
  -- Локация (Кыргызстан)
  city TEXT DEFAULT 'Бишкек',
  default_address TEXT,
  default_lat DECIMAL,
  default_lng DECIMAL,
  
  -- Статистика
  rating DECIMAL(3,2) DEFAULT 5.00,
  total_orders INT DEFAULT 0,
  total_spent DECIMAL(12,2) DEFAULT 0,
  
  -- Мета
  language TEXT DEFAULT 'ru',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── RLS ──────────────────────────────────────
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Пользователь может читать любой профиль (для соц. сети, чатов)
CREATE POLICY "user_profiles_read" ON user_profiles
  FOR SELECT TO authenticated USING (true);

-- Пользователь может обновлять только свой профиль
CREATE POLICY "user_profiles_update" ON user_profiles
  FOR UPDATE TO authenticated USING (id = auth.uid());

-- Пользователь может создать свой профиль при регистрации
CREATE POLICY "user_profiles_insert" ON user_profiles
  FOR INSERT TO authenticated WITH CHECK (id = auth.uid());

-- ─── Автосоздание профиля при регистрации ─────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, phone, name)
  VALUES (
    NEW.id,
    COALESCE(NEW.phone, ''),
    COALESCE(NEW.raw_user_meta_data ->> 'name', '')
  )
  ON CONFLICT (id) DO UPDATE SET
    phone = COALESCE(EXCLUDED.phone, user_profiles.phone),
    updated_at = now();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Триггер на auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ─── Функция обновления профиля ───────────────
CREATE OR REPLACE FUNCTION update_user_profile(
  p_name TEXT DEFAULT NULL,
  p_avatar_url TEXT DEFAULT NULL,
  p_city TEXT DEFAULT NULL,
  p_default_address TEXT DEFAULT NULL,
  p_default_lat DECIMAL DEFAULT NULL,
  p_default_lng DECIMAL DEFAULT NULL,
  p_language TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  UPDATE user_profiles SET
    name = COALESCE(p_name, name),
    avatar_url = COALESCE(p_avatar_url, avatar_url),
    city = COALESCE(p_city, city),
    default_address = COALESCE(p_default_address, default_address),
    default_lat = COALESCE(p_default_lat, default_lat),
    default_lng = COALESCE(p_default_lng, default_lng),
    language = COALESCE(p_language, language),
    updated_at = now()
  WHERE id = auth.uid()
  RETURNING to_json(user_profiles.*) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── Индексы ──────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_user_profiles_phone ON user_profiles(phone);
CREATE INDEX IF NOT EXISTS idx_user_profiles_city ON user_profiles(city);

-- ─── Realtime ─────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE user_profiles;
