BEGIN;

CREATE TABLE IF NOT EXISTS language_config (
  id INT PRIMARY KEY DEFAULT 1,
  lang_selection_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  default_lang_open TEXT NOT NULL DEFAULT 'tr',
  default_lang_closed TEXT NOT NULL DEFAULT 'tr',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT language_config_single_row CHECK (id = 1)
);

INSERT INTO language_config (id, lang_selection_enabled, default_lang_open, default_lang_closed)
VALUES (1, TRUE, 'tr', 'tr')
ON CONFLICT (id) DO NOTHING;

COMMIT;
