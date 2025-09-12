-- Simple Subscription Admin System Database Schema
-- This creates the comprehensive subscription management system

-- Create simple subscription plans table (super admin managed)
CREATE TABLE IF NOT EXISTS simple_subscription_plans (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    response_limit INTEGER NOT NULL DEFAULT 3, -- -1 for unlimited
    features JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create country-specific pricing table (country admin managed, super admin approved)
CREATE TABLE IF NOT EXISTS simple_subscription_country_pricing (
    id SERIAL PRIMARY KEY,
    plan_code VARCHAR(50) NOT NULL REFERENCES simple_subscription_plans(code) ON DELETE CASCADE,
    country_code VARCHAR(2) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    is_active BOOLEAN DEFAULT false, -- false = pending approval
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(plan_code, country_code)
);

-- Create user subscriptions table (if not exists)
CREATE TABLE IF NOT EXISTS user_simple_subscriptions (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_code VARCHAR(50) NOT NULL REFERENCES simple_subscription_plans(code),
    responses_used_this_month INTEGER DEFAULT 0,
    month_reset_date DATE DEFAULT CURRENT_DATE,
    is_verified_business BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Insert default subscription plans
INSERT INTO simple_subscription_plans (code, name, description, price, currency, response_limit, features) VALUES
    ('free', 'Free Plan', 'Perfect for small businesses starting out', 0, 'USD', 3, '["Basic response tracking", "Mobile app access", "Email support"]'::jsonb),
    ('pro', 'Professional Plan', 'Unlimited responses for growing businesses', 29.99, 'USD', -1, '["Unlimited responses", "Priority support", "Advanced analytics", "Custom branding"]'::jsonb),
    ('enterprise', 'Enterprise Plan', 'Premium features for large organizations', 99.99, 'USD', -1, '["Everything in Pro", "Dedicated account manager", "API access", "Custom integrations", "White-label options"]'::jsonb)
ON CONFLICT (code) DO NOTHING;

-- Insert default country pricing for Sri Lanka
INSERT INTO simple_subscription_country_pricing (plan_code, country_code, price, currency, is_active) VALUES
    ('free', 'LK', 0, 'LKR', true),
    ('pro', 'LK', 2999, 'LKR', true),
    ('enterprise', 'LK', 9999, 'LKR', true)
ON CONFLICT (plan_code, country_code) DO NOTHING;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_simple_subscription_plans_active ON simple_subscription_plans(is_active);
CREATE INDEX IF NOT EXISTS idx_simple_subscription_plans_price ON simple_subscription_plans(price);
CREATE INDEX IF NOT EXISTS idx_country_pricing_active ON simple_subscription_country_pricing(is_active);
CREATE INDEX IF NOT EXISTS idx_country_pricing_country ON simple_subscription_country_pricing(country_code);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_plan ON user_simple_subscriptions(plan_code);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user ON user_simple_subscriptions(user_id);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_simple_subscription_plans_updated_at 
    BEFORE UPDATE ON simple_subscription_plans 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_country_pricing_updated_at 
    BEFORE UPDATE ON simple_subscription_country_pricing 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_subscriptions_updated_at 
    BEFORE UPDATE ON user_simple_subscriptions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add country tracking to users table if not exists (for analytics)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'country_code') THEN
        ALTER TABLE users ADD COLUMN country_code VARCHAR(2);
        CREATE INDEX idx_users_country ON users(country_code);
    END IF;
END $$;
