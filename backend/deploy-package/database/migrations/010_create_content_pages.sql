-- 010_create_content_pages.sql
-- Creates content_pages table for static / country specific pages.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS content_pages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(160) NOT NULL UNIQUE,
  title VARCHAR(200) NOT NULL,
  page_type VARCHAR(40) NOT NULL DEFAULT 'centralized', -- centralized | country_specific | category_specific
  category_id UUID NULL, -- optional link (no FK to keep flexible)
  country_code VARCHAR(10) NULL REFERENCES countries(code) ON DELETE CASCADE,
  status VARCHAR(30) NOT NULL DEFAULT 'published', -- published | draft | archived
  metadata JSONB,
  content TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_content_pages_status ON content_pages(status);
CREATE INDEX IF NOT EXISTS idx_content_pages_country ON content_pages(country_code);
CREATE INDEX IF NOT EXISTS idx_content_pages_page_type ON content_pages(page_type);

-- Trigger to auto update updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_content_pages_updated_at'
  ) THEN
    CREATE OR REPLACE FUNCTION touch_content_pages_updated_at()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;$$ LANGUAGE plpgsql;

    CREATE TRIGGER trg_content_pages_updated_at
    BEFORE UPDATE ON content_pages
    FOR EACH ROW EXECUTE FUNCTION touch_content_pages_updated_at();
  END IF;
END$$;
