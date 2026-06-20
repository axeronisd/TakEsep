-- ═══════════════════════════════════════════════════════════════
-- 20260620221300: Add rpc_delete_fcm_token to bypass RLS limits
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION rpc_delete_fcm_token(
  p_fcm_token TEXT
)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM user_fcm_tokens WHERE fcm_token = p_fcm_token;
  RETURN jsonb_build_object('status', 'ok');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
