BEGIN;

DROP INDEX IF EXISTS idx_users_email_lower;
DROP INDEX IF EXISTS idx_users_graduation_year;
DROP INDEX IF EXISTS idx_posts_user_id_created_at;
DROP INDEX IF EXISTS idx_media_assets_entity;

COMMIT;
