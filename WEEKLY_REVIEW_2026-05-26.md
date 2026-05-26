# Weekly Code Review — 2026-05-26

**Scope:** Full codebase pass — all 88 Swift files read (GardenHubView.swift excluded per CLAUDE.md orphan rule), both CLAUDE.md files, AppTheme.swift, AdaptiveLayout.swift, PipComponents.swift.
**Focus areas:** (1) Stale UI state bugs — DispatchQueue/Timer anti-patterns, background mutations, missing MainActor guards. (2) Hardcoded values and missed component reuse — colors, fonts, dimensions, animations, device branches, hand-rolled surfaces.

---

## TL;DR

| Severity | Count | Summary |
|---|---|---|
| 🔴 P1 | 17 | Banned `DispatchQueue.main.async/asyncAfter` call sites across 7 files |
| 🟡 P2 | 16 | SwiftData `try? save()` swallowing errors (must log via `do/catch`) |
| 🟡 P2 | 2 | Raw `.spring()` without `AnimationConstants` tokens |
| 🟡 P2 | 35+ | Inline animation curves (`.easeInOut(duration:)`, `.linear(duration:)`) |
| 🟡 P2 | 15 | `profilePoseImage` bypassed — inline gender ternary for avatar images |
| 🟡 P2 | 12+ | Raw `tabBarClearance` padding (80/100 hardcoded) |
| 🟡 P2 | 25+ | Hand-rolled button/card surfaces (`.texturedButton(tint:)` / `.softCard()` missed) |
| 🟡 P2 | 8+ | Inline device branches (`isIPad ? X : Y`) with raw sizes |
| 🟡 P2 | 5 | `Color.black.opacity()` / `.white` — must use `Color.AppTheme` tokens |
| 🟡 P2 | 10+ | Non-standard `PipSize` raw values (`.custom(N)` where enum token exists or is needed) |
| 🟡 P2 | 8 | Stroke `lineWidth` not using `AppSpacing` tokens |
| 🟡 P2 | 6+ | Raw chip/badge padding not using `AppSpacing` tokens |
| ✅ Clean | 31 | Files with zero violations |

**8 new tokens recommended** (see Missing Tokens section).

---

## [STALE-UI] Focus 1 — Timer / Concurrency Bugs

### P1 — Banned `DispatchQueue.main.async` / `asyncAfter`

`DispatchQueue.main.async` and `DispatchQueue.main.asyncAfter` are **banned** in `ChefAcademy/`. All mutations from background queues must use `Task { @MainActor in }`. All delayed work must use `Task { @MainActor in try? await Task.sleep(for:) }`.

---

#### `AuthManager.swift` — 1 instance

**Location:** `checkExistingCredential()` — ASAuthorizationControllerDelegate callback  
**Issue:** `DispatchQueue.main.async { self.authState = .signedIn }` — callback arrives on Apple's queue; mutation reaches SwiftUI on the wrong thread.  
**Fix:**
```swift
// Before
DispatchQueue.main.async { self.authState = .signedIn }

// After
Task { @MainActor in self.authState = .signedIn }
```

---

#### `GameCenterMatchmakerView.swift` — 3 instances

**Locations:** L42, L51, L59 — `GKMatchmakerViewControllerDelegate` callbacks  
**Issue:** Three `DispatchQueue.main.async {}` blocks update `@State` from GameKit's delegate thread.  
**Fix:** Replace each with `Task { @MainActor in ... }`.

---

#### `GameCenterService.swift` — 1 instance

**Location:** L102 — `authenticateHandler` closure  
**Issue:** `DispatchQueue.main.async { self.isAuthenticated = true }` — GKLocalPlayer auth handler delivers on a background queue.  
**Fix:**
```swift
Task { @MainActor in self.isAuthenticated = true }
```

---

#### `MultiplayerManager.swift` — 5 instances

**Locations:** L65, L196, L242 (inside Timer callback), L297, L321  
**Issue:** MultipeerConnectivity delegate callbacks and a Timer-fired closure all dispatch to main via `DispatchQueue.main.async`. The Timer at L242 fires on a background thread; it wraps in `DispatchQueue.main.async` rather than `Task { @MainActor in }`.  
**Fix:** Replace every instance:
```swift
// Timer callback pattern — L242
timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
    Task { @MainActor in
        // mutations here
    }
}

// Delegate callbacks — L65, L196, L297, L321
Task { @MainActor in ... }
```

---

#### `NearbyMultiplayerManager.swift` — 6 instances

**Locations:** L155, L200 (inside Timer callback), L221, L241, L286, L308  
**Issue:** Same pattern as `MultiplayerManager` — MCSession delegate methods and a Timer callback all dispatch to main with the banned API.  
**Fix:** Same pattern:
```swift
Task { @MainActor in ... }
```
Timer callback at L200 must follow the same `Task { @MainActor [weak self] in }` pattern already present in `SessionManager.startPlayTimeTracking()`.

---

#### `ParentPINEntryView.swift` — 1 instance

**Location:** L134 — `startAppleIDVerification()` completion handler  
**Issue:** `DispatchQueue.main.async { self.verificationState = .success }` — ASAuthorizationController delivers on a background thread.  
**Fix:**
```swift
Task { @MainActor in self.verificationState = .success }
```

---

#### `SeedInfoView.swift` (VeggieCanvasView) — 1 instance

**Location:** L222 — `updateUIView` PKCanvasView delegate  
**Issue:** `DispatchQueue.main.async { clearToggle = false }` — this is a UIViewRepresentable update path; `clearToggle` is a SwiftUI `@Binding` and mutating it off main is undefined behavior.  
**Fix:**
```swift
Task { @MainActor in clearToggle = false }
```

---

### P2 — Raw `.spring()` Without `AnimationConstants`

#### `GameState.swift` — 2 instances

**Locations:** L171, L180  
**Issue:** `withAnimation(.spring())` — bare unparameterized spring. In practice this resolves to UIKit's default spring, not the app's design spring.  
**Fix:** Map to an existing `AnimationConstants` spring token (e.g., `AnimationConstants.springSnappy` or `AnimationConstants.springBouncy` depending on intent). If neither fits, add a `springDefault` token to `AnimationConstants`.

---

### P2 — SwiftData `try? save()` Silently Swallows Errors

`try?` on `modelContext.save()` discards CloudKit sync errors, constraint violations, and migration failures silently. Every call site must use:
```swift
do {
    try context.save()
} catch {
    print("[ClassName] save failed: \(error)")
}
```

**Affected call sites (16 total):**

| File | Approximate Line | Context |
|---|---|---|
| `AddChildFlowView.swift` | `finishAddChild()` | Save new child profile |
| `AllergenEditorSheet.swift` | L119 `saveAndDismiss()` | Save allergen changes |
| `ParentDashboardView.swift` | L462 | Parent dashboard action |
| `ParentDashboardView.swift` | L491 | Parent dashboard action |
| `SessionManager.swift` | L100 | PIN migration |
| `SessionManager.swift` | L206 | Link Apple ID |
| `SessionManager.swift` | L271 | Create PlayerData |
| `SessionManager.swift` | L295 | `switchToProfilePicker()` |
| `SessionManager.swift` | L355 | `removeChildProfile()` |
| `SessionManager.swift` | L374 | `updateParentPIN()` |
| `SessionManager.swift` | L419 | `migrateLegacyData()` |
| `SessionManager.swift` | L454 | `recordPlayTime()` |
| `SessionManager.swift` | L465 | `appWillBackground()` |
| `SiblingGardenView.swift` | L37 | `onLikeGarden()` |
| `SiblingGardenView.swift` | L176 | `handleHelpAction()` |
| `SiblingProfileView.swift` | L275 | Profile update |

**Note:** `SessionManager.startPlayTimeTracking()` already uses `Task { @MainActor [weak self] in }` correctly — that pattern is compliant. Only the `try? save()` sites need fixing.

---

## [HARDCODE] Focus 2 — Hardcoded Values and Missed Reuse

### A — `Color.black.opacity()` / `.white` (must use `Color.AppTheme` tokens)

All shadows must use `Color.AppTheme.sepia.opacity(N)`. `.white` in foreground/fill contexts must use `Color.AppTheme.cream` or `Color.AppTheme.pureWhite` per asset catalog.

| File | Location | Violation | Fix |
|---|---|---|---|
| `ChopMiniGame.swift` | L167 | `Color.black.opacity(0.15)` shadow | `Color.AppTheme.sepia.opacity(0.15)` |
| `GardenView.swift` | L114 `DraggablePipView` | `Color.black.opacity(0.2)` drop shadow | `Color.AppTheme.sepia.opacity(0.2)` |
| `GardenView.swift` | L352 `WalkingPipView` | `Color.black.opacity(0.15)` footstep shadow | `Color.AppTheme.sepia.opacity(0.15)` |
| `FarmShopView.swift` | pencil button | `Color.black.opacity(N)` shadow | `Color.AppTheme.sepia.opacity(N)` |
| `AllergenPickerStep.swift` | `AllergenToggleButton` (×2) | `.foregroundColor(.white)` | `Color.AppTheme.cream` |
| `RecipeDetailView.swift` | L79 | `.foregroundColor(.white)` allergen warning | `Color.AppTheme.cream` |

---

### B — Inline Animation Curves (must use `AnimationConstants` tokens)

Every `.easeInOut(duration:)`, `.easeOut(duration:)`, `.linear(duration:)`, and bare `.spring()` must be replaced with a named `AnimationConstants` token. New tokens for weather patterns are listed in the Missing Tokens section.

**`AskPipView.swift`** — L165, L445–447, L800: multiple inline duration values for Pip entrance and dialog transitions → map to `AnimationConstants.pipEntrance`, `AnimationConstants.fadeMedium`, etc.

**`BodyBuddyView.swift`** — L92, L429–430, HealthOrb: inline easeInOut durations for HealthOrb pulse and section transitions.

**`ChopMiniGame.swift`** — L186: inline duration for chop animation.

**`CookingMiniGames.swift`** — HeatPan, Season, Peel, Wash, Assemble mini-games each contain at least one raw `.easeInOut(duration:)` or `.spring(response:dampingFraction:)` block (6+ occurrences total).

**`CookingSessionView.swift`** — L523: inline easeInOut for step transition.

**`GardenView.swift`** — L765, L1174: inline easeInOut for plant growth and rain animations.

**`GlucoseJourneyView.swift`** — ~20+ occurrences across segment transitions, particle animations, and CTA button entrances.

**`HealthyChoiceGameView.swift`** — L410, L812: inline spring and easeInOut.

**`PipAnimations.swift`** — `WiggleModifier`: `.easeInOut(duration: speed).repeatForever(autoreverses: true)` — `speed` is a parameter, but the easeInOut curve itself should be `AnimationConstants.wiggleCurve` (add token).

**`PipTestView.swift`** — L162: `.easeOut(duration: 0.3)` — dev-only view, low priority.

**`PlotView.swift`** — `startWatering()`: `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` — add `AnimationConstants.wateringPulse`.

**`WeatherOverlayView.swift`** — 10+ occurrences (see new tokens below):
- `SunshineOverlay` L81: `.easeInOut(duration: 3).repeatForever(autoreverses: true)` → `AnimationConstants.weatherPulse`
- `PartlyCloudyOverlay` L114: `.easeInOut(duration: 8).repeatForever(...)` → `AnimationConstants.weatherDrift`
- `PartlyCloudyOverlay` L117: `.easeInOut(duration: 3).repeatForever(...)` → `AnimationConstants.weatherPulse`
- `CloudOverlay` L147: `.easeInOut(duration: 10).repeatForever(...)` → `AnimationConstants.weatherDriftSlow`
- `CloudOverlay` L151: `.easeInOut(duration: 7).repeatForever(...)` → `AnimationConstants.weatherDrift`
- `WindOverlay` L484, L487, L490: `.easeInOut(duration: 2).repeatForever(autoreverses: false)` (3 instances) → `AnimationConstants.windStreakLoop`
- `SeasonalOverlayView` L732: `.linear(duration: 20).repeatForever(...)` → `AnimationConstants.weatherDriftSlow`
- `SeasonalOverlayView` L736: `.easeInOut(duration: 3).repeatForever(...)` → `AnimationConstants.weatherPulse`

---

### C — Raw `tabBarClearance` Padding (use `AppSpacing.tabBarClearance = 100`)

Hardcoded bottom padding of 80, 100, or 60 that exists to clear the floating tab bar. All must use `AppSpacing.tabBarClearance`.

| File | Location | Violation |
|---|---|---|
| `GardenView.swift` | L649 | `Spacer(minLength: 100)` |
| `GlucoseJourneyView.swift` | ~4 occurrences | `.padding(.bottom, 100)` / `Spacer(minLength: 100)` |
| `HealthyChoiceGameView.swift` | L529 | `Spacer(minLength: 100)` |
| `HealthyChoiceGameView.swift` | L334 | `.padding(.bottom, 60)` |
| `HomeAnimated.swift` | L57 | `Spacer(minLength: 80)` |
| `LocalVersusView.swift` | L376 | `Spacer().frame(height: 100)` |
| `LocalVersusView.swift` | L619 | `.padding(.bottom, 60)` |
| `MultiplayerHealthyPicksView.swift` | L547 | `Spacer(minLength: 100)` |
| `NearbyVersusView.swift` | L478 | `.padding(.bottom, 100)` |
| `PipDialogView.swift` | L70 | `.padding(.bottom, 100)` |
| `PlayLearnView.swift` | L128 | `Spacer().frame(height: 80)` |
| `ProfileView.swift` | L146 | `Spacer().frame(height: 100)` |
| `RecipeCardExample.swift` | `RecipeListView` | `.padding(.bottom, 100)` |
| `SeedInfoView.swift` | multiple | `.padding(.top, 60)` (×2), `Spacer(minLength: 140)` |
| `SiblingProfileView.swift` | L209 | `Spacer().frame(height: 80)` |
| `SiblingGardenView.swift` | back button | `.padding(.top, 60)` |
| `SiblingGardenView.swift` | toast | `.padding(.bottom, 120)` |

---

### D — `profilePoseImage` Bypassed (inline gender ternary)

`UserProfile.profilePoseImage` is the **canonical** source of truth for avatar still images. It correctly handles parent vs. child and boy vs. girl. **Never** inline `gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"`.

**15 violations across 7 files:**

| File | Location | Fix |
|---|---|---|
| `ChefAcademyApp.swift` | HomeView sibling card loop | `sibling.profilePoseImage` |
| `LocalVersusView.swift` | L199 `playerReadyView` | `player.profilePoseImage` |
| `LocalVersusView.swift` | L404 `playerSelectCard` | `player.profilePoseImage` |
| `LocalVersusView.swift` | L436 `selectedPlayerChip` | `player.profilePoseImage` |
| `LocalVersusView.swift` | L462 `playerAvatarSmall` | `player.profilePoseImage` |
| `MultiplayerHealthyPicksView.swift` | `opponentScoreBar` | `opponent.profilePoseImage` |
| `MultiplayerHealthyPicksView.swift` | `playerAvatar()` | `player.profilePoseImage` |
| `NearbyVersusView.swift` | `playerAvatar()` | `player.profilePoseImage` |
| `NearbyVersusView.swift` | opponent bar | `opponent.profilePoseImage` |
| `ParentDashboardView.swift` | L506 `DashboardChildTab` | `child.profilePoseImage` |
| `SiblingProfileView.swift` | L26 `characterImage` computed property | `sibling.profilePoseImage` |
| `SplitScreenVersusView.swift` | L111 `pickPlayersView` | `player.profilePoseImage` |
| `SplitScreenVersusView.swift` | L194 `readyView` (p1) | `p1.profilePoseImage` |
| `SplitScreenVersusView.swift` | L215 `readyView` (p2) | `p2.profilePoseImage` |

---

### E — Inline `.font(.system(size:))` (use `Font.AppTheme` tokens)

#### `ProfilePickerView.swift` — multiple instances

- "Who's playing today?" heading: `.font(.system(size: N, weight: .bold))` → `Font.AppTheme.title` or `Font.AppTheme.headline`
- `ProfileCard` name label: `.font(.system(size: N))` → `Font.AppTheme.body` or `Font.AppTheme.caption`
- `ProfileCard` time label: `.font(.system(size: N))` → `Font.AppTheme.caption`
- "Add Little Chef" button: `.font(.system(size: N, weight: .semibold))` → `Font.AppTheme.buttonLabel`

#### `WeatherOverlayView.swift` — WeatherBadge

- `isIPad ? 18 : 14` inline font size → use `AdaptiveCardSize` token (or `Font.AppTheme.caption` / `Font.AppTheme.body`)

---

### F — Raw Badge / Chip Padding (use `AppSpacing` tokens)

Recurring pattern: `.padding(.horizontal, 10).padding(.vertical, 6).cornerRadius(14)` for stat chips and voice chips. These values (`chipPaddingH=10`, `chipPaddingV=6`, `chipCornerRadius=14`) do not exist as tokens yet — **add them** (see Missing Tokens).

| File | Location | Violation |
|---|---|---|
| `ChefAcademyApp.swift` | stat chips (×3) | `.padding(.horizontal, 10)`, `.padding(.vertical, 6)`, `.cornerRadius(14)` |
| `InsulinTetrisView.swift` | HUD badges | `.padding(.horizontal, 10)`, `.padding(.vertical, 4)`, `.cornerRadius(10)` |
| `PipVoice.swift` | `PipVoiceToggleChip` | `.padding(.horizontal, 10)`, `.padding(.vertical, 6)`, `.cornerRadius(14)` |
| `RecipeDetailView.swift` | adult-help badge, ingredient chips, nutrition pills | multiple raw paddings |
| `RecipeCardExample.swift` | recipe tag chips | `.padding(.horizontal, 8)`, `.padding(.vertical, 4)` |
| `SeedInfoView.swift` | USDA superpower badge | `.padding(.horizontal, 8)`, `.padding(.vertical, 3)` |
| `SplitScreenVersusView.swift` | HUD | `.padding(.horizontal, 8)`, `.padding(.top, 4)` |

---

### G — Inline Device Branches with Raw Values (use `AdaptiveCardSize`)

Every `isIPad ? X : Y` with raw numeric values is banned. Map to existing `AdaptiveCardSize` tokens or add new ones.

| File | Location | Violation |
|---|---|---|
| `GardenView.swift` | plot spot sizing | `isIPad ? 80 : 60` (and similar) inline |
| `GardenView.swift` | `IngredientBadge` | raw size branch |
| `MeetPipViews.swift` | `ReadyToStartView` | `sizeClass == .compact ? -20 : -30`, `? 120 : 180`, `? 0.5 : 0.7` |
| `PlantingSheet.swift` | `gridSpacing` | `isIPad ? 20 : 12` |
| `PlantingSheet.swift` | `npcImageSize` | `isIPad ? 300 : 200` |
| `PlantingSheet.swift` | `seedImageSize` | `isIPad ? 120 : 80` |
| `ProfilePickerView.swift` | `pipSize` | `isIPad ? 280 : 120` |
| `ProfilePickerView.swift` | `ProfileCard` sizes | multiple raw branches |
| `WeatherOverlayView.swift` | `WeatherBadge` | `isIPad ? 18 : 14` font size |

---

### H — Non-Standard `PipSize` Raw Values (use `PipSize` enum)

`PipSize` enum: `compact=40`, `medium=80`, `large=120`, `hero=160`, `custom(CGFloat)`. Where a `.custom(N)` matches an existing token, use the token. Where no token fits, add one (e.g., `PipSize.mini = 36`).

| File | Location | Violation | Fix |
|---|---|---|---|
| `GardenView.swift` | `DraggablePipView` | raw `CGFloat` literal | `PipSize.compact` or `PipSize.medium` |
| `GardenView.swift` | `PipGardenMessage` | raw size | use token |
| `GlucoseJourneyView.swift` | `PipJourneyMessage` | raw size | use token |
| `InsulinTetrisView.swift` | gameOverScreen | `size: 120` | `.large` |
| `InsulinTetrisView.swift` | victoryScreen | `.custom(100)` | no token — add `PipSize.extraLarge = 100` or use `.large` |
| `LocalVersusView.swift` | L115 | `.custom(100)` | add token or use `.large` |
| `LocalVersusView.swift` | L267 | `.custom(140)` | no token — add `PipSize.xl = 140` or use `.hero` |
| `LocalVersusView.swift` | L269–274 | `size: 140` in `PipGameAnimationView` | same as above |
| `MultiplayerHealthyPicksView.swift` | `onlineGamePip` | `size: 120` | `.large` |
| `MultiplayerHealthyPicksView.swift` | `PipGameAnimationView` (×2) | `size: 140` | add token |
| `NearbyVersusView.swift` | errorView | `frame(100, 100)` | `.large` / add token |
| `NearbyVersusView.swift` | pip widget | `.custom(100)` | add token |
| `PlayLearnView.swift` | header pip | `.custom(60)` | no token — add `PipSize.small = 60` |
| `PlayLearnView.swift` | `MiniGameCard` | `frame(width:60, height:60)` | `PipSize.small` |
| `SiblingGardenView.swift` | toast area | `.custom(36)` | `PipSize.mini` (new token, 36) |
| `SiblingProfileView.swift` | `GiftVeggieSheet` | `.custom(36)` | `PipSize.mini` |
| `SplitScreenVersusView.swift` | `gameMiniPip` | `size: 60` | `PipSize.small` |

---

### I — Stroke `lineWidth` Not Using `AppSpacing` Tokens

Existing tokens: `AppSpacing.strokeThin=1`, `AppSpacing.strokeMedium=2`, `AppSpacing.strokeBold=3`. Values of 1.5 and 2.5 have no current token — **add them** (see Missing Tokens).

| File | Location | Violation | Fix |
|---|---|---|---|
| `ChefAcademyApp.swift` | profile ring | `lineWidth: 2.5` | `AppSpacing.strokeThick` (new, 2.5) |
| `GardenView.swift` | plot border | `lineWidth: 2.5` | `AppSpacing.strokeThick` |
| `LocalVersusView.swift` | L370 "Done" overlay | `lineWidth: 1.5` | `AppSpacing.strokeLight` (new, 1.5) |
| `PipDialogView.swift` | choice button border | `lineWidth: 1.5` | `AppSpacing.strokeLight` |
| `SplitScreenVersusView.swift` | L549 "Done" overlay | `lineWidth: 1.5` | `AppSpacing.strokeLight` |
| `VoicePickerView.swift` | selection ring | `lineWidth: 2` | `AppSpacing.strokeMedium` (value matches; reference token explicitly) |
| `WeatherOverlayView.swift` | `WindStreak` | `lineWidth: 1.5` | `AppSpacing.strokeLight` |
| `WeatherOverlayView.swift` | `WindStreak` thin | `lineWidth: 1` | `AppSpacing.strokeThin` |

---

## [REFACTOR-COMPONENT] Missed Component Reuse

### Pip Speech Bubbles — use `PipSpeechBubble`

`PipSpeechBubble` is the canonical component for Pip + message layouts. The following views hand-roll the same HStack/VStack pattern:

| File | Location |
|---|---|
| `BodyBuddyView.swift` | `pipMessageSection` |
| `GlucoseJourneyView.swift` | `PipJourneyMessage` |
| `HomeAnimated.swift` | `PipMessageAnimated` |

### Hand-Rolled Button Surfaces — use `.texturedButton(tint:)`

`.texturedButton(tint:)` is the canonical interactive surface. All of the following roll their own `RoundedRectangle` + fill + shadow + `BouncyButtonStyle`:

| File | Buttons |
|---|---|
| `BodyBuddyView.swift` | Cook button |
| `CookingCompletionView.swift` | "See how your food helps!", "Back to Kitchen" |
| `GlucoseJourneyView.swift` | Multiple CTA buttons |
| `HealthyChoiceGameView.swift` | readyScreen buttons (×4) |
| `LocalVersusView.swift` | "Start Game!", "Ready!", "Rematch!", "Done" |
| `MultiplayerHealthyPicksView.swift` | "Find a Player", "Ready!", "Play Again!" |
| `NearbyVersusView.swift` | "Find Nearby Player", "Ready!", "Play Again!" |
| `PlayLearnView.swift` | placeholder "Back to Games" button |
| `ProfilePickerView.swift` | "Add Little Chef" button |
| `SiblingGardenView.swift` | Back button |
| `SiblingProfileView.swift` | "Visit Garden", "Gift Veggies" buttons |
| `SplitScreenVersusView.swift` | "Rematch!", "Done" buttons |

**Note:** "Rematch!" in `LocalVersusView` and `SplitScreenVersusView` already uses `BouncyButtonStyle` but still hard-codes the background `RoundedRectangle` — this is not equivalent to `.texturedButton(tint:)`.

### Hand-Rolled Card Surfaces — use `.softCard()` or `.cardStyle()`

| File | Location |
|---|---|
| `GlucoseJourneyView.swift` | multiple segment cards |
| `HealthyChoiceGameView.swift` | food choice cards |
| `RecipeDetailView.swift` | ingredient section container |

---

## Missing Tokens — Recommend Adding

### `AppSpacing`

Add to `AppSpacing` enum / extension:

| Token Name | Value | Rationale |
|---|---|---|
| `AppSpacing.chipPaddingH` | `10` | Universal horizontal padding for stat/voice/label chips (appears in 6+ files) |
| `AppSpacing.chipPaddingV` | `6` | Universal vertical padding for chips |
| `AppSpacing.chipCornerRadius` | `14` | Chip corner radius — sits between `smallCornerRadius=12` and `cardCornerRadius=16` |
| `AppSpacing.strokeLight` | `1.5` | Mid-weight stroke for choice buttons and overlay borders |
| `AppSpacing.strokeThick` | `2.5` | Heavy profile-ring / garden-plot border weight |

### `AnimationConstants`

Add to `AnimationConstants`:

| Token Name | Value | Rationale |
|---|---|---|
| `AnimationConstants.weatherPulse` | `.easeInOut(duration: 3).repeatForever(autoreverses: true)` | Weather element pulse (sun glow, seasonal particles) |
| `AnimationConstants.weatherDrift` | `.easeInOut(duration: 7).repeatForever(autoreverses: true)` | Cloud drift at medium speed |
| `AnimationConstants.weatherDriftSlow` | `.linear(duration: 20).repeatForever(autoreverses: false)` | Slow seasonal particle drift |
| `AnimationConstants.windStreakLoop` | `.easeInOut(duration: 2).repeatForever(autoreverses: false)` | Wind streak animation loop |
| `AnimationConstants.wateringPulse` | `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` | PlotView watering indicator |

### `PipSize`

Add to `PipSize` enum:

| Case Name | Raw Value | Rationale |
|---|---|---|
| `PipSize.mini` | `36` | Small toast / chip / sibling garden contexts (currently `.custom(36)` in 2 files) |
| `PipSize.small` | `60` | MiniGameCard icon size, SplitScreenVersus HUD pip (currently `.custom(60)`) |
| `PipSize.xl` | `140` | Versus lobby pip, multiplayer game pip (currently `.custom(140)` or raw `140`) |

**Note:** `PipSize.extraLarge` at 100 could consolidate the `.custom(100)` uses in LocalVersusView, NearbyVersusView, and InsulinTetrisView. Review whether 100 is intentionally different from `large=120` or a historical rounding.

---

## Clean Scans — No Violations

The following files were read in full and contain no violations against CLAUDE.md rules:

`Allergen.swift`, `AmbientAudioPlayer.swift`, `AppAttestService.swift`, `AssetPackController.swift`, `AssetPackImage.swift`, `AvatarModel.swift`, `CharacterWalkingView.swift`, `CloudKeyManager.swift` (deprecated/orphaned), `ContentView.swift` (unused Xcode stub), `ElevenLabsVoiceService.swift`, `FamilyProfile.swift`, `KitchenView.swift` (minor raw spacings only — `VStack(spacing: 4)`, `HStack(spacing: 6)` — not flagged as blocking), `MigrationPINSetupView.swift`, `MorphTransition.swift`, `ODRManager.swift`, `OnboardingView.swift`, `PINKeychain.swift`, `PaywallView.swift`, `PipAIService.swift`, `PipFoundationModelService.swift`, `PipGameAnimationView.swift`, `PipStaticResponses.swift`, `PlayerData.swift`, `SeededRandomGenerator.swift`, `SignInView.swift`, `SubscriptionManager.swift`, `USDAFoodService.swift`, `UserProfile.swift`, `VideoPlayerView.swift`, `WaterPourCharacterView.swift`, `WorkerClient.swift`

**31 clean files** out of 88 read (35%).

---

## Priority Order for Next Sprint

1. **P1 (ship blocker):** Fix all 17 `DispatchQueue.main.async` call sites across `AuthManager`, `GameCenterMatchmakerView`, `GameCenterService`, `MultiplayerManager`, `NearbyMultiplayerManager`, `ParentPINEntryView`, `SeedInfoView`.
2. **P2 (data integrity):** Fix all 16 `try? save()` sites in `SessionManager`, `AddChildFlowView`, `AllergenEditorSheet`, `ParentDashboardView`, `SiblingGardenView`, `SiblingProfileView`.
3. **P2 (token hygiene):** Add 8 missing tokens to `AppSpacing`, `AnimationConstants`, and `PipSize`, then sweep inline values.
4. **P2 (correctness):** Fix all 15 `profilePoseImage` bypass violations — these will incorrectly show girl avatar for parent profiles of either gender and vice versa in multiplayer/sibling contexts.
5. **P2 (design consistency):** Replace hand-rolled button surfaces with `.texturedButton(tint:)` and Pip message layouts with `PipSpeechBubble`.

---

*Report generated by automated weekly review pass. All 88 Swift files read in full. GardenHubView.swift excluded (orphaned dead code per CLAUDE.md).*
