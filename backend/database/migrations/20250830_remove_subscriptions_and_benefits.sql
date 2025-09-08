-- Danger: This migration drops all subscription and business-benefits related objects.
-- Run only if you are sure. Create backups first.

BEGIN;

-- Drop new subscription redesign objects
DROP TABLE IF EXISTS product_seller_plan_pricing CASCADE;
DROP TABLE IF EXISTS product_seller_plans CASCADE;
DROP TABLE IF EXISTS business_seller_subscriptions CASCADE;

DROP TABLE IF EXISTS user_response_plan_pricing CASCADE;
DROP TABLE IF EXISTS user_response_plans CASCADE;
DROP TABLE IF EXISTS user_response_subscriptions CASCADE;

-- Drop legacy subscription tables
DROP TABLE IF EXISTS subscription_country_pricing CASCADE;
DROP TABLE IF EXISTS subscription_transactions CASCADE;
DROP TABLE IF EXISTS user_subscriptions CASCADE;
DROP TABLE IF EXISTS subscription_plans_new CASCADE;

-- Drop business-type benefits tables
DROP TABLE IF EXISTS business_type_benefit_configs CASCADE;
DROP TABLE IF EXISTS business_type_benefit_plans CASCADE;
DROP FUNCTION IF EXISTS get_business_type_benefits(integer);
DROP FUNCTION IF EXISTS update_business_type_benefits(integer, integer, text, integer, numeric, numeric, text, jsonb, boolean, integer);
DROP TABLE IF EXISTS business_type_benefits CASCADE;

-- Drop enhanced benefits table(s)
DROP TABLE IF EXISTS enhanced_business_benefits CASCADE;

COMMIT;
