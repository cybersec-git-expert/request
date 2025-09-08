-- Update business_verifications to reference business_types table
-- Add foreign key reference to business_types

-- Add new column for business type ID
ALTER TABLE business_verifications 
ADD COLUMN IF NOT EXISTS business_type_id UUID REFERENCES business_types(id);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_business_verifications_business_type_id ON business_verifications(business_type_id);

-- Update existing records to match the new business_types
-- First, let's create a mapping for existing business_type values
UPDATE business_verifications 
SET business_type_id = (
    SELECT bt.id 
    FROM business_types bt 
    WHERE 
        (business_verifications.business_type = 'product_selling' AND bt.name = 'Product Selling' AND bt.country_code = business_verifications.country) OR
        (business_verifications.business_type = 'delivery_service' AND bt.name = 'Delivery Service' AND bt.country_code = business_verifications.country) OR
        (business_verifications.business_type = 'both' AND bt.name = 'Both Product & Delivery' AND bt.country_code = business_verifications.country)
    LIMIT 1
)
WHERE business_type_id IS NULL AND business_type IS NOT NULL;

-- Keep the old business_type column for backward compatibility during transition
COMMENT ON COLUMN business_verifications.business_type IS 'DEPRECATED: Use business_type_id instead';
COMMENT ON COLUMN business_verifications.business_type_id IS 'Reference to admin-managed business_types table';
