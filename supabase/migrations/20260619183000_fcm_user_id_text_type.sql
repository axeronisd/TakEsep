-- ═══════════════════════════════════════════════════════════════
-- 20260619183000: FCM User ID type to TEXT
-- ═══════════════════════════════════════════════════════════════

-- 1. Drop existing RLS policies on user_fcm_tokens that depend on user_id
DROP POLICY IF EXISTS fcm_tokens_self_manage ON user_fcm_tokens;
DROP POLICY IF EXISTS users_manage_own_tokens ON user_fcm_tokens;

-- 2. Alter user_id column type in user_fcm_tokens and push_notification_log
ALTER TABLE user_fcm_tokens ALTER COLUMN user_id TYPE TEXT;
ALTER TABLE push_notification_log ALTER COLUMN user_id TYPE TEXT;

-- 3. Recreate RLS policies with auth.uid()::text comparison
CREATE POLICY fcm_tokens_self_manage ON user_fcm_tokens
  FOR ALL TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY users_manage_own_tokens ON user_fcm_tokens
  FOR ALL USING (auth.uid()::text = user_id)
  WITH CHECK (auth.uid()::text = user_id);

-- 4. Recreate rpc_upsert_fcm_token function to accept and process TEXT user_id
DROP FUNCTION IF EXISTS rpc_upsert_fcm_token(text, text, text, uuid);
DROP FUNCTION IF EXISTS rpc_upsert_fcm_token(text, text, text, text);

CREATE OR REPLACE FUNCTION rpc_upsert_fcm_token(
  p_app_type TEXT,
  p_fcm_token TEXT,
  p_platform TEXT DEFAULT NULL,
  p_user_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id TEXT;
BEGIN
  -- Fallback to auth.uid() if no custom user_id is provided
  v_user_id := COALESCE(p_user_id, auth.uid()::text);

  -- Remove any existing occurrences of this token to avoid uniqueness conflicts
  DELETE FROM user_fcm_tokens WHERE fcm_token = p_fcm_token;

  -- Insert the new token registry
  INSERT INTO user_fcm_tokens (user_id, fcm_token, app_type, device_platform, updated_at)
  VALUES (v_user_id, p_fcm_token, p_app_type, p_platform, now());

  RETURN jsonb_build_object('status', 'ok');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Recreate rpc_get_push_targets function with cast user_id comparisons
CREATE OR REPLACE FUNCTION rpc_get_push_targets(
  p_order_id UUID,
  p_event TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_result JSONB;
BEGIN
  -- Load order
  SELECT * INTO v_order
  FROM delivery_orders
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('tokens', '[]'::jsonb, 'error', 'order_not_found');
  END IF;

  CASE p_event
    -- New order → notify warehouse staff
    WHEN 'new_order' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '🛒 Новый заказ!',
          'body', 'Заказ ' || v_order.order_number || ' ожидает подтверждения',
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      WHERE t.app_type = 'warehouse';

    -- Order ready → notify nearest 5 online couriers
    WHEN 'courier_needed' THEN
      WITH nearest_couriers AS (
        SELECT t.fcm_token, t.app_type, t.device_platform,
          (6371.0 * acos(
            cos(radians(v_order.pickup_lat::double precision)) * cos(radians(c.latitude::double precision)) *
            cos(radians(c.longitude::double precision) - radians(v_order.pickup_lng::double precision)) +
            sin(radians(v_order.pickup_lat::double precision)) * sin(radians(c.latitude::double precision))
          )) as distance
        FROM user_fcm_tokens t
        JOIN couriers c ON c.user_id::text = t.user_id
        WHERE t.app_type = 'courier'
          AND c.is_online = true
          AND c.latitude IS NOT NULL
          AND c.longitude IS NOT NULL
        ORDER BY distance ASC
        LIMIT 5
      ),
      all_online AS (
        SELECT t.fcm_token, t.app_type, t.device_platform
        FROM user_fcm_tokens t
        JOIN couriers c ON c.user_id::text = t.user_id
        WHERE t.app_type = 'courier'
          AND c.is_online = true
      )
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', r.fcm_token,
          'title', '📦 Заказ ждёт курьера!',
          'body', 'Заказ ' || v_order.order_number || ' готов к доставке',
          'app_type', r.app_type,
          'device_platform', r.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM (
        SELECT fcm_token, app_type, device_platform FROM nearest_couriers
        UNION
        -- Fallback if no nearest couriers found
        SELECT fcm_token, app_type, device_platform FROM all_online
        WHERE NOT EXISTS (SELECT 1 FROM nearest_couriers)
        LIMIT 5
      ) r;

    -- Courier assigned → notify customer
    WHEN 'courier_found' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '🚴 Курьер найден!',
          'body', 'Курьер скоро заберёт ваш заказ ' || v_order.order_number,
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id::text = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    -- Picked up → notify customer
    WHEN 'picked_up' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '🚚 Заказ в пути!',
          'body', 'Курьер забрал ваш заказ и едет к вам',
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id::text = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    -- Delivered → notify customer
    WHEN 'delivered' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '✅ Доставлено!',
          'body', 'Заказ ' || v_order.order_number || ' доставлен. Приятного аппетита!',
          'app_type', t.app_type,
          'device_platform', t.device_platform
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id::text = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    ELSE
      v_result := jsonb_build_object('tokens', '[]'::jsonb, 'error', 'unknown_event');
  END CASE;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
