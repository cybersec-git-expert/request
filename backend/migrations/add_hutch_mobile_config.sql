-- Add Hutch Mobile configuration column to SMS configurations table
-- This allows storing Hutch Mobile specific settings

ALTER TABLE sms_configurations 
ADD COLUMN IF NOT EXISTS hutch_mobile_config JSONB;

-- Add comment for documentation
COMMENT ON COLUMN sms_configurations.hutch_mobile_config IS 'Hutch Mobile SMS provider configuration: {apiUrl, username, password, senderId, messageType}';

-- Update the constraint to include hutch_mobile as a valid provider
-- First, let's check if there's an existing constraint
DO $$
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'valid_provider_check' 
        AND table_name = 'sms_configurations'
    ) THEN
        ALTER TABLE sms_configurations DROP CONSTRAINT valid_provider_check;
    END IF;
    
    -- Add updated constraint with hutch_mobile
    ALTER TABLE sms_configurations 
    ADD CONSTRAINT valid_provider_check 
    CHECK (active_provider IN ('twilio', 'aws', 'vonage', 'local', 'hutch_mobile'));
END
$$;

-- Add example configuration for documentation
/*
Example Hutch Mobile configuration:
{
  "apiUrl": "https://bsms.hutch.lk/api/send",
  "username": "your_username",
  "password": "your_password", 
  "senderId": "HUTCH",
  "messageType": "text"
}
*/
