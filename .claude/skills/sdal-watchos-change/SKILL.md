---
name: sdal-watchos-change
description: Use for SDAL iOS/watchOS work, WatchConnectivity/session sync, SwiftUI watch views, watch API client, icons, entitlements, signing, embedded watch app packaging, and TestFlight issues.
---

# SDAL watchOS Change

## When To Use
- Work under `mobile/flutter_sdal/ios` involving Runner, SdalWatch, notification extension, Xcode project, signing, icons, or TestFlight.
- Flutter-to-watch session sync via `core/watch/watch_bridge_service.dart`.

## Workflow
1. Restate whether the issue is build, packaging, runtime sync, or UI.
2. Search targeted paths; do not scan entire repo.
3. Map session flow across Flutter method channel, iOS bridge, watch session manager, and watch API client.
4. Treat Xcode project, entitlements, bundle IDs, embedded content, and icons as fragile.
5. Plan before editing.
6. Run the narrowest feasible build/analyze command or mark `UNVERIFIED`.
7. Summarize signing/TestFlight risk if not verified.

## Search Strategy
- Search for `WatchBridge`, `WCSession`, `SdalWatch`, `AppIcon`, `CODE_SIGN`, and bundle IDs.
- Use focused Swift/project-file ranges.

## Inspect Areas
- `lib/core/watch/watch_bridge_service.dart`.
- `ios/Runner/WatchBridge.swift`, `Runner/AppDelegate.swift`.
- `ios/SdalWatch/Networking/WatchSessionManager.swift`, `WatchAPIClient.swift`.
- `ios/SdalWatch/{App,ViewModels,Views,Models}`.
- `ios/Runner.xcodeproj/project.pbxproj`, entitlements, `Info.plist`, `tool/*`.

## Safety Rules
- Do not casually edit `project.pbxproj`, entitlements, icons, or generated xcconfig files.
- Keep watch API changes compatible with backend and iOS bridge.

## Validation
- `cd mobile/flutter_sdal && flutter analyze` for Dart-side changes.
- Exact watch-only build command: Needs confirmation.

## Output Format
- Runtime/build area, files changed, checks, remaining TestFlight risk.
