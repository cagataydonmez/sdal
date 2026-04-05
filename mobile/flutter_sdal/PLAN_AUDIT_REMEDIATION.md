# Flutter Audit Remediation Plan

## Summary
Implement the audit findings end-to-end in `mobile/flutter_sdal` without rewriting the app. Use the existing `.impeccable.md` Design Context as canonical: warm, proud, contemporary, editorial, community-led. The remediation will keep current behavior intact while replacing the generic light-only Material template with a tokenized light/dark theme, adaptive media primitives, accessible image/story interactions, systemic l10n cleanup, and more differentiated compositions for feed, explore, groups, jobs, requests, stories, chat, profile, and albums.

Execution order is fixed and must be followed:
1. `teach-impeccable` grounding: reuse `.impeccable.md`; no design-context rewrite unless repo truth conflicts with it.
2. `frontend-design` grounding: inventory current theme, shared shells, cards, avatars, story/media patterns, and screen compositions.
3. `normalize`
4. `harden`
5. `adapt`
6. `optimize`
7. `clarify`
8. `arrange`
9. `distill`
10. `polish`
11. `flutter analyze` and regression fixes

## Key Changes
### Theme foundation and dark mode
- Replace the single `buildSdalTheme()` light-only builder with a tokenized theming layer:
  - `ThemeData buildSdalTheme(Brightness brightness, SdalThemeTokens tokens)`
  - `SdalThemeTokens extends ThemeExtension<SdalThemeTokens>`
  - semantic roles must include: `canvas`, `canvasSubtle`, `panel`, `panelRaised`, `panelMuted`, `panelBorder`, `accent`, `accentMuted`, `success`, `successMuted`, `warning`, `warningMuted`, `info`, `infoMuted`, `danger`, `dangerMuted`, `chatOutgoing`, `chatIncoming`, `storyActive`, `storyInactive`, `storyOverlay`, `imagePlaceholder`, `imageError`
- Add real `theme`, `darkTheme`, and `themeMode` wiring to every `MaterialApp`/`MaterialApp.router` path in `app.dart`.
- Default theme preference to `ThemeMode.system`.
- Add a persisted user preference:
  - create `ThemeModePreference` enum with `system`, `light`, `dark`
  - persist locally via app storage in the client layer
  - expose via Riverpod provider/controller in the app/core layer
- Place the theme control in the existing Profile account/actions area using a `SegmentedButton<ThemeModePreference>` with localized labels and immediate preview/persistence.
- Keep Material 3, but all feature styling must consume tokens rather than raw local colors.

### Shared primitives and image system
- Introduce a shared network media primitive in `core/widgets` and migrate audited screens to it:
  - `SdalNetworkImage` for rectangular media
  - `SdalAvatarImage` or refactor `RemoteAvatar` to wrap the shared primitive
- Required behavior:
  - loading placeholder state using theme tokens
  - error fallback state with deterministic fallback UI
  - consistent border radius/clipping contract
  - optional fade-in via `frameBuilder`
  - `cacheWidth`/`cacheHeight` hints when target size is known
  - framework-native caching only; do not add a third-party image package
  - optional `precacheImage` hooks for stories viewer and other image-led surfaces
- Migrate at minimum: feed media, stories rail/viewer, albums grids/detail, remote avatars, and any reused image tiles touched during remediation.

### Accessibility, copy, and localization hardening
- Replace unlabeled media-only taps with semantic controls:
  - `stories_rail.dart`: story rail items get button semantics with labels like “View story from {name}”; viewer navigation halves become semantic tappable regions with explicit previous/next labels and hints
  - `albums_page.dart` and `album_category_page.dart`: replace bare `GestureDetector` photo tiles with `InkWell`/semantic button wrappers labeled “Open photo {index/title}”
- Add persistent labels or equivalent accessible context where hints were doing all the work:
  - live chat composer
  - story edit/upload forms
  - any touched admin/privacy forms with hint-only context
- Replace meaningless loading copy such as `"..."` with localized status text.
- Finish l10n cleanup in audited areas:
  - `explore_page.dart`
  - `requests_page.dart`
  - `jobs_page.dart`
  - `stories_rail.dart`
  - `albums_page.dart`
  - remaining touched strings in `group_detail_page.dart`, `profile_page.dart`, and `feed_page.dart`
- Regenerate l10n outputs after ARB updates and ensure reusable widgets do not accept raw hard-coded section titles when localized defaults already exist.

### Adaptive layout and feature restructuring
- Remove brittle fixed dimensions in audited areas and replace them with adaptive constraints:
  - `stories_rail.dart`: rail height and tile width scale from available width and text scale; labels can wrap to 2 lines; subtitle visibility may reduce only when text scale forces it
  - `explore_page.dart`: suggestion members switch from fixed horizontal card rail to adaptive horizontal/vertical layout using `LayoutBuilder`; directory rows stay list-based, not card-based
  - `profile_page.dart`: `_ProfileRow` stacks vertically on constrained widths or larger text scale; edit/account dialogs become adaptive surfaces sized from available width instead of fixed `520`
  - `live_chat_page.dart`: bubble max width derives from viewport width and text scale; composer row can stack when space is constrained
  - albums grids move from fixed `Wrap` tile sizing to adaptive grid constraints
- Do not solve overflow by shrinking typography indiscriminately; preserve hierarchy and touch target size.
- Restructure `group_detail_page.dart` into explicit sections with progressive disclosure:
  - `GroupHeroSection`: cover, name, visibility, membership state, primary action
  - `GroupAdminPanel`: collapsible panel containing settings, invite flow, cover update, join requests, pending invites, privacy/helper copy
  - `GroupPostsSection`: primary content section, visually first after hero
  - `GroupTimelineSection`: events then announcements as lighter section blocks, not identical stacked cards
  - `GroupMembersSection`: managers and members, with role controls kept scoped and visually secondary
- The page must stop reading as an endless stack of identical `SurfaceCard`s. Use section spacing, headings, dividers, and mixed surface emphasis instead.

### Visual differentiation and anti-pattern removal
- Remove the default pale gradient shell as the app-wide fallback. `FeatureScaffold` must support a tokenized background treatment enum such as:
  - `editorial`
  - `neutral`
  - `utility`
  - `immersive`
- Assign screen compositions deliberately:
  - Feed: flatter editorial list, content-led, fewer full-card wrappers, stories integrated as a living community strip
  - Explore: discovery-oriented with lighter member rows and a more intentional suggestion strip
  - Groups: structured and community-owned, with clear hero/admin/content separation
  - Jobs and Requests: utility-focused, denser information layout, stronger status hierarchy, reduced decorative chrome
  - Stories and Albums: image-led, immersive where appropriate, minimal extra framing
  - Chat: calm neutral canvas, subdued incoming/outgoing surfaces, efficient composer area
  - Profile: quieter account overview with less repeated card treatment and clearer details/actions separation
- Use spacing, headings, tokenized accent surfaces, and hierarchy to differentiate screens; do not replace one generic pattern with another.

## Public Interfaces / Types
- Add `ThemeModePreference` enum and a persisted app-level theme preference provider/controller.
- Add `SdalThemeTokens` `ThemeExtension` and token accessors used by shared/widgets and feature screens.
- Add shared media primitives in `core/widgets` and update `RemoteAvatar` to use them.
- Extend `FeatureScaffold` with a background style/tone parameter instead of a single hard-coded gradient.
- Keep `StoriesRail.title` optional/localized by default; reusable widgets should prefer internal l10n defaults over raw section-title strings.

## Test Plan
- `flutter analyze` must pass after all changes.
- Add or extend widget tests for:
  - app theme mode wiring: light, dark, system, and persisted user preference
  - profile theme selector rendering and state changes
  - story rail semantics labels and viewer next/previous semantic actions
  - album grid photo semantics
  - adaptive layouts at narrow width and larger text scale for `StoriesRail`, `ExplorePage`, `ProfilePage`, and `LiveChatPage`
  - l10n-backed labels resolving in touched screens
- Add focused tests for the theme preference persistence repository/controller.
- Regenerate l10n outputs and verify no missing keys.
- Run the smallest relevant widget/unit suites for touched areas plus a final `flutter analyze`.

## Assumptions and Defaults
- Use `.impeccable.md` as the canonical design context; no additional brand discovery is needed unless implementation reveals a contradiction.
- Default mode is `ThemeMode.system`; user can override it from Profile actions.
- Use app-local persistence in the Flutter client layer for theme preference storage.
- Stay on Flutter-native image loading/caching; do not add a new image dependency.
- Preserve existing routing, data contracts, and server behavior; this pass is UI/system remediation, not backend redesign.
