CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Note: cannot use expression in a table-level UNIQUE column list.
-- Enforce uniqueness for global (NULL country) and per-country entries via separate partial indexes.
CREATE TABLE IF NOT EXISTS custom_product_variables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES master_products(id) ON DELETE CASCADE,
  variable_key VARCHAR(100) NOT NULL,
  value TEXT,
  country_code VARCHAR(10), -- NULL means global/default
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cpv_product ON custom_product_variables(product_id);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_cpv_global ON custom_product_variables(product_id, variable_key) WHERE country_code IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uniq_cpv_country ON custom_product_variables(product_id, variable_key, country_code) WHERE country_code IS NOT NULL;
