-- 030_warehouse_address_moderation.sql
-- Add moderation fields to warehouses table

ALTER TABLE public.warehouses 
ADD COLUMN pending_address TEXT,
ADD COLUMN pending_lat DECIMAL,
ADD COLUMN pending_lng DECIMAL,
ADD COLUMN address_status TEXT DEFAULT 'verified';

-- Comment on columns
COMMENT ON COLUMN public.warehouses.pending_address IS 'Address waiting for admin approval';
COMMENT ON COLUMN public.warehouses.pending_lat IS 'Latitude waiting for admin approval';
COMMENT ON COLUMN public.warehouses.pending_lng IS 'Longitude waiting for admin approval';
COMMENT ON COLUMN public.warehouses.address_status IS 'Status of the address: verified or pending';

-- Ensure existing rows have verified status
UPDATE public.warehouses SET address_status = 'verified' WHERE address_status IS NULL;

-- Enable Realtime for these new fields (handled if table is already in replica identity full and realtime publication)
