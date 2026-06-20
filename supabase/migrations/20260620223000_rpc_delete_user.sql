-- ═══════════════════════════════════════════════════════════════
-- 20260620223000: Add rpc_delete_user security definer function
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION rpc_delete_user(
  p_user_id UUID
)
RETURNS VOID AS $$
BEGIN
  -- Perform delete operation from auth.users schemas
  DELETE FROM auth.users WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
