-- Add missing verification timestamp columns to business and driver verification tables

-- Add columns to business_verifications table
ALTER TABLE business_verifications ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMP;
ALTER TABLE business_verifications ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP;

-- Add columns to driver_verifications table  
ALTER TABLE driver_verifications ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMP;
ALTER TABLE driver_verifications ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP;

-- Check the columns were added successfully
SELECT 'business_verifications columns:' as table_info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'business_verifications' 
  AND column_name LIKE '%verified%'
ORDER BY column_name;

SELECT 'driver_verifications columns:' as table_info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'driver_verifications' 
  AND column_name LIKE '%verified%'
ORDER BY column_name;
