BEGIN;

DROP VIEW IF EXISTS audit_log;
DROP VIEW IF EXISTS takimlar;
DROP VIEW IF EXISTS oyun_tetris;
DROP VIEW IF EXISTS oyun_yilan;
DROP VIEW IF EXISTS hmes;
DROP VIEW IF EXISTS filtre;
DROP VIEW IF EXISTS album_fotoyorum;
DROP VIEW IF EXISTS album_foto;
DROP VIEW IF EXISTS album_kat;
DROP VIEW IF EXISTS sayfalar;
DROP VIEW IF EXISTS email_sablon;
DROP VIEW IF EXISTS email_kategori;
DROP VIEW IF EXISTS mesaj;
DROP VIEW IF EXISTS mesaj_kategori;
DROP VIEW IF EXISTS gelenkutusu;
DROP VIEW IF EXISTS sdal_messenger_messages;
DROP VIEW IF EXISTS sdal_messenger_threads;
DROP VIEW IF EXISTS member_engagement_scores;
DROP VIEW IF EXISTS engagement_ab_assignments;
DROP VIEW IF EXISTS moderator_permissions;
DROP VIEW IF EXISTS moderator_scopes;
DROP VIEW IF EXISTS image_records;
DROP VIEW IF EXISTS chat_messages;
DROP VIEW IF EXISTS post_likes;
DROP VIEW IF EXISTS follows;
DROP VIEW IF EXISTS verification_requests;
DROP VIEW IF EXISTS member_requests;
DROP VIEW IF EXISTS request_categories;
DROP VIEW IF EXISTS engagement_ab_config;
DROP VIEW IF EXISTS module_controls;
DROP VIEW IF EXISTS site_controls;
DROP VIEW IF EXISTS oauth_accounts;
DROP VIEW IF EXISTS uyeler;

DROP TRIGGER IF EXISTS trg_sync_event_comments_legacy_columns ON event_comments;
DROP TRIGGER IF EXISTS trg_sync_announcements_legacy_columns ON announcements;
DROP TRIGGER IF EXISTS trg_sync_events_legacy_columns ON events;
DROP TRIGGER IF EXISTS trg_sync_groups_legacy_columns ON groups;
DROP TRIGGER IF EXISTS trg_sync_stories_legacy_columns ON stories;
DROP TRIGGER IF EXISTS trg_sync_post_comments_legacy_columns ON post_comments;
DROP TRIGGER IF EXISTS trg_sync_posts_legacy_columns ON posts;

DROP FUNCTION IF EXISTS sync_event_comments_legacy_columns();
DROP FUNCTION IF EXISTS sync_announcements_legacy_columns();
DROP FUNCTION IF EXISTS sync_events_legacy_columns();
DROP FUNCTION IF EXISTS sync_groups_legacy_columns();
DROP FUNCTION IF EXISTS sync_stories_legacy_columns();
DROP FUNCTION IF EXISTS sync_post_comments_legacy_columns();
DROP FUNCTION IF EXISTS sync_posts_legacy_columns();

DROP FUNCTION IF EXISTS legacy_int8_to_bool(BIGINT);
DROP FUNCTION IF EXISTS legacy_int4_to_bool(INTEGER);
DROP FUNCTION IF EXISTS legacy_int2_to_bool(SMALLINT);

COMMIT;
