BEGIN;

DROP INDEX IF EXISTS idx_album_photo_comments_author_user_id;
DROP INDEX IF EXISTS idx_album_photo_likes_photo_id;
DROP INDEX IF EXISTS idx_album_categories_owner_user_id;
DROP INDEX IF EXISTS idx_album_categories_visibility_scope;
DROP INDEX IF EXISTS idx_album_category_permissions_category_group;
DROP INDEX IF EXISTS idx_album_category_permissions_category_user;

DROP TABLE IF EXISTS album_category_permissions;
DROP TABLE IF EXISTS album_photo_likes;

ALTER TABLE album_photo_comments
  DROP COLUMN IF EXISTS updated_at,
  DROP COLUMN IF EXISTS author_user_id;

ALTER TABLE album_photos
  DROP COLUMN IF EXISTS tagged_user_ids_json,
  DROP COLUMN IF EXISTS updated_at,
  DROP COLUMN IF EXISTS allow_comments;

ALTER TABLE album_categories
  DROP COLUMN IF EXISTS cover_file_name,
  DROP COLUMN IF EXISTS is_system_album,
  DROP COLUMN IF EXISTS owner_user_id,
  DROP COLUMN IF EXISTS album_type,
  DROP COLUMN IF EXISTS cohort_year,
  DROP COLUMN IF EXISTS visibility_scope;

COMMIT;
