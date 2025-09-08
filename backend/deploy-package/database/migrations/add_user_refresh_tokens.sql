-- Stores hashed refresh tokens per user (single active per user constraint)
CREATE TABLE IF NOT EXISTS user_refresh_tokens (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_refresh_tokens_expires ON user_refresh_tokens(expires_at);
