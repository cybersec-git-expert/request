-- Fix business_type_plan_mappings to use UUID for business_type_id
-- Drop and recreate the table with proper UUID foreign key

DROP TABLE IF EXISTS business_type_plan_allowed_request_types CASCADE;
DROP TABLE IF EXISTS business_type_plan_mappings CASCADE;

-- Recreate with UUID foreign key
CREATE TABLE IF NOT EXISTS business_type_plan_mappings (
  id SERIAL PRIMARY KEY,
  country_code VARCHAR(10) NOT NULL,
  business_type_id UUID NOT NULL REFERENCES business_types(id) ON DELETE CASCADE,
  plan_id INTEGER NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(country_code, business_type_id, plan_id)
);

CREATE OR REPLACE FUNCTION trg_update_business_type_plan_mappings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_business_type_plan_mappings_updated_at ON business_type_plan_mappings;
CREATE TRIGGER trg_business_type_plan_mappings_updated_at
BEFORE UPDATE ON business_type_plan_mappings
FOR EACH ROW EXECUTE FUNCTION trg_update_business_type_plan_mappings_updated_at();

-- Recreate allowed request types table
CREATE TABLE IF NOT EXISTS business_type_plan_allowed_request_types (
  id SERIAL PRIMARY KEY,
  mapping_id INTEGER NOT NULL REFERENCES business_type_plan_mappings(id) ON DELETE CASCADE,
  request_type VARCHAR(50) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(mapping_id, request_type)
);
