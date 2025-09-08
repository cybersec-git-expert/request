-- Add firebase_id columns and unique indexes for categories and subcategories
-- Idempotent safeguards
ALTER TABLE categories ADD COLUMN IF NOT EXISTS firebase_id VARCHAR(255) UNIQUE;
ALTER TABLE subcategories ADD COLUMN IF NOT EXISTS firebase_id VARCHAR(255) UNIQUE;

-- Backfill firebase_id from existing data if empty and name looked like original id (heuristic: length 28 base62)
UPDATE categories SET firebase_id = name WHERE firebase_id IS NULL AND length(name) BETWEEN 20 AND 36;
-- For subcategories we lack source mapping; leave nulls to be filled by importer.

-- Add request_type column if missing (as seen in runtime schema)
ALTER TABLE categories ADD COLUMN IF NOT EXISTS request_type VARCHAR(50);

-- Indexes (unique already created via UNIQUE constraint if column added). Ensure existence explicitly.
DO $$ BEGIN
  EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS categories_firebase_id_key ON categories(firebase_id)';
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS subcategories_firebase_id_key ON subcategories(firebase_id)';
EXCEPTION WHEN others THEN NULL; END $$;
