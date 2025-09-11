-- AWS RDS PostgreSQL Database Cleanup Script
-- Generated on: 2025-09-11T15:01:50.971Z
-- This script will remove all unrelated tables for simplified system

-- First, check what tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Disable foreign key checks
SET session_replication_role = replica;

-- Drop table: subscriptions
DROP TABLE IF EXISTS "subscriptions" CASCADE;

-- Drop table: subscription_plans
DROP TABLE IF EXISTS "subscription_plans" CASCADE;

-- Drop table: subscription_benefits
DROP TABLE IF EXISTS "subscription_benefits" CASCADE;

-- Drop table: user_subscriptions
DROP TABLE IF EXISTS "user_subscriptions" CASCADE;

-- Drop table: enhanced_business_benefits
DROP TABLE IF EXISTS "enhanced_business_benefits" CASCADE;

-- Drop table: business_benefits
DROP TABLE IF EXISTS "business_benefits" CASCADE;

-- Drop table: membership_plans
DROP TABLE IF EXISTS "membership_plans" CASCADE;

-- Drop table: user_memberships
DROP TABLE IF EXISTS "user_memberships" CASCADE;

-- Drop table: vehicle_types
DROP TABLE IF EXISTS "vehicle_types" CASCADE;

-- Drop table: vehicle_categories
DROP TABLE IF EXISTS "vehicle_categories" CASCADE;

-- Drop table: ride_requests
DROP TABLE IF EXISTS "ride_requests" CASCADE;

-- Drop table: ride_responses
DROP TABLE IF EXISTS "ride_responses" CASCADE;

-- Drop table: rides
DROP TABLE IF EXISTS "rides" CASCADE;

-- Drop table: drivers
DROP TABLE IF EXISTS "drivers" CASCADE;

-- Drop table: vehicles
DROP TABLE IF EXISTS "vehicles" CASCADE;

-- Drop table: driver_vehicles
DROP TABLE IF EXISTS "driver_vehicles" CASCADE;

-- Drop table: delivery_requests
DROP TABLE IF EXISTS "delivery_requests" CASCADE;

-- Drop table: delivery_responses
DROP TABLE IF EXISTS "delivery_responses" CASCADE;

-- Drop table: deliveries
DROP TABLE IF EXISTS "deliveries" CASCADE;

-- Drop table: delivery_status
DROP TABLE IF EXISTS "delivery_status" CASCADE;

-- Drop table: payment_methods
DROP TABLE IF EXISTS "payment_methods" CASCADE;

-- Drop table: payments
DROP TABLE IF EXISTS "payments" CASCADE;

-- Drop table: transactions
DROP TABLE IF EXISTS "transactions" CASCADE;

-- Drop table: user_payment_methods
DROP TABLE IF EXISTS "user_payment_methods" CASCADE;

-- Drop table: business_verifications
DROP TABLE IF EXISTS "business_verifications" CASCADE;

-- Drop table: business_types
DROP TABLE IF EXISTS "business_types" CASCADE;

-- Drop table: business_categories
DROP TABLE IF EXISTS "business_categories" CASCADE;

-- Drop table: hutch_config
DROP TABLE IF EXISTS "hutch_config" CASCADE;

-- Drop table: hutch_mobile_config
DROP TABLE IF EXISTS "hutch_mobile_config" CASCADE;

-- Drop table: hutch_sms_config
DROP TABLE IF EXISTS "hutch_sms_config" CASCADE;

-- Drop table: sms_config
DROP TABLE IF EXISTS "sms_config" CASCADE;

-- Drop table: otp_verifications
DROP TABLE IF EXISTS "otp_verifications" CASCADE;

-- Drop table: phone_verifications
DROP TABLE IF EXISTS "phone_verifications" CASCADE;

-- Drop table: email_verifications
DROP TABLE IF EXISTS "email_verifications" CASCADE;

-- Drop table: user_entitlements
DROP TABLE IF EXISTS "user_entitlements" CASCADE;

-- Drop table: entitlements
DROP TABLE IF EXISTS "entitlements" CASCADE;

-- Drop table: permissions
DROP TABLE IF EXISTS "permissions" CASCADE;

-- Drop table: roles
DROP TABLE IF EXISTS "roles" CASCADE;

-- Drop table: user_roles
DROP TABLE IF EXISTS "user_roles" CASCADE;

-- Drop table: role_permissions
DROP TABLE IF EXISTS "role_permissions" CASCADE;

-- Drop table: api_keys
DROP TABLE IF EXISTS "api_keys" CASCADE;

-- Drop table: sessions
DROP TABLE IF EXISTS "sessions" CASCADE;

-- Drop table: refresh_tokens
DROP TABLE IF EXISTS "refresh_tokens" CASCADE;

-- Drop table: password_resets
DROP TABLE IF EXISTS "password_resets" CASCADE;

-- Drop table: email_templates
DROP TABLE IF EXISTS "email_templates" CASCADE;

-- Drop table: notification_templates
DROP TABLE IF EXISTS "notification_templates" CASCADE;

-- Drop table: push_notifications
DROP TABLE IF EXISTS "push_notifications" CASCADE;

-- Drop table: user_preferences
DROP TABLE IF EXISTS "user_preferences" CASCADE;

-- Drop table: app_settings
DROP TABLE IF EXISTS "app_settings" CASCADE;

-- Drop table: system_config
DROP TABLE IF EXISTS "system_config" CASCADE;

-- Drop table: audit_logs
DROP TABLE IF EXISTS "audit_logs" CASCADE;

-- Drop table: error_logs
DROP TABLE IF EXISTS "error_logs" CASCADE;

-- Drop table: usage_stats
DROP TABLE IF EXISTS "usage_stats" CASCADE;

-- Drop table: analytics_events
DROP TABLE IF EXISTS "analytics_events" CASCADE;

-- Drop table: feedback
DROP TABLE IF EXISTS "feedback" CASCADE;

-- Drop table: reviews
DROP TABLE IF EXISTS "reviews" CASCADE;

-- Drop table: ratings
DROP TABLE IF EXISTS "ratings" CASCADE;

-- Drop table: reports
DROP TABLE IF EXISTS "reports" CASCADE;

-- Drop table: disputes
DROP TABLE IF EXISTS "disputes" CASCADE;

-- Drop table: support_tickets
DROP TABLE IF EXISTS "support_tickets" CASCADE;

-- Drop table: categories
DROP TABLE IF EXISTS "categories" CASCADE;

-- Drop table: subcategories
DROP TABLE IF EXISTS "subcategories" CASCADE;

-- Drop table: tags
DROP TABLE IF EXISTS "tags" CASCADE;

-- Drop table: locations
DROP TABLE IF EXISTS "locations" CASCADE;

-- Drop table: addresses
DROP TABLE IF EXISTS "addresses" CASCADE;

-- Drop table: regions
DROP TABLE IF EXISTS "regions" CASCADE;

-- Drop table: countries
DROP TABLE IF EXISTS "countries" CASCADE;

-- Drop table: cities
DROP TABLE IF EXISTS "cities" CASCADE;

-- Drop table: areas
DROP TABLE IF EXISTS "areas" CASCADE;

-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;

-- Show remaining tables after cleanup
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Create basic tables needed for simplified system
CREATE TABLE IF NOT EXISTS user_usage (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    month_year VARCHAR(7) NOT NULL, -- Format: YYYY-MM
    responses_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, month_year)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_usage_user_month ON user_usage(user_id, month_year);
CREATE INDEX IF NOT EXISTS idx_requests_created_at ON requests(created_at);
CREATE INDEX IF NOT EXISTS idx_responses_request_id ON responses(request_id);
