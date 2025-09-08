-- Create unified email verification system similar to phone system

-- 1. Create user_email_addresses table for professional emails
CREATE TABLE IF NOT EXISTS user_email_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email_address VARCHAR(255) NOT NULL,
  is_verified BOOLEAN DEFAULT false,
  is_primary BOOLEAN DEFAULT false,
  purpose VARCHAR(100), -- business_verification, driver_verification, profile_update, etc.
  email_type VARCHAR(50) DEFAULT 'professional', -- personal, professional, business, support, etc.
  verified_at TIMESTAMP,
  verification_method VARCHAR(50), -- otp, aws_ses, manual, admin
  verification_token VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, email_address)
);

-- 2. Create email_otp_verifications table for AWS SES OTP tracking
CREATE TABLE IF NOT EXISTS email_otp_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL,
  otp VARCHAR(10) NOT NULL,
  otp_id VARCHAR(100) UNIQUE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  verification_type VARCHAR(50), -- login, business_verification, driver_verification, profile_update
  provider_used VARCHAR(50) DEFAULT 'aws_ses', -- aws_ses, smtp, sendgrid, etc.
  verified BOOLEAN DEFAULT false,
  expires_at TIMESTAMP NOT NULL,
  verified_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create indexes
CREATE INDEX IF NOT EXISTS idx_user_email_verified ON user_email_addresses (user_id, is_verified);
CREATE INDEX IF NOT EXISTS idx_email_verified ON user_email_addresses (email_address, is_verified);
CREATE INDEX IF NOT EXISTS idx_email_otp ON email_otp_verifications (email, otp);
CREATE INDEX IF NOT EXISTS idx_otp_id ON email_otp_verifications (otp_id);
CREATE INDEX IF NOT EXISTS idx_email_verified_otp ON email_otp_verifications (email, verified);

-- 4. Add email verification tracking columns to verification tables
ALTER TABLE business_verifications 
ADD COLUMN IF NOT EXISTS email_verification_source VARCHAR(50),
ADD COLUMN IF NOT EXISTS email_verification_method VARCHAR(50);

ALTER TABLE driver_verifications 
ADD COLUMN IF NOT EXISTS email_verification_source VARCHAR(50),
ADD COLUMN IF NOT EXISTS email_verification_method VARCHAR(50);

-- 5. Insert existing user emails into the new table
INSERT INTO user_email_addresses (user_id, email_address, is_verified, is_primary, purpose, email_type, verified_at, verification_method)
SELECT 
  id as user_id,
  email as email_address,
  email_verified as is_verified,
  true as is_primary,
  'registration' as purpose,
  'personal' as email_type,
  CASE WHEN email_verified THEN created_at ELSE NULL END as verified_at,
  CASE WHEN email_verified THEN 'registration' ELSE NULL END as verification_method
FROM users 
WHERE email IS NOT NULL AND email != ''
ON CONFLICT (user_id, email_address) DO NOTHING;
