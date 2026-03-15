BEGIN;

DROP INDEX IF EXISTS idx_post_reactions_user_post;
DROP INDEX IF EXISTS idx_posts_group_id_created_at;

COMMIT;
