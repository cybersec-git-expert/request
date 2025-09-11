-- Database Cleanup Script: Remove Ride/Driver Related Tables
-- Run this script to clean up your database after removing ride functionality
-- BACKUP YOUR DATABASE BEFORE RUNNING THIS SCRIPT!

-- Drop ride/driver related tables (in correct order to handle foreign keys)
DROP TABLE IF EXISTS driver_document_audit CASCADE;
DROP TABLE IF EXISTS driver_verifications CASCADE;
DROP TABLE IF EXISTS country_vehicles CASCADE;
DROP TABLE IF EXISTS country_vehicle_types CASCADE;
DROP TABLE IF EXISTS vehicle_types CASCADE;

-- Clean up any related indexes that might remain
-- (PostgreSQL will automatically drop most indexes when tables are dropped)

-- Clean up ride-related data in remaining tables
-- Remove ride-related categories
DELETE FROM categories WHERE LOWER(name) LIKE '%ride%' 
    OR LOWER(name) LIKE '%driver%' 
    OR LOWER(name) LIKE '%vehicle%'
    OR LOWER(name) LIKE '%transport%';

-- Remove ride-related business types
DELETE FROM business_types WHERE LOWER(name) LIKE '%ride%' 
    OR LOWER(name) LIKE '%driver%' 
    OR LOWER(name) LIKE '%transport%'
    OR LOWER(name) LIKE '%vehicle%';

-- Remove ride-related products
DELETE FROM master_products WHERE LOWER(name) LIKE '%ride%' 
    OR LOWER(name) LIKE '%driver%' 
    OR LOWER(name) LIKE '%vehicle%'
    OR LOWER(name) LIKE '%transport%';

-- Remove ride-related country categories
DELETE FROM country_categories WHERE category_id IN (
    SELECT id FROM categories WHERE LOWER(name) LIKE '%ride%' 
        OR LOWER(name) LIKE '%driver%' 
        OR LOWER(name) LIKE '%vehicle%'
);

-- Remove ride-related country products
DELETE FROM country_products WHERE product_id IN (
    SELECT id FROM master_products WHERE LOWER(name) LIKE '%ride%' 
        OR LOWER(name) LIKE '%driver%' 
        OR LOWER(name) LIKE '%vehicle%'
);

-- Remove ride-related subscription plans
DELETE FROM subscription_plans WHERE LOWER(code) LIKE '%driver%' 
    OR LOWER(code) LIKE '%ride%'
    OR LOWER(name) LIKE '%driver%'
    OR LOWER(name) LIKE '%ride%';

-- Clean up subscription plan pricing for removed plans
DELETE FROM subscription_country_settings WHERE plan_id NOT IN (
    SELECT id FROM subscription_plans
);

-- Note: We're keeping requests/responses as they might contain valuable data
-- If you want to remove ride-related requests, uncomment the following:
-- DELETE FROM responses WHERE request_id IN (
--     SELECT id FROM requests WHERE request_type = 'ride'
-- );
-- DELETE FROM requests WHERE request_type = 'ride';

-- Update any remaining requests that might have ride type to 'service'
UPDATE requests SET request_type = 'service' WHERE request_type = 'ride';

-- Clean up any ride references in business type mappings
DELETE FROM business_type_plan_mappings WHERE business_type_id IN (
    SELECT id FROM business_types WHERE LOWER(name) LIKE '%ride%' 
        OR LOWER(name) LIKE '%driver%'
);

SELECT 'Ride/Driver related tables and data have been cleaned up successfully.' AS status;
