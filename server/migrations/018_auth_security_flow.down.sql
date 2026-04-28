BEGIN;

DROP TABLE IF EXISTS auth_email_challenges;
DROP TABLE IF EXISTS user_security_flags;
DROP TABLE IF EXISTS auth_audit_logs;
DROP TABLE IF EXISTS auth_rate_limits;
DROP TABLE IF EXISTS phone_verification_attempts;
DROP TABLE IF EXISTS trusted_devices;

COMMIT;
