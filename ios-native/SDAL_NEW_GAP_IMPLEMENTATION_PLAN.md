# SDAL New Native Gap Closure Plan

Date: 2026-02-22
Scope: `sdal_new` native parity gaps discovered after UX/API inventory completion.

## Audit summary
- Hardcoded UI strings still present in native views: ~510 occurrences.
- Image upload entry points currently library-only (`PhotosPicker`): 8 flows.
- Feed parity mismatch: `following`/`popular` scopes can still show own posts.
- Story manage parity mismatch: manage list does not show story photo previews.
- Admin entry flow needs explicit, always-visible password gate behavior hardening.

## Principles
- Preserve existing endpoint compatibility and fallback behavior.
- Prioritize parity behaviors users notice first.
- Keep changes incremental and build-verified after each phase.

## Phase 1 (Immediate parity blockers)
- [x] Feed scope parity: exclude own posts for `following` and `popular`.
- [x] Admin gate parity: force explicit admin password entry UX before panel actions.
- [x] Story manage parity: show story image previews in manage list.
- [x] Camera parity: add camera capture option to all 8 image upload flows.
- [x] Build verification after phase.

## Phase 2 (Localization consistency)
- [ ] Replace high-frequency hardcoded strings in auth/feed/explore/messages/profile/admin shells with `i18n.t`.
- [ ] Expand localization keyset for all converted strings.
- [ ] Ensure default language is Turkish (`tr`) and all converted strings follow selected language.
- [ ] Build verification after phase.

## Phase 3 (Flow parity hardening against web client)
- [ ] Compare `sdal_new/src/pages/*` and `sdal_new/src/components/*` interaction microflows vs native.
- [ ] Close remaining interaction gaps (state chips, action labels, error/empty copy consistency).
- [ ] Final build verification and checklist sync.

## Current execution
- Active phase: Phase 2

## 2026-02-22 incremental notes
- Implemented own-post filtering client-side for `following` and `popular` feed scopes.
- Removed admin auto-session bootstrap in native admin panel; entry now starts with password form each open.
- Completed camera parity for remaining feed-related upload sheets (events, announcements, group cover, group post).
- Added i18n keys for newly touched common labels and action feedback strings (`all`, `popular`, `camera`, `manage`, feedback copy).
- Started Phase 2 localization pass in feed sheets, story manage/upload surfaces, and admin shell/navigation labels.
- Extended Phase 2 localization to messages/profile utility flows (`MessagesView`, `ChangePassword`, `Menu/Sidebar`, `Panolar`, `Tournament`, `Help`) and auth sheets (`Login/Register/Activate/Resend/Reset`).
- Added new localization keys for auth, utility profile flows, help/troubleshooting copy, and status counters with formatted labels.
- Localized high-traffic Explore/Albums strings (`ExploreView`, `MemberDetailSheet`, `AlbumsHub`, album detail/comment/upload labels) and added key coverage for member/album copy.
- Localized high-impact Admin shell labels (admin title, moderation queue labels, verification actions, operations-tab labels, photo comments sheet copy).
- Localized major Admin operation subpanels (`users/follows/groups/filters/engagement/email/db/pages/logs/album/tournament`) and `AdminUserEditSheet` form labels to `i18n.t`.
- Verified build after localization pass (`xcodebuild -project ios-native/SDALNative.xcodeproj -scheme SDALNative -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/SDALNativeDerivedData7 build`).
- Re-verified build after Explore localization (`xcodebuild -project ios-native/SDALNative.xcodeproj -scheme SDALNative -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/SDALNativeDerivedData8 build`).
- Re-verified build after Admin shell localization and localization-map cleanup (`xcodebuild -project ios-native/SDALNative.xcodeproj -scheme SDALNative -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/SDALNativeDerivedData10 build`).
- Re-verified build after Admin operations localization sweep (`xcodebuild -project ios-native/SDALNative.xcodeproj -scheme SDALNative -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/SDALNativeDerivedData12 build`).
- Completed Admin microcopy hardening pass: localized side-rail operation labels, overview KPI cards, page/log labels, create/save actions, and admin-side validation/permission error messages.
- Re-verified build after Admin microcopy + error-localization cleanup (`xcodebuild -project ios-native/SDALNative.xcodeproj -scheme SDALNative -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/SDALNativeDerivedData13 build`).
- Remaining high-volume parity gap is full mixed-language cleanup across all screens.
