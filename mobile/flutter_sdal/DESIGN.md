---
name: SDAL Sosyal Flutter
description: Warm, trusted, lively mobile UI for the private SDAL community.
colors:
  canvas-warm-cream: "#F7F2E9"
  canvas-soft-clay: "#EDE2D3"
  panel-porcelain: "#FFFCF7"
  panel-raised-oat: "#FAF4EB"
  panel-muted-linen: "#EFE5D8"
  panel-border-clay: "#D3C1AF"
  primary-persimmon: "#B45637"
  primary-persimmon-muted: "#F3D8CA"
  success-pine: "#2A6A4C"
  success-mist: "#DDEFE6"
  warning-ochre: "#8A5D16"
  warning-mist: "#F2E3C4"
  info-mineral-blue: "#2F6078"
  info-mist: "#DCECF0"
  danger-brick: "#A44635"
  danger-mist: "#F4DDD8"
  chat-mineral-slate: "#315565"
  foreground-espresso: "#261B14"
  foreground-soft-brown: "#66594C"
  foreground-on-accent: "#FFFAF4"
  admin-violet: "#7055A6"
  dark-canvas: "#17120F"
  dark-panel: "#29211C"
  dark-primary-persimmon: "#E99A73"
typography:
  headline:
    fontFamily: "Manrope"
    fontWeight: 800
    letterSpacing: "-0.4px to -0.8px"
  title:
    fontFamily: "Manrope"
    fontWeight: 700
  body:
    fontFamily: "Manrope"
    fontWeight: 400
  label:
    fontFamily: "Manrope"
    fontWeight: 600
rounded:
  xs: "12px"
  sm: "14px"
  md: "16px"
  lg: "18px"
  xl: "20px"
  2xl: "24px"
  pill: "999px"
spacing:
  xs: "6px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "18px"
  2xl: "20px"
  3xl: "24px"
  screen-x: "20px"
components:
  button-primary:
    backgroundColor: "{colors.primary-persimmon}"
    textColor: "{colors.foreground-on-accent}"
    rounded: "{rounded.lg}"
    padding: "16px 18px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.foreground-espresso}"
    rounded: "{rounded.lg}"
    padding: "16px 18px"
  surface-card:
    backgroundColor: "{colors.panel-porcelain}"
    textColor: "{colors.foreground-espresso}"
    rounded: "{rounded.2xl}"
    padding: "18px"
  input-field:
    backgroundColor: "{colors.panel-porcelain}"
    textColor: "{colors.foreground-espresso}"
    rounded: "{rounded.xl}"
    padding: "16px 18px"
  chip:
    backgroundColor: "{colors.panel-muted-linen}"
    textColor: "{colors.foreground-espresso}"
    rounded: "{rounded.pill}"
  bottom-navigation:
    backgroundColor: "{colors.panel-porcelain}"
    textColor: "{colors.foreground-soft-brown}"
---

# Design System: SDAL Sosyal Flutter

## 1. Overview

**Creative North Star: "The Community Hearth"**

SDAL Sosyal is a private community product, not a public social network. The interface should feel like a warm, trusted meeting place for the SDAL community: familiar enough to move quickly, specific enough that it never reads as a generic school portal. The current Flutter app expresses this through warm cream surfaces, a controlled persimmon accent, Manrope typography, clear semantic states, and flat Material 3 components.

The system is product-first. It privileges task clarity, quick scanning, Turkish-first copy, and predictable mobile patterns. Liveliness comes from fresh content, status badges, warm tonal surfaces, mineral secondary colors, and small moments like logo marks or state strips; it must not come from performative social-media chrome.

**Key Characteristics:**
- Warm cream canvas with persimmon accent used for primary actions and selection.
- Flat-by-default surfaces with border and tonal layering instead of heavy shadow.
- Manrope-only typography with strong weight contrast for headings and labels.
- Large, friendly radii that still feel controlled and task-oriented.
- Semantic color vocabulary for success, warning, info, danger, admin, chat, and media states.

## 2. Colors

The palette is restrained and warmer-than-neutral, with a clearer mineral counterweight. It should feel SDAL-specific, tactile, and human without becoming nostalgic beige or generic education software.

### Primary
- **Primary Persimmon** (`primary-persimmon`): the main action and selection color. Use for FilledButton, floating action buttons, progress indicators, active story rings, and the rare emphasized state.
- **Muted Persimmon Wash** (`primary-persimmon-muted`): selected navigation indicators, soft recommendation strips, onboarding accents, and low-pressure highlights.

### Secondary
- **Mineral Blue Info** (`info-mineral-blue`): informational states, verification prompts, and secondary context that should feel credible rather than urgent.
- **Mineral Chat Slate** (`chat-mineral-slate`): outgoing chat bubbles and conversation-specific contrast.
- **Admin Violet** (`admin-violet`): admin experiment or privileged-operation signals. Keep it isolated from normal member workflows.

### Tertiary
- **Pine Success** (`success-pine`): positive completion, online presence, availability, and safe confirmations.
- **Ochre Warning** (`warning-ochre`): profile completion, required-but-not-dangerous notices, and claims that need user attention.
- **Brick Danger** (`danger-brick`): destructive, failed, banned, unavailable, or error states.

### Neutral
- **Warm Cream Canvas** (`canvas-warm-cream`): default app background.
- **Soft Clay Canvas** (`canvas-soft-clay`): gradient and immersive background layer.
- **Porcelain Panel** (`panel-porcelain`): cards, inputs, bottom navigation, and content containers.
- **Raised Oat Panel** (`panel-raised-oat`): snackbars, splash gradient middle layer, and slightly lifted surfaces.
- **Muted Linen Panel** (`panel-muted-linen`): utility backgrounds, chip backgrounds, empty-state icons, and progress tracks.
- **Clay Border** (`panel-border-clay`): 1px structure line for cards, fields, dividers, segmented buttons, chips, and outlined buttons.
- **Espresso Foreground** (`foreground-espresso`): primary text.
- **Soft Brown Foreground** (`foreground-soft-brown`): secondary text, labels, helper copy, inactive navigation, and placeholders.

### Named Rules

**The Persimmon Is Rare Rule.** Primary Persimmon must mark action, selection, or state. Do not use it as decorative filler.

**The Semantic Pair Rule.** Success, warning, info, and danger must travel as foreground plus muted background pairs. Never rely on hue alone.

**The Warm Plus Mineral Rule.** New neutral surfaces must stay in the warm cream, oat, linen, clay family, while secondary states may use the mineral blue-green lane. Do not introduce pure white, pure black, cold gray, or generic blue-gray app chrome.

## 3. Typography

**Display Font:** Manrope
**Body Font:** Manrope
**Label/Mono Font:** Manrope

**Character:** Manrope gives the app a modern humanist voice: legible, warm, and capable of dense product screens. The system uses one family across headings, labels, body, buttons, and data to keep the mobile UI cohesive.

### Hierarchy
- **Headline** (800, Material headlineMedium/headlineSmall, negative letter spacing): page-level moments, status screens, splash, onboarding titles, and high-emphasis empty states.
- **Title** (700, Material titleLarge/titleMedium): card headings, section labels, menu titles, profile names, and repeated module headers.
- **Body** (400, Material bodyLarge/bodyMedium): feed content, form helper text, banners, menu subtitles, legal guidance, and default reading text. Keep prose compact and under roughly 65-75 characters per line when constrained.
- **Small Body** (400, Material bodySmall): metadata, secondary explanations, timestamps, and muted labels.
- **Label** (600, Material labelLarge): buttons, navigation labels, chips, and compact action text.

### Named Rules

**The One Family Rule.** Use Manrope everywhere. Do not introduce display fonts, script fonts, mono-forward UI, or decorative type in product surfaces.

**The Weight Before Ornament Rule.** Create hierarchy with weight, size, spacing, and placement. Do not use gradient text, novelty casing, or decorative letter spacing.

## 4. Elevation

The Flutter app is flat by default. Depth is created through warm tonal layers, 1px borders, clipped cards, bottom sheets, and Material state feedback rather than visible drop shadows. Cards use zero elevation and a Clay Border; app bars are transparent with no scrolled-under elevation.

### Shadow Vocabulary
- **None at rest:** cards, app bars, inputs, navigation, chips, and scaffold surfaces should not cast shadows in the default state.
- **Material overlay only:** use platform Material ink, focus, bottom-sheet drag handles, and modal sheet behavior for interaction feedback rather than custom shadow recipes.

### Named Rules

**The Tonal Depth Rule.** Reach first for `panel`, `panelRaised`, `panelMuted`, and `panelBorder`. Shadows are not the default depth language.

**The No Floating Stack Rule.** Do not stack cards inside cards to create hierarchy. Use sections, list tiles, dividers, surface tone, or spacing.

## 5. Components

### Buttons
- **Shape:** gently rounded rectangles (`18px` radius), with `20px` radius for floating action buttons.
- **Primary:** Primary Persimmon background with Foreground On Accent text, `18px` horizontal and `16px` vertical padding.
- **Secondary / Outlined:** transparent background, Espresso text, Clay Border stroke, same `18px` radius and padding.
- **Text:** Primary Persimmon text only. Use for inline low-emphasis actions such as legal links or banner actions.
- **Loading:** compact spinner inside the button when an operation is in progress. Do not shift layout width dramatically.

### Chips
- **Style:** Muted Linen background, Clay Border stroke, Espresso text, pill radius.
- **State:** selected chips use Muted Persimmon Wash. Inactive chips must not use saturated color.

### Cards / Containers
- **Corner Style:** large friendly corners (`24px` radius) for Card and SurfaceCard.
- **Background:** Porcelain Panel by default, Raised Oat for snackbars or slightly lifted feedback, Muted Linen for utility zones.
- **Shadow Strategy:** zero elevation. Use border, tone, and clipping.
- **Border:** Clay Border at 1px.
- **Internal Padding:** SurfaceCard defaults to `18px`; status cards often use `24px`; screen padding commonly starts at `20px`.

### Inputs / Fields
- **Style:** filled Porcelain Panel, Clay Border, `20px` radius, `18px` horizontal and `16px` vertical padding.
- **Focus:** Primary Persimmon border at `1.5px`.
- **Labels and Helpers:** Soft Brown foreground. Error text uses Brick Danger.
- **Disabled:** preserve shape and filled surface; lower emphasis through Material disabled treatment, not custom gray blocks.

### Navigation
- **Bottom Navigation:** Porcelain Panel at high opacity, Muted Persimmon Wash selected indicator, selected label weight `700`, inactive label weight `600` in Soft Brown.
- **App Bar:** transparent background, no elevation, centered logo/title treatment, profile avatar leading action, quick menu icon action when available.
- **Quick Menu Sheet:** draggable bottom sheet with grouped Card sections, ListTile rows, icons, dividers, and selected row highlight using translucent Muted Persimmon Wash.
- **Badges:** pill red badge with live semantic label, max label `99+`, `18px` minimum size.

### Status, Empty, and Error States
- **Empty State:** circular Muted Linen icon well (`44px` compact, `56px` regular), muted icon, centered title and body, optional tonal action.
- **Error State:** circular Danger Mist icon well with Brick Danger icon, friendly localized copy, optional retry FilledButton.
- **Banners:** full-width colored strips using semantic muted backgrounds and matching icons. Keep copy direct and action-oriented.

### Signature Component: SDAL Logo Badge

The SDAL logo badge is the app's compact identity anchor. Use it in splash, app bar title states, and root navigation affordances. Keep it small and purposeful inside product surfaces; it should identify the app, not behave like a marketing hero.

## 6. Do's and Don'ts

### Do:
- **Do** use `canvas-warm-cream`, `panel-porcelain`, and `panel-muted-linen` as the default surface vocabulary.
- **Do** reserve `primary-persimmon` for primary actions, current selection, progress, and high-value state.
- **Do** pair status colors with icons, labels, or structure so color is never the only signal.
- **Do** keep buttons, fields, chips, and cards visually consistent across modules.
- **Do** use standard Flutter and Material affordances for fields, lists, bottom sheets, tabs, navigation, loading, and retry states.
- **Do** keep Turkish-first copy concise, concrete, and calm.
- **Do** use skeletons, empty states, and friendly errors instead of raw exceptions or blank screens.

### Don't:
- **Don't** make the app feel like a generic school portal.
- **Don't** make it a corporate LinkedIn clone.
- **Don't** make it a childish social app.
- **Don't** make it a heavy admin panel.
- **Don't** make it a Facebook-like feed.
- **Don't** make it an Instagram-like media app.
- **Don't** use gradient text, decorative glassmorphism, side-stripe card borders, or hero-metric templates.
- **Don't** introduce pure black, pure white, cold gray, neon accents, or default blue Material theming.
- **Don't** use heavy shadows to imply depth. Use tone and borders.
- **Don't** turn every screen into identical icon-heading-text card grids.
