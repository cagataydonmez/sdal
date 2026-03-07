BEGIN;

CREATE INDEX IF NOT EXISTS idx_direct_messages_recipient_unread_visible_created_at
  ON direct_messages (recipient_id, is_unread, recipient_visible, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_direct_messages_sender_visible_created_at
  ON direct_messages (sender_id, sender_visible, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_direct_messages_sender_recipient_created_at
  ON direct_messages (sender_id, recipient_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_album_photos_category_active_created_at
  ON album_photos (category_id, is_active, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_album_photos_uploader_created_at
  ON album_photos (uploaded_by_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_album_photo_comments_photo_id
  ON album_photo_comments (photo_id);

CREATE INDEX IF NOT EXISTS idx_group_members_user_group
  ON group_members (user_id, group_id);

COMMIT;
