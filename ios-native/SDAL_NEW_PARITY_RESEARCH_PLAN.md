# SDAL New Native Parity Research + Execution Plan

Date: 2026-02-22
Scope: client-side UX/flow parity against `sdal_new` web app.

## Findings from first-glance + source scan
- [x] Feed scope mismatch: `following`/`popular` was showing own posts.
- [x] Admin entry mismatch: native admin view could auto-enter from existing admin session.
- [x] Story manage mismatch: manage list needed explicit story photo preview visibility.
- [x] Upload action mismatch: camera option was missing in several image upload flows.
- [ ] Localization mismatch: many hardcoded strings still bypass selected language.
- [ ] Copy consistency mismatch: mixed TR/EN labels across feed/admin/messages/profile subflows.
- [ ] Web micro-interaction parity pass still incomplete (action labels, chips, error/empty wording consistency).

## Execution order
1. [x] Feed own-post filtering for `following` + `popular`.
2. [x] Enforce explicit admin-password-first gate in native admin screen.
3. [x] Ensure story manage photo preview is present.
4. [x] Complete camera option in all current `PhotosPicker` upload points.
5. [ ] Expand i18n key coverage and replace hardcoded strings in prioritized screens:
   - [x] Feed + side panels + post/comment sheets (partial high-traffic subset completed)
   - [x] Admin login shell and top-level nav labels
   - [x] Story manage sheet labels
   - [x] Messages/profile high-frequency actions
6. [ ] Web parity hardening pass for remaining microflows from `sdal_new/src/components/*` and `sdal_new/src/pages/*`.

## Validation checklist
- [x] Build succeeds (`xcodebuild`, clean derived data path).
- [x] Feed in `following` and `popular` never includes current user posts.
- [x] Admin panel always starts on password prompt in app.
- [x] Every upload entry exposes both library and camera where device supports camera.
- [x] Selected app language applies to newly touched surfaces.
