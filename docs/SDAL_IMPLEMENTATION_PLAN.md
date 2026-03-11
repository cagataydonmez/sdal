# SDAL Professional Social Hub – Implementation Plan

This document audits the current implementation against the roadmap and provides actionable plans for Phase 1, 1.5, 2, and 3.

## 2026 Social Hub Integration Addendum

- Detailed architecture addendum for Alumni Social Hub & Networking Ecosystem:
  - `docs/alumni-social-hub-networking-ecosystem.md`
- Covers:
  1. PostgreSQL schema (including teacher-alumni relationship model)
  2. Year-based feed API endpoint design and ranking logic
  3. Verification workflow for trusted closed-network onboarding
  4. Incremental migration mapping to existing SDAL tables/endpoints and backward compatibility path

## Current Implementation Snapshot (2026-03)

The codebase has progressed beyond the initial draft plan. In addition to the Phase 1 items above, these social-hub networking capabilities are already live:

- `jobs` module is implemented end-to-end:
  - API: `GET/POST/DELETE /api/new/jobs`
  - UI: `frontend-modern/src/pages/JobsPage.jsx`
- Professional profile extensions are active (`sirket`, `unvan`, `uzmanlik`, `linkedin_url`, `universite_bolum`, `mentor_opt_in`, `mentor_konulari`) in profile update and member directory payloads.
- Mentorship workflow is active:
  - `POST /api/new/mentorship/request/:id`
  - `GET /api/new/mentorship/requests`
  - `POST /api/new/mentorship/accept/:id`
  - `POST /api/new/mentorship/decline/:id`
- Teacher–alumni relationship graph API is active:
  - `POST /api/new/teachers/network/link/:teacherId`
  - `GET /api/new/teachers/network`

Remaining work is now mostly UX refinement, ranking quality, and operational hardening rather than first-time endpoint creation.

---

## Phase 1 Kickoff Execution (2026-03)

- Added year-mode feed contract support on existing endpoint:
  - `/api/new/feed?mode=year` resolves to cohort/community feed without breaking existing `scope` and `feedType` callers.
  - `/api/new/feed?mode=global` forces main/global feed.
- Added dedicated module gate for year feed:
  - New module key `year_feed` for runtime controls and admin module settings.
  - Year-mode requests now return `MODULE_CLOSED` when this module is disabled.
- Seeded `year_feed` in default module settings migration and contract test bootstrap.
- Extended Phase 1 contract suite to validate:
  - year-mode feed returns cohort post,
  - year feed module lock returns 403 with correct module key.

## Phase 1: Strengthen Alumni Network (MVP) – Audit & Gaps

### ✅ Implemented Correctly

| Task | Status | Notes |
|------|--------|-------|
| **Graduation year (mezuniyetyili)** | ✅ | Field exists in schema, validated in `/api/register` (rejects `'0'`), used in feed/explore |
| **Alumni Verification flow** | ✅ | `verification_requests` table, admin queue at `/api/new/admin/verification-requests`, approve/reject |
| **Cohort Engine** | ✅ | `assignUserToCohort()` auto-creates `{year} Mezunları` groups, assigns on verification approval |
| **Cohort Feeds** | ✅ | Feed scope `cohort` in `/api/new/feed`, FeedPage has "Dönemim" tab |
| **Alumni Directory** | ✅ | `/api/members` with filters: term, gradYear, location, profession, verified, withPhoto, online, relation, sort |
| **ExplorePage filters** | ✅ | gradYear, location, profession, verified, withPhoto, online, sort |

### ⚠️ Partially Implemented / Gaps

| Task | Gap | Action |
|------|-----|--------|
| ~~Blueprint~~ | ~~`sdal_professional_hub_strategy.md` does not exist~~ | ✅ Created at `docs/sdal_professional_hub_strategy.md` |
| ~~Graduation year mandatory in UI~~ | ~~RegisterPage select has empty default~~ | ✅ Placeholder "Mezuniyet yılı seçiniz (Zorunlu)" with `value="0"`, `required` |
| ~~KVKK consents~~ | ~~Checkboxes not sent/stored~~ | ✅ `kvkk_consent_at`, `directory_consent_at` in DB; required in register; stored on signup |
| **Verification diploma/proof** | ✅ Optional proof upload now supported | `proof_path` stored in `verification_requests`; profile supports JPG/PNG/PDF upload; admin queue includes proof link |
| **Cohort assignment on activation** | Cohort assigned only on verification approval | Roadmap says "assign incoming **verified** users" – current behavior is correct |

---

## Phase 1.5: Data Management & Privacy – Audit & Gaps

### ✅ Implemented Correctly

| Task | Status | Notes |
|------|--------|-------|
| **Legacy image wipe script** | ✅ | `server/scripts/wipe-legacy-media.mjs` – truncates legacy image cols, purges old dirs |
| **Recursive Member Deletion** | ✅ | `hardDeleteUser()` + `DELETE /api/admin/users/:id` + `DELETE /api/new/admin/members/:id` |
| **Variant pipeline** | ✅ | thumb/feed/full, `image_records`, PostCard/StoryBar use variants with legacy fallback |

### ⚠️ Gaps

| Task | Gap | Action |
|------|-----|--------|
| **Drop legacy fallback in frontend** | PostCard/StoryBar still fall back to `post.image` when no variants | After wipe is run, optionally remove legacy fallback to reduce dead code (low priority) |
| **Consent storage for data deletion** | No explicit "request data deletion" flow or consent tracking | Add `data_deletion_requested_at` or similar if GDPR-style right-to-erasure is required |

---

## Phase 1 – Implementation Plan (Missing Parts)

### 1. Create Blueprint (`sdal_professional_hub_strategy.md`)

- Merge roadmap phases, research notes, and technical decisions
- Include: 3-layer model (Community, Professional, Association), phased rollout, success metrics

### 2. KVKK & Directory Consent Storage

**DB migration:**

```sql
ALTER TABLE uyeler ADD COLUMN kvkk_consent_at TEXT;
ALTER TABLE uyeler ADD COLUMN directory_consent_at TEXT;
```

**Backend (`/api/register`):**

- Accept `kvkk_consent` and `directory_consent` (boolean) in request body
- Reject if either is false/missing
- Store `new Date().toISOString()` in `kvkk_consent_at` and `directory_consent_at` on insert

**Frontend (RegisterPage):**

- Add `kvkk_consent: false`, `directory_consent: false` to form state
- Bind checkboxes to state; include in `JSON.stringify(form)` on submit

### 3. Graduation Year UX

- Change first `<option>` to `value="0"` with label "Mezuniyet yılı seçiniz (Zorunlu)"
- Ensure backend already rejects `mezuniyetyili == '0'` (done)

### 4. Verification Proof (Optional Enhancement)

- Add `proof_path TEXT` to `verification_requests`
- Add upload endpoint for proof (e.g. diploma scan)
- Admin UI: show proof link before approve/reject

---

## Phase 1.5 – Implementation Plan (Remaining)

- **Optional:** Remove legacy `post.image` / `active.image` fallback from PostCard and StoryBar after wipe is confirmed in production
- **Optional:** Add "Verilerimi Sil" (Request Data Deletion) user-facing flow if required for compliance

---

## Phase 2: Professional Networking (V2) – Implementation Plan

### 2.1 Profile Extensions

**DB migration:**

```sql
ALTER TABLE uyeler ADD COLUMN sirket TEXT;
ALTER TABLE uyeler ADD COLUMN unvan TEXT;
ALTER TABLE uyeler ADD COLUMN uzmanlik TEXT;
ALTER TABLE uyeler ADD COLUMN linkedin_url TEXT;
ALTER TABLE uyeler ADD COLUMN universite_bolum TEXT;
ALTER TABLE uyeler ADD COLUMN mentor_opt_in INTEGER DEFAULT 0;
ALTER TABLE uyeler ADD COLUMN mentor_konulari TEXT;
```

**Backend:**

- Include new fields in profile GET/PUT
- Add to `/api/members` and explore filters

**Frontend:**

- EditProfile.jsx: add Company, Title, Skills, LinkedIn, Mentor opt-in, Mentor topics
- ProfilePage.jsx: display professional badge (e.g. "Title @ Company")

### 2.2 Mutual Connections (Refactor Follows)

**DB:**

```sql
CREATE TABLE IF NOT EXISTS connection_requests (
  id INTEGER PRIMARY KEY,
  sender_id INTEGER,
  receiver_id INTEGER,
  status TEXT DEFAULT 'pending',
  created_at TEXT,
  updated_at TEXT
);
```

**API:**

- `POST /api/new/connections/request/:id` – create request
- `POST /api/new/connections/accept/:id` – accept → insert bi-directional into `follows`
- `POST /api/new/connections/ignore/:id` – set status ignored

**Frontend:**

- Replace "Takip Et" with "Bağlantı Kur" for verified alumni
- Show pending/accept/ignore UI

### 2.3 Career & Job Board

**DB:**

```sql
CREATE TABLE IF NOT EXISTS jobs (
  id INTEGER PRIMARY KEY,
  poster_id INTEGER,
  company TEXT,
  title TEXT,
  description TEXT,
  location TEXT,
  job_type TEXT,
  link TEXT,
  created_at TEXT
);
```

**API:**

- `GET /api/new/jobs` – list with filters
- `POST /api/new/jobs` – create (auth)
- `DELETE /api/new/jobs/:id` – delete own

**Frontend:**

- JobsPage.jsx – list + "İş İlanı Ver" modal

### 2.4 Expert Directory

- Extend ExplorePage filters: `uzmanlik`, `unvan`
- Add "Mentors" filter (mentor_opt_in = 1)

### 2.5 Mentorship MVP

- Use `mentor_opt_in`, `mentor_konulari` from profile
- Filterable "Mentors" view in directory


### 2.6 Teacher–Alumni Network Graph

**API:**

- `POST /api/new/teachers/network/link/:teacherId` – alumni can add a teacher link (`relationship_type`, optional `class_year`, `notes`)
- `GET /api/new/teachers/network` – list graph edges in two directions:
  - `direction=my_teachers` (default, for alumni)
  - `direction=my_students` (for teacher-facing views)
- Filters: `relationship_type`, `class_year`, `limit`, `offset`

**Backend notes:**

- Add `teacher_alumni_links` relational table (idempotent create guard for SQLite runtimes).
- Deduplicate links by `(teacher_user_id, alumni_user_id, relationship_type, class_year)`.
- Emit teacher notification on successful link creation to keep trust graph active.

### 2.7 Job Applications (Networking Loop)

**API:**

- `POST /api/new/jobs/:id/apply` – authenticated member applies to a job post (optional `cover_letter`)
- `GET /api/new/jobs/:id/applications` – poster/admin lists applicants for a job

**Backend notes:**

- Add `job_applications` table with dedupe constraint: `UNIQUE(job_id, applicant_id)`.
- Block self-application and duplicate applications with explicit conflict codes.
- Emit a notification to the job poster on new application.

---

## Phase 3: Association Infrastructure (V3) – Implementation Plan

### 3.1 Membership Tiers

- Add `membership_tier TEXT` (e.g. 'free_alumni', 'paid_member') to `uyeler`
- Gate features by tier

### 3.2 Donations & Membership Fees

- Integrate payment gateway (Stripe, iyzico, etc.)
- Store transactions; link to membership_tier

### 3.3 Committees & Working Groups

- New `committees` table; `committee_members` with roles
- Secured workspaces (private groups with committee flag)

### 3.4 Voting & Polling (e-Genel Kurul)

- `polls` table; `poll_votes`; admin-only creation
- Results visibility rules

### 3.5 Volunteer Management

- `volunteer_events`; sign-up; assignment tracking

### 3.6 Alumni Map

- Geographic overlay (e.g. Mapbox/Leaflet)
- Filter members by `sehir` / coordinates if added

---

## Summary Checklist

| Phase | Item | Status |
|-------|------|--------|
| **1** | Blueprint doc | ❌ Create |
| **1** | graduation_year mandatory UX | ⚠️ Tighten |
| **1** | KVKK + directory consent storage | ❌ Implement |
| **1** | Verification proof upload | ✅ Implemented |
| **1.5** | Legacy wipe script | ✅ Done |
| **1.5** | Recursive member delete | ✅ Done |
| **2** | Profile extensions | ✅ Implemented (profile GET/PUT + directory payload fields) |
| **2** | connection_requests | ✅ Implemented (`/api/new/connections/*`, DB + contract test) |
| **2** | Jobs table + JobsPage | ✅ Implemented (`/api/new/jobs`, `frontend-modern/src/pages/JobsPage.jsx`) |
| **2** | Expert/Mentor filters | ✅ Implemented (`/api/members` + Explore mentors filter) |
| **2** | Mentorship requests workflow | ✅ Implemented (`/api/new/mentorship/*`, runtime schema + contract test) |
| **2** | Teacher–Alumni network graph APIs | ✅ Implemented (`/api/new/teachers/network*`, contract test) |
| **3** | All items | ❌ Plan only |

## Next Delivery Slice (Social Hub Networking Ecosystem)

### Progress update (2026-03)

- ✅ Teacher graph browsing and link creation history page is available at `/new/network/teachers`.
- ✅ Teacher graph entry points are now exposed from both Member Detail and Explore cards for teacher profiles.
- ✅ Teacher users now have a direct profile CTA to open teacher network management.
- ✅ Connection and mentorship request hardening is active:
  - Per-user rate limits on `POST /api/new/connections/request/:id` and `POST /api/new/mentorship/request/:id`
  - Cooldown after ignored/declined requests to prevent immediate re-spam
- ✅ Teacher graph contract hardening:
  - Teacher-link target validation (`INVALID_TEACHER_TARGET`)
  - Strict class year validation (`INVALID_CLASS_YEAR`) on teacher-link create/list APIs

1. **Networking UX surface**
   - Add dedicated frontend page for teacher–alumni graph browsing and link creation history.
   - Expose teacher graph entry points from profile and explore views.
2. **Connection quality and trust scoring**
   - Add weighted affinity score for suggestions (same cohort, shared groups, mentorship overlap, teacher links).
   - Introduce request abuse controls (rate limits + cooldown) for connection and mentorship endpoints.
3. **Operational analytics**
   - Add cohort/network funnel metrics: request sent → accepted → active interaction.
   - Add admin observability cards for mentorship and teacher-link adoption.
4. **Contract hardening**
   - Expand phase contract suite to cover edge cases: teacher-link authorization, class year validation, mentorship decline-retry semantics.

---

*Last updated: 2026-03*
