-- Add response_limit column to simple_subscription_country_pricing table
-- This allows country admins to set different response limits per country

-- Add the response_limit column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'simple_subscription_country_pricing' 
        AND column_name = 'response_limit'
    ) THEN
        ALTER TABLE simple_subscription_country_pricing 
        ADD COLUMN response_limit INTEGER DEFAULT 3;
        
        -- Update existing records to match their plan's response limit
        UPDATE simple_subscription_country_pricing 
        SET response_limit = (
            SELECT ssp.response_limit 
            FROM simple_subscription_plans ssp 
            WHERE ssp.code = simple_subscription_country_pricing.plan_code
        );
        
        -- Add index for performance
        CREATE INDEX IF NOT EXISTS idx_country_pricing_response_limit 
        ON simple_subscription_country_pricing(response_limit);
        
        -- Add constraint to ensure response_limit is valid
        ALTER TABLE simple_subscription_country_pricing 
        ADD CONSTRAINT chk_response_limit CHECK (response_limit >= -1);
        
        RAISE NOTICE 'Added response_limit column to simple_subscription_country_pricing';
    ELSE
        RAISE NOTICE 'response_limit column already exists in simple_subscription_country_pricing';
    END IF;
END $$;
