-- Add status column to user_simple_subscriptions table
ALTER TABLE user_simple_subscriptions 
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'active';

-- Update existing records to have active status
UPDATE user_simple_subscriptions 
SET status = 'active' 
WHERE status IS NULL;
