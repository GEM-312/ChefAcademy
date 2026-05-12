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

### High-Energy CTA Accents (added May 11)
For selective use on age-6+ visibility moments. Use sparingly — the sage / goldenWheat / terracotta tints remain the botanical default.

| Name | Hex | SwiftUI | Use For |
|------|-----|---------|---------|
| Bright Green | `#4CAF50` | `Color.AppTheme.brightGreen` | High-energy "go" / success CTAs |
| Bright Blue | `#2196F3` | `Color.AppTheme.brightBlue` | Informational / secondary CTA |
| Sunflower Yellow | `#FFD600` | `Color.AppTheme.sunflowerYellow` | Reward / celebration accents |

### Specialty Surface Colors
| Name | Hex | SwiftUI | Use For |
|------|-----|---------|---------|
| Pure White | `#F7FAFC` | `Color.AppTheme.pureWhite` | Chef hat white, snow particles, lightning flash |
| Overlay | `Color.black @ 0.4` | `Color.AppTheme.overlay` | Modal dim behind dialogs |

### Weather Icon Tints (May 11 — botanical-aligned, less saturated than Material)
| Name | Hex | SwiftUI | Use For |
|------|-----|---------|---------|
| Sun Yellow | `#FFD54F` | `Color.AppTheme.sunYellow` | Sunny icon + sunshine overlay |
| Weather Partly Cloudy | `#E08A3C` | `Color.AppTheme.weatherPartlyCloudy` | Partly cloudy icon, sun glow tint |
| Weather Cloudy | `#8E9AAB` | `Color.AppTheme.weatherCloudy` | Cloudy icon + cloud overlays |
| Rain Blue | `#4FC3F7` | `Color.AppTheme.rainBlue` | Rainy icon + rain/storm drops |
| Weather Stormy | `#7A6BA0` | `Color.AppTheme.weatherStormy` | Stormy icon |
| Weather Snowy | `#9CC5D8` | `Color.AppTheme.weatherSnowy` | Snowy icon + snow background tint |

### Seasonal Gradient Stops (May 11)
Each season's `gradientColors` array assembles a top→bottom subtle wash. Winter top reuses `frostBlue`. Fall bottom reuses `summerGradientTop` (same hex).

| Name | Hex | Used For |
|------|-----|----------|
| `springGradientTop` | `#E8F5E9` | Spring top — soft green |
| `springGradientBlossom` | `#FCE4EC` | Spring mid — cherry blossom |
| `summerGradientTop` | `#FFF8E1` | Summer top + fall bottom — warm gold |
| `summerGradientWarm` | `#FFF3E0` | Summer mid — light amber |
| `fallGradientTop` | `#FBE9E7` | Fall top — warm orange tint |
| `fallGradientMid` | `#EFEBE9` | Fall mid — light brown |
| `frostBlue` | `#E3F2FD` | Winter top + sparkle particles |
| `winterGradientMid` | `#F3E5F5` | Winter mid — frosty lavender |
| `winterGradientBot` | `#ECEFF1` | Winter bottom — cold grey |
| `autumnBrown` | `#8B4513` | Fall leaf particles |
| `springPetal` | `#F48FB1` | Spring petal particles |

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
| `.pink` | `Color.AppTheme.springPetal` (particles) or `.terracotta.opacity(0.6)` (other) |
| `.cyan` | `Color.AppTheme.sage` |
| `.white` | `Color.AppTheme.cream` or `.warmCream` |
| `.black` | `Color.AppTheme.darkBrown` |

### Exceptions (OK to use raw colors)
- **WeatherOverlayView** — weather effects intentionally use raw colors for realism (rain = blue, snow = white, sun = yellow)
- **SceneEditor** — dev-only debug tool, not user-facing
- **Body Buddy organ icons** — organ-specific colors (heart = red, brain = purple) are educational, not decorative

---

## Current Violations

**Live source of truth:** see the latest `WEEKLY_REVIEW_<date>.md` at repo root for the current Sun/Tue auto-audit. Don't trust a hand-maintained "all clear" claim here — it goes stale fast.

Exempt categories (raw colors intentionally permitted):
- **SceneEditor** — dev-only debug tool, not user-facing
- **SeedInfoView `ColorChoice`** — educational (PencilKit color → pigment-science mapping; in-file teaching comment defends this)
- **BodyBuddyView / CookingCompletionView organ icons** — organ-specific educational colors (heart = red, brain = purple)
- **Shadows** must use `Color.AppTheme.sepia.opacity(N)`, never `.black.opacity(N)` (project convention)
- **Weather overlays** — migrated May 11 to use weather tokens (`weatherSunny`, `rainBlue`, etc.). No more raw `.yellow / .blue / .gray`.

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
| Textured (PRIMARY) | `.texturedButton(tint: Color.AppTheme.sage)` | Main CTAs — wood-grain capsule, signature look |
| Primary | `.primaryButton()` | Legacy (dead code — used only in own preview); prefer Textured |
| Secondary | `.secondaryButton()` | Alternative action (parchment bg, bordered) |
| Bouncy | `.buttonStyle(BouncyButtonStyle())` | Game CTAs, interactive elements (0.9 scale on press) |
| Plot | `.buttonStyle(PlotButtonStyle())` | DEPRECATED — exact duplicate of BouncyButtonStyle; planned deletion. Use BouncyButtonStyle. |
| Plain | `.buttonStyle(.plain)` | NEVER on a primary CTA; only on full-card buttons where the label IS the visual |

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

- All veggie images: botanical watercolor style, transparent PNG background. 8 of 27 drawn so far; 19 still pending (see `MEMORY.md` Plants section).
- Opacity for backgrounds: `0.8` (farm/garden bg images)
- Seed bag images: no saturation/color modification on unowned seeds
- Avatar frame sets in `Assets.xcassets/AvatarCards/`:
  - `boy_card_frame_01..28` / `girl_card_frame_01..15` — child avatar animation
  - `mom_avatar_frame_01..15` / `dad_avatar_frame_01..15` — parent avatar (May 11)
  - `boy_pours_water_frame_01..15` / `girl_pours_water_frame_01..15` — watering animation (May 11)
  - Plus separate `boy_card_clean_*` / `girl_card_clean_*` "profile pose" sets at the catalog root
- Pip character size: always via `PipSize` enum (`.compact 40 / .medium 80 / .large 120 / .hero 160 / .custom(N)`). Use `PipWavingAnimatedView(size:)` or `PipSpeechBubble` / `PipHeaderStack` (both auto-speak via `PipVoice`).
- Pipeline for new sprite assets: run `bash extract-and-trim.sh <video> [num_frames]` (auto rembg + alpha-thresholded crop). Replaces the manual Photoshop trip — see commit `7b0f8ee`.

---

*Last Updated: May 12, 2026 — palette includes May 11 high-energy accents + weather + season tokens. Authoritative violation tracking lives in `WEEKLY_REVIEW_<date>.md`.*
