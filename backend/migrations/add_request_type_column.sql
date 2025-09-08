-- Add request_type column to requests table
-- This provides consistent request type identification for filtering

-- Add the column
ALTER TABLE requests ADD COLUMN IF NOT EXISTS request_type VARCHAR(50);

-- Create index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_requests_request_type ON requests(request_type);

-- Update existing records based on metadata
UPDATE requests 
SET request_type = CASE 
    WHEN metadata->>'type' LIKE '%item%' THEN 'item'
    WHEN metadata->>'type' LIKE '%service%' THEN 'service'
    WHEN metadata->>'type' LIKE '%ride%' THEN 'ride'
    WHEN metadata->>'type' LIKE '%rental%' OR metadata->>'type' LIKE '%rent%' THEN 'rent'
    WHEN metadata->>'type' LIKE '%delivery%' THEN 'delivery'
    WHEN category_id IN (
        SELECT id FROM categories WHERE request_type = 'item_request'
    ) THEN 'item'
    WHEN category_id IN (
        SELECT id FROM categories WHERE request_type = 'service_request'
    ) THEN 'service'
    WHEN category_id IN (
        SELECT id FROM categories WHERE request_type = 'ride_request'
    ) THEN 'ride'
    WHEN category_id IN (
        SELECT id FROM categories WHERE request_type = 'rent_request'
    ) THEN 'rent'
    WHEN category_id IN (
        SELECT id FROM categories WHERE request_type = 'delivery_request'
    ) THEN 'delivery'
    ELSE 'item' -- Default fallback
END
WHERE request_type IS NULL;

-- Add constraint to ensure valid request types
ALTER TABLE requests ADD CONSTRAINT check_request_type 
CHECK (request_type IN ('item', 'service', 'ride', 'rent', 'delivery'));

-- Create a trigger to auto-set request_type based on category
CREATE OR REPLACE FUNCTION set_request_type_from_category()
RETURNS TRIGGER AS $$
BEGIN
    -- If request_type is not explicitly set, derive from category
    IF NEW.request_type IS NULL AND NEW.category_id IS NOT NULL THEN
        SELECT CASE 
            WHEN c.request_type = 'item_request' THEN 'item'
            WHEN c.request_type = 'service_request' THEN 'service'
            WHEN c.request_type = 'ride_request' THEN 'ride'
            WHEN c.request_type = 'rent_request' THEN 'rent'
            WHEN c.request_type = 'delivery_request' THEN 'delivery'
            ELSE 'item'
        END INTO NEW.request_type
        FROM categories c 
        WHERE c.id = NEW.category_id;
    END IF;
    
    -- For ride requests without category (as implemented recently)
    IF NEW.request_type IS NULL AND NEW.category_id IS NULL 
       AND NEW.metadata->>'type' LIKE '%ride%' THEN
        NEW.request_type := 'ride';
    END IF;
    
    -- Default fallback
    IF NEW.request_type IS NULL THEN
        NEW.request_type := 'item';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_set_request_type ON requests;
CREATE TRIGGER trigger_set_request_type
    BEFORE INSERT OR UPDATE ON requests
    FOR EACH ROW
    EXECUTE FUNCTION set_request_type_from_category();
