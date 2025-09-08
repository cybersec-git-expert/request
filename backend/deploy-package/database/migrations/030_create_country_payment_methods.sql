-- Create table: country_payment_methods
-- Stores country-scoped payment methods that admins can manage

CREATE TABLE IF NOT EXISTS country_payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code VARCHAR(5) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    category VARCHAR(32) NOT NULL DEFAULT 'digital' CHECK (category IN ('digital','bank','card','cash','crypto')),
    image_url TEXT,
    link_url TEXT,
    fees VARCHAR(64),
    processing_time VARCHAR(64),
    min_amount NUMERIC(14,2),
    max_amount NUMERIC(14,2),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_country_payment_methods_country_active ON country_payment_methods(country_code, is_active);
CREATE INDEX IF NOT EXISTS idx_country_payment_methods_name ON country_payment_methods(LOWER(name));
CREATE INDEX IF NOT EXISTS idx_country_payment_methods_category ON country_payment_methods(category);

-- Trigger to keep updated_at fresh
CREATE OR REPLACE FUNCTION trg_update_country_payment_methods_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_country_payment_methods_updated_at ON country_payment_methods;
CREATE TRIGGER update_country_payment_methods_updated_at
  BEFORE UPDATE ON country_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION trg_update_country_payment_methods_updated_at();

COMMENT ON TABLE country_payment_methods IS 'Country-scoped payment methods visible to users and selectable by businesses';
COMMENT ON COLUMN country_payment_methods.category IS 'Allowed: digital, bank, card, cash, crypto';
