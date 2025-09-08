BEGIN;

-- Drop old confusing tables
DROP TABLE IF EXISTS subscription_plans_new CASCADE;
DROP TABLE IF EXISTS subscription_country_pricing CASCADE;

-- 1. PRODUCT MARKETPLACE PRICING (for businesses selling products)
CREATE TABLE IF NOT EXISTS product_seller_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL, -- 'ppc_basic', 'monthly_premium'
  name TEXT NOT NULL, -- 'Pay Per Click', 'Monthly Premium'
  billing_type TEXT NOT NULL CHECK (billing_type IN ('per_click', 'monthly')), 
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Country-specific pricing for product seller plans
CREATE TABLE IF NOT EXISTS product_seller_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES product_seller_plans(id) ON DELETE CASCADE,
  country_code CHAR(3) NOT NULL,
  price_per_click NUMERIC(10,4), -- Price per click (for PPC plans)
  monthly_fee NUMERIC(12,2), -- Monthly fee (for monthly plans)
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  is_active BOOLEAN NOT NULL DEFAULT false, -- Requires super admin approval
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(plan_id, country_code)
);

-- Business subscriptions to product seller plans
CREATE TABLE IF NOT EXISTS business_seller_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL, -- References businesses table
  plan_id UUID NOT NULL REFERENCES product_seller_plans(id),
  country_code CHAR(3) NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'cancelled')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ends_at TIMESTAMPTZ, -- For monthly plans
  auto_renew BOOLEAN NOT NULL DEFAULT true,
  total_clicks INT NOT NULL DEFAULT 0, -- Track clicks for PPC
  monthly_fee_paid NUMERIC(12,2) DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. USER RESPONSE PRICING (for users getting responses to requests)
CREATE TABLE IF NOT EXISTS user_response_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL, -- 'free', 'ride_unlimited', 'other_unlimited'
  name TEXT NOT NULL, -- 'Free Plan', 'Unlimited Ride Responses', 'Unlimited Other Responses'
  response_type TEXT NOT NULL CHECK (response_type IN ('free', 'ride', 'other', 'all')),
  response_limit INT, -- NULL = unlimited, number = limit per month
  description TEXT,
  features JSONB DEFAULT '[]'::jsonb, -- ['contact_details', 'notifications', 'urgent_boost']
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Country-specific pricing for user response plans
CREATE TABLE IF NOT EXISTS user_response_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES user_response_plans(id) ON DELETE CASCADE,
  country_code CHAR(3) NOT NULL,
  monthly_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  is_active BOOLEAN NOT NULL DEFAULT false, -- Requires super admin approval
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(plan_id, country_code)
);

-- User subscriptions to response plans
CREATE TABLE IF NOT EXISTS user_response_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES user_response_plans(id),
  country_code CHAR(3) NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'trialing', 'past_due', 'cancelled', 'expired')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ends_at TIMESTAMPTZ,
  next_renewal_at TIMESTAMPTZ,
  auto_renew BOOLEAN NOT NULL DEFAULT true,
  monthly_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Track monthly response usage for users
CREATE TABLE IF NOT EXISTS user_response_usage (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  year_month CHAR(6) NOT NULL, -- '202508'
  ride_responses INT NOT NULL DEFAULT 0,
  other_responses INT NOT NULL DEFAULT 0,
  total_responses INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, year_month)
);

-- Insert default plans
INSERT INTO product_seller_plans (code, name, billing_type, description) VALUES
('ppc_basic', 'Pay Per Click', 'per_click', 'Pay only when customers click on your products'),
('monthly_premium', 'Monthly Premium', 'monthly', 'Fixed monthly fee for unlimited product listings');

INSERT INTO user_response_plans (code, name, response_type, response_limit, description, features) VALUES
('free', 'Free Plan', 'free', 3, 'Limited to 3 responses per month', '["basic_search"]'),
('ride_unlimited', 'Unlimited Ride Responses', 'ride', NULL, 'Unlimited responses for ride requests', '["contact_details", "notifications", "urgent_boost"]'),
('other_unlimited', 'Unlimited Other Responses', 'other', NULL, 'Unlimited responses for non-ride requests', '["contact_details", "notifications", "urgent_boost"]'),
('all_unlimited', 'Unlimited All Responses', 'all', NULL, 'Unlimited responses for all request types', '["contact_details", "notifications", "urgent_boost", "priority_support"]');

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_product_seller_pricing_country ON product_seller_pricing(country_code, is_active);
CREATE INDEX IF NOT EXISTS idx_user_response_pricing_country ON user_response_pricing(country_code, is_active);
CREATE INDEX IF NOT EXISTS idx_business_seller_subscriptions_business ON business_seller_subscriptions(business_id, status);
CREATE INDEX IF NOT EXISTS idx_user_response_subscriptions_user ON user_response_subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_user_response_usage_month ON user_response_usage(year_month);

COMMIT;
