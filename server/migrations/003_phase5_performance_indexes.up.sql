BEGIN;

CREATE INDEX IF NOT EXISTS idx_post_comments_post_id_id_desc ON post_comments (post_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_post_reactions_post_user ON post_reactions (post_id, user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_id_desc ON notifications (user_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_conversation_id_id_desc ON conversation_messages (conversation_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_a_updated_desc ON conversations (participant_a_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_b_updated_desc ON conversations (participant_b_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_invites_group_invited_status ON group_invites (group_id, invited_user_id, status);
CREATE INDEX IF NOT EXISTS idx_group_join_requests_user_status_created ON group_join_requests (user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_requests_status_created ON support_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_identity_verification_requests_status_created ON identity_verification_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stories_created_id_desc ON stories (created_at DESC, id DESC);

COMMIT;
