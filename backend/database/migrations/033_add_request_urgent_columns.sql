BEGIN;

-- Add urgent boost fields to requests
ALTER TABLE IF EXISTS requests
  ADD COLUMN IF NOT EXISTS is_urgent BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS urgent_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS urgent_paid_tx_id UUID;

-- Helpful index for active urgent sorting/filtering
CREATE INDEX IF NOT EXISTS idx_requests_urgent_active ON requests ((is_urgent AND urgent_until > now()));

COMMIT;
