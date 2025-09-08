-- Create comprehensive price_listings table for price comparison system
-- This table allows businesses to directly add products with pricing and details

-- Create price_listings table if it doesn't exist
CREATE TABLE IF NOT EXISTS price_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_id VARCHAR(255),
    business_id UUID NOT NULL, -- references users.id (business owner)
    master_product_id UUID REFERENCES master_products(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),
    subcategory_id UUID REFERENCES subcategories(id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'LKR',
    unit VARCHAR(100),
    delivery_charge DECIMAL(10, 2) DEFAULT 0,
    images JSONB DEFAULT '[]',
    website VARCHAR(255),
    whatsapp VARCHAR(20),
    city_id UUID REFERENCES cities(id),
    is_active BOOLEAN DEFAULT TRUE,
    view_count INTEGER DEFAULT 0,
    contact_count INTEGER DEFAULT 0,
    country_code VARCHAR(3) DEFAULT 'LK',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add missing columns to existing price_listings table if they don't exist
ALTER TABLE price_listings 
ADD COLUMN IF NOT EXISTS master_product_id UUID REFERENCES master_products(id),
ADD COLUMN IF NOT EXISTS delivery_charge DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]',
ADD COLUMN IF NOT EXISTS website VARCHAR(255),
ADD COLUMN IF NOT EXISTS whatsapp VARCHAR(20);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_price_listings_master_product ON price_listings(master_product_id);
CREATE INDEX IF NOT EXISTS idx_price_listings_business_id ON price_listings(business_id);
CREATE INDEX IF NOT EXISTS idx_price_listings_country_active ON price_listings(country_code, is_active);
CREATE INDEX IF NOT EXISTS idx_price_listings_price ON price_listings(price);
CREATE INDEX IF NOT EXISTS idx_price_listings_category ON price_listings(category_id);
CREATE INDEX IF NOT EXISTS idx_price_listings_city ON price_listings(city_id);

-- Update business_id to be consistent with user_id from business verifications
COMMENT ON COLUMN price_listings.business_id IS 'References users.id (firebase_uid) of the business owner';
COMMENT ON COLUMN price_listings.master_product_id IS 'References master_products.id for centralized product catalog';

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_price_listings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS update_price_listings_updated_at ON price_listings;
CREATE TRIGGER update_price_listings_updated_at
    BEFORE UPDATE ON price_listings
    FOR EACH ROW
    EXECUTE FUNCTION update_price_listings_updated_at();
