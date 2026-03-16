/**
 * crossDriverTableMappings.mjs — Bidirectional table/column name mappings
 * between PostgreSQL (modern English names) and SQLite (legacy Turkish names).
 *
 * Used by:
 *   - server/src/admin/createDbAdminRuntime.js  (admin panel DB copy)
 *   - server/scripts/db-sync.mjs                (CLI sync tool)
 *
 * Each entry defines:
 *   pgTable     — table name in PostgreSQL
 *   sqliteTable — table name in SQLite
 *   columns     — array of { pg, sqlite } column name pairs
 *
 * Tables where pgTable === sqliteTable have the same name in both databases
 * but may still have different column names.
 */

export function buildCrossDriverTableMappings() {
  return [
    {
      pgTable: 'users',
      sqliteTable: 'uyeler',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'username', sqlite: 'kadi' },
        { pg: 'password_hash', sqlite: 'sifre' },
        { pg: 'first_name', sqlite: 'isim' },
        { pg: 'last_name', sqlite: 'soyisim' },
        { pg: 'activation_token', sqlite: 'aktivasyon' },
        { pg: 'email', sqlite: 'email' },
        { pg: 'is_active', sqlite: 'aktiv' },
        { pg: 'is_banned', sqlite: 'yasak' },
        { pg: 'is_profile_initialized', sqlite: 'ilkbd' },
        { pg: 'website_url', sqlite: 'websitesi' },
        { pg: 'signature', sqlite: 'imza' },
        { pg: 'profession', sqlite: 'meslek' },
        { pg: 'city', sqlite: 'sehir' },
        { pg: 'is_email_hidden', sqlite: 'mailkapali' },
        { pg: 'profile_view_count', sqlite: 'hit' },
        { pg: 'homepage_page_id', sqlite: 'ilksayfa' },
        { pg: 'graduation_year', sqlite: 'mezuniyetyili' },
        { pg: 'university_name', sqlite: 'universite' },
        { pg: 'birth_day', sqlite: 'dogumgun' },
        { pg: 'birth_month', sqlite: 'dogumay' },
        { pg: 'birth_year', sqlite: 'dogumyil' },
        { pg: 'last_activity_date', sqlite: 'sonislemtarih' },
        { pg: 'last_activity_time', sqlite: 'sonislemsaat' },
        { pg: 'is_online', sqlite: 'online' },
        { pg: 'created_at', sqlite: 'ilktarih' },
        { pg: 'last_seen_at', sqlite: 'sontarih' },
        { pg: 'legacy_admin_flag', sqlite: 'admin' },
        { pg: 'last_ip', sqlite: 'sonip' },
        { pg: 'avatar_path', sqlite: 'resim' },
        { pg: 'is_album_admin', sqlite: 'albumadmin' },
        { pg: 'quick_access_ids_json', sqlite: 'hizliliste' },
        { pg: 'legacy_status_last_activity_at', sqlite: 's_sonislem' },
        { pg: 'legacy_status_is_online', sqlite: 's_online' },
        { pg: 'previous_last_seen_at', sqlite: 'oncekisontarih' },
        { pg: 'role', sqlite: 'role' },
        { pg: 'is_verified', sqlite: 'verified' },
        { pg: 'verification_status', sqlite: 'verification_status' },
        { pg: 'privacy_consent_at', sqlite: 'kvkk_consent_at' },
        { pg: 'directory_consent_at', sqlite: 'directory_consent_at' },
        { pg: 'company_name', sqlite: 'sirket' },
        { pg: 'job_title', sqlite: 'unvan' },
        { pg: 'expertise', sqlite: 'uzmanlik' },
        { pg: 'linkedin_url', sqlite: 'linkedin_url' },
        { pg: 'university_department', sqlite: 'universite_bolum' },
        { pg: 'is_mentor_opted_in', sqlite: 'mentor_opt_in' },
        { pg: 'mentor_topics', sqlite: 'mentor_konulari' },
        { pg: 'oauth_provider', sqlite: 'oauth_provider' },
        { pg: 'oauth_subject', sqlite: 'oauth_subject' },
        { pg: 'oauth_email_verified', sqlite: 'oauth_email_verified' },
      ]
    },
    {
      pgTable: 'oauth_identities',
      sqliteTable: 'oauth_accounts',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'provider', sqlite: 'provider' },
        { pg: 'provider_subject', sqlite: 'provider_user_id' },
        { pg: 'email', sqlite: 'email' },
        { pg: 'profile_json', sqlite: 'profile_json' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'site_settings',
      sqliteTable: 'site_controls',
      conflictTarget: 'id',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'site_open', sqlite: 'site_open' },
        { pg: 'maintenance_message', sqlite: 'maintenance_message' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'module_settings',
      sqliteTable: 'module_controls',
      conflictTarget: 'module_key',
      columns: [
        { pg: 'module_key', sqlite: 'module_key' },
        { pg: 'is_open', sqlite: 'is_open' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'media_settings',
      sqliteTable: 'media_settings',
      conflictTarget: 'id',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'storage_provider', sqlite: 'storage_provider' },
        { pg: 'local_base_path', sqlite: 'local_base_path' },
        { pg: 'thumb_width', sqlite: 'thumb_width' },
        { pg: 'feed_width', sqlite: 'feed_width' },
        { pg: 'full_width', sqlite: 'full_width' },
        { pg: 'webp_quality', sqlite: 'webp_quality' },
        { pg: 'max_upload_bytes', sqlite: 'max_upload_bytes' },
        { pg: 'avif_enabled', sqlite: 'avif_enabled' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      // SQLite uses 'label'/'is_enabled' where PG uses 'name'/'enabled'
      pgTable: 'engagement_variants',
      sqliteTable: 'engagement_ab_config',
      conflictTarget: 'variant',
      columns: [
        { pg: 'variant', sqlite: 'variant' },
        { pg: 'name', sqlite: 'label' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'enabled', sqlite: 'is_enabled' },
        { pg: 'params_json', sqlite: 'params_json' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'support_request_categories',
      sqliteTable: 'request_categories',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'category_key', sqlite: 'category_key' },
        { pg: 'label', sqlite: 'label' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'is_active', sqlite: 'active' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'email_categories',
      sqliteTable: 'email_kategori',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'name', sqlite: 'ad' },
        { pg: 'type', sqlite: 'tur' },
        { pg: 'value', sqlite: 'deger' },
        { pg: 'description', sqlite: 'aciklama' },
      ]
    },
    {
      pgTable: 'email_templates',
      sqliteTable: 'email_sablon',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'name', sqlite: 'ad' },
        { pg: 'subject', sqlite: 'konu' },
        { pg: 'body_html', sqlite: 'icerik' },
        { pg: 'created_at', sqlite: 'olusturma' },
      ]
    },
    {
      pgTable: 'board_categories',
      sqliteTable: 'mesaj_kategori',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'name', sqlite: 'kategoriadi' },
        { pg: 'description', sqlite: 'aciklama' },
      ]
    },
    {
      pgTable: 'cms_pages',
      sqliteTable: 'sayfalar',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'name', sqlite: 'sayfaismi' },
        { pg: 'slug', sqlite: 'sayfaurl' },
        { pg: 'view_count', sqlite: 'hit' },
        { pg: 'last_viewed_at', sqlite: 'sontarih' },
        { pg: 'last_editor_username', sqlite: 'sonuye' },
        { pg: 'parent_page_id', sqlite: 'babaid' },
        { pg: 'is_visible_in_menu', sqlite: 'menugorun' },
        { pg: 'is_redirect', sqlite: 'yonlendir' },
        { pg: 'body_html', sqlite: 'sayfametin' },
        { pg: 'layout_option', sqlite: 'mozellik' },
        { pg: 'image_url', sqlite: 'resim' },
        { pg: 'last_editor_ip', sqlite: 'sonip' },
      ]
    },
    {
      pgTable: 'album_categories',
      sqliteTable: 'album_kat',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'name', sqlite: 'kategori' },
        { pg: 'description', sqlite: 'aciklama' },
        { pg: 'created_at', sqlite: 'ilktarih' },
        { pg: 'last_upload_at', sqlite: 'sonekleme' },
        { pg: 'last_uploaded_by_user_id', sqlite: 'sonekleyen' },
        { pg: 'is_active', sqlite: 'aktif' },
      ]
    },
    {
      pgTable: 'media_assets',
      sqliteTable: 'image_records',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'entity_type', sqlite: 'entity_type' },
        { pg: 'entity_id', sqlite: 'entity_id' },
        { pg: 'provider', sqlite: 'provider' },
        { pg: 'thumb_path', sqlite: 'thumb_path' },
        { pg: 'feed_path', sqlite: 'feed_path' },
        { pg: 'full_path', sqlite: 'full_path' },
        { pg: 'width', sqlite: 'width' },
        { pg: 'height', sqlite: 'height' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'posts',
      sqliteTable: 'posts',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'author_id', sqlite: 'user_id' },
        { pg: 'content', sqlite: 'content' },
        { pg: 'image_url', sqlite: 'image' },
        { pg: 'media_asset_id', sqlite: 'image_record_id' },
        { pg: 'group_id', sqlite: 'group_id' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'post_comments',
      sqliteTable: 'post_comments',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'post_id', sqlite: 'post_id' },
        { pg: 'author_id', sqlite: 'user_id' },
        { pg: 'body', sqlite: 'comment' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'post_reactions',
      sqliteTable: 'post_likes',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'post_id', sqlite: 'post_id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'user_follows',
      sqliteTable: 'follows',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'follower_id', sqlite: 'follower_id' },
        { pg: 'following_id', sqlite: 'following_id' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'stories',
      sqliteTable: 'stories',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'author_id', sqlite: 'user_id' },
        { pg: 'image_url', sqlite: 'image' },
        { pg: 'media_asset_id', sqlite: 'image_record_id' },
        { pg: 'caption', sqlite: 'caption' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'expires_at', sqlite: 'expires_at' },
      ]
    },
    {
      pgTable: 'story_views',
      sqliteTable: 'story_views',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'story_id', sqlite: 'story_id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'notifications',
      sqliteTable: 'notifications',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'type', sqlite: 'type' },
        { pg: 'source_user_id', sqlite: 'source_user_id' },
        { pg: 'entity_id', sqlite: 'entity_id' },
        { pg: 'message', sqlite: 'message' },
        { pg: 'read_at', sqlite: 'read_at' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'conversations',
      sqliteTable: 'sdal_messenger_threads',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'participant_a_id', sqlite: 'user_a_id' },
        { pg: 'participant_b_id', sqlite: 'user_b_id' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
        { pg: 'last_message_at', sqlite: 'last_message_at' },
      ]
    },
    {
      pgTable: 'conversation_messages',
      sqliteTable: 'sdal_messenger_messages',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'conversation_id', sqlite: 'thread_id' },
        { pg: 'sender_id', sqlite: 'sender_id' },
        { pg: 'recipient_id', sqlite: 'receiver_id' },
        { pg: 'body', sqlite: 'body' },
        { pg: 'client_written_at', sqlite: 'client_written_at' },
        { pg: 'server_received_at', sqlite: 'server_received_at' },
        { pg: 'delivered_at', sqlite: 'delivered_at' },
        { pg: 'read_at', sqlite: 'read_at' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'deleted_by_sender', sqlite: 'deleted_by_sender' },
        { pg: 'deleted_by_recipient', sqlite: 'deleted_by_receiver' },
      ]
    },
    {
      pgTable: 'live_chat_messages',
      sqliteTable: 'chat_messages',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'body', sqlite: 'message' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'events',
      sqliteTable: 'events',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'title', sqlite: 'title' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'location', sqlite: 'location' },
        { pg: 'starts_at', sqlite: 'starts_at' },
        { pg: 'ends_at', sqlite: 'ends_at' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'created_by', sqlite: 'created_by' },
        { pg: 'approved', sqlite: 'approved' },
        { pg: 'approved_by', sqlite: 'approved_by' },
        { pg: 'approved_at', sqlite: 'approved_at' },
        { pg: 'image_url', sqlite: 'image' },
        { pg: 'show_response_counts', sqlite: 'show_response_counts' },
        { pg: 'show_attendee_names', sqlite: 'show_attendee_names' },
        { pg: 'show_decliner_names', sqlite: 'show_decliner_names' },
      ]
    },
    {
      pgTable: 'event_comments',
      sqliteTable: 'event_comments',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'event_id', sqlite: 'event_id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'comment_body', sqlite: 'comment' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'event_responses',
      sqliteTable: 'event_responses',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'event_id', sqlite: 'event_id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'response', sqlite: 'response' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'announcements',
      sqliteTable: 'announcements',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'title', sqlite: 'title' },
        { pg: 'body', sqlite: 'body' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'created_by', sqlite: 'created_by' },
        { pg: 'approved', sqlite: 'approved' },
        { pg: 'approved_by', sqlite: 'approved_by' },
        { pg: 'approved_at', sqlite: 'approved_at' },
        { pg: 'image_url', sqlite: 'image' },
      ]
    },
    {
      pgTable: 'jobs',
      sqliteTable: 'jobs',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'poster_id', sqlite: 'poster_id' },
        { pg: 'company', sqlite: 'company' },
        { pg: 'title', sqlite: 'title' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'location', sqlite: 'location' },
        { pg: 'job_type', sqlite: 'job_type' },
        { pg: 'link', sqlite: 'link' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      // SQLite uses 'image'/'privacy' where PG uses 'cover_image_url'/'visibility'
      pgTable: 'groups',
      sqliteTable: 'groups',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'name', sqlite: 'name' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'cover_image_url', sqlite: 'image' },
        { pg: 'owner_id', sqlite: 'owner_id' },
        { pg: 'visibility', sqlite: 'privacy' },
        { pg: 'show_contact_hint', sqlite: 'show_contact_hint' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'group_members',
      sqliteTable: 'group_members',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'group_id', sqlite: 'group_id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'role', sqlite: 'role' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'group_join_requests',
      sqliteTable: 'group_join_requests',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'group_id', sqlite: 'group_id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'reviewed_at', sqlite: 'reviewed_at' },
        { pg: 'reviewed_by', sqlite: 'reviewed_by' },
      ]
    },
    {
      pgTable: 'group_invites',
      sqliteTable: 'group_invites',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'group_id', sqlite: 'group_id' },
        { pg: 'invited_user_id', sqlite: 'invited_user_id' },
        { pg: 'invited_by', sqlite: 'invited_by' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'responded_at', sqlite: 'responded_at' },
      ]
    },
    {
      pgTable: 'group_events',
      sqliteTable: 'group_events',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'group_id', sqlite: 'group_id' },
        { pg: 'title', sqlite: 'title' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'location', sqlite: 'location' },
        { pg: 'starts_at', sqlite: 'starts_at' },
        { pg: 'ends_at', sqlite: 'ends_at' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'created_by', sqlite: 'created_by' },
      ]
    },
    {
      pgTable: 'group_announcements',
      sqliteTable: 'group_announcements',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'group_id', sqlite: 'group_id' },
        { pg: 'title', sqlite: 'title' },
        { pg: 'body', sqlite: 'body' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'created_by', sqlite: 'created_by' },
      ]
    },
    {
      pgTable: 'direct_messages',
      sqliteTable: 'gelenkutusu',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'recipient_id', sqlite: 'kime' },
        { pg: 'sender_id', sqlite: 'kimden' },
        { pg: 'recipient_visible', sqlite: 'aktifgelen' },
        { pg: 'subject', sqlite: 'konu' },
        { pg: 'body_html', sqlite: 'mesaj' },
        { pg: 'is_unread', sqlite: 'yeni' },
        { pg: 'created_at', sqlite: 'tarih' },
        { pg: 'sender_visible', sqlite: 'aktifgiden' },
      ]
    },
    {
      pgTable: 'board_messages',
      sqliteTable: 'mesaj',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'author_user_id', sqlite: 'gonderenid' },
        { pg: 'body_html', sqlite: 'mesaj' },
        { pg: 'category_id', sqlite: 'kategori' },
        { pg: 'created_at', sqlite: 'tarih' },
      ]
    },
    {
      pgTable: 'album_photos',
      sqliteTable: 'album_foto',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'category_id', sqlite: 'katid' },
        { pg: 'file_name', sqlite: 'dosyaadi' },
        { pg: 'title', sqlite: 'baslik' },
        { pg: 'description', sqlite: 'aciklama' },
        { pg: 'is_active', sqlite: 'aktif' },
        { pg: 'uploaded_by_user_id', sqlite: 'ekleyenid' },
        { pg: 'created_at', sqlite: 'tarih' },
        { pg: 'view_count', sqlite: 'hit' },
      ]
    },
    {
      pgTable: 'album_photo_comments',
      sqliteTable: 'album_fotoyorum',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'photo_id', sqlite: 'fotoid' },
        { pg: 'author_username', sqlite: 'uyeadi' },
        { pg: 'comment_body', sqlite: 'yorum' },
        { pg: 'created_at', sqlite: 'tarih' },
      ]
    },
    {
      pgTable: 'blocked_terms',
      sqliteTable: 'filtre',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'term', sqlite: 'kufur' },
      ]
    },
    {
      pgTable: 'shoutbox_messages',
      sqliteTable: 'hmes',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'username', sqlite: 'kadi' },
        { pg: 'message_body', sqlite: 'metin' },
        { pg: 'created_at', sqlite: 'tarih' },
      ]
    },
    {
      pgTable: 'snake_scores',
      sqliteTable: 'oyun_yilan',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'username', sqlite: 'isim' },
        { pg: 'score', sqlite: 'skor' },
        { pg: 'created_at', sqlite: 'tarih' },
      ]
    },
    {
      pgTable: 'tetris_scores',
      sqliteTable: 'oyun_tetris',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'username', sqlite: 'isim' },
        { pg: 'score', sqlite: 'puan' },
        { pg: 'level', sqlite: 'seviye' },
        { pg: 'lines', sqlite: 'satir' },
        { pg: 'created_at', sqlite: 'tarih' },
      ]
    },
    {
      pgTable: 'tournament_teams',
      sqliteTable: 'takimlar',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'team_name', sqlite: 'tisim' },
        { pg: 'team_category_id', sqlite: 'tkid' },
        { pg: 'team_phone', sqlite: 'tktelefon' },
        { pg: 'captain_name', sqlite: 'boyismi' },
        { pg: 'captain_graduation_year', sqlite: 'boymezuniyet' },
        { pg: 'player1_name', sqlite: 'ioyismi' },
        { pg: 'player1_graduation_year', sqlite: 'ioymezuniyet' },
        { pg: 'player2_name', sqlite: 'uoyismi' },
        { pg: 'player2_graduation_year', sqlite: 'uoymezuniyet' },
        { pg: 'player3_name', sqlite: 'doyismi' },
        { pg: 'player3_graduation_year', sqlite: 'doymezuniyet' },
        { pg: 'created_at', sqlite: 'tarih' },
      ]
    },
    {
      pgTable: 'identity_verification_requests',
      sqliteTable: 'verification_requests',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'proof_path', sqlite: 'proof_path' },
        { pg: 'proof_media_asset_id', sqlite: 'proof_image_record_id' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'reviewed_at', sqlite: 'reviewed_at' },
        { pg: 'reviewer_id', sqlite: 'reviewer_id' },
      ]
    },
    {
      pgTable: 'support_requests',
      sqliteTable: 'member_requests',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'category_key', sqlite: 'category_key' },
        { pg: 'payload_json', sqlite: 'payload_json' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'reviewed_at', sqlite: 'reviewed_at' },
        { pg: 'reviewer_id', sqlite: 'reviewer_id' },
        { pg: 'resolution_note', sqlite: 'resolution_note' },
      ]
    },
    {
      pgTable: 'email_change_requests',
      sqliteTable: 'email_change_requests',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'current_email', sqlite: 'current_email' },
        { pg: 'new_email', sqlite: 'new_email' },
        { pg: 'token', sqlite: 'token' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'expires_at', sqlite: 'expires_at' },
        { pg: 'verified_at', sqlite: 'verified_at' },
        { pg: 'ip', sqlite: 'ip' },
        { pg: 'user_agent', sqlite: 'user_agent' },
      ]
    },
    {
      pgTable: 'moderation_scopes',
      sqliteTable: 'moderator_scopes',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'scope_type', sqlite: 'scope_type' },
        { pg: 'scope_value', sqlite: 'scope_value' },
        { pg: 'graduation_year', sqlite: 'graduation_year' },
        { pg: 'created_by', sqlite: 'created_by' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'moderation_permissions',
      sqliteTable: 'moderator_permissions',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'permission_key', sqlite: 'permission_key' },
        { pg: 'enabled', sqlite: 'enabled' },
        { pg: 'created_by', sqlite: 'created_by' },
        { pg: 'updated_by', sqlite: 'updated_by' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'audit_logs',
      sqliteTable: 'audit_log',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'actor_user_id', sqlite: 'actor_user_id' },
        { pg: 'action', sqlite: 'action' },
        { pg: 'target_type', sqlite: 'target_type' },
        { pg: 'target_id', sqlite: 'target_id' },
        { pg: 'metadata', sqlite: 'metadata' },
        { pg: 'ip', sqlite: 'ip' },
        { pg: 'user_agent', sqlite: 'user_agent' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'engagement_variant_assignments',
      sqliteTable: 'engagement_ab_assignments',
      columns: [
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'variant', sqlite: 'variant' },
        { pg: 'assigned_at', sqlite: 'assigned_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'user_engagement_scores',
      sqliteTable: 'member_engagement_scores',
      columns: [
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'ab_variant', sqlite: 'ab_variant' },
        { pg: 'score', sqlite: 'score' },
        { pg: 'raw_score', sqlite: 'raw_score' },
        { pg: 'creator_score', sqlite: 'creator_score' },
        { pg: 'engagement_received_score', sqlite: 'engagement_received_score' },
        { pg: 'community_score', sqlite: 'community_score' },
        { pg: 'network_score', sqlite: 'network_score' },
        { pg: 'quality_score', sqlite: 'quality_score' },
        { pg: 'penalty_score', sqlite: 'penalty_score' },
        { pg: 'posts_30d', sqlite: 'posts_30d' },
        { pg: 'posts_7d', sqlite: 'posts_7d' },
        { pg: 'likes_received_30d', sqlite: 'likes_received_30d' },
        { pg: 'comments_received_30d', sqlite: 'comments_received_30d' },
        { pg: 'likes_given_30d', sqlite: 'likes_given_30d' },
        { pg: 'comments_given_30d', sqlite: 'comments_given_30d' },
        { pg: 'followers_count', sqlite: 'followers_count' },
        { pg: 'following_count', sqlite: 'following_count' },
        { pg: 'follows_gained_30d', sqlite: 'follows_gained_30d' },
        { pg: 'follows_given_30d', sqlite: 'follows_given_30d' },
        { pg: 'stories_30d', sqlite: 'stories_30d' },
        { pg: 'story_views_received_30d', sqlite: 'story_views_received_30d' },
        { pg: 'chat_messages_30d', sqlite: 'chat_messages_30d' },
        { pg: 'last_activity_at', sqlite: 'last_activity_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'game_scores',
      sqliteTable: 'game_scores',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'game_key', sqlite: 'game_key' },
        { pg: 'name', sqlite: 'name' },
        { pg: 'score', sqlite: 'score' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'connection_requests',
      sqliteTable: 'connection_requests',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'sender_id', sqlite: 'sender_id' },
        { pg: 'receiver_id', sqlite: 'receiver_id' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'message', sqlite: 'message' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'responded_at', sqlite: 'responded_at' },
      ]
    },
    // Runtime-created tables (same names in both drivers)
    {
      pgTable: 'job_applications',
      sqliteTable: 'job_applications',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'job_id', sqlite: 'job_id' },
        { pg: 'applicant_id', sqlite: 'applicant_id' },
        { pg: 'cover_letter', sqlite: 'cover_letter' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'mentorship_requests',
      sqliteTable: 'mentorship_requests',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'requester_id', sqlite: 'requester_id' },
        { pg: 'mentor_id', sqlite: 'mentor_id' },
        { pg: 'focus_area', sqlite: 'focus_area' },
        { pg: 'message', sqlite: 'message' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'responded_at', sqlite: 'responded_at' },
      ]
    },
    {
      // Runtime-created table (createNotificationGovernanceRuntime) — same schema in both drivers
      pgTable: 'notification_user_preferences',
      sqliteTable: 'notification_user_preferences',
      columns: [
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'social_enabled', sqlite: 'social_enabled' },
        { pg: 'messaging_enabled', sqlite: 'messaging_enabled' },
        { pg: 'groups_enabled', sqlite: 'groups_enabled' },
        { pg: 'events_enabled', sqlite: 'events_enabled' },
        { pg: 'networking_enabled', sqlite: 'networking_enabled' },
        { pg: 'jobs_enabled', sqlite: 'jobs_enabled' },
        { pg: 'system_enabled', sqlite: 'system_enabled' },
        { pg: 'quiet_mode_enabled', sqlite: 'quiet_mode_enabled' },
        { pg: 'quiet_mode_start', sqlite: 'quiet_mode_start' },
        { pg: 'quiet_mode_end', sqlite: 'quiet_mode_end' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    // Runtime-created tables with same name and schema in both drivers
    {
      pgTable: 'notification_experiment_configs',
      sqliteTable: 'notification_experiment_configs',
      conflictTarget: 'experiment_key',
      columns: [
        { pg: 'experiment_key', sqlite: 'experiment_key' },
        { pg: 'label', sqlite: 'label' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'variants_json', sqlite: 'variants_json' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'notification_delivery_audit',
      sqliteTable: 'notification_delivery_audit',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'notification_id', sqlite: 'notification_id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'source_user_id', sqlite: 'source_user_id' },
        { pg: 'entity_id', sqlite: 'entity_id' },
        { pg: 'notification_type', sqlite: 'notification_type' },
        { pg: 'delivery_status', sqlite: 'delivery_status' },
        { pg: 'skip_reason', sqlite: 'skip_reason' },
        { pg: 'error_message', sqlite: 'error_message' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'notification_telemetry_events',
      sqliteTable: 'notification_telemetry_events',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'notification_id', sqlite: 'notification_id' },
        { pg: 'event_name', sqlite: 'event_name' },
        { pg: 'notification_type', sqlite: 'notification_type' },
        { pg: 'surface', sqlite: 'surface' },
        { pg: 'action_kind', sqlite: 'action_kind' },
        { pg: 'created_at', sqlite: 'created_at' },
      ]
    },
    {
      pgTable: 'network_suggestion_ab_config',
      sqliteTable: 'network_suggestion_ab_config',
      conflictTarget: 'variant',
      columns: [
        { pg: 'variant', sqlite: 'variant' },
        { pg: 'name', sqlite: 'name' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'traffic_pct', sqlite: 'traffic_pct' },
        { pg: 'enabled', sqlite: 'enabled' },
        { pg: 'params_json', sqlite: 'params_json' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'network_suggestion_ab_assignments',
      sqliteTable: 'network_suggestion_ab_assignments',
      columns: [
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'variant', sqlite: 'variant' },
        { pg: 'assigned_at', sqlite: 'assigned_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'network_suggestion_ab_change_log',
      sqliteTable: 'network_suggestion_ab_change_log',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'action_type', sqlite: 'action_type' },
        { pg: 'related_change_id', sqlite: 'related_change_id' },
        { pg: 'actor_user_id', sqlite: 'actor_user_id' },
        { pg: 'recommendation_index', sqlite: 'recommendation_index' },
        { pg: 'cohort', sqlite: 'cohort' },
        { pg: 'window_days', sqlite: 'window_days' },
        { pg: 'payload_json', sqlite: 'payload_json' },
        { pg: 'before_snapshot_json', sqlite: 'before_snapshot_json' },
        { pg: 'after_snapshot_json', sqlite: 'after_snapshot_json' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'rolled_back_at', sqlite: 'rolled_back_at' },
        { pg: 'rollback_change_id', sqlite: 'rollback_change_id' },
      ]
    },
  ];
}
