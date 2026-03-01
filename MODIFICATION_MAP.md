# Modification Map (Fast Edit Guide)

Purpose: quickly find the right file before making changes, with minimal search/token usage.

## Backend (server)

### Bootstrap and app wiring
- Server startup/listen + process handlers + websocket attach:
  - `server/index.js`
- Express app composition (middleware order + routes registration):
  - `server/app.js`

### Config
- ESM dirname/path helpers:
  - `server/config/paths.js`
- Runtime env config (`port`, `isProd`, `uploadsDir`, `legacyDir`, `ONLINE_HEARTBEAT_MS`):
  - `server/config/env.js`

### Middleware
- Session cookie/session behavior:
  - `server/middleware/session.js`
- Presence heartbeat (`uyeler` update, best-effort):
  - `server/middleware/presence.js`
- HTTP finish logging (`writeAppLog` / `writeLegacyLog` usage):
  - `server/middleware/requestLogging.js`
- `/uploads/images` immutable cache header + static mount:
  - `server/middleware/staticUploads.js`

### Static legacy mounts
- `/legacy` and `/smiley` static serving:
  - `server/routes/staticLegacy.js`

## Frontend (modern admin)

### Main admin orchestration (data loading, state, actions)
- Core admin page logic:
  - `frontend-modern/src/pages/AdminPage.jsx`

### Extracted admin UI components (presentational)
- Access denied panel:
  - `frontend-modern/src/components/admin/AccessDeniedView.jsx`
- Admin login panel:
  - `frontend-modern/src/components/admin/AdminLoginView.jsx`
- Header + hamburger menu:
  - `frontend-modern/src/components/admin/AdminPageHeader.jsx`
- Preview modal renderer:
  - `frontend-modern/src/components/admin/AdminPreviewModal.jsx`

## Frontend CSS split map

- Aggregator (import order owner):
  - `frontend-modern/src/styles.css`
- Theme/base variables + resets:
  - `frontend-modern/src/base.css`
- Layout/shell/grid/nav structure:
  - `frontend-modern/src/layout.css`
- Shared UI components styles (`btn`, `panel`, `input`, cards, stories, messenger):
  - `frontend-modern/src/components.css`
- Admin-specific styles (`admin-*`, db/admin view blocks):
  - `frontend-modern/src/admin.css`
- Utility + responsive/media-query heavy tail:
  - `frontend-modern/src/utilities.css`

## Quick routing rule (what to edit first)

- “Server startup/listen issue” -> `server/index.js`
- “Middleware order/session/presence/log behavior” -> `server/app.js` + matching middleware file
- “Legacy/static/upload path behavior” -> `server/config/env.js`, `server/routes/staticLegacy.js`, `server/middleware/staticUploads.js`
- “Admin API/state/action bug” -> `frontend-modern/src/pages/AdminPage.jsx`
- “Admin UI block markup only” -> `frontend-modern/src/components/admin/*`
- “Admin visual/CSS issue” -> `frontend-modern/src/admin.css` (then `components.css` if shared)

## Safety note

For backend behavior-sensitive edits, preserve middleware order in `server/app.js`:
1. `morgan`
2. `cookieParser`
3. `json/urlencoded`
4. session
5. presence
6. request logging
7. static mounts

