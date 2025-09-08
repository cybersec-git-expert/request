-- Create country_modules table to store per-country module configuration
-- Idempotent: uses IF NOT EXISTS and adds columns conditionally

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS country_modules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code VARCHAR(10) NOT NULL REFERENCES countries(code) ON DELETE CASCADE,
  modules JSONB NOT NULL DEFAULT '{}'::jsonb,
  core_dependencies JSONB NOT NULL DEFAULT '{}'::jsonb,
  version TEXT DEFAULT '1.0.0',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(country_code)
);

CREATE INDEX IF NOT EXISTS idx_country_modules_country ON country_modules(country_code);

CREATE OR REPLACE FUNCTION touch_country_modules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_country_modules_updated_at ON country_modules;
CREATE TRIGGER trg_country_modules_updated_at
BEFORE UPDATE ON country_modules
FOR EACH ROW EXECUTE FUNCTION touch_country_modules_updated_at();
