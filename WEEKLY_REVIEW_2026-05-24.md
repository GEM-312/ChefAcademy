# Weekly Code Review — 2026-05-24
> ChefAcademy · SwiftUI + SwiftData · iOS 16+

---

## 1. Files Read (89 Swift files + CLAUDE.md)

AddChildFlowView, Allergen, AllergenEditorSheet, AllergenPickerStep, AmbientAudioPlayer,
AppAttestService, AppTheme, AdaptiveLayout, AskPipView, AssetPackController, AssetPackImage,
AuthManager, AvatarCreatorView, AvatarModel, BackgroundView, BodyBuddyView,
CharacterWalkingView, ChefAcademyApp, ChopMiniGame, CloudKeyManager, ContentView,
CookingCompletionView, CookingMiniGames, CookingSessionView, ElevenLabsVoiceService,
FamilyProfile, FamilySetupView, FarmShopView, GameCenterMatchmakerView, GameCenterService,
GameState, GardenHubView, GardenView, GardenWeatherService, GlucoseJourneyView,
HealthyChoiceGameView, HomeAnimated, InsulinTetrisView, KitchenView, LocalVersusView,
MeetPipAnimated, MeetPipViews, MigrationPINSetupView, MorphTransition,
MultiplayerHealthyPicksView, MultiplayerManager, NearbyMultiplayerManager, NearbyVersusView,
ODRManager, OnboardingView, PINKeychain, PantryInfoView, ParentDashboardView,
ParentPINEntryView, PaywallView, PipAIService, PipAnimations, PipComponents, PipDialogView,
PipFoundationModelService, PipGameAnimationView, PipStaticResponses, PipTestView, PipVoice,
PlantingSheet, PlayLearnView, PlayerData, PlotView, ProfilePickerView, ProfileView,
RecipeCardExample, RecipeDetailView, SceneEditor, SeedInfoView, SeededRandomGenerator,
SessionManager, SiblingGardenView, SiblingProfileView, SignInView, SplitScreenVersusView,
SubscriptionManager, USDAFoodService, UserProfile, VideoPlayerView, VoicePickerView,
WaterPourCharacterView, WeatherOverlayView, WorkerClient

---

## 2. TL;DR

**2 confirmed STALE-UI violations** — both countdown timers in the multiplayer managers use
`DispatchQueue.main.async` inside `Timer.scheduledTimer` callbacks, violating the
CLAUDE.md rule that mandates `Task { @MainActor in }` + `try? await Task.sleep`.

**3 PERF issues** — repeated SwiftData fetches inside computed body properties, stacking
`.onAppear`-driven `withAnimation(.repeatForever)` calls in every weather overlay struct,
and dead code (GardenHubView) that allocates at startup.

**Hardcode debt is widespread but concentrated** — fonts only in ProfilePickerView (3 sites),
`.white`/`.black` color leaks in 4 files, animation-curve literals in 15 files (WeatherOverlayView
is the worst single offender at 7 inline curves), raw spacing constants in ~30 files.
No source file is fatally broken; the issues are cosmetic/maintainability debt.

**12 inline Pip patterns** duplicating `PipSpeechBubble`/`PipHeaderStack`. Collapsing them
to the shared components would delete ~300 lines and guarantee consistent auto-speak behaviour.

**GardenHubView is dead code** with zero call sites — safe to delete.

---

## 3. STALE-UI Findings

### STALE-01 · `MultiplayerManager.startCountdown()` — Timer + DispatchQueue.main.async
**File:** `MultiplayerManager.swift` (~line 240)
**Pattern:** Anti-pattern #2 — `Timer.scheduledTimer` with `DispatchQueue.main.async` inside
the callback, mutating `@Published` state off the SwiftUI-guaranteed main-actor path.

```swift
// CURRENT (violates CLAUDE.md)
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
    DispatchQueue.main.async {
        self?.countdownValue -= 1
        if self?.countdownValue == 0 {
            timer.invalidate()
            self?.startGame()
        }
    }
}

// REQUIRED FIX
Task { @MainActor [weak self] in
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard let self else { return }
        countdownValue -= 1
        if countdownValue <= 0 { startGame(); break }
    }
}
```

### STALE-02 · `NearbyMultiplayerManager.startCountdown()` — identical violation
**File:** `NearbyMultiplayerManager.swift` (lines 196–209)
Same `Timer.scheduledTimer` + `DispatchQueue.main.async` pattern. Needs the identical fix
shown above. UIKit/GK delegate callbacks in this file that also use `DispatchQueue.main.async`
are acceptable UIKit bridge calls — only the `startCountdown` timer is the violation.

### STALE-03 · `WeatherOverlayView` — stacked `.onAppear` animations
**File:** `WeatherOverlayView.swift` — `SunshineOverlay`, `PartlyCloudyOverlay`,
`CloudOverlay`, `WindOverlay`, `SeasonalOverlayView`
**Pattern:** Anti-pattern #11 — `.onAppear`-only animation startup.

Every weather overlay calls `withAnimation(.easeInOut(duration:N).repeatForever(...)) { state = true }`
inside `.onAppear`. When the parent `GardenView` re-renders (after any `@Published` change,
sheet dismiss, etc.), `.onAppear` fires again on the same live view, stacking an additional
animation driver on top of the existing one. Drift rate and pulse speed double with each re-appearance.

**Required fix:** Replace `withAnimation { }` in `.onAppear` with a `.task { }` loop:
```swift
.task {
    while !Task.isCancelled {
        withAnimation(AnimationConstants.floatLoopSlow) { pulse = true }
        try? await Task.sleep(for: .seconds(3))
        withAnimation(AnimationConstants.floatLoopSlow) { pulse = false }
        try? await Task.sleep(for: .seconds(3))
    }
}
```
Use the appropriate `AnimationConstants.floatLoop*` token for the curve (see Missing Tokens §7).

---

## 4. PERF Findings

### PERF-01 · `SiblingProfileView.playerData` — repeated SwiftData fetch in body
**File:** `SiblingProfileView.swift` (line 21–23)

```swift
private var playerData: PlayerData? {
    sibling.playerData(in: modelContext)  // executes a FetchDescriptor every call
}
```
`body` references `playerData` at four separate call sites (lines 67, 130, 144, 180).
Each reference re-executes a full `context.fetch` predicate query. Promote to `@State`:

```swift
@State private var playerData: PlayerData? = nil
// in .onAppear: playerData = sibling.playerData(in: modelContext)
```

### PERF-02 · `GardenHubView` — orphaned dead code loaded at startup
**File:** `GardenHubView.swift`
Confirmed zero call sites. The struct is compiled into the binary, imports SwiftData, and
declares `@Query` descriptors that run on startup. Delete the file entirely — no migration
or feature flag needed.

### PERF-03 · `MultiplayerManager` / `NearbyMultiplayerManager` — retained `spawnTimer` reference
Both managers store a `Timer?` as a stored property on a class that outlives individual game
sessions. Verify `spawnTimer?.invalidate()` is called in `cleanup()` / `deinit`.
The current implementations appear to call `cleanup()`, but the timer is never nil'd —
a subsequent `cleanup()` call won't double-invalidate, but the `Timer?` holds a strong
reference to the closure capture list until explicitly nil'd.
**Fix:** After `spawnTimer?.invalidate()`, add `spawnTimer = nil`.

---

## 5. HARDCODE Findings

### A · Raw Colors (never use `.white`, `.black`, `.red`, etc.)

| File | Line(s) | Offending code | Required replacement |
|------|---------|---------------|---------------------|
| `AllergenPickerStep.swift` | ~2 sites | `.foregroundColor(.white)` | `Color.AppTheme.cream` |
| `RecipeDetailView.swift` | allergen banner | `.foregroundColor(.white)` | `Color.AppTheme.cream` |
| `ChopMiniGame.swift` | chopping board | `.shadow(color: .black.opacity(0.2))` | `Color.AppTheme.sepia.opacity(0.1)` |
| `GardenView.swift` | DraggablePipView / WalkingPipView | `Color.black.opacity(0.2)` in shadow | `Color.AppTheme.sepia.opacity(0.2)` |

`FarmShopView.swift` has `.shadow(color: .black.opacity(0.5))` inside a `#if DEBUG` block —
acceptable for a dev-only tool, but flag if the block is ever shipped.

### B · Raw Fonts (never use `.font(.system(size:))`)

All three instances are in `ProfilePickerView.swift` inside `isIPad ? ... : ...` branches.
The iPad branch falls back to `.system(size:)` because `AppTheme` has no adaptive title token.
**The fix is in the token layer, not at the call site** (see Missing Tokens §7).

| File | Location | Offending code |
|------|----------|---------------|
| `ProfilePickerView.swift:39` | "Who's playing today?" title | `.system(size: 40, weight: .bold, design: .rounded)` |
| `ProfilePickerView.swift:199` | ProfileCard name | `.system(size: 22, weight: .semibold, design: .rounded)` |
| `ProfilePickerView.swift:208` | ProfileCard last-played | `.system(size: 15, design: .rounded)` |

### C · Raw Spacing / Dimensions (use `AppSpacing.*` tokens)

Below are the highest-priority sites. Each is a raw literal where a token already exists
or should be added (see §7).

**Tab bar clearance** — `AppSpacing.tabBarClearance` (100 pt) exists but is used raw:
- `ProfileView.swift`: `Spacer().frame(height: 100)` → `AppSpacing.tabBarClearance`
- `PlayLearnView.swift`: `Spacer().frame(height: 80)` → wrong value AND raw; should be `AppSpacing.tabBarClearance`
- `SiblingProfileView.swift`: `Spacer().frame(height: 80)` → same as above
- `SiblingGardenView.swift`: `.padding(.bottom, 120)` on toast → `AppSpacing.tabBarClearance` + `AppSpacing.md`

**Pill / chip padding** (horizontal 10, vertical 6/8) — appears in ≥8 files:
- `PipVoice.swift (PipVoiceToggleChip)`: `.padding(.horizontal, 10).padding(.vertical, 6)`
- `RecipeDetailView.swift` (ingredient chips): `.padding(.horizontal, 10).padding(.vertical, 8)`
- `RecipeDetailView.swift` (nutrition pills): `.padding(.horizontal, 12).padding(.vertical, 6)`
- `RecipeCardExample.swift` (ingredient chips, nutrition pills): same raw values
- `SeedInfoView.swift` (superpower badge): `.padding(.horizontal, 8).padding(.vertical, 3)`
- `PlotView.swift` (Harvest! badge): `.padding(.horizontal, 8).padding(.vertical, 3)`
→ Add `AppSpacing.chipPaddingH` / `AppSpacing.chipPaddingV` tokens (see §7)

**Avatar frame sizes** — no token exists for common avatar sizes (50/60/80/120 pt):
- `SiblingProfileView.swift`: `frame(width: 120, height: 120)`
- `SiblingProfileView.swift` / `GiftVeggieSheet`: `frame(width: 50/60, height: 50/60)`
- `SplitScreenVersusView.swift`: `frame(width: 50/60, height: 50/60)`
- `MultiplayerHealthyPicksView.swift`: `frame(width: 70/60/30, height: 70/60/30)`
- `PlotView.swift`: `Circle().frame(70×70 / 80×80 / 85×85)` (three slightly different sizes for growth stages)
- `ProfilePickerView.swift`: `avatarSize: isIPad ? 200 : 80` / `circleSize: isIPad ? 220 : 90`
→ Add `AppSpacing.avatarSm/Md/Lg` tokens (see §7)

**`lineWidth` values** — border widths appear raw throughout:
- `SiblingProfileView.swift`: `lineWidth: 3` (profile avatar ring)
- `OnboardingView.swift`: `lineWidth: 3` (GenderCard selection ring)
- `ParentDashboardView.swift`: `lineWidth: 2` (child tab selection ring)
- `PipDialogView.swift`: `lineWidth: 1.5` (dialog border)
- `SplitScreenVersusView.swift`: `lineWidth: 1.5` (Done button overlay)
→ Add `AppSpacing.borderWidthThin` (1), `borderWidthMed` (2), `borderWidthThick` (3)

**Other notable raw literals:**
- `PipDialogView.swift:padding(.bottom, 100)` → `AppSpacing.tabBarClearance`
- `PantryInfoView.swift`: `Image.frame(width: 200, height: 200)`, `Spacer(minLength: 140)`, `.padding(.top, 60)`
- `SeedInfoView.swift`: `Spacer(minLength: 140)`, `.padding(.top, 60)`, `frame(width: 42, height: 42)`
- `ParentPINEntryView.swift`: `HStack(spacing: 16)` for PIN dot row, `Circle().frame(width: 20, height: 20)`
- `ParentDashboardView.swift`: `Spacer().frame(height: 40)`, `frame(width: 50, height: 50)` (child tab avatar)
- `PlantingSheet.swift`: `Spacer(minLength: 40)` ×2, `gridSpacing: isIPad ? 20 : 12`
- `SiblingGardenView.swift`: `.padding(.top, 60)` on back button
- `SplitScreenVersusView.swift`: `let dividerHeight: CGFloat = 44`, `.padding(.horizontal, 8).padding(.vertical, 4)` in coin HUD, `Text("P1").padding(3)` badge, `.offset(x: 22, y: -22)`
- `WeatherOverlayView.SunshineOverlay`: `Circle().frame(width: 200, height: 200)`, `.offset(x: 60, y: -20)`
- `WeatherOverlayView.PartlyCloudyOverlay`: `Circle().frame(width: 80, height: 80)`, `.offset(x: 40, y: -10)`
- `WeatherOverlayView.WindOverlay`: `frame(width: 80/60/70, height: 8/6/7)` for wind streaks, offsets `y: 60/120/180`
- `VoicePickerView.VoiceOptionCard`: `VStack(spacing: 2)`, `Circle().frame(width: 24, height: 24)`, `Image.frame(width: 40)`

`HStack(spacing: 4)` / `VStack(spacing: 4)` appears in 20+ files — map to `AppSpacing.xxs`.

### D · Raw Animation Curves (use `AnimationConstants.*` tokens)

| File | Offending expression | Closest existing token |
|------|---------------------|----------------------|
| `AskPipView.swift` | `.easeOut(duration: N)`, `.easeIn(duration: N)`, `.easeInOut(duration: N)` ×multiple | `AnimationConstants.fadeQuick` / `fadeMedium` |
| `BodyBuddyView.swift` | `.easeOut(duration: 0.3)` ×multiple | `AnimationConstants.fadeFast` |
| `CookingMiniGames.swift` | multiple inline spring/ease literals | `AnimationConstants.springQuick` / `springMedium` |
| `CookingSessionView.swift` | `.easeInOut(duration: 0.4)` | `AnimationConstants.fadeMedium` |
| `FamilySetupView.swift` | `.easeOut(duration: 0.8)`, `.easeOut(duration: 0.6)` ×3 | `AnimationConstants.fadeMedium` / `revealSlow` |
| `GameState.swift` | bare `.spring()` ×2 | `AnimationConstants.springMedium` |
| `GardenView.swift` | `.spring(response: 0.3, dampingFraction: 0.7)`, `.easeIn(duration: 0.6)` | `AnimationConstants.springSnappy` |
| `GlucoseJourneyView.swift` | many inline springs and easeInOut | various `spring*` tokens |
| `HealthyChoiceGameView.swift` | `.easeIn(duration: 2)`, `.easeIn(duration: 1.5)` | Add `AnimationConstants.revealSlow` or `floatLoopSlow` |
| `MeetPipAnimated.swift (ConfettiView)` | `.easeIn(duration: Double.random(in: 1.5...2.5))` | random range is intentional — add an `AnimationConstants.confettiFall` min/max pair |
| `ParentDashboardView.swift` | bare `withAnimation { }` | `AnimationConstants.springMedium` |
| `PipAnimations.swift (WiggleModifier)` | `.easeInOut(duration: speed)` | `speed` is a parameter — wrap it: use `AnimationConstants.wiggleSpeed` constant |
| `PipTestView.swift` | `.easeOut(duration: 0.3)` | `AnimationConstants.fadeFast` |
| `PlotView.swift (startWatering)` | `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` | `AnimationConstants.floatLoopFast` |
| `WeatherOverlayView` | `.easeInOut(duration: 3/7/8/10)` ×4 overlays, `.linear(duration: 20)`, `.easeInOut(duration: 2/2.5/1.8)` wind ×3 | `AnimationConstants.floatLoopSlow` / `weatherTransition` / add `AnimationConstants.weatherDrift` |

`WeatherOverlayView.swift` is the single worst offender with 10+ inline curves. All of them
should use the `.task { while !Task.isCancelled }` fix from STALE-03 which also eliminates
the stacking bug.

### E · Device Branches with Raw Values (use `AdaptiveLayout` tokens)

Files that use `isIPad ? rawValue : rawValue` for spacing/dimensions instead of
`AdaptiveCardSize.*` or `DeviceInfo` tokens:

- `ProfilePickerView.swift` — most egregious: `pipSize: isIPad ? 280 : 120`,
  `avatarSize: isIPad ? 200 : 80`, `circleSize: isIPad ? 220 : 90`, `cardWidth: isIPad ? 280 : 120`,
  `crown offset y: isIPad ? -115 : -50`, `lock badge padding: isIPad ? 10 : 6`
- `MultiplayerHealthyPicksView.swift` — raw HUD font sizes, avatar sizes per sizeClass
- `NearbyVersusView.swift` — same pattern
- `ParentDashboardView.swift` — raw spacing in child tab layout
- `PlantingSheet.swift` — `gridSpacing: isIPad ? 20 : 12`

These should either use `AdaptiveCardSize` tokens (for fixed layout elements) or
`AdaptiveContainer` (for auto-adapting layouts). Where the adaptive tokens don't exist yet,
add them (see §7).

### F · Hand-Rolled Button / Card Surfaces

The following buttons use manual `.background(Color).cornerRadius()` instead of
`.texturedButton(tint:)`, `PrimaryButtonStyle`, `SecondaryButtonStyle`, or `BouncyButtonStyle`:

| File | Button | Required style |
|------|--------|---------------|
| `AllergenPickerStep.swift` | allergen toggle chips | `.texturedButton(tint:)` |
| `BodyBuddyView.swift` | action buttons | `PrimaryButtonStyle` |
| `CookingCompletionView.swift` | Next/Done buttons | `PrimaryButtonStyle` |
| `GlucoseJourneyView.swift` | nav buttons | `PrimaryButtonStyle` / `SecondaryButtonStyle` |
| `HealthyChoiceGameView.swift` | game control buttons | `.texturedButton(tint:)` |
| `LocalVersusView.swift` | match/lobby buttons | `PrimaryButtonStyle` |
| `MultiplayerHealthyPicksView.swift` | "Find a Player", "Ready!" | `PrimaryButtonStyle` |
| `NearbyVersusView.swift` | idleView/lobbyView/resultsView buttons | `PrimaryButtonStyle` / `SecondaryButtonStyle` |
| `PlayLearnView.MiniGameRouterView` | "Back to Games" | `SecondaryButtonStyle` |
| `SiblingProfileView.swift` | "Visit Garden", "Gift Veggies" | `PrimaryButtonStyle` |
| `SplitScreenVersusView.swift` | "Done" in resultsView | `SecondaryButtonStyle` |

Note: Buttons that use `BouncyButtonStyle()` with a hand-rolled body shape (Next, Start!, Rematch!)
are partially compliant — the bounce works, but the fill/shape should move to `PrimaryButtonStyle`
so tint and shape are consistent.

### G · Inline Pip Patterns (use `PipSpeechBubble` / `PipHeaderStack`)

Each of the following constructs duplicates PipComponents.swift and skips `PipVoice.shared.speak()`
(so the child hears no voice even in the paid tier):

| File | Struct / section | Replace with |
|------|-----------------|--------------|
| `ChefAcademyApp.swift` | `PipMessageCard` | `PipSpeechBubble` |
| `BodyBuddyView.swift` | `pipMessageSection` | `PipSpeechBubble` |
| `FarmShopView.swift` | `PipShopMessage` | `PipSpeechBubble` |
| `GardenView.swift` | `PipGardenMessage` | `PipSpeechBubble` |
| `GlucoseJourneyView.swift` | `PipJourneyMessage` | `PipSpeechBubble` |
| `HomeAnimated.swift` | `PipMessageAnimated` | `PipSpeechBubble` |
| `MultiplayerHealthyPicksView.swift` | `errorView` inline `Image("pip_got_idea")` | `PipHeaderStack` |
| `NearbyVersusView.swift` | `errorView` inline `Image("pip_got_idea")` | `PipHeaderStack` |
| `OnboardingView.swift (WelcomeView)` | inline Pip image + "Pip" badge label | `PipHeaderStack` |
| `PipAnimations.swift` | `PipWithDialogue` (partial duplicate) | Refactor to extend `PipSpeechBubble` |
| `PlayLearnView.swift` | Pip widget section (`PipWavingAnimatedView` + VStack text) | `PipSpeechBubble` |
| `SeedInfoView.swift` | `pipColorTip` (partial — has colour-conditional logic) | `PipSpeechBubble` with dynamic `message:` parameter |

### H · Repeated 3+ Line View Blocks (extract to shared components)

**H-1 · Back button overlay** — identical in `SiblingGardenView.swift` and `SiblingProfileView.swift`:
```swift
Button(action: onBack) {
    HStack(spacing: 4) { Image(systemName: "arrow.left"); Text("Back") }
        .font(.AppTheme.headline)
        .foregroundColor(Color.AppTheme.cream)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.AppTheme.sage)
        .cornerRadius(AppSpacing.largeCornerRadius)
}
```
→ Extract to `BackNavButton(action:)` in a shared component file.

**H-2 · Veggie grid tile** (`VStack(spacing: 4) { Image.frame + Text + Text.caption }.padding.background.cornerRadius`)
appears in `SiblingProfileView.swift` (harvested veggies), `GiftVeggieSheet`, and
`SplitScreenVersusView.swift` (pickPlayers cards).
→ Extract to `VeggieGridTile(vegType:quantity:)`.

**H-3 · Star rating row** (`HStack(spacing: 2) { ForEach(0..<3) { Image(star.fill or star) } }`)
appears in `SiblingProfileView.swift` and `RecipeDetailView.swift`.
→ Extract to `StarRatingView(stars: Int)`.

**H-4 · Pip reward toast overlay** — identical pattern in `SiblingGardenView.swift` and
`SiblingProfileView.swift`: `PipWavingAnimatedView(size: .custom(36)) + Text` inside
`.softCard()` at the bottom of a ZStack, with `withAnimation` show + `Task.sleep` dismiss.
→ Extract to `PipToastOverlay(message:isShowing:)`.

**H-5 · Player mini-card** — `VStack(spacing: 4) { ZStack { Circle + Image.frame(50-70) } + Text }`
for displaying a player's avatar + name appears in `SplitScreenVersusView.swift` (×2 in
pickPlayers and readyView), `LocalVersusView.swift`, and `MultiplayerHealthyPicksView.swift`.
→ Extract to `PlayerMiniCard(profile:tag:)`.

---

## 6. REFACTOR-COMPONENT Suggestions

### RC-01 · Collapse the "Pip message" zoo into `PipSpeechBubble`
**Impact: HIGH** — 12 inline variants across 12 files, ~300 lines of duplicated code.
`PipMessageCard`, `PipMessageAnimated`, `PipGardenMessage`, `PipShopMessage`, `PipJourneyMessage`,
`pipMessageSection`, `PipWithDialogue`, `pipColorTip`, and 4 inline image-only uses all exist
because callers don't know `PipSpeechBubble` accepts a `pose:` parameter and auto-invokes TTS.
Action: audit each site, replace with `PipSpeechBubble(message:pose:)`, delete the local structs.

### RC-02 · `ProfileCard` adaptive layout → `AdaptiveContainer`
**File:** `ProfilePickerView.swift`
`ProfileCard` has 6 separate `isIPad ?` branches, two of which use raw `.system(size:)` fonts
(caught in §5-B). Move to `AdaptiveContainer` for layout and add `AppTheme` adaptive font tokens
so the view works on any size class without branching.

### RC-03 · Weather overlay animation → `.task` loop
**File:** `WeatherOverlayView.swift`
Unifies the STALE-03 bug fix and the HARDCODE-D violations: replace all `withAnimation(...).repeatForever`
in `.onAppear` with structured concurrency loops so animations are cancellable, don't stack, and
use `AnimationConstants` tokens.

### RC-04 · `GardenHubView` — delete dead file
Zero references, zero callers, still compiled and linked. Delete.

### RC-05 · Shared `VeggieGridTile` + `PlayerMiniCard` + `BackNavButton`
Addresses H-2, H-3, H-5 above. Recommend adding a `SharedComponents.swift` file
(or `SocialComponents.swift` given the social-feature context) for the three siblings-and-social
view fragments that are currently copy-pasted.

---

## 7. Missing Tokens

The following tokens are referenced by the codebase but not yet in AppTheme/AppSpacing/AnimationConstants:

### AppSpacing

| Token name | Value | Files that need it |
|-----------|-------|-------------------|
| `chipPaddingH` | 10 | RecipeDetailView, RecipeCardExample, PipVoice, SeedInfoView, PlotView |
| `chipPaddingV` | 6 | same |
| `avatarSm` | 50 | SiblingProfileView, SplitScreenVersusView, GiftVeggieSheet |
| `avatarMd` | 80 | ProfilePickerView, MultiplayerHealthyPicksView, NearbyVersusView |
| `avatarLg` | 120 | SiblingProfileView, ParentDashboardView |
| `borderWidthThin` | 1 | PipDialogView |
| `borderWidthMed` | 2 | ParentDashboardView, VoiceOptionCard, ParentPINEntryView |
| `borderWidthThick` | 3 | SiblingProfileView, OnboardingView |

### Font.AppTheme

| Token name | Purpose | Files that need it |
|-----------|---------|-------------------|
| `adaptiveLargeTitle` | Scales between `largeTitle` (iPhone) and a larger rounded variant on iPad without raw `.system(size:)` | ProfilePickerView (×3 sites) |

Recommended implementation using `AdaptiveLayout`:
```swift
static func adaptiveLargeTitle(for sizeClass: UserInterfaceSizeClass?) -> Font {
    sizeClass == .regular
        ? .rounded(size: 40, weight: .bold)
        : .AppTheme.largeTitle
}
```

### AnimationConstants

| Token name | Curve | Files that need it |
|-----------|-------|-------------------|
| `weatherDrift` | `.easeInOut(duration: 8).repeatForever(autoreverses: true)` | WeatherOverlayView (cloud drift, sun pulse) |
| `ambientPulse` | `.easeInOut(duration: 3).repeatForever(autoreverses: true)` | WeatherOverlayView (SunshineOverlay, SeasonalOverlayView) |
| `seasonalDrift` | `.linear(duration: 20).repeatForever(autoreverses: false)` | SeasonalOverlayView |
| `windSweep` | `.easeInOut(duration: 2).repeatForever(autoreverses: false)` | WindOverlay |

---

## 8. Clean Scans

The following files have zero hardcode violations, correct concurrency patterns, and proper
token usage. No action required:

| File | Notes |
|------|-------|
| `AmbientAudioPlayer.swift` | Proper async/await, no UI |
| `AppAttestService.swift` | Actor-based, no UI |
| `AssetPackController.swift` | Replaces ODR, uses Task + AnimationConstants ✓ |
| `AssetPackImage.swift` | UIKit bridge, no tokens needed |
| `AuthManager.swift` | `DispatchQueue.main.async` in UIKit callbacks only — acceptable bridge pattern |
| `CharacterWalkingView.swift` | TimelineView delta-time, WalkEngine correct ✓ |
| `CloudKeyManager.swift` | Pure Keychain, no UI |
| `ElevenLabsVoiceService.swift` | Pure service, actor-safe |
| `FamilyProfile.swift` | @Model with all defaults ✓ |
| `GameCenterService.swift` | GK delegate bridging pattern ✓ |
| `GardenView.swift` | Timer.publish ConnectablePublisher bug already fixed with `.task { while !Task.isCancelled }` |
| `GardenWeatherService.swift` | Timer COMPLIANT ✓ |
| `MorphTransition.swift` | Uses AnimationConstants.morphTransition + springQuick only |
| `ODRManager.swift` | Task { @MainActor }, AnimationConstants, AppSpacing ✓ |
| `PaywallView.swift` | Zero hardcoded values — gold standard for the codebase |
| `PINKeychain.swift` | Pure Keychain, no UI |
| `PipAIService.swift` | Proper async/await, App Attest guard ✓ |
| `PipComponents.swift` | Reference implementation — auto-speak wired, tokens correct |
| `PipFoundationModelService.swift` | Actor-based, iOS 26+ guard ✓ |
| `PipGameAnimationView.swift` | Timer COMPLIANT, AnimationConstants.gameFPS ✓ |
| `PipStaticResponses.swift` | Pure data, no UI |
| `PlayerData.swift` | @Model with all defaults ✓ |
| `SeededRandomGenerator.swift` | Pure math utility, no UI |
| `SessionManager.swift` | `startPlayTimeTracking()` Timer COMPLIANT — `Task { @MainActor in }` wrapper ✓ |
| `SignInView.swift` | Proper AnimationConstants use; Sign in with Apple button fixed dimensions are Apple-mandated |
| `SplitScreenVersusView.startCountdown()` | Timer COMPLIANT — `Task { @MainActor in }` ✓ |
| `SubscriptionManager.swift` | @MainActor class, StoreKit 2 async ✓ |
| `USDAFoodService.swift` | `MainActor.run` for cache writes, chunked concurrency ✓ |
| `UserProfile.swift` | @Model with all defaults, UUID linking ✓ |
| `WaterPourCharacterView.swift` | Timer COMPLIANT, TimelineView Canvas particles ✓ |
| `WeatherOverlayView.StormOverlay` | `runLightningLoop()` — correct `@MainActor` + `while !Task.isCancelled` pattern |
| `WorkerClient.swift` | URL config only, App Attest guard ✓ |
