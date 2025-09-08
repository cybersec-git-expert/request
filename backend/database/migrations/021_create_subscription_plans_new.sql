BEGIN;

CREATE TABLE IF NOT EXISTS subscription_plans_new (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_id VARCHAR(255) UNIQUE,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('rider','business')),
  plan_type TEXT NOT NULL CHECK (plan_type IN ('monthly','yearly','pay_per_click')),
  description TEXT,
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  duration_days INT NOT NULL DEFAULT 30,
  features JSONB NOT NULL DEFAULT '[]'::jsonb,
  limitations JSONB NOT NULL DEFAULT '{}'::jsonb,
  countries TEXT[] NULL,
  pricing_by_country JSONB NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default_plan BOOLEAN NOT NULL DEFAULT false,
  requires_country_pricing BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscription_plans_new_active ON subscription_plans_new(is_active);
CREATE INDEX IF NOT EXISTS idx_subscription_plans_new_type ON subscription_plans_new(type);
CREATE INDEX IF NOT EXISTS idx_subscription_plans_new_plan_type ON subscription_plans_new(plan_type);
CREATE INDEX IF NOT EXISTS idx_subscription_plans_new_is_default ON subscription_plans_new(is_default_plan);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION trg_subscription_plans_new_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp_subscription_plans_new ON subscription_plans_new;
CREATE TRIGGER set_timestamp_subscription_plans_new
BEFORE UPDATE ON subscription_plans_new
FOR EACH ROW EXECUTE FUNCTION trg_subscription_plans_new_updated_at();

COMMIT;
