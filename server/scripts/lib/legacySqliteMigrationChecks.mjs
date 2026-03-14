export const SEQUENCE_TABLES = [
  'users', 'oauth_identities', 'groups', 'support_request_categories', 'email_categories',
  'email_templates', 'board_categories', 'cms_pages', 'album_categories', 'posts', 'post_comments',
  'post_reactions', 'user_follows', 'stories', 'story_views', 'notifications', 'conversations',
  'conversation_members', 'conversation_messages', 'live_chat_messages', 'events', 'event_comments',
  'event_responses', 'announcements', 'jobs', 'group_members', 'group_join_requests', 'group_invites',
  'group_events', 'group_announcements', 'direct_messages', 'board_messages', 'album_photos',
  'album_photo_comments', 'blocked_terms', 'shoutbox_messages', 'snake_scores', 'tetris_scores',
  'tournament_teams', 'identity_verification_requests', 'support_requests', 'email_change_requests',
  'moderation_scopes', 'moderation_permissions', 'audit_logs', 'game_scores'
];

export function fkChecks() {
  return [
    {
      name: 'posts.author_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM posts p LEFT JOIN users u ON u.id = p.author_id WHERE u.id IS NULL'
    },
    {
      name: 'post_comments.post_id -> posts.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM post_comments c LEFT JOIN posts p ON p.id = c.post_id WHERE p.id IS NULL'
    },
    {
      name: 'post_comments.author_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM post_comments c LEFT JOIN users u ON u.id = c.author_id WHERE u.id IS NULL'
    },
    {
      name: 'post_reactions.user_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM post_reactions r LEFT JOIN users u ON u.id = r.user_id WHERE u.id IS NULL'
    },
    {
      name: 'stories.author_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM stories s LEFT JOIN users u ON u.id = s.author_id WHERE u.id IS NULL'
    },
    {
      name: 'conversation_members.user_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM conversation_members m LEFT JOIN users u ON u.id = m.user_id WHERE u.id IS NULL'
    },
    {
      name: 'conversation_messages.conversation_id -> conversations.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM conversation_messages m LEFT JOIN conversations c ON c.id = m.conversation_id WHERE c.id IS NULL'
    },
    {
      name: 'notifications.user_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM notifications n LEFT JOIN users u ON u.id = n.user_id WHERE u.id IS NULL'
    },
    {
      name: 'group_members.group_id -> groups.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM group_members gm LEFT JOIN groups g ON g.id = gm.group_id WHERE g.id IS NULL'
    },
    {
      name: 'direct_messages.sender_id -> users.id',
      sql: 'SELECT COUNT(*)::bigint AS violations FROM direct_messages d LEFT JOIN users u ON u.id = d.sender_id WHERE u.id IS NULL'
    }
  ];
}
