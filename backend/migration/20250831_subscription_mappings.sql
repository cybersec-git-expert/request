-- Subscription mappings schema (business_type -> plan per country)
-- Safe to run multiple times; uses IF NOT EXISTS and idempotent indexes

BEGIN;

-- Core mapping table: which plan is allowed for a business type in a country
CREATE TABLE IF NOT EXISTS business_type_plan_mappings (
  id BIGSERIAL PRIMARY KEY,
  country_code VARCHAR(4) NOT NULL,
  business_type_id BIGINT NOT NULL,
  plan_id BIGINT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_btp_mapping_business_type
    FOREIGN KEY (business_type_id) REFERENCES business_types(id) ON DELETE RESTRICT,
  CONSTRAINT fk_btp_mapping_plan
    FOREIGN KEY (plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT
);

-- Uniqueness needed for ON CONFLICT (country_code, business_type_id, plan_id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
      AND indexname = 'ux_btp_mapping_country_bt_plan'
  ) THEN
    CREATE UNIQUE INDEX ux_btp_mapping_country_bt_plan
      ON business_type_plan_mappings (country_code, business_type_id, plan_id);
  END IF;
END$$;

-- Allowed request types per mapping
CREATE TABLE IF NOT EXISTS business_type_plan_allowed_request_types (
  mapping_id BIGINT NOT NULL,
  request_type TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pk_btp_allowed_request_types PRIMARY KEY (mapping_id, request_type),
  CONSTRAINT fk_btp_allowed_request_types_mapping
    FOREIGN KEY (mapping_id) REFERENCES business_type_plan_mappings(id) ON DELETE CASCADE
);

COMMIT;
