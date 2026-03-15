BEGIN;

-- Teacher alumni links: used in EXISTS subquery in member list and explore suggestions scoring
-- Both columns are scanned with OR conditions across large candidate sets
CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_teacher_user_id
  ON teacher_alumni_links (teacher_user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_alumni_links_alumni_user_id
  ON teacher_alumni_links (alumni_user_id);

-- Follows relationship: used in feed following filter subquery
-- and explore suggestions NOT EXISTS check
CREATE INDEX IF NOT EXISTS idx_follows_follower_following
  ON user_follows (follower_id, following_id);

-- Job applications: opportunity inbox queries pending/reviewed applications
CREATE INDEX IF NOT EXISTS idx_job_applications_job_poster_status
  ON job_applications (job_id, applicant_id, status);

-- Mentorship requests: explore suggestions scoring and opportunity inbox
-- filter by status with OR across requester/mentor columns
CREATE INDEX IF NOT EXISTS idx_mentorship_requests_requester_status
  ON mentorship_requests (requester_id, status);
CREATE INDEX IF NOT EXISTS idx_mentorship_requests_mentor_status
  ON mentorship_requests (mentor_id, status);

COMMIT;
