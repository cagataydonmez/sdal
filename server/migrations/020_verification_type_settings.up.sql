CREATE TABLE IF NOT EXISTS verification_type_settings (
  type TEXT PRIMARY KEY,
  verification_required INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL,
  updated_by INTEGER
);

INSERT INTO verification_type_settings (type, verification_required, updated_at)
VALUES ('alumni', 1, CURRENT_TIMESTAMP)
ON CONFLICT(type) DO NOTHING;

INSERT INTO verification_type_settings (type, verification_required, updated_at)
VALUES ('teacher', 1, CURRENT_TIMESTAMP)
ON CONFLICT(type) DO NOTHING;
