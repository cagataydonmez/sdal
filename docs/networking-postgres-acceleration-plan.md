# Networking Postgres Acceleration Plan

## Goal

Reduce PostgreSQL page-load latency for the heaviest networking surfaces, especially:

- Network Hub
- Teacher Network
- Admin networking analytics

Target outcome:

- noticeably faster first content render
- lower backend query time
- lower pool contention under concurrent traffic

## Scope

Focus only on the networking surfaces currently reported as slow on PostgreSQL:

- `/api/new/network/hub`
- `/api/new/explore/suggestions`
- `/api/new/connections/requests`
- `/api/new/teachers/network`
- `/api/new/teachers/options`
- `/api/new/admin/network/analytics`

Do not broaden into unrelated modules until these endpoints are measured and improved.

## Phase 1: Baseline Measurement

1. Add timing instrumentation around the heavy networking endpoints.
2. Break down `/api/new/network/hub` into internal timings:
   - inbox
   - metrics
   - discovery
   - pending connection maps
3. Capture PostgreSQL pool state during slow requests:
   - totalCount
   - idleCount
   - waitingCount
4. Record payload sizes for hub and teacher-network responses.
5. Build a before-state benchmark table for:
   - cold request latency
   - warm request latency
   - repeated concurrent requests

Deliverable:

- one benchmark note with endpoint-by-endpoint timings and bottleneck ranking

## Phase 2: Query Audit

1. Run `EXPLAIN ANALYZE` for the slowest networking queries on PostgreSQL.
2. Prioritize:
   - teacher options query
   - teacher network list query
   - explore suggestions candidate query
   - networking analytics aggregations
3. Identify:
   - correlated subqueries
   - sequential scans on large tables
   - sort-heavy plans
   - repeated counts on the same tables
   - application-side full-set scoring that should be narrowed earlier

Deliverable:

- a short query audit showing which plans are the worst and why

## Phase 3: Teacher Network Rewrite

1. Rewrite `teachers/options` to remove correlated subqueries.
2. Replace repeated per-row counts with:
   - pre-aggregated CTEs, or
   - `LEFT JOIN` + grouped summaries
3. Ensure `include_id` follows the same optimized path.
4. Re-test before and after on PostgreSQL.

Expected win:

- lower latency for teacher picker
- fewer repeated scans of `teacher_alumni_links`

## Phase 4: Network Hub Slimming

1. Reduce work done inside `/api/new/network/hub`.
2. Keep initial render data minimal and defer non-critical sections.
3. Split heavy discovery work from must-render inbox data if needed.
4. Avoid recomputing suggestion and connection maps when unchanged.
5. Consider separate lazy refresh for:
   - suggestions
   - metrics
   - telemetry-derived summaries

Expected win:

- faster first paint on Network Hub
- less backend CPU per hub visit

## Phase 5: Suggestion Pipeline Reduction

1. Shrink the candidate set before JavaScript scoring.
2. Prefer SQL pre-filtering for:
   - active users only
   - non-banned users only
   - not already followed
   - optionally same cohort / city / school relevance windows
3. Keep application scoring only for the top candidate slice.
4. Revisit cache keys and cache hit rate for explore suggestions.

Expected win:

- lower memory and CPU pressure in suggestion generation
- lower total response time for Network Hub discovery

## Phase 6: Index Pass

Add or adjust PostgreSQL indexes only after the real slow queries are confirmed.

Likely candidates:

- `teacher_alumni_links (teacher_user_id, review_status, created_at desc)`
- `teacher_alumni_links (alumni_user_id, review_status, created_at desc)`
- `connection_requests (receiver_id, status, updated_at desc)`
- `connection_requests (sender_id, status, updated_at desc)`
- `mentorship_requests (mentor_id, status, updated_at desc)`
- `mentorship_requests (requester_id, status, updated_at desc)`
- `follows (follower_id, following_id)`
- `follows (following_id, follower_id)`
- `notifications (user_id, type, created_at desc)`
- `group_members (user_id, group_id)`

Rules:

- create only indexes justified by `EXPLAIN ANALYZE`
- prefer composite indexes that match actual filter + sort shape

## Phase 7: Caching and Summaries

1. Add short TTL caches for stable-but-frequently-requested networking payloads.
2. Move expensive analytics aggregations to background rebuilds when possible.
3. Consider lightweight summary tables for:
   - teacher link counts
   - pending networking counts
   - top-level hub metrics

Expected win:

- less request-time aggregation
- more predictable hub latency under load

## Phase 8: Frontend Loading Strategy

1. Keep first render focused on visible content.
2. Defer non-critical sections until after initial content settles.
3. Avoid one large blocking bootstrap when the page can hydrate incrementally.
4. Review repeated refresh patterns and unnecessary background reloads.

Targets:

- `frontend-modern/src/hooks/useNetworkingHubState.js`
- `frontend-modern/src/pages/NetworkingHubPage.jsx`
- teacher network page client fetch behavior

## Phase 9: Pool and Runtime Tuning

Only do this after query and index work is in place.

Review:

- `PGPOOL_MAX`
- `PGPOOL_MIN`
- `PGPOOL_IDLE_MS`
- `PGPOOL_CONNECT_TIMEOUT_MS`
- `PG_STATEMENT_TIMEOUT_MS`
- `PG_QUERY_TIMEOUT_MS`

Check:

- queueing under concurrent requests
- connection starvation
- timeouts masking slow plans

## Validation Strategy

After each phase:

1. benchmark the affected endpoints again
2. compare before and after latency
3. confirm no functional regression on networking pages
4. verify pool waiting count did not worsen

Minimum reporting after each implementation pass:

- what changed
- measured latency delta
- remaining hotspots
- risks

## Recommended Execution Order

1. Phase 1 baseline measurement
2. Phase 2 query audit
3. Phase 3 teacher network rewrite
4. Phase 4 network hub slimming
5. Phase 5 suggestion pipeline reduction
6. Phase 6 targeted indexes
7. Phase 7 caching and summaries
8. Phase 8 frontend loading strategy
9. Phase 9 pool tuning

## Non-Goals

- broad repository-wide PostgreSQL tuning without measurements
- changing unrelated modules before networking bottlenecks are fixed
- adding indexes speculatively without plan evidence
