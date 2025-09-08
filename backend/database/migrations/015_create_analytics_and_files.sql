-- 015_create_analytics_and_files.sql
-- Analytics events + file storage metadata.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  session_id UUID,
  event_name VARCHAR(150) NOT NULL,
  event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source VARCHAR(60),
  context JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_analytics_event_name ON analytics_events(event_name);
CREATE INDEX IF NOT EXISTS idx_analytics_event_time ON analytics_events(event_time DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_user ON analytics_events(user_id);

CREATE TABLE IF NOT EXISTS files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  original_name VARCHAR(255),
  storage_path VARCHAR(500) NOT NULL,
  mime_type VARCHAR(120),
  size_bytes BIGINT,
  purpose VARCHAR(80),
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_files_owner ON files(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_files_purpose ON files(purpose);
