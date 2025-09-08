-- Generic entity activations and overrides
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS entity_activations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(50) NOT NULL,
  entity_id UUID NOT NULL,
  country_code VARCHAR(10) NOT NULL REFERENCES countries(code) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  config JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(entity_type, entity_id, country_code)
);
CREATE INDEX IF NOT EXISTS idx_entity_act_type_country ON entity_activations(entity_type, country_code);

CREATE TABLE IF NOT EXISTS entity_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(50) NOT NULL,
  entity_id UUID NOT NULL,
  country_code VARCHAR(10) NOT NULL REFERENCES countries(code) ON DELETE CASCADE,
  overrides JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(entity_type, entity_id, country_code)
);
CREATE INDEX IF NOT EXISTS idx_entity_ovr_type_country ON entity_overrides(entity_type, country_code);
