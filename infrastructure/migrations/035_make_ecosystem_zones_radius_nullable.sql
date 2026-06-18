-- ==============================================================
-- 035: Make radius_km nullable on ecosystem_zones for polygon support
-- ==============================================================

ALTER TABLE public.ecosystem_zones ALTER COLUMN radius_km DROP NOT NULL;
