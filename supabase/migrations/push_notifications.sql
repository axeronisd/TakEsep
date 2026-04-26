-- ═══════════════════════════════════════════════════════════════
-- TakEsep Push Notifications — Database Migration
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- 1. FCM Token storage
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  app_type TEXT NOT NULL CHECK (app_type IN ('customer', 'courier', 'warehouse')),
  platform TEXT NOT NULL DEFAULT 'android',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(fcm_token)
);

-- Index for fast lookup by user + app
CREATE INDEX IF NOT EXISTS idx_fcm_user_app ON user_fcm_tokens(user_id, app_type);

-- Enable RLS
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Users can manage their own tokens
CREATE POLICY "users_manage_own_tokens" ON user_fcm_tokens
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role can read all (for Edge Functions)
CREATE POLICY "service_read_all_tokens" ON user_fcm_tokens
  FOR SELECT USING (true);

-- 2. Upsert RPC (called from Flutter apps)
DROP FUNCTION IF EXISTS rpc_upsert_fcm_token(text, text, text);
CREATE OR REPLACE FUNCTION rpc_upsert_fcm_token(
  p_app_type TEXT,
  p_fcm_token TEXT,
  p_platform TEXT
) RETURNS void AS $$
BEGIN
  INSERT INTO user_fcm_tokens (user_id, fcm_token, app_type, platform, updated_at)
  VALUES (auth.uid(), p_fcm_token, p_app_type, p_platform, now())
  ON CONFLICT (fcm_token) DO UPDATE SET
    user_id = auth.uid(),
    app_type = p_app_type,
    platform = p_platform,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Notification log (optional, for debugging)
CREATE TABLE IF NOT EXISTS push_notification_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  app_type TEXT,
  title TEXT,
  body TEXT,
  data JSONB,
  sent_at TIMESTAMPTZ DEFAULT now(),
  status TEXT DEFAULT 'sent'
);

-- RLS for log
ALTER TABLE push_notification_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_manage_logs" ON push_notification_log FOR ALL USING (true);
