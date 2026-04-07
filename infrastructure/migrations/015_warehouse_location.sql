-- Migration 015: Add location fields to warehouses
-- Stores GPS coordinates and floor info for courier delivery

ALTER TABLE warehouses ADD COLUMN IF NOT EXISTS latitude DECIMAL;
ALTER TABLE warehouses ADD COLUMN IF NOT EXISTS longitude DECIMAL;
ALTER TABLE warehouses ADD COLUMN IF NOT EXISTS floor_info TEXT;

COMMENT ON COLUMN warehouses.latitude IS 'GPS latitude of warehouse location';
COMMENT ON COLUMN warehouses.longitude IS 'GPS longitude of warehouse location';
COMMENT ON COLUMN warehouses.floor_info IS 'Floor/office info for courier navigation, e.g. "2 этаж, офис 205"';
