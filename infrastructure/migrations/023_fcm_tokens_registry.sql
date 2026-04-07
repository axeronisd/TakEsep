-- ═══════════════════════════════════════════════════════════════
-- 023: FCM Token Registry
-- Push notification token storage for all three apps
-- Run in Supabase SQL Editor AFTER 022
-- ═══════════════════════════════════════════════════════════════


-- ─── 1. Token registry table ──────────────────────────────────

CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  app_type TEXT NOT NULL CHECK (app_type IN ('customer', 'warehouse', 'courier')),
  device_platform TEXT CHECK (device_platform IN ('android', 'ios', 'web', 'windows', 'macos', 'linux')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, fcm_token)
);

-- Index for fast lookup by app_type (when sending pushes to couriers/customers)
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_app_type
  ON user_fcm_tokens(app_type);

-- Index for cleanup of stale tokens
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_updated
  ON user_fcm_tokens(updated_at);

-- ─── 2. RLS ───────────────────────────────────────────────────

ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Users can manage their own tokens
CREATE POLICY "fcm_tokens_self_manage" ON user_fcm_tokens
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Edge Functions (service_role) can read all tokens for push dispatch
-- (service_role bypasses RLS by default, no policy needed)


-- ─── 3. Upsert RPC ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION rpc_upsert_fcm_token(
  p_app_type TEXT,
  p_fcm_token TEXT,
  p_platform TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
  -- Delete any old record with the same token (different user logged in on same device)
  DELETE FROM user_fcm_tokens
  WHERE fcm_token = p_fcm_token
    AND user_id != auth.uid();

  -- Upsert for current user
  INSERT INTO user_fcm_tokens (user_id, fcm_token, app_type, device_platform)
  VALUES (auth.uid(), p_fcm_token, p_app_type, p_platform)
  ON CONFLICT (user_id, fcm_token) DO UPDATE SET
    app_type = EXCLUDED.app_type,
    device_platform = EXCLUDED.device_platform,
    updated_at = now();

  RETURN jsonb_build_object('status', 'ok');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 4. Cleanup stale tokens (older than 30 days) ─────────────

CREATE OR REPLACE FUNCTION rpc_cleanup_stale_fcm_tokens()
RETURNS JSONB AS $$
DECLARE
  v_count INT;
BEGIN
  DELETE FROM user_fcm_tokens
  WHERE updated_at < now() - INTERVAL '30 days';

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('cleaned', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ─── 5. Helper: get tokens for a specific order event ─────────
-- Used by Edge Function to find who to notify

CREATE OR REPLACE FUNCTION rpc_get_push_targets(
  p_order_id UUID,
  p_event TEXT  -- 'new_order', 'courier_found', 'picked_up', 'delivered'
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
          'body', 'Заказ ' || v_order.order_number || ' ожидает подтверждения'
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      WHERE t.app_type = 'warehouse';
      -- Note: In production, filter by warehouse staff user_ids

    -- Order ready → notify couriers
    WHEN 'courier_needed' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '📦 Заказ ждёт курьера!',
          'body', 'Заказ ' || v_order.order_number || ' готов к доставке'
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      WHERE t.app_type = 'courier';

    -- Courier assigned → notify customer
    WHEN 'courier_found' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '🚴 Курьер найден!',
          'body', 'Курьер скоро заберёт ваш заказ ' || v_order.order_number
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    -- Picked up → notify customer
    WHEN 'picked_up' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '🚚 Заказ в пути!',
          'body', 'Курьер забрал ваш заказ и едет к вам'
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    -- Delivered → notify customer
    WHEN 'delivered' THEN
      SELECT jsonb_build_object(
        'tokens', COALESCE(jsonb_agg(jsonb_build_object(
          'token', t.fcm_token,
          'title', '✅ Доставлено!',
          'body', 'Заказ ' || v_order.order_number || ' доставлен. Приятного аппетита!'
        )), '[]'::jsonb)
      ) INTO v_result
      FROM user_fcm_tokens t
      JOIN customers c ON c.user_id = t.user_id
      WHERE c.id = v_order.customer_id
        AND t.app_type = 'customer';

    ELSE
      v_result := jsonb_build_object('tokens', '[]'::jsonb, 'error', 'unknown_event');
  END CASE;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
