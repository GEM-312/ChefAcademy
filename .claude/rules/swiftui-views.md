---
paths:
  - "**/*View.swift"
  - "**/MeetPipViews.swift"
---

# SwiftUI View conventions (extracted from CLAUDE.md §3 + §4)

This loads whenever you edit any view file. It uses a **by-type glob** (`**/*View.swift`) for the 44 files that follow the `…View.swift` convention, plus one **explicit entry** (`**/MeetPipViews.swift`) for the plural-named exception that holds several view structs. Both feed this same rule; a file matching either path loads it. This targets files by role wherever they sit, and skips non-View files like `AppTheme.swift` (which defines the tokens and is exempt). The explicit entry is deliberately used instead of widening to `**/*View*.swift`, which would also sweep in unrelated `*ViewModel*` / `*ViewHelper*` files.

## No hardcoded values (§3)

Zero hardcoded colors / fonts / spacing / animation curves / stroke widths in any new SwiftUI code. Period.

| Category | Token namespace | Examples |
|---|---|---|
| **Colors** | `Color.AppTheme.*` | `cream`, `sage`, `goldenWheat`, `terracotta`, `sepia`, `darkBrown`, `weatherSunny`, `springGradientTop`. Shadows: `Color.AppTheme.sepia.opacity(N)` — never `Color.black.opacity(N)`. |
| **Fonts** | `Font.AppTheme.*` | `caption / subheadline / body / bodyBold / headline / title3 / title / largeTitle`. One-offs: `Font.AppTheme.rounded(size: N, weight: .X)`. Never `.font(.system(size:))`. |
| **Spacing** | `AppSpacing.*` | `xxs (4) / xs (8) / sm (12) / md (16) / lg (24) / xl (32) / xxl (48)`, `buttonHeight (52)`, corner radii `pill (8) / small (12) / card (16) / large (20)`, strokes `thin (1) / medium (2) / bold (3)`, `tabBarClearance (100)`, `pinButtonWidth (75)`, `pinButtonHeight (55)`, `infoCardImageSize (200)`. |
| **iPad sizing** | `AdaptiveCardSize.*(for: sizeClass)` | `pipMessage`, `pipReadyScreen`, `kitchenSpotRing`, etc. Never inline `isIPad ? 280 : 200`. |
| **Animations** | `AnimationConstants.*` | Springs: `springQuick / Medium / Slow / Bouncy / Snappy / Tight / Fly`. Easings: `fadeQuick / Fast / Medium / revealSlow / pipTransition / morphTransition / weatherTransition`. Loops: `floatLoopFast / floatLoop / floatLoopSlow / pinShake`. Frame rates: `walkingFPS / wavingFPS / gameFPS / walkSpeed`. Never inline `.spring(response:)` or `.easeInOut(duration:)`. |

**Pre-commit enforcement:** the `design-guard.py` hook (`.claude/hooks/`) auto-blocks `git commit` when the staged diff's added lines contain hardcoded values (`Color.black/white`, `Color(hex:`, `.system(size:`, inline spring/easing, numeric corner radius, `DispatchQueue.main.asyncAfter`) in non-AppTheme files. Still audit your own diff — the hook only catches unambiguous literals, not wrong-token misuse. Any hit in non-AppTheme files = not done. If a needed token doesn't exist, **add it to `AppTheme.swift` / `AppSpacing` / `AnimationConstants` / `AdaptiveLayout`** with a comment explaining what it's for. Never inline as a one-off.

## Component reuse (§4)

- **Buttons:** Primary CTAs → `.texturedButton(tint:)` (wood-grain capsule); secondary → `.buttonStyle(BouncyButtonStyle())`. Never `.buttonStyle(.plain)` with a custom-styled label; never hand-roll `.background() + .cornerRadius() + .shadow()` on a `Button`.
- **Cards:** `.softCard()` for the warm-cream surface (80% case). `.cardStyle()` for the parchment variant (rare).
- **Pip avatars:** Size via the `PipSize` enum (`.compact 40 / .medium 80 / .large 120 / .hero 160 / .custom(N)`). Never raw `Image("pip_...")` with hardcoded `.frame(width: N, height: N)`.
- **Pip dialogue:** `PipSpeechBubble` and `PipHeaderStack` **auto-speak** via `PipVoice.shared.speak(...)` on appear and on message change. Do NOT manually call `PipVoice.shared.speak(...)` next to these components — it double-speaks. Use `speakOnAppear: false` only for decorative usage.
- **PIN UI:** Use the shared `PINPadGrid<Leading, Trailing>` and `PINButton` from `PipComponents.swift`. Three views previously had local copies — never reintroduce.
- **Horizontal carousels:** Apply `.trailingFade()` (from `AdaptiveLayout.swift`) as the at-rest scroll cue. iOS's default scrollbar only appears mid-gesture; kids don't intuit swipe without this.
- **Primary CTAs that must always be reachable:** sticky footer pattern (see `RecipeDetailView` "Let's Cook!"). Don't bury below an un-cued `ScrollView(showsIndicators: false)`.
- **Profile pose image:** use `UserProfile.profilePoseImage` — never inline `gender == .boy ? "boy_card_clean_..." : "girl_card_clean_..."`. The helper routes parents to mom/dad frames.
- **Recipe display:** look up by ID, fall back to slug — `GardenRecipes.all.first { $0.id == star.recipeID }?.title ?? star.recipeID`. Never render raw recipe-ID slugs.
