# STYLES.md — Visual Consistency Guide

All colors, fonts, spacing, and component styles for Pip's Kitchen Garden.
Every view MUST use these — no raw `.red`, `.blue`, or hardcoded hex values.

---

## Color Palette (AppTheme.swift)

### Backgrounds
| Name | Hex | SwiftUI | Use For |
|------|-----|---------|---------|
| Cream | `#F5F0E1` | `Color.AppTheme.cream` | Screen backgrounds |
| Warm Cream | `#FAF6EB` | `Color.AppTheme.warmCream` | Cards, elevated surfaces |
| Parchment | `#EDE6D3` | `Color.AppTheme.parchment` | Card fills, progress bar backgrounds |

### Text
| Name | Hex | SwiftUI | Use For |
|------|-----|---------|---------|
| Dark Brown | `#5D4E37` | `Color.AppTheme.darkBrown` | Headlines, titles, emphasis |
| Sepia | `#8B7355` | `Color.AppTheme.sepia` | Body text, descriptions |
| Light Sepia | `#A89880` | `Color.AppTheme.lightSepia` | Secondary text, captions, metadata |

### Accents
| Name | Hex | SwiftUI | Use For |
|------|-----|---------|---------|
| Sage | `#6B7B5E` | `Color.AppTheme.sage` | Nature accents, success states, primary buttons, garden elements |
| Golden Wheat | `#C9A227` | `Color.AppTheme.goldenWheat` | Coins, rewards, highlights, CTAs, star ratings |
| Soft Olive | `#8A9A7B` | `Color.AppTheme.softOlive` | Secondary accents, easy level badge |
| Terracotta | `#B87333` | `Color.AppTheme.terracotta` | Warnings, heat, hard level badge |
| Warm Khaki | `#C6BA8B` | `Color.AppTheme.warmKhaki` | Warm accent, avatar style elements |

### Functional
| Name | SwiftUI | Use For |
|------|---------|---------|
| Easy Level | `Color.AppTheme.easyLevel` | Easy recipe badge (same as softOlive) |
| Medium Level | `Color.AppTheme.mediumLevel` | Medium recipe badge (same as goldenWheat) |
| Hard Level | `Color.AppTheme.hardLevel` | Hard recipe badge (same as terracotta) |

---

## BANNED: Raw System Colors

These system colors break the botanical watercolor aesthetic. **NEVER** use them directly:

| Banned | Replace With |
|--------|-------------|
| `.red` | `Color.AppTheme.terracotta` (warnings) or `.terracotta.opacity(0.7)` (errors) |
| `.blue` | `Color.AppTheme.sage` (actions) or `.sepia` (informational) |
| `.green` | `Color.AppTheme.sage` |
| `.orange` | `Color.AppTheme.goldenWheat` or `.terracotta` |
| `.purple` | `Color.AppTheme.sepia` or `.darkBrown` |
| `.yellow` | `Color.AppTheme.goldenWheat` |
| `.gray` | `Color.AppTheme.lightSepia` |
| `.pink` | `Color.AppTheme.terracotta.opacity(0.6)` |
| `.cyan` | `Color.AppTheme.sage` |
| `.white` | `Color.AppTheme.cream` or `.warmCream` |
| `.black` | `Color.AppTheme.darkBrown` |

### Exceptions (OK to use raw colors)
- **WeatherOverlayView** — weather effects intentionally use raw colors for realism (rain = blue, snow = white, sun = yellow)
- **SceneEditor** — dev-only debug tool, not user-facing
- **Body Buddy organ icons** — organ-specific colors (heart = red, brain = purple) are educational, not decorative

---

## Current Violations

**All clear!** Last audit: March 23, 2026.

Remaining raw system colors are all in exempt categories:
- WeatherOverlayView — weather visual effects (rain=blue, snow=white, sun=yellow)
- SceneEditor — dev-only debug tool
- SeedInfoView ColorChoice — educational (PencilKit color-to-nutrient mapping)
- BodyBuddyView / CookingCompletionView — organ-specific educational colors
- GardenWeatherService badge — weather indicator colors
- `.shadow(color: .black.opacity(...))` — shadows require real black
- DEBUG edit-mode pencil buttons (`.red` indicator)

---

## Typography (Font.AppTheme)

| Name | Size | Weight | Use For |
|------|------|--------|---------|
| `.largeTitle` | 34 | Bold | Screen titles, welcome messages |
| `.title` | 28 | Semibold | Section headers, recipe names |
| `.title2` | 22 | Semibold | Sub-headers |
| `.title3` | 20 | Medium | Card titles, dialog headers |
| `.headline` | 17 | Semibold | Button text, emphasis |
| `.body` | 17 | Regular | Body text, descriptions |
| `.bodyBold` | 17 | Semibold | Bold body text |
| `.callout` | 16 | Regular | Callout text |
| `.subheadline` | 15 | Regular | Smaller text |
| `.footnote` | 13 | Regular | Metadata, timestamps |
| `.caption` | 12 | Regular | Labels, badges |
| `.recipeStep` | 18 | Medium | Cooking step instructions |
| `.ingredientItem` | 16 | Regular | Ingredient lists |
| `.timerDisplay` | 48 | Light | Timer countdown |

### BANNED: Inline Font Definitions
Do NOT use `.font(.system(size: 14))` inline. Add a named style to `Font.AppTheme` if none fits.

Exception: One-off sizes in components like SeedBadge, PlotView where the size is layout-critical and unique to that view.

---

## Spacing (AppSpacing)

| Name | Value | Use For |
|------|-------|---------|
| `.xxs` | 4pt | Tiny gaps (icon-to-text in badges) |
| `.xs` | 8pt | Small gaps (between related items) |
| `.sm` | 12pt | Standard gaps (button padding, list spacing) |
| `.md` | 16pt | Medium gaps (card padding, section spacing) |
| `.lg` | 24pt | Large gaps (between sections) |
| `.xl` | 32pt | Extra large (screen-level spacing) |
| `.xxl` | 48pt | Maximum spacing (hero sections) |

### Key Constants
| Name | Value | Use For |
|------|-------|---------|
| `.minTapTarget` | 44pt | Minimum touch target (accessibility) |
| `.buttonHeight` | 52pt | Standard button height |
| `.cardCornerRadius` | 16pt | All card corners |
| `.iconSize` | 24pt | Standard icon size |
| `.largeIconSize` | 48pt | Large icon size |

---

## Component Styles

### Buttons
| Style | SwiftUI | Use For |
|-------|---------|---------|
| Primary | `.buttonStyle(PrimaryButtonStyle())` | Main CTA (golden wheat bg, cream text) |
| Secondary | `.buttonStyle(SecondaryButtonStyle())` | Alternative action (parchment bg, bordered) |
| Bouncy | `.buttonStyle(BouncyButtonStyle())` | Interactive elements (scale on press) |
| Plot | `.buttonStyle(PlotButtonStyle())` | Garden plot buttons (spring bounce) |
| Plain | `.buttonStyle(.plain)` | Custom-styled buttons (cards, chips) |

### Cards
- Use `.cardStyle()` modifier for standard cards
- Or manually: `.padding(AppSpacing.md)` + `.background(Color.AppTheme.warmCream)` + `.cornerRadius(AppSpacing.cardCornerRadius)`

### Shadows
- Cards: `.shadow(color: Color.AppTheme.sepia.opacity(0.08-0.1), radius: 4-8, y: 2-4)`
- Never use `.shadow(radius: X)` without specifying color (defaults to harsh black)

---

## Animation Standards

**Full animation rules: See [`ANIMATIONS.md`](ANIMATIONS.md)**

Quick reference — use `AnimationConstants` from AppTheme.swift:

| Constant | Use For |
|----------|---------|
| `.springQuick` | Buttons, bounces |
| `.springMedium` | Cards, dialogs |
| `.springSlow` | Large elements, reveals |
| `.morphTransition` | Card-to-detail morph |
| `.routeTransition` | Tab/route changes |
| `.fadeQuick` | Button press feedback |

Haptics: Use shared `Haptic` enum (AppTheme.swift), never raw UIKit generators.

---

## Image & Asset Rules

- All veggie images: botanical watercolor style, transparent PNG background
- Opacity for backgrounds: `0.8` (farm/garden bg images)
- Seed bag images: no saturation/color modification on unowned seeds
- Avatar frames: boy_card_frame_01-28, girl_card_frame_01-15
- Pip character: always use `PipWavingAnimatedView(size:)` component

---

*Last Updated: April 13, 2026*
