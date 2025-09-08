CREATE TABLE IF NOT EXISTS verification_audit_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID,
  subject_type VARCHAR(50),
  subject_id UUID,
  action VARCHAR(50),
  metadata JSONB,
  performed_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_verif_audit_subject ON verification_audit_log(subject_type, subject_id);
CREATE INDEX IF NOT EXISTS idx_verif_audit_action ON verification_audit_log(action);
