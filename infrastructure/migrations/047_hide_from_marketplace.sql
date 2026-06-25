-- ═══════════════════════════════════════════════════════════════════
-- Migration 047: Add hide_from_marketplace to delivery_settings
-- This setting allows hiding specific warehouses/stores from the
-- customer marketplace screens, while leaving them active on the
-- map of free delivery.
-- Run this in Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE delivery_settings ADD COLUMN IF NOT EXISTS hide_from_marketplace BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN delivery_settings.hide_from_marketplace IS 'If true, the store is hidden from the main marketplace and search screens, but available for custom free delivery.';
