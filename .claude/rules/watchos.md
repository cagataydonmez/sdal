---
paths:
  - "mobile/flutter_sdal/ios/**"
  - "mobile/flutter_sdal/lib/core/watch/**"
  - "mobile/flutter_sdal/tool/**"
---

# watchOS Rules

- Treat `Runner.xcodeproj/project.pbxproj`, entitlements, bundle IDs, signing, and icons as fragile.
- For session issues, trace Flutter `core/watch`, iOS `Runner/WatchBridge.swift`, and watch `SdalWatch/Networking`.
- Do not remove watch icon/build phase logic without TestFlight-specific evidence.
- Prefer focused Swift changes over project-file edits.
- Mark signing/archive/TestFlight results `UNVERIFIED` unless actually built or archived.
