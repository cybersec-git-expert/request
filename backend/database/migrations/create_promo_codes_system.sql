-- Promo Codes System Migration
-- Creates tables for managing promotional codes that grant temporary subscription benefits

-- Main promo codes table
CREATE TABLE IF NOT EXISTS promo_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Promo code configuration
    benefit_type VARCHAR(50) NOT NULL DEFAULT 'free_plan', -- 'free_plan', 'discount', 'extension'
    benefit_duration_days INTEGER DEFAULT 30, -- How many days of benefit
    benefit_plan_code VARCHAR(50) DEFAULT 'pro', -- Which plan to grant (for free_plan type)
    discount_percentage DECIMAL(5,2), -- For discount type promos
    
    -- Usage limits
    max_uses INTEGER, -- NULL = unlimited uses
    max_uses_per_user INTEGER DEFAULT 1, -- How many times one user can use this code
    current_uses INTEGER DEFAULT 0,
    
    -- Validity period
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_by UUID, -- Admin user who created this
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_benefit_type CHECK (benefit_type IN ('free_plan', 'discount', 'extension')),
    CONSTRAINT valid_discount CHECK (discount_percentage IS NULL OR (discount_percentage >= 0 AND discount_percentage <= 100)),
    CONSTRAINT valid_duration CHECK (benefit_duration_days > 0),
    CONSTRAINT valid_dates CHECK (valid_until IS NULL OR valid_until > valid_from)
);

-- Promo code redemptions tracking
CREATE TABLE IF NOT EXISTS promo_code_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promo_code_id UUID NOT NULL REFERENCES promo_codes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    
    -- Redemption details
    redeemed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    benefit_start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    benefit_end_date TIMESTAMP NOT NULL,
    
    -- What was granted
    granted_plan_code VARCHAR(50),
    original_plan_code VARCHAR(50), -- To restore after promo expires
    
    -- Status
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'expired', 'cancelled'
    
    -- Metadata
    ip_address INET,
    user_agent TEXT,
    
    UNIQUE(promo_code_id, user_id), -- One redemption per user per promo code
    CONSTRAINT valid_redemption_status CHECK (status IN ('active', 'expired', 'cancelled'))
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON promo_codes(code);
CREATE INDEX IF NOT EXISTS idx_promo_codes_active ON promo_codes(is_active, valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_promo_codes_created_by ON promo_codes(created_by);

CREATE INDEX IF NOT EXISTS idx_promo_redemptions_user ON promo_code_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_promo ON promo_code_redemptions(promo_code_id);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_status ON promo_code_redemptions(status);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_dates ON promo_code_redemptions(benefit_start_date, benefit_end_date);

-- Function to check if user can use a promo code
CREATE OR REPLACE FUNCTION can_user_use_promo_code(
    p_promo_code_id UUID,
    p_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    promo_record promo_codes%ROWTYPE;
    user_usage_count INTEGER;
BEGIN
    -- Get promo code details
    SELECT * INTO promo_record FROM promo_codes WHERE id = p_promo_code_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Check if promo is active
    IF NOT promo_record.is_active THEN
        RETURN FALSE;
    END IF;
    
    -- Check validity dates
    IF promo_record.valid_from > CURRENT_TIMESTAMP THEN
        RETURN FALSE;
    END IF;
    
    IF promo_record.valid_until IS NOT NULL AND promo_record.valid_until < CURRENT_TIMESTAMP THEN
        RETURN FALSE;
    END IF;
    
    -- Check global usage limit
    IF promo_record.max_uses IS NOT NULL AND promo_record.current_uses >= promo_record.max_uses THEN
        RETURN FALSE;
    END IF;
    
    -- Check per-user usage limit
    SELECT COUNT(*) INTO user_usage_count 
    FROM promo_code_redemptions 
    WHERE promo_code_id = p_promo_code_id AND user_id = p_user_id;
    
    IF promo_record.max_uses_per_user IS NOT NULL AND user_usage_count >= promo_record.max_uses_per_user THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to redeem a promo code
CREATE OR REPLACE FUNCTION redeem_promo_code(
    p_code VARCHAR(50),
    p_user_id UUID,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    promo_record promo_codes%ROWTYPE;
    redemption_id UUID;
    benefit_end TIMESTAMP;
    current_subscription RECORD;
    result JSON;
BEGIN
    -- Get promo code
    SELECT * INTO promo_record FROM promo_codes WHERE code = p_code;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Invalid promo code');
    END IF;
    
    -- Check if user can use this code
    IF NOT can_user_use_promo_code(promo_record.id, p_user_id) THEN
        RETURN json_build_object('success', false, 'error', 'Promo code cannot be used');
    END IF;
    
    -- Calculate benefit end date
    benefit_end := CURRENT_TIMESTAMP + INTERVAL '1 day' * promo_record.benefit_duration_days;
    
    -- Get user's current subscription
    SELECT plan_code INTO current_subscription 
    FROM user_simple_subscriptions 
    WHERE user_id = p_user_id 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    -- Create redemption record
    INSERT INTO promo_code_redemptions (
        promo_code_id,
        user_id,
        benefit_end_date,
        granted_plan_code,
        original_plan_code,
        ip_address,
        user_agent
    ) VALUES (
        promo_record.id,
        p_user_id,
        benefit_end,
        promo_record.benefit_plan_code,
        COALESCE(current_subscription.plan_code, 'Free'),
        p_ip_address,
        p_user_agent
    ) RETURNING id INTO redemption_id;
    
    -- Update user's subscription to the promo plan
    INSERT INTO user_simple_subscriptions (
        user_id,
        plan_code,
        status,
        subscription_start_date,
        subscription_end_date,
        payment_id,
        payment_status,
        plan_name
    ) VALUES (
        p_user_id,
        promo_record.benefit_plan_code,
        'active',
        CURRENT_TIMESTAMP,
        benefit_end,
        'promo_' || promo_record.code,
        'completed',
        promo_record.benefit_plan_code || ' Plan (Promo)'
    );
    
    -- Update promo code usage count
    UPDATE promo_codes 
    SET current_uses = current_uses + 1 
    WHERE id = promo_record.id;
    
    -- Return success result
    result := json_build_object(
        'success', true,
        'redemption_id', redemption_id,
        'benefit_plan', promo_record.benefit_plan_code,
        'benefit_end_date', benefit_end,
        'message', 'Promo code applied successfully! You now have ' || promo_record.benefit_plan_code || ' access until ' || benefit_end::date
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'error', 'Failed to redeem promo code: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- Insert some sample promo codes for testing
INSERT INTO promo_codes (code, name, description, benefit_type, benefit_duration_days, benefit_plan_code, max_uses_per_user) VALUES
('WELCOME30', 'Welcome Free Month', 'Get 1 month of Pro access for new users', 'free_plan', 30, 'pro', 1),
('LAUNCH50', 'Launch Special', 'Limited time 1 month Pro access', 'free_plan', 30, 'pro', 1),
('TESTCODE', 'Test Promo', 'Testing promo code system', 'free_plan', 7, 'pro', 2)
ON CONFLICT (code) DO NOTHING;

-- Comments for documentation
COMMENT ON TABLE promo_codes IS 'Promotional codes that grant temporary subscription benefits';
COMMENT ON TABLE promo_code_redemptions IS 'Tracking table for promo code usage and redemptions';
COMMENT ON FUNCTION can_user_use_promo_code IS 'Checks if a user is eligible to use a specific promo code';
COMMENT ON FUNCTION redeem_promo_code IS 'Redeems a promo code for a user and grants the specified benefits';