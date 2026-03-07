BEGIN;

DROP INDEX IF EXISTS idx_group_members_user_group;
DROP INDEX IF EXISTS idx_album_photo_comments_photo_id;
DROP INDEX IF EXISTS idx_album_photos_uploader_created_at;
DROP INDEX IF EXISTS idx_album_photos_category_active_created_at;
DROP INDEX IF EXISTS idx_direct_messages_sender_recipient_created_at;
DROP INDEX IF EXISTS idx_direct_messages_sender_visible_created_at;
DROP INDEX IF EXISTS idx_direct_messages_recipient_unread_visible_created_at;

COMMIT;
