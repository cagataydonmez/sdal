---
name: sdal-watchos-change
description: Use for SDAL iOS/watchOS work, WatchConnectivity/session sync, SwiftUI watch views, watch API client, icons, entitlements, signing, embedded watch app packaging, and TestFlight issues.
---

# SDAL watchOS Change

## When To Use
- Any change under `mobile/flutter_sdal/ios` involving Runner, SdalWatch, notification extension, Xcode project, signing, icons, or TestFlight.
- Flutter-to-watch session sync via `core/watch/watch_bridge_service.dart`.

## Workflow
1. Restate the watch/iOS issue and whether it affects build, packaging, runtime sync, or UI.
2. Search targeted paths; do not scan entire repo.
3. Map both sides of session flow when auth is involved: Flutter method channel, iOS bridge, watch session manager, watch API client.
4. Treat Xcode project, entitlements, bundle IDs, embedded content, and icons as fragile.
5. Plan before editing; prefer Swift/source changes over project-file changes when possible.
6. Run the narrowest feasible build/analyze command or mark as `UNVERIFIED`.
7. Summarize exact risk around signing/TestFlight if not locally verified.

## Search Strategy
- `rg -n "WatchBridge|WatchConnectivity|WCSession|SdalWatch|bundle|AppIcon|CODE_SIGN|PRODUCT_BUNDLE_IDENTIFIER" mobile/flutter_sdal/ios mobile/flutter_sdal/lib/core/watch`
- Use `sed -n` for specific Swift methods or project-file sections.

## Inspect Areas
- Flutter bridge: `mobile/flutter_sdal/lib/core/watch/watch_bridge_service.dart`.
- iOS bridge: `mobile/flutter_sdal/ios/Runner/WatchBridge.swift`, `Runner/AppDelegate.swift`.
- Watch networking/session: `mobile/flutter_sdal/ios/SdalWatch/Networking/WatchSessionManager.swift`, `WatchAPIClient.swift`.
- Watch UI/models: `mobile/flutter_sdal/ios/SdalWatch/{App,ViewModels,Views,Models}`.
- Project/signing: `mobile/flutter_sdal/ios/Runner.xcodeproj/project.pbxproj`, entitlements, `Info.plist`.
- Helpers: `mobile/flutter_sdal/README.md`, `mobile/flutter_sdal/tool/*`.

## Safety Rules
- Do not casually edit `project.pbxproj`, entitlements, icons, or generated Flutter xcconfig files.
- Do not remove icon injection/build phase logic without proving TestFlight impact.
- Keep watch API changes compatible with backend and iOS bridge.

## Validation
- `cd mobile/flutter_sdal && flutter analyze` for Dart-side changes.
- iOS/watch build command: use README/helper scripts when applicable; exact watch-only command is `Needs confirmation`.
- Mark signing/TestFlight behavior `UNVERIFIED` unless actually built/archive-validated.

## Output Format
- Runtime/build area touched.
- Files changed.
- Build/signing checks run or skipped.
- Remaining TestFlight risk.
