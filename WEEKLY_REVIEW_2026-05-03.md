# Weekly Code Review — 2026-05-03
**Project:** Pip's Kitchen Garden (ChefAcademy)  
**Scope:** All 87 Swift source files read in full (STEP 0 complete)  
**Focus 1:** Stale UI State Bugs  
**Focus 2:** Hardcoded Values + Missed Component Reuse  

---

## TL;DR

| Category | Count | Highest Severity |
|---|---|---|
| Stale UI: Timer → @State without MainActor | 19 timer instances across 11 files | P0 — crashes / purple-thread warnings |
| Stale UI: `UIScreen.main.bounds` deprecated | 2 call sites | P1 |
| Stale UI: Recursive uncancelled asyncAfter | 1 (StormOverlay) | P1 — memory leak |
| Stale UI: Uncancelled asyncAfter | ~18 call sites | P2 |
| Hardcoded: Animation curves/durations | 60+ inline springs/eases | P1 |
| Hardcoded: Pip sizes not using PipSize enum | 12+ call sites | P2 |
| Hardcoded: Fonts using `.system(size:)` | 20+ call sites | P2 |
| Hardcoded: isIPad branches with raw sizes | 4 files | P2 |
| Hardcoded: Colors not in AppTheme | 15+ call sites | P2 |
| Component duplication | 4 clusters | P3 |

**Gold-standard files (zero violations):** `PaywallView`, `SubscriptionManager`, `PipGameAnimationView`, `InsulinTetrisView`, `KitchenView`, `WorkerClient`, `PipFoundationModelService`.

---

## FOCUS 1 — STALE UI STATE BUGS

### F1-1 [P0] Timer Closures Mutating @State Without @MainActor Hop

**Pattern:** `Timer.scheduledTimer(withTimeInterval: X, repeats: true) { _ in someStateVar = ... }`  
**Risk:** Timer callbacks fire on an unspecified thread. SwiftUI requires all `@State`/`@Published` writes to happen on the main actor. The compiler does NOT warn about this. On devices with elevated thread contention (ProMotion displays, background downloads) this surfaces as purple "Main Thread Checker" violations and visual glitches: frozen physics, dropped spawns, waterProgress bar stuck.

**Gold standard (from `PipGameAnimationView.swift`):**
```swift
timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { t in
    Task { @MainActor in
        // safe to mutate @State here
    }
}
```

**Violations by file:**

| File | Timer Count | @State vars affected | Cleanup |
|---|---|---|---|
| `CookingMiniGames.swift` | 4 | `progress`, `heatLevel`, `timeLeft`, `animFrame` | ✓ `.onDisappear` |
| `FamilySetupView.swift` | 2 | `frameIndex` (x2 in FamilyAvatarStep) | ✓ `.onDisappear` |
| `HealthyChoiceGameView.swift` | 2 | `flyingFoods`, spawn sequence | ✓ `cleanupGame()` |
| `LocalVersusView.swift` | 2 | `p1Foods`, `p2Foods` | ✓ `cleanup()` |
| `MultiplayerHealthyPicksView.swift` | 2 | `localFoods`, `remoteFoods` | ✓ `cleanup()` |
| `NearbyVersusView.swift` | 2 | `flyingFoods`, spawn sequence | ✓ `cleanupGame()` |
| `OnboardingView.swift` (GenderCard) | 1 | `frameIndex` | ✓ `.onDisappear` |
| `PipAnimations.swift` (OneShotFrameAnimationView) | 1 | `currentFrame` | ✓ `.onDisappear` |
| `PipAnimations.swift` (AvatarAnimator) | 1 | `frameIndex` (via `[weak self]` — loses actor isolation) | ✓ `deinit` |
| `PlotView.swift` | 1 | `waterProgress` | ✗ **No `.onDisappear` cleanup** |
| `SessionManager.swift` | 1 | `profile.totalPlayTimeSeconds` via non-@MainActor class | ✓ `stopPlayTimeTracking()` |
| `SplitScreenVersusView.swift` | 2 | `p1Foods`, `p2Foods`, `countdownValue` | ✓ `cleanup()` |

**PlotView — missing cleanup (P0):**  
`waterTimer` at line ~403 is assigned but `PlotView` has no `.onDisappear { waterTimer?.invalidate() }`. If the user dismisses the plot sheet while holding the water button, the timer fires indefinitely against a deallocated view's @State, causing an EXC_BAD_ACCESS or at minimum a purple warning.

**AvatarAnimator — actor isolation gap:**  
```swift
// PipAnimations.swift — AvatarAnimator
timer = Timer.scheduledTimer(...) { [weak self] _ in
    self?.frameIndex = next   // [weak self] breaks @MainActor isolation
}
```
The class is declared `@MainActor` but `[weak self]` in a Timer callback creates an unprotected hop. Correct fix:
```swift
timer = Timer.scheduledTimer(...) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.frameIndex = next
    }
}
```

**Fix template for all 19 instances:**
```swift
timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
    Task { @MainActor [weak self] in
        guard let self else { return }
        // mutate @State / @Published here
    }
}
```

---

### F1-2 [P1] Physics Loops via Timer — Should Use TimelineView

Five Healthy Picks game variants all drive their 60 fps physics loop with `Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, ...)`:

- `HealthyChoiceGameView.swift`
- `LocalVersusView.swift`
- `MultiplayerHealthyPicksView.swift`
- `NearbyVersusView.swift`
- `SplitScreenVersusView.swift`

`WeatherOverlayView` (RainOverlay, SnowOverlay, StormOverlay) and `InsulinTetrisView` correctly use `TimelineView(.animation)` with delta-time, making them frame-rate independent.

The Timer-based physics tie game speed to the timer fire interval, not actual elapsed time. On 120 Hz ProMotion devices the physics runs at only half the display rate (visible stutter); a CPU spike causes food to "teleport" downward. `WeatherOverlayView`'s `RainParticle.speed` is in "points per second" — the Timer-based games should adopt the same delta-time model.

**Recommended refactor:**
```swift
// Replace the 60fps gameTimer with:
TimelineView(.animation) { ctx in
    let dt = min(ctx.date.timeIntervalSince(lastFrame), 0.05)
    Canvas { ... }
    .onChange(of: ctx.date) { _, newDate in
        updatePhysics(dt: dt)
        lastFrame = newDate
    }
}
```

---

### F1-3 [P1] Recursive Uncancelled asyncAfter — StormOverlay

`WeatherOverlayView.swift`, `StormOverlay.triggerLightning()`:

```swift
private func triggerLightning() {
    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 5...10)) {
        withAnimation(.easeIn(duration: 0.1)) { flashOpacity = 0.3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0 }
        }
        triggerLightning()   // ← recursive: never stops
    }
}
```

When the `StormOverlay` is removed from the view hierarchy (weather changes to sunny), all the pending closures are still in the queue, still calling `triggerLightning()`, still mutating `flashOpacity`. Replace with a `Task` that can be stored and cancelled in `.onDisappear`:

```swift
@State private var lightningTask: Task<Void, Never>?

.onAppear { lightningTask = Task { await lightningLoop() } }
.onDisappear { lightningTask?.cancel() }

private func lightningLoop() async {
    while !Task.isCancelled {
        let delay = Double.random(in: 5...10)
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.1)) { flashOpacity = 0.3 }
        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 0 }
    }
}
```

---

### F1-4 [P2] Uncancelled DispatchQueue.main.asyncAfter

~18 call sites across 10+ files fire delayed closures that are never stored for cancellation. If the view is dismissed before the deadline, the closure runs against deallocated state. While this rarely crashes, it generates "updating state of a dismissed view" runtime warnings and shows stale animations.

**Files affected (non-exhaustive):**

| File | asyncAfter delays | Risk |
|---|---|---|
| `PantryInfoView.swift` | `+1.2s` (coin reward, x2) | coin toast on dismissed view |
| `PipAnimations.swift` (PipCharacterView) | `+0.5s`, `+1.0s`, `+2.0s` | bubble/reaction on dismissed Pip |
| `PipAnimations.swift` (PipWithDialogue) | `+0.5s`, `+1.0s` | dialogue sequence |
| `PlantingSheet.swift` | `+0.3s` | NPC morph timing |
| `PlotView.swift` | multiple | plot animation |
| `SeedInfoView.swift` | `+0.8s`, `+0.2s`, `+1.2s` (x3) | coin toast + tip reveal |
| `SiblingGardenView.swift` | `+2.5s` | help reward toast |
| `SiblingProfileView.swift` | `+2.5s` | gift toast |
| `WeatherOverlayView.swift` (StormOverlay) | recursive | see F1-3 above |

**Pattern to adopt:**  
Store the `Task` and cancel on `.onDisappear`, same as `KitchenView`'s `cancelCookingTasks()` pattern:
```swift
@State private var toastTask: Task<Void, Never>?

toastTask?.cancel()
toastTask = Task { @MainActor in
    try? await Task.sleep(for: .seconds(1.2))
    guard !Task.isCancelled else { return }
    withAnimation { showCoinReward = nil }
}
```

---

### F1-5 [P1] UIScreen.main.bounds (Deprecated iOS 16)

Two physics-loop views read screen geometry from the deprecated UIKit API instead of using the `GeometryReader` that is already in scope:

- `NearbyVersusView.swift` line ~556: `let screenSize = UIScreen.main.bounds.size`
- `SplitScreenVersusView.swift` line ~584: `let screenSize = UIScreen.main.bounds.size`

Both views already receive `geo: GeometryProxy` from an enclosing `GeometryReader`. Replace:
```swift
// Before
let screenSize = UIScreen.main.bounds.size

// After — geo is already in scope
let screenSize = geo.size
```

---

## FOCUS 2 — HARDCODED VALUES + MISSED COMPONENT REUSE

**Rule (non-negotiable from CLAUDE.md):** Zero inline hardcoded colors, fonts, dimensions, or animation curves. All must map to `AppTheme` / `AppSpacing` / `AnimationConstants` / `AdaptiveCardSize` / `PipSize` tokens.

---

### F2-1 [P1] BouncyButtonStyle Uses Hardcoded Spring

`PipAnimations.swift`, `BouncyButtonStyle`:
```swift
// Current
.scaleEffect(configuration.isPressed ? 0.9 : 1.0)
.animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
```

`BouncyButtonStyle` is used across the entire app (CookingMiniGames, PlayLearnView, SplitScreenVersusView, FarmShopView, and others). This one-line fix propagates to every usage:
```swift
.animation(AnimationConstants.springQuick, value: configuration.isPressed)
```

---

### F2-2 [P1] Hardcoded Animation Curves/Durations (60+ instances)

Every inline `.spring(response:dampingFraction:)` and `.easeIn/Out(duration:)` bypasses `AnimationConstants` and makes future-wide tuning impossible.

**Mapping to use:**

| Hardcoded value | Correct token |
|---|---|
| `.spring(response: 0.3, dampingFraction: 0.6)` | `AnimationConstants.springQuick` |
| `.spring(response: 0.4, dampingFraction: 0.7)` | `AnimationConstants.springMedium` |
| `.spring(response: 0.5, dampingFraction: 0.7)` | `AnimationConstants.springMedium` |
| `.spring(response: 0.6, dampingFraction: 0.7)` | `AnimationConstants.springSlow` |
| `.spring(response: 0.4, dampingFraction: 0.6)` | `AnimationConstants.springBouncy` |
| `.spring(response: 0.3, dampingFraction: 0.4)` | `AnimationConstants.bouncyPressScale` context → `AnimationConstants.springBouncy` |
| `.easeOut(duration: 0.3)` | `AnimationConstants.fadeQuick` |
| `.easeOut(duration: 0.5)` | `AnimationConstants.fadeMedium` |
| `.easeOut(duration: 0.8)` | `AnimationConstants.revealSlow` |
| `.easeInOut(duration: 1.0).repeatForever(autoreverses: true)` | `AnimationConstants.pipTransition.repeatForever(...)` |

**Most-impacted files (files with 5+ violations):**
`PipAnimations.swift`, `SeedInfoView.swift`, `PantryInfoView.swift`, `PlotView.swift`, `SplitScreenVersusView.swift`, `NearbyVersusView.swift`, `PipCharacterView` (within PipAnimations), `WeatherOverlayView.swift`.

---

### F2-3 [P2] Pip Sizes Not Using PipSize Enum (12+ call sites)

`PipSize` enum provides `.compact` (40pt), `.medium` (80pt), `.large` (120pt), `.hero` (160pt), `.custom(CGFloat)`. All raw numeric `size:` arguments should resolve through this enum.

| File | Hardcoded size | Correct token |
|---|---|---|
| `ODRManager.swift` | `PipWavingAnimatedView(size: 120)` | `.large` |
| `AssetPackController.swift` | `PipWavingAnimatedView(size: 120)` | `.large` |
| `NearbyVersusView.swift` | `PipWavingAnimatedView(size: 120)`, `size: 100` | `.large`, `.custom(100)` |
| `PipDialogView.swift` | `PipWavingAnimatedView(size: 120)` | `.large` |
| `PlayLearnView.swift` | `size: 60`, `size: 120` | `.custom(60)`, `.large` |
| `SignInView.swift` | `PipWavingAnimatedView(size: 160)` | `.hero` |
| `SiblingGardenView.swift` | `PipWavingAnimatedView(size: 36)` | `.custom(36)` or `.compact` |
| `SiblingProfileView.swift` | `PipWavingAnimatedView(size: 36)` | `.custom(36)` |
| `SplitScreenVersusView.swift` | `size: 80`, `size: 120` | `.medium`, `.large` |
| `PipWithDialogue` (PipAnimations) | `var pipSize: CGFloat = 180` | `.custom(180)` default |
| `SplitScreenVersusView` gameMiniPip | `size: 60` | `.custom(60)` |

---

### F2-4 [P2] Fonts Using .system(size:) Instead of .AppTheme.rounded(size:)

`AppTheme.Font` provides `rounded(size:weight:)` as the app-wide font factory. Using `.system(size:)` bypasses the rounded design system.

**Critical call sites:**

| File | Location | Fix |
|---|---|---|
| `PipVoice.swift` (`SpeakerButton`) | `.font(.system(size: size))` | `.font(.AppTheme.rounded(size: size))` |
| `ProfilePickerView.swift` | `.system(size: 40, weight: .bold, design: .rounded)` heading | `.AppTheme.largeTitle` |
| `ProfilePickerView.swift` | `.system(size: 22, ...)` add-button | `.AppTheme.title3` or `.headline` |
| `ProfileCard` (ProfilePickerView) | `.system(size: isIPad ? X : Y)` for crown/lock/clock | `.AppTheme.caption` / `.captionLarge` |
| `WeatherBadge` (`WeatherOverlayView`) | `.font(.system(size: isIPad ? 18 : 14))` | `.AppTheme.caption` (+ responsive font via AdaptiveLayout) |
| `SeasonalOverlayView` (winterParticles) | `.font(.system(size: CGFloat.random(in: 8...14)))` | `.AppTheme.rounded(size: CGFloat.random(in: 8...14))` |
| `CookingMiniGames` (AssembleMiniGame) | `.font(.system(size: ...))` for emoji labels | `.AppTheme.rounded(size:)` |
| `PlotView.swift` | `.font(.system(size: ...))` for plant label array | `.AppTheme.rounded(size:)` |

Note: `SceneEditor.swift` intentionally uses `.system(.monospaced)` for coordinate readouts — this is a dev-only tool and is explicitly acceptable.

---

### F2-5 [P2] Hardcoded Colors Not in AppTheme

| Call site | Hardcoded value | Should use |
|---|---|---|
| `AvatarModel.swift` | `Color(hex: "#...")` for outfit colors | Add tint tokens to AppTheme or AvatarModel.OutfitColor enum |
| `GardenWeatherService.swift` | `.yellow`, `.blue`, `.gray`, `.orange` for weather icon colors | Extend `GardenWeather.iconColor` to return AppTheme tokens |
| `SeedInfoView.swift`, `PipDialogView.swift` | `shadow(color: .black.opacity(0.2/0.15))` | `Color.AppTheme.sepia.opacity(0.15)` (matches existing card shadows) |
| `RecipeDetailView.swift` | `.foregroundColor(.white)` (allergen banner) | `Color.AppTheme.cream` |
| `WeatherOverlayView.swift` (fallParticles) | `Color(hex: "8B4513")`, `Color(hex: "DAA520")` | `Color.AppTheme.sepia`, `Color.AppTheme.goldenWheat` |
| `WeatherOverlayView.swift` (winterParticles) | `Color(hex: "E3F2FD")` | `Color.AppTheme.warmCream.opacity(0.5)` |
| `WeatherOverlayView.swift` (rain/snow Canvas) | `.blue.opacity(0.4)`, `.white.opacity(0.7)` | Weather-specific: acceptable as artistic particle colors, document intent |
| `CharacterWalkingView.swift` | `Color.black.opacity(0.15)` shadow | `Color.AppTheme.sepia.opacity(0.12)` |

---

### F2-6 [P2] Hardcoded Dimensions — Frame and Spacing

**Pattern:** Inline `frame(width: X, height: X)` for circles and images; `VStack(spacing: N)` with raw integers; `Spacer(minLength: N)` for tab-bar clearance.

**High-frequency violations:**

| File | Value | Should use |
|---|---|---|
| `PlotView.swift` | Circle frames 70/80/85pt, image frames 50/65pt | `AdaptiveCardSize.gardenPlot(for:)` or new token |
| `AvatarCreatorView.swift` | Circle 220pt, image 200pt, circle 60pt, circle 50pt | `AdaptiveCardSize` avatar preview tokens |
| `ProfilePickerView.swift` / `ProfileCard` | `isIPad ? 200 : 80` avatar, `isIPad ? 90 : 80` circle | `AdaptiveCardSize.profileAvatar(for:)` (new token) |
| `PantryInfoView.swift` | Image 200×200 | `AdaptiveCardSize` item image token |
| `SiblingProfileView.swift` | Image 120×120 avatar, 50×50 veggie | `PipSize.large` → 120, `AdaptiveCardSize` item thumb |
| `SplitScreenVersusView.swift` | Circle 60pt, image 50pt | `AdaptiveCardSize` profile avatar |
| `RecipeDetailView.swift` | Hero image `height: 180`, ingredient icons 28/24pt | `AdaptiveCardSize.recipeHero(for:)` |
| Multiple files | `Spacer(minLength: 140)` / `100` / `80` tab-bar gap | `AppSpacing.tabBarClearance` (new named constant) |
| Multiple files | `.padding(.top, 60)` close-button clearance | `AppSpacing.safeAreaTop` or `.padding(.top, AppSpacing.xxl + AppSpacing.md)` |

---

### F2-7 [P2] PIN Pad Hardcodes Duplicated in Two Files

`ParentPINEntryView.swift` and `MigrationPINSetupView.swift` both hardcode identical values:
```swift
// Appears identically in BOTH files:
Button.frame(width: 75, height: 55)   // digit button
Circle().frame(width: 20, height: 20) // PIN dot indicator
HStack(spacing: 16)                   // dot row spacing
```

Extract to a `PINPadMetrics` namespace or private `struct` in a shared location:
```swift
enum PINPadMetrics {
    static let buttonSize = CGSize(width: 75, height: 55)
    static let dotSize: CGFloat = 20
    static let dotSpacing: CGFloat = AppSpacing.md
}
```

---

### F2-8 [P2] isIPad Branches With Raw Pixel Values

Four files use `DeviceInfo.isIPad` or computed `isIPad` var with hardcoded numeric alternatives instead of `AdaptiveCardSize` tokens:

| File | Hardcoded branch | Recommended |
|---|---|---|
| `ProfilePickerView.swift` | `isIPad ? 280 : 120` card width; `isIPad ? 200 : 80` avatar | Add `AdaptiveCardSize.profileCard(for:)` token |
| `PlantingSheet.swift` | `isIPad ? 120 : 80` seed; `isIPad ? 300 : 200` NPC | Add `AdaptiveCardSize.plantingNPC(for:)` token |
| `WeatherBadge` (WeatherOverlayView) | `isIPad ? 18 : 14` font size | `.AppTheme.captionLarge` (14pt) on both — badge is always small |
| `SiblingProfileView.swift` (minor) | `Image().frame(width: 120, ...)` fixed but not adaptive | `AdaptiveCardSize.siblingAvatar(for:)` |

---

### F2-9 [P3] Component Duplication

**Cluster 1 — Pip Speech Bubble variants:**  
`PipJourneyMessage` (GlucoseJourneyView), `PipMessageAnimated` (HomeAnimated), and inline Pip-image+bubble combos in AskPipView and MeetPipViews all independently implement the Pip-avatar-left / text-card-right layout that `PipSpeechBubble` already provides. All call sites should migrate to `PipSpeechBubble(message:pose:size:speakOnAppear:)`.

**Cluster 2 — PlotButtonStyle ≈ BouncyButtonStyle:**  
`PlotView.swift` defines `PlotButtonStyle` with `.spring(response: 0.3, dampingFraction: 0.4)` and `scaleEffect(0.9)`. This is identical to `BouncyButtonStyle` (same scale, overlapping spring). Remove `PlotButtonStyle` and use `BouncyButtonStyle()` everywhere.

**Cluster 3 — Pip waving header:**  
`ODRManager`, `AssetPackController`, and `VoicePickerView` each independently show `PipWavingAnimatedView` + title + subtitle in a VStack. `PipHeaderStack` already handles this — all three should switch to `PipHeaderStack(title:subtitle:pose:size:)`.

**Cluster 4 — Coin reward toast:**  
`PantryInfoView`, `SeedInfoView`, and `GlucoseJourneyView` all implement an identical floating `+N 🪙` coin reward animation (ZStack, top-centered Text, spring entrance, asyncAfter dismissal). Extract to a `CoinRewardToast(amount:)` view modifier or overlay that also handles its own cancellable `Task`.

---

### F2-10 [P3] Misc Missing Token Usage

| Location | Hardcoded | Token exists |
|---|---|---|
| `SiblingProfileView.swift` line ~60 | `.stroke(lineWidth: 3)` | `AppSpacing.strokeBold` (= 3) |
| `SplitScreenVersusView.swift` line ~537 | `.stroke(lineWidth: 1.5)` | `AppSpacing.strokeMedium` (= 2) or `AppSpacing.strokeThin` (= 1) |
| `RecipeDetailView.swift` inline corners | `.cornerRadius(10)` | `AppSpacing.smallCornerRadius` (= 12) |
| `VoicePickerView.swift` (VoiceOptionCard) | `Circle().frame(24, 24)` | `AppSpacing.md + AppSpacing.xs` context → add `PINPadMetrics` or local const |
| `PipVoice.swift` (PipVoiceToggleChip) | `.padding(.horizontal, 10).padding(.vertical, 6).cornerRadius(14)` | `AppSpacing.xs + 2`, `AppSpacing.xs`, `AppSpacing.cardCornerRadius - 2` → define as chip style |
| `SeedInfoView.swift` brush button | `Button.frame(42, 42)` | `AppSpacing.tapTarget` (new 44pt constant — Apple HIG minimum) |

---

## POSITIVE PATTERNS — DO NOT CHANGE

The following files and patterns are exemplary and should serve as templates for fixing the issues above.

### Timer/Animation Patterns
- **`KitchenView.swift`** — `cookingTasks: [Task<Void, Never>]` with `cancelCookingTasks()` in `.onDisappear`. Gold standard for multi-step async task management.
- **`InsulinTetrisView.swift`** — `TimelineView(.animation)` for 60 fps physics. Frame-rate independent, MainActor-safe.
- **`PipGameAnimationView.swift`** — `Task { @MainActor in }` inside every Timer callback. The correct pattern for the ~11 files that need it.
- **`CharacterWalkingView.swift` / `WalkEngine`** — `TimelineView` + delta-time for walking animation. No `Timer`, no frame-rate dependency.
- **`WeatherOverlayView.swift`** (RainOverlay, SnowOverlay) — `TimelineView(.animation)` with `min(dt, 0.1)` cap to prevent physics jumps after backgrounding.
- **`GardenView.swift`** — `.task { }` for async weather/garden operations. Auto-cancelled on view disappear.
- **`NearbyMultiplayerManager.swift`** — countdown timer uses `DispatchQueue.main.async` wrapper + proper `invalidate()` in `disconnect()`.

### Zero-Hardcode Files
`PaywallView.swift` (explicitly documented "Zero hardcoded values"), `SubscriptionManager.swift`, `WorkerClient.swift`, `PipFoundationModelService.swift`, `SeededRandomGenerator.swift`, `USDAFoodService.swift`, `SessionManager.swift` (minor timer thread concern aside), `AppAttestService.swift`, `AuthManager.swift`, `PINKeychain.swift`, `PlayerData.swift`, `UserProfile.swift`, `FamilyProfile.swift`.

### Architecture
- **`SessionManager.swift`** — `pickBestFamily()` CloudKit dedup with Apple-ID matching and orphan cleanup is well-structured.
- **`PipFoundationModelService.swift`** — 12-tool Foundation Models toolset, `@MainActor`-isolated service, clean async/await patterns.
- **`SubscriptionManager.swift`** — `@MainActor` class, `Task.detached` transaction listener with `deinit` cancellation, cached state for cold-launch UX.
- **`SiblingGardenView.swift` + `SiblingProfileView.swift`** — gift/help social graph written cleanly against SwiftData UUID-based model.

---

## MISSING TOKENS (Proposed Additions to AppTheme/AppSpacing)

These values appear hardcoded repeatedly and would benefit from a named constant:

```swift
// AppSpacing additions
static let tabBarClearance: CGFloat = 100   // bottom Spacer clearing tab bar
static let closeButtonTop: CGFloat = 60     // top padding for X button overlay
static let tapTarget: CGFloat = 44          // Apple HIG minimum touch target

// AdaptiveCardSize additions (for adaptive-layout-engineer)
// profileAvatar(for:)  — 80pt iPhone, 200pt iPad
// profileCard(for:)    — 120pt iPhone, 280pt iPad
// plantingNPC(for:)    — 200pt iPhone, 300pt iPad
// recipeHero(for:)     — height 160pt iPhone, 220pt iPad
// siblingAvatar(for:)  — 80pt iPhone, 120pt iPad
```

---

## FILE INVENTORY (All 87 files read)

`AdaptiveLayout.swift`, `AllergenEditorSheet.swift`, `Allergen.swift`, `AmbientAudioPlayer.swift`, `AppAttestService.swift`, `AppTheme.swift`, `AskPipView.swift`, `AssetPackController.swift`, `AssetPackImage.swift`, `AuthManager.swift`, `AvatarCreatorView.swift`, `AvatarModel.swift`, `BackgroundView.swift`, `BodyBuddyView.swift`, `CharacterWalkingView.swift`, `ChefAcademyApp.swift`, `ChopMiniGame.swift`, `CloudKeyManager.swift`, `ContentView.swift`, `CookingCompletionView.swift`, `CookingMiniGames.swift`, `ElevenLabsVoiceService.swift`, `FamilyProfile.swift`, `FamilySetupView.swift`, `FarmShopView.swift`, `GameCenterMatchmakerView.swift`, `GameCenterService.swift`, `GameState.swift`, `GardenHubView.swift`, `GardenView.swift`, `GardenWeatherService.swift`, `GlucoseJourneyView.swift`, `HealthyChoiceGameView.swift`, `HomeAnimated.swift`, `InsulinTetrisView.swift`, `KitchenView.swift`, `LocalVersusView.swift`, `MeetPipAnimated.swift`, `MeetPipViews.swift`, `MigrationPINSetupView.swift`, `MorphTransition.swift`, `MultiplayerHealthyPicksView.swift`, `MultiplayerManager.swift`, `NearbyMultiplayerManager.swift`, `NearbyVersusView.swift`, `ODRManager.swift`, `OnboardingView.swift`, `PINKeychain.swift`, `PantryInfoView.swift`, `ParentDashboardView.swift`, `ParentPINEntryView.swift`, `PaywallView.swift`, `PipAIService.swift`, `PipAnimations.swift`, `PipComponents.swift`, `PipDialogView.swift`, `PipFoundationModelService.swift`, `PipGameAnimationView.swift`, `PipStaticResponses.swift`, `PipTestView.swift`, `PipVoice.swift`, `PlantingSheet.swift`, `PlayLearnView.swift`, `PlayerData.swift`, `PlotView.swift`, `ProfilePickerView.swift`, `ProfileView.swift`, `RecipeCardExample.swift`, `RecipeDetailView.swift`, `SceneEditor.swift`, `SeedInfoView.swift`, `SeededRandomGenerator.swift`, `SessionManager.swift`, `SiblingGardenView.swift`, `SiblingProfileView.swift`, `SignInView.swift`, `SplitScreenVersusView.swift`, `SubscriptionManager.swift`, `USDAFoodService.swift`, `UserProfile.swift`, `VideoPlayerView.swift`, `VoicePickerView.swift`, `WeatherOverlayView.swift`, `WorkerClient.swift`

---

*Review generated by Claude Code (claude-sonnet-4-6) — 2026-05-03*  
*All 87 Swift source files read in full before analysis.*
