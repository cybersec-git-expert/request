-- Create country_business_types table (per-country activation of global business types)
-- Mirrors the style of other country_* tables like country_brands

-- Enable pgcrypto for gen_random_uuid if needed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS country_business_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_id VARCHAR(255),
  country_code VARCHAR(10) NOT NULL,
  -- Reference to global business type template
  global_business_type_id INTEGER REFERENCES business_types(id),

  -- Optional denormalized display fields for admin convenience
  name VARCHAR(100) NOT NULL,
  description TEXT,
  icon VARCHAR(50),
  display_order INTEGER DEFAULT 0,

  is_active BOOLEAN DEFAULT TRUE,
  created_by UUID REFERENCES admin_users(id),
  updated_by UUID REFERENCES admin_users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Avoid duplicates per country
  CONSTRAINT uq_country_business_types_name UNIQUE (country_code, name)
);

-- Also avoid duplicate mapping when global_business_type_id is present
CREATE UNIQUE INDEX IF NOT EXISTS uq_country_business_types_global
  ON country_business_types(country_code, global_business_type_id)
  WHERE global_business_type_id IS NOT NULL;

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_cbt_country ON country_business_types(country_code);
CREATE INDEX IF NOT EXISTS idx_cbt_active ON country_business_types(is_active);
CREATE INDEX IF NOT EXISTS idx_cbt_display_order ON country_business_types(display_order);
CREATE INDEX IF NOT EXISTS idx_cbt_global_ref ON country_business_types(global_business_type_id);

-- updated_at trigger
CREATE OR REPLACE FUNCTION update_country_business_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_country_business_types_updated_at ON country_business_types;
CREATE TRIGGER trg_update_country_business_types_updated_at
BEFORE UPDATE ON country_business_types
FOR EACH ROW EXECUTE FUNCTION update_country_business_types_updated_at();
