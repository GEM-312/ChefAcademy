# Weekly Code Review — 2026-06-16

## 1. Files Read (Step 0 Confirmation)

**Style/architecture files read in full:**
- `ChefAcademy/AppTheme.swift` (colors, fonts, spacing, animations, button styles)
- `ChefAcademy/AdaptiveLayout.swift` (device detection, AdaptiveCardSize tokens, trailingFade)
- `ChefAcademy/PipComponents.swift` (PipSize, PipSpeechBubble, PipHeaderStack, PINPadGrid)

**Swift files scanned: 89 total** (full list in `find ChefAcademy -name '*.swift' -type f | sort`; confirmed complete including AllergenEditorSheet.swift and AllergenPickerStep.swift which are not listed in the CLAUDE.md project structure but are present)

---

## 2. TL;DR

🔴 **RED** — P0 violations present in shipping code. `try? save()` (§1 ban) found in **18 call sites** across 7 files including SessionManager.swift (10 occurrences). `DispatchQueue.main.async` (§2 ban) found in **15 sites** across 5 files. Both patterns have caused production data loss and data-race warnings in the past.

**Count by category:**
- [STALE-UI / CONCURRENCY] 6 findings (1 P0, 3 P1, 2 P2)
- [HARDCODE-COLOR] 5 findings (production files only; SceneEditor is DEV-only, omitted)
- [HARDCODE-ANIMATION] 30+ findings across 10 files (grouped by file below)
- [HARDCODE-DIMENSION] scattered (see section 5C)
- [COMPONENT-REUSE: profilePoseImage bypass] 12 call sites across 7 files (P1)
- [SWIFTDATA: try? save()] 18 call sites across 7 files (P0)

---

## 3. [STALE-UI] Findings

### STALE-UI-1 · P0 · `try? save()` everywhere in SessionManager.swift

**Files:** `SessionManager.swift` lines 100, 206, 230, 271, 294, 355, 373, 419, 454, 465 (10 occurrences)

**Root cause:** Every SwiftData save in SessionManager silently swallows errors. Architecture §1 is explicit: *"Use `do { try save() } catch { print(error) }` — never `try?`. Silent failures destroyed child profiles for a week (March bug)."*

These are the highest-risk save sites in the entire app: profile selection, play-time recording, PIN clearing, child creation, and app-background saves all go silent on failure.

**Fix pattern (apply to all 10 sites):**
```swift
// Before:
try? context.save()

// After:
do {
    try context.save()
} catch {
    print("[SessionManager] SwiftData save failed: \(error)")
}
```

**Same violation in 6 other files:**
- `FamilySetupView.swift:204`
- `ParentDashboardView.swift:461, 490`
- `AllergenEditorSheet.swift:119`
- `ChefAcademyApp.swift:464`
- `SiblingProfileView.swift:275`
- `SiblingGardenView.swift:36`

**Total: 18 call sites — all must be converted before next session.**

---

### STALE-UI-2 · P1 · `DispatchQueue.main.async` in multiplayer managers (§2 ban)

**Files:**
- `NearbyMultiplayerManager.swift:155, 200, 221, 241, 286, 308` (6 occurrences)
- `MultiplayerManager.swift:65, 196, 242, 297, 321` (5 occurrences)

**Root cause:** MCSession/MultipeerConnectivity and GKMatch delegates call back on background threads. Both files hop to main with `DispatchQueue.main.async` to update `@Published` properties. Architecture §2 bans this and requires `await MainActor.run { }` or `Task { @MainActor in }` for any `@Published` mutation from a background context. The difference matters under Swift 6 strict concurrency: `DispatchQueue.main.async` is not actor-isolated and will produce data-race warnings.

**Most concerning instance** — Timer + DispatchQueue.main.async combined:

```swift
// NearbyMultiplayerManager.swift:198–208 (also MultiplayerManager.swift:240–252)
countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
    count -= 1
    DispatchQueue.main.async {          // ← two violations: Timer callback + DispatchQueue
        if count > 0 {
            self?.matchPhase = .countdown(count)
        } else {
            timer.invalidate()
            self?.matchPhase = .playing
        }
    }
}
```

**Fix:**
```swift
countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
    count -= 1
    Task { @MainActor [weak self] in
        guard let self else { return }
        if count > 0 {
            self.matchPhase = .countdown(count)
        } else {
            timer.invalidate()
            self.countdownTimer = nil
            self.matchPhase = .playing
        }
    }
}
```

Apply the same `Task { @MainActor in }` pattern to all MCSession/GKMatch delegate callbacks in both files.

---

### STALE-UI-3 · P1 · `DispatchQueue.main.async` in other callbacks

**Files:**
- `GameCenterService.swift:102` — `GKLocalPlayer.authenticateHandler` callback
- `GameCenterMatchmakerView.swift:42, 50, 59` — GKMatchmakerViewController delegate
- `AuthManager.swift:113` — `ASAuthorizationAppleIDProvider` credential state callback
- `ParentPINEntryView.swift:134` — Sign in with Apple completion handler

These are all UIKit/GameKit/AuthServices callbacks that fire on non-main threads. All use `DispatchQueue.main.async` to hop to main.

**Fix (same pattern for all):**
```swift
// Before (GameCenterService.swift:102):
GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
    DispatchQueue.main.async {
        // ... mutations ...
    }
}

// After:
GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
    Task { @MainActor [weak self] in
        guard let self else { return }
        // ... mutations ...
    }
}
```

**Special case — `SeedInfoView.swift:222`:** Uses `DispatchQueue.main.async` inside a UIViewRepresentable coordinator callback to reset a `@Binding`. This is a narrow UIKit bridge context — acceptable to convert to `Task { @MainActor in }` for consistency.

---

### STALE-UI-4 · P1 · `SplitScreenVersusView.swift:579` — countdown timer not stored

**File:** `SplitScreenVersusView.swift:577–588`

**Root cause:** The view declares `@State private var spawnTimer: Timer?` (stored, can be invalidated), but the countdown timer created in `startCountdown()` is **not** assigned to a stored variable:

```swift
private func startCountdown() {
    countdownValue = 3
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in  // ← no @State storage
        Task { @MainActor in
            countdownValue -= 1
            if countdownValue <= 0 {
                timer.invalidate()  // ← only invalidated if countdown completes naturally
                startGame()
            }
        }
    }
}
```

If the user navigates away before `countdownValue` reaches zero, the timer keeps firing indefinitely. The `Task { @MainActor in }` means the `@State` write is safe but wasteful. No `.onDisappear` cleanup is wired.

**Fix:**
```swift
@State private var countdownTimer: Timer?

private func startCountdown() {
    countdownValue = 3
    countdownTimer?.invalidate()
    countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
        Task { @MainActor in
            countdownValue -= 1
            if countdownValue <= 0 {
                timer.invalidate()
                countdownTimer = nil
                startGame()
            }
        }
    }
}

// In the view body's .onDisappear:
.onDisappear {
    countdownTimer?.invalidate()
    countdownTimer = nil
    spawnTimer?.invalidate()
    spawnTimer = nil
}
```

---

### STALE-UI-5 · P2 · `AskPipView.swift` typing indicator — inline animation with hardcoded duration

**File:** `AskPipView.swift:445–449`

The bouncing-dot typing indicator uses a raw inline animation:
```swift
.animation(
    .easeInOut(duration: 0.4)
    .repeatForever()
    .delay(Double(i) * 0.15),
    value: aiService.isLoading
)
```

This is both a hardcoded animation violation (§3) and a stale-UI risk: the animation repeats forever and is tied to `aiService.isLoading`. If the view is dismissed while `isLoading` is true (network timeout, navigation), the animation continues on the `@StateObject`'s `@Published` value. Consider using `.task` to cancel the loading state on disappear, and replace the inline animation with `AnimationConstants.fadeMedium.repeatForever()`.

---

### STALE-UI-6 · P2 · `PlotView.swift:428` — Timer.scheduledTimer for water progress

**File:** `PlotView.swift:424–441`

```swift
withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
    waterDropY = 10
}
waterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
    Task { @MainActor in
        waterProgress += 0.015
        ...
    }
}
```

The Timer wrapping is correct (`Task { @MainActor in }`), and `waterTimer` is stored so it can be invalidated. However, 0.05s interval (20fps) for a `@State` update loop is heavy. The `withAnimation(.easeInOut(duration: 0.6).repeatForever(...))` is also a hardcoded animation violation (closest token: `AnimationConstants.floatLoop`). No critical stale-state risk here but the Timer-based progress loop should migrate to `TimelineView(.animation)` per §2 ("Game physics loops use TimelineView(.animation) with delta-time").

---

## 4. [PERF] Findings

### PERF-1 · `GardenWeatherService.swift:330` — Timer-based 30-min refresh on main RunLoop

The weather service creates a `Timer.scheduledTimer(withTimeInterval: cacheInterval, repeats: true)` that wraps its callback in `Task { @MainActor in }` (correct pattern). However, a 30-minute repeating Timer on the main RunLoop means the timer fires even when the app is backgrounded. The `Task { @MainActor in }` protects the `@Published` mutation, but the timer resource itself is never cleaned up on `scenePhase` change. Consider replacing with a background `Task` loop that checks `Date()` and sleeps, respecting cancellation when the scene goes background.

### PERF-2 · `AskPipView.swift` — heavy context assembly on every `.onAppear`

`injectGameContext()` is called once on appear. It does 8 separate calls to PipAIService, each rebuilding context from GameState. This is fine for correctness, but if AskPipView is repeatedly shown/dismissed (paywall rejection → re-open), the context is rebuilt each time including recipe iteration (`GardenRecipes.all.filter {...}`) which touches an O(n×m) allergen check. Not urgent; note for when recipe count grows beyond current ~20.

---

## 5. [HARDCODE] Findings

### 5A. Hardcoded Colors

| File | Line | Current | Correct Token |
|------|------|---------|---------------|
| `GardenView.swift` | 114, 352 | `Color.black.opacity(0.2)` (shadow) | `Color.AppTheme.sepia.opacity(0.2)` |
| `AllergenPickerStep.swift` | 142 | `.foregroundColor(.white)` | `.foregroundColor(Color.AppTheme.cream)` |
| `FarmShopView.swift` | 345 | `.foregroundColor(.white)` | `.foregroundColor(Color.AppTheme.cream)` |
| `RecipeDetailView.swift` | 78 | `.foregroundColor(.white)` | `.foregroundColor(Color.AppTheme.cream)` |
| `AvatarCreatorView.swift` | 400 | `.foregroundColor(.white)` | `.foregroundColor(Color.AppTheme.cream)` |

**GardenView.swift:114,352 — before/after:**
```swift
// Before:
.shadow(
    color: isDragging ? Color.AppTheme.sage.opacity(0.4) : Color.black.opacity(0.2),
    ...
)

// After:
.shadow(
    color: isDragging ? Color.AppTheme.sage.opacity(0.4) : Color.AppTheme.sepia.opacity(0.2),
    ...
)
```

**Note:** `SceneEditor.swift` has many `.foregroundColor(.white)`, `.foregroundColor(.yellow)`, `.foregroundColor(.cyan)`, `.foregroundColor(.green)`, and `Color.black.opacity(0.85)` violations. These are in a **DEV-only** tool (never shown to users) — flag for awareness but not blocking.

---

### 5B. Hardcoded Animations

Sorted by severity. All need AppTheme tokens per §3.

**`WeatherOverlayView.swift`** — 9 inline animations, all for ambient weather effects:

| Line | Current | Recommended Fix |
|------|---------|-----------------|
| 81 | `.easeInOut(duration: 3).repeatForever(autoreverses: true)` | Add `AnimationConstants.weatherPulse` token |
| 114 | `.easeInOut(duration: 8).repeatForever(autoreverses: true)` | Add `AnimationConstants.weatherCloudDrift` token |
| 117 | `.easeInOut(duration: 3).repeatForever(autoreverses: true)` | reuse `weatherPulse` |
| 147 | `.easeInOut(duration: 10).repeatForever(autoreverses: true)` | reuse `weatherCloudDrift` |
| 150 | `.easeInOut(duration: 7).repeatForever(autoreverses: true)` | Add `AnimationConstants.weatherCloudDriftFast` |
| 484 | `.easeInOut(duration: 2).repeatForever(autoreverses: false)` | Add `AnimationConstants.weatherLightningStrike` |
| 487 | `.easeInOut(duration: 2.5).repeatForever(...)` | reuse `weatherLightningStrike` with delay |
| 490 | `.easeInOut(duration: 1.8).repeatForever(...)` | reuse `weatherLightningStrike` |
| 736 | `.easeInOut(duration: 3).repeatForever(autoreverses: true)` | reuse `weatherPulse` |

**`CookingMiniGames.swift`** — 6 inline animations:

| Line | Current | Recommended |
|------|---------|-------------|
| 469 | `.easeIn(duration: 0.6)` | `AnimationConstants.revealSlow` |
| 577 | `.easeOut(duration: 0.3)` | `AnimationConstants.fadeMedium` |
| 958 | `.easeOut(duration: 0.3)` | `AnimationConstants.fadeMedium` |
| 963 | `.easeIn(duration: 0.3)` | `AnimationConstants.fadeMedium` |
| 977 | `.easeOut(duration: 0.4)` | `AnimationConstants.fadeFast` |
| 1160 | `.easeOut(duration: 0.2)` | `AnimationConstants.fadeFast` |
| 1219 | `.easeOut(duration: 1.0)` | `AnimationConstants.weatherTransition` (1.0s easeInOut already exists) |

**`BodyBuddyView.swift`** — 4 inline animations:

| Line | Current | Recommended |
|------|---------|-------------|
| 92 | `.easeOut(duration: 1.0).delay(0.3)` | `AnimationConstants.weatherTransition.delay(0.3)` |
| 429 | `.easeOut(duration: 0.8).delay(0.2)` | `AnimationConstants.revealSlow.delay(0.2)` |
| 443 | `.easeOut(duration: 0.8).delay(0.2)` | `AnimationConstants.revealSlow.delay(0.2)` |
| 507 | `.easeOut(duration: 1.0)` | `AnimationConstants.weatherTransition` |

**`AskPipView.swift`** — 3 inline animations:

| Line | Current | Recommended |
|------|---------|-------------|
| 165 | `.easeOut(duration: 0.3)` | `AnimationConstants.fadeMedium` |
| 446 | `.easeInOut(duration: 0.4).repeatForever()` | `AnimationConstants.fadeFast.repeatForever()` |
| 806 | `.easeIn(duration: 0.3).delay(0.5)` | `AnimationConstants.fadeMedium.delay(0.5)` |

**`FamilySetupView.swift`** — 3 inline animations:

| Line | Current | Recommended |
|------|---------|-------------|
| 261 | `.easeOut(duration: 0.8)` | `AnimationConstants.revealSlow` |
| 1064 | `.easeOut(duration: 0.8)` | `AnimationConstants.revealSlow` |
| 1176 | `.easeOut(duration: 0.6)` | `AnimationConstants.revealSlow` (0.5 is close enough) |

**`GardenView.swift`** — 2 inline animations:

| Line | Current | Recommended |
|------|---------|-------------|
| 765 | `.spring(response: 0.3, dampingFraction: 0.7)` | `AnimationConstants.springMedium` |
| 1174 | `.easeIn(duration: 0.6)` | `AnimationConstants.revealSlow` |

**`GlucoseJourneyView.swift`** — 4 inline animations:

| Line | Current | Recommended |
|------|---------|-------------|
| 390 | `.spring(response: 0.5)` | `AnimationConstants.springSlow` |
| 391 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 485 | `.spring(response: 0.3)` | `AnimationConstants.springQuick` |
| 569 | `.spring(response: 0.4, dampingFraction: 0.6)` | `AnimationConstants.springMedium` |

**`PlotView.swift:424`:**
```swift
// Before:
withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {

// After:
withAnimation(AnimationConstants.floatLoop) {
```

**`PipTestView.swift:162`** (DEV view):
```swift
// Before:
withAnimation(.easeOut(duration: 0.3)) {
// After:
withAnimation(AnimationConstants.fadeMedium) {
```

**`ChopMiniGame.swift:186`:**
```swift
// Before:
.animation(.easeOut(duration: 0.1), value: justChopped)
// After:
.animation(AnimationConstants.fadeQuick, value: justChopped)
```

**`MeetPipAnimated.swift:381`:** `.easeIn(duration: Double.random(in: 1.5...2.5))` — random duration for confetti; cannot be a static token. Add `AnimationConstants.confettiFall` with a fixed 2.0s duration and apply jitter only to `.delay(Double.random(in: 0...0.5))` which doesn't violate the rule.

**`HealthyChoiceGameView.swift:410, 812`:**
```swift
// Line 410:
.animation(.easeIn(duration: 2), value: pipFloatingAway)
// → AnimationConstants.pipTransition (0.8s) is nearest; or add a new token

// Line 812:
withAnimation(.easeIn(duration: 1.5)) { pipOffset = -800 }
// → AnimationConstants.revealSlow (0.5s) or add AnimationConstants.pipExit
```

---

### 5C. Hardcoded Dimensions (selected high-impact findings)

The following are hardcoded frame/spacing values in production views where AppSpacing tokens should be used or AdaptiveCardSize tokens should be consulted:

| File | Line | Value | Issue |
|------|------|-------|-------|
| `AskPipView.swift` | 280 | `Color.clear.frame(width: 28, height: 28)` | Header spacer; use `AppSpacing.iconSize` (24) or explicit 28 token |
| `AskPipView.swift` | 431 | `.frame(width: 40, height: 40)` | Pip typing avatar; use `PipSize.compact.points` (40) |
| `AskPipView.swift` | 436 | `.frame(width: 44, height: 44)` | Background circle; use `AppSpacing.minTapTarget` |
| `AskPipView.swift` | 443 | `.frame(width: 8, height: 8)` | Typing dots; no token exists — add `AppSpacing.typingDot` |
| `NearbyVersusView.swift` | 365 | `.frame(width: 80 * pipScale, height: 80 * pipScale)` | Pip; use `PipSize.medium.points * pipScale` |
| `NearbyVersusView.swift` | 302 | `.frame(width: 8, height: 8)` | Score dot; needs `AppSpacing.scoreDot` token |
| `NearbyVersusView.swift` | 534 | `.frame(width: 60, height: 60)` | Food bubble image; no adaptive token — add |
| `SplitScreenVersusView.swift` | 449 | `.frame(width: 40, height: 40)` | Mini food image; no adaptive token |
| `GardenView.swift` | 167, 390, 1497 | `.cornerRadius(6)` | No token for radius=6; use `AppSpacing.pillCornerRadius` (8) or add `AppSpacing.tinyCornerRadius = 6` |

**Note:** `SceneEditor.swift` has many hardcoded font sizes, but it is a DEV-only tool — not surfaced to users. Low priority.

---

### 5D. Hardcoded Device Branches

No inline `UIDevice.current.userInterfaceIdiom == .pad ? X : Y` found in production views outside `AdaptiveLayout.swift` (where it belongs as the implementation). ✅

---

### 5E. Inline `gender == .boy ?` — profilePoseImage bypass (§4 violation)

**12 call sites** across 7 files bypass `UserProfile.profilePoseImage` and hardcode image names:

```
SplitScreenVersusView.swift:111, 194, 215
NearbyVersusView.swift:525
LocalVersusView.swift:199, 404, 436, 462
MultiplayerHealthyPicksView.swift:600
ChefAcademyApp.swift:669
SiblingProfileView.swift:26 (computed property)
AvatarCreatorView.swift:114 (computed property)
ParentDashboardView.swift:506 (computed property)
```

**Two categories of fix:**

**Category 1 — call sites that have a `UserProfile` available** (LocalVersusView, SiblingProfileView, ParentDashboardView): Replace directly with `.profilePoseImage`:
```swift
// Before (LocalVersusView.swift:199):
Image(player.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")

// After:
Image(player.profilePoseImage)
```

**Category 2 — call sites with only a `Gender` value** (SplitScreenVersusView uses `child.gender` from a UserProfile — still qualifies for category 1; MultiplayerHealthyPicksView uses `Gender` enum for remote opponent who has no UserProfile; AvatarCreatorView uses `AvatarModel.gender`):
Add a convenience property to `Gender` enum:
```swift
// In AvatarModel.swift (Gender enum):
extension Gender {
    var cardCleanFrameName: String {
        switch self {
        case .boy:  return "boy_card_clean_frame_11"
        case .girl: return "girl_card_clean_frame_06"
        }
    }
}
```
Then:
```swift
// MultiplayerHealthyPicksView.swift:600:
let imageName = gender.cardCleanFrameName
```

**Note:** `FamilySetupView.swift:373,396` and `OnboardingView.swift:285` use gender during profile *creation*, before a `UserProfile` exists. These are legitimate pre-creation contexts — `Gender.cardCleanFrameName` applies there too, but both use the full animation frame sequence logic which is an animation helper, not a profilePoseImage call. These are lower priority.

**Special case — `GardenHubView.swift:143`** — this is dead code (orphaned file, zero references per §9). No fix needed; flag for scheduled deletion.

---

### 5F. Hand-Rolled Card/Button Surfaces

**`AllergenPickerStep.swift` — Back button is hand-rolled instead of using `.buttonStyle(SecondaryButtonStyle())`:**

```swift
// Lines ~176–186 (Back button):
Button(action: onBack) {
    Text("Back")
        .font(.AppTheme.headline)
        .foregroundColor(Color.AppTheme.sepia)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1.5)
        )
}
.buttonStyle(.plain)
```

```swift
// After:
Button("Back", action: onBack)
    .buttonStyle(SecondaryButtonStyle())
    .frame(maxWidth: nil)  // SecondaryButtonStyle is full-width by default; constrain if needed
```

Similarly the Next button should use `.texturedButton(tint: Color.AppTheme.sage)`.

---

## 6. [REFACTOR-COMPONENT] Suggestions

### RC-1 · `gender.cardCleanFrameName` helper on `Gender` enum

Described above in §5E. This eliminates 12 hardcoded string literals. Proposed addition to `AvatarModel.swift`:

```swift
extension Gender {
    /// Frame name for the static child card image (used in versus, profile, sibling views).
    var cardCleanFrameName: String {
        self == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"
    }
}
```

### RC-2 · Versus-screen avatar circle (repeated 4-file pattern)

The same ZStack pattern (parchment circle + gender image + clipShape) appears in `LocalVersusView`, `SplitScreenVersusView`, `NearbyVersusView`, and `MultiplayerHealthyPicksView`:

```swift
ZStack {
    Circle()
        .fill(Color.AppTheme.parchment)
        .frame(width: 70, height: 70)
    Image(gender == .boy ? "boy_card..." : "girl_card...")
        .resizable().aspectRatio(contentMode: .fit)
        .frame(width: 60, height: 60).clipShape(Circle())
}
```

Propose adding to `PipComponents.swift`:
```swift
struct PlayerAvatarCircle: View {
    let gender: Gender
    var size: CGFloat = 70

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.AppTheme.parchment)
                .frame(width: size, height: size)
            Image(gender.cardCleanFrameName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size - 10, height: size - 10)
                .clipShape(Circle())
        }
    }
}
```

### RC-3 · `pipBubble` / `kidBubble` are not truly reusable

`AskPipView` defines `pipBubble(_:)` and `kidBubble(_:)` as private view builders. These are almost identical to `PipSpeechBubble` with `hasTail: true`. Consider using `PipSpeechBubble` directly instead of wrapping it; the kid bubble is unique. Minor cleanup, low priority.

---

## 7. Missing Tokens

These animations appeared multiple times and have no existing token. Add to `AnimationConstants` in `AppTheme.swift`:

```swift
// In AnimationConstants enum:

// Weather ambient effects — for WeatherOverlayView
static let weatherPulse       = Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)
static let weatherCloudDrift  = Animation.easeInOut(duration: 8.0).repeatForever(autoreverses: true)
static let weatherCloudDriftFast = Animation.easeInOut(duration: 7.0).repeatForever(autoreverses: true)
static let weatherLightningStrike = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: false)

// Pip exit animation (HealthyChoiceGameView pip float-away)
static let pipExit = Animation.easeIn(duration: 1.5)

// Game-specific
static let confettiFall = Animation.easeIn(duration: 2.0)
```

Add to `AppSpacing`:
```swift
// Micro UI elements
static let tinyCornerRadius: CGFloat = 6    // Pip drag label, harvest tooltip
static let typingDot: CGFloat = 8           // AskPipView typing indicator dots
static let scoreDot: CGFloat = 8            // Versus view mistake-counter dots
```

---

## 8. Clean Scans

No regressions found in the following files:

- `AppTheme.swift` — all tokens clean, no hardcoded values in production code (hex values are inside token definitions, which is correct)
- `AdaptiveLayout.swift` — all AdaptiveCardSize tokens defined; `DeviceInfo.isIPad` is internal to the helper, not inlined at call sites
- `PipComponents.swift` — PipSpeechBubble, PipHeaderStack, PINPadGrid all use tokens correctly
- `BackgroundView.swift` — clean
- `MorphTransition.swift` — clean
- `PipDialogView.swift` — clean
- `PipAnimations.swift` — `PipWithDialogue.speed` parameter drives the inline easeInOut, which is a variable not a magic number; acceptable
- `CharacterWalkingView.swift` — uses `AnimationConstants.walkingFPS`, `walkSpeed` correctly; TimelineView pattern correct
- `GardenView.swift` — growth-timer bug already fixed (comment at line 667 confirms); `.task { while !Task.isCancelled }` pattern in use ✅
- `FarmShopView.swift` — `bounceTask` pattern correct (Task + cancel on disappear) ✅
- `PlantingSheet.swift` — clean
- `PipVoice.swift` — DEBUG override pattern correct (computed property, no UserDefaults mutation)
- `PIPKeychain.swift` — clean
- `AuthManager.swift` — `DispatchQueue.main.async` flagged above; rest is clean
- `SeededRandomGenerator.swift` — no SwiftUI, no state; clean
- `AssetPackController.swift` — `@MainActor` class, all publishes correct
- `AssetPackImage.swift` — Task.detached + MainActor.run pattern correct ✅
- `ODRManager.swift` — legacy; correct KVO cleanup with `observation.invalidate()`
- `AmbientAudioPlayer.swift` — `fadeTask?.cancel()` pattern correct; `Task.isCancelled` check in fade loop ✅
- `PipAIService.swift` — `await MainActor.run { }` pattern used correctly for all @Published mutations from background
- `GameState.swift` — Combine debounce for auto-save is clean; no banned patterns
- `FamilyProfile.swift`, `UserProfile.swift`, `PlayerData.swift`, `Allergen.swift` — SwiftData models clean; all properties have defaults
- `SessionManager.swift` — Timer callback correctly uses `Task { @MainActor [weak self] in }` at line 435; `try? save()` violations flagged in §3
- `SubscriptionManager.swift` — `transactionUpdatesTask?.cancel()` in deinit is correct Task lifecycle
- `WorkerClient.swift`, `AppAttestService.swift`, `CloudKeyManager.swift` — no SwiftUI state patterns; clean
- `RecipeCardExample.swift` — recipe lookup uses ID+slug fallback pattern ✅
- `RecipeDetailView.swift` — `.foregroundColor(.white)` flagged; rest clean including sticky footer
- `SeedInfoView.swift` — `DispatchQueue.main.async` flagged; ColorChoice teaching comment preserved ✅
- `ElevenLabsVoiceService.swift` — `await MainActor.run { }` pattern correct
- `PipFoundationModelService.swift` — gated by `#if canImport(FoundationModels)` ✅
- `InsulinTetrisView.swift` — uses `TimelineView(.animation)` for game physics ✅
- `GlucoseJourneyView.swift` — inline springs flagged; no stale-UI issues
- `HealthyChoiceGameView.swift` — Timer.scheduledTimer + `Task { @MainActor in }` correct; inline animations flagged
- `GameState.swift` — no banned patterns; SwiftData saves use `do/catch` ✅
- `VideoPlayerView.swift` — `deinit` player cleanup correct
- `SceneEditor.swift` — DEV-only; violations noted but not blocking

---

*Review completed 2026-06-16. 89 Swift files scanned. Most urgent action: convert 18 `try? save()` call sites before next session — this is a repeat of the March 2026 silent data-loss bug.*
