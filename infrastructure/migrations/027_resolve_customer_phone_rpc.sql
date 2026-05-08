-- ═══════════════════════════════════════════════════════════════
-- 027: Resolve Customer Phone RPC
-- Fallback function for courier app when delivery_orders.customer_id
-- is an auth.users UUID without a matching customers row.
-- Uses SECURITY DEFINER to read auth.users directly.
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION rpc_resolve_customer_phone(p_customer_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_customer RECORD;
  v_profile RECORD;
  v_auth_user RECORD;
BEGIN
  -- 1. Try customers by id
  SELECT phone, user_id INTO v_customer FROM customers WHERE id = p_customer_id;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'source', 'customers',
      'phone', v_customer.phone,
      'user_id', v_customer.user_id
    );
  END IF;

  -- 2. Try customers by user_id (in case customer_id is auth UUID)
  SELECT phone, user_id INTO v_customer FROM customers WHERE user_id = p_customer_id;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'source', 'customers_by_user_id',
      'phone', v_customer.phone,
      'user_id', v_customer.user_id
    );
  END IF;

  -- 3. Try user_profiles by id
  SELECT phone INTO v_profile FROM user_profiles WHERE id = p_customer_id;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'source', 'user_profiles',
      'phone', v_profile.phone
    );
  END IF;

  -- 4. Try auth.users directly (SECURITY DEFINER bypasses RLS here)
  SELECT phone INTO v_auth_user FROM auth.users WHERE id = p_customer_id;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'source', 'auth.users',
      'phone', v_auth_user.phone
    );
  END IF;

  RETURN jsonb_build_object('source', 'none', 'phone', null);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
