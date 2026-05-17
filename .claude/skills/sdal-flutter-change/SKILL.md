---
name: sdal-flutter-change
description: Use for SDAL Flutter app changes in mobile/flutter_sdal, including UI, routing, Riverpod state, Dio API clients, auth/session storage, localization, media upload/crop, admin screens, and push notifications.
---

# SDAL Flutter Change

## When To Use
- Flutter/Dart work under `mobile/flutter_sdal/lib`.
- UI, state, routing, API repositories, auth/session, localization, upload/crop, admin screens, push notifications.

## Workflow
1. Restate the mobile objective and affected feature.
2. Search first; do not scan entire repo.
3. Inspect `pubspec.yaml`, `lib/main.dart`, providers/router, then only relevant feature files.
4. Check repository/API usage before UI/model changes.
5. For user-facing strings, update `lib/l10n/app_tr.arb` and `app_en.arb`; never generated localization files.
6. Plan the smallest safe patch.
7. Run `flutter analyze` or targeted tests when feasible.
8. Summarize files, checks, and visual/API risks.

## Search Strategy
- `rg` for widget, provider, route, endpoint, and field names.
- Exclude generated `*.g.dart`, `*.freezed.dart`, and `lib/l10n/generated`.

## Inspect Areas
- `lib/main.dart`, `lib/app/app.dart`, `lib/app/providers.dart`.
- `lib/core/routing/app_router.dart`, `lib/core/network/api_client.dart`, `lib/core/session/*`.
- `lib/features/<feature>/{data,application,presentation}`.
- `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, `l10n.yaml`.

## Safety Rules
- Do not edit generated Dart.
- Check backend response shape before assuming fields.
- Do not rewrite unrelated widgets/providers.

## Validation
- `cd mobile/flutter_sdal && flutter analyze`
- `cd mobile/flutter_sdal && flutter test <target>` when focused.

## Output Format
- Files changed, ARB status, checks run, API/visual risks.
