BEGIN;

DROP VIEW IF EXISTS engagement_ab_config;

CREATE VIEW engagement_ab_config AS
SELECT
  variant,
  name,
  description,
  traffic_pct,
  enabled,
  params_json,
  created_at,
  updated_at
FROM engagement_variants;

COMMIT;
