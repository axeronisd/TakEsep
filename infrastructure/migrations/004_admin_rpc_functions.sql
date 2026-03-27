-- Drop old functions if they exist
DROP FUNCTION IF EXISTS admin_create_company(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS admin_toggle_company(TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS admin_update_license_key(TEXT, TEXT);

-- RPC function to create a company, bypassing RLS
CREATE OR REPLACE FUNCTION admin_create_company(
  p_id UUID,
  p_title TEXT,
  p_license_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSONB;
BEGIN
  INSERT INTO companies (id, title, license_key, is_active, created_at, updated_at)
  VALUES (p_id, p_title, p_license_key, true, NOW(), NOW())
  RETURNING to_jsonb(companies.*) INTO result;
  
  RETURN result;
END;
$$;

-- RPC function to toggle company active status
CREATE OR REPLACE FUNCTION admin_toggle_company(
  p_company_id UUID,
  p_is_active BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE companies
  SET is_active = p_is_active, updated_at = NOW()
  WHERE id = p_company_id;
END;
$$;

-- RPC function to update license key
CREATE OR REPLACE FUNCTION admin_update_license_key(
  p_company_id UUID,
  p_license_key TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE companies
  SET license_key = p_license_key, updated_at = NOW()
  WHERE id = p_company_id;
END;
$$;
