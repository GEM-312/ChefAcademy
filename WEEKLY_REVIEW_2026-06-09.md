# ChefAcademy Weekly Code Review — 2026-06-09

**Scope:** All 87 Swift source files in `ChefAcademy/`
**Reviewer:** Automated weekly pass (Claude Code)
**Focus areas:** Stale-UI state bugs · SwiftData save safety · profilePoseImage violations · hardcoded design values · raw Pip component misuse

---

## §1 — Critical Stale-UI Bugs

These are the most urgent fixes. Each one is a latent race condition that will produce
inconsistent UI state under Swift 6 strict concurrency and will generate data-race
warnings today.

### P1 — DispatchQueue.main.async (must replace with Task { @MainActor in })

| File | Lines | Context |
|------|-------|---------|
| `AuthManager.swift` | 113 | Apple ID credential state handler completion |
| `GameCenterService.swift` | 104 | `GKLocalPlayer.authenticateHandler` |
| `MultiplayerManager.swift` | 65, 196, 242, 297, 321 | `GKMatchDelegate` callbacks + `startCountdown()` timer block |
| `NearbyMultiplayerManager.swift` | 155, 200, 221, 241, 287, 308, 310 | `MCSessionDelegate` / `MCNearbyServiceAdvertiserDelegate` callbacks + `startCountdown()` |
| `ParentPINEntryView.swift` | 134 | `ASAuthorizationControllerDelegate` completion in `startAppleIDVerification()` |
| `SeedInfoView.swift` | 222 | `VeggieCanvasView.updateUIView()` — `DispatchQueue.main.async { clearToggle = false }` inside a `UIViewRepresentable` update call |

**Pattern to apply (from Architecture Rule §2):**
```swift
// BEFORE
DispatchQueue.main.async {
    self.somePublished = newValue
}

// AFTER
Task { @MainActor in
    self.somePublished = newValue
}
```

For `startCountdown()` in both multiplayer managers, the `Timer.scheduledTimer` callback
must also be wrapped:
```swift
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
    Task { @MainActor in
        guard let self else { timer.invalidate(); return }
        // mutate @Published here
    }
}
```

### P2 — DispatchQueue.main.async in UIKit bridge delegates

| File | Lines | Context |
|------|-------|---------|
| `GameCenterMatchmakerView.swift` | 41, 57, 61 | `GKMatchmakerViewControllerDelegate` callbacks in `UIViewControllerRepresentable` |

These fire from UIKit delegate threads. Same fix as P1, but lower urgency because
`GameCenterMatchmakerView` is a shallow bridge with minimal state.

---

## §2 — Architecture Rule §1: SwiftData Save Violations (`try?` instead of `do/catch`)

Rule §1: **`do { try save() } catch { print(error) }` — NEVER `try?`.** Silent failures
destroyed child profiles for a week (March bug). Every `try?` here is a silent data-loss
risk on a write that matters.

| File | Line | Call site | Severity |
|------|------|-----------|----------|
| `AddChildFlowView.swift` | 133 | `try? modelContext.save()` after inserting a new child profile | **High** — new child profile may silently not persist |
| `AllergenEditorSheet.swift` | 119 | `try? modelContext.save()` after editing allergen list | Medium |
| `FamilySetupView.swift` | 204 | `try? context.save()` during family setup wizard completion | **High** — entire family setup could silently fail |
| `ParentDashboardView.swift` | 461 | `try? modelContext.save()` inside `deleteAllDataAndRestart()` | Medium |
| `ParentDashboardView.swift` | 492 | `try? modelContext.save()` inside `linkAppleID()` | Medium |
| `SiblingGardenView.swift` | 176 | `try? modelContext.save()` | Low (read-only visit scenario) |

**Fix template:**
```swift
// BEFORE
try? modelContext.save()

// AFTER
do {
    try modelContext.save()
} catch {
    print("[ChildFlow] save failed: \(error)")
}
```

---

## §3 — Architecture Rule §4: profilePoseImage Violations

Rule §4: **Use `UserProfile.profilePoseImage` — never inline `gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"`.** The helper routes parents to mom/dad frames — all inline checks silently break the parent visual.

| File | Lines | Violation detail |
|------|-------|-----------------|
| `ChefAcademyApp.swift` | ~chip button section | `sibling.gender == .boy ? "boy_card_..." : "girl_card_..."` inline |
| `ParentDashboardView.swift` | 506 | `DashboardChildTab.characterImage` computed property inlines the gender check |
| `LocalVersusView.swift` | 199, 404, 436, 461, 465 | `Image(player.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")` — five separate sites |
| `MultiplayerHealthyPicksView.swift` | 358, 598–613 | Inline gender ternary for avatar images |
| `NearbyVersusView.swift` | 275, 525 | Inline gender ternary |
| `SiblingProfileView.swift` | 26 | `private var characterImage: String { sibling.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06" }` — the entire private property is the pattern that `profilePoseImage` replaces |
| `SplitScreenVersusView.swift` | 111, 194, 215 | `Image(child.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")` — three sites |

**Fix template:**
```swift
// BEFORE
Image(player.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")

// AFTER
Image(player.profilePoseImage)
```

Note: `SiblingProfileView` passes a `UserProfile` object; call `.profilePoseImage` directly
on it and delete the local `characterImage` computed property.

---

## §4 — Hardcoded Animation Curves

All animation curves must come from `AnimationConstants.*`. The pre-commit grep targets:
`.spring(response:`, `.easeInOut(duration:`, `.easeOut(duration:`, `.easeIn(duration:`.

### Inline `.spring(response:dampingFraction:)` / `.spring()`

| File | Line(s) | Detail |
|------|---------|--------|
| `GameState.swift` | 172, 181 | `.spring()` bare — use `AnimationConstants.springQuick` |
| `GardenView.swift` | 765 (DEBUG only) | `.spring(response: 0.3, dampingFraction: 0.7)` — use `AnimationConstants.springSnappy` |
| `GlucoseJourneyView.swift` | multiple | Several `.spring(response: N, dampingFraction: N)` calls |

### Inline `.easeInOut(duration:)`

| File | Line(s) | Detail |
|------|---------|--------|
| `CookingSessionView.swift` | 523 | `.easeInOut(duration: 0.4)` |
| `GlucoseJourneyView.swift` | 874 | `.easeInOut(duration: 0.6)` |
| `PlotView.swift` | 424 | `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` in `startWatering()` |
| `WeatherOverlayView.swift` | multiple | `.easeInOut(duration: 3)` in SunshineOverlay; `.easeInOut(duration: 8)`, `.easeInOut(duration: 3)` in PartlyCloudyOverlay; `.easeInOut(duration: 10)`, `.easeInOut(duration: 7)` in CloudOverlay; `.easeInOut(duration: 3)` in SeasonalOverlayView |
| `PipAnimations.swift` | 489 | `WiggleModifier` — `.easeInOut(duration: speed).repeatForever(autoreverses: true)` |

### Inline `.easeOut(duration:)`

| File | Line(s) | Detail |
|------|---------|--------|
| `AskPipView.swift` | 165 | `.easeOut(duration: 0.3)` |
| `BodyBuddyView.swift` | multiple | Several `.easeOut(duration: N)` |
| `ChopMiniGame.swift` | 186 | `.easeOut(duration: 0.1)` |
| `FamilySetupView.swift` | multiple | Several `.easeOut(duration: N)` in step transitions |
| `PipAnimations.swift` | 162 | `PipGridItem.stopBreathingAnimation()` — `.easeOut(duration: 0.3)` |

### Inline `.easeIn(duration:)`

| File | Line(s) | Detail |
|------|---------|--------|
| `AskPipView.swift` | 806 | `.easeIn(duration: 0.3).delay(0.5)` |
| `GardenView.swift` | 1174 | `.easeIn(duration: 0.6)` |
| `HealthyChoiceGameView.swift` | 411, 812 | `.easeIn(duration: 2)`, `.easeIn(duration: 1.5)` |
| `MeetPipAnimated.swift` | 381 | `.easeIn(duration: Double.random(in: 1.5...2.5))` in `ConfettiView.createConfetti()` |

### Inline `.linear(duration:)`

| File | Line(s) | Detail |
|------|---------|--------|
| `WeatherOverlayView.swift` | multiple | `.linear(duration: 20)` in `SeasonalOverlayView` leaf animation |

**Resolution note for WeatherOverlayView:** The overlay animations are domain-specific
(weather loops that need particular feel). Add named tokens to `AnimationConstants`:
```swift
// Suggested additions to AnimationConstants in AppTheme.swift:
static let weatherFloatSlow   = Animation.easeInOut(duration: 10).repeatForever(autoreverses: true)
static let weatherFloatMedium = Animation.easeInOut(duration: 7).repeatForever(autoreverses: true)
static let weatherFloatFast   = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)
static let weatherRotate      = Animation.linear(duration: 20).repeatForever(autoreverses: false)
static let sunPulse           = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)
```

---

## §5 — Hardcoded Colors, Fonts, and Spacing

### A. Hardcoded Colors

| File | Line(s) | Issue | Fix |
|------|---------|-------|-----|
| `AllergenPickerStep.swift` | 134, 143 | `.foregroundColor(.white)` on selected chip label | `.foregroundColor(Color.AppTheme.cream)` |
| `ChopMiniGame.swift` | 167 | `.shadow(color: .black.opacity(0.2))` | `.shadow(color: Color.AppTheme.sepia.opacity(0.2))` |
| `GardenView.swift` | 114, 353 | `Color.black.opacity(0.2)` for shadows | `Color.AppTheme.sepia.opacity(0.2)` |
| `RecipeDetailView.swift` | 78 | `.foregroundColor(.white)` on badge text | `.foregroundColor(Color.AppTheme.cream)` |

### B. Hardcoded Fonts (`.font(.system(size:))`)

| File | Line(s) | Issue | Fix |
|------|---------|-------|-----|
| `ProfilePickerView.swift` | 39 | `.font(.system(size: 40, weight: .bold, design: .rounded))` for "Who's playing today?" title | `Font.AppTheme.rounded(size: 40, weight: .bold)` or add a `profilePickerTitle` token |
| `ProfilePickerView.swift` | 86, 199 | `.font(.system(size: 22, weight: .bold, design: .rounded))` in `ProfileCard` name label | `Font.AppTheme.rounded(size: 22, weight: .bold)` |
| `ProfilePickerView.swift` | 208 | `.font(.system(size: 15, weight: .medium, design: .rounded))` in `ProfileCard` role label | `Font.AppTheme.rounded(size: 15, weight: .medium)` |

### C. Hardcoded Spacing / Padding Tokens

The following should use `AppSpacing.*` constants:

| File | Line(s) | Hardcoded value | Correct token |
|------|---------|-----------------|---------------|
| `MigrationPINSetupView.swift` | 38 | `HStack(spacing: 16)` PIN dots | `AppSpacing.md` |
| `ParentPINEntryView.swift` | 46 | `HStack(spacing: 16)` PIN dots | `AppSpacing.md` |
| `PipDialogView.swift` | 70 | `.padding(.bottom, 100)` | `AppSpacing.tabBarClearance` |
| `ProfileView.swift` | 146 | `Spacer().frame(height: 100)` | `Spacer().frame(height: AppSpacing.tabBarClearance)` |
| `RecipeCardExample.swift` | multiple | `.padding(.bottom, 100)` in `RecipeListView` | `AppSpacing.tabBarClearance` |
| `HealthyChoiceGameView.swift` | 334 | `.padding(.bottom, 60)` | `AppSpacing.tabBarClearance` |
| `MultiplayerHealthyPicksView.swift` | 331 | `.padding(.bottom, 60)` | `AppSpacing.tabBarClearance` |
| `SeedInfoView.swift` | 360, 413 | `.padding(.top, 60)` | Needs AdaptiveCardSize token or AppSpacing token |
| `PantryInfoView.swift` | 87, 147 | `.padding(.top, 60)` | Same as above |
| `SiblingGardenView.swift` | 63 | `.padding(.top, 60)` | Same |
| `ParentDashboardView.swift` | 307 | `Spacer().frame(height: 40)` | `AppSpacing.xl` |
| `AllergenEditorSheet.swift` | 84 | `Spacer().frame(height: 40)` | `AppSpacing.xl` |
| `BodyBuddyView.swift` | 85 | `Spacer().frame(height: 80)` | Needs token |
| `PlayLearnView.swift` | ~end | `Spacer().frame(height: 80)` | Needs token |
| `SiblingProfileView.swift` | 209 | `Spacer().frame(height: 80)` | Needs token |
| `GlucoseJourneyView.swift` | multiple | `Spacer().frame(height: 100)` | `AppSpacing.tabBarClearance` |

### D. Hardcoded Corner Radii

| File | Line(s) | Value | Token |
|------|---------|-------|-------|
| `AvatarCreatorView.swift` | 232 | `cornerRadius: 4` | `AppSpacing.cornerRadius.pill` (8) or add a `xs` radius token |
| `ChefAcademyApp.swift` | chip buttons | `cornerRadius(14)` | `AppSpacing.cornerRadius.large` (20) or `card` (16) — check visual intent |
| `FamilySetupView.swift` | ~503 | `cornerRadius(24)` | None — add `AppSpacing.cornerRadius.xl` token or use `large` (20) |
| `GardenView.swift` | 167, 391 | `cornerRadius(6)` | `AppSpacing.cornerRadius.pill` (8) is nearest — check visually |
| `InsulinTetrisView.swift` | 549–550 | `cornerRadius(10)` | `AppSpacing.cornerRadius.small` (12) is nearest |
| `PipVoice.swift` | 219–220 | `cornerRadius(14)` | `AppSpacing.cornerRadius.large` (20) or `card` (16) |
| `RecipeDetailView.swift` | multiple | `cornerRadius(10)`, `cornerRadius(14)` | `AppSpacing.cornerRadius.small` / `card` |
| `SiblingProfileView.swift` | ~60 | `lineWidth: 3` | `AppSpacing.stroke.bold` |
| `SplitScreenVersusView.swift` | 548 | `lineWidth: 1.5` | `AppSpacing.stroke.medium` (2) — verify intent |
| `PipDialogView.swift` | 101 | `lineWidth: 1.5` | `AppSpacing.stroke.medium` (2) |

### E. Hardcoded Frame Sizes

| File | Line(s) | Value | Token / fix |
|------|---------|-------|-------------|
| `AvatarCreatorView.swift` | multiple | `.frame(width: 200, height: 200)`, `.frame(width: 220, height: 220)` | `AppSpacing.infoCardImageSize` (200) for the first; add token for 220 |
| `PantryInfoView.swift` | 54 | `.frame(width: 200, height: 200)` | `AppSpacing.infoCardImageSize` |
| `SeedInfoView.swift` | 519 | `.frame(width: 42, height: 42)` | `AppSpacing.buttonHeight`-derived or new token |
| `SiblingProfileView.swift` | 56 | `.frame(width: 120, height: 120)` | `PipSize.hero` (160) is nearest — use AdaptiveCardSize if variant needed |

### F. Hardcoded `HStack(spacing:)` / `VStack(spacing:)`

These should use `AppSpacing.*` (xs=8, sm=12, md=16, lg=24):

| File | Line(s) | Value |
|------|---------|-------|
| `AllergenPickerStep.swift` | grid | spacing: 6 → `AppSpacing.xs` (8) |
| `CookingMiniGames.swift` | 622 | `HStack(spacing: 8)` → `AppSpacing.xs` |
| `HealthyChoiceGameView.swift` | 169, 185 | `HStack(spacing: 8)` → `AppSpacing.xs` |
| `InsulinTetrisView.swift` | 547–548 | `.padding(.horizontal, 10).padding(.vertical, 4)` → `AppSpacing.xs` / `AppSpacing.xxs` |
| `MultiplayerHealthyPicksView.swift` | 128 | `HStack(spacing: 8)` → `AppSpacing.xs` |
| `NearbyVersusView.swift` | 109 | `HStack(spacing: 8)` → `AppSpacing.xs` |
| `PlotView.swift` | multiple | `VStack(spacing: 6)`, `VStack(spacing: 4)`, `VStack(spacing: 2)` → `AppSpacing.xs` / `AppSpacing.xxs` |
| `PipVoice.swift` | 219 | `.padding(.horizontal, 10).padding(.vertical, 6)` → `AppSpacing.xs` / `AppSpacing.xs` |
| `RecipeDetailView.swift` | multiple | `.padding(.horizontal, 10).padding(.vertical, 5)`, `.padding(.horizontal, 12).padding(.vertical, 8)` → `AppSpacing.xs` / `AppSpacing.sm` |

---

## §6 — Raw Pip Images Without PipSize / PipSpeechBubble

Rule §4: Pip dialogue layouts use `PipSpeechBubble` / `PipHeaderStack`. Pip size is managed
via the `PipSize` enum. Raw `Image("pip_...")` with a hardcoded `.frame(width:height:)` is a
violation.

### Hand-rolled Pip speech bubbles (should use `PipSpeechBubble`)

| File | Lines | Description |
|------|-------|-------------|
| `AskPipView.swift` | 426–458 | `pipTypingIndicator` — `Image("pip_neutral")` at 40pt inside a custom HStack bubble. Replace with `PipSpeechBubble` (or the `PipSize.compact` variant if only the avatar is needed) |
| `BodyBuddyView.swift` | 253–268 | `pipMessageSection` — custom ZStack with Pip avatar + speech tail + message text. Replace with `PipSpeechBubble` |
| `GlucoseJourneyView.swift` | 1438–1460 | `PipJourneyMessage` struct — `.frame(width: 80, height: 80)` Pip avatar + inline bubble layout. Replace with `PipSpeechBubble` |

### Raw Pip images with hardcoded sizes (should use `PipSize`)

| File | Lines | Code | Fix |
|------|-------|------|-----|
| `InsulinTetrisView.swift` | 611–615 | `Image("pip_got_idea").frame(width: 120, height: 120)` in `gameOverScreen` | `PipWavingAnimatedView(size: .large)` or `Image(PipPose.gotIdea.rawValue).frame(width: PipSize.large.value, height: PipSize.large.value)` |
| `NearbyVersusView.swift` | 362–370 | `Image("pip_got_idea").frame(width: 80 * pipScale, height: 80 * pipScale)` in countdown | `PipSize.medium.value` scaled or `PipWavingAnimatedView(size: .medium)` |
| `PipTestView.swift` | (DEV tool) | `Image(pose.rawValue).frame(width: 120, height: 120)` — DEV-only | Low priority; DEV file exempt but worth fixing for consistency |

---

## §7 — Clean-Bill Files (No Issues Found)

The following files passed both focus areas with no actionable findings:

`AmbientAudioPlayer.swift`, `AppAttestService.swift`, `AssetPackController.swift`,
`AssetPackImage.swift`, `AvatarModel.swift`, `BackgroundView.swift`¹,
`CharacterWalkingView.swift`, `ChefAcademyApp.swift`²,
`ElevenLabsVoiceService.swift`, `FarmShopView.swift`, `GardenWeatherService.swift`,
`HomeAnimated.swift`, `KitchenView.swift`, `MeetPipViews.swift`, `MorphTransition.swift`,
`ODRManager.swift`, `OnboardingView.swift`, `PINKeychain.swift`, `PaywallView.swift`,
`PipAIService.swift`, `PipFoundationModelService.swift`, `PipGameAnimationView.swift`,
`PipStaticResponses.swift`, `PlayerData.swift`, `RecipeCardExample.swift`³,
`SeededRandomGenerator.swift`, `SubscriptionManager.swift`, `USDAFoodService.swift`,
`UserProfile.swift`, `VideoPlayerView.swift`, `VoicePickerView.swift`,
`WaterPourCharacterView.swift`, `WorkerClient.swift`

> ¹ `BackgroundView.swift` uses `.padding(.trailing, 20)` and `floatOffset = -8` which
> are animation-internal literals; acceptable for a single-purpose background component.
> 
> ² `ChefAcademyApp.swift` has a §4 sibling-gender check (see §3 table above) — listed
> here because all other patterns in the file are clean.
>
> ³ `RecipeCardExample.swift` has a `.padding(.bottom, 100)` tabBarClearance issue in
> `RecipeListView` (see §5-C) but is otherwise clean.

**Developer tool exemptions (intentional hardcoded values):**
- `SceneEditor.swift` — `Color.black/red/white`, `.font(.system(size: N, design: .monospaced))` — debug overlay, intentional.
- `PipTestView.swift` — DEV-only view, low priority but listed in §6 for completeness.
- `SignInView.swift` — Apple Sign In button sizing follows HIG requirements, not AppTheme tokens.

---

## §8 — Summary Table

| Category | Severity | File count | Issue count | Sprint recommendation |
|----------|----------|------------|-------------|----------------------|
| §1 Stale-UI: `DispatchQueue.main.async` | **P1** | 6 | 17 call sites | Fix before next sprint |
| §1 Stale-UI: UIKit bridge `DispatchQueue.main.async` | P2 | 1 | 3 call sites | Fix this sprint |
| §2 SwiftData `try?` saves | **High** | 6 | 7 call sites | Fix before next sprint |
| §3 `profilePoseImage` violations | Medium | 7 | 15+ call sites | Fix this sprint (one grep, one sweep) |
| §4 Hardcoded animation curves | Low–Medium | 14 | 30+ call sites | Batch fix in a single AnimationConstants token pass |
| §5 Hardcoded colors | Low | 4 | 6 call sites | Easy; fix alongside §4 pass |
| §5 `.font(.system(size:))` | Low | 1 | 4 call sites | Easy |
| §5 Hardcoded spacing/padding | Low | 15 | 30+ call sites | Batch fix with tabBarClearance sweep |
| §5 Hardcoded corner radii / stroke | Low | 9 | 15 call sites | Bundle with spacing pass |
| §6 Raw Pip without PipSize/PipSpeechBubble | Medium | 5 | 8 call sites | Fix this sprint |
| **Total actionable** | | **~35 files** | **~130 sites** | |

### Recommended sprint order

1. **§2 SwiftData saves** — highest blast radius (data loss). One-line fix each; do all 6 files together.
2. **§1 P1 DispatchQueue.main.async** — 6 files, mechanical replacement. Start with `AuthManager` + `GameCenterService` (smallest), then multiplayer managers.
3. **§3 profilePoseImage** — one grep (`gender == .boy ? "boy_card_clean_frame_11"`) finds all sites; replace with `.profilePoseImage`.
4. **§6 Raw Pip bubbles** — `AskPipView`, `BodyBuddyView`, `GlucoseJourneyView` are the highest-value replacements.
5. **§5 tabBarClearance sweep** — grep `padding(.bottom, 100)` + `padding(.bottom, 60)` + `Spacer().frame(height: 100)` and replace with `AppSpacing.tabBarClearance`.
6. **§4 Animation tokens** — largest surface area but purely cosmetic; batch last.

---

*Generated by automated weekly pass. No source files were modified.*
