-- Allow NULL values for pricing fields in plan templates
-- Super admin creates templates, country admin sets pricing

-- Allow NULL for price, currency, and response_limit in plan templates
ALTER TABLE simple_subscription_plans 
ALTER COLUMN price DROP NOT NULL,
ALTER COLUMN currency DROP NOT NULL,
ALTER COLUMN response_limit DROP NOT NULL;

-- Update existing plans to have NULL pricing (they will use country pricing)
UPDATE simple_subscription_plans 
SET price = NULL, currency = NULL, response_limit = NULL 
WHERE id IN (1, 2, 3, 5); -- Update the template plans

-- Note: Actual pricing will come from simple_subscription_country_pricing table
