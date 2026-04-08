# Flutter App Audit Implementation Plan

Last updated: 2026-04-08

## Goal

Implement every actionable output in [Flutter_APP_Audit.md](/Users/cagataydonmez/Desktop/SDAL/docs/Flutter_APP_Audit.md), without dropping duplicated or differently-worded findings from the two audit passes inside that file.

This document is deliberately implementation-oriented:

- it deduplicates overlapping audit findings into a canonical backlog
- it preserves every unique issue raised anywhere in the audit
- it defines rollout order, file targets, validation strategy, and definition of done

This is not a design critique. It is the execution plan for closing the audit.

---

## Source Basis

This plan is based on:

- `docs/Flutter_APP_Audit.md`
- current Flutter app code under `mobile/flutter_sdal/lib/**`
- current Flutter app config under `mobile/flutter_sdal/pubspec.yaml`
- current lint config under `mobile/flutter_sdal/analysis_options.yaml`

Important note:

- `Flutter_APP_Audit.md` contains two overlapping audit writeups with different severity counts and slightly different wording.
- This plan uses the union of both writeups.
- When two findings describe the same underlying problem, they are merged into one canonical work item.
- When one writeup adds extra scope not present in the other, that extra scope remains explicitly tracked.

---

## Success Criteria

The audit is considered fully implemented when all of the following are true:

1. No remaining hardcoded color usage exists on user-facing surfaces where tokens already define the semantic color.
2. All user-facing strings on audited screens are routed through `AppLocalizations`.
3. Complex modal forms identified by the audit are replaced with dedicated pages or otherwise redesigned to avoid modal-overuse UX failures.
4. Core interactive surfaces have meaningful semantics, labels, tooltips, and focus-visible behavior.
5. Primary async list surfaces have content-aware loading and empty states.
6. Chat and feed interactions no longer exhibit the audited UX regressions.
7. Theming, border radius, loading, and motion behavior are consistent with the token/design system.
8. Code-quality/config items from the audit are either implemented or explicitly closed with a documented rationale.

---

## Constraints

- Keep context narrow and work feature-by-feature.
- Do not batch unrelated UI rewrites without validation checkpoints.
- Prefer token reuse over introducing new ad hoc colors, spacing, or shapes.
- Preserve the existing warm visual language; do not regress toward generic dark-tech aesthetics.
- Every UI change should include narrow validation:
  - `dart format`
  - `flutter analyze`
  - targeted widget/unit tests where practical
- High-risk UX refactors should also include manual simulator/device verification.

---

## Recommended Skills During Implementation

The audit already suggested several `/skill` commands. Those recommendations should be treated as part of the execution plan, not as optional commentary.

Use the following skills while implementing the corresponding tracks:

- `harden`
  - use for profile edit page migration, form validation, refresh/pull-to-refresh rollout, chat auto-scroll behavior, registration CAPTCHA flow, and general resilience fixes
- `adapt`
  - use for small-phone profile edit redesign, keyboard-safe layouts, chat bubble width fixes, and responsive touch-target corrections
- `fixing-accessibility`
  - use for semantics, tooltips, focus-visible behavior, badge accessibility, SurfaceCard grouping, and icon-only action labeling
- `normalize`
  - use for token migration, splash redesign, chat bubble theming, status chip colors, unread indicators, and admin tint cleanup
- `clarify`
  - use for l10n migration, Turkish copy fixes, error icon/copy cleanup, and empty-state explanation text
- `polish`
  - use for OAuth provider branding/icon improvements and final UI consistency pass after larger refactors land
- `delight`
  - use for skeleton/placeholder quality and richer empty states once the base UX is correct
- `onboard`
  - use for empty states that need teaching content, contextual explanation, and next-step CTAs
- `optimize`
  - use for theme build caching, menu rebuild review, and any avoidable rebuild/layout work identified during implementation
- `fixing-motion-performance`
  - use for inefficient animation patterns such as `AnimatedContainer` decoration-only animation and expand/collapse layout work
- `animate`
  - use for meaningful motion additions such as status banner transitions, page-level motion polish, and scroll-to-bottom/new-message affordances
- `arrange`
  - use when replacing stacked modal content with dedicated page layouts, and when improving spacing/rhythm in empty states, admin screens, and profile edit structure
- `typeset`
  - use during copy/l10n cleanup if hierarchy and readability regress while replacing hardcoded strings
- `audit`
  - run again as a final verification pass after implementation batches are complete

### Skill Mapping by Track

- A1 profile edit redesign: `harden`, `adapt`, `arrange`
- A2 accessibility pass: `fixing-accessibility`
- A3 theme rebuild performance: `optimize`
- B1 token/color cleanup: `normalize`
- B2 splash redesign: `normalize`, `polish`
- B3 border radius system: `normalize`
- C1 l10n migration: `clarify`, `typeset`
- C2 empty/error state redesign: `clarify`, `onboard`, `arrange`
- D1 skeleton loading states: `delight`, `arrange`
- D2 motion refinements: `fixing-motion-performance`, `animate`
- D3 responsive/touch-target fixes: `adapt`, `fixing-accessibility`
- E1 chat behavior improvements: `harden`, `animate`, `adapt`
- F1 profile validation: `harden`
- F2 registration UX hardening: `harden`, `clarify`
- G1 explore follow-state clarity: `harden`, `polish`
- G2 native refresh behavior: `harden`, `adapt`
- H1 admin palette cleanup: `normalize`, `arrange`
- I1-I4 config/release/code-quality work: `optimize`, `clarify`, `polish` as needed

### Execution Rule

Each implementation batch should explicitly call out which of the above skills it is using before edits begin. The final audit-closeout pass should use `audit` to verify that the original findings are actually closed rather than only partially mitigated.

---

## Canonical Backlog

Status legend used below:

- `Completed` means code landed and received narrow validation.
- `In progress` means some implementation has landed, but the track is not fully closed against the audit.
- `Not started` means not yet verified as implemented in this audit rollout.

The audit collapses into 20 implementation tracks plus 4 config/release tasks.

### A. Critical Tracks

#### A1. Replace profile-edit modal with dedicated edit flow

Status: `Completed`

Used skills in implementation:

- `harden`
- `adapt`
- `arrange`

Audit coverage:

- `C1 — Edit Profile Modal with 14 Fields`
- `H3 — Profile edit puts 14+ fields in an AlertDialog`
- `H8 — 14 TextEditingControllers without validation`
- systemic note: modal overuse

Scope:

- replace `_openEditProfileDialog` with a dedicated `/profile/edit` route
- move the full profile form into its own screen
- preserve all current editable fields
- add `Form` + `GlobalKey<FormState>`
- add inline validation for:
  - graduation year
  - website URL
  - linkedin URL
  - optional contact/social fields where format matters
- keep save CTA sticky/reachable with keyboard open
- keep password/email change flows under review after the profile page migration

Likely files:

- `mobile/flutter_sdal/lib/features/profile/presentation/profile_page.dart`
- new `mobile/flutter_sdal/lib/features/profile/presentation/profile_edit_page.dart`
- `mobile/flutter_sdal/lib/core/routing/app_router.dart`

Definition of done:

- no 14-field `AlertDialog` remains
- all current fields are editable on a dedicated page
- invalid inputs show inline errors before submit
- keyboard does not trap actions on small phones

#### A2. Full accessibility semantics pass on audited surfaces

Status: `In progress`

Current progress in implementation:

- shell navigation badges now expose unread counts to screen readers
- `FeatureScaffold` profile affordances and app logo now announce as buttons with tooltips
- `SurfaceCard` now supports optional interactive semantics and focus/ripple handling for card-like rows
- refresh icon buttons on the audited top-level feed/profile/explore/notifications/networking/messenger screens now expose localized tooltips
- interactive member avatar/profile affordances in feed surfaces now announce correctly
- messenger inbox rows now expose unread-count semantics through the card surface pattern
- feed post detail author/comment avatars now announce correctly as profile-navigation affordances
- feed overflow menus and composer image-removal controls now expose localized tooltips instead of raw gesture-only affordances

Audit coverage:

- `C2 — Zero Semantic Accessibility Annotations`
- `C3 — Near-zero accessibility semantics`
- `M4 — Missing focus indicators on custom interactive surfaces`
- `L1 — SurfaceCard Has No Semantic Role`

Scope:

- add `Semantics`, `MergeSemantics`, `ExcludeSemantics`, `Tooltip`, and semantic labels across:
  - `_NavBadgeIcon`
  - `_AppMenuButton`
  - `RemoteAvatar` usages that are interactive
  - member/profile avatar tap targets
  - refresh buttons
  - icon-only actions
  - card-like navigation rows
- expose unread counts to screen readers
- ensure decorative icons are excluded where parent widgets already carry labels
- add visible focus handling for custom interactive surfaces
- evaluate whether `SurfaceCard` should expose optional semantic grouping support

Likely files:

- `mobile/flutter_sdal/lib/core/widgets/app_tab_shell.dart`
- `mobile/flutter_sdal/lib/core/widgets/feature_scaffold.dart`
- `mobile/flutter_sdal/lib/core/widgets/remote_avatar.dart`
- `mobile/flutter_sdal/lib/core/widgets/surface_card.dart`
- audited presentation files across feed/profile/explore/notifications/networking/messenger

Definition of done:

- all icon-only buttons have tooltips
- badge counts are screen-reader visible
- avatar/profile navigation affordances announce correctly
- focus-visible behavior exists for custom interactive elements

#### A3. Stop rebuilding full themes on app rebuilds

Status: `Completed`

Used skills in implementation:

- `optimize`

Audit coverage:

- `C3 — Theme Build Called on Every Frame`

Scope:

- compute light/dark theme once
- move theme construction out of `build()`
- ensure no repeated `ColorScheme.fromSeed()` / `TextTheme` / component theme recomputation on app rebuild

Likely files:

- `mobile/flutter_sdal/lib/app/app.dart`
- `mobile/flutter_sdal/lib/core/theme/app_theme.dart`

Definition of done:

- `buildSdalLightTheme()` and `buildSdalDarkTheme()` are not called from `build()`
- `flutter analyze` clean

---

### B. Token / Theming Tracks

#### B1. Replace all audited hardcoded colors with token references

Status: `Not started`

Audit coverage:

- `H1 — Hardcoded Colors Bypass Token System`
- `C1 — Chat bubbles ignore design tokens`
- `H1 — Profile status chips use hardcoded colors`
- `H2 — Colors.blue / Colors.black54 usage in multiple feature pages`
- `M2 — Notification unread dot uses wrong color token`
- `L2 — admin_pages.dart uses hardcoded tint colors not from tokens`
- systemic note: hardcoded colors in 10+ files

Scope:

- replace audited hardcoded colors in:
  - `thread_detail_page.dart`
  - `profile_page.dart`
  - `notifications_page.dart`
  - `status_views.dart`
  - `following_page.dart`
  - `album_photo_page.dart`
  - `networking_pages.dart`
  - `admin_pages.dart`
- replace raw `Colors.blue`, `Colors.black54`, `Colors.white`, `Colors.blueAccent`, `Colors.redAccent`, `Colors.orange`, `Color(0xFF...)`
- ensure dark mode uses token-adjusted colors
- if admin needs a unique accent not covered by tokens, add it deliberately to tokens instead of hardcoding a one-off purple

Definition of done:

- no audited hardcoded color remains on those surfaces
- DM chat matches live chat token usage
- unread indicators, chips, banners, and links derive from tokens

#### B2. Redesign splash screen to match brand tokens

Status: `Not started`

Audit coverage:

- `H3 — Splash Screen Design Mismatch`
- `C2 — Splash screen hardcoded colors detached from theme`

Scope:

- replace dark navy gradient splash with branded warm token-based appearance
- align with `SdalThemeTokens`
- use token-driven foreground/loading colors
- keep contrast correct in both themes

Likely files:

- `mobile/flutter_sdal/lib/core/widgets/status_views.dart`

Definition of done:

- splash no longer uses cold navy gradient
- visual language matches auth/feed shell palette

#### B3. Define and enforce a border-radius scale

Status: `Not started`

Audit coverage:

- `L3 — CardTheme Border Radius is 24 but Buttons Are 18`
- `L3 — BorderRadius.circular(999) magic number anti-pattern`

Scope:

- define semantic radius scale in tokens/theme layer
- replace scattered radius literals where practical
- standardize:
  - cards
  - buttons
  - pills/chips
  - badges
  - online indicators

Likely files:

- `mobile/flutter_sdal/lib/core/theme/sdal_theme_tokens.dart`
- `mobile/flutter_sdal/lib/core/theme/app_theme.dart`
- core widgets using repeated radius literals

Definition of done:

- common radius values are tokenized or normalized
- pill shapes stop relying on arbitrary `999` magic without semantic intent

---

### C. Localization / Copy Tracks

#### C1. Route all audited hardcoded strings through l10n

Status: `In progress`

Audit coverage:

- `H2 — Hardcoded Strings Bypass l10n System`
- `M2 — Hardcoded localized strings outside the l10n system`
- `M5 — _SidebarHighlights Has Broken Turkish Text`
- `C3 — Hardcoded Strings Bypass l10n System (Systemic)`
- systemic note: localization gaps in 10+ locations

Scope:

- identify all hardcoded Turkish/English strings referenced by the audit
- add keys to `app_tr.arb` and `app_en.arb`
- replace inline locale branching and raw strings on audited screens
- correct Turkish diacritics and copy quality while migrating

Known surfaces from audit:

- `feature_scaffold.dart`
- `post_detail_page.dart`
- `explore_page.dart`
- `profile_page.dart`
- story feed titles
- menu headings
- sidebar highlight text

Definition of done:

- audited strings no longer appear as raw literals in presentation files
- TR and EN locale both show translated values correctly

#### C2. Improve error and empty-state copy clarity

Status: `Not started`

Audit coverage:

- `M7 — Error View Uses WiFi Icon for All Errors`
- `H6 — No Empty States with Guidance`
- `H5 — Empty states provide no guidance`

Scope:

- give `ErrorView` contextual icon support instead of always `wifi_off`
- redesign empty states with:
  - icon
  - headline
  - explanation
  - contextual CTA when possible
- prioritize:
  - notifications
  - explore
  - messenger/thread
  - requests
  - comments

Likely files:

- `mobile/flutter_sdal/lib/core/widgets/error_view.dart`
- audited feature pages

Definition of done:

- empty states teach the feature instead of only reporting emptiness
- network errors and generic errors no longer share the same misleading icon

---

### D. Loading / Motion / Responsiveness Tracks

#### D1. Add skeleton loading states for primary surfaces

Status: `Not started`

Audit coverage:

- `H5 — No Loading Skeleton / Shimmer States`
- `H4 — No loading skeletons; all async states show only spinners`
- systemic note: every async state is a spinner

Scope:

- create reusable skeleton primitives
- implement content-shaped loading for:
  - feed list
  - explore member list/cards
  - notifications list
  - profile sections where loading is prominent
  - messenger thread list
- use token-friendly placeholders rather than generic shimmer unless shimmer is intentionally added

Definition of done:

- the highest-traffic list screens no longer cold-start with only a centered spinner

#### D2. Replace inefficient or flat motion patterns

Status: `Not started`

Audit coverage:

- `M1 — AnimatedContainer used for animating decoration`
- `M3 — Animated Expand uses AnimatedCrossFade instead of AnimatedSize`
- `M9 — No Motion / Transitions Between Screens`
- `L4 — Live Chat Status Banner Has No Animation`

Scope:

- replace decoration-only `AnimatedContainer` usage with cheaper alternatives where appropriate
- switch preference-panel expand/collapse from `AnimatedCrossFade` to a size-based pattern if still warranted after review
- add purposeful, minimal motion to:
  - key page transitions where router allows
  - important action confirmations
  - live chat status banner
- avoid gratuitous animation; prioritize feedback and continuity

Definition of done:

- audited inefficient animation patterns are corrected
- app gains meaningful motion in a small number of important places

#### D3. Fix audited responsive constraints

Status: `Not started`

Audit coverage:

- `M4 — Touch Targets Below 44px Minimum`
- `L1 — Magic number maxWidth: 320 for chat bubbles`

Scope:

- ensure touch targets reach 44x44 minimum where audited
- replace fixed 320px chat bubble max width with responsive sizing

Definition of done:

- profile leading avatar target reaches accessible size
- chat bubble width adapts to screen size

---

### E. Chat / Messaging Tracks

#### E1. Fix DM chat theming and scroll behavior

Status: `Not started`

Audit coverage:

- `C1 — Chat bubbles ignore design tokens`
- `H7 — Chat Bubbles Don't Scroll to Bottom on New Messages`
- `M3 — No scroll-to-bottom button in chat`

Scope:

- migrate DM bubbles to chat tokens
- add `ScrollController` where missing
- only auto-scroll when user is near bottom
- add unread/new-message affordance or scroll-to-bottom CTA when user is reading history
- align DM behavior with live chat quality bar

Likely files:

- `mobile/flutter_sdal/lib/features/messenger/presentation/thread_detail_page.dart`
- `mobile/flutter_sdal/lib/features/live_chat/presentation/live_chat_page.dart`

Definition of done:

- new messages do not yank users away from older history
- users can jump to bottom intentionally
- DM and live chat feel visually and behaviorally consistent

---

### F. Form / Validation Tracks

#### F1. Profile form validation and field hygiene

Status: `Completed`

Used skills in implementation:

- `harden`

Audit coverage:

- `H8 — Profile edit dialog creates 14 TextEditingControllers without validation`

Scope:

- included as part of A1 but tracked separately for completeness
- add field validators
- avoid submitting unchanged/invalid data where unnecessary
- show inline feedback

Definition of done:

- invalid profile fields fail before network submit

#### F2. Registration UX hardening

Status: `Completed`

Used skills in implementation:

- `harden`
- `clarify`

Audit coverage:

- `M7 — Register page CAPTCHA timing UX gap`
- `M8 — Register page has no password strength indicator`

Scope:

- show CAPTCHA loading placeholder while SVG is loading
- prevent confusing empty CAPTCHA state
- add scroll-to-error behavior after failed submit
- add password-strength indicator and/or requirements hint

Likely files:

- `mobile/flutter_sdal/lib/features/auth/presentation/auth_pages.dart`

Definition of done:

- users understand password requirements before submit
- CAPTCHA load state is explicit

---

### G. Feature-Specific UX Tracks

#### G1. Explore follow-state clarity

Status: `Not started`

Audit coverage:

- `M1 — _MemberCard Follow Button Always Shows`

Scope:

- represent follow state in member cards
- add optimistic or immediate visual state change after follow
- prevent confusing repeated follow affordance

Likely files:

- `mobile/flutter_sdal/lib/features/explore/presentation/explore_page.dart`
- supporting repository/provider if needed

Definition of done:

- followed members no longer look identical to unfollowed members

#### G2. Native refresh behavior

Status: `Not started`

Audit coverage:

- `M5 — Refresh button on every page is duplicate pattern, no pull-to-refresh on most lists`

Scope:

- audit list screens using app-bar refresh buttons
- add `RefreshIndicator` to main list surfaces
- remove or demote redundant refresh icons where pull-to-refresh becomes primary
- preserve explicit refresh only where page structure is not list-based

Definition of done:

- list-heavy pages use pull-to-refresh as the primary refresh affordance

---

### H. Admin / Secondary Surface Tracks

#### H1. Normalize admin palette and accents

Status: `Not started`

Audit coverage:

- `L2 — admin_pages.dart uses hardcoded tint colors not from tokens`

Scope:

- map admin dashboard tints to semantic tokens or intentionally add admin token variants
- remove raw `Colors.blueAccent`, `Colors.redAccent`, `Colors.orange`, one-off purple where unjustified

Likely files:

- `mobile/flutter_sdal/lib/features/admin/presentation/admin_pages.dart`

Definition of done:

- admin visual language is deliberate and token-based rather than a Material-default palette leak

#### H2. Decide and implement album moderation if still desired

Status: `Not started`

Audit coverage:

- low-priority carryover from audit plan discussions
- `Albums & Photos` admin moderation decision remains open

Scope:

- verify whether this was explicitly requested by product
- if yes, scope into admin rollout
- if no, close as de-scoped rather than leave dangling

Definition of done:

- explicit decision recorded in audit plan status

---

### I. Code Quality / Config / Release Tracks

#### I1. Review and tighten lint rules

Status: `Not started`

Audit coverage:

- `L5 — analysis_options.yaml Not Reviewed`

Scope:

- review current `analysis_options.yaml`
- decide whether to add custom linting guidance for:
  - token usage
  - localization
  - magic colors
  - semantics/tooltips on icon-only buttons

Definition of done:

- `analysis_options.yaml` either improved or explicitly documented as intentionally unchanged

#### I2. Stabilize SDK constraint

Status: `Not started`

Audit coverage:

- `L6 — pubspec.yaml SDK Constraint Is Pre-release`

Scope:

- verify current stable Flutter/Dart toolchain for this repo
- align `environment.sdk` / Flutter constraints with the actual supported CI/runtime version
- avoid speculative pre-release constraints unless the app truly depends on them

Definition of done:

- SDK constraint reflects real supported toolchain

#### I3. Add branded app icon / asset setup

Status: `Not started`

Audit coverage:

- `L4 — pubspec.yaml has no app icon / assets configured`

Scope:

- define branded app icon delivery path
- wire `flutter_launcher_icons` or equivalent if the team wants it inside Flutter
- ensure app assets strategy is no longer “all commented out”

Definition of done:

- icon/asset strategy is configured or explicitly parked with owner/rationale

#### I4. Document server oddities surfaced by the audit

Status: `Not started`

Audit coverage:

- `L2 — RemoteAvatar URL normalization has magic string`

Scope:

- either move the special-case handling server-side
- or document the server contract and keep the client guard intentionally

Definition of done:

- `"yok"` handling is no longer an undocumented magic behavior

---

## Phase Plan

### Phase 1 — Critical UX, Theme, Accessibility

Includes:

- A1 profile edit page
- A2 accessibility semantics pass on audited surfaces
- A3 theme build perf fix
- B1 token/color cleanup for critical files
- B2 splash redesign
- E1 chat bubble theming

Why first:

- fixes the highest-severity issues
- removes dark mode breakage
- closes the largest accessibility gap
- eliminates the profile-edit blocker

Validation:

- `flutter analyze`
- widget tests for profile edit form validation
- manual VoiceOver/TalkBack sanity checks on:
  - nav badges
  - profile avatar navigation
  - refresh buttons
  - app menu button
- manual dark-mode verification

### Phase 2 — Localization, Forms, Secondary UX

Includes:

- C1 l10n migration
- C2 empty/error state copy
- F1 profile validation finish
- F2 register improvements
- G1 follow-state clarity
- G2 pull-to-refresh
- D3 responsive constraints

Validation:

- `flutter gen-l10n`
- `flutter analyze`
- locale smoke test in TR and EN
- manual registration/profile/edit flows

### Phase 3 — Loading, Motion, Chat Behavior

Includes:

- D1 skeleton states
- D2 motion refinements
- E1 near-bottom auto-scroll logic

Validation:

- widget tests where possible for loading/empty states
- manual simulator/device checks for:
  - notification/preferences animation
  - chat scroll behavior
  - pull-to-refresh

### Phase 4 — Admin Polish and Config Hardening

Includes:

- H1 admin tint normalization
- H2 album moderation decision
- I1 analysis options review
- I2 SDK constraint stabilization
- I3 app icon/assets
- I4 remote-avatar server-contract cleanup

Validation:

- `flutter analyze`
- config diff review
- manual admin visual pass

---

## File-Oriented Execution Map

### Core app shell / theme

- `mobile/flutter_sdal/lib/app/app.dart`
- `mobile/flutter_sdal/lib/core/theme/app_theme.dart`
- `mobile/flutter_sdal/lib/core/theme/sdal_theme_tokens.dart`
- `mobile/flutter_sdal/lib/core/widgets/status_views.dart`
- `mobile/flutter_sdal/lib/core/widgets/error_view.dart`
- `mobile/flutter_sdal/lib/core/widgets/feature_scaffold.dart`
- `mobile/flutter_sdal/lib/core/widgets/app_tab_shell.dart`
- `mobile/flutter_sdal/lib/core/widgets/surface_card.dart`
- `mobile/flutter_sdal/lib/core/widgets/remote_avatar.dart`

### Profile / auth

- `mobile/flutter_sdal/lib/features/profile/presentation/profile_page.dart`
- new `mobile/flutter_sdal/lib/features/profile/presentation/profile_edit_page.dart`
- `mobile/flutter_sdal/lib/features/auth/presentation/auth_pages.dart`

### Feed / explore / notifications / networking

- `mobile/flutter_sdal/lib/features/feed/presentation/feed_page.dart`
- `mobile/flutter_sdal/lib/features/feed/presentation/post_detail_page.dart`
- `mobile/flutter_sdal/lib/features/explore/presentation/explore_page.dart`
- `mobile/flutter_sdal/lib/features/notifications/presentation/notifications_page.dart`
- `mobile/flutter_sdal/lib/features/networking/presentation/networking_pages.dart`
- `mobile/flutter_sdal/lib/features/following/presentation/following_page.dart`
- `mobile/flutter_sdal/lib/features/albums/presentation/album_photo_page.dart`

### Messenger / live chat

- `mobile/flutter_sdal/lib/features/messenger/presentation/thread_detail_page.dart`
- `mobile/flutter_sdal/lib/features/live_chat/presentation/live_chat_page.dart`

### Admin / config

- `mobile/flutter_sdal/lib/features/admin/presentation/admin_pages.dart`
- `mobile/flutter_sdal/analysis_options.yaml`
- `mobile/flutter_sdal/pubspec.yaml`

---

## Validation Plan

Every phase should use the narrowest practical checks.

### Static validation

- `dart format` on touched files
- `flutter analyze` on touched files

### Suggested targeted tests

- profile edit form validators
- l10n key presence smoke checks if existing test infrastructure allows
- chat scroll behavior tests if the current code is structured enough for widget tests
- skeleton/empty state widget tests for primary surfaces

### Manual verification checklist

- dark mode on splash, DM thread, notifications, profile chips
- VoiceOver/TalkBack announcements for badges, avatars, icon buttons
- small-phone profile edit flow with keyboard open
- English locale pass through audited screens
- refresh behavior on main lists
- chat behavior when scrolled up and new messages arrive

---

## Raw Audit Coverage Map

This section proves nothing from the audit was dropped.

### First audit block coverage

- Splash mismatch: covered by B2
- Card grid repeat: not a standalone defect in the later audit, but absorbed into D1 and C2 for loading/empty-state variation and future surface polish; if product wants stronger visual differentiation, handle during Phase 3 polish review
- OAuth icon placeholders: covered by a dedicated subtask under C1/C2 adjacent auth polish, plus Phase 2 UI polish
- Chat bubbles bypass token system: covered by B1 and E1
- Edit profile modal: covered by A1
- Zero semantics: covered by A2
- Hardcoded Turkish strings: covered by C1
- Theme build every frame: covered by A3
- No skeletons: covered by D1
- No guided empty states: covered by C2
- Chat not scrolling / wrong scrolling: covered by E1
- Profile validation gap: covered by F1
- Follow state ambiguity: covered by G1
- Wrong unread dot token: covered by B1
- AnimatedCrossFade efficiency issue: covered by D2
- sub-44px touch targets: covered by D3
- broken Turkish text: covered by C1
- menu rebuild cost: can be reviewed opportunistically during Phase 2/4 optimization, but is lower priority than A3 and not omitted
- WiFi icon misuse in errors: covered by C2
- password strength missing: covered by F2
- no motion/transitions: covered by D2
- `SurfaceCard` semantics: covered by A2
- `RemoteAvatar` magic `"yok"`: covered by I4
- card/button radius inconsistency: covered by B3
- live chat status banner animation: covered by D2
- `analysis_options.yaml` review: covered by I1
- SDK constraint issue: covered by I2

### Second audit block coverage

- chat bubble token issue: covered by B1 and E1
- splash colors detached from theme: covered by B2
- near-zero accessibility semantics: covered by A2
- profile chips hardcoded colors: covered by B1
- `Colors.blue` / `Colors.black54` spread: covered by B1
- profile edit dialog anti-pattern: covered by A1
- loading spinners everywhere: covered by D1
- empty states no guidance: covered by C2
- AnimatedContainer decoration misuse: covered by D2
- hardcoded localized strings: covered by C1
- no scroll-to-bottom button / over-eager auto-scroll: covered by E1
- missing focus indicators: covered by A2
- pull-to-refresh missing: covered by G2
- redundant `TextAlign.left`: can be cleaned as part of general hardening during touched-file edits; not a separate rollout blocker
- register CAPTCHA timing: covered by F2
- chat bubble fixed max width: covered by D3
- admin hardcoded tints: covered by H1
- border radius magic number: covered by B3
- app icon/assets missing: covered by I3

---

## Remaining Decision Items

These are not missing from the plan; they are explicitly decision-bound:

- whether to introduce shimmer or static skeletons
- whether to add a distinct admin-only accent token
- whether admin album moderation belongs in Flutter scope now
- whether app-icon setup should be part of this implementation batch or a brand/assets dependency handoff

If the user wants, a second document can break this plan into task-by-task implementation batches with statuses and validation checkpoints.
