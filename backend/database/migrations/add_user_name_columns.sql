-- Migration: add first_name and last_name columns to users table
-- Idempotent: only adds columns if they do not already exist

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS first_name VARCHAR(100),
    ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);

-- Optional: populate from display_name if present and first/last empty
UPDATE users
SET first_name = COALESCE(first_name, split_part(display_name, ' ', 1)),
    last_name = COALESCE(last_name, NULLIF(trim(substring(display_name FROM position(' ' IN display_name))), ''))
WHERE display_name IS NOT NULL
  AND (first_name IS NULL OR last_name IS NULL);
