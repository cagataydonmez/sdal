-- Add sort_order to cms_pages for drag-and-drop menu ordering
ALTER TABLE cms_pages ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;

-- Add default_landing_page to site_settings
ALTER TABLE site_settings ADD COLUMN IF NOT EXISTS default_landing_page TEXT NOT NULL DEFAULT '';

-- Initialize sort_order based on current alphabetical order
UPDATE cms_pages SET sort_order = sub.rn
FROM (
  SELECT id, ROW_NUMBER() OVER (ORDER BY name ASC NULLS LAST) AS rn FROM cms_pages
) sub
WHERE cms_pages.id = sub.id;
