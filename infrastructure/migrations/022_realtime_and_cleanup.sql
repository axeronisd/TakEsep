-- ═══════════════════════════════════════════════════════════════
-- 022: Realtime Publication + Cleanup RPC
-- Enables Supabase Realtime for delivery tracking tables
-- and adds auto-cancellation for expired orders
-- Run in Supabase SQL Editor AFTER 021
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Enable Realtime (idempotent) ──────────────────────────

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE delivery_orders;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE couriers;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- ─── 2. Auto-cancel expired orders (no courier after 30 min) ──

CREATE OR REPLACE FUNCTION rpc_cleanup_expired_orders()
RETURNS JSONB AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE delivery_orders
  SET status = 'cancelled_no_courier',
      cancel_reason = 'Нет свободных курьеров (таймаут 30 мин)'
  WHERE status = 'ready'
    AND created_at < now() - INTERVAL '30 minutes';

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'cancelled_count', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
