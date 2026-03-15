BEGIN;

-- Viewer's likes subquery in feed: SELECT DISTINCT post_id FROM post_reactions WHERE user_id = ?
-- The existing (post_id, user_id) index does not help for WHERE user_id = ? leading column.
-- This composite index enables an index-only scan for that subquery.
CREATE INDEX IF NOT EXISTS idx_post_reactions_user_post
  ON post_reactions (user_id, post_id);

-- Group/community feed queries: WHERE p.group_id = ? ORDER BY p.id DESC / created_at DESC
CREATE INDEX IF NOT EXISTS idx_posts_group_id_created_at
  ON posts (group_id, created_at DESC);

COMMIT;
