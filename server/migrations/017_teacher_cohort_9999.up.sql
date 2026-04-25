BEGIN;

UPDATE users
SET graduation_year = 9999
WHERE LOWER(COALESCE(role, '')) = 'teacher';

COMMIT;
