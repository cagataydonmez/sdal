BEGIN;

-- Accept legacy 0/1 writes and comparisons for boolean columns.
CREATE OR REPLACE FUNCTION legacy_int2_to_bool(value SMALLINT)
RETURNS BOOLEAN
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  SELECT value <> 0;
$$;

CREATE OR REPLACE FUNCTION legacy_int4_to_bool(value INTEGER)
RETURNS BOOLEAN
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  SELECT value <> 0;
$$;

CREATE OR REPLACE FUNCTION legacy_int8_to_bool(value BIGINT)
RETURNS BOOLEAN
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT
AS $$
  SELECT value <> 0;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_cast c
    JOIN pg_type s ON s.oid = c.castsource
    JOIN pg_type t ON t.oid = c.casttarget
    WHERE s.typname = 'int2' AND t.typname = 'bool'
  ) THEN
    CREATE CAST (SMALLINT AS BOOLEAN) WITH FUNCTION legacy_int2_to_bool(SMALLINT) AS IMPLICIT;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_cast c
    JOIN pg_type s ON s.oid = c.castsource
    JOIN pg_type t ON t.oid = c.casttarget
    WHERE s.typname = 'int4' AND t.typname = 'bool'
  ) THEN
    CREATE CAST (INTEGER AS BOOLEAN) WITH FUNCTION legacy_int4_to_bool(INTEGER) AS IMPLICIT;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_cast c
    JOIN pg_type s ON s.oid = c.castsource
    JOIN pg_type t ON t.oid = c.casttarget
    WHERE s.typname = 'int8' AND t.typname = 'bool'
  ) THEN
    CREATE CAST (BIGINT AS BOOLEAN) WITH FUNCTION legacy_int8_to_bool(BIGINT) AS IMPLICIT;
  END IF;
END $$;

-- Same-name table compatibility columns (legacy names kept alive).
ALTER TABLE posts ADD COLUMN IF NOT EXISTS user_id BIGINT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_record_id TEXT;

ALTER TABLE post_comments ADD COLUMN IF NOT EXISTS user_id BIGINT;
ALTER TABLE post_comments ADD COLUMN IF NOT EXISTS comment TEXT;

ALTER TABLE stories ADD COLUMN IF NOT EXISTS user_id BIGINT;
ALTER TABLE stories ADD COLUMN IF NOT EXISTS image TEXT;
ALTER TABLE stories ADD COLUMN IF NOT EXISTS image_record_id TEXT;

ALTER TABLE groups ADD COLUMN IF NOT EXISTS cover_image TEXT;
ALTER TABLE events ADD COLUMN IF NOT EXISTS image TEXT;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS image TEXT;
ALTER TABLE event_comments ADD COLUMN IF NOT EXISTS comment TEXT;

ALTER TABLE identity_verification_requests ADD COLUMN IF NOT EXISTS request_type TEXT;
ALTER TABLE identity_verification_requests ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE identity_verification_requests ADD COLUMN IF NOT EXISTS reviewer_note TEXT;
ALTER TABLE identity_verification_requests ADD COLUMN IF NOT EXISTS resolution_note TEXT;
ALTER TABLE identity_verification_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

ALTER TABLE support_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

ALTER TABLE engagement_variants ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE engagement_variants ADD COLUMN IF NOT EXISTS weight DOUBLE PRECISION NOT NULL DEFAULT 1;
ALTER TABLE engagement_variants ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE user_engagement_scores ADD COLUMN IF NOT EXISTS computed_at TIMESTAMPTZ;

ALTER TABLE media_assets ADD COLUMN IF NOT EXISTS mime TEXT;
ALTER TABLE media_assets ADD COLUMN IF NOT EXISTS size_bytes BIGINT;
ALTER TABLE media_assets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION sync_posts_legacy_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.author_id := COALESCE(NEW.author_id, NEW.user_id);
  NEW.user_id := COALESCE(NEW.user_id, NEW.author_id);
  NEW.image_url := COALESCE(NEW.image_url, NEW.image);
  NEW.image := COALESCE(NEW.image, NEW.image_url);
  NEW.media_asset_id := COALESCE(NEW.media_asset_id, NEW.image_record_id);
  NEW.image_record_id := COALESCE(NEW.image_record_id, NEW.media_asset_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_posts_legacy_columns ON posts;
CREATE TRIGGER trg_sync_posts_legacy_columns
BEFORE INSERT OR UPDATE ON posts
FOR EACH ROW EXECUTE FUNCTION sync_posts_legacy_columns();

UPDATE posts
SET
  author_id = COALESCE(author_id, user_id),
  user_id = COALESCE(user_id, author_id),
  image_url = COALESCE(image_url, image),
  image = COALESCE(image, image_url),
  media_asset_id = COALESCE(media_asset_id, image_record_id),
  image_record_id = COALESCE(image_record_id, media_asset_id);

CREATE OR REPLACE FUNCTION sync_post_comments_legacy_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.author_id := COALESCE(NEW.author_id, NEW.user_id);
  NEW.user_id := COALESCE(NEW.user_id, NEW.author_id);
  NEW.body := COALESCE(NEW.body, NEW.comment);
  NEW.comment := COALESCE(NEW.comment, NEW.body);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_post_comments_legacy_columns ON post_comments;
CREATE TRIGGER trg_sync_post_comments_legacy_columns
BEFORE INSERT OR UPDATE ON post_comments
FOR EACH ROW EXECUTE FUNCTION sync_post_comments_legacy_columns();

UPDATE post_comments
SET
  author_id = COALESCE(author_id, user_id),
  user_id = COALESCE(user_id, author_id),
  body = COALESCE(body, comment),
  comment = COALESCE(comment, body);

CREATE OR REPLACE FUNCTION sync_stories_legacy_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.author_id := COALESCE(NEW.author_id, NEW.user_id);
  NEW.user_id := COALESCE(NEW.user_id, NEW.author_id);
  NEW.image_url := COALESCE(NEW.image_url, NEW.image);
  NEW.image := COALESCE(NEW.image, NEW.image_url);
  NEW.media_asset_id := COALESCE(NEW.media_asset_id, NEW.image_record_id);
  NEW.image_record_id := COALESCE(NEW.image_record_id, NEW.media_asset_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_stories_legacy_columns ON stories;
CREATE TRIGGER trg_sync_stories_legacy_columns
BEFORE INSERT OR UPDATE ON stories
FOR EACH ROW EXECUTE FUNCTION sync_stories_legacy_columns();

UPDATE stories
SET
  author_id = COALESCE(author_id, user_id),
  user_id = COALESCE(user_id, author_id),
  image_url = COALESCE(image_url, image),
  image = COALESCE(image, image_url),
  media_asset_id = COALESCE(media_asset_id, image_record_id),
  image_record_id = COALESCE(image_record_id, media_asset_id);

CREATE OR REPLACE FUNCTION sync_groups_legacy_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.cover_image_url := COALESCE(NEW.cover_image_url, NEW.cover_image);
  NEW.cover_image := COALESCE(NEW.cover_image, NEW.cover_image_url);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_groups_legacy_columns ON groups;
CREATE TRIGGER trg_sync_groups_legacy_columns
BEFORE INSERT OR UPDATE ON groups
FOR EACH ROW EXECUTE FUNCTION sync_groups_legacy_columns();

UPDATE groups
SET
  cover_image_url = COALESCE(cover_image_url, cover_image),
  cover_image = COALESCE(cover_image, cover_image_url);

CREATE OR REPLACE FUNCTION sync_events_legacy_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.image_url := COALESCE(NEW.image_url, NEW.image);
  NEW.image := COALESCE(NEW.image, NEW.image_url);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_events_legacy_columns ON events;
CREATE TRIGGER trg_sync_events_legacy_columns
BEFORE INSERT OR UPDATE ON events
FOR EACH ROW EXECUTE FUNCTION sync_events_legacy_columns();

UPDATE events
SET
  image_url = COALESCE(image_url, image),
  image = COALESCE(image, image_url);

CREATE OR REPLACE FUNCTION sync_announcements_legacy_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.image_url := COALESCE(NEW.image_url, NEW.image);
  NEW.image := COALESCE(NEW.image, NEW.image_url);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_announcements_legacy_columns ON announcements;
CREATE TRIGGER trg_sync_announcements_legacy_columns
BEFORE INSERT OR UPDATE ON announcements
FOR EACH ROW EXECUTE FUNCTION sync_announcements_legacy_columns();

UPDATE announcements
SET
  image_url = COALESCE(image_url, image),
  image = COALESCE(image, image_url);

CREATE OR REPLACE FUNCTION sync_event_comments_legacy_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.comment_body := COALESCE(NEW.comment_body, NEW.comment);
  NEW.comment := COALESCE(NEW.comment, NEW.comment_body);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_event_comments_legacy_columns ON event_comments;
CREATE TRIGGER trg_sync_event_comments_legacy_columns
BEFORE INSERT OR UPDATE ON event_comments
FOR EACH ROW EXECUTE FUNCTION sync_event_comments_legacy_columns();

UPDATE event_comments
SET
  comment_body = COALESCE(comment_body, comment),
  comment = COALESCE(comment, comment_body);

UPDATE identity_verification_requests
SET updated_at = COALESCE(updated_at, reviewed_at, created_at)
WHERE updated_at IS NULL;

UPDATE support_requests
SET updated_at = COALESCE(updated_at, reviewed_at, created_at)
WHERE updated_at IS NULL;

UPDATE user_engagement_scores
SET computed_at = COALESCE(computed_at, updated_at)
WHERE computed_at IS NULL;

UPDATE media_assets
SET updated_at = COALESCE(updated_at, created_at)
WHERE updated_at IS NULL;

-- Legacy compatibility views (old table names over modern schema).
CREATE OR REPLACE VIEW uyeler AS
SELECT
  id,
  username AS kadi,
  password_hash AS sifre,
  email,
  first_name AS isim,
  last_name AS soyisim,
  activation_token AS aktivasyon,
  is_active AS aktiv,
  created_at AS ilktarih,
  avatar_path AS resim,
  graduation_year AS mezuniyetyili,
  is_profile_initialized AS ilkbd,
  legacy_admin_flag AS admin,
  is_album_admin AS albumadmin,
  role,
  is_verified AS verified,
  verification_status,
  privacy_consent_at AS kvkk_consent_at,
  directory_consent_at,
  city AS sehir,
  profession AS meslek,
  website_url AS websitesi,
  university_name AS universite,
  birth_day AS dogumgun,
  birth_month AS dogumay,
  birth_year AS dogumyil,
  is_email_hidden AS mailkapali,
  signature AS imza,
  company_name AS sirket,
  job_title AS unvan,
  expertise AS uzmanlik,
  linkedin_url,
  university_department AS universite_bolum,
  is_mentor_opted_in AS mentor_opt_in,
  mentor_topics AS mentor_konulari,
  is_online AS online,
  last_seen_at AS sontarih,
  last_activity_date AS sonislemtarih,
  last_activity_time AS sonislemsaat,
  last_ip AS sonip,
  is_banned AS yasak,
  quick_access_ids_json AS hizliliste,
  profile_view_count AS hit,
  homepage_page_id AS ilksayfa,
  legacy_status_last_activity_at AS s_sonislem,
  legacy_status_is_online AS s_online,
  previous_last_seen_at AS oncekisontarih,
  oauth_provider,
  oauth_subject,
  oauth_email_verified
FROM users;

CREATE OR REPLACE VIEW oauth_accounts AS
SELECT
  id,
  user_id,
  provider,
  provider_subject AS provider_user_id,
  email,
  profile_json,
  created_at,
  updated_at
FROM oauth_identities;

CREATE OR REPLACE VIEW site_controls AS
SELECT
  id,
  site_open,
  maintenance_message,
  updated_at
FROM site_settings;

CREATE OR REPLACE VIEW module_controls AS
SELECT
  module_key,
  is_open,
  updated_at
FROM module_settings;

CREATE OR REPLACE VIEW engagement_ab_config AS
SELECT
  variant,
  name AS label,
  enabled AS is_enabled,
  is_default,
  weight,
  description,
  params_json,
  created_at,
  updated_at
FROM engagement_variants;

CREATE OR REPLACE VIEW request_categories AS
SELECT
  id,
  category_key,
  label,
  description,
  is_active AS active,
  created_at,
  updated_at
FROM support_request_categories;

CREATE OR REPLACE VIEW member_requests AS
SELECT
  id,
  user_id,
  category_key,
  payload_json,
  status,
  resolution_note,
  reviewer_id,
  reviewed_at,
  created_at,
  updated_at
FROM support_requests;

CREATE OR REPLACE VIEW verification_requests AS
SELECT
  id,
  user_id,
  status,
  request_type,
  note,
  proof_path,
  proof_media_asset_id AS proof_image_record_id,
  reviewer_id,
  reviewer_note,
  resolution_note,
  created_at,
  updated_at,
  reviewed_at
FROM identity_verification_requests;

CREATE OR REPLACE VIEW follows AS
SELECT
  id,
  follower_id,
  following_id,
  created_at
FROM user_follows;

CREATE OR REPLACE VIEW post_likes AS
SELECT
  id,
  post_id,
  user_id,
  created_at
FROM post_reactions;

CREATE OR REPLACE VIEW chat_messages AS
SELECT
  id,
  user_id,
  body AS message,
  created_at,
  updated_at
FROM live_chat_messages;

CREATE OR REPLACE VIEW image_records AS
SELECT
  id,
  user_id,
  entity_type,
  entity_id,
  provider,
  thumb_path,
  feed_path,
  full_path,
  width,
  height,
  mime,
  size_bytes,
  created_at,
  updated_at
FROM media_assets;

CREATE OR REPLACE VIEW moderator_scopes AS
SELECT
  id,
  user_id,
  scope_type,
  scope_value,
  graduation_year,
  created_by,
  created_at
FROM moderation_scopes;

CREATE OR REPLACE VIEW moderator_permissions AS
SELECT
  id,
  user_id,
  permission_key,
  enabled,
  created_by,
  updated_by,
  created_at,
  updated_at
FROM moderation_permissions;

CREATE OR REPLACE VIEW engagement_ab_assignments AS
SELECT
  user_id,
  variant,
  assigned_at,
  updated_at
FROM engagement_variant_assignments;

CREATE OR REPLACE VIEW member_engagement_scores AS
SELECT
  user_id,
  ab_variant,
  score,
  raw_score,
  creator_score,
  engagement_received_score,
  community_score,
  network_score,
  quality_score,
  penalty_score,
  posts_30d,
  posts_7d,
  likes_received_30d,
  comments_received_30d,
  likes_given_30d,
  comments_given_30d,
  followers_count,
  following_count,
  follows_gained_30d,
  follows_given_30d,
  stories_30d,
  story_views_received_30d,
  chat_messages_30d,
  last_activity_at,
  computed_at,
  updated_at
FROM user_engagement_scores;

CREATE OR REPLACE VIEW sdal_messenger_threads AS
SELECT
  id,
  participant_a_id AS user_a_id,
  participant_b_id AS user_b_id,
  created_at,
  updated_at,
  last_message_at
FROM conversations;

CREATE OR REPLACE VIEW sdal_messenger_messages AS
SELECT
  id,
  conversation_id AS thread_id,
  sender_id,
  recipient_id AS receiver_id,
  body,
  client_written_at,
  server_received_at,
  delivered_at,
  created_at,
  read_at,
  deleted_by_sender,
  deleted_by_recipient AS deleted_by_receiver
FROM conversation_messages;

CREATE OR REPLACE VIEW gelenkutusu AS
SELECT
  id,
  recipient_id AS kime,
  sender_id AS kimden,
  recipient_visible AS aktifgelen,
  sender_visible AS aktifgiden,
  is_unread AS yeni,
  subject AS konu,
  body_html AS mesaj,
  created_at AS tarih
FROM direct_messages;

CREATE OR REPLACE VIEW mesaj_kategori AS
SELECT
  id,
  name AS kategoriadi,
  description AS aciklama
FROM board_categories;

CREATE OR REPLACE VIEW mesaj AS
SELECT
  id,
  author_user_id AS gonderenid,
  body_html AS mesaj,
  category_id AS kategori,
  created_at AS tarih
FROM board_messages;

CREATE OR REPLACE VIEW email_kategori AS
SELECT
  id,
  name AS ad,
  type AS tur,
  value AS deger,
  description AS aciklama
FROM email_categories;

CREATE OR REPLACE VIEW email_sablon AS
SELECT
  id,
  name AS ad,
  subject AS konu,
  body_html AS icerik,
  created_at AS olusturma
FROM email_templates;

CREATE OR REPLACE VIEW sayfalar AS
SELECT
  id,
  name AS sayfaismi,
  slug AS sayfaurl,
  view_count AS hit,
  last_viewed_at AS sontarih,
  last_editor_username AS sonuye,
  parent_page_id AS babaid,
  is_visible_in_menu AS menugorun,
  is_redirect AS yonlendir,
  body_html AS sayfametin,
  layout_option AS mozellik,
  image_url AS resim,
  last_editor_ip AS sonip
FROM cms_pages;

CREATE OR REPLACE VIEW album_kat AS
SELECT
  id,
  name AS kategori,
  description AS aciklama,
  created_at AS ilktarih,
  last_upload_at AS sonekleme,
  last_uploaded_by_user_id AS sonekleyen,
  is_active AS aktif
FROM album_categories;

CREATE OR REPLACE VIEW album_foto AS
SELECT
  id,
  category_id AS katid,
  file_name AS dosyaadi,
  title AS baslik,
  description AS aciklama,
  is_active AS aktif,
  uploaded_by_user_id AS ekleyenid,
  created_at AS tarih,
  view_count AS hit
FROM album_photos;

CREATE OR REPLACE VIEW album_fotoyorum AS
SELECT
  id,
  photo_id AS fotoid,
  author_username AS uyeadi,
  comment_body AS yorum,
  created_at AS tarih
FROM album_photo_comments;

CREATE OR REPLACE VIEW filtre AS
SELECT
  id,
  term AS kufur
FROM blocked_terms;

CREATE OR REPLACE VIEW hmes AS
SELECT
  id,
  username AS kadi,
  message_body AS metin,
  created_at AS tarih
FROM shoutbox_messages;

CREATE OR REPLACE VIEW oyun_yilan AS
SELECT
  id,
  username AS isim,
  score AS skor,
  created_at AS tarih
FROM snake_scores;

CREATE OR REPLACE VIEW oyun_tetris AS
SELECT
  id,
  username AS isim,
  score AS puan,
  level AS seviye,
  lines AS satir,
  created_at AS tarih
FROM tetris_scores;

CREATE OR REPLACE VIEW takimlar AS
SELECT
  id,
  team_name AS tisim,
  team_category_id AS tkid,
  team_phone AS tktelefon,
  captain_name AS boyismi,
  captain_graduation_year AS boymezuniyet,
  player1_name AS ioyismi,
  player1_graduation_year AS ioymezuniyet,
  player2_name AS uoyismi,
  player2_graduation_year AS uoymezuniyet,
  player3_name AS doyismi,
  player3_graduation_year AS doymezuniyet,
  created_at AS tarih
FROM tournament_teams;

CREATE OR REPLACE VIEW audit_log AS
SELECT
  id,
  actor_user_id,
  action,
  target_type,
  target_id,
  metadata,
  ip,
  user_agent,
  created_at
FROM audit_logs;

COMMIT;
