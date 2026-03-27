-- Add subscription tracking fields to companies table
ALTER TABLE companies
  ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'basic',
  ADD COLUMN IF NOT EXISTS subscription_start TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS subscription_end TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days');

-- Add a comment for documentation
COMMENT ON COLUMN companies.subscription_plan IS 'Subscription plan: basic, pro, premium';
COMMENT ON COLUMN companies.subscription_start IS 'When the current subscription period started';
COMMENT ON COLUMN companies.subscription_end IS 'When the current subscription expires';
