BEGIN;

INSERT INTO site_settings (id, site_open, maintenance_message, updated_at)
VALUES (
  1,
  TRUE,
  'Site geçici bakım modundadır. Lütfen daha sonra tekrar deneyin.',
  NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO module_settings (module_key, is_open, updated_at)
VALUES
  ('feed', TRUE, NOW()),
  ('main_feed', TRUE, NOW()),
  ('explore', TRUE, NOW()),
  ('following', TRUE, NOW()),
  ('groups', TRUE, NOW()),
  ('messages', TRUE, NOW()),
  ('messenger', TRUE, NOW()),
  ('notifications', TRUE, NOW()),
  ('albums', TRUE, NOW()),
  ('games', TRUE, NOW()),
  ('events', TRUE, NOW()),
  ('announcements', TRUE, NOW()),
  ('jobs', TRUE, NOW()),
  ('profile', TRUE, NOW()),
  ('help', TRUE, NOW()),
  ('requests', TRUE, NOW())
ON CONFLICT (module_key) DO UPDATE SET updated_at = EXCLUDED.updated_at;

INSERT INTO media_settings
  (id, storage_provider, local_base_path, thumb_width, feed_width, full_width, webp_quality, max_upload_bytes, avif_enabled, updated_at)
VALUES
  (1, 'local', '/var/www/sdal/uploads', 200, 800, 1600, 80, 10485760, FALSE, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO support_request_categories (category_key, label, description, is_active, created_at, updated_at)
VALUES
  ('graduation_year_change', 'Mezuniyet Yılı Değişikliği', 'Doğrulanmış üyelerin mezuniyet yılı değişiklik talepleri.', TRUE, NOW(), NOW()),
  ('profile_data_correction', 'Profil Veri Düzeltme', 'Kişisel profil bilgilerinde manuel düzenleme talepleri.', TRUE, NOW(), NOW()),
  ('account_status_review', 'Hesap Durumu İncelemesi', 'Hesap erişimi/yetki/ban inceleme talepleri.', TRUE, NOW(), NOW()),
  ('content_moderation_appeal', 'İçerik Moderasyon İtirazı', 'Silinen veya kısıtlanan içeriklere itiraz talepleri.', TRUE, NOW(), NOW()),
  ('group_management_support', 'Grup Yönetim Desteği', 'Grup moderasyonu veya sahiplik desteği talepleri.', TRUE, NOW(), NOW()),
  ('feature_access_request', 'Özellik Erişim Talebi', 'Yeni veya kısıtlı özelliklere erişim talepleri.', TRUE, NOW(), NOW())
ON CONFLICT (category_key) DO UPDATE SET
  label = EXCLUDED.label,
  description = EXCLUDED.description,
  updated_at = EXCLUDED.updated_at;

COMMIT;
