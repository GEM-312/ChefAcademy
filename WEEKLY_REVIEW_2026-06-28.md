# ChefAcademy — Weekly Code Review
**Date:** 2026-06-28  
**Reviewer:** Automated routine (Claude Sonnet 4.6)

---

## 1. Files Read (Step 0 Confirmation)

**Style/architecture files read in full:**
- `ChefAcademy/AppTheme.swift`
- `ChefAcademy/AdaptiveLayout.swift`
- `ChefAcademy/PipComponents.swift`
- `CLAUDE.md` (root)

**Swift files scanned:** 89 files under `ChefAcademy/` (full list in §8 Clean Scans)

---

## 2. TL;DR

**Status: 🟡 YELLOW**

| Category | Count | Severity |
|---|---|---|
| STALE-UI / Concurrency | 2 confirmed data-race bugs + 8 async dispatch patterns | P1 |
| SwiftData `try?` saves | 13 violations | P1 |
| Hardcoded animations | ~38 instances across 9 files | P2 |
| Black shadows (non-DEV) | 3 instances | P2 |
| `profilePoseImage` bypasses | 8 instances | P2 |
| Raw `Image("pip_*")` bypasses | 4 instances | P3 |
| Hardcoded fonts (ProfilePickerView iPad path) | 2 instances | P2 |

No regressions in the core game loop (Garden harvest, cooking mini-games, weather overlays are structurally sound). The P1s are all pre-existing — none introduced this week.

---

## 3. [STALE-UI] Findings

### STALE-UI-01 — P1 · `MultiplayerManager.swift:240` · Timer + DispatchQueue combo: data race on captured `count`

**Root cause:** The `countdownTimer` callback mutates captured `var count` directly on the RunLoop/thread-pool thread (wherever Timer fires), then hops to main via `DispatchQueue.main.async`. The mutation `count -= 1` is a data race — no actor isolation protects it. Under Swift 6 strict concurrency this is a compile-time error.

```swift
// CURRENT (MultiplayerManager.swift:237-252) — data race on `count`
var count = 3
countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
    count -= 1                          // ← OFF main thread — race!
    DispatchQueue.main.async {          // ← doubly wrong per §2
        if count > 0 {
            self?.matchPhase = .countdown(count)
        } else {
            timer.invalidate()
            self?.countdownTimer = nil
            self?.matchPhase = .playing
        }
    }
}

// FIX — move ALL mutation inside Task { @MainActor }
var count = 3
countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
    Task { @MainActor [weak self] in
        count -= 1
        if count > 0 {
            self?.matchPhase = .countdown(count)
        } else {
            timer.invalidate()
            self?.countdownTimer = nil
            self?.matchPhase = .playing
        }
    }
}
```

**Symptom:** Countdown value can desync (count decrements off-main, UI update on main sees stale value); rare but non-deterministic.

---

### STALE-UI-02 — P1 · `NearbyMultiplayerManager.swift:198` · Identical pattern

Exact same Timer + DispatchQueue.main.async combo on `count` as STALE-UI-01. Same race, same fix.

```swift
// CURRENT (NearbyMultiplayerManager.swift:195-210) — same data race
countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
    count -= 1                          // ← OFF main thread
    DispatchQueue.main.async { ... }    // ← banned per §2
}
```

---

### STALE-UI-03 — P1 · 8 files · `DispatchQueue.main.async` touching `@Published` from background callbacks

Architecture Rule §2: *"async/await + await MainActor.run { ... } for any code touching @Published from a background context."* `DispatchQueue.main.async` does not integrate with Swift concurrency's actor isolation model — it can mask data-race warnings and won't emit errors under strict concurrency.

| File | Lines | Context |
|---|---|---|
| `AuthManager.swift` | 113 | `ASAuthorizationAppleIDProvider.getCredentialState` closure |
| `GameCenterService.swift` | 102 | `GKLocalPlayer.authenticateHandler` |
| `GameCenterMatchmakerView.swift` | 42, 50, 59 | `GKMatchmakerViewControllerDelegate` callbacks |
| `MultiplayerManager.swift` | 65, 196, 297, 321 | Auth handler + `GKMatchDelegate` |
| `NearbyMultiplayerManager.swift` | 155, 221, 241, 286, 308 | `MCSessionDelegate` + message handler |
| `ParentPINEntryView.swift` | 134 | Apple ID verification completion closure |

**Fix pattern (same for all):**
```swift
// Before:
DispatchQueue.main.async { [weak self] in
    self?.matchPhase = .playing
}

// After:
Task { @MainActor [weak self] in
    self?.matchPhase = .playing
}
```

**Note on `SeedInfoView.swift:222`:** The `DispatchQueue.main.async` inside `UIViewRepresentable.updateUIView` is used to defer a `@Binding` reset to avoid "modifying state during view update." This is a UIKit-bridge workaround pattern — replace with `Task { @MainActor in }` per §2, but the underlying need is legitimate.

---

## 4. [PERF] Findings

No new performance regressions identified beyond the concurrency issues above. Specific items already tracked:

- `GardenView.swift` — ConnectablePublisher pattern already fixed (May 2 bugfix confirmed at line 667). ✓  
- All `Timer.scheduledTimer` callbacks in gameplay files (PlotView, CookingMiniGames, ChopMiniGame, WaterPourCharacterView, SplitScreenVersusView, NearbyVersusView, LocalVersusView, HealthyChoiceGameView, FamilySetupView, OnboardingView, SessionManager) correctly wrap mutations in `Task { @MainActor in }`. ✓

### PERF-01 — P1 (SwiftData) · 13 `try?` save violations — silent data loss

Architecture Rule §1: *"never `try?`. Silent failures destroyed child profiles for a week."*

| File | Lines |
|---|---|
| `SessionManager.swift` | 100, 206, 355, 419, 454 |
| `ParentDashboardView.swift` | 461, 490 |
| `SiblingGardenView.swift` | 36, 176 |
| `FamilySetupView.swift` | 204 |
| `AddChildFlowView.swift` | 132 |
| `SiblingProfileView.swift` | 275 |
| `AllergenEditorSheet.swift` | 119 |
| `ChefAcademyApp.swift` | 464 |

**Fix (all sites):**
```swift
// Before:
try? modelContext.save()

// After:
do { try modelContext.save() } catch { print("[Error] SwiftData save failed: \(error)") }
```

---

## 5. [HARDCODE] Findings

### Category A — Hardcoded colors / shadows

**A-01 · `GardenView.swift:114, 352` — `Color.black.opacity(0.2)` in Pip drag shadow**
```swift
// Current:
.shadow(color: isDragging ? Color.AppTheme.sage.opacity(0.4) : Color.black.opacity(0.2), ...)

// Fix:
.shadow(color: isDragging ? Color.AppTheme.sage.opacity(0.4) : Color.AppTheme.sepia.opacity(0.2), ...)
```

**A-02 · `ChopMiniGame.swift:167` — `.black.opacity(0.2)` on chop indicator circle**
```swift
// Current:
.shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

// Fix:
.shadow(color: Color.AppTheme.sepia.opacity(0.2), radius: 2, x: 0, y: 1)
```

**A-03 · `FarmShopView.swift:581` (inside `#if DEBUG`) — `.black.opacity(0.5)` and `.white` on pencil icon**
```swift
// Current:
.foregroundColor(editMode ? Color.AppTheme.terracotta : .white)
.shadow(color: .black.opacity(0.5), radius: 4)

// Fix:
.foregroundColor(editMode ? Color.AppTheme.terracotta : Color.AppTheme.pureWhite)
.shadow(color: Color.AppTheme.darkBrown.opacity(0.5), radius: 4)
```
*(Lower priority: inside `#if DEBUG` block — release builds unaffected)*

**SceneEditor.swift** — Many raw `Color.black/white/red/green/gray` uses throughout. DEV-only file, not user-facing. Note only; fix when convenient.

---

### Category B — Hardcoded fonts

**B-01 · `ProfilePickerView.swift:39` — iPad path uses `.system(size: 40, ...)` instead of AppTheme token**
```swift
// Current:
.font(isIPad ? .system(size: 40, weight: .bold, design: .rounded) : .AppTheme.largeTitle)

// Fix — add to AppTheme.swift first:
// static let profilePickerTitle = Font.system(size: 40, weight: .bold, design: .rounded)

.font(isIPad ? .AppTheme.profilePickerTitle : .AppTheme.largeTitle)
```
*(Alternatively, use `.adaptiveFont(compact: 34, regular: 40)` from `AdaptiveLayout.swift`)*

**B-02 · `ProfilePickerView.swift:86` — iPad path uses `.system(size: 22, ...)` but `Font.AppTheme.title2` (22pt semibold) already exists**
```swift
// Current:
.font(isIPad ? .system(size: 22, weight: .semibold, design: .rounded) : .AppTheme.headline)

// Fix (token already exists!):
.font(isIPad ? .AppTheme.title2 : .AppTheme.headline)
```

---

### Category C — Hardcoded dimensions / device branches

**C-01 · `ProfilePickerView.swift:26` — raw `isIPad ? 280 : 120` for Pip size**

`AdaptiveCardSize.pipMessage(for: sizeClass)` returns exactly `280` iPad / `140` iPhone, which is close. The 120→140 difference can be absorbed. Add a specific token if the 120 is intentional:
```swift
// Current:
private var pipSize: CGFloat { isIPad ? 280 : 120 }

// Fix option A (use existing token, minor visual difference):
PipWavingAnimatedView(size: AdaptiveCardSize.pipMessage(for: sizeClass))

// Fix option B (add token to AdaptiveCardSize):
// static func profilePickerPip(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
//     sizeClass == .compact ? 120 : 280
// }
```

**C-02 · `ProfilePickerView.swift:154-156` (ProfileCard) — three raw iPad/iPhone sizes for avatar/circle/card**
```swift
// Current:
private var avatarSize: CGFloat { isIPad ? 200 : 80 }
private var circleSize: CGFloat { isIPad ? 220 : 90 }
private var cardWidth:  CGFloat { isIPad ? 280 : 120 }

// Fix — add to AdaptiveCardSize:
// static func profileCardAvatar(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
//     sizeClass == .compact ? 80 : 200
// }
// static func profileCardCircle(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
//     sizeClass == .compact ? 90 : 220
// }
// static func profileCardWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
//     sizeClass == .compact ? 120 : 280
// }
```

---

### Category D — Hardcoded animations

**D-01 · `GlucoseJourneyView.swift` — 13 inline animation values**

Most map to existing tokens:

| Line | Current | Fix |
|---|---|---|
| 390 | `.spring(response: 0.5)` | `AnimationConstants.springSlow` |
| 391 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 485 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 569 | `.spring(response: 0.4, dampingFraction: 0.6)` | `AnimationConstants.springMedium` |
| 771 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 786 | `.spring(response: 0.4)` | `AnimationConstants.springMedium` |
| 787 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 874 | `.easeInOut(duration: 0.6)` | `AnimationConstants.revealMedium` *(new token — see §7)* |
| 897 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 905 | `.spring(response: 0.4).delay(0.2)` | `AnimationConstants.springMedium.delay(0.2)` |
| 1005 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 1214 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 1242 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |

**D-02 · `WeatherOverlayView.swift` — 9 inline animation loop values (need new weather tokens)**

These are all weather-specific perpetual loops with unique durations that don't fit any existing token:

| Lines | Current | Needed token |
|---|---|---|
| 81, 117, 736 | `.easeInOut(duration: 3).repeatForever(autoreverses: true)` | `AnimationConstants.weatherPulseSlow` |
| 114 | `.easeInOut(duration: 8).repeatForever(autoreverses: true)` | `AnimationConstants.weatherDriftSlow` |
| 147 | `.easeInOut(duration: 10).repeatForever(autoreverses: true)` | `AnimationConstants.weatherDriftVerySlow` |
| 150 | `.easeInOut(duration: 7).repeatForever(autoreverses: true)` | `AnimationConstants.weatherDriftMedium` |
| 484 | `.easeInOut(duration: 2).repeatForever(autoreverses: true)` | `AnimationConstants.weatherFlicker` |
| 487 | `.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.3)` | `AnimationConstants.weatherFlickerB` |
| 490 | `.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.7)` | `AnimationConstants.weatherFlickerC` |
| 732 | `.linear(duration: 20).repeatForever(autoreverses: false)` | `AnimationConstants.weatherSpinSlow` |

All 8 need to be added to `AnimationConstants` in `AppTheme.swift` under a `// Weather overlay loops` comment block.

**D-03 · `CookingMiniGames.swift` — 8 inline values**

| Line | Current | Fix |
|---|---|---|
| 88 | `.linear(duration: 0.05)` | Intentional real-time progress bar — needs `AnimationConstants.progressTick` |
| 469 | `.easeIn(duration: 0.6)` | `AnimationConstants.revealSlow` (0.5s, close enough) or new `revealMedium` |
| 577, 958 | `.easeOut(duration: 0.3)` | `AnimationConstants.fadeMedium` |
| 963 | `.easeIn(duration: 0.3)` | `AnimationConstants.fadeMedium` |
| 977 | `.easeOut(duration: 0.4)` | `AnimationConstants.fadeMedium` (or new `fadeMediumOut`) |
| 1160 | `.easeOut(duration: 0.2)` | `AnimationConstants.fadeFast` |
| 1219 | `.easeOut(duration: 1.0)` | `AnimationConstants.revealSlow` |

**D-04 · Other files (single instances)**

| File | Line | Current | Fix |
|---|---|---|---|
| `AskPipView.swift` | 446 | `.easeInOut(duration: 0.4)` | `AnimationConstants.fadeMedium` |
| `CookingSessionView.swift` | 523 | `.easeInOut(duration: 0.4)` | `AnimationConstants.fadeMedium` |
| `BodyBuddyView.swift` | 92 | `.easeOut(duration: 1.0).delay(0.3)` | `AnimationConstants.ringReveal` *(new token)* |
| `BodyBuddyView.swift` | 429, 443 | `.easeOut(duration: 0.8).delay(0.2)` | new `revealSlow.delay(0.2)` or token |
| `BodyBuddyView.swift` | 507 | `.easeOut(duration: 1.0)` | `AnimationConstants.revealSlow` |
| `PlotView.swift` | 424 | `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` | `AnimationConstants.waterDropBounce` *(new)* |
| `GardenView.swift` | 765 | `.spring(response: 0.3, dampingFraction: 0.7)` | `AnimationConstants.springQuick` |
| `GardenView.swift` | 1174 | `.easeIn(duration: 0.6)` | `AnimationConstants.revealSlow` |
| `FamilySetupView.swift` | 261, 1064 | `.easeOut(duration: 0.8)` | needs new `AnimationConstants.revealMediumOut` |
| `FamilySetupView.swift` | 1176 | `.easeOut(duration: 0.6)` | `AnimationConstants.revealSlow` |

---

### Category E — Hardcoded device branches (ProfilePickerView)

See C-01, C-02, B-01, B-02 above — all in `ProfilePickerView.swift`.

---

### Category F — Hand-rolled surfaces

No new hand-rolled card/button surfaces found in non-DEV files. All `RoundedRectangle` usages are legitimate (clip shapes, canvas drawing, game-specific fill indicators, or use AppSpacing token corner radii). ✓

---

### Category G — Inline Pip + gender image patterns

**G-01 · `profilePoseImage` bypassed in 8 places**

Architecture Rule §4: "use `UserProfile.profilePoseImage` — never inline `gender == .boy ? "boy_card_clean_..." : "girl_card_clean_..."."

| File | Lines | Fix |
|---|---|---|
| `SplitScreenVersusView.swift` | 111 | `Image(child.profilePoseImage)` |
| `LocalVersusView.swift` | 199, 404, 436, 462 | `Image(player.profilePoseImage)` |
| `MultiplayerHealthyPicksView.swift` | 600 | `Image(profile.profilePoseImage)` |
| `ChefAcademyApp.swift` | 669 | `Image(sibling.profilePoseImage)` |
| `SiblingProfileView.swift` | 26 | `Image(sibling.profilePoseImage)` |
| `ParentDashboardView.swift` | 506 | `Image(profile.profilePoseImage)` |
| `AvatarCreatorView.swift` | 114 | Builds on `AvatarModel`, which has no `profilePoseImage` helper. Add `var previewImageName: String` to `AvatarModel` that mirrors the same logic. |

**Not flagged:** `WaterPourCharacterView.swift:35` — uses `gender` to select *water-pouring animation frames* (`girl_pours_water_frame` / `boy_pours_water_frame`), not card images. This is intentional. ✓  
**Not flagged:** `FamilySetupView.swift:373, 396` — uses the final frame of a costume animation sequence, which serves as the "landing" frame, not a profile display. Minor but acceptable in animation context.

---

### Category H — Raw `Image("pip_*")` bypassing PipSize/PipComponents

**H-01 · `NearbyVersusView.swift:362`** — `Image("pip_got_idea")` with dynamic `.frame(width: 80 * pipScale, height: 80 * pipScale)`
```swift
// Current:
Image("pip_got_idea")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 80 * pipScale, height: 80 * pipScale)

// Fix — anchor to PipSize.medium (80pt), let pipScale drive variance:
Image(PipPose.gotIdea.rawValue)
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: PipSize.medium.points * pipScale, height: PipSize.medium.points * pipScale)
```

**H-02 · `InsulinTetrisView.swift:611`** — `Image("pip_got_idea")` with no size token — add `.frame(width: PipSize.large.points, height: PipSize.large.points)`

**H-03 · `OnboardingView.swift:118`** — `Image("pip_got_idea")` — add PipSize

**H-04 · `GardenView.swift:99`** — `Image("pip_got_idea")` — comment says "replace with walking sprite later." Known placeholder; track but low urgency.

**H-05 · `GardenView.swift:1484`** — `Image("pip_waving_frame_01")` — raw single frame of waving animation. Consider replacing the still with `PipWavingAnimatedView` if the context supports animation.

---

## 6. [REFACTOR-COMPONENT] Suggestions

### RC-01 · Add `previewImageName` to `AvatarModel`

`AvatarCreatorView.swift:114` needs to preview the final avatar image before a `UserProfile` is created (no `profilePoseImage` available yet). The current inline `avatarModel.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"` should move to a helper on `AvatarModel`:

```swift
// In AvatarModel.swift
var previewImageName: String {
    gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"
}
```

This gives one place to update when non-binary assets land (K-01 roadmap item).

### RC-02 · Gender-based profile image (7 call sites)

Seven views repeat the same `gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"` lookup on a `UserProfile`. All should use the existing `profilePoseImage` computed property on `UserProfile` — which already handles the parent/child-role distinction. The fix is pure deletion, not new code.

---

## 7. Missing Tokens

The following tokens need to be added before the corresponding hardcode violations can be fixed.

### Add to `AnimationConstants` in `AppTheme.swift`:

```swift
// Weather overlay loops — perpetual ambient animations per weather state.
// These run forever on the overlay layer and cannot reuse shorter game tokens.
static let weatherPulseSlow      = Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)
static let weatherDriftSlow      = Animation.easeInOut(duration: 8.0).repeatForever(autoreverses: true)
static let weatherDriftMedium    = Animation.easeInOut(duration: 7.0).repeatForever(autoreverses: true)
static let weatherDriftVerySlow  = Animation.easeInOut(duration: 10.0).repeatForever(autoreverses: true)
static let weatherFlicker        = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
static let weatherFlickerB       = Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)
static let weatherFlickerC       = Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
static let weatherSpinSlow       = Animation.linear(duration: 20.0).repeatForever(autoreverses: false)

// Easing reveal — 0.6s for mid-length content reveals (sits between fadeMedium 0.3s and revealSlow 0.5s)
static let revealMedium          = Animation.easeInOut(duration: 0.6)

// Organ health ring reveal — delayed entry animation used by BodyBuddyView
static let ringReveal            = Animation.easeOut(duration: 1.0).delay(0.3)

// Water drop bounce — PlotView watering progress bar animation
static let waterDropBounce       = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)

// Progress bar tick — real-time HeatPan progress bar update (very short, linear)
static let progressTick          = Animation.linear(duration: 0.05)
```

### Add to `AdaptiveCardSize` in `AdaptiveLayout.swift`:

```swift
/// Profile card avatar image size (ProfilePickerView + ProfileCard)
static func profileCardAvatar(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
    sizeClass == .compact ? 80 : 200
}

/// Profile card background circle size
static func profileCardCircle(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
    sizeClass == .compact ? 90 : 220
}

/// Profile card total width
static func profileCardWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
    sizeClass == .compact ? 120 : 280
}
```

### Add to `Font.AppTheme` in `AppTheme.swift` (optional, `adaptiveFont` works too):

```swift
// Profile picker hero title — larger than largeTitle for iPad prominence
static let profilePickerTitle = Font.system(size: 40, weight: .bold, design: .rounded)
```

---

## 8. Clean Scans — No Regressions Found

The following files were read and found clean (no violations in any category):

**Timer pattern (all correct — `Task { @MainActor in }` wrapping):**  
`PlotView.swift`, `CookingMiniGames.swift`, `ChopMiniGame.swift`, `WaterPourCharacterView.swift`, `HealthyChoiceGameView.swift`, `SplitScreenVersusView.swift`, `NearbyVersusView.swift`, `LocalVersusView.swift`, `GardenWeatherService.swift`, `OnboardingView.swift`, `FamilySetupView.swift` (animation timers), `SessionManager.swift`, `PipGameAnimationView.swift`, `PipAnimations.swift` (waving/walking), `AvatarAnimator` (class-level, `@MainActor`)

**ConnectablePublisher anti-pattern:**  
`GardenView.swift` — fixed May 2 (confirmed by comment at line 667). ✓

**SwiftData `@Relationship` (none found):**  
`FamilyProfile.swift`, `UserProfile.swift`, `PlayerData.swift` — all use UUID linking correctly. ✓

**`try? save` (clean):**  
`GameState.swift`, `ProfilePickerView.swift`, `PlantingSheet.swift`, `KitchenView.swift`, `BodyBuddyView.swift`, `RecipeDetailView.swift`, `CookingSessionView.swift`, `CookingCompletionView.swift`

**Hardcoded values (clean):**  
`PipDialogView.swift`, `MorphTransition.swift`, `BackgroundView.swift`, `PipVoice.swift`, `PipStaticResponses.swift`, `AmbientAudioPlayer.swift`, `SeededRandomGenerator.swift`, `AssetPackController.swift`, `AssetPackImage.swift`, `VideoPlayerView.swift`, `VoicePickerView.swift`, `SubscriptionManager.swift`, `WorkerClient.swift`, `AppAttestService.swift`, `PINKeychain.swift`, `AuthManager.swift` (colors), `ElevenLabsVoiceService.swift`, `USDAFoodService.swift`, `PipAIService.swift`, `PipFoundationModelService.swift`, `AllergenEditorSheet.swift` (colors), `AllergenPickerStep.swift` (colors), `RecipeCardExample.swift`, `Allergen.swift`, `AvatarModel.swift`, `FamilyProfile.swift`, `PlayerData.swift`, `UserProfile.swift`

**Intentional patterns (not flagged):**  
- `SeedInfoView.swift` — `ColorChoice.color` returning `.red/.orange/.yellow/.green` is intentional plant-pigment science education per CLAUDE.md §9. These are not UI chrome colors; they represent the actual hue of the food.  
- `WaterPourCharacterView.swift:35` — gender-based frame selection is for water-pouring animation frames (not profile card images). ✓  
- `PipAnimations.swift:489` — `.easeInOut(duration: speed)` uses a caller-supplied variable, not a literal. ✓  
- `GardenHubView.swift` — orphaned dead code, skip per CLAUDE.md §9. ✓

---

*End of review — 2026-06-28*
