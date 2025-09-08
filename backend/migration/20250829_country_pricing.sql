-- Country-specific overrides for subscription plans (pricing, currency, limitations)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS subscription_plan_country_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES subscription_plans_new(id) ON DELETE CASCADE,
  country_code CHAR(2) NOT NULL,
  price NUMERIC(10,2) NULL,
  currency TEXT NULL,
  limitations JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (plan_id, country_code)
);

CREATE INDEX IF NOT EXISTS idx_spcp_plan ON subscription_plan_country_pricing(plan_id);
CREATE INDEX IF NOT EXISTS idx_spcp_country ON subscription_plan_country_pricing(country_code);
