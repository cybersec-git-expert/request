-- Adds responder location fields to responses table
ALTER TABLE responses ADD COLUMN IF NOT EXISTS location_address TEXT;
ALTER TABLE responses ADD COLUMN IF NOT EXISTS location_latitude DECIMAL(10,8);
ALTER TABLE responses ADD COLUMN IF NOT EXISTS location_longitude DECIMAL(11,8);
ALTER TABLE responses ADD COLUMN IF NOT EXISTS country_code VARCHAR(10);

-- Indexes to help filtering by geography
CREATE INDEX IF NOT EXISTS idx_responses_country ON responses(country_code);
-- Latitude/longitude rarely filtered directly; skip spatial index until PostGIS is introduced.
