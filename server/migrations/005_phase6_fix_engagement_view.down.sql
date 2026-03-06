BEGIN;

DROP VIEW IF EXISTS engagement_ab_config;

CREATE VIEW engagement_ab_config AS
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

COMMIT;
