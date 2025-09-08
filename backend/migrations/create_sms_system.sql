-- 📱 SMS API Management System Database Schema

-- SMS Configurations table
CREATE TABLE IF NOT EXISTS sms_configurations (
    id SERIAL PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL UNIQUE, -- ISO country code (LK, IN, US, etc.)
    country_name VARCHAR(100) NOT NULL, -- Human readable name
    active_provider VARCHAR(20) NOT NULL, -- twilio, aws, vonage, local
    is_active BOOLEAN DEFAULT true,
    
    -- Provider configurations (JSON fields)
    twilio_config JSONB, -- {accountSid, authToken, fromNumber}
    aws_config JSONB, -- {accessKeyId, secretAccessKey, region}
    vonage_config JSONB, -- {apiKey, apiSecret, brandName}
    local_config JSONB, -- {endpoint, apiKey, method}
    
    -- Cost tracking
    total_sms_sent INTEGER DEFAULT 0,
    total_cost DECIMAL(10,4) DEFAULT 0,
    cost_per_sms DECIMAL(6,4) DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(255)
);

-- Enhanced OTP verifications table
DROP TABLE IF EXISTS phone_otp_verifications;
CREATE TABLE phone_otp_verifications (
    id SERIAL PRIMARY KEY,
    otp_id VARCHAR(50) UNIQUE NOT NULL, -- Unique OTP identifier
    phone VARCHAR(20) NOT NULL,
    otp VARCHAR(6) NOT NULL,
    country_code VARCHAR(2) NOT NULL,
    provider_used VARCHAR(20), -- Which provider was used
    
    -- Status tracking
    verified BOOLEAN DEFAULT FALSE,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    verified_at TIMESTAMPTZ,
    
    -- Indexes for performance
    INDEX idx_phone_otp_active (phone, verified, expires_at),
    INDEX idx_otp_id (otp_id),
    INDEX idx_phone_created (phone, created_at)
);

-- SMS Analytics table
CREATE TABLE IF NOT EXISTS sms_analytics (
    id SERIAL PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL,
    provider VARCHAR(20) NOT NULL,
    cost DECIMAL(6,4) DEFAULT 0,
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    
    -- Time tracking
    month INTEGER NOT NULL, -- 1-12
    year INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_analytics_country_month (country_code, year, month),
    INDEX idx_analytics_provider (provider, created_at)
);

-- User phone numbers table (for multiple phone support)
CREATE TABLE IF NOT EXISTS user_phone_numbers (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    country_code VARCHAR(2),
    
    -- Verification status
    is_verified BOOLEAN DEFAULT FALSE,
    is_primary BOOLEAN DEFAULT FALSE, -- One primary phone per user
    verified_at TIMESTAMPTZ,
    
    -- Purpose/Label
    label VARCHAR(50), -- 'personal', 'business', 'emergency', etc.
    purpose VARCHAR(100), -- 'login', 'driver_verification', 'business_profile', etc.
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(user_id, phone_number),
    INDEX idx_user_phones (user_id),
    INDEX idx_phone_lookup (phone_number),
    INDEX idx_primary_phone (user_id, is_primary)
);

-- Update users table to support multiple phones
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS primary_phone_id INTEGER REFERENCES user_phone_numbers(id),
ADD COLUMN IF NOT EXISTS phone_verification_enabled BOOLEAN DEFAULT TRUE;

-- Default SMS configurations for supported countries
INSERT INTO sms_configurations (country_code, country_name, active_provider, twilio_config, is_active) 
VALUES 
(
    'LK', 
    'Sri Lanka', 
    'twilio',
    '{"accountSid": "", "authToken": "", "fromNumber": "+94700000000"}',
    false
),
(
    'IN', 
    'India', 
    'twilio',
    '{"accountSid": "", "authToken": "", "fromNumber": "+911234567890"}',
    false
),
(
    'US', 
    'United States', 
    'twilio',
    '{"accountSid": "", "authToken": "", "fromNumber": "+1234567890"}',
    false
),
(
    'UK', 
    'United Kingdom', 
    'twilio',
    '{"accountSid": "", "authToken": "", "fromNumber": "+441234567890"}',
    false
),
(
    'AE', 
    'United Arab Emirates', 
    'twilio',
    '{"accountSid": "", "authToken": "", "fromNumber": "+971501234567"}',
    false
) ON CONFLICT (country_code) DO NOTHING;

-- Function to ensure only one primary phone per user
CREATE OR REPLACE FUNCTION ensure_single_primary_phone()
RETURNS TRIGGER AS $$
BEGIN
    -- If setting a phone as primary, unset all other primary phones for this user
    IF NEW.is_primary = TRUE THEN
        UPDATE user_phone_numbers 
        SET is_primary = FALSE 
        WHERE user_id = NEW.user_id AND id != NEW.id;
        
        -- Update user's primary_phone_id
        UPDATE users 
        SET primary_phone_id = NEW.id 
        WHERE id = NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for primary phone management
DROP TRIGGER IF EXISTS trigger_ensure_single_primary_phone ON user_phone_numbers;
CREATE TRIGGER trigger_ensure_single_primary_phone
    BEFORE INSERT OR UPDATE ON user_phone_numbers
    FOR EACH ROW
    EXECUTE FUNCTION ensure_single_primary_phone();

-- Function to migrate existing phone data
CREATE OR REPLACE FUNCTION migrate_existing_phone_data()
RETURNS INTEGER AS $$
DECLARE
    user_record RECORD;
    phone_id INTEGER;
    migrated_count INTEGER := 0;
BEGIN
    -- Migrate existing phone numbers from users table to user_phone_numbers table
    FOR user_record IN 
        SELECT id, phone, phone_verified 
        FROM users 
        WHERE phone IS NOT NULL AND phone != ''
    LOOP
        -- Insert into user_phone_numbers
        INSERT INTO user_phone_numbers 
        (user_id, phone_number, is_verified, is_primary, label, purpose, verified_at)
        VALUES 
        (
            user_record.id, 
            user_record.phone, 
            user_record.phone_verified,
            TRUE, -- Make existing phone primary
            'personal',
            'login',
            CASE WHEN user_record.phone_verified THEN NOW() ELSE NULL END
        )
        RETURNING id INTO phone_id;
        
        -- Update users table with primary phone reference
        UPDATE users 
        SET primary_phone_id = phone_id 
        WHERE id = user_record.id;
        
        migrated_count := migrated_count + 1;
    END LOOP;
    
    RETURN migrated_count;
END;
$$ LANGUAGE plpgsql;

-- Execute migration (commented out for safety)
-- SELECT migrate_existing_phone_data();

-- Views for easy querying
CREATE OR REPLACE VIEW user_phone_summary AS
SELECT 
    u.id as user_id,
    u.email,
    u.display_name,
    up.phone_number as primary_phone,
    up.is_verified as primary_phone_verified,
    up.verified_at as primary_phone_verified_at,
    COUNT(up_all.id) as total_phone_numbers,
    COUNT(CASE WHEN up_all.is_verified THEN 1 END) as verified_phone_numbers
FROM users u
LEFT JOIN user_phone_numbers up ON u.primary_phone_id = up.id
LEFT JOIN user_phone_numbers up_all ON u.id = up_all.user_id
GROUP BY u.id, u.email, u.display_name, up.phone_number, up.is_verified, up.verified_at;

-- View for SMS analytics
CREATE OR REPLACE VIEW monthly_sms_stats AS
SELECT 
    sc.country_code,
    sc.country_name,
    sc.active_provider,
    sa.month,
    sa.year,
    COUNT(*) as total_sms,
    SUM(sa.cost) as total_cost,
    AVG(sa.cost) as avg_cost_per_sms,
    SUM(CASE WHEN sa.success THEN 1 ELSE 0 END) as successful_sms,
    ROUND(
        (SUM(CASE WHEN sa.success THEN 1 ELSE 0 END)::DECIMAL / COUNT(*)) * 100, 
        2
    ) as success_rate
FROM sms_configurations sc
LEFT JOIN sms_analytics sa ON sc.country_code = sa.country_code
WHERE sa.month IS NOT NULL
GROUP BY sc.country_code, sc.country_name, sc.active_provider, sa.month, sa.year
ORDER BY sa.year DESC, sa.month DESC, sc.country_code;
