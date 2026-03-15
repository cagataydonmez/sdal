BEGIN;

-- Email lookups (login, activation, profile edit, OAuth) use LOWER(email)
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email));

-- Admin/teacher search by name columns with LOWER + LIKE
CREATE INDEX IF NOT EXISTS idx_users_graduation_year ON users (graduation_year);

-- Posts by user for profile/feed queries
CREATE INDEX IF NOT EXISTS idx_posts_user_id_created_at ON posts (user_id, created_at DESC);

-- Media assets entity lookup (used in feed image resolution)
CREATE INDEX IF NOT EXISTS idx_media_assets_entity ON media_assets (entity_type, entity_id);

COMMIT;
