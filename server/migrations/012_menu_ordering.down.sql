-- Remove sort_order from cms_pages
ALTER TABLE cms_pages DROP COLUMN IF EXISTS sort_order;

-- Remove default_landing_page from site_settings
ALTER TABLE site_settings DROP COLUMN IF EXISTS default_landing_page;
