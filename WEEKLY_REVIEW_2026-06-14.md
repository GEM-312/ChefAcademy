# Weekly Code Review — 2026-06-14

Scope: all Swift source files in `ChefAcademy/`. Every finding below was verified against the current file on disk. Pre-commit grep targets (§3) were applied to every file.

---

## Legend

| Tag | Meaning |
|-----|---------|
| **P1** | Fix before next TestFlight / shipping. Correctness/data-safety issue. |
| **P2** | Fix before App Review submission. Architecture violation that will accumulate tech debt. |
| **P3** | Fix during cleanup pass. Cosmetic or low-risk token violations. |
| **CLEAN** | File reviewed; no findings. |

---

## P1 — Data Safety (§1: `try?` on SwiftData saves)

Rule: `saveToStore()` / `modelContext.save()` must use `do { try save() } catch { print(error) }`. Silent `try?` hides the March-style data-loss bug.

**14 violations across 7 files:**

| File | Function |
|------|----------|
| `AddChildFlowView.swift` | `finishAddChild()` |
| `FamilySetupView.swift` | `finishSetup()` |
| `ParentDashboardView.swift` | `deleteAllDataAndRestart()` |
| `ParentDashboardView.swift` | `linkAppleID()` |
| `SessionManager.swift` | `migrateLegacyData()` |
| `SessionManager.swift` | `updateParentPIN()` |
| `SessionManager.swift` | `removeChildProfile()` |
| `SessionManager.swift` | `switchToProfilePicker()` |
| `SessionManager.swift` | `signOut()` |
| `SessionManager.swift` | `appWillBackground()` |
| `SessionManager.swift` | `recordPlayTime()` |
| `SessionManager.swift` | `handleAuthenticationComplete()` |
| `SiblingGardenView.swift` | `handleHelpAction()` |
| `SiblingProfileView.swift` | `giftVeggie()` |

Note: `HomeView.dismissHelpMessages()` also uses `try? modelContext.save()`. That is an additional violation in `ChefAcademyApp.swift`.

**Pattern fix:**
```swift
// BEFORE (silent failure — 14 occurrences)
try? modelContext.save()

// AFTER
do {
    try modelContext.save()
} catch {
    print("[FileName] save failed: \(error)")
}
```

---

## P1 — Concurrency (§2: `DispatchQueue.main.async` banned)

Rule: All `@Published` / `@State` mutations from non-main contexts must use `Task { @MainActor in }`.

**16+ violations across 6 files:**

| File | Site | Count |
|------|------|-------|
| `GameCenterMatchmakerView.swift` | GK delegate callbacks (`matchmakerViewController(_:didFind:)`, `matchmakerViewControllerWasCancelled`, `matchmakerViewController(_:didFailWithError:)`) | 3 |
| `GameCenterService.swift` | `authenticate()` → GKLocalPlayer completion handler | 1 |
| `MultiplayerManager.swift` | `authenticateLocalPlayer`, `handleMessage`, `match(_:player:didChange:)`, `match(_:didFailWithError:)`, `startCountdown()` timer callback | 5 |
| `NearbyMultiplayerManager.swift` | `handleMessage`, `session(_:peer:didChange:)`, `handleConnection`, `advertiser(_:didNotStartAdvertisingPeer:)`, `browser(_:didNotStartBrowsingForPeers:)`, `startCountdown()` | 6 |
| `ParentPINEntryView.swift` | `startAppleIDVerification()` ASCredentialIdentityStore callback | 1 |
| `SeedInfoView.swift` | `VeggieCanvasView.updateUIView` → `DispatchQueue.main.async { clearToggle = false }` | 1 |

**Pattern fix (same for all):**
```swift
// BEFORE
DispatchQueue.main.async { self.someState = newValue }

// AFTER
Task { @MainActor in self.someState = newValue }
```

---

## P1 — Game Physics (§2: `Timer.scheduledTimer` for frame-rate-dependent physics)

Rule: Physics and countdown loops that advance by a fixed value per tick must use `TimelineView(.animation)` with delta-time so speed is frame-rate-independent.

| File | Function | Violation |
|------|----------|-----------|
| `CookingMiniGames.swift` | `HeatPanMiniGame.startHolding()` | `Timer.scheduledTimer(withTimeInterval: 0.05)` advances heat by fixed delta — breaks on 120 Hz ProMotion |
| `CookingMiniGames.swift` | `CookTimerMiniGame.startTimer()` | `Timer.scheduledTimer(withTimeInterval: 0.1)` advances countdown — same issue |

Note: `ChopMiniGame.startGame()` also uses `Timer.scheduledTimer(withTimeInterval: 0.02)` to move the knife back-and-forth. The knife speed is frame-rate-tied. This is a third violation in the same category.

**Correct pattern (already used in `WaterPourCharacterView`, `InsulinTetrisView`, `WeatherOverlayView`):**
```swift
TimelineView(.animation) { context in
    let dt = context.date.timeIntervalSince(lastUpdate)
    Canvas { ctx, size in ... }
    .onChange(of: context.date) { _, newDate in
        updatePhysics(dt: CGFloat(min(dt, 0.1)))
        lastUpdate = newDate
    }
}
```

---

## P2 — Architecture Violation (§4: Inline gender checks instead of `profilePoseImage`)

Rule: Never write `gender == .boy ? "boy_card_..." : "girl_card_..."`. Use `UserProfile.profilePoseImage`, which also handles parent mom/dad frames.

| File | Location | Notes |
|------|----------|-------|
| `LocalVersusView.swift` | `playerSelectCard`, `selectedPlayerChip`, `playerAvatarSmall`, `playerReadyView` | 4 inline gender checks |
| `MultiplayerHealthyPicksView.swift` | `opponentScoreBar`, `playerAvatar(isLocal:)` | 2 inline gender checks |
| `NearbyVersusView.swift` | `playerAvatar(gender:)`, opponent bar | 2 inline gender checks |
| `ParentDashboardView.swift` | `DashboardChildTab` | 1 inline gender check |
| `SiblingProfileView.swift` | `characterImage` computed property | Direct `sibling.profilePoseImage` drop-in |
| `SplitScreenVersusView.swift` | `pickPlayersView`, `readyView` (p1 and p2) | 2 inline gender checks |
| `ChefAcademyApp.swift` | `HomeView` sibling carousel | `Image(sibling.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")` |

`GardenHubView.swift` `SiblingPickerView` also contains an inline gender check — noted only, file is orphaned dead code awaiting deletion.

`AvatarCreatorView.swift` `AvatarPreviewView.characterImage` uses a gender check for the avatar creator preview — lower priority (creator preview context, not a profile card display).

**Fix pattern:**
```swift
// BEFORE
Image(profile.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")

// AFTER
Image(profile.profilePoseImage)
```

---

## P2 — STALE-UI: Deprecated APIs

| File | Location | Issue |
|------|----------|-------|
| `GardenView.swift` | `DraggablePipView` | `UIScreen.main.bounds.width` — deprecated in iOS 16; use `GeometryReader` or `.containerRelativeFrame` |
| `KitchenView.swift` | `recipePicker` | Wraps content in `NavigationView` — deprecated; use `NavigationStack` |
| `RecipeCardExample.swift` | `RecipeListView` | Wraps content in `NavigationView` — deprecated; use `NavigationStack` |
| `PipTestView.swift` | Root view | Wraps in `NavigationView` — deprecated |

---

## P3 — Design Token Violations

### A. Hardcoded shadow colors (§3: shadows must use `Color.AppTheme.sepia.opacity(N)`)

| File | Line/location | Violation |
|------|--------------|-----------|
| `ChopMiniGame.swift` | `sweetSpotIndicator` | `.shadow(color: .black.opacity(0.2), ...)` |
| `FarmShopView.swift` | shop card | `.shadow(color: .black.opacity(0.5), ...)` |
| `GardenView.swift` | `DraggablePipView`, `WalkingPipView` | `.shadow(color: Color.black.opacity(0.2), ...)` |
| `RecipeDetailView.swift` | allergen banner | `.foregroundColor(.white)` (should be `Color.AppTheme.cream`) |

### B. Hardcoded fonts (§3: use `Font.AppTheme.*`)

| File | Violation |
|------|-----------|
| `ProfilePickerView.swift` | `.font(.system(size: 40, weight: .bold, design: .rounded))` on title; `.font(.system(size: 22))` on button; `.font(.system(size: 15, design: .rounded))` in `ProfileCard` |

### C. Hardcoded spacing / sizing (§3: use `AppSpacing.*`)

Grouped by file for readability. All inline literals that duplicate existing `AppSpacing` tokens:

**`AskPipView.swift`:** `.padding(.leading, 50)` (× multiple), `.padding(.horizontal, 12)`, `.padding(.vertical, 8)`, `HStack(spacing: 6)`

**`AvatarCreatorView.swift`:** `VStack(spacing: 8)` in `HairStyleSelector`/`OutfitSelector`, `VStack(spacing: 4)` in `HeadCoveringSelector`, `.frame(width: 44, height: 44)`, `.frame(width: 50, height: 50)`

**`BodyBuddyView.swift`:** `Spacer().frame(height: 80)`, `VStack(spacing: 2)` in `HealthOrb`, `Circle().stroke(lineWidth: 4)`, `.frame(width: 50, height: 50)`, `.frame(width: 36, height: 36)`, `HStack(spacing: 1)`, `.frame(width: 85)`

**`ChefAcademyApp.swift`:** `CustomTabBar`: `VStack(spacing: 4)`, `.frame(width: 28, height: 28)`; `StreakCard`: `VStack(alignment: .leading, spacing: 4)`, `HStack(spacing: -5)`; chip padding `.padding(.horizontal, 10)`, `.padding(.vertical, 6)`, `.cornerRadius(14)` (× 3 chips)

**`ChopMiniGame.swift`:** `HStack(spacing: 4)` in header stars and `vegetableView`; `.frame(height: 250)` cutting board; `.frame(height: 50)` knife; `.frame(width: 30, height: 30)` chopped pieces; `.frame(width: 50, height: 50)` whole vegetable

**`CookingCompletionView.swift`:** `.frame(width: 140, height: 140)` recipe image; `Circle().overlay ... lineWidth: 4`; `VStack(spacing: 2)` in health boost; `HStack(spacing: 6)` in reward chip

**`FarmShopView.swift`:** Multiple inline spacing values; `isWideScreen ? 220 : 110` inline device branch (use `AdaptiveCardSize`)

**`GardenView.swift`:** `.cornerRadius(6)` badge; `isIPad ? 200 : 100` inline device branch (use `AdaptiveCardSize`)

**`GlucoseJourneyView.swift`:** `Spacer().frame(height: 100)` (× multiple)

**`HealthyChoiceGameView.swift`:** Multiple inline spacing values

**`InsulinTetrisView.swift`:** Multiple inline spacing values; `Image("pip_got_idea")` with `.frame(width: 120, height: 120)`

**`MeetPipAnimated.swift`:** `HStack(spacing: 4)`

**`MigrationPINSetupView.swift`:** `HStack(spacing: 16)` for PIN dots

**`PantryInfoView.swift`:** `Image(item.imageName).frame(width: 200, height: 200)` (should use `AppSpacing.infoCardImageSize`); `Spacer(minLength: 140)`, `.padding(.top, 60)`, `HStack(spacing: 6)`, `VStack(spacing: 2)`, `HStack(spacing: 2)`, `HStack(spacing: 4)`

**`ParentDashboardView.swift`:** Multiple inline sizing values

**`ParentPINEntryView.swift`:** `HStack(spacing: 16)` for PIN dots

**`PipDialogView.swift`:** `.padding(.bottom, 100)`

**`PlantingSheet.swift`:** `Spacer(minLength: 40)` (× 2)

**`PlayLearnView.swift`:** `Spacer().frame(height: 80)`

**`PlotView.swift`:** `.frame(width: 100, height: 110)`, multiple `.frame(width: 70/80/85)`

**`ProfileView.swift`:** `Spacer().frame(height: 100)`

**`RecipeCardExample.swift`:** `Circle().frame(width: 50, height: 50)`, `HStack(spacing: 4)` (× 2), `VStack(alignment: .leading, spacing: 4)`

**`RecipeDetailView.swift`:** `.cornerRadius(10)` badge; `VStack(alignment: .leading, spacing: 2)`; allergen warning padding `.padding(.horizontal, 12)`, `.padding(.vertical, 8)`; ingredient rows `.padding(.horizontal, 10)`, `.padding(.vertical, 8)`, `.cornerRadius(10)`; step circles `.frame(width: 32, height: 32)`; nutrition pills `.padding(.horizontal, 12)`, `.padding(.vertical, 6)`, `.cornerRadius(14)`

**`SeedInfoView.swift`:** `Spacer(minLength: 140)`, `.padding(.top, 60)` (× 2), `HStack(spacing: 6)`, `.frame(width: 42, height: 42)`, `VStack(spacing: 4)`, `HStack(spacing: 4)`, `VStack(alignment: .leading, spacing: 3)`, `HStack(spacing: 2)`

**`SiblingProfileView.swift`:** `VStack(spacing: 4)`, `.frame(width: 50, height: 50)`, `.frame(width: 120, height: 120)`, `.frame(width: 60, height: 60)`, `Spacer().frame(height: 80)`

### D. Hardcoded animation curves (§3: use `AnimationConstants.*`)

| File | Violation |
|------|-----------|
| `AskPipView.swift` | `.easeOut(duration: 0.3)` in ScrollViewReader scroll; `.easeInOut(duration: 0.4).repeatForever()` in typing indicator; `.easeIn(duration: 0.3).delay(0.5)` in follow-ups |
| `BodyBuddyView.swift` | `.easeOut(duration: 1.0).delay(0.3)` in `onAppear`; `.easeOut(duration: 1.0)` in `HealthOrb`; `.easeOut(duration: 0.8).delay(0.2)` (× 2) in `RecipeNutrientBreakdown` |
| `ChopMiniGame.swift` | `.animation(.easeOut(duration: 0.1), value: justChopped)` on knife view |
| `CookingMiniGames.swift` | `.easeOut(duration:)` in `PeelMiniGame`, `WashMiniGame`, `AssembleMiniGame`; `.spring(response:)` in `spawnSparkle` |
| `CookingSessionView.swift` | `withAnimation(.easeInOut(duration: 0.4))` in `handleStepComplete()` |
| `FamilySetupView.swift` | `.easeOut(duration: 0.8)` and `.easeOut(duration: 0.6)` in step `onAppear` animations |
| `GameState.swift` | `withAnimation(.spring())` in `addCoins()` and `spendCoins()` |
| `GlucoseJourneyView.swift` | Multiple `.spring(response:)` and `.easeInOut(duration:)` |
| `HealthyChoiceGameView.swift` | `.easeIn(duration: 2)` and `.easeIn(duration: 1.5)` |
| `MeetPipAnimated.swift` | `.easeIn(duration: Double.random(in: 1.5...2.5))` in confetti |
| `PipAnimations.swift` | `WiggleModifier`: `.easeInOut(duration: speed).repeatForever(autoreverses: true)` |
| `PlotView.swift` | `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` in `startWatering()` |
| `PipTestView.swift` | `.easeOut(duration: 0.3)` in `stopBreathingAnimation()` |
| `WeatherOverlayView.swift` | `SunshineOverlay`: `.easeInOut(duration: 3).repeatForever`; `PartlyCloudyOverlay`: `.easeInOut(duration: 8)`, `.easeInOut(duration: 3)`; `CloudOverlay`: `.easeInOut(duration: 10)`, `.easeInOut(duration: 7)`; `WindOverlay`: `.easeInOut(duration: 2)`, `.easeInOut(duration: 2.5).delay(0.3)`, `.easeInOut(duration: 1.8).delay(0.7)`; `SeasonalOverlayView`: `.linear(duration: 20)`, `.easeInOut(duration: 3)` |

### E. Hardcoded device branches (§3: use `AdaptiveCardSize`)

| File | Violation |
|------|-----------|
| `FarmShopView.swift` | `isWideScreen ? 220 : 110` |
| `GardenView.swift` | `isIPad ? 200 : 100` |
| `ProfilePickerView.swift` | `pipSize: CGFloat { isIPad ? 280 : 120 }` |

### F. Button style violations (§4: primary CTAs must use `.texturedButton(tint:)` or `BouncyButtonStyle()`)

| File | Location |
|------|----------|
| `BodyBuddyView.swift` | "Cook" button uses `.plain` with manual background/cornerRadius |
| `CookingCompletionView.swift` | "See how your food helps!" button: hand-rolled `.background(Color.AppTheme.goldenWheat)` + `.cornerRadius(...)` — uses `BouncyButtonStyle()` but bypasses `.texturedButton` |
| `CookingMiniGames.swift` | `SeasonMiniGame` hand-rolled button |
| `HealthyChoiceGameView.swift` | `placeholderView` and game-screen CTAs hand-rolled |
| `PlayLearnView.swift` | `MiniGameRouterView.placeholderView` hand-rolled button |
| `ProfilePickerView.swift` | "Add Little Chef" button: `.buttonStyle(.plain)` with manual background/cornerRadius |
| `SiblingProfileView.swift` | `GiftVeggieSheet`: "Visit Garden" and "Gift Veggies" buttons hand-rolled |
| `SplitScreenVersusView.swift` | `resultsView`: Rematch and Done buttons hand-rolled |

### G. Raw `Image(...)` with hardcoded frame instead of `PipSize` (§4)

| File | Violation |
|------|-----------|
| `AskPipView.swift` | `Image("pip_got_idea")` with `.frame(width: 40, height: 40)` in typing indicator |
| `GardenView.swift` | `Image("pip_waving_frame_01")` with hardcoded frame in `WalkingPipView` |
| `GlucoseJourneyView.swift` | `Image(pose)` with hardcoded frame |
| `InsulinTetrisView.swift` | `Image("pip_got_idea")` with `.frame(width: 120, height: 120)` |
| `MultiplayerHealthyPicksView.swift` | `Image("pip_got_idea")` with `.frame(width: 100, height: 100)` |
| `NearbyVersusView.swift` | `Image("pip_got_idea")` with `pipScale` multiplier |
| `SiblingProfileView.swift` | `Image(characterImage)` with `.frame(width: 120, height: 120)` — also a §4 violation since `characterImage` uses an inline gender check |

---

## Files with No Findings

`AvatarModel.swift`, `ChopMiniGame.swift` (except physics timer and minor hardcodes above), `CookingCompletionView.swift` (all token-clean; `animateStars()` correctly uses `Task { @MainActor in }` with `guard !Task.isCancelled`), `ContentView.swift` (legacy stub, never referenced), `ElevenLabsVoiceService.swift`, `FamilyProfile.swift`, `GardenWeatherService.swift`, `HomeAnimated.swift`, `MeetPipViews.swift`, `MorphTransition.swift`, `ODRManager.swift`, `OnboardingView.swift`, `PaywallView.swift`, `PipAIService.swift`, `PipDialogView.swift` (one padding finding above), `PipFoundationModelService.swift`, `PipGameAnimationView.swift`, `PipStaticResponses.swift`, `PipVoice.swift`, `PINKeychain.swift`, `PlantingSheet.swift` (two minor spacing findings), `PlayerData.swift`, `ProfileView.swift` (one spacing finding), `SeededRandomGenerator.swift`, `SignInView.swift`, `SubscriptionManager.swift`, `USDAFoodService.swift`, `UserProfile.swift`, `VideoPlayerView.swift`, `VoicePickerView.swift`, `WaterPourCharacterView.swift`, `WorkerClient.swift`

---

## Orphaned Dead Code

`GardenHubView.swift` — zero references anywhere in the codebase. Contains a `SiblingPickerView` with an inline gender check (note only). Planned deletion — do not add features here.

`ContentView.swift` — template stub, never referenced. Can be deleted when convenient.

---

## Patterns Verified CORRECT (Not Violations)

The following patterns were explicitly verified during this review and are intentional:

- `Timer.scheduledTimer` with `Task { @MainActor in }` wrapper — correct for **sprite frame animation** at fixed fps (`WaterPourCharacterView`, `PipGameAnimationView`, `CharacterWalkingView`, `OnboardingView GenderCard`, `PipAnimations OneShotFrameAnimationView`) and for **spawn scheduling** (`LocalVersusView.spawnTimer`, `MultiplayerHealthyPicksView.spawnTimer`, `SplitScreenVersusView` countdown/spawn). This is the documented-correct pattern; only timer-based **physics** (value advancing per tick) is the violation.
- `GardenWeatherService.startPeriodicRefresh()` — `Timer.scheduledTimer` + `Task { @MainActor in }`. Correct.
- `SessionManager.playTimeTimer` — `Timer.scheduledTimer` + `Task { @MainActor [weak self] in }`. Correct.
- `CookingCompletionView.animateStars()` — sequential `Task { @MainActor in }` with `guard !Task.isCancelled`. Correct replacement for the old `asyncAfter` chain.
- `PipSpeechBubble` / `PipHeaderStack` — auto-speak on appear/change. Do not add manual `PipVoice.shared.speak()` calls alongside them.
- `PipMessageCard` in `ChefAcademyApp.swift` — uses `PipWavingAnimatedView` (not `PipSpeechBubble`), so the manual `PipVoice.shared.speak()` call on `.onAppear` / `.onChange` is correct (no double-speak).
- `PipFoundationModelService` and `@Generable` types — gated by `#if canImport(FoundationModels)` and `@available(iOS 26, *)`. Correct isolation.
- `Color(hex:)` in `AppTheme.swift` itself — the canonical hex initializer. Not a violation. Flag `Color(hex:)` only in **other** files.
- `Color.AppTheme.overlay` is defined — not a violation when used.
- `SceneEditor.swift` — DEV-only tool. Hardcoded `Color.red`, `Color.black`, `.font(.system(size:))` are intentional. Low priority.
- `PencilKit` canvas fixed size in `SeedInfoView` — `canvasSize = CGSize(width: 320, height: 280)` is documented as intentional.

---

## Prioritized Fix Order

### This sprint (P1 — before next TestFlight)
1. **`try?` save violations** — 15 sites across 8 files. Data-loss risk. Pattern is identical each time; can be fixed in one pass.
2. **`DispatchQueue.main.async` violations** — 16+ sites across 6 files. Thread-safety under Swift 6 strict concurrency. `NearbyMultiplayerManager` (6 sites) and `MultiplayerManager` (5 sites) are the densest.
3. **Cooking mini-game physics timers** (`HeatPanMiniGame`, `CookTimerMiniGame`, `ChopMiniGame`) — breaks on ProMotion 120 Hz.

### Next sprint (P2 — before App Review)
4. **Inline gender checks** — 11+ sites. One `profilePoseImage` call each; highest-value fix-to-impact ratio.
5. **Deprecated `NavigationView`** — 4 files; `NavigationStack` is a drop-in replacement.
6. **`UIScreen.main.bounds.width`** in `GardenView.swift` — one `GeometryReader` wrapper fixes it.

### Cleanup pass (P3)
7. **Hardcoded animation curves** — 14 files; swap to `AnimationConstants.*` tokens.
8. **Hardcoded spacing / sizing** — 25+ files; swap to `AppSpacing.*` tokens.
9. **Button style violations** — 8 files; apply `.texturedButton(tint:)` or `BouncyButtonStyle()`.
10. **Raw `Image(...)` with hardcoded frame** — 7 files; swap to `PipSize` enum.
11. **Hardcoded device branches** — 3 files; swap to `AdaptiveCardSize.*`.
12. **Shadow color violations** — 4 files; swap to `Color.AppTheme.sepia.opacity(N)`.
13. **Hardcoded font violations** — `ProfilePickerView.swift`.

---

*Review completed 2026-06-14. All files read from disk; findings reflect current state of `ChefAcademy/` source tree.*
