-- =============================================
-- Добавить сообщение деактивации к companies
-- Когда админ деактивирует ключ, он может написать причину
-- TakEsep покажет это сообщение владельцу
-- =============================================

ALTER TABLE companies
  ADD COLUMN IF NOT EXISTS deactivation_message TEXT,
  ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ;

COMMENT ON COLUMN companies.deactivation_message IS 'Сообщение от админа при деактивации ключа';
COMMENT ON COLUMN companies.deactivated_at IS 'Когда был деактивирован ключ';

-- RPC для деактивации с сообщением (из админки)
CREATE OR REPLACE FUNCTION admin_deactivate_company(
  p_company_id UUID,
  p_message TEXT DEFAULT 'Ваш аккаунт был деактивирован. Свяжитесь с администрацией.'
)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  UPDATE companies
  SET is_active = false,
      deactivation_message = p_message,
      deactivated_at = now(),
      updated_at = now()
  WHERE id = p_company_id
  RETURNING to_jsonb(companies.*) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC для реактивации
CREATE OR REPLACE FUNCTION admin_reactivate_company(p_company_id UUID)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  UPDATE companies
  SET is_active = true,
      deactivation_message = NULL,
      deactivated_at = NULL,
      updated_at = now()
  WHERE id = p_company_id
  RETURNING to_jsonb(companies.*) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC проверки статуса ключа (TakEsep вызывает периодически)
CREATE OR REPLACE FUNCTION check_license_status(p_license_key TEXT)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'is_active', c.is_active,
    'deactivation_message', c.deactivation_message,
    'deactivated_at', c.deactivated_at,
    'title', c.title
  ) INTO result
  FROM companies c
  WHERE c.license_key = p_license_key;

  IF result IS NULL THEN
    RETURN jsonb_build_object('is_active', false, 'deactivation_message', 'Ключ не найден');
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
