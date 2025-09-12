-- Enhance subscription tracking with payment lifecycle
-- Add columns to track subscription lifecycle and payments

ALTER TABLE user_simple_subscriptions 
ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMP,
ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMP,
ADD COLUMN IF NOT EXISTS payment_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50) DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS grace_period_end TIMESTAMP,
ADD COLUMN IF NOT EXISTS last_payment_attempt TIMESTAMP,
ADD COLUMN IF NOT EXISTS payment_failure_count INTEGER DEFAULT 0;

-- Update existing records to have proper dates for free plans
UPDATE user_simple_subscriptions 
SET 
    subscription_start_date = created_at,
    subscription_end_date = created_at + INTERVAL '30 days',
    payment_status = 'completed'
WHERE plan_code = 'Free' AND subscription_start_date IS NULL;

-- Create index for efficient subscription expiry checks
CREATE INDEX IF NOT EXISTS idx_subscription_end_date ON user_simple_subscriptions(subscription_end_date);
CREATE INDEX IF NOT EXISTS idx_payment_status ON user_simple_subscriptions(payment_status);

-- Create a function to check if subscription is active
CREATE OR REPLACE FUNCTION is_subscription_active(
    p_subscription_end_date TIMESTAMP,
    p_grace_period_end TIMESTAMP,
    p_payment_status VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    -- Free plan is always active if status is completed
    IF p_payment_status = 'completed' AND p_subscription_end_date > CURRENT_TIMESTAMP THEN
        RETURN TRUE;
    END IF;
    
    -- Paid plan with grace period
    IF p_grace_period_end IS NOT NULL AND p_grace_period_end > CURRENT_TIMESTAMP THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;
