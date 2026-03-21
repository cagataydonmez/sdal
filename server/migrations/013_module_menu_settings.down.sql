BEGIN;

ALTER TABLE site_settings DROP COLUMN IF EXISTS menu_visibility_json;
ALTER TABLE site_settings DROP COLUMN IF EXISTS menu_order_json;

COMMIT;
