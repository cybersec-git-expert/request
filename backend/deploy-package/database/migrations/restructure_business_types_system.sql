-- Migration: Restructure business types system
-- This restructures the system so that:
-- 1. business_types = global types (super admin managed)
-- 2. country_business_types = country-specific types (country admin managed)

-- Step 1: Create country_business_types table by copying current business_types structure
CREATE TABLE IF NOT EXISTS country_business_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50), -- Icon name for UI
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    
    -- Country-specific activation
    country_code VARCHAR(2) NOT NULL,
    
    -- Reference to global business type (optional)
    global_business_type_id INTEGER REFERENCES business_types(id),
    
    -- Admin management
    created_by UUID REFERENCES admin_users(id),
    updated_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint per country
    UNIQUE(name, country_code)
);

-- Step 2: Copy existing business_types data to country_business_types
INSERT INTO country_business_types (
    id, name, description, icon, is_active, display_order, 
    country_code, created_by, updated_by, created_at, updated_at
)
SELECT 
    id, name, description, icon, is_active, display_order,
    country_code, created_by, updated_by, created_at, updated_at
FROM business_types
ON CONFLICT DO NOTHING;

-- Step 3: Clear business_types table and restructure it for global use
TRUNCATE TABLE business_types CASCADE;

-- Step 4: Restructure business_types table for global use (super admin managed)
-- Remove country_code column since it's now global
DO $$ 
BEGIN
    -- Drop country-specific constraints and indexes
    DROP INDEX IF EXISTS idx_business_types_country;
    
    -- Remove country_code column
    IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'business_types'
        AND column_name = 'country_code'
    ) THEN
        ALTER TABLE business_types DROP COLUMN country_code;
    END IF;
    
    -- Remove country-specific unique constraint
    IF EXISTS (
        SELECT FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'business_types'
        AND constraint_name LIKE '%business_types_name_country_code_key%'
    ) THEN
        ALTER TABLE business_types DROP CONSTRAINT business_types_name_country_code_key;
    END IF;
END $$;

-- Step 5: Add global unique constraint to business_types
ALTER TABLE business_types ADD CONSTRAINT business_types_name_unique UNIQUE(name);

-- Step 6: Insert default global business types
INSERT INTO business_types (name, description, icon, display_order) VALUES
('Product Seller', 'Businesses that sell physical products (electronics, food, clothing, etc.)', 'store', 1),
('Service Provider', 'Businesses that provide services (repairs, consultations, etc.)', 'tools', 2),
('Rental Business', 'Businesses that rent out items (vehicles, equipment, etc.)', 'home', 3),
('Restaurant/Food', 'Restaurants, cafes, food delivery businesses', 'restaurant', 4),
('Delivery Service', 'Courier, logistics, and delivery companies', 'truck', 5),
('Other Business', 'Businesses that don''t fit into other categories', 'business', 6),
('Professional Services', 'Legal, accounting, consulting, medical services', 'briefcase', 7),
('Retail Store', 'Physical retail stores and shops', 'store', 8),
('E-commerce', 'Online businesses and digital marketplaces', 'computer', 9),
('Manufacturing', 'Production and manufacturing businesses', 'factory', 10),
('Education & Training', 'Schools, training centers, tutoring services', 'education', 11),
('Healthcare', 'Medical services, clinics, pharmacies', 'medical', 12),
('Entertainment', 'Events, gaming, media, recreation services', 'camera', 13),
('Transportation', 'Taxi, bus, logistics, transport services', 'car', 14),
('Real Estate', 'Property sales, rentals, real estate services', 'home', 15)
ON CONFLICT (name) DO NOTHING;

-- Step 7: Create indexes for country_business_types
CREATE INDEX IF NOT EXISTS idx_country_business_types_country ON country_business_types(country_code);
CREATE INDEX IF NOT EXISTS idx_country_business_types_active ON country_business_types(is_active);
CREATE INDEX IF NOT EXISTS idx_country_business_types_display_order ON country_business_types(display_order);
CREATE INDEX IF NOT EXISTS idx_country_business_types_global_ref ON country_business_types(global_business_type_id);

-- Step 8: Create indexes for business_types (global)
CREATE INDEX IF NOT EXISTS idx_business_types_active_global ON business_types(is_active);
CREATE INDEX IF NOT EXISTS idx_business_types_display_order_global ON business_types(display_order);

-- Step 9: Add trigger for country_business_types updated_at
CREATE OR REPLACE FUNCTION update_country_business_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_country_business_types_updated_at
    BEFORE UPDATE ON country_business_types
    FOR EACH ROW
    EXECUTE FUNCTION update_country_business_types_updated_at();

-- Step 10: Update business verification table to reference country_business_types
DO $$ 
BEGIN
    -- Add new column for country business types reference
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'business_verification'
        AND column_name = 'country_business_type_id'
    ) THEN
        ALTER TABLE business_verification 
        ADD COLUMN country_business_type_id UUID REFERENCES country_business_types(id);
    END IF;
    
    -- Update existing records to reference country business types
    -- This assumes business_type_id currently references the old business_types table
    UPDATE business_verification 
    SET country_business_type_id = business_type_id
    WHERE country_business_type_id IS NULL AND business_type_id IS NOT NULL;
END $$;

-- Step 11: Create view for country business types with global information
CREATE OR REPLACE VIEW country_business_types_with_global AS
SELECT 
    cbt.*,
    bt.name as global_name,
    bt.description as global_description,
    bt.icon as global_icon,
    bt.display_order as global_display_order
FROM country_business_types cbt
LEFT JOIN business_types bt ON cbt.global_business_type_id = bt.id;

-- Step 12: Add comments for clarity
COMMENT ON TABLE business_types IS 'Global business types managed by super admins, serve as templates for countries';
COMMENT ON TABLE country_business_types IS 'Country-specific business types managed by country admins';
COMMENT ON COLUMN country_business_types.global_business_type_id IS 'Optional reference to global business type template';
COMMENT ON COLUMN business_verification.country_business_type_id IS 'Reference to country-specific business type';

-- Step 13: Grant permissions (adjust as needed for your user roles)
-- These are examples - adjust according to your actual user setup
-- GRANT SELECT, INSERT, UPDATE, DELETE ON business_types TO super_admin_role;
-- GRANT SELECT ON business_types TO country_admin_role;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON country_business_types TO country_admin_role;
