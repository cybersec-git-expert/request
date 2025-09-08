-- Create responses table for request marketplace
CREATE TABLE IF NOT EXISTS responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  price NUMERIC(12,2),
  currency VARCHAR(10),
  metadata JSONB,
  image_urls TEXT[],
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Prevent duplicate responses by the same user on the same request
CREATE UNIQUE INDEX IF NOT EXISTS uniq_responses_request_user ON responses(request_id, user_id);

-- Useful filtering indexes
CREATE INDEX IF NOT EXISTS idx_responses_request ON responses(request_id);
CREATE INDEX IF NOT EXISTS idx_responses_user ON responses(user_id);
CREATE INDEX IF NOT EXISTS idx_responses_request_created_at ON responses(request_id, created_at DESC);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION touch_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_responses_updated_at ON responses;
CREATE TRIGGER trg_responses_updated_at
BEFORE UPDATE ON responses
FOR EACH ROW EXECUTE FUNCTION touch_updated_at_column();
