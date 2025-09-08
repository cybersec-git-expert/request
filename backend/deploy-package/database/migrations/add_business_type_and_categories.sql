-- Add business_type and categories columns to business_verifications table
-- This migration transforms the existing business_category system

-- 1. Add new columns
ALTER TABLE business_verifications 
ADD COLUMN IF NOT EXISTS business_type VARCHAR(50),
ADD COLUMN IF NOT EXISTS categories JSONB DEFAULT '[]'::jsonb;

-- 2. Create enum-like constraint for business_type
ALTER TABLE business_verifications 
ADD CONSTRAINT check_business_type 
CHECK (business_type IN ('product_selling', 'delivery_service', 'both'));

-- 3. Migrate existing data: map business_category to business_type
UPDATE business_verifications 
SET business_type = CASE 
    WHEN LOWER(business_category) LIKE '%delivery%' THEN 'delivery_service'
    WHEN LOWER(business_category) LIKE '%service%' THEN 'delivery_service'
    WHEN LOWER(business_category) LIKE '%product%' THEN 'product_selling'
    WHEN LOWER(business_category) LIKE '%retail%' THEN 'product_selling'
    WHEN LOWER(business_category) LIKE '%shop%' THEN 'product_selling'
    WHEN LOWER(business_category) LIKE '%store%' THEN 'product_selling'
    WHEN LOWER(business_category) LIKE '%electronics%' THEN 'product_selling'
    WHEN LOWER(business_category) LIKE '%mobile%' THEN 'product_selling'
    WHEN LOWER(business_category) LIKE '%food%' THEN 'product_selling'
    ELSE 'product_selling' -- Default to product selling
END
WHERE business_type IS NULL;

-- 4. For businesses that might do both (courier companies, marketplace vendors)
UPDATE business_verifications 
SET business_type = 'both'
WHERE LOWER(business_category) LIKE '%courier%' 
   OR LOWER(business_category) LIKE '%marketplace%'
   OR LOWER(business_category) LIKE '%logistics%';

-- 5. Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_business_verifications_business_type ON business_verifications(business_type);
CREATE INDEX IF NOT EXISTS idx_business_verifications_categories ON business_verifications USING GIN (categories);

-- 6. Add comment for clarity
COMMENT ON COLUMN business_verifications.business_type IS 'Type of business: product_selling, delivery_service, or both';
COMMENT ON COLUMN business_verifications.categories IS 'Array of category IDs that business operates in for notifications';

-- 7. Keep business_category for backward compatibility (will be deprecated later)
COMMENT ON COLUMN business_verifications.business_category IS 'DEPRECATED: Use business_type and categories instead';
