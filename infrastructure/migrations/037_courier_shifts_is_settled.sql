-- ==============================================================
-- 037: Courier shifts settlement (is_settled field and RPC helper)
-- ==============================================================

-- 1. Add settlement fields to courier_shifts
ALTER TABLE courier_shifts ADD COLUMN IF NOT EXISTS is_settled BOOLEAN DEFAULT false;
ALTER TABLE courier_shifts ADD COLUMN IF NOT EXISTS settled_at TIMESTAMPTZ;
ALTER TABLE courier_shifts ADD COLUMN IF NOT EXISTS settled_by UUID;

-- Create index for quick filtering of unsettled shifts
CREATE INDEX IF NOT EXISTS idx_courier_shifts_unsettled ON courier_shifts(courier_id, is_settled) WHERE ended_at IS NOT NULL;

-- 2. Create RPC function to settle/close shift debt
CREATE OR REPLACE FUNCTION rpc_settle_courier_shift(
  p_shift_id UUID,
  p_admin_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE courier_shifts
  SET is_settled = true,
      settled_at = now(),
      settled_by = p_admin_id
  WHERE id = p_shift_id;
END;
$$;
