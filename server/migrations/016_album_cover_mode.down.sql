BEGIN;

ALTER TABLE album_categories
  DROP COLUMN IF EXISTS cover_mode;

COMMIT;
