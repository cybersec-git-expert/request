-- Add image_urls field to requests table
ALTER TABLE requests ADD COLUMN IF NOT EXISTS image_urls TEXT[];

-- Also add metadata field if it doesn't exist
ALTER TABLE requests ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Also add budget field (single field) if it doesn't exist (to replace budget_min/budget_max)
ALTER TABLE requests ADD COLUMN IF NOT EXISTS budget NUMERIC(12,2);

-- Also add deadline field if it doesn't exist
ALTER TABLE requests ADD COLUMN IF NOT EXISTS deadline TIMESTAMPTZ;

-- Also add accepted_response_id field if it doesn't exist
ALTER TABLE requests ADD COLUMN IF NOT EXISTS accepted_response_id UUID REFERENCES responses(id);

-- Add location fields that are missing
ALTER TABLE requests ADD COLUMN IF NOT EXISTS location_address TEXT;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS location_latitude DECIMAL(10, 8);
ALTER TABLE requests ADD COLUMN IF NOT EXISTS location_longitude DECIMAL(11, 8);

-- Add currency field if it doesn't exist
ALTER TABLE requests ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'LKR';

-- Create index for image_urls array searching
CREATE INDEX IF NOT EXISTS idx_requests_image_urls ON requests USING GIN(image_urls);

-- Create index for metadata JSONB searching
CREATE INDEX IF NOT EXISTS idx_requests_metadata ON requests USING GIN(metadata);
