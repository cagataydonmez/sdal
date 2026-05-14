BEGIN;

-- SQLite ALTER TABLE DROP COLUMN support depends on runtime version.
-- Keep rollback as a portable no-op; runtime schema guards tolerate the columns.

COMMIT;
