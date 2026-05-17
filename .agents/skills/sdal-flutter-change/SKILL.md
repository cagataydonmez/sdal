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
3. Inspect `pubspec.yaml`, `lib/main.dart`, providers/router, then only the relevant feature files.
4. Check repository/API usage before UI or model changes.
5. For user-facing strings, update `lib/l10n/app_tr.arb` and `app_en.arb`; do not edit generated localization files.
6. Plan the smallest safe patch and avoid unrelated formatting churn.
7. Run `flutter analyze` or targeted tests when feasible.
8. Summarize files, checks, and visual/API risks.

## Search Strategy
- `rg -n "WidgetName|route|provider|endpoint|field" mobile/flutter_sdal/lib --glob '!**/*.g.dart' --glob '!**/*.freezed.dart'`
- `rg -n "AppLocalizations|hardcoded text" mobile/flutter_sdal/lib/features/<feature>`
- `rg -n "/api/path|fieldName" server frontend-modern/src mobile/flutter_sdal/lib`

## Inspect Areas
- App setup: `lib/main.dart`, `lib/app/app.dart`, `lib/app/providers.dart`.
- Routing: `lib/core/routing/app_router.dart`.
- API/session: `lib/core/network/api_client.dart`, `lib/core/session/*`.
- Feature modules: `lib/features/<feature>/{data,application,presentation}`.
- Localization: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, `l10n.yaml`.
- Media: `lib/core/media/pick_cropped_image.dart`, upload repositories.
- Push: `features/push_notifications`, `features/notifications`.

## Safety Rules
- Do not edit generated `*.g.dart`, `*.freezed.dart`, or `lib/l10n/generated`.
- Keep UI changes consistent with existing Cupertino-style app patterns.
- Check backend response shape before assuming fields.
- Do not rewrite unrelated widgets/providers.

## Validation
- `cd mobile/flutter_sdal && flutter analyze`
- `cd mobile/flutter_sdal && flutter test <target>` when a focused test exists.
- `cd mobile/flutter_sdal && flutter test` for broad Flutter risk only when justified.

## Output Format
- Files changed.
- ARB/localization status.
- Checks run.
- API/visual risks.
