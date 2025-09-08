-- Migration: add request type to categories
-- Adds a nullable request_type column and supporting index.
-- Idempotent / safe to run multiple times.

ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS request_type VARCHAR(30);

-- Optional: seed initial request types based on simple heuristics (can adjust manually later)
UPDATE categories
SET request_type = CASE
  WHEN LOWER(name) LIKE '%service%' THEN 'service'
  WHEN LOWER(name) LIKE '%event%' THEN 'service'
  WHEN LOWER(name) LIKE '%professional%' THEN 'service'
  WHEN LOWER(name) LIKE '%technical%' THEN 'service'
  WHEN LOWER(name) LIKE '%personal%' THEN 'service'
  WHEN LOWER(name) LIKE '%home%' THEN 'item'
  WHEN LOWER(name) LIKE '%garden%' THEN 'item'
  WHEN LOWER(name) LIKE '%tool%' THEN 'item'
  WHEN LOWER(name) LIKE '%equipment%' THEN 'item'
  WHEN LOWER(name) LIKE '%electronic%' THEN 'item'
  WHEN LOWER(name) LIKE '%fashion%' THEN 'item'
  WHEN LOWER(name) LIKE '%vehicle%' THEN 'rent'
  WHEN LOWER(name) LIKE '%transport%' THEN 'delivery'
  WHEN LOWER(name) LIKE '%document%' OR LOWER(name) LIKE '%mail%' THEN 'delivery'
  ELSE request_type
END
WHERE request_type IS NULL;

CREATE INDEX IF NOT EXISTS idx_categories_request_type ON categories(request_type);
