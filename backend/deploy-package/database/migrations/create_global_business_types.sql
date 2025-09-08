-- Migration: Create global business types system
-- This creates a global business types table that serves as templates for countries

-- 1. Create global_business_types table (super admin managed)
CREATE TABLE IF NOT EXISTS global_business_types (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  icon VARCHAR(255),
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_by INTEGER REFERENCES admin_users(id),
  updated_by INTEGER REFERENCES admin_users(id)
);

-- 2. Add global_type_id column to business_types table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'business_types'
    AND column_name = 'global_type_id'
  ) THEN
    ALTER TABLE business_types 
    ADD COLUMN global_type_id INTEGER REFERENCES global_business_types(id);
  END IF;
END $$;

-- 3. Insert default global business types
INSERT INTO global_business_types (name, description, icon, display_order) 
VALUES 
  ('Product Seller', 'Businesses that sell physical products (electronics, food, clothing, etc.)', '🛍️', 1),
  ('Service Provider', 'Businesses that provide services (repairs, consultations, etc.)', '🔧', 2),
  ('Rental Business', 'Businesses that rent out items (vehicles, equipment, etc.)', '🏠', 3),
  ('Restaurant/Food', 'Restaurants, cafes, food delivery businesses', '🍽️', 4),
  ('Delivery Service', 'Courier, logistics, and delivery companies', '🚚', 5),
  ('Other Business', 'Businesses that don\'t fit into other categories', '🏢', 6),
  ('Professional Services', 'Legal, accounting, consulting, medical services', '💼', 7),
  ('Retail Store', 'Physical retail stores and shops', '🏪', 8),
  ('E-commerce', 'Online businesses and digital marketplaces', '💻', 9),
  ('Manufacturing', 'Production and manufacturing businesses', '🏭', 10),
  ('Education & Training', 'Schools, training centers, tutoring services', '🎓', 11),
  ('Healthcare', 'Medical services, clinics, pharmacies', '🏥', 12),
  ('Entertainment', 'Events, gaming, media, recreation services', '🎭', 13),
  ('Transportation', 'Taxi, bus, logistics, transport services', '🚗', 14),
  ('Real Estate', 'Property sales, rentals, real estate services', '🏠', 15)
ON CONFLICT (name) DO NOTHING;

-- 4. Update existing business_types to reference global types
UPDATE business_types 
SET global_type_id = (
  SELECT id FROM global_business_types 
  WHERE global_business_types.name = business_types.name
  LIMIT 1
)
WHERE global_type_id IS NULL;

-- 5. Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_global_business_types_active ON global_business_types(is_active);
CREATE INDEX IF NOT EXISTS idx_global_business_types_display_order ON global_business_types(display_order);
CREATE INDEX IF NOT EXISTS idx_business_types_global_type_id ON business_types(global_type_id);

-- 6. Add comments for clarity
COMMENT ON TABLE global_business_types IS 'Global business types managed by super admins, serve as templates for countries';
COMMENT ON COLUMN business_types.global_type_id IS 'Reference to global business type template';

-- 7. Create view for business types with global information
CREATE OR REPLACE VIEW business_types_with_global AS
SELECT 
  bt.*,
  gbt.name as global_name,
  gbt.description as global_description,
  gbt.icon as global_icon,
  gbt.display_order as global_display_order
FROM business_types bt
LEFT JOIN global_business_types gbt ON bt.global_type_id = gbt.id;
