BEGIN;

ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS cv_link TEXT;
ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS contact_channel TEXT;
ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS contact_value TEXT;
ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS city TEXT;

COMMIT;
