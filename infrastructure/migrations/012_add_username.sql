-- =============================================
-- AkJol — Добавление username в профили
-- =============================================

-- Добавляем username
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;

-- Индекс для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_user_profiles_username ON user_profiles(username);

-- Функция поиска пользователя по username для входа
CREATE OR REPLACE FUNCTION find_user_by_username(p_username TEXT)
RETURNS TABLE(phone TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT up.phone FROM user_profiles up
  WHERE up.username = lower(p_username)
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Обновить триггер: сохранять username при регистрации
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, phone, name, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.phone, ''),
    COALESCE(NEW.raw_user_meta_data ->> 'name', ''),
    COALESCE(NEW.raw_user_meta_data ->> 'username', NULL)
  )
  ON CONFLICT (id) DO UPDATE SET
    phone = COALESCE(EXCLUDED.phone, user_profiles.phone),
    username = COALESCE(EXCLUDED.username, user_profiles.username),
    updated_at = now();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
