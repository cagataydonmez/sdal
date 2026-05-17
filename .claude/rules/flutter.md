---
paths:
  - "mobile/flutter_sdal/lib/**"
  - "mobile/flutter_sdal/test/**"
  - "mobile/flutter_sdal/l10n.yaml"
  - "mobile/flutter_sdal/pubspec.yaml"
---

# Flutter Rules

- Exclude generated `*.g.dart`, `*.freezed.dart`, and `lib/l10n/generated` unless diagnosing generation output.
- Inspect `lib/main.dart`, `lib/app`, `lib/core/routing/app_router.dart`, and the relevant feature folder only as needed.
- Update both `lib/l10n/app_tr.arb` and `app_en.arb` for user-facing strings; do not edit generated localization files.
- Check repositories/API clients before changing UI assumptions.
- Prefer `cd mobile/flutter_sdal && flutter analyze` and targeted tests.
