-- Adds indexes to optimize search & filtering on requests
-- Safe to run multiple times (IF NOT EXISTS clauses)

-- Ensure pg_trgm extension exists (required for gin_trgm_ops) BEFORE creating trigram indexes
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Trigram GIN indexes for ILIKE search
CREATE INDEX IF NOT EXISTS idx_requests_title_trgm ON requests USING gin (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_requests_description_trgm ON requests USING gin (description gin_trgm_ops);

-- Standard btree indexes for filtering
CREATE INDEX IF NOT EXISTS idx_requests_category ON requests (category_id);
CREATE INDEX IF NOT EXISTS idx_requests_subcategory ON requests (subcategory_id);
CREATE INDEX IF NOT EXISTS idx_requests_city ON requests (location_city_id);
CREATE INDEX IF NOT EXISTS idx_requests_country ON requests (country_code);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests (status);
CREATE INDEX IF NOT EXISTS idx_requests_accepted_response ON requests (accepted_response_id);

-- Partial index for accepted requests to speed has_accepted filter
CREATE INDEX IF NOT EXISTS idx_requests_accepted_only ON requests (accepted_response_id) WHERE accepted_response_id IS NOT NULL;
