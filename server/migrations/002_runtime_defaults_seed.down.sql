BEGIN;

DELETE FROM support_request_categories
WHERE category_key IN (
  'graduation_year_change',
  'profile_data_correction',
  'account_status_review',
  'content_moderation_appeal',
  'group_management_support',
  'feature_access_request'
);

DELETE FROM module_settings
WHERE module_key IN (
  'feed',
  'main_feed',
  'explore',
  'following',
  'groups',
  'messages',
  'messenger',
  'notifications',
  'albums',
  'games',
  'events',
  'announcements',
  'jobs',
  'profile',
  'help',
  'requests'
);

DELETE FROM site_settings WHERE id = 1;
DELETE FROM media_settings WHERE id = 1;

COMMIT;
