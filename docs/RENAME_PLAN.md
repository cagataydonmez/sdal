# SDAL Legacy-to-Modern Rename Plan

This plan defines the one-time naming migration from legacy naming to modern conventions across database schema, backend code, and API DTO boundaries.

## Naming Rules (Non-Negotiable)

1. Database tables: plural `snake_case`
   - Example: `users`, `posts`, `conversation_members`
2. Database columns: `snake_case`
   - Example: `created_at`, `updated_at`, `user_id`, `deleted_at`
3. JavaScript/TypeScript code: `camelCase`
   - Example: `userId`, `createdAt`, `isVerified`
4. Constants/env names: `UPPER_SNAKE_CASE`
5. File naming:
   - Repositories/services/controllers: `kebab-case` filenames
   - Types/domain models: `kebab-case` filenames with named exports

## One-Time Strategy

1. Build modern PostgreSQL schema using target names.
2. Migrate data from SQLite legacy tables to modern tables with explicit field transforms.
3. Refactor runtime code to only use modern schema names.
4. Keep legacy response fields only at API adapter boundary until client migration is complete.
5. Remove legacy runtime table creation and legacy naming helpers from application startup.
6. Keep temporary SQLite runtime compatibility paths only for local regression tests while Postgres runtime is migration-first.

## Table Mapping

| Current Table | Target Table | Notes |
|---|---|---|
| `uyeler` | `users` | Core identity/profile/auth fields |
| `gelenkutusu` | `direct_messages` | Legacy inbox/outbox model |
| `mesaj` | `board_messages` | Legacy board/panel messages |
| `mesaj_kategori` | `board_categories` | Legacy board categories |
| `album_kat` | `album_categories` | Album category metadata |
| `album_foto` | `album_photos` | Album photos |
| `album_fotoyorum` | `album_photo_comments` | Photo comments |
| `sayfalar` | `cms_pages` | Legacy CMS pages |
| `filtre` | `blocked_terms` | Content filter dictionary |
| `hmes` | `shoutbox_messages` | Legacy shoutbox/chat bridge |
| `oyun_yilan` | `snake_scores` | Legacy snake leaderboard |
| `oyun_tetris` | `tetris_scores` | Legacy tetris leaderboard |
| `takimlar` | `tournament_teams` | Tournament registrations |
| `email_kategori` | `email_categories` | Admin email categories |
| `email_sablon` | `email_templates` | Admin email templates |
| `sdal_messenger_threads` | `conversations` | Private messaging threads |
| `sdal_messenger_messages` | `conversation_messages` | Private thread messages |
| `post_comments` | `post_comments` | Keep name; already modern |
| `post_likes` | `post_reactions` | Normalize for extensibility (`reaction_type`) |
| `follows` | `user_follows` | Clarify relationship intent |
| `chat_messages` | `live_chat_messages` | Distinguish from direct messages |
| `verification_requests` | `identity_verification_requests` | Explicit domain name |
| `member_requests` | `support_requests` | Generic internal request pipeline |
| `request_categories` | `support_request_categories` | Category normalization |
| `image_records` | `media_assets` | Unified media metadata |
| `media_settings` | `media_settings` | Keep (already meaningful) |
| `site_controls` | `site_settings` | Platform-level controls |
| `module_controls` | `module_settings` | Per-module feature flags |
| `engagement_ab_config` | `engagement_variants` | A/B config table |
| `engagement_ab_assignments` | `engagement_variant_assignments` | Variant assignment map |
| `member_engagement_scores` | `user_engagement_scores` | User ranking metrics |
| `oauth_accounts` | `oauth_identities` | External auth linkage |
| `audit_log` | `audit_logs` | Standard pluralization |
| `moderator_scopes` | `moderation_scopes` | Role scope normalization |
| `moderator_permissions` | `moderation_permissions` | Permission normalization |

## Column Mapping (Key Legacy Tables)

## `users` (from `uyeler`)

| Legacy Column | Target Column |
|---|---|
| `id` | `id` |
| `kadi` | `username` |
| `sifre` | `password_hash` |
| `isim` | `first_name` |
| `soyisim` | `last_name` |
| `email` | `email` |
| `resim` | `avatar_path` |
| `aktiv` | `is_active` |
| `yasak` | `is_banned` |
| `admin` | `is_admin_legacy` |
| `online` | `is_online` |
| `mezuniyetyili` | `graduation_year` |
| `universite` | `university_name` |
| `meslek` | `profession` |
| `sehir` | `city` |
| `websitesi` | `website_url` |
| `imza` | `signature` |
| `sonip` | `last_ip` |
| `sonislemtarih` | `last_activity_date` |
| `sonislemsaat` | `last_activity_time` |
| `ilktarih` | `created_at` |
| `sontarih` | `last_seen_at` |
| `oncekisontarih` | `previous_last_seen_at` |
| `mailkapali` | `is_email_hidden` |
| `hizliliste` | `quick_access_ids_json` |
| `aktivasyon` | `activation_token` |
| `dogumgun` | `birth_day` |
| `dogumay` | `birth_month` |
| `dogumyil` | `birth_year` |
| `sirket` | `company_name` |
| `unvan` | `job_title` |
| `uzmanlik` | `expertise` |
| `mentor_opt_in` | `is_mentor_opted_in` |
| `mentor_konulari` | `mentor_topics` |
| `kvkk_consent_at` | `privacy_consent_at` |
| `directory_consent_at` | `directory_consent_at` |

## `direct_messages` (from `gelenkutusu`)

| Legacy Column | Target Column |
|---|---|
| `id` | `id` |
| `kime` | `recipient_id` |
| `kimden` | `sender_id` |
| `konu` | `subject` |
| `mesaj` | `body_html` |
| `yeni` | `is_unread` |
| `aktifgelen` | `recipient_visible` |
| `aktifgiden` | `sender_visible` |
| `tarih` | `created_at` |

## `album_photos` (from `album_foto`)

| Legacy Column | Target Column |
|---|---|
| `id` | `id` |
| `katid` | `category_id` |
| `dosyaadi` | `file_name` |
| `baslik` | `title` |
| `aciklama` | `description` |
| `aktif` | `is_active` |
| `ekleyenid` | `uploaded_by_user_id` |
| `tarih` | `created_at` |
| `hit` | `view_count` |

## `album_photo_comments` (from `album_fotoyorum`)

| Legacy Column | Target Column |
|---|---|
| `id` | `id` |
| `fotoid` | `photo_id` |
| `uyeadi` | `author_username` |
| `yorum` | `comment_text` |
| `tarih` | `created_at` |

## `board_messages` (from `mesaj`)

| Legacy Column | Target Column |
|---|---|
| `id` | `id` |
| `gonderenid` | `author_user_id` |
| `mesaj` | `message_html` |
| `kategori` | `category_id` |
| `tarih` | `created_at` |

## JS/TS Identifier Mapping

| Legacy Identifier | Modern Identifier |
|---|---|
| `kadi` | `username` |
| `sifre` | `passwordHash` |
| `isim` | `firstName` |
| `soyisim` | `lastName` |
| `resim` | `avatarPath` |
| `yasak` | `isBanned` |
| `aktiv` | `isActive` |
| `mezuniyetyili` | `graduationYear` |
| `uyeId` / `uye_id` | `userId` |
| `fotoid` | `photoId` |
| `katid` | `categoryId` |
| `gonderenid` | `senderId` |
| `kime` | `recipientId` |
| `kimden` | `senderId` |
| `konu` | `subject` |
| `mesaj` | `messageBody` |
| `tarih` | `createdAt` |
| `aciklama` | `description` |
| `sonekleme` | `last_upload_at` |

## API DTO Compatibility Mapping

Internal domain objects will use modern names. API adapters preserve current wire format during transition.

| Internal Field | Public Field (legacy-compatible) |
|---|---|
| `username` | `kadi` |
| `firstName` | `isim` |
| `lastName` | `soyisim` |
| `avatarPath` | `resim` / `photo` |
| `createdAt` | `tarih` / `created_at` (context-dependent) |
| `isVerified` | `verified` |
| `author.userId` | `user_id` |
| `messageBody` | `message` / `mesaj` |

## File/Module Rename Targets

| Current | Target |
|---|---|
| `server/app.js` monolith sections | modular files in `server/src` (`services`, `repositories`, `controllers`) |
| `server/db.js` hybrid adapter | `server/src/infra/db/*` with pooled pg + sqlite migration reader |
| `server/media/uploadPipeline.js` | `server/src/media/media-service.js` (retaining pipeline logic) |
| `server/middleware/requestLogging.js` | `server/src/http/middleware/request-logging.js` |

## Enforcement

1. DB migrations create only target names.
2. Repositories query target schema only.
3. DTO adapter layer is the only place where legacy field names appear.
4. Lint rule/process check: disallow newly introduced legacy identifiers in domain/service/repository layers.

## Rollout Order for Naming

1. Introduce modern domain models + DTO adapters.
2. Create modern PostgreSQL schema with target names.
3. Run one-time data migration with explicit field mapping.
4. Switch runtime DB access to modern schema.
5. Remove legacy-name runtime code paths and boot-time DDL.
