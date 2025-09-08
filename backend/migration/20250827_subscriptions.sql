-- Safe to run multiple times (use IF NOT EXISTS)

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- for gen_random_uuid()

-- Compatibility view to align with existing subscription_plans_new
-- Maps:
--  type -> audience ('rider' => 'normal', 'business' => 'business')
--  plan_type -> model ('monthly'|'pay_per_click' -> 'monthly'|'ppc')
--  price (decimal) -> price_cents (integer) best-effort conversion
CREATE OR REPLACE VIEW subscription_plans AS
SELECT
  spn.id,
  spn.name,
  CASE spn.type
    WHEN 'rider' THEN 'normal'
    WHEN 'business' THEN 'business'
    ELSE 'normal'
  END AS audience,
  CASE spn.plan_type
    WHEN 'pay_per_click' THEN 'ppc'
    ELSE spn.plan_type
  END AS model,
  CASE WHEN spn.price IS NOT NULL THEN (spn.price * 100)::int ELSE NULL END AS price_cents,
  spn.currency,
  spn.is_active,
  spn.created_at
FROM subscription_plans_new spn
WHERE spn.is_active = true;

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  -- FK must reference a real table, not a view
  plan_id UUID REFERENCES subscription_plans_new(id),
  status TEXT NOT NULL CHECK (status IN ('active','canceled','expired','trialing')),
  start_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT false,
  provider TEXT NOT NULL DEFAULT 'internal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_active ON subscriptions(user_id, status);

-- Monthly usage counts for normal users (responses per month)
CREATE TABLE IF NOT EXISTS usage_monthly (
  user_id UUID NOT NULL,
  year_month CHAR(6) NOT NULL,
  response_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, year_month)
);

-- Business price comparison mode
CREATE TABLE IF NOT EXISTS price_comparison_business (
  business_id UUID PRIMARY KEY,
  mode TEXT NOT NULL CHECK (mode IN ('ppc','monthly')),
  -- FK must reference a real table, not a view
  monthly_plan_id UUID REFERENCES subscription_plans_new(id),
  ppc_price_cents INTEGER,
  currency TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Per-click charges
CREATE TABLE IF NOT EXISTS ppc_clicks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  request_id UUID NOT NULL,
  click_type TEXT NOT NULL CHECK (click_type IN ('view_contact','message','call')),
  cost_cents INTEGER NOT NULL,
  currency TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ppc_clicks_business ON ppc_clicks(business_id);
CREATE INDEX IF NOT EXISTS idx_ppc_clicks_request ON ppc_clicks(request_id);
