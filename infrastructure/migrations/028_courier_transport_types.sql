-- ═══════════════════════════════════════════════════════════════
-- Migration 027: Add transport_types JSONB to couriers
-- Allows specifying multiple transportation options per courier
-- ═══════════════════════════════════════════════════════════════

-- Add JSONB column for multiple transport types
ALTER TABLE couriers
ADD COLUMN IF NOT EXISTS transport_types JSONB DEFAULT '[]'::jsonb;

-- Migrate existing data: convert single transport_type to array
UPDATE couriers
SET transport_types = to_jsonb(ARRAY[transport_type])
WHERE transport_types = '[]'::jsonb
   OR transport_types IS NULL
   OR jsonb_array_length(transport_types) = 0;
