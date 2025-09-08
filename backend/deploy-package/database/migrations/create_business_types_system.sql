-- Migration: Create business_types table and update business_verifications
-- This creates an admin-managed business types system

-- 1. Create business_types table (admin-managed)
CREATE TABLE IF NOT EXISTS business_types (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  icon VARCHAR(255),
  country_code VARCHAR(2) NOT NULL DEFAULT 'LK',
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(name, country_code)
);

-- 2. Add business_type_id column to business_verifications
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'business_verifications'
    AND column_name = 'business_type_id'
  ) THEN
    ALTER TABLE business_verifications 
    ADD COLUMN business_type_id INTEGER REFERENCES business_types(id);
  END IF;
END $$;

-- 3. Add categories column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'business_verifications'
    AND column_name = 'categories'
  ) THEN
    ALTER TABLE business_verifications 
    ADD COLUMN categories JSONB DEFAULT '[]';
  END IF;
END $$;

-- 4. Drop old constraint if it exists and create new one
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM information_schema.table_constraints 
    WHERE table_schema = 'public' 
    AND table_name = 'business_verifications'
    AND constraint_name = 'check_business_type'
  ) THEN
    ALTER TABLE business_verifications DROP CONSTRAINT check_business_type;
  END IF;
  
  -- Add new constraint with current values
  ALTER TABLE business_verifications 
  ADD CONSTRAINT check_business_type 
  CHECK (business_type IN ('item', 'service', 'rent', 'restaurant', 'delivery', 'other'));
END $$;

-- 5. Insert default business types for Sri Lanka
INSERT INTO business_types (name, description, icon, country_code, display_order) 
VALUES 
  ('Product Seller', 'Businesses that sell physical products (electronics, food, clothing, etc.)', '🛍️', 'LK', 1),
  ('Service Provider', 'Businesses that provide services (repairs, consultations, etc.)', '🔧', 'LK', 2),
  ('Rental Business', 'Businesses that rent out items (vehicles, equipment, etc.)', '🏠', 'LK', 3),
  ('Restaurant/Food', 'Restaurants, cafes, food delivery businesses', '🍽️', 'LK', 4),
  ('Delivery Service', 'Courier, logistics, and delivery companies', '🚚', 'LK', 5),
  ('Other Business', 'Businesses that do not fit into other categories', '🏢', 'LK', 6)
ON CONFLICT (name, country_code) DO NOTHING;

-- 6. Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_business_verifications_business_type ON business_verifications(business_type);
CREATE INDEX IF NOT EXISTS idx_business_verifications_business_type_id ON business_verifications(business_type_id);
CREATE INDEX IF NOT EXISTS idx_business_verifications_categories ON business_verifications USING GIN (categories);
CREATE INDEX IF NOT EXISTS idx_business_types_country_active ON business_types(country_code, is_active);

-- 7. Add comments for clarity
COMMENT ON TABLE business_types IS 'Admin-managed business types for each country';
COMMENT ON COLUMN business_verifications.business_type_id IS 'Reference to admin-managed business type';
COMMENT ON COLUMN business_verifications.business_type IS 'LEGACY: String business type, use business_type_id instead';
COMMENT ON COLUMN business_verifications.categories IS 'Array of category IDs that business operates in for notifications';
