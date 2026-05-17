# Weekly Code Review — 2026-05-17

> Scope: All Swift source files under `ChefAcademy/ChefAcademy/`.  
> Focus 1: Stale UI State bugs (concurrency, timers, dispatch).  
> Focus 2: Hardcoded values + missed component reuse.  
> **No source files were modified during this review.**  
> Rule: every fix recommendation must use existing design-system tokens; if a token is missing, the recommendation is to *add* it — never inline.

---

## Executive Summary

| Priority | Category | Count |
|---|---|---|
| P1 | `DispatchQueue.main.async` in UIKit delegate callbacks | 6 files, 16 call sites |
| P1 | `UserProfile.profilePoseImage` bypassed (gender inline) | 7 files, 14 call sites |
| P1 | Inline hardcoded animation curves | 15 files, 50+ call sites |
| P2 | Hardcoded dimensions / spacing | 18 files |
| P2 | Hand-rolled button/card surfaces | 10 files |
| P2 | Inline Pip + speech bubble patterns | 9 files |
| P2 | Hardcoded colors | 6 files |
| P2 | Hardcoded fonts | 2 files |
| P2 | Inline `isIPad` device branches | 6 files |
| P3 | Repeated chip / PIN-dot / avatar-grid blocks needing extraction | 3 patterns |

**Compliant highlights**: `SessionManager`, `SubscriptionManager`, `ODRManager`, `WorkerClient`, `PlayerData`, `UserProfile`, `SeededRandomGenerator`, `PipAIService`, `PipStaticResponses`, `GardenWeatherService`, `VoicePickerView`, `SignInView`, `PaywallView`, `HomeAnimated`, `MorphTransition`, `SiblingGardenView` — all clean.

---

## FOCUS 1 — Stale UI State Bugs

### F1-01 · `DispatchQueue.main.async` in UIKit Delegate Callbacks — P1

**Rule**: ZERO inline `DispatchQueue.main.async` in `ChefAcademy/`. All `@Published`/`@State` mutations from non-main contexts use `Task { @MainActor in }`.

The following files use `DispatchQueue.main.async` to hop to the main thread from UIKit delegate callbacks or authentication handlers. This is a Swift 6 strict-concurrency violation and will produce data-race warnings under `SWIFT_STRICT_CONCURRENCY = complete`.

#### `AuthManager.swift`
- `checkExistingCredential()` — `DispatchQueue.main.async { self.isAuthenticated = … }` inside an `ASAuthorizationController` completion closure.
- **Fix**: Replace with `Task { @MainActor in self.isAuthenticated = … }`.

#### `GameCenterMatchmakerView.swift` — `Coordinator`
- Line ~43–45: `DispatchQueue.main.async { self.parent.onMatchFound(match) }` inside `GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFind:)`.
- Line ~51–53: same pattern in `matchmakerViewController(_:didFailWithError:)`.
- Line ~59–62: same pattern in `matchmakerViewControllerWasCancelled(_:)`.
- **Fix**: All three → `Task { @MainActor in … }`.

#### `GameCenterService.swift`
- `authenticateHandler` block (~lines 102–129): multiple `DispatchQueue.main.async { self.isAuthenticated = … }` calls inside the `GKLocalPlayer.local.authenticateHandler` closure.
- **Fix**: `Task { @MainActor in self.isAuthenticated = …; self.localPlayer = … }`.

#### `MultiplayerManager.swift`
- Line ~65: `DispatchQueue.main.async { self.isAuthenticated = … }` in `authenticateLocalPlayer()`.
- Line ~196: `DispatchQueue.main.async { … }` in `handleMessage()`.
- Line ~242: **Double violation** — `DispatchQueue.main.async { … }` *inside* a `Timer.scheduledTimer` callback in `startCountdown()`. The timer fires on the RunLoop; wrapping with `DispatchQueue.main.async` instead of `Task { @MainActor in }` is a strict-concurrency violation.
- Line ~297: `DispatchQueue.main.async { … }` in `GKMatchDelegate.match(_:player:didChange:)`.
- Line ~321: `DispatchQueue.main.async { … }` in `match(_:didFailWithError:)`.
- **Fix**: All five → `Task { @MainActor in }`.

#### `NearbyMultiplayerManager.swift`
- Line ~155: `DispatchQueue.main.async { … }` in `handleMessage()`.
- Line ~200: `DispatchQueue.main.async { … }` inside Timer callback in `startCountdown()` (same double-violation pattern as MultiplayerManager).
- Line ~221: `DispatchQueue.main.async { … }` in `handleConnection()`.
- Line ~241: `DispatchQueue.main.async { … }` in `MCSessionDelegate.session(_:peer:didChange:)`.
- Line ~286: `DispatchQueue.main.async { … }` in `MCNearbyServiceAdvertiserDelegate.advertiser(_:didNotStartAdvertisingPeer:)`.
- Line ~308: `DispatchQueue.main.async { … }` in `MCNearbyServiceBrowserDelegate.browser(_:didNotStartBrowsingForPeers:)`.
- **Fix**: All six → `Task { @MainActor in }`.

#### `ParentPINEntryView.swift`
- Line ~134: `DispatchQueue.main.async { self.shake = true }` in `startAppleIDVerification()` inside an `ASAuthorizationController` callback.
- **Fix**: `Task { @MainActor in self.shake = true }`.

---

### F1-02 · All Timer Callbacks — COMPLIANT ✓

`Timer.scheduledTimer` callbacks in all game views wrap `@State` mutations in `Task { @MainActor in }`:
`CookingMiniGames`, `MultiplayerHealthyPicksView`, `NearbyVersusView`, `SplitScreenVersusView`, `PipGameAnimationView`, `WaterPourCharacterView`, `GardenWeatherService`, `SessionManager`, `GardenView`, `PlotView`, `OnboardingView`, `SeedInfoView` — all compliant.

---

### F1-03 · ConnectablePublisher / DispatchQueue.main.asyncAfter — NONE FOUND ✓

No `ConnectablePublisher` misuse. No `DispatchQueue.main.asyncAfter` in any view file.

---

### F1-04 · `UIScreen.main.bounds` — Deprecated (iOS 17+)

**File**: `GardenView.swift` — three call sites using `UIScreen.main.bounds` to read screen width/height for plot positioning and drag clamping.

**Fix**: Replace with `GeometryReader` or pass size via `let geo: GeometryProxy` parameter. Pattern already used correctly in `SplitScreenVersusView.splitGameView(size:)` and `WaterPourCharacterView`.

---

## FOCUS 2 — Hardcoded Values + Missed Component Reuse

---

### F2-A · Hardcoded Colors — P2

**Rule**: Shadows always use `Color.AppTheme.sepia.opacity(N)` — never `Color.black.opacity(N)`. White fills use `Color.AppTheme.cream` — never `.white`.

| File | Location | Violation | Fix |
|---|---|---|---|
| `AllergenPickerStep.swift` | `AllergenToggleButton` lines 134, 142 | `.white` (two foreground colors) | `Color.AppTheme.cream` |
| `ChopMiniGame.swift` | Shadow | `Color.black.opacity(0.2)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `FarmShopView.swift` | Overlay | `Color.black.opacity(0.5)` | `Color.AppTheme.sepia.opacity(0.5)` |
| `GardenView.swift` | Plot shadow ×2 | `Color.black.opacity(0.2)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `RecipeDetailView.swift` | Line ~79 | `.foregroundColor(.white)` | `Color.AppTheme.cream` |

> **`SceneEditor.swift`**: Dev-only drag-tool; contains `.white`, `.yellow`, `.cyan`, `.green`, `.red`, `Color.black.opacity` throughout. Not user-facing, lower priority — but should be gated with `#if DEBUG` at the file level if it isn't already.

---

### F2-B · Hardcoded Fonts — P2

**Rule**: Never `.font(.system(size:weight:design:))` in production views. Use `Font.AppTheme.*` or `Font.AppTheme.rounded(size:weight:)`.

| File | Location | Violation | Fix |
|---|---|---|---|
| `ProfilePickerView.swift` | Line ~39 | `.font(isIPad ? .system(size: 40, weight: .bold, design: .rounded) : .AppTheme.largeTitle)` | Remove branch; use `Font.AppTheme.rounded(size: 40, weight: .bold)` controlled by `AdaptiveCardSize` |
| `ProfilePickerView.swift` | `ProfileCard` line ~199 | `.system(size: 22, weight: .semibold, design: .rounded)` | `Font.AppTheme.rounded(size: 22, weight: .semibold)` |
| `ProfilePickerView.swift` | `ProfileCard` line ~208 | `.system(size: 15, design: .rounded)` | `Font.AppTheme.rounded(size: 15)` |

---

### F2-C · Hardcoded Dimensions — P2

#### New Tokens Needed First

Before fixing the call sites, add these tokens to `AppTheme.swift` / `AppSpacing`:

```swift
// AppSpacing additions
static let pinDotSize:         CGFloat = 20    // PIN entry indicator dot
static let pinShakeOffset:     CGFloat = 10    // PIN wrong-entry shake amplitude
static let screenTopPad:       CGFloat = 60    // Sheet close-button clearance
static let strokeThick:        CGFloat = 1.5   // Mid-weight stroke (between strokeThin & strokeMedium)
static let avatarPreviewHeight: CGFloat = 180  // ProfileView AvatarPreviewView fixed height
```

And a `PlotViewSize` namespace in `AdaptiveLayout.swift` (or `AppTheme.swift`):

```swift
enum PlotViewSize {
    static let outerWidth:  CGFloat = 100
    static let outerHeight: CGFloat = 110
    static let emptyRing:   CGFloat = 70
    static let growingOuter: CGFloat = 80
    static let vegImage:    CGFloat = 60
    static let readyRing:   CGFloat = 85
    static let readyVeg:    CGFloat = 65
    static let progressBar: CGFloat = 6
}
```

#### Violations by File

**`PlotView.swift`** — most significant block; every dimension is hardcoded:
- `.frame(width: 100, height: 110)` outer (line 53) → `PlotViewSize.outerWidth/Height`
- Empty-plot ring `.frame(width: 70, height: 70)` ×2 (lines 117, 124) → `PlotViewSize.emptyRing`
- Growing-plot outer `.frame(width: 80)` (line 144), veg `.frame(width: 60)` (line 150) → `PlotViewSize.growingOuter/vegImage`
- Ready-plot ring `.frame(width: 85)` (line 183), veg `.frame(width: 65)` (line 189), outer ring (line 258) → `PlotViewSize.readyRing/readyVeg`
- Progress bar `.frame(height: 6)` ×3 (lines 161, 164, 167) → `PlotViewSize.progressBar`
- Watering/weeding/bugRescue outer `.frame(width: 80)` (lines 221, 300, 369), inner images `.frame(width: 60/50/55)` → `PlotViewSize.*`
- "Harvest!" badge `.padding(.horizontal, 8).padding(.vertical, 3)` (lines 207–208) → `AppSpacing.xs` / `AppSpacing.xxs`

**`MigrationPINSetupView.swift`** + **`ParentPINEntryView.swift`** — identical PIN-dot row:
- `HStack(spacing: 16)` → `AppSpacing.md`
- `.frame(width: 20, height: 20)` dot indicator → `AppSpacing.pinDotSize`
- `lineWidth: 1` → `AppSpacing.strokeThin`
- `.offset(x: shake ? -10 : 0)` → `AppSpacing.pinShakeOffset`

**`ProfilePickerView.swift`**:
- `avatarSize: isIPad ? 200 : 80`, `circleSize: isIPad ? 220 : 90`, `cardWidth: isIPad ? 280 : 120` — all inline `isIPad` branches → `AdaptiveCardSize.*` tokens
- Crown offset `isIPad ? -115 : -50`, lock offset `isIPad ? 80 : 35` → `AdaptiveCardSize.*`
- `pipSize: isIPad ? 280 : 120` → `AdaptiveCardSize.pipOnboarding(for: sizeClass)`

**`MultiplayerHealthyPicksView.swift`**:
- `.frame(width: 30, height: 30)` (line 361), `.frame(width: 60, height: 60)` ×3 (lines 344, 346, 624), `.frame(width: 70, height: 70)` (line 605)
- `lineWidth: 1.5` (line 363) → `AppSpacing.strokeThick`
- `HStack(spacing: 8)` (line 128), `HStack(spacing: 6)` (line 289), `HStack(spacing: 4)` (lines 305, 373), `HStack(spacing: 2)` (line 383) — no matching tokens for 2/4/6/8; use nearest (`AppSpacing.xxs = 4`, `AppSpacing.xs = 8`) or add `AppSpacing.xxs2: CGFloat = 2`
- `.frame(width: 8, height: 8)` (line 388) — needs new token or use `AppSpacing.xxs * 2`
- `Spacer().frame(height: 100)` (line 547) → `AppSpacing.tabBarClearance`

**`NearbyVersusView.swift`**: same dimensions as above (`.frame(30/8pt)`, `lineWidth: 1.5`, HStack spacings, `Spacer().frame(height: 100)`) → same tokens.

**`SplitScreenVersusView.swift`**:
- `.frame(width: 60, height: 60)` (line 110), `.frame(width: 50, height: 50)` (lines 113, 196, 216), `.frame(width: 40, height: 40)` (line 449)
- `.padding(.horizontal, 8).padding(.vertical, 4)` (lines 393–394) → `AppSpacing.xs` / `AppSpacing.xxs`
- `lineWidth: 1.5` (line 548) → `AppSpacing.strokeThick`
- `dividerHeight: CGFloat = 44` (line 267) — needs `AppSpacing.splitScreenDivider: CGFloat = 44`

**`GardenView.swift`**:
- `lineWidth: 2.5` (plot ring) — not in AppSpacing; needs `AppSpacing.strokeThickPlot: CGFloat = 2.5` or use `strokeMedium + 0.5` — prefer adding the token
- `IngredientBadge` `.cornerRadius(isIPad ? 16 : 12)` → `AppSpacing.cardCornerRadius` / `AppSpacing.smallCornerRadius`
- `PipGardenMessage` `isIPad ? 200 : 100` → `AdaptiveCardSize.*`

**`SeedInfoView.swift`**:
- `Spacer(minLength: 140)` (line 358) — no matching token; needs `AppSpacing.toolPickerClearance: CGFloat = 140`
- `.padding(.top, 60)` ×2 (lines 360, 413) → `AppSpacing.screenTopPad`
- `.padding(.horizontal, 8).padding(.vertical, 3)` (lines 837–839) on nutrient superpower pill → `AppSpacing.xs` / `AppSpacing.xxs`
- `HStack(spacing: 6)` (line 369) — closest available is `AppSpacing.xxs = 4` or `AppSpacing.xs = 8`; add `AppSpacing.chip: CGFloat = 6` or absorb into the chip component (see F2-H)
- `withAnimation { showCoinReward = nil }` bare (lines 496, 807) → `withAnimation(AnimationConstants.fadeQuick) { … }`

**`PantryInfoView.swift`**:
- `.frame(width: 200, height: 200)` (line 54) → `AppSpacing.infoCardImageSize` (token already exists ✓)
- `.padding(.top, 60)` ×2 (lines 87, 148) → `AppSpacing.screenTopPad`
- `Spacer(minLength: 140)` (line 84) → `AppSpacing.toolPickerClearance`
- `HStack(spacing: 6)` (line 103) — same issue as above; add `AppSpacing.chip: CGFloat = 6`
- Bare `withAnimation { showCoinReward = nil }` ×2 (lines 227, 289) → `withAnimation(AnimationConstants.fadeQuick) { … }`

**`ProfileView.swift`**:
- `.frame(height: 180)` for AvatarPreviewView (line 26) → `AppSpacing.avatarPreviewHeight`
- `Spacer().frame(height: 100)` (line 146) → `AppSpacing.tabBarClearance`

**`SiblingProfileView.swift`**:
- `.frame(width: 120, height: 120)` avatar (line 56)
- `lineWidth: 3` (line 60) → `AppSpacing.strokeBold`
- `.frame(width: 50, height: 50)` harvested-veggie grid (line 161)
- `VStack(spacing: 4)` (line 157) — `AppSpacing.xxs`
- `GiftVeggieSheet` `.frame(width: 60, height: 60)` (line 343)
- `.padding(.bottom, 120)` ×2 (SiblingProfileView line 243, SiblingGardenView line 78) — exceeds `tabBarClearance = 100`; needs `AppSpacing.deepTabBarClearance: CGFloat = 120`
- `Spacer().frame(height: 80)` (line 209) → `AppSpacing.tabBarClearance`

**`SiblingGardenView.swift`**:
- `.padding(.top, 60)` (line 63) → `AppSpacing.screenTopPad`

**`AvatarCreatorView.swift`**:
- `.frame(width: 220)` and `.frame(width: 200)` — needs `AdaptiveCardSize` tokens

**`FamilySetupView.swift`**:
- `HStack(spacing: 16)` → `AppSpacing.md`
- `lineWidth: 1` → `AppSpacing.strokeThin`
- `.clipShape(RoundedRectangle(cornerRadius: 24))` — 24 not in AppSpacing; closest is `AppSpacing.largeCornerRadius = 20`; either use 20 or add `AppSpacing.xxlCornerRadius: CGFloat = 24`

**`PipDialogView.swift`**:
- `.padding(.bottom, 100)` (line 70) → `AppSpacing.tabBarClearance`
- `lineWidth: choice.style == .secondary ? 1.5 : 0` (line 101) → `AppSpacing.strokeThick : 0`

**`PipTestView.swift`** (`PipGridItem`):
- Background circle `.frame(width: 130, height: 130)` ×2, image `.frame(width: 120, height: 120)` — use `PipSize.hero.points` (160) or `.large.points` (120); background ring: `PipSize.large.points + 10`
- `lineWidth: isSelected ? 4 : 2` → `AppSpacing.strokeBold : AppSpacing.strokeMedium`
- `Spacer(minLength: 50)` (line 68) → nearest: `AppSpacing.xl = 32` or new token

**`RecipeCardExample.swift`** (`RecipeCardView`):
- `.frame(height: 160)` recipe card image area (line 978) — no matching token; add `AppSpacing.recipeCardImageHeight: CGFloat = 160`
- Adult-help / allergen badge `.padding(.horizontal, 8).padding(.vertical, 4)` → `AppSpacing.xs` / `AppSpacing.xxs`
- `.padding(8)` wrapper (lines 995, 996, 1011) → `AppSpacing.xs`
- `RecipeListView` `.frame(width: 50, height: 50)` profile-circle placeholder (line 1112)
- `VStack(spacing: 4)` (line 1099) → `AppSpacing.xxs`
- `.padding(.bottom, 100)` (line 1156) → `AppSpacing.tabBarClearance`

**`PlantingSheet.swift`**:
- `seedImageSize: isIPad ? 120 : 80`, `gridSpacing: isIPad ? 20 : 12`, `npcImageSize: isIPad ? 300 : 200` (lines 45–48) → `AdaptiveCardSize.*`
- `Spacer(minLength: 40)` ×2 (lines 165, 327) → `AppSpacing.xl`

**`WeatherOverlayView.swift`** (`WeatherBadge`):
- Inline `isIPad ? 18 : 14` for icon font size → `AdaptiveCardSize`
- `isIPad ? .AppTheme.title3 : .AppTheme.headline` font branch → `AdaptiveCardSize`
- `lineWidth: 1.5` (WindOverlay line 463) → `AppSpacing.strokeThick`
- `lineWidth: 1` (WindOverlay line 469) → `AppSpacing.strokeThin`
- `SunshineOverlay` `.frame(width: 200, height: 200)` (line 66) — needs weather-specific token
- `PartlyCloudyOverlay` `.frame(width: 80, height: 80)` (line 100)

**`BodyBuddyView.swift`**:
- `lineWidth: 4` ×2 (organ rings) — not in AppSpacing; add `AppSpacing.strokeRing: CGFloat = 4`

**`MeetPipViews.swift`** (`ReadyToStartView`):
- `HStack(spacing: sizeClass == .compact ? -20 : -30)` (line 289) → `AdaptiveCardSize`
- `.frame(width: sizeClass == .compact ? 120 : 180, height: sizeClass == .compact ? 120 : 180)` (lines 298–300) → `AdaptiveCardSize.pipOnboarding(for: sizeClass)`

**`InsulinTetrisView.swift`**:
- Multiple hardcoded paddings and corner radii for game UI elements

**`PipVoice.swift`** (`PipVoiceToggleChip`):
- `.padding(.horizontal, 10)`, `.padding(.vertical, 6)`, `.cornerRadius(14)` (lines 220–223) — see F2-H Chip pattern

**`ChefAcademyApp.swift`** (stats chips):
- `.padding(.horizontal, 10)/.padding(.vertical, 6)/.cornerRadius(14)` — see F2-H Chip pattern

---

### F2-D · Hardcoded Animation Curves — P1

**Rule**: ZERO `.spring()`, `.spring(response:)`, `.easeIn/Out/InOut(duration:)` outside of `AnimationConstants` and `AppTheme`. Every animation curve must come from `AnimationConstants.*`.

This is the most pervasive category — 15 files, 50+ call sites. Listed by file with approximate counts:

| File | Violations | Examples |
|---|---|---|
| `GlucoseJourneyView.swift` | 15+ | `.spring()`, `.spring(response: 0.4, dampingFraction: 0.7)`, `.easeInOut(duration: 0.5)`, `.easeOut(duration: 0.3)` throughout all phase transitions |
| `WeatherOverlayView.swift` | 8 | `SunshineOverlay`: `.easeInOut(duration: 3).repeatForever()`; `PartlyCloudyOverlay`: `.easeInOut(duration: 8)`, `.easeInOut(duration: 3)`; `CloudOverlay`: `.easeInOut(duration: 10)`, `.easeInOut(duration: 7)`; `WindOverlay`: `.easeInOut(duration: 2)`, `.easeInOut(duration: 2.5)`, `.easeInOut(duration: 1.8)`; `SeasonalOverlayView`: `.linear(duration: 20)`, `.easeInOut(duration: 3)` |
| `CookingMiniGames.swift` | 6+ | `.spring(response: 0.3)`, `.easeInOut(duration: 0.2)`, `.easeOut(duration: 0.15)` per mini-game |
| `GardenView.swift` | 2 | `.easeIn(duration: 0.6)` (plot appearance); `.spring(response: 0.3)` in `#if DEBUG` block |
| `FamilySetupView.swift` | 3 | `.easeOut(duration: 0.8)` ×2, `.easeOut(duration: 0.6)` |
| `BodyBuddyView.swift` | 2 | `.easeOut(duration: 1.0).delay(0.3)`, `.animation(.easeOut(duration: 1.0))` |
| `GameState.swift` | 2 | `withAnimation(.spring())` at lines 172, 181 → `AnimationConstants.springMedium` |
| `HealthyChoiceGameView.swift` | 2 | `.animation(.easeIn(duration: 2))`, `.easeIn(duration: 1.5)` (food float-away) |
| `PlotView.swift` | 1 | `startWatering()` `.easeInOut(duration: 0.6).repeatForever()` → `AnimationConstants.floatLoopSlow` |
| `AskPipView.swift` | 1 | `.easeInOut(duration: 0.4)` |
| `CookingSessionView.swift` | 1 | `.easeInOut(duration: 0.4)` |
| `MeetPipAnimated.swift` | 1 | `ConfettiView.createConfetti()` `.easeIn(duration: Double.random(in: 1.5...2.5))` |
| `PipAnimations.swift` | 1 | `WiggleModifier` `.easeInOut(duration: speed)` with hardcoded default `speed: 0.15` |
| `PipTestView.swift` | 1 | `PipGridItem.stopBreathingAnimation()` `.easeOut(duration: 0.3)` → `AnimationConstants.fadeQuick` |
| `ChopMiniGame.swift` | 1 | `.animation(.easeOut(duration: 0.1))` |

#### New AnimationConstants Tokens Needed

Add to `AppTheme.swift`:

```swift
// Weather loop animations
static let sunPulseLoop    = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)
static let cloudDriftSlow  = Animation.easeInOut(duration: 8).repeatForever(autoreverses: true)
static let cloudDriftVSlow = Animation.easeInOut(duration: 10).repeatForever(autoreverses: true)
static let windStreakFast  = Animation.easeInOut(duration: 2).repeatForever(autoreverses: false)
static let windStreakMed   = Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: false)
static let seasonDrift     = Animation.linear(duration: 20).repeatForever(autoreverses: false)
static let seasonPulse     = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)

// Gameplay-specific
static let confettiFall    = Animation.easeIn(duration: 2.0)   // base; callers add .random jitter
static let floatAway       = Animation.easeIn(duration: 2.0)   // HealthyChoiceGameView food exit
static let waterDropLoop   = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
static let bodyBuddyReveal = Animation.easeOut(duration: 1.0).delay(0.3)
```

Also add a frame-rate constant:
```swift
static let pourFPS: TimeInterval = 0.1    // WaterPourCharacterView character animation (~10fps)
static let genderCardFPS: TimeInterval = 1.0 / 10.0  // OnboardingView GenderCard sprite
```

---

### F2-E · Hardcoded Device Branches — P2

**Rule**: Never inline `isIPad ? X : Y`. Use `AdaptiveCardSize.*(for: sizeClass)` tokens.

| File | Violation |
|---|---|
| `BackgroundView.swift` | `sizeClass == .compact ? X : Y` padding inline |
| `GardenView.swift` | `isIPad ? 200 : 100` (pip message size), `isIPad ? 16 : 12` (badge corner radius) |
| `MeetPipViews.swift` | `sizeClass == .compact ? -20 : -30` (avatar overlap), avatar frame |
| `PlantingSheet.swift` | `isIPad ? 120 : 80`, `isIPad ? 20 : 12`, `isIPad ? 300 : 200` |
| `ProfilePickerView.swift` | Avatar size, circle size, card width, crown/lock offsets, pip size — 6 branches |
| `WeatherOverlayView.swift` | `WeatherBadge` font size, padding |

All → add `AdaptiveCardSize` cases for the semantic role (e.g. `pipGardenMessage`, `plantingSheetSeed`, `plantingSheetNPC`) and resolve via `AdaptiveCardSize.*.value(for: sizeClass)`.

---

### F2-F · Hand-Rolled Button / Card Surfaces — P2

**Rule**: Primary CTAs → `.texturedButton(tint:)`. Bouncy secondary → `.buttonStyle(BouncyButtonStyle())`. Never `.buttonStyle(.plain)` with a custom `.background() + .cornerRadius() + .shadow()` chain.

Files with hand-rolled buttons (buttons using custom `.background` + `.cornerRadius` without a button style from `AppTheme.swift`):

| File | Buttons |
|---|---|
| `CookingCompletionView.swift` | Primary "Cook Again" / "Share" CTAs |
| `GlucoseJourneyView.swift` | `completePhase` advance button |
| `HealthyChoiceGameView.swift` | "Play Again!", "Go to Garden" |
| `LocalVersusView.swift` | Multiple game-flow buttons |
| `MultiplayerHealthyPicksView.swift` | "Find a Player", "Ready!", "Play Again!", "Try Again" |
| `NearbyVersusView.swift` | Multiple game-flow buttons |
| `SiblingProfileView.swift` | "Visit Garden", "Gift Veggies" |
| `SplitScreenVersusView.swift` | "Start!", "Done" (also uses `BouncyButtonStyle` inconsistently: "Next" and "Rematch!" do, "Start!" and "Done" don't) |
| `PlayLearnView.swift` | `MiniGameRouterView.placeholderView` "Back to Games" |
| `PipTestView.swift` | `PipGridItem` — selection card pattern; `.buttonStyle(.plain)` with full custom styling |

---

### F2-G · Inline Pip + Speech Bubble Patterns — P2

**Rule**: `PipSpeechBubble` and `PipHeaderStack` are the canonical layout components in `PipComponents.swift`. Inline `Image("pip_got_idea") + .frame(width: N)` patterns with a manual speech bubble must be refactored to use these components.

| File | Pattern | Fix |
|---|---|---|
| `AskPipView.swift` | Inline `Image("pip_got_idea")` + hardcoded `.frame(40)` | `PipWavingAnimatedView(size: .compact)` |
| `ChefAcademyApp.swift` | `PipMessageCard` — inline Pip + message card, device branch | `PipSpeechBubble` or `PipHeaderStack` |
| `CookingSessionView.swift` | `pipMessageView` — partial inline Pip avatar | `PipHeaderStack` |
| `GlucoseJourneyView.swift` | `PipJourneyMessage` (lines 1438–1459) — inline `Image("pip_got_idea")` + speech card | `PipSpeechBubble` |
| `InsulinTetrisView.swift` | `Image("pip_got_idea").frame(width: 120)` inline | `PipWavingAnimatedView(size: .large)` |
| `MultiplayerHealthyPicksView.swift` | `errorView` — `Image("pip_got_idea").frame(width: 100)` | `PipWavingAnimatedView(size: .large)` |
| `NearbyVersusView.swift` | Gameplay pip — `Image("pip_got_idea")` × pipScale inline | `PipGameAnimationView` or `PipWavingAnimatedView` |
| `OnboardingView.swift` | `WelcomeView` — inline Pip image with `AdaptiveCardSize` for size (partial compliance) | `PipHeaderStack` |
| `PlayLearnView.swift` | Lines 50–62: `PipWavingAnimatedView` + manual `.softCard(padding:)` speech bubble | `PipSpeechBubble` |

---

### F2-H · Repeated View Blocks Needing Extraction — P3

#### Pattern H-1: Chip Component (`.padding(.horizontal, ~10).padding(.vertical, ~6).cornerRadius(~14)`)

This pill-chip style appears in at least 3 files with slight variations:

| File | Exact padding/radius |
|---|---|
| `ChefAcademyApp.swift` | `.padding(.horizontal, 10).padding(.vertical, 6).cornerRadius(14)` (stats chips) |
| `PipVoice.swift` | `.padding(.horizontal, 10).padding(.vertical, 6).cornerRadius(14)` (`PipVoiceToggleChip`) |
| `RecipeDetailView.swift` | `.padding(.horizontal, 12).padding(.vertical, 6).cornerRadius(14)` (nutrition fact pills) |

**Fix**: Extract `ChipModifier` or `ChipView` to `AppTheme.swift` or `PipComponents.swift`:
```swift
// In AppTheme.swift
struct ChipModifier: ViewModifier {
    var tint: Color = Color.AppTheme.parchment
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppSpacing.sm)   // or a new token AppSpacing.chipH
            .padding(.vertical, AppSpacing.xxs + 2) // or AppSpacing.chipV
            .background(tint)
            .cornerRadius(AppSpacing.largeCornerRadius)
    }
}
extension View {
    func chipStyle(tint: Color = Color.AppTheme.parchment) -> some View {
        modifier(ChipModifier(tint: tint))
    }
}
```
Note: the exact padding values (`10`, `12`) and radius (`14`) don't perfectly map to existing tokens. Add `AppSpacing.chipH: CGFloat = 10` and `AppSpacing.chipV: CGFloat = 6` alongside this extraction.

#### Pattern H-2: PIN Dot Row (duplicated across 2 files)

Both `MigrationPINSetupView.swift` and `ParentPINEntryView.swift` contain an identical ~15-line PIN indicator row:
- `HStack(spacing: 16)` with dot indicators
- Each dot: `Circle().stroke(..., lineWidth: 1).frame(width: 20, height: 20)` conditionally filled
- `.offset(x: shake ? -10 : 0)` shake animation

**Fix**: Extract `PINDotRow(pinLength:enteredCount:shake:)` view to `PipComponents.swift` alongside the existing `PINPadGrid`. Use new tokens `AppSpacing.pinDotSize`, `AppSpacing.pinShakeOffset`, `AppSpacing.strokeThin`, `AppSpacing.md`.

#### Pattern H-3: Multiplayer Avatar Score Bar (duplicated across 3 files)

`MultiplayerHealthyPicksView.swift`, `NearbyVersusView.swift`, and `SplitScreenVersusView.swift` all contain a structurally identical avatar + score + hearts HUD bar:
- Player avatar circle `.frame(width: 60, height: 60)` with score and health hearts
- The avatar image uses the gender-conditional anti-pattern (see Arch section below)

**Fix**: Extract `PlayerScoreBar(profile:score:badChoices:maxBad:)` view. See Arch violation below for the avatar image fix.

---

## Architectural Violations

### ARCH-01 · `UserProfile.profilePoseImage` Bypassed — P1

**Rule**: Never inline `gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"`. Always call `profile.profilePoseImage` which correctly routes parents to mom/dad frames.

`UserProfile.profilePoseImage` is defined at `UserProfile.swift:82–89`. It correctly handles `.parent + .girl → "mom_avatar_frame_15"`, `.parent + .boy → "dad_avatar_frame_15"`, and children to their clean frames.

The following files bypass it with hardcoded gender conditionals:

| File | Call sites | Fix |
|---|---|---|
| `ChefAcademyApp.swift` | Sibling section, 1 site | `sibling.profilePoseImage` |
| `LocalVersusView.swift` | 5 sites (lines 199, 404, 436, 462–463) | `player.profilePoseImage` |
| `MultiplayerHealthyPicksView.swift` | 2 sites (`opponentScoreBar` line 358, `playerAvatar` line 600–601) | `manager.opponentProfile?.profilePoseImage` |
| `NearbyVersusView.swift` | 2 sites (line 275, `playerAvatar` line 525) | same |
| `ParentDashboardView.swift` | `DashboardChildTab.characterImage` (line 506) | `profile.profilePoseImage` |
| `SiblingProfileView.swift` | `characterImage` computed property (lines 25–27) | `sibling.profilePoseImage` |
| `SplitScreenVersusView.swift` | 3 sites (lines 111, 194, 215) | `child.profilePoseImage` |

**Total: 7 files, 14 call sites.** This is the highest-volume single-pattern violation in the codebase.

---

## Compliant Files (No Findings)

The following files were read in full and are clean with respect to both focus areas:

`SessionManager.swift`, `SubscriptionManager.swift`, `ODRManager.swift`, `WorkerClient.swift`, `PlayerData.swift`, `UserProfile.swift`, `SeededRandomGenerator.swift`, `PipAIService.swift`, `PipFoundationModelService.swift`, `PipStaticResponses.swift`, `PipGameAnimationView.swift`, `GardenWeatherService.swift`, `VoicePickerView.swift`, `SignInView.swift`, `PaywallView.swift`, `HomeAnimated.swift`, `MorphTransition.swift`, `PINKeychain.swift`, `VideoPlayerView.swift`, `WaterPourCharacterView.swift`, `SiblingGardenView.swift`, `RecipeCardExample.swift` (data model section), `GardenRecipes.all`.

---

## Token Additions Summary

All recommendations in this report depend on the following additions. Add them before any fix sweep.

### AppSpacing additions (`AppTheme.swift`)
```swift
static let pinDotSize:          CGFloat = 20    // PIN entry indicator dot diameter
static let pinShakeOffset:      CGFloat = 10    // PIN wrong-entry horizontal shake
static let screenTopPad:        CGFloat = 60    // Modal/sheet top clearance for close button
static let strokeThick:         CGFloat = 1.5   // Between strokeThin(1) and strokeMedium(2)
static let strokeRing:          CGFloat = 4     // Organ-ring stroke (BodyBuddyView)
static let strokeThickPlot:     CGFloat = 2.5   // Plot-ready ring stroke (GardenView)
static let avatarPreviewHeight: CGFloat = 180   // ProfileView AvatarPreviewView height
static let recipeCardImageHeight: CGFloat = 160 // RecipeCardView image area
static let toolPickerClearance: CGFloat = 140   // PencilKit tool-picker bottom spacing
static let deepTabBarClearance: CGFloat = 120   // Extra tab-bar clearance for nested sheets
static let splitScreenDivider:  CGFloat = 44    // SplitScreenVersusView score divider
static let chipH:               CGFloat = 10    // Horizontal padding for chip/pill UI
static let chipV:               CGFloat = 6     // Vertical padding for chip/pill UI
```

### PlotViewSize namespace (`AdaptiveLayout.swift` or `AppTheme.swift`)
```swift
enum PlotViewSize {
    static let outerWidth:   CGFloat = 100
    static let outerHeight:  CGFloat = 110
    static let emptyRing:    CGFloat = 70
    static let growingOuter: CGFloat = 80
    static let vegImage:     CGFloat = 60
    static let readyRing:    CGFloat = 85
    static let readyVeg:     CGFloat = 65
    static let progressBar:  CGFloat = 6
}
```

### AnimationConstants additions (`AppTheme.swift`)
```swift
static let sunPulseLoop    = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)
static let cloudDriftSlow  = Animation.easeInOut(duration: 8).repeatForever(autoreverses: true)
static let cloudDriftVSlow = Animation.easeInOut(duration: 10).repeatForever(autoreverses: true)
static let windStreakFast   = Animation.easeInOut(duration: 2).repeatForever(autoreverses: false)
static let windStreakMed    = Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: false)
static let seasonDrift      = Animation.linear(duration: 20).repeatForever(autoreverses: false)
static let seasonPulse      = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)
static let confettiFall     = Animation.easeIn(duration: 2.0)
static let floatAway        = Animation.easeIn(duration: 2.0)
static let waterDropLoop    = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
static let bodyBuddyReveal  = Animation.easeOut(duration: 1.0).delay(0.3)
static let pourFPS: TimeInterval        = 0.1
static let genderCardFPS: TimeInterval  = 0.1
```

---

## Recommended Fix Order

1. **ARCH-01** — `profilePoseImage` sweep (7 files, 14 sites, low risk, high visibility)
2. **F1-01** — `DispatchQueue.main.async` → `Task { @MainActor in }` (6 files, concurrency correctness)
3. **Add all tokens** (zero risk, enables all F2 fixes)
4. **F2-D** — Animation constants sweep (highest volume P1, start with `GameState`, `GlucoseJourneyView`, `WeatherOverlayView`)
5. **F2-H-2** — Extract `PINDotRow` (blocks PIN UI duplication in 2 files)
6. **F2-A** — Hardcoded color fixes (6 files, small diffs)
7. **F2-C** — Dimension token sweep by file (PlotView, MultiplayerHealthyPicksView, NearbyVersusView highest priority)
8. **F2-F** — Button style sweep (multiplayer views first)
9. **F1-04** — Replace `UIScreen.main.bounds` in `GardenView.swift`
10. **F2-G** — Pip component refactor (touch carefully — auto-speak behavior)
11. **F2-H-1** — Extract `ChipModifier`
12. **F2-H-3** — Extract `PlayerScoreBar`

---

*Reviewed by Claude Code · 2026-05-17 · 82 Swift files read.*
