-- =============================================
-- AkJol Delivery — Дополнительные RLS Policies
-- Run AFTER 006_akjol_delivery.sql
-- 
-- Примечание: 006 уже создала базовые RLS policies
-- Этот файл добавляет индексы для производительности
-- =============================================

-- ─── INDEXES FOR PERFORMANCE ─────────────────
CREATE INDEX IF NOT EXISTS idx_delivery_orders_customer ON delivery_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_warehouse ON delivery_orders(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_courier ON delivery_orders(courier_id);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_status ON delivery_orders(status);
CREATE INDEX IF NOT EXISTS idx_delivery_orders_created ON delivery_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_couriers_warehouse ON couriers(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_couriers_user ON couriers(user_id);
CREATE INDEX IF NOT EXISTS idx_courier_shifts_courier ON courier_shifts(courier_id);
CREATE INDEX IF NOT EXISTS idx_delivery_order_items_order ON delivery_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_ratings_order ON delivery_ratings(order_id);
CREATE INDEX IF NOT EXISTS idx_customer_addresses_customer ON customer_addresses(customer_id);
