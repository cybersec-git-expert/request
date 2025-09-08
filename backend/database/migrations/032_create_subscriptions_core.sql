BEGIN;

-- Country overrides for each plan (price, currency, response limits, options)
CREATE TABLE IF NOT EXISTS subscription_country_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES subscription_plans_new(id) ON DELETE CASCADE,
  country_code CHAR(3) NOT NULL,
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  response_limit INT, -- per month limit override (NULL means unlimited or use plan limitations)
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  show_contact_details BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(plan_id, country_code)
);

CREATE INDEX IF NOT EXISTS idx_subscription_country_pricing_country ON subscription_country_pricing(country_code);
CREATE INDEX IF NOT EXISTS idx_subscription_country_pricing_active ON subscription_country_pricing(is_active);

CREATE OR REPLACE FUNCTION trg_subscription_country_pricing_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp_subscription_country_pricing ON subscription_country_pricing;
CREATE TRIGGER set_timestamp_subscription_country_pricing
BEFORE UPDATE ON subscription_country_pricing
FOR EACH ROW EXECUTE FUNCTION trg_subscription_country_pricing_updated_at();

-- User subscriptions
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES subscription_plans_new(id) ON DELETE RESTRICT,
  country_code CHAR(3) NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active|trialing|past_due|canceled|expired|pending_payment
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ends_at TIMESTAMPTZ,
  next_renewal_at TIMESTAMPTZ,
  auto_renew BOOLEAN NOT NULL DEFAULT true,
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  promo_code_id UUID REFERENCES promo_codes(id),
  promo_metadata JSONB,
  gateway_provider TEXT, -- e.g. stripe, payhere, midtrans
  gateway_subscription_id TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user ON user_subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_active ON user_subscriptions(status, ends_at);

CREATE OR REPLACE FUNCTION trg_user_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp_user_subscriptions ON user_subscriptions;
CREATE TRIGGER set_timestamp_user_subscriptions
BEFORE UPDATE ON user_subscriptions
FOR EACH ROW EXECUTE FUNCTION trg_user_subscriptions_updated_at();

-- Monthly usage counter for responses per user (reset by year_month)
CREATE TABLE IF NOT EXISTS usage_monthly (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  year_month CHAR(6) NOT NULL, -- e.g., 202508
  response_count INT NOT NULL DEFAULT 0,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, year_month)
);

CREATE OR REPLACE FUNCTION trg_usage_monthly_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp_usage_monthly ON usage_monthly;
CREATE TRIGGER set_timestamp_usage_monthly
BEFORE UPDATE ON usage_monthly
FOR EACH ROW EXECUTE FUNCTION trg_usage_monthly_updated_at();

-- Country payment gateways configuration (for mobile checkout)
CREATE TABLE IF NOT EXISTS country_payment_gateways (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code CHAR(3) NOT NULL,
  provider TEXT NOT NULL, -- e.g., stripe, payhere, midtrans, razorpay
  display_name TEXT NOT NULL,
  public_config JSONB DEFAULT '{}'::jsonb, -- non-sensitive display config
  secret_ref TEXT, -- name/arn of secret in AWS Secrets Manager/SSM
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES admin_users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(country_code, provider)
);

CREATE INDEX IF NOT EXISTS idx_country_payment_gateways_country ON country_payment_gateways(country_code);

CREATE OR REPLACE FUNCTION trg_country_payment_gateways_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp_country_payment_gateways ON country_payment_gateways;
CREATE TRIGGER set_timestamp_country_payment_gateways
BEFORE UPDATE ON country_payment_gateways
FOR EACH ROW EXECUTE FUNCTION trg_country_payment_gateways_updated_at();

-- Optional: transactions log for subscriptions and urgent boosts
CREATE TABLE IF NOT EXISTS subscription_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  country_code CHAR(3) NOT NULL,
  plan_id UUID REFERENCES subscription_plans_new(id),
  subscription_id UUID REFERENCES user_subscriptions(id),
  purpose TEXT NOT NULL, -- subscription|urgent_boost|ppc_click
  amount NUMERIC(12,2) NOT NULL,
  currency CHAR(3) NOT NULL,
  provider TEXT, -- gateway id
  provider_ref TEXT, -- payment intent/session id
  status TEXT NOT NULL DEFAULT 'pending', -- pending|paid|failed|refunded
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscription_tx_user ON subscription_transactions(user_id, created_at DESC);

CREATE OR REPLACE FUNCTION trg_subscription_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_timestamp_subscription_transactions ON subscription_transactions;
CREATE TRIGGER set_timestamp_subscription_transactions
BEFORE UPDATE ON subscription_transactions
FOR EACH ROW EXECUTE FUNCTION trg_subscription_transactions_updated_at();

COMMIT;
