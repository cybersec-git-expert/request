-- Add firebase_uid to users (for mapping Firestore auth user id) and firebase_id to brands
-- Idempotent / safe re-run

ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(255);
-- Ensure uniqueness but allow many NULLs (Postgres treats NULLs as distinct)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'users_firebase_uid_key'
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX users_firebase_uid_key ON users(firebase_uid)';
  END IF;
END$$;

-- Add firebase_id to brands for Firestore doc id mapping
ALTER TABLE brands ADD COLUMN IF NOT EXISTS firebase_id VARCHAR(255);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'brands_firebase_id_key'
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX brands_firebase_id_key ON brands(firebase_id)';
  END IF;
END$$;

-- Backfill heuristics: if slug looks like a firebase id and firebase_id is null, set it
UPDATE brands SET firebase_id = slug WHERE firebase_id IS NULL AND slug IS NOT NULL AND length(slug) BETWEEN 10 AND 40;

-- Touch updated_at when firebase columns change
CREATE OR REPLACE FUNCTION touch_brands_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_brands_updated_at ON brands;
CREATE TRIGGER trg_brands_updated_at
BEFORE UPDATE ON brands
FOR EACH ROW EXECUTE FUNCTION touch_brands_updated_at();
