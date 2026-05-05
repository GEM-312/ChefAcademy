# Weekly Code Review — 2026-05-05

**Reviewer:** Claude Code (automated pass)
**Scope:** All 87 `.swift` files under `ChefAcademy/`
**Focus 1:** Stale UI State Bugs (Timer, asyncAfter, background-queue mutations)
**Focus 2:** Hardcoded Values + Missed Component Reuse

---

## FOCUS 1 — STALE UI STATE BUGS

### 🔴 P0 — Critical: `Timer.scheduledTimer` at 60fps mutating `@State` directly

**Five game views share the identical anti-pattern.** The timers fire on the RunLoop even when the app is backgrounded, a sheet is covering the view, or the device is charging. Every tick unconditionally mutates `@State` properties (`flyingFoods`, `round`, `p1Bad`, etc.) from outside SwiftUI's rendering pipeline.

The **correct pattern already exists** in this codebase — `InsulinTetrisView.swift` and `WalkingPipView` both use `TimelineView(.animation)` with delta-time, which participates in SwiftUI's rendering lifecycle and pauses automatically when the view is off-screen.

#### Affected files

| File | Timer(s) | Rate |
|------|----------|------|
| `HealthyChoiceGameView.swift` | `gameTimer` (physics) + `spawnTimer` | 60 fps + interval |
| `LocalVersusView.swift` (`LocalVersusGameView`) | `gameTimer` + `spawnTimer` | 60 fps + interval |
| `MultiplayerHealthyPicksView.swift` | `gameTimer` + `spawnTimer` | 60 fps + interval |
| `NearbyVersusView.swift` | `gameTimer` + `spawnTimer` | 60 fps + interval |
| `SplitScreenVersusView.swift` | `gameTimer` + `spawnTimer` | 60 fps + interval |

#### Current (broken) pattern
```swift
// ❌ — fires whether or not the view is visible
gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
    for i in flyingFoods.indices { flyingFoods[i].y += gravity }
    // ...mutates @State from a RunLoop callback
}
spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
    spawnNextFood()   // also mutates @State
}
```

#### Correct pattern (already in InsulinTetrisView.swift)
```swift
// ✓ — pauses when off-screen, delta-time prevents drift
TimelineView(.animation) { timeline in
    let dt = min(timeline.date.timeIntervalSince(lastUpdate), 0.05)
    gameCanvas(deltaTime: dt)
        .onChange(of: timeline.date) { _, now in
            lastUpdate = now
            updatePhysics(dt: dt)
        }
}
```

---

### 🔴 P0 — Critical: `Timer.scheduledTimer` at 20fps in `PlotView.swift` watering mechanic

`PlotView.startWatering()` creates a `Timer` firing every 0.05s to advance `waterProgress`. The timer runs while the user is holding down — but if the view is dismissed mid-hold, the timer keeps firing and mutating `@State waterProgress` with no `@MainActor` isolation guard.

```swift
// PlotView.swift — startWatering()
// ❌
waterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
    waterProgress += 0.015     // no @MainActor, no cancellation on dismiss
    if waterProgress >= 1.0 { completeWatering() }
}
```

**Fix:** Replace with a `Task`-based loop using `withTaskCancellationHandler` and store as `@State private var wateringTask: Task<Void, Never>?`, cancelled in `.onDisappear`.

---

### 🟠 P1 — Significant: `DispatchQueue.main.asyncAfter` chains outlive the view

These chains are used as poor-man's animation sequencers. Work items are not captured as `DispatchWorkItem`, so they cannot be cancelled when the view disappears. If the user backs out of onboarding mid-animation, the queued closures still fire and mutate `@State` on deallocated views.

| File | asyncAfter count | Purpose |
|------|-----------------|---------|
| `CookingCompletionView.swift` | 3 chained | Star rating reveal sequence |
| `MeetPipAnimated.swift` | 5 | Onboarding entrance + dialogue pacing |
| `MeetPipViews.swift` | 4 | Same (non-animated variant) |
| `GardenView.swift` | 4 | Visitor greeting, harvest bounce x3 |
| `GlucoseJourneyView.swift` | 2 | Phase transitions |
| `PlantingSheet.swift` | 1 | NPC entrance after morph |
| `FamilySetupView.swift` | 3 | PIN setup step gating |

**Fix pattern** (cancels automatically on view disappear):
```swift
// ✓
.task(id: triggerKey) {
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    withAnimation(AnimationConstants.springBouncy) { npcAppeared = true }
}
```

---

### 🟡 P2 — Low: `DispatchQueue.main.asyncAfter` for transient-dismissal (cosmetic)

20+ instances across the codebase follow this pattern:

```swift
// e.g. PantryInfoView, AskPipView, HomeAnimated, etc.
withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
    showCoinReward = "+\(coins)"
}
DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
    withAnimation { showCoinReward = nil }
}
```

These are cosmetically safe (SwiftUI discards mutations to deallocated `@State`), but noisy. Prefer `.task(id: showCoinReward) { try? await Task.sleep(for: .seconds(1.2)); showCoinReward = nil }`.

---

### ✅ Confirmed Clean (no timer/async issues)

`KitchenView.swift`, `AmbientAudioPlayer.swift`, `InsulinTetrisView.swift`, `CharacterWalkingView.swift`, `MorphTransition.swift`, `PipAIService.swift`, `PipFoundationModelService.swift`, `ODRManager.swift`, `GameCenterService.swift`, `MultiplayerManager.swift`, `NearbyMultiplayerManager.swift`

---

## FOCUS 2 — HARDCODED VALUES + MISSED COMPONENT REUSE

**Rule:** Every color, font, spacing, animation constant, and stroke width MUST map to an existing token in `AppTheme.swift` (`Color.AppTheme.*`, `Font.AppTheme.*`, `AppSpacing.*`, `AnimationConstants.*`) or `AdaptiveLayout.swift` (`AdaptiveCardSize.*`). No inlines.

---

### 2A — Missed `PipSpeechBubble` reuse (4 inline duplicates)

`PipComponents.swift` exports `PipSpeechBubble(message:pose:size:)` precisely for these situations. Four files hand-roll the same HStack(avatar + name + text bubble) pattern instead:

| File | Struct | Fix |
|------|--------|-----|
| `GardenView.swift` | `PipGardenMessage` (lines ~620-650) | `PipSpeechBubble(message: message, pose: .waving)` |
| `GlucoseJourneyView.swift` | `PipJourneyMessage` (multiple phases) | `PipSpeechBubble(message: message, pose: .gotIdea)` |
| `PlayLearnView.swift` | Inline HStack with `PipWavingAnimatedView` + text VStack | `PipSpeechBubble(message: ..., pose: .waving, speakOnAppear: false)` |
| `PipAnimations.swift` | `PipWithDialogue` struct | Refactor callers to use `PipSpeechBubble`; `PipWithDialogue` → mark `@available(*, deprecated)` |

---

### 2B — Hardcoded animation constants (should use `AnimationConstants.*`)

Available tokens: `springBouncy`, `springMedium`, `springQuick`, `fadeMedium`, `fadeSlow`, `fadeQuick`, `morphTransition`, `pipTransition`, `revealSlow`.

#### High-frequency offenders

**`CookingMiniGames.swift`**
```swift
// ❌ (HeatPanMiniGame, CookTimerMiniGame, WashMiniGame)
.animation(.spring(response: 0.3, dampingFraction: 0.5), value: progress)
.spring(response: 0.3, dampingFraction: 0.7)
// ✓
.animation(AnimationConstants.springMedium, value: progress)
AnimationConstants.springBouncy
```

**`GardenView.swift`**
```swift
// ❌ (DraggablePipView, GardenView)
.animation(.spring(response: 0.4, dampingFraction: 0.7), value: isVisible)
.easeIn(duration: 0.6), .easeOut(duration: 0.3)
.spring(response: 0.3, dampingFraction: 0.4)   // triggerHarvest
// ✓
.animation(AnimationConstants.springMedium, value: isVisible)
AnimationConstants.fadeMedium, AnimationConstants.fadeQuick
AnimationConstants.springBouncy
```

**`InsulinTetrisView.swift`** (5 inline springs that should use existing tokens)
```swift
// ❌
.animation(.spring(response: 0.2), value: block.isDragging)
.animation(.spring(response: 0.4), value: bin.fillFraction)
.animation(.spring(response: 0.3))      // attemptStore, activateFiber
.animation(.spring(response: 0.4, dampingFraction: 0.3))  // rejectBlock
// ✓
AnimationConstants.springQuick, AnimationConstants.springMedium,
AnimationConstants.springBouncy (for reject shake: low dampingFraction)
```

**`MeetPipAnimated.swift` + `MeetPipViews.swift`**
```swift
// ❌ — shared in both files
.spring(response: 0.6, dampingFraction: 0.7)   // entrance
.easeOut(duration: 0.5), .easeOut(duration: 0.4)
.spring(response: 0.5, dampingFraction: 0.6)   // ready screen
// ✓ (or add AnimationConstants.springEntrance = .spring(response: 0.6, dampingFraction: 0.7))
AnimationConstants.springMedium for ready screen
AnimationConstants.fadeSlow / fadeMedium for easeOut fades
```

**`PipAnimations.swift`** (`PipCharacterView`, `PipWithDialogue`, `PipReactionView`)
```swift
// ❌
.spring(response: 0.5, dampingFraction: 0.6)   // entrance
.easeInOut(duration: 1.5).repeatForever(...)    // idle bounce
.spring(response: 0.3, dampingFraction: 0.5)   // pose change out
// ✓
AnimationConstants.springMedium, AnimationConstants.revealSlow.repeatForever(...)
AnimationConstants.springBouncy
```

**`WeatherOverlayView.swift`**
```swift
// ❌
.animation(.easeInOut(duration: 1.0), value: weather)   // weather transition
// ✓ — add to AnimationConstants:
// static let weatherTransition = Animation.easeInOut(duration: 1.0)
```

**`PlotView.swift`**
```swift
// ❌
.spring(response: 0.3)           // showWateringCan
.easeInOut(duration: 0.6).repeatForever(...)   // water drops
.easeOut(duration: 0.3)          // weed pull
.spring(response: 0.3)           // weed snap-back
.easeIn(duration: 0.3)           // ladybug fly-in
.spring(response: 0.4)           // XP badge
// ✓
AnimationConstants.springBouncy, AnimationConstants.revealSlow.repeatForever(...),
AnimationConstants.fadeQuick, AnimationConstants.springBouncy,
AnimationConstants.fadeMedium, AnimationConstants.springMedium
```

**`PipDialogView.swift`**
```swift
// ❌
withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
.padding(.bottom, 100)    // arbitrary safe-area pad
// ✓
AnimationConstants.springMedium
AppSpacing.safeAreaPad (or use .safeAreaInset / .ignoresSafeArea properly)
```

**`MigrationPINSetupView.swift` + `ParentPINEntryView.swift`** (same PIN pad layout)
```swift
// ❌ — identical in both files
HStack(spacing: 16)     // PIN dots row
VStack(spacing: 12)     // number pad rows
HStack(spacing: 20)     // digit rows
.spring(response: 0.2, dampingFraction: 0.3)   // shake error
// ✓
AppSpacing.md, AppSpacing.sm, AppSpacing.md
AnimationConstants.springQuick   (note: dampingFraction 0.3 ≠ springQuick.0.5 → needs a new 'springShake' constant with low damping, or use springBouncy which has .dampingFraction 0.4)
```

**`OnboardingView.swift`** (`GenderSelectionView`, `WelcomeView`)
```swift
// ❌
.spring(response: 0.4, dampingFraction: 0.7)   // gender card select
.easeOut(duration: 0.8)    // welcome entrance
.easeOut(duration: 0.6)    // gender selection entrance
// ✓
AnimationConstants.springMedium, AnimationConstants.fadeSlow, AnimationConstants.fadeMedium
```

---

### 2C — Hardcoded colors (should use `Color.AppTheme.*`)

| File | Line pattern | Fix |
|------|-------------|-----|
| `AllergenPickerStep.swift` | `.foregroundColor(.white)` on CTA buttons | `Color.AppTheme.cream` |
| `CharacterWalkingView.swift` | `Color.black.opacity(0.2)` shadow | `Color.AppTheme.sepia.opacity(0.2)` |
| `CookingMiniGames.swift` | `Color(white: 0.85)` border, `Color(white: 0.7)` dim, `Color(white: 0.3)` text | `Color.AppTheme.parchment`, `Color.AppTheme.warmCream.opacity(0.7)`, `Color.AppTheme.sepia` |
| `GardenView.swift` | `Color.black.opacity(0.2)` shadow on DraggablePipView | `Color.AppTheme.sepia.opacity(0.2)` |
| `HealthyChoiceGameView.swift` | `shadow(color: .white, radius: 2)` on food bubbles | `Color.AppTheme.cream` |
| `LocalVersusView.swift` | `shadow(color: .white, radius: 2)` | `Color.AppTheme.cream` |
| `MultiplayerHealthyPicksView.swift` | `shadow(color: .white, radius: 2)` | `Color.AppTheme.cream` |
| `NearbyVersusView.swift` | `shadow(color: .white, radius: 2)` | `Color.AppTheme.cream` |
| `PantryInfoView.swift` | `.shadow(color: .black.opacity(0.2), ...)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `RecipeDetailView.swift` | `.foregroundColor(.white)` × 2 in allergen banner | `Color.AppTheme.cream` |
| `GardenWeatherService.swift` | `Color(hex:)` × 8 for seasonal gradients | Define 8 new `Color.AppTheme.*` seasonal tokens or a `GardenSeason.gradientColors` using existing tokens |

---

### 2D — Hardcoded system fonts (should use `Font.AppTheme.*`)

| File | Hardcoded | Fix |
|------|-----------|-----|
| `ChefAcademyApp.swift` | `.font(.system(size: isLarge ? 40 : 30))` (tab bar overlay) | `.font(isLarge ? .AppTheme.largeTitle : .AppTheme.title)` |
| `GardenView.swift` | `.font(.system(size: isIPad ? 18 : 14, weight: .medium, design: .rounded))` × 3 (SeedBadge, IngredientBadge) | `.font(.AppTheme.rounded(size: isIPad ? 18 : 14, weight: .medium))` |
| `HomeAnimated.swift` | `.font(.system(size: sizeClass == .compact ? 20 : 28))` (flame streak) | `.font(.AppTheme.rounded(size: sizeClass == .compact ? 20 : 28, weight: .bold))` |
| `ProfilePickerView.swift` | `.system(size: 40, weight: .bold, design: .rounded)` + `.system(size: 22, ...)` × 4 | `.AppTheme.largeTitle`, `.AppTheme.headline`, `.AppTheme.rounded(size: 22, ...)` |
| `PipTestView.swift` | `.font(.system(size: 20))` for emoji indicator | `.font(.AppTheme.title3)` |
| `WeatherOverlayView.swift` | `.font(.system(size: isIPad ? 18 : 14))` for weather particle emoji | `.font(.AppTheme.rounded(size: isIPad ? 18 : 14))` |

---

### 2E — Hardcoded spacing + dimensions

#### PIN pad (identical in `MigrationPINSetupView.swift` AND `ParentPINEntryView.swift`)
```swift
// ❌ — copy-pasted in both files
HStack(spacing: 16)           // PIN dot row    → AppSpacing.md (= 16)
VStack(spacing: 12)           // number rows    → AppSpacing.sm (= 12)
HStack(spacing: 20)           // digit columns  → AppSpacing.lg (= 20)
.frame(width: 75, height: 55) // Cancel/delete  → extract as PINActionButton frame constant
```
Both files should share these via a `private extension` or by extracting a `PINPadView` component.

#### `RecipeDetailView.swift`
```swift
// ❌
.padding(.horizontal, 10).padding(.vertical, 5)   // adult help badge  → AppSpacing.xs
.padding(.horizontal, 12).padding(.vertical, 8)   // allergen banner   → AppSpacing.sm
.padding(.horizontal, 10).padding(.vertical, 8)   // ingredient pills  → AppSpacing.xs/sm
.cornerRadius(10)     → AppSpacing.smallCornerRadius
.cornerRadius(14)     → AppSpacing.pillCornerRadius
.frame(height: 56)    // cook button  → AppSpacing.buttonHeight (= 56 — already defined)
HStack(spacing: 4/6/8) → AppSpacing.xxs / AppSpacing.xs / AppSpacing.xs
```

#### `PlotView.swift`
```swift
// ❌ — pixel-grid coordinates, acceptable but document
.frame(width: 100, height: 110)   // plot cell — likely intentional pixel grid
VStack(spacing: 6/4/2)            // sub-AppSpacing micro spacings
.padding(.horizontal, 8).padding(.vertical, 3)   // "Harvest!" badge  → AppSpacing.xxs/xs
```

---

### 2F — Hardcoded stroke widths

```swift
// ChefAcademyApp.swift and GardenView.swift
// ❌
lineWidth: 2.5
// ✓
AppSpacing.strokeBold   // already defined as 2.5 — just not used consistently
```

---

### 2G — `PlotButtonStyle` duplicates `BouncyButtonStyle`

`PlotView.swift` (bottom of file) defines:
```swift
// ❌ — exact duplicate of BouncyButtonStyle in AppTheme.swift
struct PlotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
```
**Fix:** Delete `PlotButtonStyle`. Call sites should use `.buttonStyle(BouncyButtonStyle())`.

---

### 2H — Minor: `PipVoiceToggleChip` inline dimensions

`PipVoice.swift`
```swift
// ❌
.padding(.horizontal, 10).padding(.vertical, 6)
.cornerRadius(14)
// ✓
.padding(.horizontal, AppSpacing.xs).padding(.vertical, AppSpacing.xxs)
.cornerRadius(AppSpacing.pillCornerRadius)
```

---

## Summary Table

### Stale UI State

| Severity | Files | Issue |
|----------|-------|-------|
| 🔴 P0 | HealthyChoiceGameView, LocalVersusView, MultiplayerHealthyPicksView, NearbyVersusView, SplitScreenVersusView | `Timer.scheduledTimer` at 60fps in physics loop |
| 🔴 P0 | PlotView | `Timer.scheduledTimer` at 20fps in watering hold gesture |
| 🟠 P1 | CookingCompletionView, MeetPipAnimated, MeetPipViews, GardenView | `asyncAfter` chains without cancellation handles |
| 🟡 P2 | 20+ files | `asyncAfter` for transient UI (cosmetic risk only) |

### Hardcoded Values

| Category | Files | Token(s) to use |
|----------|-------|----------------|
| Inline Pip+bubble | GardenView, GlucoseJourneyView, PlayLearnView, PipAnimations | `PipSpeechBubble(message:pose:)` |
| Animation constants | 15 files | `AnimationConstants.springBouncy/Medium/Quick/fadeMedium/etc.` |
| Colors | 11 files | `Color.AppTheme.cream/.sepia.opacity/.parchment` |
| System fonts | 6 files | `Font.AppTheme.*` / `.AppTheme.rounded(size:weight:)` |
| Spacing/dims | MigrationPINSetupView, ParentPINEntryView, RecipeDetailView | `AppSpacing.xs/sm/md/lg`, `AppSpacing.buttonHeight/pillCornerRadius/smallCornerRadius` |
| Stroke widths | ChefAcademyApp, GardenView | `AppSpacing.strokeBold` |
| PlotButtonStyle duplicate | PlotView | Delete; use `BouncyButtonStyle()` |

---

## Recommended Next Actions

1. **Week 1 (P0 blockers):** Migrate the 5 game views + PlotView from `Timer.scheduledTimer` to `TimelineView(.animation)` using the delta-time pattern from `InsulinTetrisView.swift`. Each view follows the same food-physics pattern so a shared `FoodPhysicsEngine` struct could be extracted to avoid the fix × 5.

2. **Week 2 (P1 async chains):** Audit all `DispatchQueue.main.asyncAfter` in animation-sequencing context. Convert to `.task(id:) { try? await Task.sleep(for:) }` for automatic cancellation.

3. **Week 3 (Hardcodes):** Address `.white` color leaks first (easiest, highest visual correctness gain). Then inline animations → `AnimationConstants.*`. Then missed `PipSpeechBubble` replacements.

4. **Ongoing:** Add a SwiftLint rule or custom build phase grep for `Color\.white`, `Color\.black`, `font(.system(`, and `Timer.scheduledTimer` that fails CI on new additions.
