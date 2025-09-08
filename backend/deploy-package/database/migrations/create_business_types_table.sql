-- Create business_types table for admin-managed business types
CREATE TABLE IF NOT EXISTS business_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50), -- Icon name for UI
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    
    -- Country-specific activation
    country_code VARCHAR(2) NOT NULL,
    
    -- Admin management
    created_by UUID REFERENCES admin_users(id),
    updated_by UUID REFERENCES admin_users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint per country
    UNIQUE(name, country_code)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_business_types_country ON business_types(country_code);
CREATE INDEX IF NOT EXISTS idx_business_types_active ON business_types(is_active);
CREATE INDEX IF NOT EXISTS idx_business_types_display_order ON business_types(display_order);

-- Insert default business types for Sri Lanka
INSERT INTO business_types (name, description, icon, country_code, display_order) VALUES
('Product Selling', 'Sell physical products to customers', 'store', 'LK', 1),
('Delivery Service', 'Provide delivery and logistics services', 'truck', 'LK', 2),
('Both Product & Delivery', 'Both product selling and delivery services', 'business', 'LK', 3),
('Restaurant/Food Service', 'Food and beverage services', 'restaurant', 'LK', 4),
('Professional Services', 'Consulting, legal, accounting services', 'briefcase', 'LK', 5),
('Home Services', 'Cleaning, maintenance, repair services', 'home', 'LK', 6),
('Healthcare Services', 'Medical, dental, wellness services', 'medical', 'LK', 7),
('Educational Services', 'Training, tutoring, courses', 'education', 'LK', 8),
('Entertainment Services', 'Events, photography, music', 'camera', 'LK', 9),
('Technology Services', 'IT support, software development', 'computer', 'LK', 10);

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_business_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_business_types_updated_at
    BEFORE UPDATE ON business_types
    FOR EACH ROW
    EXECUTE FUNCTION update_business_types_updated_at();

-- Comments
COMMENT ON TABLE business_types IS 'Admin-managed business types available per country';
COMMENT ON COLUMN business_types.country_code IS 'Country where this business type is available';
COMMENT ON COLUMN business_types.display_order IS 'Order to display in registration form';
COMMENT ON COLUMN business_types.is_active IS 'Whether this type is available for new registrations';
