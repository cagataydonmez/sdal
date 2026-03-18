BEGIN;

ALTER TABLE site_settings ADD COLUMN IF NOT EXISTS menu_visibility_json TEXT;
ALTER TABLE site_settings ADD COLUMN IF NOT EXISTS menu_order_json TEXT;

COMMIT;
