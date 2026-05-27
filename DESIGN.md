# Design System

## Overview
SDAL offers **10 user-selectable themes**. Themes are now micro-app experiences, not only palette swaps. Every theme has light and dark variants plus a theme experience profile that controls shell behavior, logo framing, content rhythm, surface material, motion, media treatment, and primary-action placement.

Theme colors remain in `lib/core/theme/sdal_app_theme.dart` and `lib/core/theme/sdal_theme_tokens.dart`. Experience profiles live in `lib/core/theme/sdal_theme_experience.dart` and are attached to `ThemeData` alongside the existing token extension.

---

## Theme Engine v2

Each theme defines these layers:

- **Identity**: physical usage scene, product promise, color strategy, and micro-app mode.
- **Palette**: semantic color tokens for surfaces, text, feedback, chat, stories, and media placeholders.
- **Shell**: navigation style, header style, transparent overlay hit-testing, and primary-action placement.
- **Composition**: feed/list rhythm, content breathing room, and control density.
- **Components**: surface material, empty-state tone, inline guidance, and blur permissions.
- **Motion**: route duration, press response, reduced-motion fallback, and tactile intensity.
- **Media**: feed image aspect, avatar frame width, story ring width, and image overlay preference.
- **Logo**: asset, frame, background, border, shadow, radius, and padding.

---

## Themes at a Glance

| Theme | Tagline | Micro-app Mode | Shell/Composition | Font | Accent Direction |
|-------|---------|----------------|-------------------|------|------------------|
| **Kor** | Ocak ağı & sıcak akış | Hearth | Warm magazine feed, standard elevated nav, guided composer action | Manrope (local) | Terracotta + indigo + community green |
| **Atlas** | Harita & yapı | Atlas | Structured controls, compact scan rhythm, precision outlined surfaces | IBM Plex Sans | Cobalt + chartreuse signal |
| **Vibe** | Sosyal nabız | Pulse | Floating pill nav, social cards, energetic story/online rhythm | Nunito | Violet + cyan + grape |
| **Zinc** | Ink & hızlı tarama | Ink | Compact header, icon nav, flat ink panels, command-like scanning | DM Sans | Graphite + cyan signal |
| **Ember** | Arşiv & etkinlik salonu | Archive | Warm archive surfaces, event/album-friendly media rhythm | Outfit | Amber + clay + oxblood |
| **Mist** | Bahçe & sakin okuma | Garden | Airy layout, calm tonal cards, profile/reading-friendly pacing | Jost | Sage + mint + coral |
| **Nova** | Uzaysal cam & zerafet | Spatial | Frosted floating pill, glass chrome, spatial feed rhythm | Space Grotesk | Luminous blue |
| **Prism** | Modüler bento & netlik | Bento | Drawer shell, bento grid, modular workspace hierarchy | Archivo | Violet workspace layers |
| **Dusk** | Sinematik karanlık & dramatik | Cinema | Transparent pass-through chrome, cinematic full-bleed rhythm | Space Grotesk | Amber on cinematic dark |
| **Flux** | Dinamik & uyarlanabilir | Adaptive | Route-aware shell FAB, compact Material tonal flow | Plus Jakarta Sans | Adaptive teal |

---

## Semantic Color Token Roles

All themes follow this token structure. Use tokens by role, not by name alone.

### Primary Colors

**`accent`** — Primary interactive elements and focus states.
- **Use for**: Filled buttons, active links, focus rings, selection highlights, active tab indicators, feature highlights
- **Never use for**: Background fills, disabled states, muted secondary content
- **Accessibility**: Test contrast against your canvas color (minimum 4.5:1 for text)

**`accentMuted`** — Secondary interactions and hover states.
- **Use for**: Outlined button backgrounds, hover states on secondary actions, disabled button backgrounds (when combined with reduced opacity), tag backgrounds, badge backgrounds
- **Never use for**: Primary call-to-action buttons, primary text
- **Example**: "Like" button changes from white to accentMuted on hover (not to accent, which would feel active)

### Semantic Functional Colors

**`success`** — Positive feedback and confirmations.
- **Use for**: Success messages, "approved" badges, checkmarks, positive state indicators
- **Contrast requirement**: 4.5:1 against canvas and panel
- **companion**: `successMuted` for light backgrounds behind success content (e.g., success toast background)

**`warning`** — Caution, pending actions, intermediate states.
- **Use for**: Warning icons, "in progress" badges, attention-needed indicators
- **Example**: Yellow/orange badge on an event that's been reported for moderation

**`info`** — Informational content, help text, neutral states.
- **Use for**: Info icons, help text, neutral badges, informational toasts
- **Companion**: `infoMuted` for light backgrounds (e.g., info panel background)

**`danger`** — Errors, destructive actions, critical alerts.
- **Use for**: Error messages, delete buttons, critical alerts, red warning icons
- **Contrast requirement**: 4.5:1 against canvas/panel
- **Companion**: `dangerMuted` for light error backgrounds (e.g., error toast, form validation error field background)

### Content & Hierarchy

**`foreground`** — Primary body text and main content.
- **Use for**: Paragraph text, list item text, card titles, primary labels
- **Contrast requirement**: Minimum 7:1 against canvas (WCAG AAA). Minimum 4.5:1 (WCAG AA)
- **Never use for**: Disabled state text (use foregroundMuted instead)

**`foregroundMuted`** — Secondary text, captions, hints.
- **Use for**: Metadata (timestamps, author names), helper text, captions, placeholder text, breadcrumbs, disabled button text
- **Contrast requirement**: Minimum 4.5:1 against canvas
- **Example**: "Posted 2 hours ago" in smaller, muted text under a post title

**`foregroundOnAccent`** — Text that sits on top of accent-colored backgrounds.
- **Use for**: Text inside filled buttons, text on accent backgrounds
- **Contrast requirement**: Minimum 4.5:1 against accent color
- **Example**: Button text inside a filled button with accent background

### Surfaces & Containers

**`canvas`** — Main background color for the entire screen.
- **Use for**: Screen background, list backgrounds, large container backgrounds
- **Fixed per theme**: Darkest in dark mode, lightest in light mode
- **Never change**: This is the app foundation; other colors are defined relative to it

**`canvasSubtle`** — Subtle background for grouped content.
- **Use for**: Background for sticky headers, footers, or grouped sections that need visual separation without becoming cards
- **Lighter than**: canvas
- **Example**: A light gray background for a "Filter By" section header

**`panel`** — Card and raised surface backgrounds.
- **Use for**: Card backgrounds, dialog backgrounds, modal backgrounds, chips, tags
- **Contrast**: Must be visually distinct from canvas (cards should "pop")
- **Companion**: `panelRaised` for elevated cards (e.g., selected card, floating action menus)

**`panelMuted`** — Subtle container backgrounds for inactive or secondary content.
- **Use for**: Inactive tab backgrounds, muted list items, disabled card backgrounds, secondary containers
- **Example**: An event card that's already passed shows with panelMuted background to de-emphasize it

**`panelBorder`** — Border color for card and panel edges.
- **Use for**: Thin (0.5–1.0px) borders on cards, dividers, input field borders
- **Note**: Some themes set panelBorderWidth to 0 (Ember). Follow the theme's panelBorderWidth value

### Chat & Social

**`chatOutgoing`** — Message bubbles sent by the current user.
- **Use for**: Outgoing chat message background (theme-specific background color)
- **Partner**: `foregroundOnAccent` for text color on top

**`chatIncoming`** — Message bubbles received from others.
- **Use for**: Incoming chat message background (usually same as panel)
- **Partner**: `foreground` for text color

### Media & Placeholders

**`imagePlaceholder`** — Background for loading image placeholders.
- **Use for**: Image loading state (skeleton or solid color), blurred image placeholders
- **Contrast**: Should be visually distinct from canvas so users know content is loading

**`imageError`** — Background for failed image placeholders.
- **Use for**: Image load failure state (show error icon + imageError background)
- **Distinguish from**: `imagePlaceholder` so users understand the difference (loading ≠ broken)

### Stories & Activity Feeds

**`storyActive`** — Color for active/unseen story rings.
- **Use for**: Story ring borders for unseen stories (e.g., WhatsApp-style story indicators)
- **Often equals**: accent color

**`storyInactive`** — Color for viewed/seen story rings.
- **Use for**: Story ring borders for already-viewed stories (more muted)

**`storyOverlay`** — Semi-transparent overlay on story backgrounds.
- **Use for**: Dark overlay on full-screen story images (improves text readability)
- **Format**: ARGB with alpha (e.g., 0xB30C1A26 = 70% opacity dark overlay)

### Admin & Experimental

**`adminExperiment`** — Reserved for A/B tests and feature flags.
- **Use for**: Admin-only UI elements, experimental feature indicators, debug panels
- **Visibility**: Never shown to regular users
- **Example**: A special badge visible only to admins for flagged/test content

---

## Shape Strategy by Theme

All themes use the same radius tokens (`cardRadius`, `buttonRadius`, `inputRadius`) to differentiate personality while maintaining consistency within each theme.

### Minimal & Editorial (Zinc)
- **Card Radius**: 6px
- **Button Radius**: 4px
- **Input Radius**: 6px
- **Intent**: Sharp, precise, high-contrast. Targets users who prioritize readability and professional appearance.
- **Affordance**: Tight angles signal "serious" and "minimal." Perfect for data-heavy UIs.
- **Border Width**: 0.8px (visible, helps define edge)

### Structured (Atlas)
- **Card Radius**: 10px
- **Button Radius**: 8px
- **Input Radius**: 10px
- **Intent**: Balanced, professional, structural. Default for most users who want both personality and clarity.
- **Affordance**: Subtle rounding softens precision without sacrificing professionalism.
- **Border Width**: 1.0px (crisp definition)

### Luxury & Premium (Ember)
- **Card Radius**: 16px
- **Button Radius**: 14px
- **Input Radius**: 14px
- **Intent**: Warm, sophisticated, elevated. Targets users who prefer premium, polished appearance.
- **Affordance**: Medium rounding + soft amber palette creates luxury feel.
- **Border Width**: 0.0px (no borders; elevation defines cards via shadow alone)

### Humanist & Organic (Mist)
- **Card Radius**: 24px
- **Button Radius**: 20px
- **Input Radius**: 20px
- **Intent**: Natural, approachable, humanist. Targets users seeking calm, organic feel.
- **Affordance**: Soft rounded corners + sage green palette create accessible, welcoming experience.
- **Border Width**: 0.6px (subtle definition)

### Energetic & Playful (Vibe)
- **Card Radius**: 28px
- **Button Radius**: 24px
- **Input Radius**: 24px
- **Intent**: Joyful, energetic, casual. Targets younger users or those seeking playful interaction.
- **Affordance**: Very round buttons feel forgiving and fun; violet palette is vibrant.
- **Border Width**: 0.5px (minimal, lets color shine)

### Warm & Community (Kor)
- **Card Radius**: 18px
- **Button Radius**: 16px
- **Input Radius**: 18px
- **Intent**: Warm, approachable, community-focused. Kor is the default micro-app experience and should feel crafted, not neutral.
- **Affordance**: Paper-like warm surfaces, clear composer action, and magazine pacing make the default theme feel like the SDAL home base.

---

## Spacing & Layout

- **Gutters**: 20px standard padding on cards and containers
- **Card spacing**: 12px between list items and card items
- **Density**: Material 3 default. Do not override.
- **Insets**: Use 16px for interior padding within cards; 12px for tight spacing

---

## Typography

- **Font Family**: Per-theme (see Themes table above)
- **Text Theme**: Flutter Material 3 text theme, applied via `applyFont()` in `sdal_app_theme.dart`
- **Hierarchy**:
  - **Display Large/Medium**: Rarely used; reserve for major headings (page title)
  - **Headline Large**: Section headings (e.g., "Upcoming Events")
  - **Title Large**: Card titles, modal titles
  - **Body Large**: Primary body text (rare; usually Body Medium)
  - **Body Medium**: Default paragraph text, list items
  - **Body Small**: Metadata, timestamps, captions, helper text
  - **Label Large**: Button text, chip labels
  - **Label Small**: Tags, badges, small labels

---

## Component Shapes & Tokens

- **SurfaceCard**: Uses `cardRadius`, elevated with `panel` background
- **FilledButton / FAB**: Uses `buttonRadius`, filled with `accent`
- **OutlinedButton**: Uses `buttonRadius`, outlined with `panelBorder`
- **TextButton**: No radius override
- **TextField / InputField**: Uses `inputRadius`, bordered with `panelBorder`
- **Chip**: Uses `cardRadius` (slightly softer than buttons)
- **Dialog / Modal**: Uses `cardRadius`, `panel` background

---

## Accessibility Requirements

### Contrast Minimums
- **Normal text** (body, labels): WCAG AA 4.5:1, WCAG AAA 7:1
- **Large text** (18pt+): WCAG AA 3:1, WCAG AAA 4.5:1
- **UI components** (buttons, borders): WCAG AA 3:1

### Per-Theme Notes
- **Zinc**: Highest contrast (dark #0E1014 on light #ECF0F6). Excellent for low-vision users.
- **Mist**: Sage tones may be lower contrast. Verify `foreground` on `canvas` meets 4.5:1 (see Step 2 audit).
- **Vibe**: Violet + purple can fail contrast. Verify in UI before shipping.

### watchOS Color
Each theme maps to a watchOS accent color via `watchAccent` property. This color applies to `.tint()` on watchOS UI elements (buttons, icons, progress rings). Verify contrast on watch screen before finalizing.

---

## Migration Notes

### From Kor-Only to Multi-Theme
- Existing hardcoded colors (e.g., `#B45637`) should migrate to theme tokens
- Use `Theme.of(context).extension<SdalThemeTokens>()` to access tokens
- Never hardcode color values in widgets; always use token lookups
