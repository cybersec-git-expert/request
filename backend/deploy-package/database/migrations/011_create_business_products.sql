-- 011_create_business_products.sql
-- Associates businesses with master products and allows per-business overrides/pricing basics.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS business_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL, -- expected to reference users (business role) or businesses table if added later
  master_product_id UUID NOT NULL REFERENCES master_products(id) ON DELETE CASCADE,
  country_code VARCHAR(10) NULL REFERENCES countries(code) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(business_id, master_product_id, country_code)
);
CREATE INDEX IF NOT EXISTS idx_business_products_business ON business_products(business_id);
CREATE INDEX IF NOT EXISTS idx_business_products_country ON business_products(country_code);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_business_products_updated_at'
  ) THEN
    CREATE OR REPLACE FUNCTION touch_business_products_updated_at()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

    CREATE TRIGGER trg_business_products_updated_at
    BEFORE UPDATE ON business_products
    FOR EACH ROW EXECUTE FUNCTION touch_business_products_updated_at();
  END IF;
END$$;
