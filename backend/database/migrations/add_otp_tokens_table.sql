-- Create OTP tokens table for handling registration verification
CREATE TABLE IF NOT EXISTS otp_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_or_phone VARCHAR(255) NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    purpose VARCHAR(50) DEFAULT 'registration',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    attempts INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_otp_tokens_email_token ON otp_tokens(email_or_phone, token_hash);
CREATE INDEX IF NOT EXISTS idx_otp_tokens_expires ON otp_tokens(expires_at) WHERE used = FALSE;

-- Auto-update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_otp_tokens_updated_at BEFORE UPDATE ON otp_tokens
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
