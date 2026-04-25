BEGIN;

UPDATE users
SET graduation_year = NULL
WHERE LOWER(COALESCE(role, '')) = 'teacher'
  AND graduation_year = 9999;

COMMIT;
