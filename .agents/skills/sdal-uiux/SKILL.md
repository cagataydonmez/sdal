---
name: sdal-uiux
description: Use for SDAL UI/UX design, admin panel usability, Flutter or React interface polish, visual hierarchy, mobile usability, accessibility, theme consistency, and practical implementation guidance.
---

# SDAL UI/UX

## When To Use
- UI/UX critique or implementation for Flutter app, React admin/web, mobile usability, visual cleanup, empty/error/loading states.
- Pair with `sdal-flutter-change` or backend skill when code/API changes are required.

## Workflow
1. Identify user role, screen goal, and primary task.
2. Inspect only the relevant screen/component, state/controller, route, and style/theme files.
3. Make UI practical for repeated real use; avoid generic marketing or decorative redesign.
4. Preserve existing app conventions unless a clear usability issue exists.
5. For Flutter strings, update ARB files.
6. Keep changes implementable and scoped.
7. Verify layout with targeted tests/screenshots when available, or mark visual QA as `UNVERIFIED`.

## Search Strategy
- `rg -n "ScreenName|WidgetName|route|class|label" mobile/flutter_sdal/lib frontend-modern/src`
- `rg -n "theme|color|spacing|AppLocalizations" relevant-paths`
- Avoid broad CSS/widget rewrites.

## Inspect Areas
- Flutter: `lib/features/<feature>/presentation`, `lib/core/theme`, `lib/core/widgets`, `lib/l10n`.
- React admin: `frontend-modern/src/admin`, `frontend-modern/src/components/admin`, `frontend-modern/src/admin.css`, shared CSS.
- API/state: relevant repository/controller/provider.

## Safety Rules
- Do not rewrite unrelated screens or shared design systems casually.
- Do not add user-facing Flutter text without ARB updates.
- Keep admin surfaces dense, clear, and operational.
- Avoid one-note palettes, nested cards, text overflow, and inaccessible icon-only controls.

## Validation
- Flutter: `flutter analyze`, targeted widget test if present.
- React: `npm --prefix frontend-modern run lint`, `npm --prefix frontend-modern run test`, or focused visual check if running locally.

## Output Format
- UX intent.
- Files changed.
- Localization status.
- Checks run.
- Visual/accessibility risks.
