BEGIN;

DROP INDEX IF EXISTS idx_stories_created_id_desc;
DROP INDEX IF EXISTS idx_identity_verification_requests_status_created;
DROP INDEX IF EXISTS idx_support_requests_status_created;
DROP INDEX IF EXISTS idx_group_join_requests_user_status_created;
DROP INDEX IF EXISTS idx_group_invites_group_invited_status;
DROP INDEX IF EXISTS idx_conversations_participant_b_updated_desc;
DROP INDEX IF EXISTS idx_conversations_participant_a_updated_desc;
DROP INDEX IF EXISTS idx_conversation_messages_conversation_id_id_desc;
DROP INDEX IF EXISTS idx_notifications_user_id_id_desc;
DROP INDEX IF EXISTS idx_post_reactions_post_user;
DROP INDEX IF EXISTS idx_post_comments_post_id_id_desc;

COMMIT;
