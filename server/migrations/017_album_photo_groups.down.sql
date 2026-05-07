BEGIN;

DROP INDEX IF EXISTS idx_album_photos_group_key;

ALTER TABLE album_photos
  DROP COLUMN IF EXISTS album_group_index,
  DROP COLUMN IF EXISTS album_group_key;

COMMIT;
