BEGIN;

ALTER TABLE album_photos
  ADD COLUMN IF NOT EXISTS album_group_key TEXT,
  ADD COLUMN IF NOT EXISTS album_group_index INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_album_photos_group_key
  ON album_photos (category_id, album_group_key, album_group_index, id);

COMMIT;
