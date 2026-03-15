BEGIN;

DROP INDEX IF EXISTS idx_teacher_alumni_links_teacher_user_id;
DROP INDEX IF EXISTS idx_teacher_alumni_links_alumni_user_id;
DROP INDEX IF EXISTS idx_follows_follower_following;
DROP INDEX IF EXISTS idx_job_applications_job_poster_status;
DROP INDEX IF EXISTS idx_mentorship_requests_requester_status;
DROP INDEX IF EXISTS idx_mentorship_requests_mentor_status;

COMMIT;
