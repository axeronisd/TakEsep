-- ═══════════════════════════════════════════════════════════════
-- 031: Realtime Updates and FCM Push Registration Fixes
-- ═══════════════════════════════════════════════════════════════

-- 1. Enable REPLICA IDENTITY FULL on delivery_orders
-- This ensures that PostgreSQL sends the full row (including courier_id) in UPDATE events,
-- allowing Supabase Realtime filters like "courier_id = eq.XYZ" to work correctly when status changes.
ALTER TABLE delivery_orders REPLICA IDENTITY FULL;

-- 2. Modify user_fcm_tokens to allow non-auth users (couriers, warehouse)
-- Drop the foreign key constraint to auth.users
ALTER TABLE user_fcm_tokens DROP CONSTRAINT IF EXISTS user_fcm_tokens_user_id_fkey;

-- Drop the composite primary key constraint (which requires user_id to be NOT NULL)
ALTER TABLE user_fcm_tokens DROP CONSTRAINT IF EXISTS user_fcm_tokens_pkey;

-- Make user_id nullable
ALTER TABLE user_fcm_tokens ALTER COLUMN user_id DROP NOT NULL;

-- Make fcm_token the primary key (it is unique and NOT NULL)
ALTER TABLE user_fcm_tokens ADD CONSTRAINT user_fcm_tokens_pkey PRIMARY KEY (fcm_token);

-- 3. Update the token upsert function to support manual user_id
DROP FUNCTION IF EXISTS rpc_upsert_fcm_token(text, text, text);

CREATE OR REPLACE FUNCTION rpc_upsert_fcm_token(
  p_app_type TEXT,
  p_fcm_token TEXT,
  p_platform TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Fallback to auth.uid() if no custom user_id is provided
  v_user_id := COALESCE(p_user_id, auth.uid());

  -- Remove any existing occurrences of this token to avoid uniqueness conflicts
  DELETE FROM user_fcm_tokens WHERE fcm_token = p_fcm_token;

  -- Insert the new token registry
  INSERT INTO user_fcm_tokens (user_id, fcm_token, app_type, device_platform, updated_at)
  VALUES (v_user_id, p_fcm_token, p_app_type, p_platform, now());

  RETURN jsonb_build_object('status', 'ok');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
