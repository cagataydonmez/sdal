BEGIN;

CREATE TABLE IF NOT EXISTS auth_security_settings (
  id INTEGER PRIMARY KEY,
  sms_verification_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT auth_security_settings_singleton_id CHECK (id = 1)
);

INSERT INTO auth_security_settings (id, sms_verification_enabled, updated_at)
VALUES (1, FALSE, NOW())
ON CONFLICT (id) DO NOTHING;

COMMIT;
