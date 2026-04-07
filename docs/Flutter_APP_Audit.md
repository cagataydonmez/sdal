Flutter App Audit — SDAL Mobile
Anti-Patterns Verdict
Mostly passes the AI slop test, but with notable fails.

The warm terra cotta / cream palette (#C8633C, #F7F1E8) is distinctive — not cyan-on-dark, not purple-to-blue gradients. The design token system is architecturally solid. However several specific tells expose the seams:

Splash screen is full AI slop: Dark navy gradient (#0D2238 → #173657) completely contradicts the warm earthy app palette. Classic dark mode with "tech" vibes as a lazy first impression.
Card grid repeat: Explore page renders identical _MemberCard components in a horizontal carousel, then again in a vertical list, then again in a grid — same card, three times, no variation.
Icon as OAuth logo: Icons.g_mobiledata for Google and Icons.alternate_email for X — obviously placeholder-level work.
Chat bubbles bypass the token system: ThreadDetailPage hard-codes Color(0xFF0D2238) / Colors.white instead of using the chatOutgoing/chatIncoming tokens that already exist for this exact purpose.
Executive Summary
Severity	Count
Critical	3
High	8
Medium	9
Low	6
Top 5 critical issues:

Edit profile uses a modal dialog with 14 scrollable fields — severe UX and accessibility failure
Zero semantic accessibility annotations across the entire app
Splash screen completely mismatches the design system
Wholesale hardcoded Turkish strings bypass the l10n system
buildSdalLightTheme() / buildSdalDarkTheme() called on every frame
Overall quality score: 6/10 — solid foundation, token architecture is good, Riverpod usage is correct, but finish quality and accessibility are significantly below production standard.

Detailed Findings
Critical Issues
C1 — Edit Profile Modal with 14 Fields
Location: profile_page.dart:452–607
Category: UX / Accessibility
Description: _openEditProfileDialog opens an AlertDialog containing a SingleChildScrollView with 14 TextField inputs plus 4 SwitchListTile toggles. On small phones this creates a scroll-within-a-scroll trap.
Impact: Keyboard-nav users cannot exit the dialog without completing it. Screen readers lose context. On short screens the action buttons may be unreachable. WCAG 2.1 — SC 2.1.2 (No Keyboard Trap), SC 3.2.2.
Recommendation: Replace with a dedicated /profile/edit page route. Use FeatureScaffold with a Form widget and GlobalKey<FormState> for validation.
Suggested command: /harden then /adapt
C2 — Zero Semantic Accessibility Annotations
Location: App-wide — every presentation file
Category: Accessibility (WCAG A)
Description: No Semantics, MergeSemantics, or ExcludeSemantics widgets anywhere. Icon-only buttons have no tooltip. Custom interactive widgets (_NavBadgeIcon, _StatusChip, RemoteAvatar) expose no semantic labels beyond what Material derives.
Impact: VoiceOver / TalkBack users receive meaningless or missing announcements. The unread badge on navigation icons (_NavBadgeIcon) is invisible to screen readers. WCAG SC 1.3.1, 4.1.2.
Recommendation: Add Semantics(label: '${count} okunmamış mesaj', child: ...) to badge widgets. Add tooltip to all IconButtons. Add semanticLabel to decorative/informational icons.
Suggested command: /fixing-accessibility
C3 — Theme Build Called on Every Frame
Location: app.dart:19–20
Category: Performance
Description: buildSdalLightTheme() and buildSdalDarkTheme() are called inside build(). These allocate a full ThemeData, multiple TextTheme copies, ColorScheme.fromSeed(), and all component themes on every rebuild of SdalFlutterApp.
Impact: Every session state change (e.g., navigation) rebuilds MaterialApp and recomputes both full themes. Measurable jank on older devices during startup.
Recommendation: Promote to late final fields in the widget or use a provider: final lightTheme = buildSdalLightTheme(); above the class, computed once.
Suggested command: /optimize
High-Severity Issues
H1 — Hardcoded Colors Bypass Token System
Location: thread_detail_page.dart:199–203, profile_page.dart:105–110, notifications_page.dart:209, status_views.dart:17–18
Category: Theming
Description: At least 8 hardcoded color values found that bypass SdalThemeTokens:
Color(0xFF0D2238) / Colors.white for chat bubbles in ThreadDetailPage — tokens chatOutgoing/chatIncoming exist for exactly this.
Color(0xFF0D7A4B), Color(0xFF9A6700), Color(0xFF173657) in _StatusChip
Color(0xFF1F6FEB) for unread notification dot
Colors.black.withValues(alpha: 0.06), Colors.white70, Colors.black54 in thread bubbles
Color(0xFF0D2238) / Color(0xFF173657) in splash screen
Impact: Dark mode breaks for these elements. System theme changes don't update these values. Design consistency breaks.
Recommendation: Map all to tokens or compute via Color.lerp from existing tokens. The _StatusChip status colors should use tokens.success, tokens.warning, tokens.info.
Suggested command: /normalize
H2 — Hardcoded Strings Bypass l10n System
Location: Across feature_scaffold.dart, post_detail_page.dart, explore_page.dart, profile_page.dart
Category: Responsive / i18n
Description: 40+ hardcoded Turkish strings bypass AppLocalizations. Examples:
feature_scaffold.dart: 'Ana gezinme', 'Topluluk', 'Ek sayfalar', 'Yonetim', 'Admin paneli', 'Hızlı erişim', 'Hızlı menü', 'cevrimici uye', 'yeni mesaj', 'yeni uye' (last three missing diacritics)
post_detail_page.dart: 'Yorumlar', 'Yorum ekle', 'Yorumun', 'Yorumu gönder', 'Gönderiliyor...', 'Henüz yorum yok.', 'Gönderiyi sil', etc.
explore_page.dart: 'En Yeni Uyeler' (missing diacritic on Ü), 'Dizin filtreleri', 'Ara', 'Filtreleri uygula'
Impact: English locale (en) users see Turkish strings. 'Ogretmen baglantilari' and 'cevrimici uye' have broken Turkish encoding — would look wrong to Turkish users too.
Recommendation: Add all missing keys to app_en.arb and app_tr.arb and replace hardcoded strings with l10n.* lookups.
Suggested command: /clarify
H3 — Splash Screen Design Mismatch
Location: status_views.dart:17–18
Category: Theming / Anti-Pattern
Description: Splash uses a dark navy gradient (Color(0xFF0D2238) → Color(0xFF173657)) with white text and a white CircularProgressIndicator. The entire app palette is warm earth tones (cream, terra cotta). This is a completely different product.
Impact: Jarring brand discontinuity on first launch. The app theme correctly defines SdalThemeTokens.light.accent and SdalThemeTokens.light.canvas — neither is used here.
Recommendation: Replace with tokens.accent to tokens.canvas gradient (matching _AuthFrame) and use tokens.foregroundOnAccent for text.
Suggested command: /normalize
H4 — OAuth Icons Are Wrong
Location: auth_pages.dart:109–116
Category: UX / Accessibility
Description: Icons.g_mobiledata is used for Google login, Icons.alternate_email for X login. Neither icon resembles the actual brand. g_mobiledata is a 5G mobile data icon.
Impact: Users cannot recognize the OAuth providers at a glance. Breaks brand trust. flutter_svg is already a dependency — branded SVG assets should be used instead.
Recommended: Use SVG assets for Google/X/Twitter logos. Google provides official brand assets. flutter_svg is already in pubspec.yaml.
Suggested command: /polish
H5 — No Loading Skeleton / Shimmer States
Location: All feature pages
Category: Performance / UX
Description: Every loading state renders a centered CircularProgressIndicator. There are ~12 distinct load states across the app (feed, explore, notifications, profile, etc.) all showing the same spinner.
Impact: Perceived performance is poor. Content layout shift occurs when data loads. Users can't anticipate the shape of incoming content.
Recommendation: Implement skeleton screens for key surfaces (feed post list, member cards, notification list). Consider shimmer-style placeholders using the existing imagePlaceholder token.
Suggested command: /delight
H6 — No Empty States with Guidance
Location: post_detail_page.dart:213, explore_page.dart:83, multiple pages
Category: UX
Description: Empty states display minimal text ('Henüz yorum yok.', 'Yeni bildirim bulunamadı.', SurfaceCard(child: Text(l10n.exploreNoSuggestions))). No guidance on what users can do next, no visual treatment.
Impact: Users hitting empty states get no direction. The design guideline says "design empty states that teach the interface."
Recommendation: Add icon + heading + contextual action to each empty state. For comments: suggest posting the first comment. For explore: suggest completing profile.
Suggested command: /onboard
H7 — Chat Bubbles Don't Scroll to Bottom on New Messages
Location: thread_detail_page.dart:163
Category: UX
Description: ThreadDetailPage renders ListView with reverse: false but has no scroll-to-bottom logic when new messages arrive via realtime events (ref.invalidate triggers a re-render but no scroll). LiveChatPage has _jumpToBottom() but ThreadDetailPage does not.
Impact: In active conversations, new messages appear off-screen below the viewport and users must manually scroll down.
Recommendation: Add a ScrollController and call jumpToBottom() after the provider rebuilds with new messages.
Suggested command: /harden
H8 — Profile Edit Dialog Creates 14 TextEditingControllers Without Form Validation
Location: profile_page.dart:452–607
Category: UX / Resilience
Description: The edit dialog instantiates 14 TextEditingControllers and submits all fields even if they're unchanged. No input validation (e.g., URL format for website/linkedinUrl, graduation year range). Error reporting only via SnackBar after dialog closes.
Impact: Users receive no inline validation feedback. Invalid URLs or years silently fail after form submission.
Recommendation: Use Form widget with TextFormField and validator callbacks. Show validation errors inline.
Suggested command: /harden
Medium-Severity Issues
M1 — _MemberCard Follow Button Always Shows (Even if Already Following)
Location: explore_page.dart:429
Category: UX
Description: Every member card shows an OutlinedButton with followAction label regardless of follow state. After following, the button re-appears with the same label. invalidate refreshes the list but there's no optimistic state change.
Impact: Users can't tell if they're already following someone. Double-follow attempts are possible.
Suggested command: /harden
M2 — Notification Unread Dot Uses Wrong Color Token
Location: notifications_page.dart:209
Category: Theming
Description: const Icon(Icons.circle, size: 10, color: Color(0xFF1F6FEB)) — hardcoded GitHub-blue. Should use tokens.info (Color(0xFF355C87) light / Color(0xFF8EB2E0) dark).
Suggested command: /normalize
M3 — Animated Expand Uses AnimatedCrossFade Instead of AnimatedSize
Location: notifications_page.dart:514
Category: Performance
Description: AnimatedCrossFade between SizedBox.shrink() and the preference content. This renders both children simultaneously during transition, causing double-layout. AnimatedSize + AnimatedOpacity or SizeTransition would be more efficient.
Impact: Minor visual stutter during preference panel expand/collapse; double build cost during animation.
Suggested command: /fixing-motion-performance
M4 — Touch Targets Below 44px Minimum
Location: feature_scaffold.dart:104–123, remote_avatar.dart header usage
Category: Accessibility / Responsive
Description: The profile avatar in _ProfileLeading is radius: 16 = 32px diameter, wrapped in Padding(all: 4) = 40px tap target. Slightly under the 44×44px HIG minimum. The back chevron Icons.chevron_left_rounded has no explicit size constraint.
Recommendation: Increase radius to 18 (36px) + padding to 6 = 48px, or use SizedBox(width: 44, height: 44) wrapper.
Suggested command: /fixing-accessibility
M5 — _SidebarHighlights Has Broken Turkish Text
Location: feature_scaffold.dart:599
Category: UX / i18n
Description: '${sidebar.onlineUsers.length} cevrimici uye' — missing ç and ü diacritics. Should be çevrimiçi üye. Similarly 'yeni uye' → 'yeni üye'. These display in the quick-access menu visible on every screen.
Suggested command: /clarify
M6 — FeatureScaffold Rebuilds Full App Menu on Every Navigation
Location: feature_scaffold.dart:176–335
Category: Performance
Description: _AppMenuSheet.build() constructs 3 _MenuSection lists, sorts entries, builds extraMenuEntries, and evaluates session?.isModuleVisible() for 12+ modules on every bottom sheet open.
Impact: Minor CPU cost on open; could be const or pre-computed.
Suggested command: /optimize
M7 — Error View Uses WiFi Icon for All Errors
Location: error_view.dart:32
Category: UX / Accessibility
Description: Icons.wifi_off_rounded is shown for all error types — server errors, auth failures, parsing errors — not just connectivity issues. The icon misguides users to check their WiFi.
Recommendation: Accept an optional IconData parameter, default to Icons.error_outline. Use Icons.wifi_off_rounded only for network-specific errors.
Suggested command: /clarify
M8 — Register Page Has No Password Strength Indicator
Location: auth_pages.dart:164–511
Category: UX
Description: Password field has no strength meter or requirements hint. Users can't know if their chosen password will be accepted until server-side validation rejects it.
Suggested command: /harden
M9 — No Motion / Transitions Between Screens
Location: App-wide
Category: UX / Motion
Description: go_router uses default page transitions. No enter/exit animations for bottom sheets beyond Material defaults. No micro-interactions on buttons, no feedback animations on like/unlike.
Impact: App feels flat and unresponsive compared to native iOS apps. Users miss state confirmation on actions.
Suggested command: /animate
Low-Severity Issues
L1 — SurfaceCard Has No Semantic Role
Location: surface_card.dart
Category: Accessibility
Description: SurfaceCard wraps Card with Padding but adds no semantic grouping. Screen readers don't understand card boundaries.
Recommendation: Consider adding optional semanticLabel parameter.
L2 — RemoteAvatar URL Normalization Has Magic String
Location: remote_avatar.dart:77
Category: Resilience
Description: value.toLowerCase() == 'yok' — Turkish word for "none" hardcoded as special case. Suggests server can return 'yok' as a photo URL. This should be handled server-side or at least documented.
L3 — CardTheme Border Radius is 24 but Buttons Are 18
Location: app_theme.dart:86–89
Category: Design Consistency
Description: CardThemeData uses BorderRadius.circular(24), but FilledButton, OutlinedButton, FloatingActionButton all use BorderRadius.circular(18). Minor inconsistency creates visual jitter.
L4 — Live Chat Status Banner Has No Animation
Location: live_chat_page.dart:169
Category: UX / Motion
Description: Connection status banner appears/disappears instantly via if (_connectionState != null). Should use AnimatedSize or AnimatedSwitcher for smooth entrance.
Suggested command: /animate
L5 — analysis_options.yaml Not Reviewed
Location: analysis_options.yaml
Category: Code Quality
Description: flutter_lints is listed as a dev dependency but the rules file content was not verified. No custom lint rules for token usage enforcement.
L6 — pubspec.yaml SDK Constraint Is Pre-release
Location: pubspec.yaml:22
Category: Build Stability
Description: sdk: ^3.11.4 — Dart 3.11.4 is not yet a stable release (current stable is 3.7.x as of early 2026). This may cause CI inconsistencies.
Patterns & Systemic Issues
Hardcoded colors appear in 4+ files — a consistent pattern of bypassing the token system exactly where it was most needed (status indicators, chat bubbles, splash).
Hardcoded Turkish strings in 8+ files — the l10n system is set up correctly but bypassed for ~40 strings throughout feature pages and core widgets.
Modal dialogs used for complex interactions — profile edit (14 fields), password change, email change, comment delete, post delete — all in AlertDialog. Only live chat edit/delete use bottom sheets (correct pattern).
No semantic annotations anywhere — this is a systemic gap, not per-feature. Requires a dedicated accessibility pass.
Identical loading states — every async state shows the same CircularProgressIndicator. No content-aware loading states.
Positive Findings
Token system architecture is excellent — SdalThemeTokens with lerp support, ThemeExtension, both light/dark defined, warm earthy palette is distinctive and non-generic.
FeatureScaffold is a good pattern — consistent app bar with avatar shortcut, background variants, app menu integration.
Live chat is the best-implemented screen — uses tokens correctly, has realtime events, scroll management, message actions, adaptive composer layout.
RemoteAvatar handles edge cases well — loading fallback to initials, error fallback, URL normalization.
_PreferencesCard expand/collapse has proper AnimatedRotation + AnimatedCrossFade — good use of animation for state communication.
_ProfileRow responsive stacking — correctly stacks label/value on small screens and text-scaled displays.
Realtime connection status shown in thread header — good visibility of system state.
ErrorView never exposes raw exception strings — user-friendly.
AppSupportDirectory for persistent storage is properly abstracted.
Riverpod usage
Now let me check for hardcoded colors and other issues across the codebase.

Grep "Color\(0x" (in mobile/flutter_sdal/lib, glob: *.dart)
69 lines of output
Grep "Colors\." (in mobile/flutter_sdal/lib, glob: *.dart)
34 lines of output
Grep "Semantics|MergeSemantics|ExcludeSemantics|semanticsLabel|semanticLabel" (in mobile/flutter_sdal/lib, glob: *.dart)
7 lines of output
Grep "AnimatedContainer|AnimatedOpacity|AnimatedBuilder|TweenAnimationBuilder|AnimatedSwitcher|Hero\(" (in mobile/flutter_sdal/lib, glob: *.dart)
5 lines of output
Now I have a comprehensive picture of the Flutter app. Let me compile the full audit report.

Flutter App Audit Report — mobile/flutter_sdal
Anti-Patterns Verdict
Pass — not AI slop. The warm amber/terracotta palette, warm-tinted neutrals, and Manrope font are deliberate choices that avoid the typical "cyan-on-dark, glowing neon" AI aesthetic. The token system is genuinely well-thought-out. However, the code contains scattered anti-patterns that undermine the otherwise solid design system.

Executive Summary
Severity	Count
Critical	3
High	5
Medium	7
Low	4
Top 3 issues:

Chat bubbles bypass the design token system entirely, using hardcoded dark navy + white instead of tokens.chatOutgoing / tokens.chatIncoming
Near-zero accessibility semantics — only 14 Semantics usages across all presentation files; screen readers will fail on most interactive surfaces
Profile editing UX puts 14+ form fields in an AlertDialog — a major usability problem on small screens
Quality score: 6.5 / 10 — Strong foundation, execution gaps.

Next steps: /harden for the hardcoded color issues, /fixing-accessibility for semantics, /onboard for empty states.

Detailed Findings
Critical Issues
C1 — Chat bubbles ignore design tokens

Location: thread_detail_page.dart:199–203
Category: Theming
Description: Outgoing bubble color is const Color(0xFF0D2238) and incoming is Colors.white — raw hex values that don't switch in dark mode and were not sourced from SdalThemeTokens. The token system already has tokens.chatOutgoing and tokens.chatIncoming for exactly this purpose. Live chat (live_chat_page.dart) correctly uses tokens.chatOutgoing / tokens.chatIncoming, but thread_detail_page.dart does not.
Impact: In dark mode, the chat view will use light-mode colors. Direct/private messages look visually inconsistent with the live chat feature.
Recommendation: Replace const Color(0xFF0D2238) / Colors.white with tokens.chatOutgoing / tokens.chatIncoming. Remove the boxShadow (uses Colors.black — also hardcoded).
Suggested command: /normalize
C2 — Splash screen hardcoded colors detached from theme

Location: status_views.dart:15
Category: Theming
Description: AppSplashScreen uses [Color(0xFF0D2238), Color(0xFF173657)] as gradient stops. These are hardcoded dark-navy values. They don't use SdalThemeTokens, they won't adapt to theme changes, and they represent a completely different visual language from the warm amber/terracotta brand.
Impact: The very first thing a user sees is off-brand. The app transitions from a cold navy blue into a warm amber product, which is jarring.
Recommendation: Use tokens.canvas and tokens.accent for the gradient stops, referencing the design token system. Or simply set Scaffold(backgroundColor: tokens.canvas) for a clean branded splash.
Suggested command: /normalize
C3 — Near-zero accessibility semantics

Location: Entire lib/ — only 14 total Semantics usages across all files
Category: Accessibility (WCAG A violation)
Description: Interactive InkWell wrappers around RemoteAvatar (navigate to member profile, navigate to author) have no Semantics label. The _NavBadgeIcon badge count is not exposed to screen readers. The _AppMenuButton (grid icon) has a tooltip but no semantic role. Most IconButton refresh buttons have no tooltip. Icon-only buttons throughout the app provide no accessible name.
Impact: Screen reader users (VoiceOver/TalkBack) cannot navigate the app meaningfully. The badge count for unread messages/notifications is invisible to assistive technology.
Recommendation: Wrap InkWell around avatars with Semantics(label: '${member.name} profilini aç', button: true). Add Semantics(label: '${count} okunmamış mesaj') to _NavBadgeIcon. Add tooltip: to all IconButton instances. Use ExcludeSemantics on decorative icons inside already-labeled buttons.
Standard: WCAG 2.1 SC 1.1.1 (Non-text Content), SC 4.1.2 (Name, Role, Value)
Suggested command: /fixing-accessibility
High-Severity Issues
H1 — Profile status chips use hardcoded colors

Location: profile_page.dart:104–109
Category: Theming
Description: _StatusChip widgets use const Color(0xFF0D7A4B) (should be tokens.success), const Color(0xFF9A6700) (should be tokens.warning), and const Color(0xFF173657) (should be tokens.info). These are copies of the token values, not references — they'll drift out of sync and won't adapt to dark mode.
Impact: Status chips use wrong colors in dark mode (token values are lighter in dark mode).
Recommendation: Replace all three hardcoded values with the appropriate token references.
Suggested command: /normalize
H2 — Colors.blue / Colors.black54 usage in multiple feature pages

Location: following_page.dart:151,160,209, album_photo_page.dart:169,176, notifications_page.dart:208, networking_pages.dart:386
Category: Theming
Description: Raw Colors.blue (link-style color), Colors.black54 (secondary text), and Color(0xFF1F6FEB) (unread indicator) are hardcoded across multiple feature pages. None of these adapt to dark mode. Colors.black54 on dark backgrounds will have near-zero contrast.
Impact: Dark mode users will see near-invisible text (black on dark background). Unread notification dot color is incorrect (bright blue vs. brand accent).
Recommendation: Replace Colors.blue with tokens.info or tokens.accent. Replace Colors.black54 with tokens.foregroundMuted. Replace Color(0xFF1F6FEB) on unread dots with tokens.info.
Suggested command: /normalize
H3 — Profile edit puts 14+ fields in an AlertDialog

Location: profile_page.dart:451–607
Category: Responsive Design / UX
Description: _openEditProfileDialog opens a showDialog<void> with SingleChildScrollView containing 14 TextField widgets plus 4 SwitchListTile widgets. On mobile screens, this modal cannot show its full height, the keyboard pushes content off-screen, and there's no way to see field context while typing.
Impact: Editing profile is broken on smaller phones — fields near the bottom may be unreachable with keyboard open. AlertDialog on mobile is a well-known anti-pattern for complex forms.
Recommendation: Promote profile editing to a dedicated page (ProfileEditPage) navigated via context.push('/profile/edit'). Use a Scaffold with a scroll view, not a dialog.
Suggested command: /harden
H4 — No loading skeletons; all async states show only spinners

Location: Every feature page — feed, explore, notifications, profile, messenger, etc.
Category: Performance / UX
Description: Every AsyncValue.when(loading: () => Center(child: CircularProgressIndicator())) causes blank-to-content layout shifts. There are no shimmer placeholders or skeleton layouts. For dense list views (notifications, explore), this is especially jarring as the page jumps from nothing to a full list.
Impact: Perceived performance is poor. Users have no layout preview while loading, causing orientation/scroll position to be lost on refresh.
Recommendation: Add skeleton placeholders for the primary content area of each page using a Shimmer effect or static placeholder layouts matching the real content structure.
Suggested command: /animate
H5 — Empty states provide no guidance

Location: Throughout — explore, notifications, messenger, live chat, requests, etc.
Category: UX (Onboarding)
Description: Empty states are bare text inside SurfaceCard: Text(l10n.notificationsEmpty), Text(l10n.exploreNoSuggestions), Text(l10n.threadEmpty). None provide context about what the feature is for, why it's empty, or what action to take to populate it.
Impact: First-time users see a blank card with a generic message. They don't know what action creates content or why the section is empty.
Recommendation: Design purposeful empty states with an icon, descriptive headline, explanation, and a CTA button where applicable. Example: For notifications empty state, show a bell icon, "No notifications yet", "You'll see activity from your network here", and a button to explore members.
Suggested command: /onboard
Medium-Severity Issues
M1 — AnimatedContainer used for animating decoration (triggers layout)

Location: feed_page.dart:808, requests_page.dart:481
Category: Performance
Description: AnimatedContainer animates layout properties along with decoration. When only color/border changes are needed, this is wasteful. AnimatedContainer calculates layout on every animation frame, even when dimensions don't change.
Recommendation: Use AnimatedDecoratedBox (or a raw DecoratedBox with a separate TweenAnimationBuilder on color) for decoration-only animations to keep them off the layout phase.
Suggested command: /fixing-motion-performance
M2 — Hardcoded localized strings outside the l10n system

Location: profile_page.dart:303–325, feature_scaffold.dart:289–334, explore_page.dart:78
Category: Responsive / i18n
Description: Story feed titles are constructed from Dart switch expressions with inline Turkish/English strings (isTurkish ? 'Ana Akış Hikayelerim' : 'My Main Feed Stories'). Menu section headings ('Ana gezinme', 'Topluluk', 'Yönetim') and 'En Yeni Üyeler' are all hardcoded Turkish strings not routed through AppLocalizations.
Impact: The app supports both Turkish and English (supportedLocales: [Locale('tr'), Locale('en')]), but these strings never change with locale. English-language users see Turkish UI.
Recommendation: Add all these strings to the .arb localization files and access via context.l10n.*.
Suggested command: /harden
M3 — No scroll-to-bottom button in chat

Location: thread_detail_page.dart, live_chat_page.dart
Category: UX / Responsive
Description: Both chat implementations _jumpToBottom() on every new message using animateTo(maxScrollExtent). If the user is scrolled up reading history, a new incoming message forcibly scrolls them to the bottom. There's no "new message" indicator or scroll-to-bottom button.
Impact: Users reading chat history are interrupted whenever any message arrives. This is a known chat UX anti-pattern.
Recommendation: Only auto-scroll if the user is already near the bottom (within ~100px of maxScrollExtent). Show a floating badge/button with the unread count if they're scrolled up.
Suggested command: /harden
M4 — Missing focus indicators on custom interactive surfaces

Location: Multiple — InkWell avatars, _MenuTile, custom chip components
Category: Accessibility (WCAG AA)
Description: Custom tappable surfaces like InkWell-wrapped avatars and _MenuTile rely only on InkWell's default focus ring, which is often insufficient. DecoratedBox-based custom components (like _StatusChip, _SidebarHighlights pills) are not keyboard-focusable at all.
Standard: WCAG 2.1 SC 2.4.7 (Focus Visible)
Recommendation: Ensure all interactive elements are wrapped in Focus widgets with visible FocusNode decoration when focused. Use FocusableActionDetector for complex custom targets.
Suggested command: /fixing-accessibility
M5 — Refresh button on every page is duplicate pattern, no pull-to-refresh on most lists

Location: All FeatureScaffold pages — explore, profile, notifications, etc.
Category: UX
Description: Every page adds IconButton(icon: Icon(Icons.refresh)) as an app bar action. This is a crutch — pull-to-refresh (RefreshIndicator) is the native mobile pattern for list refresh and is used in only a few places (live chat). Most ListView pages don't have RefreshIndicator.
Recommendation: Add RefreshIndicator to all paginated ListView views and remove the manual refresh button (or at minimum reduce its prominence). Keep it only for non-list pages where pull-to-refresh doesn't apply.
Suggested command: /harden
M6 — TextAlign.left redundant annotations

Location: post_detail_page.dart:253, 264, 339, 346
Category: Code quality (Low UX impact)
Description: Multiple Text widgets specify textAlign: TextAlign.left which is the default for LTR locales. These are redundant but more importantly signal that RTL layout hasn't been considered (if the app is ever used in an RTL language context, these explicit overrides would break RTL text alignment).
Recommendation: Remove redundant textAlign: TextAlign.left. For deliberate alignment, use TextAlign.start instead which respects text direction.
Suggested command: /harden
M7 — Register page CAPTCHA timing UX gap

Location: auth_pages.dart:212–253
Category: UX / Accessibility
Description: The CAPTCHA SVG is loaded asynchronously but there's no loading indicator or placeholder shown while it loads. The CAPTCHA field appears before the image loads, users might try to submit before they can see the CAPTCHA. After a failed submit, the form doesn't scroll to the error.
Impact: Users may be confused about why the CAPTCHA field has no image, or try submitting prematurely.
Recommendation: Show a placeholder/spinner while _captchaSvg is null. Add a ScrollController to auto-scroll to the error message after a failed submit.
Suggested command: /harden
Low-Severity Issues
L1 — Magic number maxWidth: 320 for chat bubbles

Location: thread_detail_page.dart:209
Category: Responsive Design
Description: Chat bubble max width is BoxConstraints(maxWidth: 320) — a fixed pixel value that may overflow on very narrow devices or look too small on tablets.
Recommendation: Replace with MediaQuery.sizeOf(context).width * 0.72 (matching the pattern used in live chat).
L2 — admin_pages.dart uses hardcoded tint colors not from tokens

Location: admin_pages.dart:3972, 3987, 4003, 4018, 4034, 4050, 4066
Category: Theming
Description: Admin dashboard metric cards use tint: Color(0xFF355C87) etc. One tint (Color(0xFF6A4FB4)) doesn't exist in the token system at all (a purple that appears nowhere else in the design). Admin pages also use Colors.blueAccent, Colors.redAccent, Colors.orange — all raw Material colors.
Recommendation: Map admin metric tints to token equivalents (info, warning, success, danger). Add a purple/special token if the admin dashboard genuinely needs one.
L3 — BorderRadius.circular(999) magic number anti-pattern

Location: Multiple — _NavBadgeIcon, ChipTheme, _StatusChip, _SidebarHighlights, _QuickAccessTile online indicator
Category: Code quality
Description: BorderRadius.circular(999) is a common hack for pill shapes. Flutter provides StadiumBorder or BorderRadius.circular(100) is sufficient. More importantly, there's no consistent border radius scale — values like 14, 18, 20, 22, 24, 999 all appear without a defined system.
Recommendation: Define a border radius scale in SdalThemeTokens (e.g. radiusSm: 12, radiusMd: 18, radiusLg: 24, radiusPill: 999) for consistency.
L4 — pubspec.yaml has no app icon / assets configured

Location: pubspec.yaml:71–103
Category: Production readiness
Description: The assets section is entirely commented out. No app icon is configured in the Flutter pubspec. The app is missing branded assets (icon, splash image).
Recommendation: Configure flutter_launcher_icons and add a branded app icon asset.
Patterns & Systemic Issues
Hardcoded colors appear in 10+ files — Colors.blue, Colors.black54, Colors.white, Colors.blueAccent, and raw Color(0xFF...) hex values appear outside the token system. The SdalThemeTokens system is excellent but under-used.

Accessibility coverage is approximately 5% — 14 Semantics usages across the entire UI layer. Interactive elements that navigate, trigger actions, or display state information are consistently missing Semantics annotations.

Every async state is a spinner — CircularProgressIndicator() appears 20+ times as the sole loading state. No skeleton layouts exist anywhere.

Modal overuse — Profile edit (14 fields), delete confirmations, email change, password change, comment delete, post delete, live chat edit — all use showDialog. The result is a wall of modals for routine user flows.

Localization gaps — The l10n system is in place but bypassed in 10+ locations with hardcoded Turkish strings.

Positive Findings
SdalThemeTokens — Semantic, comprehensive, lerp-capable. Light and dark variants are warm-tinted and cohesive. This is exemplary Flutter theming.
ErrorView — Branded, friendly, hides raw exception strings. Has compact/full variants. An excellent shared component.
RemoteAvatar — Graceful degradation (initials → placeholder → image), semantic label, medium filter quality. Well-built.
Auth forms — Real-time availability checking with debounce, CAPTCHA, autofill hints. Production-quality form thinking.
FeatureScaffold — Consistent per-screen shell with user avatar shortcut, back navigation, and menu abstraction. Scales well.
AnimatedCrossFade in preferences panel — Smooth expand/collapse with Curves.easeOutCubic. Correct easing.
Responsive text scaling — _ProfileRow adapts layout at text scale > 1.15. Live chat composer stacks at narrow widths. Good accessibility-adjacent thinking.
Real-time architecture — WebSocket integration in live chat and messenger with proper stream subscription lifecycle management.
Recommendations by Priority
Immediate (Critical blockers)

Fix thread_detail_page.dart chat bubble colors → use tokens.chatOutgoing / tokens.chatIncoming
Fix splash screen colors → use token system
Begin accessibility pass on interactive elements (avatar InkWells, badge icons, icon buttons)
Short-term (This sprint)
4. Fix all Colors.blue / Colors.black54 / Color(0xFF1F6FEB) occurrences in following_page, album_photo_page, notifications_page, networking_pages
5. Fix profile status chip hardcoded colors
6. Move profile editing out of AlertDialog into a dedicated page
7. Add tooltip: to all IconButton instances without one
8. Fix hardcoded Turkish strings in explore_page, profile_page, feature_scaffold

Medium-term (Next sprint)
9. Add skeleton/shimmer loading states to main list views (feed, explore, notifications, messenger)
10. Design proper empty states with teaching content and CTAs
11. Add pull-to-refresh (RefreshIndicator) to all main list views; remove or demote manual refresh buttons
12. Fix auto-scroll behavior in chat to only fire when user is near bottom; add unread indicator

Long-term (Quality improvements)
13. Define a border radius scale in tokens;

I now have enough data for a thorough audit. Here's the comprehensive report:

Flutter App Audit Report
App: flutter_sdal — SDAL Social Platform iOS/Android Client
Date: 2026-04-07
Files reviewed: ~25 presentation files, full theme system, core widgets

Anti-Patterns Verdict
PARTIAL PASS — Not generic AI slop, but has specific tells.

Strengths that distinguish it:

Warm parchment/terracotta palette (#F7F1E8 canvas, #C8633C accent) avoids the cyan-on-dark / purple-gradient AI fingerprint
Semantic token naming (canvas, panel, accentMuted, chatOutgoing) is genuinely thoughtful design work
AI-Slop tells found:

Splash screen — LinearGradient with hardcoded dark navy [Color(0xFF0D2238), Color(0xFF173657)] — a spinner on a dark gradient is peak AI loading screen
Card grid everywhere — SurfaceCard wraps nearly every list item across all pages; profile page alone has 5 stacked cards
Modal for 14-field form — Profile edit dialog is an AlertDialog scrolling through 14 fields. This is the "modal as lazy default" anti-pattern
Identical card rows — Member cards in explore have identical avatar+name+meta+button structure repeated in horizontal scroll and vertical list
Executive Summary
Severity	Count
Critical	3
High	8
Medium	7
Low	5
Top 3 issues: Chat bubble dark mode bug, profile edit modal UX, pervasive hardcoded strings bypassing l10n.

Overall quality: Foundation is solid (token system, arch, real-time features). The execution layer has systemic issues in i18n consistency, accessibility, and hardcoded colors that slip through the token system.

Detailed Findings
Critical Issues
C1 — Chat Bubbles Don't Use Theme Tokens (Dark Mode Bug)

Location: thread_detail_page.dart:198-204
Severity: Critical
Category: Theming
Description: DM bubble colors are const Color(0xFF0D2238) and Colors.white — hardcoded values that ignore tokens.chatOutgoing / tokens.chatIncoming which are defined precisely for this purpose and used correctly in live_chat_page.dart
Impact: In dark mode, DM bubbles render with light-theme colors. Users in dark mode see near-invisible dark navy outgoing bubbles against a dark background. Core feature is visually broken.
Recommendation: Replace with tokens.chatOutgoing, tokens.chatIncoming, tokens.foregroundOnAccent / tokens.foreground — same as live_chat_page.dart:229-237
Suggested command: /normalize
C2 — Profile Edit: 14-Field AlertDialog

Location: profile_page.dart:451-607
Severity: Critical
Category: Responsive / UX
Description: Editing a profile opens an AlertDialog with 14 TextField widgets, 4 SwitchListTile widgets, scrollable content inside a modal. On small phones (iPhone SE), this is unusable — the keyboard and the modal fight for space.
Impact: Users cannot comfortably edit their profile on small screens. The pattern also violates the "modals are lazy" principle — a dedicated edit page would be more usable and discoverable.
Recommendation: Replace with a dedicated /profile/edit page using FeatureScaffold. Email change and password change dialogs have the same problem but are smaller in scope.
Suggested command: /harden
C3 — Hardcoded Strings Bypass l10n System (Systemic)

Location: Across feature_scaffold.dart, post_detail_page.dart, explore_page.dart, profile_page.dart, notifications_page.dart, thread_detail_page.dart
Severity: Critical
Category: Responsive / Accessibility
Description: The app declares support for both Turkish and English (supportedLocales: [Locale('tr'), Locale('en')]), but dozens of UI strings are hardcoded Turkish in widget build methods and never extracted to the ARB localization files. Examples:
'En Yeni Uyeler' (explore_page, line 78)
'Dizin filtreleri', 'Mezuniyet yılı', 'Filtreleri uygula' (explore_page)
'Hikayeler', 'Ad', 'Soyad', etc. (profile_page labels)
'Ana gezinme', 'Topluluk', 'Ek sayfalar' (feature_scaffold)
'Ogretmen baglantilari' (feature_scaffold line ~224 — also missing Turkish diacritics, should be 'Öğretmen bağlantıları')
Dozens of snackbar messages: 'Gönderi silinemedi.', 'Yorum gönderilemedi.', etc.
Impact: English-locale users see Turkish strings everywhere. The l10n infrastructure is set up but not used consistently.
Suggested command: /harden (extract strings), /clarify (improve copy)
High-Severity Issues
H1 — Splash Screen Uses Hardcoded Colors Outside Token System

Location: status_views.dart:15-16
Severity: High
Category: Theming
Description: Splash gradient [Color(0xFF0D2238), Color(0xFF173657)] is hardcoded dark navy that doesn't exist in SdalThemeTokens. These colors come from a different visual language than the rest of the app (warm parchment/terracotta). The splash screen looks like a different product.
Impact: Brand discontinuity on app launch. Won't adapt to theme changes. The warm-toned app starts with a cold dark gradient.
Recommendation: Use tokens.accent to tokens.canvas gradient (same as _AuthFrame) or define a splashBackground token. Alternatively match the auth frame style for consistency.
Suggested command: /normalize
H2 — Accessibility: Profile Avatar Touch Target Too Small

Location: feature_scaffold.dart:103-112
Severity: High
Category: Accessibility
Description: The profile avatar in the app bar leading area has radius: 16 (32px total), wrapped in a 4px padding Padding(padding: EdgeInsets.all(4)). Total interactive area is 40px. Minimum touch target should be 44×44pt per Apple HIG and Material guidelines. The InkWell wrapping it has borderRadius: BorderRadius.circular(999) which clips the ripple to the avatar, making it feel even smaller.
Impact: Users with motor difficulties may fail to tap the avatar. Primary navigation tap target for profile access.
WCAG/Standard: WCAG 2.5.5 Target Size (AAA), iOS HIG 44pt minimum, Material 48dp minimum
Recommendation: Increase to radius: 20 (40px + 4px padding = 48px) or add explicit minWidth/minHeight constraints via ConstrainedBox.
Suggested command: /fixing-accessibility
H3 — Accessibility: No Semantic Labels on Loading Indicators

Location: All pages — e.g., post_detail_page.dart:53, explore_page.dart:80
Severity: High
Category: Accessibility
Description: CircularProgressIndicator() widgets are used ~20+ times with no semanticsLabel or wrapping Semantics. Screen readers announce nothing when content is loading.
Impact: VoiceOver/TalkBack users receive no feedback that content is loading. They may think the app is frozen.
WCAG/Standard: WCAG 4.1.3 Status Messages (AA)
Recommendation: Add semanticsLabel to all CircularProgressIndicator usages: CircularProgressIndicator(semanticsLabel: context.l10n.loading). Define a loading key in ARB.
Suggested command: /fixing-accessibility
H4 — Accessibility: Unread Notification Dot Has No Semantics

Location: notifications_page.dart:204-211 and networking_pages.dart:386
Severity: High
Category: Accessibility
Description: Unread status is indicated via Icon(Icons.circle, size: 10, color: Color(0xFF1F6FEB)). This is purely visual with no semantic alternative. Also uses a hardcoded Color(0xFF1F6FEB) (hardcoded blue not in token system).
Impact: Screen reader users cannot determine which notifications are unread. The hardcoded blue also fails dark mode.
WCAG/Standard: WCAG 1.4.1 Use of Color (A), WCAG 1.3.1 Info and Relationships (A)
Recommendation: Wrap in Semantics(label: 'Unread', child: ...) and replace Color(0xFF1F6FEB) with tokens.info.
Suggested command: /fixing-accessibility, /normalize
H5 — Hardcoded Colors in Profile Status Chips

Location: profile_page.dart:104-109
Severity: High
Category: Theming
Description: _StatusChip uses const Color(0xFF0D7A4B) (verified green), const Color(0xFF9A6700) (pending yellow), const Color(0xFF173657) (role blue). These are close but not identical to theme tokens success, warning, info.
Impact: Status chip colors don't adapt to dark mode. The chips are a key user-facing element (verification status).
Recommendation: Replace with tokens.success, tokens.warning, tokens.info respectively.
Suggested command: /normalize
H6 — Disabled Comment Button is Confusing UX

Location: post_detail_page.dart:161-168
Severity: High
Category: Accessibility / UX
Description: FilledButton.tonalIcon(onPressed: null, icon: Icon(Icons.chat_bubble_outline), label: Text('${post.commentCount} yorum')) — a visually styled tappable button with onPressed: null. Users will tap it expecting to navigate to comments, but nothing happens.
Impact: Confusing interaction, appears broken. Users may think the app is unresponsive.
Recommendation: Replace with a non-interactive display — a Row with an icon and text, or remove the button chrome. Alternatively make it scroll to the comment section.
Suggested command: /clarify
H7 — No Empty State Design — Just Text Strings

Location: Multiple pages: explore, feed, notifications, thread, profile
Severity: High
Category: UX / Accessibility
Description: Empty states are bare text strings in SurfaceCard or Center:
SurfaceCard(child: Text('Henüz yorum yok.')) (post detail)
SurfaceCard(child: Text(l10n.notificationsEmpty)) (notifications)
Center(child: Text(l10n.threadEmpty)) (thread)
Latest members section silently disappears with SizedBox.shrink() if empty
Impact: Users don't know why content is absent or what to do about it. The SizedBox.shrink() case is worse — the section heading appears with nothing beneath it.
Recommendation: Each empty state should have: an illustration or icon, a descriptive message, and a call-to-action where relevant.
Suggested command: /onboard
H8 — Repeated Identical Loading Pattern (20+ Spinners)

Location: All presentation files
Severity: High
Category: Performance / UX
Description: Every AsyncValue.when() uses the identical loading: () => const Center(child: CircularProgressIndicator()). PostDetailPage shows two independent spinners simultaneously (post + comments). The notification preferences card wraps its spinner in a SurfaceCard. No skeleton loading or progressive disclosure.
Impact: Content loads abruptly causing layout shifts. Multiple simultaneous spinners on one screen feel chaotic.
Recommendation: Implement skeleton loading using ColorFiltered or animated containers in neutral placeholder colors from the token system. At minimum, use shimmer or Skeletonizer package for list items.
Suggested command: /animate
Medium-Severity Issues
M1 — ThreadDetailPage: Side Effect in Build (markThreadRead)

Location: thread_detail_page.dart:145-153
Severity: Medium
Category: Performance
Description: markThreadRead is called inside the data: builder using Future<void>.microtask(...). This will be called every time the widget rebuilds while _markedRead is false. If ref.invalidate() triggers multiple rebuilds before the async completes, this may fire multiple times.
Impact: Potential extra API calls; doesn't cause UI breakage but creates unnecessary network traffic.
Recommendation: Move the markThreadRead call to initState or didChangeDependencies after the first data is available, or use a Riverpod listener with ref.listenManual.
M2 — Bubble Border Radius Inconsistency

Location: thread_detail_page.dart:213 vs live_chat_page.dart:233
Severity: Medium
Category: Theming
Description: DM bubbles use BorderRadius.circular(20), live chat bubbles use BorderRadius.circular(22). Minor inconsistency that indicates lack of a shared message bubble component.
Recommendation: Extract a MessageBubble widget with consistent radius and shared colors from tokens.
Suggested command: /extract
M3 — Admin Pages Use Colors.blueAccent / Colors.redAccent

Location: admin_pages.dart:1667, 2371, 2821, 3049
Severity: Medium
Category: Theming
Description: Admin page status cards use Colors.blueAccent, Colors.redAccent instead of tokens.info, tokens.danger. Admin purple (Color(0xFF6A4FB4)) is not in the token system at all.
Impact: Admin panel has different visual language than the rest of the app, and colors won't adapt to dark mode.
Suggested command: /normalize
M4 — AnimatedCrossFade Uses Linear Fade, No Size Curve

Location: notifications_page.dart:513-585
Severity: Medium
Category: Performance / Animation
Description: AnimatedCrossFade with sizeCurve: Curves.easeOutCubic but the duration: Duration(milliseconds: 180) is fast enough that the cross-fade itself could use FadeInImage or AnimatedSwitcher approach. The AnimatedRotation for the chevron is good. The content cross-fade clips the old content suddenly. This is acceptable but the height animation uses layout (height changes), which is not compositor-only.
Recommendation: For the expand/collapse animation on the preferences card, prefer AnimatedSize + ClipRect + FadeTransition to avoid layout animations.
Suggested command: /fixing-motion-performance
M5 — Following Page Uses Colors.blue / Colors.black54

Location: following_page.dart:151-209
Severity: Medium
Category: Theming
Description: Follow/pending status chips use Colors.blue and Colors.black54 — neither adapts to dark mode. Colors.black54 on a dark background is near-invisible.
Suggested command: /normalize
M6 — Album Photo Page Uses Colors.blue, Colors.black54

Location: album_photo_page.dart:88, 169, 176
Severity: Medium
Category: Theming
Description: Same pattern as following_page — Colors.blue and Colors.black54 hardcoded.
Suggested command: /normalize
M7 — No Transition Animations Between Routes

Location: App-wide (app_router.dart)
Severity: Medium
Category: Animation / UX
Description: GoRouter uses default page transitions (standard slide on iOS, fade on Android). No custom transitions between main sections or detail pages. The app feels functional but flat — no sense of spatial navigation.
Impact: The app feels like a web app adapted to mobile rather than a native experience.
Recommendation: Add CustomTransitionPage with FadeTransition for tab navigation and SlideTransition for hierarchical navigation within go_router.
Suggested command: /animate
Low-Severity Issues
L1 — SurfaceCard Has Only One Padding Variant

Location: surface_card.dart
Severity: Low
Category: UX
Description: SurfaceCard defaults to EdgeInsets.all(18). Many call sites pass padding: EdgeInsets.zero or custom values. The naming is somewhat misleading — it's just Card + Padding.
Recommendation: Consider adding semantic variants (compact, default, spacious) to prevent divergent call sites.
L2 — Registration Form: Default Year Hardcoded to '2011'

Location: auth_pages.dart:178
Severity: Low
Category: UX
Description: TextEditingController(text: '2011') — graduation year defaults to 2011 which may be outdated. Should default to current year or be blank.
L3 — Missing Turkish Diacritics in Menu Label

Location: feature_scaffold.dart:~224
Severity: Low
Category: UX Copy
Description: 'Ogretmen baglantilari' — missing Turkish diacritics. Should be 'Öğretmen bağlantıları'. This string also isn't in l10n.
L4 — Google icon for OAuth Uses Generic Icon

Location: auth_pages.dart:107-108
Severity: Low
Category: UX
Description: Icon(Icons.g_mobiledata) is used as the Google sign-in icon. This is not the Google logo — it's a generic cellular data icon. The X/Twitter button uses Icons.alternate_email (which is the @ icon) — also not the X logo.
Recommendation: Use flutter_svg (already a dependency) with brand icons, or use a google_sign_in-branded button package.
L5 — BoxShadow on Every Chat Bubble (DM page)

Location: thread_detail_page.dart:214-220
Severity: Low
Category: Performance
Description: BoxShadow with blurRadius: 18 on every message bubble. With long conversations, this is a lot of shadow rendering. Live chat page correctly omits shadows on its bubbles.
Recommendation: Remove the drop shadow or switch to a subtle border (like live chat uses Border.all(color: tokens.panelBorder)).
Patterns & Systemic Issues
Hardcoded strings in 8+ files — The l10n system exists and is used in some files but bypassed in others. Needs a full pass to extract remaining strings.
Colors.black54 / Colors.blue appear in 4+ feature files — A consistent pattern of using Material Colors.* constants instead of theme tokens for secondary text and accent colors.
SurfaceCard used for every list item — Instead of a card grid, a ListView with Divider or a custom InkWell-wrapped row would give better visual rhythm and less visual weight.
Loading states always show full-screen or centered spinner — No progressive disclosure, no skeleton loading. Systematic across all 15+ pages.
Positive Findings
SdalThemeTokens — Exceptional semantic token system with proper lerp() for smooth transitions. Warm, distinctive palette. Both light and dark variants are complete and well-considered.
FeatureScaffold — Elegant pattern that centralizes the app bar with contextual profile avatar as back/profile button. Smart reuse.
ErrorView — Clean, on-brand error component that correctly hides raw exception strings.
Text scaling support — profile_page.dart and live_chat_page.dart check MediaQuery.textScalerOf(context).scale(1) > 1.15 and adapt layout. This is rare and well done.
Real-time chat — Live chat and DM both handle connection state display, reconnection, and message merging correctly.
Registration flow — Debounced availability check, captcha support, and KVKK consent are all correctly implemented.
RemoteAvatar — Correctly handles empty URLs, initials fallback, 'yok'/'null' string normalization, loading state, and error state.
Recommendations by Priority
Immediate (Critical Blockers)
Fix DM chat bubbles — Use tokens.chatOutgoing/tokens.chatIncoming to fix dark mode breakage (/normalize)
Replace profile edit modal — Dedicated edit page for better mobile UX (/harden)
Audit and extract hardcoded l10n strings — Full pass across 8+ files (/harden + /clarify)
Short-Term (This Sprint)
Fix all Colors.black54, Colors.blue, Color(0xFF1F6FEB) usages with token equivalents (/normalize)
Fix profile status chips to use tokens.success/tokens.warning/tokens.info (/normalize)
Add semanticsLabel to all CircularProgressIndicator and semantics to unread dot (/fixing-accessibility)
Fix disabled comment button — make it non-interactive display or functional (/clarify)
Increase profile avatar touch target to ≥44px (/fixing-accessibility)
Medium-Term (Next Sprint)
Redesign empty states with illustration + call-to-action (/onboard)
Introduce skeleton loading for list items (/animate)
Extract shared MessageBubble widget to fix bubble inconsistencies (/extract)
Fix Turkish diacritics in hardcoded menu labels (/clarify)
Long-Term (Nice-to-Haves)
Add custom route transitions for spatial navigation feel (/animate)
Replace OAuth brand icons with correct logos
Fix markThreadRead side effect in build method
Add route transitions (/animate, /overdrive)
Suggested Commands Summary
Issue Category	Affected Count	Command
Hardcoded colors outside token system	12+ locations	/normalize
Missing l10n strings	8+ files	/harden + /clarify
Accessibility gaps	5 issues	/fixing-accessibility
Profile edit modal UX	1 flow	/harden
Empty states	5+ pages	/onboard
Loading state design	15+ pages	/animate
Shared component extraction (bubbles)	2 files	/extract
Route transitions	App-wide	/animate
