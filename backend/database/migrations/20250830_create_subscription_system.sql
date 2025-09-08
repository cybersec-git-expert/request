-- Create subscription management tables
-- Plans are global (super admin creates/approves). Country admins set pricing and response limits per country.

BEGIN;

-- 1) Global subscription plans (super admin)
CREATE TABLE IF NOT EXISTS subscription_plans (
  id SERIAL PRIMARY KEY,
  code VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  plan_type VARCHAR(20) NOT NULL CHECK (plan_type IN ('basic','unlimited','ppc')),
  default_responses_per_month INTEGER,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','inactive')),
  approved_by VARCHAR(100),
  approved_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION trg_update_subscription_plans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_subscription_plans_updated_at ON subscription_plans;
CREATE TRIGGER trg_subscription_plans_updated_at
BEFORE UPDATE ON subscription_plans
FOR EACH ROW EXECUTE FUNCTION trg_update_subscription_plans_updated_at();

-- 2) Per-country plan settings (country admin)
CREATE TABLE IF NOT EXISTS subscription_country_settings (
  id SERIAL PRIMARY KEY,
  plan_id INTEGER NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
  country_code VARCHAR(10) NOT NULL,
  currency VARCHAR(10) NOT NULL,
  price NUMERIC(12,2),
  responses_per_month INTEGER, -- override for basic plans
  ppc_price NUMERIC(12,3),     -- per-click price for PPC plans
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  created_by VARCHAR(100),
  updated_by VARCHAR(100),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(plan_id, country_code)
);

CREATE OR REPLACE FUNCTION trg_update_subscription_country_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_subscription_country_settings_updated_at ON subscription_country_settings;
CREATE TRIGGER trg_subscription_country_settings_updated_at
BEFORE UPDATE ON subscription_country_settings
FOR EACH ROW EXECUTE FUNCTION trg_update_subscription_country_settings_updated_at();

-- 3) Map business types to plans (per country)
CREATE TABLE IF NOT EXISTS business_type_plan_mappings (
  id SERIAL PRIMARY KEY,
  country_code VARCHAR(10) NOT NULL,
  business_type_id INTEGER NOT NULL REFERENCES business_types(id) ON DELETE CASCADE,
  plan_id INTEGER NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(country_code, business_type_id, plan_id)
);

CREATE OR REPLACE FUNCTION trg_update_business_type_plan_mappings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_business_type_plan_mappings_updated_at ON business_type_plan_mappings;
CREATE TRIGGER trg_business_type_plan_mappings_updated_at
BEFORE UPDATE ON business_type_plan_mappings
FOR EACH ROW EXECUTE FUNCTION trg_update_business_type_plan_mappings_updated_at();

-- 4) Allowed request types for a mapping (which request types a business type can respond to under a plan)
CREATE TABLE IF NOT EXISTS business_type_plan_allowed_request_types (
  id SERIAL PRIMARY KEY,
  mapping_id INTEGER NOT NULL REFERENCES business_type_plan_mappings(id) ON DELETE CASCADE,
  request_type VARCHAR(50) NOT NULL, -- e.g. item, service, ride, rent, delivery
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(mapping_id, request_type)
);

-- 5) Seed the three default global plans (pending by default)
INSERT INTO subscription_plans (code, name, description, plan_type, default_responses_per_month, status)
VALUES
  ('basic', 'Basic', 'Basic plan with limited responses per month', 'basic', 3, 'pending'),
  ('unlimited', 'Unlimited', 'Unlimited responses per month', 'unlimited', NULL, 'pending'),
  ('ppc', 'Pay Per Click', 'Pay-per-click responses', 'ppc', NULL, 'pending')
ON CONFLICT (code) DO NOTHING;

COMMIT;
