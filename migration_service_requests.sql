-- ═══════════════════════════════════════════════════════════════
-- Service Requests — заявки на услуги от клиентов Ак Жол
-- ═══════════════════════════════════════════════════════════════

-- Таблица заявок клиентов на услуги
CREATE TABLE IF NOT EXISTS service_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  customer_phone TEXT,
  address TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'in_progress', 'completed', 'cancelled')),
  scheduled_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  price_final NUMERIC(12,2),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_service_requests_company
  ON service_requests(company_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_customer
  ON service_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_status
  ON service_requests(status);
CREATE INDEX IF NOT EXISTS idx_service_requests_service
  ON service_requests(service_id);

-- RLS
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;

-- Клиенты могут создавать заявки
CREATE POLICY "Customers can insert service_requests"
  ON service_requests FOR INSERT
  WITH CHECK (true);

-- Клиенты могут видеть свои заявки
CREATE POLICY "Customers can view own service_requests"
  ON service_requests FOR SELECT
  USING (customer_id = auth.uid());

-- Бизнесы могут видеть заявки к своей компании
CREATE POLICY "Companies can view their service_requests"
  ON service_requests FOR SELECT
  USING (company_id IN (
    SELECT id FROM companies WHERE owner_id = auth.uid()
  ));

-- Бизнесы могут обновлять заявки к своей компании
CREATE POLICY "Companies can update their service_requests"
  ON service_requests FOR UPDATE
  USING (company_id IN (
    SELECT id FROM companies WHERE owner_id = auth.uid()
  ));

-- Anon может создавать заявки (для незалогиненных)
CREATE POLICY "Anon can insert service_requests"
  ON service_requests FOR INSERT
  WITH CHECK (customer_id IS NULL);

-- Trigger для updated_at
CREATE OR REPLACE FUNCTION update_service_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER service_requests_updated_at
  BEFORE UPDATE ON service_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_service_requests_updated_at();
