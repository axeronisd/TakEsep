-- ═══════════════════════════════════════════════════════════════
-- 014: Hybrid Courier System
-- Adds courier types, invitations, and multi-warehouse binding
-- Run in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- 1. Добавляем тип курьера (фрилансер или штатный)
ALTER TABLE couriers ADD COLUMN IF NOT EXISTS courier_type TEXT NOT NULL DEFAULT 'freelance';
-- 'freelance' = сам зарегистрировался, берёт любые заказы
-- 'store'     = привязан к магазину, приоритет на заказы

-- 2. Таблица приглашений
CREATE TABLE IF NOT EXISTS courier_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  courier_id UUID REFERENCES couriers(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending | accepted | declined
  invited_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  responded_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_courier_invitations_phone ON courier_invitations(phone);
CREATE INDEX IF NOT EXISTS idx_courier_invitations_warehouse ON courier_invitations(warehouse_id);

-- 3. Связь курьер ↔ склад (многие-ко-многим)
--    Один курьер может быть штатным в нескольких магазинах
CREATE TABLE IF NOT EXISTS courier_warehouse (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID NOT NULL REFERENCES couriers(id) ON DELETE CASCADE,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  joined_at TIMESTAMPTZ DEFAULT now(),
  left_at TIMESTAMPTZ, -- заполняется, когда курьер уходит
  UNIQUE(courier_id, warehouse_id)
);

CREATE INDEX IF NOT EXISTS idx_courier_warehouse_courier ON courier_warehouse(courier_id);
CREATE INDEX IF NOT EXISTS idx_courier_warehouse_warehouse ON courier_warehouse(warehouse_id);

-- ═══════════════════════════════════════════════════════════════
-- RLS Policies
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE courier_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE courier_warehouse ENABLE ROW LEVEL SECURITY;

-- Invitations: readable/writable by all authenticated
CREATE POLICY "courier_invitations_read" ON courier_invitations 
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "courier_invitations_write" ON courier_invitations 
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Courier-warehouse binding: readable/writable by all authenticated
CREATE POLICY "courier_warehouse_read" ON courier_warehouse 
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "courier_warehouse_write" ON courier_warehouse 
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════
-- Realtime (для уведомлений о новых приглашениях)
-- ═══════════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE courier_invitations;
ALTER PUBLICATION supabase_realtime ADD TABLE courier_warehouse;
