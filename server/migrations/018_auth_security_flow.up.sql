BEGIN;

CREATE TABLE IF NOT EXISTS trusted_devices (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  device_id_hash TEXT NOT NULL,
  device_name TEXT,
  platform TEXT NOT NULL,
  app_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  trusted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  ip_created_hash TEXT,
  user_agent TEXT,
  device_info JSONB
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_trusted_devices_user_hash_active
  ON trusted_devices (user_id, device_id_hash)
  WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trusted_devices_user ON trusted_devices (user_id);
CREATE INDEX IF NOT EXISTS idx_trusted_devices_hash ON trusted_devices (device_id_hash);

CREATE TABLE IF NOT EXISTS phone_verification_attempts (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT,
  phone_number_hash TEXT NOT NULL,
  ip_hash TEXT,
  device_id_hash TEXT,
  status TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phone_attempts_phone_created ON phone_verification_attempts (phone_number_hash, created_at);
CREATE INDEX IF NOT EXISTS idx_phone_attempts_user_created ON phone_verification_attempts (user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_phone_attempts_ip_created ON phone_verification_attempts (ip_hash, created_at);
CREATE INDEX IF NOT EXISTS idx_phone_attempts_device_created ON phone_verification_attempts (device_id_hash, created_at);

CREATE TABLE IF NOT EXISTS auth_rate_limits (
  id BIGSERIAL PRIMARY KEY,
  scope TEXT NOT NULL,
  key_hash TEXT NOT NULL,
  action TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_scope_key_created ON auth_rate_limits (scope, key_hash, created_at);

CREATE TABLE IF NOT EXISTS auth_audit_logs (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT,
  event_type TEXT NOT NULL,
  risk_level TEXT NOT NULL DEFAULT 'info',
  ip_hash TEXT,
  device_id_hash TEXT,
  phone_number_hash TEXT,
  email_hash TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_audit_logs_event_created ON auth_audit_logs (event_type, created_at);

CREATE TABLE IF NOT EXISTS user_security_flags (
  user_id BIGINT PRIMARY KEY,
  phone_verified_at TIMESTAMPTZ,
  phone_number_hash TEXT,
  phone_verification_required BOOLEAN NOT NULL DEFAULT FALSE,
  manual_review_required BOOLEAN NOT NULL DEFAULT FALSE,
  suspicious_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth_email_challenges (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  device_id_hash TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_email_challenges_user_device
  ON auth_email_challenges (user_id, device_id_hash, created_at);

COMMIT;
