# SDAL Professional Social Hub – Implementation Plan

This document audits the current implementation against the roadmap and provides actionable plans for Phase 1, 1.5, 2, and 3.

---

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
| **Verification diploma/proof** | Admin approves by status only; no file upload or proof attachment | Add optional `proof_url` / `proof_path` to `verification_requests`; admin can view before approving |
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
| **1** | Verification proof upload | ⚠️ Optional |
| **1.5** | Legacy wipe script | ✅ Done |
| **1.5** | Recursive member delete | ✅ Done |
| **2** | Profile extensions | ❌ Implement |
| **2** | connection_requests | ❌ Implement |
| **2** | Jobs table + JobsPage | ❌ Implement |
| **2** | Expert/Mentor filters | ❌ Implement |
| **3** | All items | ❌ Plan only |

---

*Last updated: 2026-02*
