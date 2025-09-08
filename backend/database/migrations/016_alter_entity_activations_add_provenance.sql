-- 016_alter_entity_activations_add_provenance.sql
-- Adds provenance/source fields to entity_activations if missing.
ALTER TABLE entity_activations
  ADD COLUMN IF NOT EXISTS source VARCHAR(40) DEFAULT 'import';

-- Track how activation was created (script, admin UI, import, auto)
ALTER TABLE entity_activations
  ADD COLUMN IF NOT EXISTS provenance JSONB;
