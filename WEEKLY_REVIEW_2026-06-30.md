# Weekly Code Review — 2026-06-30

**Scope:** All 87 `.swift` files in `ChefAcademy/` (full read per Step 0)
**Review focus:** (1) Stale UI State bugs; (2) Hardcoded values & missed component reuse
**Status:** Read-only. No source files were modified.

---

## Executive Summary

| Category | Code | Count | Severity |
|---|---|---|---|
| Silent `try? save()` (data loss risk) | S2 | 6 sites | **CRITICAL** |
| Deprecated `UIScreen.main.bounds` | S3 | 4 sites | HIGH |
| `Timer.scheduledTimer` in view code | S1 | 19 sites | MEDIUM (mitigated) |
| Inline animation curves (not AnimationConstants) | H1 | 30+ sites, 14 files | MEDIUM |
| `profilePoseImage` bypass (hardcoded gender branch) | H11 | 16 sites, 9 files | MEDIUM |
| `.font(.system(size:))` instead of Font.AppTheme | H9 | 4 sites | MEDIUM |
| `.foregroundColor(.white)` instead of token | H8 | 6 sites | LOW |
| `Color.black.opacity()` shadow (not sepia token) | H7 | 2 sites | LOW |
| Hardcoded spacing / sizing / padding | H18 | 35+ sites, 15+ files | LOW |
| Raw `Image("pip_...")` bypasses PipSize | H21 | 5 sites | LOW |
| Hand-rolled card surfaces (not `.softCard()`) | R1 | 6 sites | LOW |
| Hand-rolled CTA buttons (not `.texturedButton(tint:)`) | R2 | 4 files | LOW |

**Clean files (no violations found):** `SessionManager`, `PipAIService`, `PipDialogView`, `PipStaticResponses`, `PipFoundationModelService`, `ProfileView`, `PlayerData`, `SeededRandomGenerator`, `SubscriptionManager`, `USDAFoodService`, `UserProfile`, `VideoPlayerView`, `WorkerClient`, `AuthManager`, `PINKeychain`, `MultiplayerManager`, `NearbyMultiplayerManager`, `GameCenterService`, `GardenWeatherService`, `AvatarModel`, `AmbientAudioPlayer`, `AssetPackController`, `AssetPackImage`, `MorphTransition`, `ODRManager`, `ContentView`, `Allergen`, `AppAttestService`, `FamilyProfile`, `CloudKeyManager`.

---

## Focus 1: Stale UI State

### S2 — Silent `try? save()` ⚠️ CRITICAL

CLAUDE.md §1 mandates `do { try save() } catch { print(error) }` — never `try?`. Silent failures destroyed child profiles for a week (March bug). Six active violations remain:

| File | Line(s) | Context |
|---|---|---|
| `FamilySetupView.swift` | 204 | `try? context.save()` after creating family + profiles |
| `AllergenEditorSheet.swift` | 119 | `try? modelContext.save()` after allergen toggle |
| `SiblingGardenView.swift` | 37, 176 | `try? modelContext.save()` on gift and gift confirmation |
| `SiblingProfileView.swift` | 275 | `try? modelContext.save()` after gift transaction |
| `ParentDashboardView.swift` | 461 | `try? modelContext.save()` after child delete / allergen edit |

**Fix pattern** (replace every instance):
```swift
// BEFORE
try? context.save()

// AFTER
do {
    try context.save()
} catch {
    print("[FileName] Failed to save: \(error)")
}
```

---

### S3 — Deprecated `UIScreen.main.bounds.width`

`UIScreen.main` is deprecated in iOS 16 and will be removed. On Stage Manager and split-screen iPadOS, it returns the full screen width rather than the window width, producing layout bugs.

| File | Lines | Usage |
|---|---|---|
| `GardenView.swift` | 1093, 1100, 1106 | Plot positioning calculations |
| `GardenView.swift` | 1625 | Pip drag boundary |

**Fix pattern:**
```swift
// BEFORE
let width = UIScreen.main.bounds.width

// AFTER — in a View, use GeometryReader or:
// Pass the geometry size from an enclosing GeometryReader as a parameter
```

---

### S1 — `Timer.scheduledTimer` in View Code (19 sites, all mitigated)

All 19 instances below wrap their state mutations in `Task { @MainActor in }`, so there is no immediate data-race crash risk. However, CLAUDE.md §2 prefers async `Task` loops over Timer for new code, and the Timer pattern still has the frame-rate coupling issue (fixed by the `TimelineView` pattern for physics).

The mitigation wrapper is present everywhere. These are pre-existing non-compliant patterns — log them but do not prioritize over S2/S3.

**Files and line references:**

| File | Line | Context |
|---|---|---|
| `PlotView.swift` | 428 | 0.05s animation loop |
| `ChopMiniGame.swift` | 275 | `startGame()` countdown |
| `CookingMiniGames.swift` | 121 | `HeatPanMiniGame` heat loop |
| `CookingMiniGames.swift` | 746 | `CookTimerMiniGame` countdown |
| `CookingMiniGames.swift` | 932 | `WashMiniGame` scrub loop |
| `HealthyChoiceGameView.swift` | 608 | `scheduleNextSpawn()` |
| `LocalVersusView.swift` | 752 | Countdown timer |
| `FamilySetupView.swift` | 610, 634, 668 | Step 5/6/7 intro animations |
| `MultiplayerHealthyPicksView.swift` | 746 | Spawn timer |
| `NearbyVersusView.swift` | 625 | Spawn timer |
| `SplitScreenVersusView.swift` | 579, 683 | Countdown + spawn |
| `PipAnimations.swift` | 103, 179 | `OneShotFrameAnimationView`, `AvatarAnimator.play()` |
| `PipGameAnimationView.swift` | 64 | Game-screen frame animation |
| `WaterPourCharacterView.swift` | 109 | Pour character frame loop |

`CharacterWalkingView.swift` is the canonical Timer-based walking engine — flagged in prior reviews as intentional (30fps Timer with `Task { @MainActor in }` mitigation). Continue tracking it but it is the established pattern for walking.

---

## Focus 2: Hardcoded Values & Missed Component Reuse

### H11 — `profilePoseImage` Bypass (16 sites, 9 files)

CLAUDE.md §4: "use `UserProfile.profilePoseImage` — never inline `gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"`."

The `profilePoseImage` computed property on `UserProfile` correctly routes parents to mom/dad frames and children to kid frames. All 16 bypass sites hardcode the child-specific frames and silently produce the wrong asset for parent profiles.

| File | Line(s) | Notes |
|---|---|---|
| `ChefAcademyApp.swift` | sibling chip | Also hardcodes `.frame(width: 90, height: 90)` |
| `AvatarCreatorView.swift` | 114 | `AvatarPreviewView` — preview context |
| `LocalVersusView.swift` | 199, 404, 436, 463 | 4 inline branches |
| `MultiplayerHealthyPicksView.swift` | 358, 600 | 2 sites |
| `NearbyVersusView.swift` | 275, 525 | 2 sites |
| `ParentDashboardView.swift` | 506 | `DashboardChildTab.characterImage` computed var |
| `SiblingProfileView.swift` | 26 | `characterImage` computed var |
| `SplitScreenVersusView.swift` | 111, 194, 215 | 3 sites |

**Fix pattern** (replace all inline branches):
```swift
// BEFORE
Image(child.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")

// AFTER
Image(child.profilePoseImage)
```

---

### H9 — `.font(.system(size:))` Instead of `Font.AppTheme.*`

CLAUDE.md §3: "Never `.font(.system(size:))`." All four violations are in `ProfilePickerView.swift` on the iPad branch of conditional font expressions:

| File | Line | Issue |
|---|---|---|
| `ProfilePickerView.swift` | 39 | `isIPad ? .system(size: 40, weight: .bold, design: .rounded) : .AppTheme.largeTitle` |
| `ProfilePickerView.swift` | 86 | `isIPad ? .system(size: 22, weight: .semibold, design: .rounded) : .AppTheme.headline` |
| `ProfilePickerView.swift` | 199 | `ProfileCard` — same iPad branch pattern |
| `ProfilePickerView.swift` | 208 | `ProfileCard` — `isIPad ? .system(size: 15, design: .rounded) : .AppTheme.caption` |

**Fix pattern:** Add iPad-scaled variants to `Font.AppTheme` (or use `AdaptiveCardSize` for the sizing decision), then use `Font.AppTheme.rounded(size: N, weight: .X)` for both branches:
```swift
// BEFORE
.font(isIPad ? .system(size: 40, weight: .bold, design: .rounded) : .AppTheme.largeTitle)

// AFTER — add to AppTheme.swift if needed:
.font(isIPad ? .AppTheme.rounded(size: 40, weight: .bold) : .AppTheme.largeTitle)
```

Note: `SceneEditor.swift` (DEV-only tool) also uses `.font(.system(size:))` throughout — acceptable for an internal layout editor.

---

### H8 — `.foregroundColor(.white)` Instead of Design Token

CLAUDE.md §3: shadows use `Color.AppTheme.sepia.opacity(N)`, and foreground colors must use `Color.AppTheme.*`. `.white` is not a token — the correct equivalent is `Color.AppTheme.cream` for text on colored backgrounds.

| File | Line(s) | Context |
|---|---|---|
| `BodyBuddyView.swift` | allergen badge | Allergen warning text on terracotta |
| `FarmShopView.swift` | 347 | Button label on sage background |
| `AllergenPickerStep.swift` | 134, 142 | Selected allergen pill text |
| `AvatarCreatorView.swift` | 400 | Selected-state tab text |
| `RecipeDetailView.swift` | 78 | Allergen banner text on terracotta |
| `FamilySetupView.swift` | (step screens) | CTA text on colored background |

**Fix:** Replace `.foregroundColor(.white)` → `.foregroundColor(Color.AppTheme.cream)` in each case.

---

### H7 — `Color.black.opacity()` Shadow (Not `Color.AppTheme.sepia.opacity()`)

CLAUDE.md §3: "Shadows: `Color.AppTheme.sepia.opacity(N)` — never `Color.black.opacity(N)`."

| File | Line | Issue |
|---|---|---|
| `FarmShopView.swift` | 582 | `.shadow(color: .black.opacity(0.5), ...)` |
| `ChopMiniGame.swift` | 167 | `.shadow(color: .black.opacity(0.2), ...)` |

---

### H1 — Inline Animation Curves (30+ violations, 14 files)

CLAUDE.md §3: "Never inline `.spring(response:)` or `.easeInOut(duration:)`." All animation curves must come from `AnimationConstants.*`. This is the largest category by raw count.

**Files with violations:**

| File | Lines / Context |
|---|---|
| `GameState.swift` | 171, 181 — bare `.spring()` calls |
| `PlotView.swift` | 424 — `.easeInOut(duration:0.6).repeatForever()` |
| `CookingSessionView.swift` | 523 — `.easeInOut(duration: 0.4)` |
| `CookingMiniGames.swift` | Multiple — `.easeOut(duration: N)`, `.easeIn(duration: N)` throughout |
| `BodyBuddyView.swift` | 92 — `.easeOut(duration: 1.0).delay(0.3)` |
| `AskPipView.swift` | 165 — `.easeOut(duration: 0.3)`; 445-449 — `.easeInOut(duration:0.4).repeatForever()` (typing indicator) |
| `ChopMiniGame.swift` | 186 — `.animation(.easeOut(duration: 0.1))` |
| `FamilySetupView.swift` | Step intro animations — `.easeOut(duration: 0.8)`, `.easeOut(duration: 0.6)` |
| `HealthyChoiceGameView.swift` | 412 — `.easeIn(duration: 2)`; 812 — `.easeIn(duration: 1.5)` |
| `MeetPipAnimated.swift` | 381 — `.easeIn(duration: Double.random(in: 1.5...2.5))` |
| `GlucoseJourneyView.swift` | 391, 485, 569, 591, 592, 597, 831, 837, 897, 905, 916, 919 — `.spring(response: N)`; 874 — `.easeInOut(duration: 0.6)` |
| `PipAnimations.swift` | `WiggleModifier` line 489 — `.easeInOut(duration: speed).repeatForever(autoreverses: true)` |
| `WeatherOverlayView.swift` | `SunshineOverlay` 81; `PartlyCloudyOverlay` 114, 117; `CloudOverlay` 147, 151; `WindOverlay` 484-490; `SeasonalOverlayView` 732, 736 — all inline `.easeInOut(duration:)` / `.linear(duration:)` |
| `PipTestView.swift` | 162 — `.easeOut(duration: 0.3)` (DEV-only) |

`GlucoseJourneyView.swift` is the single worst offender with 13 inline spring/easing calls. When fixing, add the needed tokens to `AnimationConstants` in `AppTheme.swift` — e.g., a `floatLoopWeather` (3s easeInOut repeatForever) and a `glucoseSpring` token.

---

### H18 — Hardcoded Spacing, Sizing, and Padding

CLAUDE.md §3: all spacing/sizing via `AppSpacing.*`. This category has the broadest spread across files.

**Recurring patterns:**

**PIN dot spacing** (consistent `HStack(spacing: 16)` across 3 views — should be one token):

| File | Line | Issue |
|---|---|---|
| `FamilySetupView.swift` | 836 | `HStack(spacing: 16)` PIN dots |
| `MigrationPINSetupView.swift` | 38 | `HStack(spacing: 16)` PIN dots |
| `ParentPINEntryView.swift` | 46 | `HStack(spacing: 16)` PIN dots |

Consider adding `AppSpacing.pinDotSpacing: CGFloat = 16` to `AppSpacing` and replacing all three.

**Small inter-item spacing (no AppSpacing token exists for sub-8pt values):**

| File | Lines | Values |
|---|---|---|
| `SeedInfoView.swift` | 369, 585, 821 | `HStack(spacing: 6)`, `HStack(spacing: 4)` |
| `SeedInfoView.swift` | 816 | `VStack(spacing: 3)` |
| `RecipeDetailView.swift` | 119, 124, 156, 170, 191, 205 | `HStack(spacing: 6/8)`, `VStack(spacing: 2)` |
| `RecipeCardExample.swift` | 985, 993, 1099, 1195 | `VStack(spacing: 4)`, `HStack(spacing: 6)` |
| `PlantingSheet.swift` | 226, 235, 251, 261 | `VStack(spacing: 2)`, `HStack(spacing: 3/4)` |
| `SplitScreenVersusView.swift` | 106, 303, 385, 393-394, 400, 407-408 | `VStack(spacing: 4)`, `HStack(spacing: 4/3)` |
| `AllergenPickerStep.swift` | 128 | `VStack(spacing: 6)` |
| `VoicePickerView.swift` (VoiceOptionCard) | 124 | `VStack(alignment: .leading, spacing: 2)` |
| `PlayLearnView.swift` | 53 | `VStack(alignment: .leading, spacing: 4)` |
| `ParentDashboardView.swift` | 511 | `VStack(spacing: 4)` |

**Hardcoded frame sizes:**

| File | Line | Value |
|---|---|---|
| `RecipeDetailView.swift` | 156-170 | `.frame(width: 28, height: 28)` garden ingredient icons |
| `RecipeDetailView.swift` | 191-205 | `.frame(width: 24, height: 24)` pantry ingredient icons |
| `RecipeDetailView.swift` | 229-230 | `.frame(width: 32, height: 32)` step number circle |
| `SiblingProfileView.swift` | 56 | `.frame(width: 120, height: 120)` avatar circle |
| `SiblingProfileView.swift` | 343 | `.frame(width: 60, height: 60)` gift sheet icon |
| `SiblingProfileView.swift` | 60 | `.stroke(..., lineWidth: 3)` — should be `AppSpacing.strokeBold` |
| `ChefAcademyApp.swift` | sibling chip | `.frame(width: 90, height: 90)`, `.cornerRadius(14)` |
| `WeatherOverlayView.swift` | 520 | `isIPad ? 18 : 14` raw sizes in `.rounded(size:)` |

**isIPad ternary sizing without AdaptiveCardSize:**

| File | Context |
|---|---|
| `GardenView.swift` | 271-277 — inline `isIPad ? 160 : 55`, `isIPad ? 16 : 12` |
| `GardenView.swift` | 1718 — `.cornerRadius(isIPad ? 16 : 12)` |
| `PlantingSheet.swift` | `seedImageSize`, `gridSpacing`, `npcImageSize` computed vars use `isIPad ?` |
| `ProfilePickerView.swift` | `avatarSize`, `circleSize`, `cardWidth` in `ProfileCard` |
| `MeetPipViews.swift` | 289 — `HStack(spacing: sizeClass == .compact ? -20 : -30)`, 297-303 |

**Hardcoded pill padding:**

| File | Line(s) | Issue |
|---|---|---|
| `RecipeDetailView.swift` | 60-63 | `.padding(.horizontal, 10).padding(.vertical, 5).cornerRadius(10)` |
| `RecipeDetailView.swift` | 80-81 | `.padding(.horizontal, 12).padding(.vertical, 8)` |
| `RecipeDetailView.swift` | 263-267 | `.padding(.horizontal, 12).padding(.vertical, 6).cornerRadius(14)` |
| `RecipeCardExample.swift` | 985-1012 | `.padding(.horizontal, 8).padding(.vertical, 4)`, `.padding(8)` |
| `SeedInfoView.swift` | 837 | `.padding(.horizontal, 8).padding(.vertical, 3)` |
| `SplitScreenVersusView.swift` | 393-394, 407-408 | `.padding(.horizontal, 8).padding(.vertical, 4)` |
| `PipVoice.swift` (PipVoiceToggleChip) | 224-225 | `.padding(.horizontal, 10).padding(.vertical, 6).cornerRadius(14)` |
| `AllergenPickerStep.swift` | 134-142 | `.cornerRadius(20)` pill shapes |

**Other isolated values:**

| File | Line | Issue |
|---|---|---|
| `BackgroundView.swift` | 66, 145 | `.padding(.trailing, 20)` |
| `PlantingSheet.swift` | 137, 303 | `Spacer(minLength: 40)` |
| `PipTestView.swift` | 69 | `Spacer(minLength: 50)` (DEV-only) |

---

### H21 — Raw `Image("pip_...")` Bypasses `PipSize` (5 sites)

CLAUDE.md §4: "Size via the `PipSize` enum. Never raw `Image("pip_...")` with hardcoded `.frame(width: N, height: N)`."

| File | Line(s) | Issue |
|---|---|---|
| `AskPipView.swift` | inline | `Image("pip_got_idea").frame(width: 40, height: 40)` |
| `GlucoseJourneyView.swift` | `PipJourneyMessage` | Raw `Image(pose).frame(width: 80, height: 80)` — bypasses PipSpeechBubble too |
| `InsulinTetrisView.swift` | 611-614 | `Image("pip_got_idea").frame(width: 120, height: 120)` |
| `MultiplayerHealthyPicksView.swift` | 561-564 | `Image("pip_got_idea").frame(width: 100, height: 100)` |
| `NearbyVersusView.swift` | 362-365 | `Image("pip_got_idea").frame(width: 80 * pipScale, height: 80 * pipScale)` |

**Fix pattern:**
```swift
// BEFORE
Image("pip_got_idea")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 100, height: 100)

// AFTER
Image(PipPose.gotIdea.rawValue)
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: PipSize.large.points, height: PipSize.large.points)
```

---

## Focus 3: Missed Component Reuse

### R1 — Hand-Rolled Card Surfaces (Not `.softCard()`)

CLAUDE.md §4: "`.softCard()` for the warm-cream surface (80% case)."

| File | Line(s) | Issue |
|---|---|---|
| `HomeAnimated.swift` | `StreakCardAnimated` | `.background(warmCream).cornerRadius(cardCornerRadius)` — no shadow, no modifiers |
| `MeetPipAnimated.swift` | 247 | `.background(warmCream).cornerRadius(cardCornerRadius)` |
| `MeetPipViews.swift` | 321-323 | `.background(warmCream).cornerRadius(cardCornerRadius)` |
| `NearbyVersusView.swift` | 434-436 | Results card — `.background(warmCream).cornerRadius(cardCornerRadius)` |
| `PipAnimations.swift` (`PipWithDialogue`) | 344-352 | `.background(Color.AppTheme.warmCream).cornerRadius(AppSpacing.cardCornerRadius)` |
| `BodyBuddyView.swift` | `pipMessageSection` | Hand-rolled warm-cream card surface |

**Fix:** Replace with `.softCard()` (or `.softCard(showShadow: false)` when no shadow is desired).

---

### R2 — Hand-Rolled Primary Buttons (Not `.texturedButton(tint:)`)

CLAUDE.md §4: "Primary CTAs → `.texturedButton(tint:)` (wood-grain capsule)." The following use raw `.background(sage).cornerRadius(cardCornerRadius).buttonStyle(.plain)` instead:

| File | Location | Button labels |
|---|---|---|
| `PlayLearnView.swift` | `MiniGameRouterView.placeholderView` | "Coming Soon" placeholder |
| `ProfilePickerView.swift` | 87-93 | "Add Little Chef" |
| `SiblingProfileView.swift` | 97-128 | "Visit Garden", "Gift Veggies" |
| `SplitScreenVersusView.swift` | 137-147, 233-243, 527-551 | "Next", "Start!", "Rematch!", "Done" |

Note: `SplitScreenVersusView` buttons combine hand-rolled `.background(sage).cornerRadius(...)` with `BouncyButtonStyle()`. This produces the bounce effect but loses the textured wood-grain capsule that is the design system's primary CTA surface.

---

## Appendix: Files With No Violations

The following files were read in full and are clean (no violations against CLAUDE.md §1–§6 rules):

`SessionManager.swift` · `PipAIService.swift` · `PipDialogView.swift` · `PipStaticResponses.swift` · `PipFoundationModelService.swift` · `ProfileView.swift` · `PlayerData.swift` · `SeededRandomGenerator.swift` · `SubscriptionManager.swift` · `USDAFoodService.swift` · `UserProfile.swift` · `VideoPlayerView.swift` · `WorkerClient.swift` · `AuthManager.swift` · `PINKeychain.swift` · `MultiplayerManager.swift` · `NearbyMultiplayerManager.swift` · `GameCenterService.swift` · `GardenWeatherService.swift` · `AvatarModel.swift` · `AmbientAudioPlayer.swift` · `AssetPackController.swift` · `AssetPackImage.swift` · `MorphTransition.swift` · `ODRManager.swift` · `ContentView.swift` · `Allergen.swift` · `AppAttestService.swift` · `FamilyProfile.swift` · `CloudKeyManager.swift` · `ElevenLabsVoiceService.swift` · `GameCenterMatchmakerView.swift` · `OnboardingView.swift` · `PaywallView.swift` · `CookingCompletionView.swift` · `AddChildFlowView.swift` · `PantryInfoView.swift` · `KitchenView.swift` · `CharacterWalkingView.swift` (Timer-based walking is the established pattern per §9)

**DEV-only files with intentional rule violations** (not production UI, not actioned):
`SceneEditor.swift` — dev overlay tool; uses raw system colors + `.font(.system(size:))` by design.
`PipTestView.swift` — dev test harness; contains one H1 + H18 violation but is never shown to users.

---

## Recommended Fix Order

1. **S2 — Silent saves** (6 sites) — Data integrity risk; straightforward 3-line fix per site.
2. **S3 — UIScreen.main.bounds** (4 sites in GardenView) — Replace with `GeometryReader`-passed size.
3. **H11 — profilePoseImage bypasses** (16 sites) — One-line fix per site; improves parent avatar rendering now and future-proofs non-binary expansion (K-01).
4. **H9 — .font(.system(size:)) in ProfilePickerView** (4 sites) — Convert iPad branch to `Font.AppTheme.rounded(size:weight:)`.
5. **H8 — .foregroundColor(.white)** (6 sites) — Replace with `Color.AppTheme.cream`.
6. **H7 — Black shadow colors** (2 sites) — Replace with `Color.AppTheme.sepia.opacity(N)`.
7. **R2 — Hand-rolled CTA buttons** (4 files) — Convert to `.texturedButton(tint:)`.
8. **R1 — Hand-rolled card surfaces** (6 sites) — Convert to `.softCard()`.
9. **H1 — Inline animations** (14 files) — Add missing tokens to `AnimationConstants`, then sweep.
10. **H18 — Hardcoded spacing** (15+ files) — Consider adding `AppSpacing.pinDotSpacing` for the PIN dot pattern; audit remaining small spacings.
11. **H21 — Raw Pip image frames** (5 sites) — Convert to `PipSize` enum values.
12. **S1 — Timer pattern** (19 sites, all mitigated) — Low urgency; convert to async Task loops opportunistically when touching those views.

---

*Review generated: 2026-06-30 | Method: full read of all 87 .swift files in ChefAcademy/ | No source files were modified.*
