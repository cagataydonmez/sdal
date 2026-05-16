# Theme Consistency Audit

## Current Shape Strategy (from sdal_app_theme.dart)

| Theme | Card Radius | Button Radius | Border Width | Visual Intent |
|-------|-------------|---------------|--------------|---------------|
| **Kor** | Default | Default | Default | Warm, approachable (Material 3 baseline) |
| **Atlas** | 10px | 8px | 1.0px | Sharp, structural (crisp edges) |
| **Vibe** | 28px | 24px | 0.5px | Energetic, playful (very round) |
| **Zinc** | 6px | 4px | 0.8px | Minimal, editorial (tight angles) |
| **Ember** | 16px | 14px | 0.0px | Luxury, premium (elevation only) |
| **Mist** | 24px | 20px | 0.6px | Organic, humanist (soft rounded) |

## Analysis

### Radius Spread: 6x difference (4px to 28px)
- **Pro**: Each theme has distinctive personality
- **Con**: Large variation creates jarring switching experience
  - If user tries Zinc (4px sharp) then Vibe (28px round), buttons feel completely different
  - May cause affordance confusion ("Is this button active/tappable?")
  - Each theme feels like a different app

### Recommendation: Cluster into 3 Radius Tiers

Keep the 6 themes distinct, but group radii into semantic tiers so switching between themes in the same tier feels cohesive:

**TIER 1: Minimal & Precise** (for users who prioritize readability)
- **Zinc**: 4–6px (editorial, high-contrast)
- **Atlas**: 8–10px (professional, structured)
- **Kor**: Material 3 default (~12px) (warm, community-focused)
- Cohesion: All <= 12px. Switching within this tier = consistent visual grammar.

**TIER 2: Balanced** (default for most users)
- (No current themes fall here — gap opportunity)
- Candidates: 12–16px range

**TIER 3: Soft & Approachable** (for users seeking humanist/premium feel)
- **Ember**: 14–16px (luxury)
- **Mist**: 20–24px (organic)
- **Vibe**: 24–28px (energetic)
- Cohesion: All >= 14px. Softer feel, forgiving interaction.

### Action Items

**Option A: Keep current (status quo)**
- Pro: Themes are already shipped and users are happy
- Con: Unintuitive grouping; no guidance for designers
- Decision: Document the current spread and provide warnings

**Option B: Realign into tiers (breaking change)**
- Adjust radii to cluster:
  - Tier 1: 4px (Zinc), 8px (Atlas), 12px (Kor)
  - Tier 2: 14px (Ember)
  - Tier 3: 20px (Mist), 24px (Vibe)
- Pro: Cleaner semantic grouping; less jarring theme switching
- Con: Requires design review and testing; may alter personality

### Border Width Strategy

**Current state:**
- Atlas: 1.0px (crisp, clearly visible)
- Zinc: 0.8px (visible, professional)
- Mist: 0.6px (subtle, soft)
- Vibe: 0.5px (minimal, lets color show)
- Ember: 0.0px (borderless, elevation-only)
- Kor: Default (assumed ~1.0px)

**Intent**: Border presence signals affordance. Variation is intentional per theme personality.

**Concern**: Some platforms (old phones, small screens) may struggle to render sub-1px borders.

**Recommendation**:
1. Validate on actual devices (iPhone 11, older Android tablets)
2. If sub-1px borders disappear, increase to 0.75px or 1.0px minimum
3. Document: "Borders define card tappability. If a border is invisible, use elevation/shadow as fallback."

---

## Summary Table

| Issue | Status | Action |
|-------|--------|--------|
| Accent color contrast (light modes) | ⚠️ Borderline | Do not use light-mode accent for normal body text. Use for icons, buttons, large headings only. |
| Border rendering (sub-1px) | 🔍 Unknown | Test on older devices. Increase to 0.75px if invisible. |
| Radius clustering | ✅ Optional | Current spread (4–28px) is intentional. No action required. Document for designers. |
| watchOS theme sync | 🐛 **FIXED** | Bug fixed: WatchBridge now validates all 6 themes (was only validating 3). |
| Semantic color token roles | ✅ Documented | DESIGN.md enhanced with usage rules for all tokens. |

---

## Designer Guidance (for DESIGN.md)

Add to DESIGN.md:

### When to Choose Each Theme

- **Minimal & Precise Tier** (Zinc, Atlas, Kor)
  - Use for: Data-heavy UIs, professional/corporate contexts, high-contrast accessibility needs
  - Default for: Power users, analytics users, users with vision impairment
  - Switching within tier: Feels consistent

- **Soft & Approachable Tier** (Mist, Vibe, Ember)
  - Use for: Community contexts, casual engagement, premium branding
  - Default for: General users, first-time users, users seeking warmth
  - Switching within tier: Feels consistent

### Theme Switching Expectations

Users switching from one tier to another should expect:
1. Accent color change (branding shift)
2. Border presence change (affordance shift)
3. Radius change (personality shift)

This is **intentional**. Each theme is its own visual system, not a reskin of the same system.
