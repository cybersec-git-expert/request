-- Create table: business_payment_methods
-- Maps a business (users.id) to accepted payment methods in their country

CREATE TABLE IF NOT EXISTS business_payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payment_method_id UUID NOT NULL REFERENCES country_payment_methods(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (business_id, payment_method_id)
);

CREATE INDEX IF NOT EXISTS idx_business_payment_methods_business ON business_payment_methods(business_id);
CREATE INDEX IF NOT EXISTS idx_business_payment_methods_payment ON business_payment_methods(payment_method_id);

-- Trigger to keep updated_at fresh
CREATE OR REPLACE FUNCTION trg_update_business_payment_methods_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_business_payment_methods_updated_at ON business_payment_methods;
CREATE TRIGGER update_business_payment_methods_updated_at
  BEFORE UPDATE ON business_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION trg_update_business_payment_methods_updated_at();

COMMENT ON TABLE business_payment_methods IS 'Mapping of businesses to accepted payment methods';
