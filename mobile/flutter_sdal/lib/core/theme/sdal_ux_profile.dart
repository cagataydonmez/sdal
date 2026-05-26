// UX profile enums — every dimension that differentiates theme experiences.
// Values are read by widgets to branch layout, interaction, and presentation.
// All enums have a value that matches the legacy (pre-profile) behavior so
// existing themes can declare defaults without any widget change.

// ── 1. Navigation Architecture ────────────────────────────────────────────────

enum SdalNavStyle {
  bottomBar,       // Standard Material NavigationBar (current default)
  floatingPill,    // Icons-only pill floating above safe edge, frosted glass
  sideDrawer,      // No bottom bar — hamburger opens full-height side drawer
  transparentBar,  // Nav floats over content with heavy backdrop blur
  materialFab,     // M3: bottom nav + centered morphing FAB between tabs
}

enum SdalNavLabelMode {
  always,          // All tab labels visible (current)
  selectedOnly,    // Only active tab shows label (M3 style)
  never,           // Icons only — used by floatingPill
}

enum SdalNavIndicator {
  filledPill,      // Filled rounded pill behind active icon (M3 default)
  underline,       // 3px accent underline at base of active icon
  dot,             // Small accent dot below active icon
  accentIcon,      // Only icon color changes — no indicator shape
  none,            // No indicator at all
}

enum SdalNavBarBackground {
  solid,           // Opaque surface color (current)
  frosted,         // BackdropFilter blur + translucent fill
  transparentBlur, // Fully transparent with heavy blur (Dusk)
  elevated,        // Elevated with hard drop shadow
}

// ── 2. App Bar / Header ───────────────────────────────────────────────────────

enum SdalHeaderStyle {
  standard,        // 56px fixed, logo center, avatar leading (current)
  minimal,         // 44px thin chrome, glass blur background
  collapsible,     // Large (~88px) collapses to compact on scroll
  transparent,     // No visible bar — content starts at status bar edge
  heroAvatar,      // Large profile strip collapses on scroll (Prism)
}

enum SdalHeaderBackground {
  solid,           // Opaque theme surface (current)
  frosted,         // Blur + translucent fill
  transparent,     // Fully transparent — content scrolls behind
  gradientScrim,   // Top gradient scrim fades to clear
}

enum SdalLogoPosition {
  center,          // Logo badge centered in AppBar (current)
  leading,         // Logo left-aligned
  hidden,          // Not in bar — sidebar drawer shows it instead
}

enum SdalAvatarPosition {
  leading,         // Avatar in leading slot (current)
  trailing,        // Avatar in trailing slot
  headerHero,      // Large avatar in collapsible header, not in bar
  none,            // Not shown in header area
}

enum SdalTitleAlignment {
  center,          // Centered title (current)
  start,           // Left-aligned title
}

// ── 3. Cards & Surfaces ───────────────────────────────────────────────────────

enum SdalCardStyle {
  elevated,        // Box shadow + solid background (current)
  glass,           // BackdropFilter blur + translucent fill
  flat,            // No shadow, solid fill + optional border
  outlined,        // Transparent fill, accent border only
  fullBleed,       // Edge-to-edge, image fills entire card
  tonal,           // M3 filled tonal card (surfaceContainerHigh)
}

enum SdalSurfaceDepth {
  flat,            // No elevation — zero shadow
  subtle,          // Single very soft shadow (1–2dp)
  raised,          // Medium shadow (4–6dp)
  floating,        // High shadow (8–12dp), slight scale
  glass,           // BackdropFilter replaces shadow
}

enum SdalBorderStyle {
  none,            // No border (relies on shadow)
  hairline,        // 0.5px — barely perceptible
  thin,            // 1px standard (current panelBorderWidth)
  medium,          // 2px prominent
  accent,          // 2px in accent color on interactive elements
}

enum SdalBackgroundPattern {
  solid,           // Flat solid color (current)
  subtleGradient,  // Soft 2-stop linear gradient top → bottom
  radialGlow,      // Radial gradient from center (splash / Nova)
  mesh,            // Multi-point gradient mesh
  noise,           // Subtle film grain texture overlay
}

// ── 4. Feed & List Layout ─────────────────────────────────────────────────────

enum SdalFeedLayout {
  singleColumn,    // Standard 1-column scrollable list (current)
  twoColumnGrid,   // Masonry 2-column staggered grid (Prism)
  cinematic,       // Full-width tall cards, peek below fold (Dusk)
  compact,         // Dense 1-column list, reduced padding (Flux)
  magazine,        // Lead hero card + 2-col mini-cards below
}

enum SdalListItemStyle {
  tile,            // Material ListTile — dense, icon-left
  card,            // Padded card with shadow, full width (current)
  inlineCard,      // Slim card, tight padding, no extra margin
  fullBleedCard,   // Image-first, text overlaid at bottom (Dusk)
  compact,         // Minimal height: icon + 2-line text
}

enum SdalSeparatorStyle {
  none,            // No separator
  hairline,        // 0.5px Divider
  padded,          // Divider with leading indent (Material standard)
  spacer,          // Empty vertical gap (current SurfaceCard behavior)
  cardGap,         // Cards float as tiles with gap between (Prism)
}

enum SdalScrollPhysics {
  bouncing,        // iOS BouncingScrollPhysics (current)
  clamped,         // ClampingScrollPhysics — hard stop
  snapping,        // PageScrollPhysics — snap per item (Dusk)
}

// ── 5. Interaction & Animation ────────────────────────────────────────────────

enum SdalTapFeedback {
  ripple,          // Material InkWell ripple (current)
  scalePress,      // Scale down to 0.97 on press
  lift,            // Scale up 1.02 + shadow increase on press
  highlight,       // Flash color overlay on tap
  none,            // No visual tap feedback
}

enum SdalTransitionStyle {
  slide,           // Slide in/out — current _SlidingTabBranchContainer
  fade,            // Cross-fade between tabs/pages
  scale,           // Scale + fade (M3 shared axis)
  blurFade,        // Blur + opacity cross-dissolve (Nova)
  none,            // Instant switch — no animation
}

enum SdalAnimationSpeed {
  instant,         // 0ms — no animations (accessibility)
  fast,            // 150ms
  normal,          // 250ms (current ~220ms)
  slow,            // 400ms
  dramatic,        // 600ms — cinematic pacing (Dusk)
}

enum SdalScrollBehavior {
  standard,        // Normal velocity + friction (current)
  bouncy,          // Amplified spring physics
  smooth,          // Reduced velocity, gentle decel
}

// ── 6. Avatar & User Identity ─────────────────────────────────────────────────

enum SdalAvatarShape {
  circle,          // ClipOval (current)
  roundedSquare,   // ClipRRect radius ~10–12
  hexagon,         // CustomClipper<Path> hexagonal shape
  squircle,        // iOS-style continuous curve (superellipse)
}

enum SdalAvatarBorder {
  none,            // No border (current)
  photoRim,        // 2px white/canvas rim — clean photo framing
  accentRing,      // 2px accent color ring
  glowRing,        // Colored drop shadow simulating a glow
  roleColor,       // Border color indicates member role (Flux)
  gradient,        // Multi-color gradient ring (Prism hexagon)
}

enum SdalOnlineIndicator {
  dot,             // Small colored dot bottom-right (current)
  ring,            // Colored ring around full avatar
  pulse,           // Pulsing animated dot (Nova)
  none,            // Not displayed
}

enum SdalMemberBadgeStyle {
  pill,            // "Mezun 2019" pill chip (current)
  iconTag,         // Icon + text tag below name
  colorRing,       // Badge via avatar border color only
  subtleLabel,     // Muted small text label
  none,            // Hidden
}

// ── 7. Data Presentation ─────────────────────────────────────────────────────

enum SdalMetaPlacement {
  below,           // Below title/content (current)
  trailing,        // Right-aligned, same row as title
  overlay,         // On top of image/card (Dusk)
  inline,          // Interspersed within content flow
  hidden,          // Not shown
}

enum SdalActionsStyle {
  iconRow,         // Row of icon buttons — like, comment, share (current)
  textButtons,     // Labeled text buttons
  pillButtons,     // Rounded pill buttons with counts inside
  contextMenu,     // Hidden under "•••" overflow
  floating,        // Floating overlay row on item press (Nova/Dusk)
}

enum SdalStatsDisplay {
  chips,           // Pill/chip badges with label + count (current)
  inlineText,      // Plain text "142 members · 38 posts"
  metricCards,     // Small stat tiles in a row
  progressBar,     // Bar visualization for relative stats
  hidden,
}

enum SdalTimestampStyle {
  relative,        // "2 hours ago" (current)
  absolute,        // "May 26, 14:30"
  compact,         // "2h" / "26 May"
  hidden,
}

// ── 8. Modals & Overlays ──────────────────────────────────────────────────────

enum SdalMenuStyle {
  bottomSheet,     // DraggableScrollableSheet (current)
  fullscreen,      // Full-screen frosted overlay with large type (Nova)
  drawer,          // Left slide-in persistent drawer (Prism)
  centerModal,     // Centered dialog card over dim backdrop (Dusk)
  expandedTab,     // 5th tab expands inline to module grid (Flux)
}

enum SdalModalBackdrop {
  dim,             // Dark semi-transparent (current ~0.5)
  blur,            // BackdropFilter blur only, no tint
  tinted,          // Accent-tinted translucent
  frosted,         // Blur + accent tint together (Nova)
  clear,           // No backdrop
}

enum SdalSheetStyle {
  pillHandle,      // Wide pill drag handle at top (current M3 default)
  lineHandle,      // Thin 32px line handle
  none,            // No drag handle shown
}

// ── 9. Empty & Loading States ─────────────────────────────────────────────────

enum SdalLoadingStyle {
  skeleton,        // Bone placeholder blocks (current — SkeletonView)
  shimmer,         // Shimmer wave sweep across placeholders
  spinner,         // Circular progress indicator centered
  pulse,           // Pulsing placeholder blocks (no sweep)
  dots,            // Three-dot bounce indicator (chat-style)
}

enum SdalEmptyStateStyle {
  centered,        // Large centered icon + text + button (current)
  inline,          // Small inline message within list
  minimal,         // Text only, no icon
  card,            // Empty state inside a card container
}

// ── 10. Images & Media ────────────────────────────────────────────────────────

enum SdalImageShape {
  rectangle,       // Default uncropped rectangle
  roundedSmall,    // Corner radius 4–8px (current)
  roundedLarge,    // Corner radius 16–24px (Nova/Prism)
  circle,          // Circular crop
}

enum SdalImageOverlay {
  none,            // No overlay (current)
  gradientBottom,  // Bottom-up gradient scrim for text legibility
  gradientTop,     // Top-down scrim
  frosted,         // Frosted glass patch under text
  dimmed,          // Uniform opacity dim (40–60%)
}

enum SdalPlaceholderStyle {
  shimmer,         // Animated shimmer (current — SdalNetworkImage)
  solidColor,      // Flat color fill (imagePlaceholder token)
  blurredPreview,  // Low-res blurred version loads first
  crossFade,       // Instant crossfade from color to loaded image
}

// ── 11. Typography Personality ────────────────────────────────────────────────

enum SdalHeadingWeight {
  light,           // w300 — airy, editorial
  regular,         // w400
  medium,          // w500
  semibold,        // w600 (current effective default)
  bold,            // w700
  black,           // w900 — dramatic impact (Dusk)
}

enum SdalBodyLineHeight {
  tight,           // 1.3 — data-dense (Flux)
  normal,          // 1.5 — standard (current)
  loose,           // 1.75 — airy reading (Nova)
}

enum SdalLetterSpacing {
  tight,           // −0.02em — modern headings
  normal,          // 0em (current)
  wide,            // +0.05em — all-caps labels
  ultraWide,       // +0.15em — editorial display caps (Dusk)
}

enum SdalTypographyHierarchy {
  standard,        // Balanced heading/body scale (current)
  editorial,       // Large dramatic headings, small elegant body
  functional,      // Compact headings, max-readable body
  display,         // Oversized display type — headings dominate
}

// ── 12. Spacing System ────────────────────────────────────────────────────────

enum SdalSpacingScale {
  compact,         // ×0.75 — data-dense (Flux)
  normal,          // ×1.0 (current)
  relaxed,         // ×1.25 — comfortable reading (Dusk)
  airy,            // ×1.5 — luxury, open (Nova)
}

enum SdalContentInset {
  none,            // 0px — full edge to edge (Dusk cards)
  tight,           // 8px
  standard,        // 16px (current)
  wide,            // 24px (Nova)
}

// ── 13. Notification Badges ───────────────────────────────────────────────────

enum SdalBadgeStyle {
  count,           // Numbered "99+" badge (current)
  dot,             // Plain dot, no number
  none,            // Not shown
}

enum SdalUnreadIndicator {
  badgeCount,      // Count on tab icon (current)
  coloredDot,      // Small accent dot above icon
  accentBar,       // Thin bar below nav icon
  none,
}

// ── 14. Status & Feedback ─────────────────────────────────────────────────────

enum SdalToastPosition {
  bottom,          // Snackbar at bottom (current)
  top,             // Toast at top of screen
  center,          // Centered overlay toast
}

enum SdalToastStyle {
  snackbar,        // Material Snackbar (current)
  pill,            // Small rounded pill — minimal, floating
  card,            // Card with icon + action
  banner,          // Full-width banner at top
}
