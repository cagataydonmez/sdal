# Decisions

Initial decision log for future AI agents. Do not invent decisions; append only when confirmed by code, docs, or the user.

## Confirmed From Repo
- Backend runtime is Node.js/Express using ES modules.
- Backend supports both SQLite and Postgres through `server/db.js`.
- Production deployment target is DigitalOcean via `.github/workflows/deploy.yml` and `ops/deploy-systemd.sh`.
- Flutter mobile app uses Riverpod, GoRouter, Dio, persistent cookie jar, Firebase Auth/App Check/Messaging, and ARB localization.
- Turkish ARB (`app_tr.arb`) is the localization template.
- watchOS app is embedded in the iOS project and receives session context from the Flutter/iOS app through WatchConnectivity.
- Upload/media handling has a local provider and S3-compatible Spaces provider abstraction.

## Needs Confirmation
- Whether `frontend-classic` is still user-facing in production or only retained for legacy pages.
- Whether Docker Compose is used for active local development or only historical/deploy support.
- Exact preferred watchOS/TestFlight build command.
- Whether new Flutter user-facing strings should always be added to both Turkish and English ARB in the same patch.

## Future Entries
Append new decisions in this format:

```md
## YYYY-MM-DD - Short Title
- Decision:
- Context:
- Impacted paths:
- Source:
```
