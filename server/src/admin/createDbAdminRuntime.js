import fs from 'fs';
import path from 'path';
import Database from 'better-sqlite3';
import crypto from 'crypto';
import { execFileSync } from 'child_process';
import { buildCrossDriverTableMappings } from '../../scripts/lib/crossDriverTableMappings.mjs';

// Table/column mappings: see scripts/lib/crossDriverTableMappings.mjs
// (imported as buildCrossDriverTableMappings above)

const _DEAD_BLOCK_PLACEHOLDER = [
    {
      pgTable: '_removed_inline_mappings_see_crossDriverTableMappings_mjs_',
      sqliteTable: '_removed_',
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
      columns: [
        { pg: 'module_key', sqlite: 'module_key' },
        { pg: 'is_open', sqlite: 'is_open' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'media_settings',
      sqliteTable: 'media_settings',
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
      pgTable: 'engagement_variants',
      sqliteTable: 'engagement_ab_config',
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
      pgTable: 'groups',
      sqliteTable: 'groups',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'name', sqlite: 'name' },
        { pg: 'description', sqlite: 'description' },
        { pg: 'cover_image_url', sqlite: 'cover_image' },
        { pg: 'owner_id', sqlite: 'owner_id' },
        { pg: 'visibility', sqlite: 'visibility' },
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
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'cover_letter', sqlite: 'cover_letter' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
    {
      pgTable: 'mentorship_requests',
      sqliteTable: 'mentorship_requests',
      columns: [
        { pg: 'id', sqlite: 'id' },
        { pg: 'mentee_id', sqlite: 'mentee_id' },
        { pg: 'mentor_id', sqlite: 'mentor_id' },
        { pg: 'topic', sqlite: 'topic' },
        { pg: 'message', sqlite: 'message' },
        { pg: 'status', sqlite: 'status' },
        { pg: 'created_at', sqlite: 'created_at' },
        { pg: 'responded_at', sqlite: 'responded_at' },
      ]
    },
    {
      pgTable: 'notification_user_preferences',
      sqliteTable: 'notification_user_preferences',
      columns: [
        { pg: 'user_id', sqlite: 'user_id' },
        { pg: 'channel', sqlite: 'channel' },
        { pg: 'category', sqlite: 'category' },
        { pg: 'enabled', sqlite: 'enabled' },
        { pg: 'updated_at', sqlite: 'updated_at' },
      ]
    },
  ];

// Convert a PostgreSQL value to SQLite-compatible format
function sqliteValueFromPg(val, pgType) {
  if (val === null || val === undefined) return null;
  const t = String(pgType || '').toLowerCase();
  if (t === 'boolean' || t === 'bool') return val ? 1 : 0;
  if (val instanceof Date) return val.toISOString();
  if (t === 'json' || t === 'jsonb') return typeof val === 'string' ? val : JSON.stringify(val);
  if (Array.isArray(val)) return JSON.stringify(val);
  if (typeof val === 'object') return JSON.stringify(val);
  return val;
}

// Convert a SQLite value to PostgreSQL-compatible format
function pgValueFromSqlite(val, pgType) {
  if (val === null || val === undefined) return null;
  const t = String(pgType || '').toLowerCase();
  if (t === 'boolean' || t === 'bool') {
    if (typeof val === 'number') return val !== 0;
    if (typeof val === 'string') return val === '1' || val.toLowerCase() === 'true';
    return Boolean(val);
  }
  if (t === 'json' || t === 'jsonb') {
    if (typeof val === 'string') { try { return JSON.parse(val); } catch { return val; } }
    return val;
  }
  return val;
}

export function createDbAdminRuntime({
  appRootDir,
  dbDriver,
  dbPath,
  getDb,
  closeDbConnection,
  resetDbConnection,
  checkPostgresHealth,
  pgQuery,
  getPgPool,
  writeAppLog
}) {
  const isPostgresDb = dbDriver === 'postgres';
  const dbBackupIncomingDir = path.resolve(appRootDir, '../tmp/db-backup-upload');
  if (!fs.existsSync(dbBackupIncomingDir)) {
    fs.mkdirSync(dbBackupIncomingDir, { recursive: true });
  }

  const dbBackupDir = path.join(path.dirname(dbPath), 'backups');
  if (!fs.existsSync(dbBackupDir)) {
    fs.mkdirSync(dbBackupDir, { recursive: true });
  }

  const DB_DRIVER_SET = new Set(['sqlite', 'postgres']);
  const dbDriverSwitchEnvFile = (() => {
    const fromEnv = String(process.env.SDAL_DB_SWITCH_ENV_FILE || '').trim();
    return path.resolve(fromEnv || '/etc/sdal/sdal.env');
  })();
  const dbDriverSwitchChallengeTtlMs = (() => {
    const parsed = Number.parseInt(String(process.env.SDAL_DB_SWITCH_CHALLENGE_TTL_MS || ''), 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 2 * 60 * 1000;
  })();
  const dbDriverSwitchRestartDelayMs = (() => {
    const parsed = Number.parseInt(String(process.env.SDAL_DB_SWITCH_RESTART_DELAY_MS || ''), 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 1200;
  })();
  const dbDriverSwitchRestartCommand = String(process.env.SDAL_DB_SWITCH_RESTART_CMD || '').trim();
  const dbDriverSwitchChallenges = new Map();
  const dbDriverSwitchState = {
    inProgress: false,
    lastAttemptAt: null,
    lastSuccessAt: null,
    lastError: null,
    lastSwitch: null
  };

  function backupTimestamp(date = new Date()) {
    const pad = (n) => String(n).padStart(2, '0');
    return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}-${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
  }

  function normalizeBackupName(value) {
    const base = path.basename(String(value || ''));
    const safe = base.replace(/[^a-zA-Z0-9._-]/g, '_');
    if (!safe) return '';
    if (isPostgresDb) {
      if (!/\.(dump|sql|backup)$/i.test(safe)) return `${safe}.dump`;
      return safe;
    }
    if (!safe.endsWith('.sqlite')) return `${safe}.sqlite`;
    return safe;
  }

  function resolveBackupPath(fileName) {
    const safeName = normalizeBackupName(fileName);
    if (!safeName) return null;
    return path.join(dbBackupDir, safeName);
  }

  function isSqliteHeader(buffer) {
    if (!buffer || buffer.length < 16) return false;
    const signature = Buffer.from('SQLite format 3\u0000', 'utf-8');
    return buffer.subarray(0, 16).equals(signature);
  }

  function isSqliteFile(filePath) {
    if (!filePath || !fs.existsSync(filePath)) return false;
    const fd = fs.openSync(filePath, 'r');
    try {
      const header = Buffer.alloc(16);
      const bytes = fs.readSync(fd, header, 0, 16, 0);
      if (bytes < 16) return false;
      return isSqliteHeader(header);
    } finally {
      fs.closeSync(fd);
    }
  }

  function listDbBackups() {
    if (!fs.existsSync(dbBackupDir)) return [];
    const backupExtPattern = isPostgresDb ? /\.(dump|sql|backup)$/i : /\.(sqlite|db|backup|bak)$/i;
    return fs.readdirSync(dbBackupDir)
      .filter((name) => backupExtPattern.test(name))
      .map((name) => {
        const fullPath = path.join(dbBackupDir, name);
        const st = fs.statSync(fullPath);
        return {
          name,
          size: st.size,
          mtime: st.mtime.toISOString()
        };
      })
      .sort((a, b) => new Date(b.mtime).getTime() - new Date(a.mtime).getTime());
  }

  async function createDbBackup(label = 'manual') {
    const safeLabel = String(label || 'manual').replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 32) || 'manual';
    if (isPostgresDb) {
      const databaseUrl = String(process.env.DATABASE_URL || '').trim();
      if (!databaseUrl) throw new Error('DATABASE_URL eksik. PostgreSQL yedeği alınamadı.');
      const name = `sdal-backup-${backupTimestamp()}-${safeLabel}.dump`;
      const fullPath = path.join(dbBackupDir, name);
      execFileSync('pg_dump', ['--format=custom', '--file', fullPath, databaseUrl], { stdio: 'pipe' });
      const st = fs.statSync(fullPath);
      return {
        name,
        size: st.size,
        mtime: st.mtime.toISOString()
      };
    }

    const name = `sdal-backup-${backupTimestamp()}-${safeLabel}.sqlite`;
    const fullPath = path.join(dbBackupDir, name);
    const db = getDb();
    try {
      db.pragma('wal_checkpoint(FULL)');
    } catch {
      // no-op
    }
    await db.backup(fullPath);
    const st = fs.statSync(fullPath);
    return {
      name,
      size: st.size,
      mtime: st.mtime.toISOString()
    };
  }

  function restoreDbFromUploadedFile(incomingPath) {
    if (isPostgresDb) {
      const databaseUrl = String(process.env.DATABASE_URL || '').trim();
      if (!databaseUrl) throw new Error('DATABASE_URL eksik. PostgreSQL geri yükleme yapılamadı.');
      const stamp = backupTimestamp();
      const uploadedName = `uploaded-${stamp}.dump`;
      const uploadedPath = path.join(dbBackupDir, uploadedName);
      fs.copyFileSync(incomingPath, uploadedPath);

      const preRestoreName = `pre-restore-${stamp}.dump`;
      const preRestorePath = path.join(dbBackupDir, preRestoreName);
      execFileSync('pg_dump', ['--format=custom', '--file', preRestorePath, databaseUrl], { stdio: 'pipe' });

      try {
        execFileSync(
          'pg_restore',
          ['--clean', '--if-exists', '--no-owner', '--no-privileges', '--dbname', databaseUrl, uploadedPath],
          { stdio: 'pipe' }
        );
      } catch (err) {
        try {
          execFileSync(
            'pg_restore',
            ['--clean', '--if-exists', '--no-owner', '--no-privileges', '--dbname', databaseUrl, preRestorePath],
            { stdio: 'pipe' }
          );
        } catch {
          // best effort rollback
        }
        throw err;
      }
      return { uploadedName, preRestoreName };
    }

    if (!isSqliteFile(incomingPath)) {
      throw new Error('Yüklenen dosya geçerli bir SQLite yedeği değil.');
    }

    const stamp = backupTimestamp();
    const uploadedName = `uploaded-${stamp}.sqlite`;
    const uploadedPath = path.join(dbBackupDir, uploadedName);
    fs.copyFileSync(incomingPath, uploadedPath);

    const preRestoreName = `pre-restore-${stamp}.sqlite`;
    const preRestorePath = path.join(dbBackupDir, preRestoreName);
    if (fs.existsSync(dbPath)) {
      fs.copyFileSync(dbPath, preRestorePath);
    }

    const tmpPath = `${dbPath}.restore.${Date.now()}.tmp`;
    fs.copyFileSync(uploadedPath, tmpPath);
    closeDbConnection();
    try {
      fs.renameSync(tmpPath, dbPath);
    } catch (err) {
      if (fs.existsSync(preRestorePath)) {
        fs.copyFileSync(preRestorePath, dbPath);
      }
      throw err;
    } finally {
      try {
        if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
      } catch {
        // no-op
      }
      resetDbConnection();
    }

    return { uploadedName, preRestoreName };
  }

  function resolveDbDriverSwitchTarget(currentDriver = dbDriver) {
    return String(currentDriver || '').toLowerCase() === 'postgres' ? 'sqlite' : 'postgres';
  }

  function buildDbDriverSwitchConfirmText(currentDriver, targetDriver) {
    return `SWITCH ${String(currentDriver || '').toUpperCase()} -> ${String(targetDriver || '').toUpperCase()}`;
  }

  function buildDbDriverSwitchChallengeKey(req, targetDriver) {
    const sessionKey = String(req.sessionID || req.session?.id || req.session?.userId || req.ip || 'anon');
    return `${sessionKey}:${String(targetDriver || '').toLowerCase()}`;
  }

  function cleanupExpiredDbDriverSwitchChallenges(now = Date.now()) {
    for (const [key, value] of dbDriverSwitchChallenges.entries()) {
      if (!value || Number(value.expiresAt || 0) <= now) {
        dbDriverSwitchChallenges.delete(key);
      }
    }
  }

  function issueDbDriverSwitchChallenge(req, targetDriver) {
    cleanupExpiredDbDriverSwitchChallenges();
    const key = buildDbDriverSwitchChallengeKey(req, targetDriver);
    const token = crypto.randomBytes(24).toString('hex');
    const expiresAt = Date.now() + dbDriverSwitchChallengeTtlMs;
    dbDriverSwitchChallenges.set(key, { token, expiresAt });
    return { token, expiresAt };
  }

  function consumeDbDriverSwitchChallenge(req, targetDriver, token) {
    cleanupExpiredDbDriverSwitchChallenges();
    const key = buildDbDriverSwitchChallengeKey(req, targetDriver);
    const row = dbDriverSwitchChallenges.get(key);
    dbDriverSwitchChallenges.delete(key);
    if (!row) return false;
    if (!token || row.token !== token) return false;
    if (Number(row.expiresAt || 0) <= Date.now()) return false;
    return true;
  }

  function inspectDbDriverSwitchEnvFile() {
    const info = {
      path: dbDriverSwitchEnvFile,
      exists: false,
      readable: false,
      writable: false
    };
    try {
      info.exists = fs.existsSync(dbDriverSwitchEnvFile);
      if (!info.exists) return info;
      fs.accessSync(dbDriverSwitchEnvFile, fs.constants.R_OK);
      info.readable = true;
      fs.accessSync(dbDriverSwitchEnvFile, fs.constants.W_OK);
      info.writable = true;
      return info;
    } catch {
      return info;
    }
  }

  function inspectSqliteSwitchTarget(sqliteFilePath) {
    const payload = {
      ready: false,
      detail: '',
      path: sqliteFilePath,
      tableCount: 0,
      usersTableExists: false
    };

    if (!sqliteFilePath) {
      payload.detail = 'SQLite dosya yolu bulunamadı.';
      return payload;
    }
    if (!fs.existsSync(sqliteFilePath)) {
      payload.detail = `SQLite dosyası bulunamadı (${sqliteFilePath}).`;
      return payload;
    }
    if (!isSqliteFile(sqliteFilePath)) {
      payload.detail = 'SQLite dosya imzası doğrulanamadı.';
      return payload;
    }

    let tmp = null;
    try {
      tmp = new Database(sqliteFilePath, { readonly: true, fileMustExist: true });
      const tableCount = Number(tmp.prepare(
        "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
      ).get()?.cnt || 0);
      const usersTableExists = !!tmp.prepare(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('uyeler', 'users') LIMIT 1"
      ).get();
      payload.tableCount = tableCount;
      payload.usersTableExists = usersTableExists;
      if (!usersTableExists) {
        payload.detail = 'SQLite içinde beklenen kullanıcı tablosu bulunamadı (uyeler/users).';
        return payload;
      }
      payload.ready = true;
      payload.detail = 'ok';
      return payload;
    } catch (err) {
      payload.detail = err?.message || 'SQLite hedef doğrulaması başarısız.';
      return payload;
    } finally {
      try {
        tmp?.close();
      } catch {
        // no-op
      }
    }
  }

  async function inspectPostgresSwitchTarget() {
    const health = await checkPostgresHealth();
    const payload = {
      ready: false,
      configured: health.configured,
      latencyMs: Number(health.latencyMs || 0),
      detail: health.detail || '',
      tableCount: 0,
      usersTableExists: false
    };

    if (!health.ready) return payload;

    try {
      const tableCountResult = await pgQuery(
        "SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM information_schema.tables WHERE table_schema = 'public'"
      );
      const usersTableResult = await pgQuery(
        "SELECT CAST(COUNT(*) AS INTEGER) AS cnt FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('uyeler', 'users')"
      );
      payload.tableCount = Number(tableCountResult.rows?.[0]?.cnt || 0);
      payload.usersTableExists = Number(usersTableResult.rows?.[0]?.cnt || 0) > 0;
      if (!payload.usersTableExists) {
        payload.detail = 'PostgreSQL şemasında beklenen kullanıcı tablosu bulunamadı (uyeler/users).';
        return payload;
      }
      payload.ready = true;
      payload.detail = 'ok';
      return payload;
    } catch (err) {
      payload.detail = err?.message || 'PostgreSQL hedef doğrulaması başarısız.';
      return payload;
    }
  }

  async function buildDbDriverSwitchReadiness() {
    const currentDriver = DB_DRIVER_SET.has(dbDriver) ? dbDriver : 'sqlite';
    const targetDriver = resolveDbDriverSwitchTarget(currentDriver);
    const envFile = inspectDbDriverSwitchEnvFile();
    const sqlite = inspectSqliteSwitchTarget(dbPath);
    const postgres = await inspectPostgresSwitchTarget();
    const targetState = targetDriver === 'postgres' ? postgres : sqlite;
    const blockers = [];

    if (!envFile.exists) blockers.push(`Env dosyası bulunamadı: ${envFile.path}`);
    if (!envFile.readable) blockers.push(`Env dosyası okunamıyor: ${envFile.path}`);
    if (!envFile.writable) blockers.push(`Env dosyası yazılamıyor: ${envFile.path}`);
    if (!targetState.ready) blockers.push(`Hedef ${targetDriver} hazır değil: ${targetState.detail || 'unknown'}`);

    return {
      currentDriver,
      targetDriver,
      envFile,
      sqlite,
      postgres,
      blockers
    };
  }

  function quoteEnvValue(value) {
    const raw = String(value ?? '');
    if (!raw) return '';
    if (/^[A-Za-z0-9_./:@%+-]+$/.test(raw)) return raw;
    return `'${raw.replace(/'/g, "'\\''")}'`;
  }

  function writeEnvUpdates(filePath, updates = {}) {
    const originalText = fs.readFileSync(filePath, 'utf-8');
    const newline = originalText.includes('\r\n') ? '\r\n' : '\n';
    const lines = originalText.replace(/\r\n/g, '\n').split('\n');
    const entries = Object.entries(updates).filter(([key]) => String(key || '').trim().length > 0);

    for (const [key, value] of entries) {
      const rendered = `${key}=${quoteEnvValue(value)}`;
      let updated = false;
      for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i];
        if (!line || /^\s*#/.test(line)) continue;
        const eqIndex = line.indexOf('=');
        if (eqIndex <= 0) continue;
        const lineKey = line.slice(0, eqIndex).trim();
        if (lineKey !== key) continue;
        lines[i] = rendered;
        updated = true;
        break;
      }
      if (!updated) {
        lines.push(rendered);
      }
    }

    const normalized = lines.join('\n').replace(/\n+$/, '');
    const nextText = `${normalized}${newline}`;
    const tmpPath = `${filePath}.tmp-${process.pid}-${Date.now()}`;
    fs.writeFileSync(tmpPath, nextText, 'utf-8');
    fs.renameSync(tmpPath, filePath);
  }

  function pgTypeToSqlite(pgType) {
    const t = String(pgType || '').toLowerCase();
    if (t.includes('int') || t === 'bigint' || t === 'smallint' || t === 'integer' || t === 'serial' || t === 'bigserial') return 'INTEGER';
    if (t === 'real' || t.includes('float') || t.includes('double') || t.includes('numeric') || t.includes('decimal')) return 'REAL';
    if (t === 'boolean' || t === 'bool') return 'INTEGER';
    if (t === 'bytea') return 'BLOB';
    return 'TEXT';
  }

function pgValueForSqlite(val) {
    if (val === null || val === undefined) return null;
    if (typeof val === 'boolean') return val ? 1 : 0;
    if (val instanceof Date) return val.toISOString();
    if (typeof val === 'object') return JSON.stringify(val);
    return val;
  }

  async function copyDbDataAcrossDrivers(sourceDriver, targetDriver) {
    if (sourceDriver === targetDriver) throw new Error('Source and target drivers must be different.');
    if (sourceDriver !== 'sqlite' && sourceDriver !== 'postgres') throw new Error(`Unknown source driver: ${sourceDriver}`);
    if (targetDriver !== 'sqlite' && targetDriver !== 'postgres') throw new Error(`Unknown target driver: ${targetDriver}`);

    const BATCH_SIZE = 500;
    const stats = { tables: 0, rows: 0, errors: [], skipped: [], mapped: [] };
    const tableMappings = buildCrossDriverTableMappings();

    if (sourceDriver === 'sqlite' && targetDriver === 'postgres') {
      const pool = getPgPool ? getPgPool() : null;
      if (!pool) throw new Error('PostgreSQL pool not available. Set DATABASE_URL.');

      // Build lookup: sqliteTableName → mapping entry
      const sqliteToMapping = new Map();
      for (const m of tableMappings) {
        sqliteToMapping.set(m.sqliteTable, m);
      }

      // Fetch PG column types for value conversion
      const pgColTypesResult = await pgQuery(
        `SELECT table_name, column_name, data_type
         FROM information_schema.columns
         WHERE table_schema = 'public'
         ORDER BY table_name, ordinal_position`
      );
      const pgColTypes = {};
      for (const row of pgColTypesResult.rows) {
        if (!pgColTypes[row.table_name]) pgColTypes[row.table_name] = {};
        pgColTypes[row.table_name][row.column_name] = row.data_type;
      }

      // Check which PG tables exist
      const pgTablesResult = await pgQuery(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'"
      );
      const pgTableSet = new Set(pgTablesResult.rows.map(r => r.table_name));

      const sqliteDb = new Database(dbPath, { readonly: true, fileMustExist: true });
      try {
        const sqliteTables = sqliteDb.prepare(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY rowid"
        ).all().map(r => r.name);

        for (const sqliteTable of sqliteTables) {
          if (sqliteTable === 'schema_migrations') continue;

          const mapping = sqliteToMapping.get(sqliteTable);
          const pgTable = mapping ? mapping.pgTable : sqliteTable;

          if (!pgTableSet.has(pgTable)) {
            stats.skipped.push(sqliteTable);
            continue;
          }

          try {
            const rows = sqliteDb.prepare(`SELECT * FROM "${sqliteTable}"`).all();
            if (rows.length === 0) { stats.tables++; continue; }

            // Build column mapping: which SQLite columns go to which PG columns
            const colPairs = []; // [{ sqlite, pg }]
            if (mapping && mapping.columns.length > 0) {
              const rowKeys = new Set(Object.keys(rows[0]));
              const pgTableCols = pgColTypes[pgTable] || {};
              for (const col of mapping.columns) {
                if (rowKeys.has(col.sqlite) && pgTableCols[col.pg] !== undefined) {
                  colPairs.push(col);
                }
              }
              if (sqliteTable !== pgTable) {
                stats.mapped.push({ from: sqliteTable, to: pgTable, columns: colPairs.length });
              }
            } else {
              // No mapping — same table/column names (fallback)
              const columns = Object.keys(rows[0]);
              for (const c of columns) {
                colPairs.push({ sqlite: c, pg: c });
              }
            }

            if (colPairs.length === 0) {
              stats.skipped.push(sqliteTable);
              continue;
            }

            const pgColList = colPairs.map(p => `"${p.pg}"`).join(', ');
            const pgTypes = pgColTypes[pgTable] || {};

            // Build upsert SQL if this mapping has a conflictTarget
            const conflictTarget = mapping && mapping.conflictTarget;
            let buildInsertSql;
            if (conflictTarget) {
              const updateCols = colPairs
                .filter(p => p.pg !== conflictTarget)
                .map(p => `"${p.pg}"=EXCLUDED."${p.pg}"`);
              buildInsertSql = (placeholders) =>
                `INSERT INTO "${pgTable}" (${pgColList}) VALUES (${placeholders})` +
                (updateCols.length > 0
                  ? ` ON CONFLICT ("${conflictTarget}") DO UPDATE SET ${updateCols.join(', ')}`
                  : ` ON CONFLICT DO NOTHING`);
            } else {
              buildInsertSql = (placeholders) =>
                `INSERT INTO "${pgTable}" (${pgColList}) VALUES (${placeholders}) ON CONFLICT DO NOTHING`;
            }

            for (let i = 0; i < rows.length; i += BATCH_SIZE) {
              const batch = rows.slice(i, i + BATCH_SIZE);
              const client = await pool.connect();
              try {
                await client.query('BEGIN');
                try { await client.query('SET LOCAL session_replication_role = replica'); } catch { /* best effort */ }
                for (const row of batch) {
                  const vals = colPairs.map(p => pgValueFromSqlite(row[p.sqlite], pgTypes[p.pg] || ''));
                  const placeholders = vals.map((_, idx) => `$${idx + 1}`).join(', ');
                  await client.query(buildInsertSql(placeholders), vals);
                }
                await client.query('COMMIT');
                stats.rows += batch.length;
              } catch (batchErr) {
                await client.query('ROLLBACK').catch(() => {});
                throw batchErr;
              } finally {
                client.release();
              }
            }
            stats.tables++;
          } catch (tableErr) {
            stats.errors.push({ table: sqliteTable, target: pgTable, message: tableErr?.message || 'unknown' });
          }
        }

        // Reset PG sequences to avoid ID collisions after copy
        try {
          const seqResult = await pgQuery(`
            SELECT s.relname AS sequence_name, t.relname AS table_name, a.attname AS column_name
            FROM pg_class s
            JOIN pg_depend d ON d.objid = s.oid
            JOIN pg_class t ON t.oid = d.refobjid
            JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
            WHERE s.relkind = 'S' AND d.deptype = 'a'
              AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
          `);
          for (const seq of (seqResult.rows || [])) {
            try {
              await pgQuery(
                `SELECT setval($1, COALESCE((SELECT MAX("${seq.column_name}") FROM "${seq.table_name}"), 1))`,
                [seq.sequence_name]
              );
            } catch { /* best effort */ }
          }
        } catch { /* best effort */ }

      } finally {
        sqliteDb.close();
      }

    } else if (sourceDriver === 'postgres' && targetDriver === 'sqlite') {
      // Build lookup: pgTableName → mapping entry
      const pgToMapping = new Map();
      for (const m of tableMappings) {
        pgToMapping.set(m.pgTable, m);
      }

      const tablesResult = await pgQuery(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name"
      );
      const pgTables = tablesResult.rows.map(r => r.table_name);

      // Fetch all column definitions from PostgreSQL upfront
      const colDefsResult = await pgQuery(
        `SELECT table_name, column_name, data_type
         FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = ANY($1)
         ORDER BY table_name, ordinal_position`,
        [pgTables]
      );
      const pgColsByTable = {};
      for (const row of colDefsResult.rows) {
        if (!pgColsByTable[row.table_name]) pgColsByTable[row.table_name] = [];
        pgColsByTable[row.table_name].push(row);
      }

      const sqliteDb = new Database(dbPath, { fileMustExist: true });
      try {
        sqliteDb.pragma('foreign_keys = OFF');
        sqliteDb.pragma('journal_mode = WAL');

        for (const pgTable of pgTables) {
          if (pgTable === 'schema_migrations') continue;

          const mapping = pgToMapping.get(pgTable);
          const sqliteTable = mapping ? mapping.sqliteTable : pgTable;

          try {
            // Check if target SQLite table exists
            const sqliteTableRow = sqliteDb.prepare(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
            ).get(sqliteTable);

            if (!sqliteTableRow) {
              stats.skipped.push(pgTable);
              continue;
            }

            // Get existing SQLite column names
            const existingSqliteCols = sqliteDb.prepare(`PRAGMA table_info("${sqliteTable}")`).all();
            const existingSqliteColNames = new Set(existingSqliteCols.map(c => c.name));

            const pgCols = pgColsByTable[pgTable] || [];

            // Build column pairs based on mapping or fallback to same-name matching
            const colPairs = []; // [{ pg, sqlite, pgType }]
            if (mapping && mapping.columns.length > 0) {
              // Use explicit mapping — only include columns that exist in both sides
              const pgColMap = new Map(pgCols.map(c => [c.column_name, c.data_type]));
              for (const col of mapping.columns) {
                const pgType = pgColMap.get(col.pg);
                if (pgType === undefined) continue; // PG column doesn't exist
                if (!existingSqliteColNames.has(col.sqlite)) {
                  // Auto-add missing SQLite column
                  const sqliteType = pgTypeToSqlite(pgType);
                  try {
                    sqliteDb.exec(`ALTER TABLE "${sqliteTable}" ADD COLUMN "${col.sqlite}" ${sqliteType}`);
                    existingSqliteColNames.add(col.sqlite);
                  } catch { /* ignore if column was added concurrently */ }
                }
                if (existingSqliteColNames.has(col.sqlite)) {
                  colPairs.push({ pg: col.pg, sqlite: col.sqlite, pgType });
                }
              }
              if (pgTable !== sqliteTable) {
                stats.mapped.push({ from: pgTable, to: sqliteTable, columns: colPairs.length });
              }
            } else {
              // No mapping — use same-name column intersection (original behavior)
              for (const pgCol of pgCols) {
                if (existingSqliteColNames.has(pgCol.column_name)) {
                  colPairs.push({ pg: pgCol.column_name, sqlite: pgCol.column_name, pgType: pgCol.data_type });
                } else {
                  // Auto-add missing column
                  const sqliteType = pgTypeToSqlite(pgCol.data_type);
                  try {
                    sqliteDb.exec(`ALTER TABLE "${sqliteTable}" ADD COLUMN "${pgCol.column_name}" ${sqliteType}`);
                    colPairs.push({ pg: pgCol.column_name, sqlite: pgCol.column_name, pgType: pgCol.data_type });
                  } catch { /* ignore */ }
                }
              }
            }

            if (colPairs.length === 0) {
              stats.skipped.push(pgTable);
              continue;
            }

            // Read from PG using PG column names
            const pgSelectCols = colPairs.map(p => `"${p.pg}"`).join(', ');
            const rowsResult = await pgQuery(`SELECT ${pgSelectCols} FROM "${pgTable}"`);
            const rows = rowsResult.rows;
            if (rows.length === 0) { stats.tables++; continue; }

            // Write to SQLite using SQLite column names
            // Use INSERT OR REPLACE for tables with a conflictTarget to ensure source data wins
            const sqliteColList = colPairs.map(p => `"${p.sqlite}"`).join(', ');
            const placeholders = colPairs.map(() => '?').join(', ');
            const insertVerb = (mapping && mapping.conflictTarget) ? 'INSERT OR REPLACE' : 'INSERT OR IGNORE';

            const stmt = sqliteDb.prepare(`${insertVerb} INTO "${sqliteTable}" (${sqliteColList}) VALUES (${placeholders})`);
            const insertBatch = sqliteDb.transaction((batch) => {
              for (const row of batch) {
                stmt.run(colPairs.map(p => sqliteValueFromPg(row[p.pg], p.pgType)));
              }
            });

            for (let i = 0; i < rows.length; i += BATCH_SIZE) {
              insertBatch(rows.slice(i, i + BATCH_SIZE));
              stats.rows += Math.min(BATCH_SIZE, rows.length - i);
            }
            stats.tables++;
          } catch (tableErr) {
            stats.errors.push({ table: pgTable, target: sqliteTable, message: tableErr?.message || 'unknown' });
          }
        }

        // Synthesize conversation_members from conversations if needed
        try {
          const convMembersExists = sqliteDb.prepare(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='conversation_members'"
          ).get();
          if (!convMembersExists) {
            // conversation_members is a PG-only table derived from conversations;
            // SQLite uses sdal_messenger_threads with user_a_id/user_b_id directly
          }
        } catch { /* no-op */ }
      } finally {
        try { sqliteDb.pragma('foreign_keys = ON'); } catch { /* no-op */ }
        sqliteDb.close();
      }
    }

    return stats;
  }

  function scheduleDbDriverSwitchRestart(meta = {}) {
    if (String(process.env.NODE_ENV || '').toLowerCase() === 'test') return;
    const timer = setTimeout(() => {
      writeAppLog('info', 'db_driver_switch_restart', {
        mode: dbDriverSwitchRestartCommand ? 'custom_command' : 'api_process_exit',
        ...meta
      });
      if (dbDriverSwitchRestartCommand) {
        try {
          execFileSync('/bin/sh', ['-lc', dbDriverSwitchRestartCommand], { stdio: 'ignore' });
          return;
        } catch (err) {
          writeAppLog('error', 'db_driver_switch_restart_command_failed', {
            message: err?.message || 'unknown_error'
          });
        }
      }
      try {
        process.kill(process.pid, 'SIGTERM');
      } catch (err) {
        writeAppLog('error', 'db_driver_switch_restart_failed', {
          message: err?.message || 'unknown_error'
        });
      }
    }, dbDriverSwitchRestartDelayMs);
    if (typeof timer?.unref === 'function') timer.unref();
  }

  return {
    dbBackupIncomingDir,
    dbBackupDir,
    dbDriverSwitchEnvFile,
    dbDriverSwitchRestartDelayMs,
    dbDriverSwitchRestartCommand,
    dbDriverSwitchState,
    backupTimestamp,
    listDbBackups,
    createDbBackup,
    restoreDbFromUploadedFile,
    resolveBackupPath,
    buildDbDriverSwitchReadiness,
    buildDbDriverSwitchConfirmText,
    issueDbDriverSwitchChallenge,
    consumeDbDriverSwitchChallenge,
    writeEnvUpdates,
    scheduleDbDriverSwitchRestart,
    copyDbDataAcrossDrivers
  };
}
