# Weekly Code Review — 2026-05-10

> Automated pass covering all 87 Swift source files in `ChefAcademy/`.
> Two focus areas: **STALE-UI state bugs** and **hardcoded values / missed component reuse**.
> Source files were NOT modified. This document is read-only analysis.

---

## 1. Files Read

All 87 `.swift` files were read in full before any analysis was written.

```
AdaptiveLayout.swift              AddChildFlowView.swift
Allergen.swift                    AllergenEditorSheet.swift
AllergenPickerStep.swift          AmbientAudioPlayer.swift
AppAttestService.swift            AppTheme.swift
AskPipView.swift                  AssetPackController.swift
AssetPackImage.swift              AuthManager.swift
AvatarCreatorView.swift           AvatarModel.swift
BackgroundView.swift              BodyBuddyView.swift
CharacterWalkingView.swift        ChefAcademyApp.swift
ChopMiniGame.swift                CloudKeyManager.swift
ContentView.swift                 CookingCompletionView.swift
CookingMiniGames.swift            CookingSessionView.swift
ElevenLabsVoiceService.swift      FamilyProfile.swift
FamilySetupView.swift             FarmShopView.swift
GameCenterMatchmakerView.swift    GameCenterService.swift
GameState.swift                   GardenHubView.swift
GardenView.swift                  GardenWeatherService.swift
GlucoseJourneyView.swift          HealthyChoiceGameView.swift
HomeAnimated.swift                InsulinTetrisView.swift
KitchenView.swift                 LocalVersusView.swift
MeetPipAnimated.swift             MeetPipViews.swift
MigrationPINSetupView.swift       MorphTransition.swift
MultiplayerHealthyPicksView.swift MultiplayerManager.swift
NearbyMultiplayerManager.swift    NearbyVersusView.swift
ODRManager.swift                  OnboardingView.swift
PINKeychain.swift                 PantryInfoView.swift
ParentDashboardView.swift         ParentPINEntryView.swift
PaywallView.swift                 PipAIService.swift
PipAnimations.swift               PipComponents.swift
PipDialogView.swift               PipFoundationModelService.swift
PipGameAnimationView.swift        PipStaticResponses.swift
PipTestView.swift                 PipVoice.swift
PlantingSheet.swift               PlayLearnView.swift
PlayerData.swift                  PlotView.swift
ProfilePickerView.swift           ProfileView.swift
RecipeCardExample.swift           RecipeDetailView.swift
SceneEditor.swift                 SeedInfoView.swift
SeededRandomGenerator.swift       SessionManager.swift
SiblingGardenView.swift           SiblingProfileView.swift
SignInView.swift                  SplitScreenVersusView.swift
SubscriptionManager.swift         USDAFoodService.swift
UserProfile.swift                 VideoPlayerView.swift
VoicePickerView.swift             WeatherOverlayView.swift
WorkerClient.swift
```

Style / architecture references also read in full:
`AppTheme.swift`, `AdaptiveLayout.swift`, `PipComponents.swift`, `ChefAcademy/CLAUDE.md`

---

## 2. TL;DR

| Category | Count | Worst offender |
|---|---|---|
| STALE-UI — `DispatchQueue.main.asyncAfter` | 26 files / ~55 call sites | `FarmShopView.swift` (P0 — dangling write after dismiss) |
| STALE-UI — deprecated `.onChange(of:)` single-arg | 1 | `AskPipView.swift` |
| STALE-UI — Timer without `@MainActor` guard | 1 | `ChopMiniGame.swift` |
| HARDCODE — inline animation curves | ~65 call sites across 22 files | `SeedInfoView.swift` (10 inline curves) |
| HARDCODE — raw colors (`Color.black`, `.white`, hex strings) | ~30 call sites across 10 files | `WeatherOverlayView.swift` (12 raw colors) |
| HARDCODE — `.font(.system(size:))` | ~18 call sites across 7 files | `ProfilePickerView.swift` (7 inline device-branch fonts) |
| HARDCODE — inline spacing/padding/frame dimensions | ~50 call sites across 18 files | `PlotView.swift` / `RecipeDetailView.swift` |
| REFACTOR — hand-rolled views duplicating existing components | 6 cases | `PipJourneyMessage` duplicates `PipSpeechBubble` |
| Missing design tokens | 8 tokens | `AnimationConstants.floatLoop`, `AnimationConstants.pinShake` |

**Bottom line:** The codebase is architecturally sound. `SessionManager`, `GameState`, `PlayerData`, `SubscriptionManager`, `PipAIService`, `PipFoundationModelService`, `PaywallView`, and `PipGameAnimationView` are reference-quality. The two endemic problems are (a) `DispatchQueue.main.asyncAfter` used for animation sequencing everywhere instead of `Task + Task.sleep` — creates dangling-capture risk and drops animations on view dismiss — and (b) inline animation curves / raw color literals in roughly a third of the view files, defeating the design system.

---

## 3. [STALE-UI] — Stale State & Threading Bugs

### 3a. `DispatchQueue.main.asyncAfter` — fire-and-forget (P0 / P1)

**Why it's wrong:** When the closure executes, the view may have been dismissed, the `@State` variable may be gone, or the animation may conflict with a new transition already in progress. SwiftUI does not cancel pending closures on view teardown. The correct replacement is:

```swift
// BEFORE (broken)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    showReward = false
}

// AFTER (correct)
Task { @MainActor in
    try? await Task.sleep(for: .seconds(0.3))
    guard !Task.isCancelled else { return }
    showReward = false
}
```

Assign the `Task` to a `@State var animTask: Task<Void,Never>?` and cancel it in `.onDisappear` for full safety.

**Affected files and call sites:**

| Severity | File | Line(s) | Description |
|---|---|---|---|
| **P0** | `FarmShopView.swift` | ~290 | `bounceItem = nil` after 0.5s — view dismissal during that window writes to dead `@State`. Most dangerous instance in the codebase. |
| P1 | `LocalVersusView.swift` | 6 sites | Countdown, food reveal, score flash — 6 chained asyncAfter calls; any navigation during a countdown leaves all 6 pending. |
| P1 | `MultiplayerHealthyPicksView.swift` | 6 sites | Same countdown/reveal pattern as LocalVersusView. |
| P1 | `MeetPipAnimated.swift` | 4 sites | `startAnimation()`, `advanceDialogue()`, `ConfettiView.spawnConfetti()` — chained delays build up if the onboarding view is exited early. |
| P1 | `SeedInfoView.swift` | 6+ sites | Pip tip reveal (0.8s), color tip transition ×2 (0.2s), coin reward dismiss ×3 (1.2s) — heavy chaining; any of the 3 coin paths leaves 2 orphaned closures. |
| P1 | `PlotView.swift` | 5 sites | Weed removal (0.3s), `checkWeedingComplete` (0.3s), `rescueBug` nested ×2 (0.3s each), `showXPBadge` (1.0s). Nested asyncAfter in `rescueBug` is the worst: outer fires, inner fires 0.3s later — no cancellation possible. |
| P1 | `GlucoseJourneyView.swift` | 4 sites | `CellPhaseView` and `SmartSnackQuizView` both sequence state transitions via asyncAfter. |
| P1 | `InsulinTetrisView.swift` | 2 sites | Game-over flash and input lock release. |
| P1 | `HealthyChoiceGameView.swift` | 3 sites | Round transitions and correct-answer feedback. |
| P1 | `NearbyVersusView.swift` | 3 sites | Match start, round end, disconnect handling. |
| P1 | `PipAnimations.swift` | 4 sites | `PipCharacterView.triggerPoseChangeAnimation` (0.15s), `PipReactionView.triggerCelebration` (2.0s), `PipWithDialogue` ×2 (0.5s, 0.2s). |
| P1 | `PantryInfoView.swift` | 2 sites | Pip tip show (0.5s), coin reward dismiss (1.5s). |
| P1 | `SiblingGardenView.swift` | 1 site | Help reward toast dismiss (2.5s). |
| P1 | `SiblingProfileView.swift` | 1 site | Gift toast dismiss (2.5s). |
| P1 | `SplitScreenVersusView.swift` | 3 sites | `startFirstSplitSpawn` (0.3s), `tapFood` ×2 (0.3s each). |
| P1 | `CookingCompletionView.swift` | 2 sites | Star reveal sequence (0.3s, 0.6s). |
| P1 | `GardenView.swift` | 3 sites | NPC entrance, help toast, weed warning. |
| P1 | `FamilySetupView.swift` | 3 sites | Step transitions, avatar load, welcome delay. |
| P1 | `MigrationPINSetupView.swift` | 2 sites | Success confirmation, onward routing. |
| P1 | `CookingSessionView.swift` | 1 site | Mini-game transition delay. |
| P1 | `HomeAnimated.swift` | 1 site | Pip idle trigger. |
| P1 | `PlantingSheet.swift` | 1 site | Pip NPC entrance (0.3s). |
| P1 | `ChopMiniGame.swift` | 1 site | Chop feedback reset. |
| P1 | `AskPipView.swift` | 1 site | ScrollView proxy scroll-to-bottom. |

### 3b. Deprecated `.onChange(of:)` single-argument form (P1)

**File:** `AskPipView.swift`

The single-argument `.onChange(of: value) { newValue in }` closure form is deprecated in iOS 17+ and removed in iOS 18. Replace with the two-argument form:

```swift
// BEFORE (deprecated)
.onChange(of: messages) { newMessages in
    scrollProxy.scrollTo(...)
}

// AFTER
.onChange(of: messages) { _, newMessages in
    scrollProxy.scrollTo(...)
}
```

### 3c. Timer callback without `@MainActor` wrapper (P1)

**File:** `ChopMiniGame.swift`

The `Timer.scheduledTimer` callback mutates `@State` / `@Published` variables directly without `Task { @MainActor in }`. All `@Published` writes must happen on the main actor. The pattern used correctly in `SessionManager.swift` (play-time timer) and `PipGameAnimationView.swift` should be adopted:

```swift
// BEFORE (unsafe)
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
    progress -= step   // mutates @State off main actor
}

// AFTER (correct)
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
    Task { @MainActor in
        progress -= step
    }
}
```

---

## 4. [PERF] — Performance Issues

### 4a. `SeasonalOverlayView` — random positions recomputed every render (P2)

**File:** `WeatherOverlayView.swift`, `SeasonalOverlayView.springParticles` / `fallParticles` / `winterParticles`

`CGFloat.random(in:)` is called directly inside the `var body` computed property for each `ForEach` child. Every time SwiftUI re-evaluates the body (on any parent state change, device rotation, etc.) all particle positions jump to new random values, causing a visual glitch and wasted layout work.

Fix: Move particle data into `@State` arrays initialized once in `.onAppear`, as done correctly by `RainOverlay`, `StormOverlay`, and `SnowOverlay` in the same file.

```swift
// BEFORE (position computed every render)
var springParticles: some View {
    ForEach(0..<8, id: \.self) { i in
        Ellipse()
            .offset(x: CGFloat.random(in: -mapWidth/2...mapWidth/2), ...)
    }
}

// AFTER (position stable across renders)
struct SpringParticle { var x: CGFloat; var y: CGFloat; ... }
@State private var springData: [SpringParticle] = []
// init in .onAppear, use springData[i].x in body
```

### 4b. `USDAFoodService.fetchAll` — unbounded concurrency (P2)

**File:** `USDAFoodService.swift` — `fetchAll(items:)` method

`withTaskGroup` spawns one child task per item without a concurrency limit. With all 46 FDC IDs loaded at once this fires 46 simultaneous requests to the Cloudflare Worker, easily triggering rate-limiting on the Worker or App Attest service. Add a semaphore or use `TaskGroup` with a bounded pool:

```swift
// Simple bounded approach: process in batches of 5
for chunk in items.chunked(into: 5) {
    await withTaskGroup(of: Void.self) { group in
        for item in chunk { group.addTask { _ = await self.nutrientProfile(for: item) } }
    }
}
```

### 4c. `KitchenView` — arithmetic on spacing tokens (P3)

**File:** `KitchenView.swift`

`.padding(.vertical, AppSpacing.xxs - 1)` performs arithmetic on a design token at call site. This obscures intent and breaks if the token value changes. Add a named token (`AppSpacing.tightVertical` or similar) or use the nearest existing token.

---

## 5. [HARDCODE] — Hardcoded Values (Non-Negotiable Rule Violations)

All values below must map to `AppTheme` / `AppSpacing` / `AnimationConstants` tokens, or a new named token must be added (see Section 7). **Never propose inline values.**

### 5a. Raw Color Literals

#### `Color.black` / `Color.white` / raw system colors used as UI values

| File | Location | Raw value | Correct token |
|---|---|---|---|
| `AvatarModel.swift` | `.chefHatWhite` switch case | `Color(hex: "F7FAFC")` | Add `Color.AppTheme.pureWhite` |
| `CharacterWalkingView.swift` | Shadow under Pip | `Color.black.opacity(0.2)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `PipDialogView.swift` | Dim overlay behind dialog | `Color.black.opacity(0.4)` | Add `Color.AppTheme.overlay` |
| `PantryInfoView.swift` | Coin reward card shadow | `.shadow(color: .black.opacity(0.2), ...)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `PantryInfoView.swift` | Paintbrush button shadow | `.shadow(color: Color.black.opacity(0.15), ...)` | `Color.AppTheme.sepia.opacity(0.15)` |
| `SeedInfoView.swift` | Coin reward card shadow | `.shadow(color: .black.opacity(0.2), ...)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `SeedInfoView.swift` | Paintbrush button shadow | `.shadow(color: Color.black.opacity(0.15), ...)` | `Color.AppTheme.sepia.opacity(0.15)` |
| `RecipeCardExample.swift` | Allergen warning text | `.foregroundColor(.white)` | `Color.AppTheme.cream` |
| `RecipeDetailView.swift` | Allergen warning text | `.foregroundColor(.white)` | `Color.AppTheme.cream` |
| `HealthyChoiceGameView.swift` | Food label shadow | `.shadow(color: .white, radius: 2)` | `Color.AppTheme.cream` |
| `LocalVersusView.swift` | Food label shadow | `.shadow(color: .white, radius: 2)` | `Color.AppTheme.cream` |
| `MultiplayerHealthyPicksView.swift` | Food label shadow | `.shadow(color: .white, radius: 2)` | `Color.AppTheme.cream` |
| `NearbyVersusView.swift` | Food label shadow | `.shadow(color: .white, radius: 2)` | `Color.AppTheme.cream` |
| `CookingMiniGames.swift` | Pan / ingredient surfaces | `Color(white: 0.85)`, `Color(white: 0.7)`, `Color(white: 0.3)` | Map to `Color.AppTheme.warmCream`, `Color.AppTheme.sepia`, `Color.AppTheme.darkBrown` |

#### `Color(hex:)` strings that should be named tokens

| File | Location | Value | Action |
|---|---|---|---|
| `GardenWeatherService.swift` | Seasonal gradient arrays | Multiple `Color(hex: "...")` | Add `GardenSeason.gradientColors` to return `[Color.AppTheme.*]` tokens; define seasonal color tokens in `AppTheme.swift` |
| `WeatherOverlayView.swift` | `fallParticles` | `Color(hex: "8B4513")` (saddle brown), `Color(hex: "DAA520")` (golden rod) | `Color.AppTheme.terracotta` / `Color.AppTheme.goldenWheat` approximate these; or add `Color.AppTheme.autumnBrown` |
| `WeatherOverlayView.swift` | `winterParticles` | `Color(hex: "E3F2FD")` (ice blue) | Add `Color.AppTheme.frostBlue` |

#### Raw system colors in weather particles (WeatherOverlayView.swift)

The weather particle overlays use `.yellow`, `.orange`, `.blue`, `.gray`, `.white`, `.cyan`, `.pink` directly throughout `SunshineOverlay`, `PartlyCloudyOverlay`, `CloudOverlay`, `RainOverlay`, `SnowOverlay`. While some creative license is acceptable for transient atmospheric particles, they should at minimum use opacity-adjusted AppTheme tokens or new weather-specific tokens to stay in the design system.

Recommended additions to `AppTheme.swift`: `Color.AppTheme.sunYellow`, `Color.AppTheme.skyBlue`, `Color.AppTheme.cloudWhite`, `Color.AppTheme.rainBlue`.

### 5b. `.font(.system(size:))` Violations

All font sizing must use `Font.AppTheme.rounded(size:weight:)` or a named `Font.AppTheme.*` token. Never use `.font(.system(size:))` or `.font(.system(size:weight:design:))`.

| File | Location | Raw value | Correct replacement |
|---|---|---|---|
| `ChefAcademyApp.swift` | `HomeStatChip` text | `.font(.system(size: 13))` | `Font.AppTheme.caption` |
| `ChefAcademyApp.swift` | `QuickActionCard` icon | `.font(.system(size: isLarge ? 40 : 30))` | `Font.AppTheme.rounded(size: isLarge ? 40 : 30)` + use `AdaptiveCardSize` |
| `HomeAnimated.swift` | Notification badge | `.font(.system(size: 10))` | `Font.AppTheme.caption` or a new `Font.AppTheme.micro` |
| `PlotView.swift` | Emoji water drops / weeds / bugs | `.font(.system(size: 24))`, `.font(.system(size: 20))` etc. | `Font.AppTheme.rounded(size: 24)` |
| `ProfilePickerView.swift` | `ProfileCard` crown icon | `.font(.system(size: isIPad ? 36 : 18))` | `Font.AppTheme.rounded(size: isIPad ? 36 : 18)` |
| `ProfilePickerView.swift` | `ProfileCard` lock icon | `.font(.system(size: isIPad ? 22 : 12))` | `Font.AppTheme.rounded(size: isIPad ? 22 : 12)` |
| `ProfilePickerView.swift` | `ProfileCard` clock icon | `.font(.system(size: isIPad ? 14 : 10))` | `Font.AppTheme.rounded(size: isIPad ? 14 : 10)` |
| `ProfilePickerView.swift` | `ProfileCard` name | `.font(isIPad ? .system(size: 22, weight: .semibold, design: .rounded) : .AppTheme.headline)` | `Font.AppTheme.rounded(size: isIPad ? 22 : 17, weight: .semibold)` |
| `ProfilePickerView.swift` | `ProfileCard` last-played | `.font(isIPad ? .system(size: 15, design: .rounded) : .AppTheme.caption)` | `Font.AppTheme.rounded(size: isIPad ? 15 : 12)` |
| `ProfilePickerView.swift` | Header title | `.font(isIPad ? .system(size: 40, weight: .bold, design: .rounded) : .AppTheme.largeTitle)` | `Font.AppTheme.rounded(size: isIPad ? 40 : 34, weight: .bold)` |
| `ProfilePickerView.swift` | "Add Little Chef" button | `.font(isIPad ? .system(size: 22, ...) : .AppTheme.headline)` | `Font.AppTheme.rounded(size: isIPad ? 22 : 17, weight: .semibold)` |
| `WeatherOverlayView.swift` | `WeatherBadge` weather icon | `.font(.system(size: isIPad ? 18 : 14))` | `Font.AppTheme.rounded(size: isIPad ? 18 : 14)` |
| `WeatherOverlayView.swift` | `winterParticles` sparkle | `.font(.system(size: CGFloat.random(in: 8...14)))` | `Font.AppTheme.rounded(size: N)` with pre-seeded size |

### 5c. Inline Animation Curves

All curves must use `AnimationConstants.*` tokens. Tokens needed but currently missing are flagged with ★ (see Section 7).

#### `.spring(response:, dampingFraction:)` inline — should be tokens

| File | Inline value | Correct token |
|---|---|---|
| `AllergenPickerStep.swift` | `.spring(response: 0.3, dampingFraction: 0.7)` | `AnimationConstants.springMedium` |
| `CookingMiniGames.swift` | Multiple inline springs | `AnimationConstants.springMedium` / `AnimationConstants.springQuick` |
| `FamilySetupView.swift` | `.spring(response: 0.2, dampingFraction: 0.3)` (PIN shake) | ★ `AnimationConstants.pinShake` |
| `FamilySetupView.swift` | `.spring(response: 0.3, dampingFraction: 0.7)` (step reveal) | `AnimationConstants.springMedium` |
| `GameState.swift` | `.withAnimation(.spring())` bare ×2 | `AnimationConstants.springMedium` |
| `InsulinTetrisView.swift` | `.spring(response: 0.4, dampingFraction: 0.6)` | `AnimationConstants.springMedium` |
| `MigrationPINSetupView.swift` | `.spring(response: 0.2, dampingFraction: 0.3)` (PIN shake) | ★ `AnimationConstants.pinShake` |
| `PantryInfoView.swift` | `.spring(response: 0.4, dampingFraction: 0.6)` ×2 | `AnimationConstants.springMedium` |
| `ParentPINEntryView.swift` | `.spring(response: 0.2, dampingFraction: 0.3)` (PIN shake) | ★ `AnimationConstants.pinShake` |
| `PipAnimations.swift` | `.spring(response: 0.5, dampingFraction: 0.6)` (pose change) | `AnimationConstants.springMedium` |
| `PipAnimations.swift` | `.spring(response: 0.4, dampingFraction: 0.6)` (pose settle) | `AnimationConstants.springMedium` |
| `PipTestView.swift` | `.spring(response: 0.3, dampingFraction: 0.7)` | `AnimationConstants.springMedium` |
| `PlotView.swift` | `.spring(response: 0.3)` / `.spring(response: 0.4)` | `AnimationConstants.springMedium` |
| `SeedInfoView.swift` | `.spring(response: 0.4, dampingFraction: 0.6)` ×3 | `AnimationConstants.springMedium` |
| `SeedInfoView.swift` | `.spring(response: 0.3, dampingFraction: 0.7)` (paintbrush toggle) | `AnimationConstants.springMedium` |
| `SplitScreenVersusView.swift` | `.spring(response: 0.2)` / `.spring(response: 0.3)` (food spawn) | `AnimationConstants.springQuick` / `AnimationConstants.springMedium` |

#### `.easeInOut(duration:).repeatForever()` — the "float loop" pattern (★ missing token)

All idle-bounce / float animations use `.easeInOut(duration: ~1.2–1.5).repeatForever(autoreverses: true)`. No token exists. Four files:

| File | Location | Inline value |
|---|---|---|
| `BackgroundView.swift` | Floating cloud | `.easeInOut(duration: 4).repeatForever(...)` |
| `GardenView.swift` | Pip idle bounce | `.easeInOut(duration: 1.0).repeatForever(...)` |
| `PipAnimations.swift` | `PipCharacterView.startIdleBounce()` | `.easeInOut(duration: 1.5).repeatForever(...)` |
| `PipTestView.swift` | Breathing ring | `.easeInOut(duration: 1.2).repeatForever(...)` |

Add `AnimationConstants.floatLoop` — see Section 7.

#### `.easeOut(duration:)` / `.easeIn(duration:)` / `.easeInOut(duration:)` one-shots

Too numerous to table exhaustively; representative worst offenders:

| File | Count | Example |
|---|---|---|
| `SeedInfoView.swift` | 5 | `.easeOut(duration: 0.3)`, `.easeOut(duration: 0.15)`, `.easeIn(duration: 0.2)` |
| `PipAnimations.swift` | 4 | `.easeOut(duration: 0.3)`, `.easeIn(duration: 0.2)`, `.easeOut(duration: 1.0)` (SparkleEffect) |
| `MeetPipAnimated.swift` | 4 | `.easeOut(duration: 0.8)` ×2, `.easeIn(duration: 0.5)` ×2 |
| `OnboardingView.swift` | 2 | `.easeOut(duration: 0.8)` ×2 entrance animations |
| `SignInView.swift` | 1 | `.easeOut(duration: 0.8)` entrance |
| `BackgroundView.swift` | 1 | `.easeInOut(duration: 4)` (floatLoop candidate) |
| `WeatherOverlayView.swift` | 5 | `.easeInOut(duration: 1.0)` weather switch, `.easeIn(duration: 0.1)` / `.easeOut(duration: 0.2)` lightning flash |

Map all to existing tokens: `AnimationConstants.fadeQuick` (0.15s easeOut), `AnimationConstants.fadeMedium` (0.3s), `AnimationConstants.revealSlow` (0.8s easeOut entrance). Add `AnimationConstants.weatherTransition` for the weather switch.

### 5d. Inline Spacing, Padding, and Frame Dimensions

#### PIN pad layout — triplicated across 3 files

`HStack(spacing: 16)`, `VStack(spacing: 12)`, `HStack(spacing: 20)`, `.frame(width: 75, height: 55)`, `.cornerRadius(12)`, `.spring(response: 0.2, dampingFraction: 0.3)` appear identically in **three** files:

- `ParentPINEntryView.swift` (defines `PINButton` struct but does not export it)
- `FamilySetupView.swift` (reimplements PINButton from scratch)
- `MigrationPINSetupView.swift` (reimplements PINButton from scratch)

Add two tokens: `AppSpacing.pinButtonWidth = 75` and `AppSpacing.pinButtonHeight = 55`. See Section 6 for the component refactor.

#### Tab bar bottom spacer — repeated in 4 files

`Spacer().frame(height: 80)` / `Spacer().frame(height: 100)` / `.padding(.bottom, 100)` as tab-bar clearance. Add `AppSpacing.tabBarClearance` and use it consistently.

| File | Value |
|---|---|
| `PlayLearnView.swift` | `Spacer().frame(height: 80)` |
| `ProfileView.swift` | `Spacer().frame(height: 100)` |
| `RecipeCardExample.swift` | `.padding(.bottom, 100)` |
| `MultiplayerHealthyPicksView.swift` | `.padding(.bottom, 60)` |
| `HealthyChoiceGameView.swift` | `.padding(.bottom, 60)` |

#### "Adult Help" badge — duplicate in 2 files

`.padding(.horizontal, 10)`, `.padding(.vertical, 5)`, `.cornerRadius(10)` — identical badge style in `RecipeCardExample.swift` and `RecipeDetailView.swift`. Replace with `AppSpacing.xs` / `AppSpacing.xxs` / `AppSpacing.pillCornerRadius`.

#### Nutrition fact pill — duplicate in 2 files

`.padding(.horizontal, 12)`, `.padding(.vertical, 6)`, `.cornerRadius(14)` in both `RecipeCardExample.swift` and `RecipeDetailView.swift`. Replace with `AppSpacing.sm` / `AppSpacing.xxs` / `AppSpacing.pillCornerRadius`.

#### `PipVoiceToggleChip` (PipVoice.swift)

`.padding(.horizontal, 10)`, `.padding(.vertical, 6)`, `.cornerRadius(14)` — should match the `HomeStatChip` pattern: `AppSpacing.xs` / `AppSpacing.xxs` / `AppSpacing.smallCornerRadius`.

#### Other inline dimensions

| File | Value | Token |
|---|---|---|
| `PantryInfoView.swift` | `.frame(width: 200, height: 200)` info card image | Add `AppSpacing.infoCardImageSize` or use `AdaptiveCardSize` |
| `PlotView.swift` | `.frame(width: 100, height: 110)` plot tile | `AdaptiveCardSize.plotTile` or new `AppSpacing.plotTileWidth/Height` |
| `PlotView.swift` | `.padding(.horizontal, 8)`, `.padding(.vertical, 3)` "Harvest!" badge | `AppSpacing.xxs` / `AppSpacing.xxxs` (add token) |
| `ProfilePickerView.swift` | `avatarSize: isIPad ? 200 : 80`, `circleSize: isIPad ? 220 : 90`, `cardWidth: isIPad ? 280 : 120` | Use `AdaptiveCardSize` tokens |
| `SeedInfoView.swift` | `.padding(.horizontal, 8)`, `.padding(.vertical, 3)` superpower badge | `AppSpacing.xxs` / add `AppSpacing.xxxs` |
| `SeedInfoView.swift` | `Spacer(minLength: 140)` / `.padding(.top, 60)` | `AppSpacing.xxl` / `AppSpacing.xl` |
| `PipTestView.swift` | `.frame(width: 130, height: 130)` / `120×120` Pip circles | Named constants or `PipSize.large.points` |
| `PipTestView.swift` | `Spacer(minLength: 50)` | `AppSpacing.xl` |
| `WeatherOverlayView.swift` | `SunshineOverlay` `.frame(width: 200, height: 200)` | `AppSpacing.infoCardImageSize` or new `AppSpacing.sunGlowSize` |

---

## 6. [REFACTOR-COMPONENT] — Hand-Rolled Views / Missed Reuse

### 6a. `PINButton` not exported — three files hand-roll the same PIN pad (HIGH)

`PINButton` is defined in `ParentPINEntryView.swift` as a file-private struct. `FamilySetupView.swift` and `MigrationPINSetupView.swift` each re-implement it from scratch including identical spacing, frame sizes, animation, and shake logic.

**Fix:** Move `PINButton` and the PIN grid layout (`pinPadGrid`) to `PipComponents.swift` or a new `PINComponents.swift`, making it `public`/`internal`. All three call sites then reference the same struct. This eliminates three copies of the hardcoded layout values described in §5d.

### 6b. `PipJourneyMessage` duplicates `PipSpeechBubble` (MEDIUM)

**File:** `GlucoseJourneyView.swift`

`PipJourneyMessage` is a local struct with a Pip image, speech bubble background, and text — structurally identical to `PipSpeechBubble` from `PipComponents.swift`. It doesn't use `PipSize`, `PipSpeechBubble`, or `PipHeaderStack`.

**Fix:** Replace `PipJourneyMessage` with `PipSpeechBubble(text: ..., pipSize: .medium)`. If a custom pose is needed, use the `pose:` parameter already on `PipHeaderStack`.

### 6c. Help-streak update logic duplicated (MEDIUM)

**File:** `SiblingGardenView.swift` — `handleHelpAction()`

The consecutive-day streak calculation (check yesterday → increment / same day → no change / different day → reset to 1) is inlined in `handleHelpAction`. This same pattern should appear wherever social help rewards are issued.

**Fix:** Encapsulate in `PlayerData`:
```swift
// PlayerData.swift
func recordHelp() {
    let last = lastHelpDateRaw > 0 ? Date(timeIntervalSince1970: lastHelpDateRaw) : nil
    if let last, Calendar.current.isDate(last, inSameDayAs: Date().addingTimeInterval(-86400)) {
        helpStreak += 1
    } else if last == nil || !Calendar.current.isDateInToday(last!) {
        helpStreak = 1
    }
    helpGivenCount += 1
    lastHelpDateRaw = Date().timeIntervalSince1970
}
```

### 6d. "Adult Help Needed" badge — inline in 2 recipe views (LOW)

`RecipeCardExample.swift` and `RecipeDetailView.swift` each contain an identically-styled "Adult Help Needed" badge (terracotta background, cream text, icon, padding). Extract to a reusable `AdultHelpBadge` view in `PipComponents.swift`.

### 6e. Nutrition fact pill — inline in 2 recipe views (LOW)

Same padding+cornerRadius pill shape in both recipe views. Extract to `NutritionFactPill(text:)` or use a modifier.

### 6f. `AskPipView` typing-indicator bubble (LOW)

The three-dot typing indicator in `AskPipView` is hand-rolled (HStack of circles with staggered opacity animation). It duplicates the spirit of `PipSpeechBubble`. If `PipSpeechBubble` gains a `isLoading: Bool` parameter, this can be consolidated and the animation managed in one place.

---

## 7. Missing Tokens — Recommended Additions to AppTheme

The following values appear in multiple files with no existing token. Add these to `AppTheme.swift` / `AnimationConstants`:

### AnimationConstants

| Token name | Value | Used in |
|---|---|---|
| `floatLoop` | `.easeInOut(duration: 1.5).repeatForever(autoreverses: true)` | `BackgroundView`, `GardenView`, `PipAnimations`, `PipTestView` |
| `pinShake` | `.spring(response: 0.2, dampingFraction: 0.3)` | `ParentPINEntryView`, `FamilySetupView`, `MigrationPINSetupView` |
| `weatherTransition` | `.easeInOut(duration: 1.0)` | `WeatherOverlayView` weather switch |

### Color.AppTheme

| Token name | Value | Used in |
|---|---|---|
| `pureWhite` | `Color(hex: "F7FAFC")` | `AvatarModel` chefHatWhite case |
| `overlay` | `Color.black.opacity(0.4)` | `PipDialogView` modal dim |
| `sunYellow` | `.yellow.opacity(0.5)` (approx) | `WeatherOverlayView` sun glow |
| `rainBlue` | `.blue.opacity(0.4)` | `WeatherOverlayView` rain / storm drops |
| `autumnBrown` | `Color(hex: "8B4513")` | `WeatherOverlayView` fall leaves |
| `frostBlue` | `Color(hex: "E3F2FD")` | `WeatherOverlayView` winter sparkles |

### AppSpacing

| Token name | Value | Used in |
|---|---|---|
| `pinButtonWidth` | `75` | PIN pads in 3 files |
| `pinButtonHeight` | `55` | PIN pads in 3 files |
| `tabBarClearance` | `100` | Bottom spacers in 5 files |
| `infoCardImageSize` | `200` | `PantryInfoView`, `WeatherOverlayView` |

---

## 8. Clean Scans

The following files passed both focus areas with no issues:

**Architecture / models (reference quality):**
- `SessionManager.swift` — `withAnimation(AnimationConstants.fadeMedium)` on every route transition; Timer with `Task { @MainActor [weak self] in }` play-time tracker. ✓
- `PlayerData.swift` — Pure `@Model`, all CloudKit-safe defaults, no UI values. ✓
- `UserProfile.swift` — Pure `@Model`, UUID-based links, no UI values. ✓
- `FamilyProfile.swift` — UUID-based member queries, no UI values. ✓
- `SubscriptionManager.swift` — `@MainActor`, StoreKit 2 async/await, `Task.detached` listener. ✓
- `USDAFoodService.swift` — `await MainActor.run` for cache, `withTaskGroup` batch, no UI values. ✓
- `SeededRandomGenerator.swift` — Pure math. ✓
- `WorkerClient.swift` — Pure config; Worker URL correctly noted as non-secret. ✓
- `PINKeychain.swift` — Correct Keychain wrapper. ✓

**Service / AI layer:**
- `PipAIService.swift` — Rate limiting, `Task { @MainActor in }` for UI updates, `defer` pattern. ✓
- `PipFoundationModelService.swift` — `#if canImport(FoundationModels)`, actor isolation, `@Generable`. ✓
- `PipStaticResponses.swift` — Pure data, no UI. ✓
- `AmbientAudioPlayer.swift` — `Task`-based crossfade loops. ✓

**View layer (reference implementations):**
- `PaywallView.swift` — `.task {}` for products, `TexturedButtonStyle`, `PipWavingAnimatedView`. ✓
- `PipGameAnimationView.swift` — Timer + `Task { @MainActor in }`, `AnimationConstants.gameFPS`. ✓
- `VoicePickerView.swift` — All AppTheme / AppSpacing tokens, `PipHeaderStack`, `cardCornerRadius`. ✓
- `VideoPlayerView.swift` — `AVPlayerLayer` without controls; AppTheme colors. ✓
- `ParentDashboardView.swift` — AppTheme throughout. ✓
- `MorphTransition.swift` — Pure `matchedGeometryEffect` helper. ✓

**Infrastructure:**
- `ODRManager.swift` — Task-based async ODR. ✓
- `MultiplayerManager.swift` — Clean GameKit wrapper. ✓
- `NearbyMultiplayerManager.swift` — Clean MultipeerConnectivity wrapper. ✓
- `AppAttestService.swift` — Correct Secure Enclave / App Attest flow. ✓
- `AssetPackController.swift`, `AssetPackImage.swift` — ODR asset helpers. ✓
- `CloudKeyManager.swift` — Clean CloudKit key helper. ✓
- `AuthManager.swift` — Sign in with Apple, `@MainActor`. ✓
- `ElevenLabsVoiceService.swift` — `async/await` TTS, no UI values. ✓

**Dev tool (exempt from design system rules):**
- `SceneEditor.swift` — Debug-only scene layout tool; `Color.red`, `Color.cyan`, `.system(size:)` are intentional. ✓

---

*Reviewed by automated weekly pass — 2026-05-10*
*Source files unchanged. All recommendations require human implementation.*
