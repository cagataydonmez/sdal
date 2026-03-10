# Alumni Social Hub & Networking Ecosystem Integration Plan

This document integrates the proposed **Alumni Social Hub** strategy into the existing SDAL modern platform roadmap, with practical schema and API design that can be introduced incrementally.

---

## 1) Product Intent (Why) translated into implementable platform rules

### 1.1 Nostalgia + Opportunity dual-loop
- **Nostalgia loop:** Year-based circles, story memories, yearbook archives, teacher appreciation.
- **Opportunity loop:** Career directory, mentorship, job board, events.
- Product rule: every user home view should expose both loops (social + professional) with role-aware ordering.

### 1.2 Year-first social graph
- Primary social partition is `class_year` (cohort).
- Feed rank should favor:
  1. Same class year content,
  2. School-wide official content,
  3. Cross-year high relevance content (mentorship/job/event).

### 1.3 Trust-based closed network
- No full participation without verification.
- Unverified users can only access restricted onboarding surfaces.
- Students get read-only access for Career/Mentorship sections until graduation + alumni verification.

---

## 2) RBAC & Permissions Matrix

| Capability | Alumni | Teacher | Admin | Student |
|---|---:|---:|---:|---:|
| View global feed | ✅ | ✅ | ✅ | ✅ (restricted content) |
| Post in own class circle | ✅ | ✅ (all circles) | ✅ | ❌ |
| Post in Teacher's Podium | ❌ | ✅ | ✅ | ❌ |
| Browse directory | ✅ | ✅ | ✅ | ✅ (limited fields) |
| Apply to alumni jobs | ✅ | ✅ (optional) | ✅ | ✅ (internship tracks only) |
| Manage users/verification | ❌ | ❌ | ✅ | ❌ |
| Access KVKK audit logs | ❌ | ❌ | ✅ | ❌ |

Implementation note:
- Keep existing role model but normalize permission checks via scoped policies (`role`, `verification_status`, `cohort_scope`).

---

## 3) Detailed PostgreSQL Schema (with Teacher–Alumni relationship)

> Designed for PostgreSQL 15+, compatible with incremental migration from current SDAL schema.

### 3.1 Enums

```sql
create extension if not exists citext;

create type user_role as enum ('student', 'alumni', 'teacher', 'admin');
create type verification_status as enum ('pending', 'under_review', 'verified', 'rejected', 'suspended');
create type mentorship_status as enum ('requested', 'accepted', 'declined', 'completed', 'cancelled');
create type post_scope as enum ('global', 'class_circle', 'teachers_podium', 'official');
create type visibility_scope as enum ('public_school', 'verified_only', 'class_only', 'teachers_only');
create type job_type as enum ('full_time', 'part_time', 'internship', 'contract', 'freelance');
```

### 3.2 Core identity tables

```sql
create table users (
  id bigserial primary key,
  email citext unique not null,
  phone_e164 varchar(20),
  password_hash text not null,
  role user_role not null,
  verification_status verification_status not null default 'pending',
  is_active boolean not null default true,
  is_private_profile boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_login_at timestamptz
);

create table alumni_profiles (
  user_id bigint primary key references users(id) on delete cascade,
  first_name varchar(80) not null,
  last_name varchar(80) not null,
  graduation_year int not null check (graduation_year between 1950 and 2100),
  university varchar(160),
  industry varchar(120),
  company varchar(160),
  title varchar(160),
  city varchar(120),
  country varchar(120),
  bio text,
  linkedin_url text,
  available_for_mentoring boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table teacher_profiles (
  user_id bigint primary key references users(id) on delete cascade,
  first_name varchar(80) not null,
  last_name varchar(80) not null,
  subject varchar(120) not null,
  years_active int4range not null,
  retired boolean not null default false,
  office_city varchar(120),
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table student_profiles (
  user_id bigint primary key references users(id) on delete cascade,
  first_name varchar(80) not null,
  last_name varchar(80) not null,
  expected_graduation_year int not null check (expected_graduation_year between 1950 and 2100),
  track varchar(120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### 3.3 Cohort and social grouping

```sql
create table class_circles (
  id bigserial primary key,
  class_year int not null unique check (class_year between 1950 and 2100),
  title varchar(120) generated always as ('Class of ' || class_year::text) stored,
  yearbook_cover_media_id bigint,
  created_at timestamptz not null default now()
);

create table class_circle_memberships (
  id bigserial primary key,
  class_circle_id bigint not null references class_circles(id) on delete cascade,
  user_id bigint not null references users(id) on delete cascade,
  role_in_circle varchar(24) not null default 'member',
  joined_at timestamptz not null default now(),
  unique(class_circle_id, user_id)
);
```

### 3.4 Teacher–Alumni relationship model

> Includes both direct mentorship and historical “was my teacher” association.

```sql
create table teacher_alumni_links (
  id bigserial primary key,
  teacher_user_id bigint not null references users(id) on delete cascade,
  alumni_user_id bigint not null references users(id) on delete cascade,
  relationship_type varchar(32) not null check (relationship_type in ('taught_in_class', 'mentor', 'advisor')),
  class_year int,
  notes text,
  confidence_score numeric(4,3) not null default 1.000,
  created_by bigint references users(id),
  created_at timestamptz not null default now(),
  -- expression uniqueness with nullable class_year should be enforced by unique index (below)
  unique(teacher_user_id, alumni_user_id, relationship_type, class_year)
);

create unique index uq_teacher_alumni_links_dedup
  on teacher_alumni_links (teacher_user_id, alumni_user_id, relationship_type, coalesce(class_year, -1));

create table mentorship_requests (
  id bigserial primary key,
  requester_user_id bigint not null references users(id) on delete cascade,
  mentor_user_id bigint not null references users(id) on delete cascade,
  status mentorship_status not null default 'requested',
  focus_area varchar(120),
  message text,
  requested_at timestamptz not null default now(),
  responded_at timestamptz,
  scheduled_at timestamptz,
  completed_at timestamptz,
  unique(requester_user_id, mentor_user_id, requested_at)
);
```

### 3.5 Content, stories, and feed entities

```sql
create table posts (
  id bigserial primary key,
  author_user_id bigint not null references users(id) on delete cascade,
  scope post_scope not null,
  class_circle_id bigint references class_circles(id) on delete set null,
  title varchar(200),
  body_markdown text not null,
  media_json jsonb not null default '[]'::jsonb,
  visibility visibility_scope not null default 'verified_only',
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table stories (
  id bigserial primary key,
  author_user_id bigint not null references users(id) on delete cascade,
  class_circle_id bigint references class_circles(id) on delete set null,
  media_url text not null,
  caption varchar(280),
  visibility visibility_scope not null default 'verified_only',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at)
);

create index idx_stories_expires_at on stories (expires_at);
```

### 3.6 Directory, jobs, events, archives

```sql
create table jobs (
  id bigserial primary key,
  posted_by_user_id bigint not null references users(id) on delete cascade,
  company varchar(160) not null,
  title varchar(180) not null,
  description text not null,
  location varchar(160),
  job_type job_type not null,
  is_alumni_priority boolean not null default true,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);

create table job_applications (
  id bigserial primary key,
  job_id bigint not null references jobs(id) on delete cascade,
  applicant_user_id bigint not null references users(id) on delete cascade,
  cover_letter text,
  cv_media_url text,
  created_at timestamptz not null default now(),
  unique(job_id, applicant_user_id)
);

create table events (
  id bigserial primary key,
  organizer_user_id bigint not null references users(id) on delete cascade,
  title varchar(180) not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  venue varchar(180),
  city varchar(120),
  ticket_url text,
  class_circle_id bigint references class_circles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table digital_archives (
  id bigserial primary key,
  class_circle_id bigint not null references class_circles(id) on delete cascade,
  uploaded_by_user_id bigint not null references users(id) on delete cascade,
  media_url text not null,
  media_type varchar(20) not null check (media_type in ('image', 'video', 'pdf')),
  caption text,
  created_at timestamptz not null default now()
);
```

### 3.7 Verification & compliance

```sql
create table verification_requests (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  declared_role user_role not null,
  graduation_year int,
  evidence_type varchar(40) not null,
  evidence_url text,
  national_id_hash char(64),
  status verification_status not null default 'pending',
  reviewer_user_id bigint references users(id),
  review_notes text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create table compliance_audit_logs (
  id bigserial primary key,
  actor_user_id bigint references users(id),
  action_key varchar(120) not null,
  entity_name varchar(80) not null,
  entity_id bigint,
  before_data jsonb,
  after_data jsonb,
  ip inet,
  user_agent text,
  created_at timestamptz not null default now()
);
```

### 3.8 Key indexes for year-based feed and directory

```sql
create index idx_alumni_profiles_grad_year on alumni_profiles (graduation_year);
create index idx_alumni_profiles_directory on alumni_profiles (graduation_year, city, industry, company);
create index idx_posts_feed_rank on posts (scope, class_circle_id, created_at desc) where deleted_at is null;
create index idx_posts_author on posts (author_user_id, created_at desc);
create index idx_class_circle_memberships_user on class_circle_memberships (user_id, class_circle_id);
create index idx_teacher_alumni_teacher on teacher_alumni_links (teacher_user_id, relationship_type);
create index idx_teacher_alumni_alumni on teacher_alumni_links (alumni_user_id, relationship_type);
```

---

## 4) API Endpoint Draft for Year-Based Feed

Base namespace: `/api/v2/feed`  
Auth: OAuth2 bearer token/session token  
Real-time fanout: Socket.io channels (`feed:global`, `feed:class:{year}`)

### 4.1 Read feed

#### `GET /api/v2/feed`
Query params:
- `mode=global|class` (default: `global`)
- `classYear=YYYY` (required when `mode=class`, optional override if teacher/admin)
- `cursor=<opaque>`
- `limit=10..50`

Behavior:
- `mode=class`: return posts scoped to user’s own class year unless teacher/admin requested explicit year.
- `mode=global`: return blended stream with ranking weights.

Response:
```json
{
  "items": [
    {
      "id": 991,
      "type": "post",
      "scope": "class_circle",
      "classYear": 2012,
      "author": { "id": 32, "name": "...", "role": "alumni" },
      "content": "...",
      "createdAt": "2026-03-01T10:01:00Z"
    }
  ],
  "nextCursor": "eyJjcmVhdGVkQXQiOiIyMDI2LTAzLTAxVDEwOjAxOjAwWiIsImlkIjo5OTF9"
}
```

#### `GET /api/v2/feed/stories`
Query params:
- `classYear` (optional)

Behavior:
- returns only non-expired stories (`expires_at > now()`)
- default mix = own class stories + official stories.

### 4.2 Create content

#### `POST /api/v2/feed/posts`
Rules:
- verified alumni/teacher/admin can create posts.
- students blocked from alumni-only circle posting.
- for `scope=teachers_podium`, role must be `teacher` or `admin`.

Payload:
```json
{
  "scope": "class_circle",
  "classYear": 2012,
  "title": "Reunion update",
  "bodyMarkdown": "...",
  "media": []
}
```

#### `POST /api/v2/feed/stories`
Rules:
- set `expiresAt = now() + interval '24 hour'` server-side.

### 4.3 Engagement endpoints

- `POST /api/v2/feed/posts/:postId/like`
- `DELETE /api/v2/feed/posts/:postId/like`
- `POST /api/v2/feed/posts/:postId/comments`
- `GET /api/v2/feed/posts/:postId/comments?cursor=...`

### 4.4 Year-based query logic (service layer pseudocode)

```ts
if (mode === 'class') {
  targetYear = requestedYear ?? viewer.classYear;
  assertCanAccessClassYear(viewer, targetYear); // teacher/admin all, alumni own, student restricted
  return fetchClassPosts(targetYear, cursor, limit);
}

return fetchGlobalRankedFeed({
  viewerId,
  weights: {
    sameYear: 0.55,
    official: 0.25,
    mentorshipCareer: 0.20
  },
  cursor,
  limit
});
```

### 4.5 Caching and realtime
- Redis key pattern:
  - `feed:class:{year}:{cursorHash}`
  - `feed:global:{viewerId}:{cursorHash}`
- TTL: 30–90 seconds for fast-moving feed pages.
- Invalidate cache on new post/story in affected scopes.
- Socket.io emits:
  - `feed.post.created`
  - `story.created`

---

## 5) Verification Workflow (Trusted closed network)

### 5.1 Entry points
- Web/mobile registration with declared role: `student`, `alumni`, `teacher`.
- User is created as `verification_status = pending`.

### 5.2 Evidence collection

#### Alumni evidence options
- School-issued student number + graduation year match.
- Diploma/transcript upload.
- Invite code from already verified alumni (risk-scored, not auto-approved).

#### Teacher evidence options
- Legacy HR roster match (name + tenure + subject).
- Institutional email domain verification.
- Manual admin verification for retired teachers.

### 5.3 Automated risk scoring
- Inputs: data match confidence, device fingerprint, velocity checks, invite graph trust.
- Outcomes:
  - `auto-verify` for high confidence,
  - `under_review` for medium,
  - `rejected` for low/suspicious.

### 5.4 Manual admin review console
- Queue split: `pending`, `under_review`, `appeals`.
- Reviewer sees masked PII by default; explicit reveal requires reason logging (KVKK audit).
- Actions:
  - Approve and assign role profile,
  - Reject with reason template,
  - Request additional evidence.

### 5.5 Post-verification provisioning
- Alumni:
  - create/get `class_circle` by graduation year,
  - auto-membership into circle,
  - unlock posting + full directory access.
- Teacher:
  - create teacher profile,
  - grant Teacher’s Podium permission,
  - enable all year-circle visibility.
- Student:
  - limited access maintained.

### 5.6 Controls & compliance
- Immutable `compliance_audit_logs` for every verification decision.
- Data retention policy for sensitive docs (e.g., 90 days then secure purge/hash-only record).
- Right-to-erasure flow with legal hold exceptions.
- Rate limiting + anomaly alerts for mass fake-signup attempts.

---

## 6) Suggested phased delivery on current SDAL stack

1. **Phase 1 (Identity first):** tables for `verification_requests`, profile splits, class circles, and RBAC policies.
2. **Phase 2 (Social):** year-based posts/stories endpoints + story TTL job + Teacher’s Podium.
3. **Phase 3 (Networking):** directory filters, mentorship requests, jobs/events, digital archives.
4. **Phase 4 (Realtime optimization):** Redis feed caches, Socket.io fanout, ranking iterations.

This allows delivery on current backend while preserving migration path to NestJS modules later.


---

## 7) Integration mapping for existing SDAL schema (incremental, no big-bang)

To avoid a risky full rewrite, map new entities to current SDAL naming and APIs in staged migrations:

| Target domain | Current SDAL table(s) | Proposed evolution |
|---|---|---|
| Identity | `users` / legacy `uyeler` | Keep `users` as source of truth; add missing role/verification enums via migration wrappers |
| Verification queue | `identity_verification_requests` / legacy `verification_requests` | Add evidence metadata + risk score columns instead of introducing a parallel queue |
| Cohorts | `groups`, `group_members` | Add `group_type='class_circle'` + `class_year` columns; only create `class_circles` view initially |
| Feed | `posts`, `stories` | Add `scope`, `class_circle_id`, `visibility`; keep old readers compatible with defaults |
| Teacher-Alumni links | *(new)* | Introduce `teacher_alumni_links` and `mentorship_requests` as standalone bounded context |
| Compliance logs | `audit_logs` | Extend with PII reveal reason + before/after payload masking strategy |

### 7.1 Migration order (recommended)
1. Add enum/types and nullable columns with defaults.
2. Backfill `class_year` from alumni graduation year where available.
3. Add new indexes concurrently.
4. Switch read path (`GET /feed`) to year-aware query.
5. Enable write path rules by role + verification status.

### 7.2 Backward compatibility notes
- Keep existing endpoints (`/api/new/feed`) as aliases while rolling out `/api/v2/feed`.
- For existing clients, default `mode=global`; silently ignore unknown fields in response for old app versions.
- Use feature flags (`feed_year_mode_enabled`, `teachers_podium_enabled`) for gradual rollout.

---

## 8) Concrete Year-Based Feed SQL (server-side reference)

### 8.1 Class feed query

```sql
select
  p.id,
  p.scope,
  c.class_year,
  p.author_user_id,
  p.body_markdown,
  p.media_json,
  p.created_at
from posts p
join class_circles c on c.id = p.class_circle_id
where p.deleted_at is null
  and p.scope = 'class_circle'
  and c.class_year = $1
order by p.created_at desc, p.id desc
limit $2;
```

### 8.2 Global blend query idea

```sql
with viewer as (
  select ap.graduation_year as class_year
  from alumni_profiles ap
  where ap.user_id = $1
),
ranked as (
  select
    p.*,
    c.class_year,
    (case when c.class_year = (select class_year from viewer) then 0.55 else 0 end) +
    (case when p.scope = 'official' then 0.25 else 0 end) +
    (case when p.scope in ('global','teachers_podium') then 0.20 else 0 end) as rank_score
  from posts p
  left join class_circles c on c.id = p.class_circle_id
  where p.deleted_at is null
)
select *
from ranked
order by rank_score desc, created_at desc, id desc
limit $2;
```

---

## 9) Verification workflow as API state machine

### 9.1 Endpoints
- `POST /api/v2/verification/requests`
- `POST /api/v2/verification/requests/:id/evidence`
- `POST /api/v2/admin/verification/:id/approve`
- `POST /api/v2/admin/verification/:id/reject`
- `POST /api/v2/admin/verification/:id/request-more`

### 9.2 Status transitions

```text
pending -> under_review -> verified
pending -> under_review -> rejected
rejected -> under_review (appeal)
verified -> suspended (fraud / policy)
```

### 9.3 Auto-provision hooks on approve
- If role=alumni: upsert alumni profile, upsert class circle membership.
- If role=teacher: upsert teacher profile, grant podium + all class visibility scopes.
- Always: write `compliance_audit_logs` with reviewer action and masked payload snapshot.
