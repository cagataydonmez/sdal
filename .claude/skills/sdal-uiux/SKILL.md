---
name: sdal-uiux
description: Use for SDAL UI/UX design, admin panel usability, Flutter or React interface polish, visual hierarchy, mobile usability, accessibility, theme consistency, and practical implementation guidance.
---

# SDAL UI/UX

## When To Use
- UI/UX critique or implementation for Flutter app, React admin/web, mobile usability, visual cleanup, empty/error/loading states.
- Pair with `sdal-flutter-change` when Flutter code changes are needed.

## Workflow
1. Identify user role, screen goal, and primary task.
2. Inspect only relevant screen/component, state/controller, route, and style/theme files.
3. Make UI practical for repeated real use, not generic marketing.
4. Preserve existing conventions unless a clear usability issue exists.
5. For Flutter strings, update ARB files.
6. Keep changes implementable and scoped.
7. Verify layout with targeted tests/screenshots when available or mark visual QA `UNVERIFIED`.

## Search Strategy
- Search for screen/widget/route/class/label in `mobile/flutter_sdal/lib` and `frontend-modern/src`.

## Inspect Areas
- Flutter presentation/theme/widgets/l10n.
- React admin/components/admin CSS/shared CSS.
- Relevant API/state repository/controller/provider.

## Safety Rules
- Do not rewrite unrelated screens or shared design systems casually.
- Do not add user-facing Flutter text without ARB updates.
- Keep admin surfaces dense, clear, and operational.

## Validation
- Flutter: `flutter analyze`, targeted widget test if present.
- React: `npm --prefix frontend-modern run lint` or `test`.

## Output Format
- UX intent, files changed, localization status, checks, visual/accessibility risks.
