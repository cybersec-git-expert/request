-- Simple subscription system for simplified app
-- Remove ride functionality and implement 3 responses/month free limit

-- Create simple subscription plans table
CREATE TABLE IF NOT EXISTS simple_subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    response_limit INTEGER DEFAULT 3, -- 3 for free, unlimited for paid
    features JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default plans
INSERT INTO simple_subscription_plans (code, name, description, price, currency, response_limit, features) VALUES
('free', 'Free Plan', 'Free plan with 3 responses per month', 0, 'USD', 3, '["Browse all requests", "Respond to 3 requests per month", "Basic profile"]'),
('premium', 'Premium Plan', 'Unlimited responses and premium features', 9.99, 'USD', -1, '["Browse all requests", "Unlimited responses per month", "Priority support", "Verified business badge", "Advanced analytics"]')
ON CONFLICT (code) DO NOTHING;

-- Simple user subscriptions table
CREATE TABLE IF NOT EXISTS user_simple_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    plan_code VARCHAR(50) NOT NULL DEFAULT 'free',
    responses_used_this_month INTEGER DEFAULT 0,
    month_reset_date DATE DEFAULT CURRENT_DATE,
    is_verified_business BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_code) REFERENCES simple_subscription_plans(code)
);

-- Create unique index for user subscriptions
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_simple_subscriptions_user_id ON user_simple_subscriptions(user_id);

-- Function to reset monthly usage
CREATE OR REPLACE FUNCTION reset_monthly_usage()
RETURNS void AS $$
BEGIN
    UPDATE user_simple_subscriptions 
    SET responses_used_this_month = 0,
        month_reset_date = CURRENT_DATE,
        updated_at = CURRENT_TIMESTAMP
    WHERE month_reset_date < DATE_TRUNC('month', CURRENT_DATE);
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to auto-create subscription for new users
CREATE OR REPLACE FUNCTION create_default_subscription()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_simple_subscriptions (user_id, plan_code)
    VALUES (NEW.id, 'free')
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create subscription when user is created
DROP TRIGGER IF EXISTS trigger_create_default_subscription ON users;
CREATE TRIGGER trigger_create_default_subscription
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_default_subscription();
