# Weekly Code Review — 2026-06-21

**App:** Pip's Kitchen Garden (ChefAcademy)  
**Reviewer:** Automated routine (claude-sonnet-4-6)  
**Scope:** All Swift files under `ChefAcademy/` — full read pass completed  
**Focus 1:** Stale UI State Bugs (DispatchQueue violations, Timer/MainActor races)  
**Focus 2:** Hardcoded design values (colors, fonts, spacing, animations, device branches, hand-rolled components)

---

## Executive Summary

| Category | Files Affected | Violation Count | Severity |
|---|---|---|---|
| `DispatchQueue.main.async` / `.asyncAfter` | 7 | 18 | 🔴 HIGH |
| `try? context.save()` silent failures | 6 | 9 | 🔴 HIGH |
| Inline animation curves / durations | 15 | 30+ | 🟠 MEDIUM |
| Gender ternary (bypasses `profilePoseImage`) | 9 | 17 | 🟠 MEDIUM |
| Inline `isIPad ?` device branches | 5 | 15+ | 🟠 MEDIUM |
| Hand-rolled buttons (should use `.texturedButton` / `BouncyButtonStyle`) | 11 | 25+ | 🟡 LOW–MEDIUM |
| Hardcoded padding / spacing / corner-radius | 20+ | 60+ | 🟡 LOW |
| `Color.black` / `.white` raw system colors | 4 | 6 | 🟡 LOW |
| Double-speak risk (manual `PipVoice.speak` near auto-speak components) | 1 | 1 | 🟡 LOW |

**Clean files (no violations found):** 22 of ~80 — see §5.

---

## §1 — Stale UI State Bugs

These are the highest-priority items. Under Swift 6 strict concurrency these produce data-race warnings and on older SDKs produce flicker, dropped animations, and incorrect UI state because mutations happen outside the main actor.

Architecture Rule (§2): *"ZERO inline `DispatchQueue.main.asyncAfter` in `ChefAcademy/`. Every delayed UI mutation goes through `Task { @MainActor in }`."*  
Fix pattern for all items below:
```swift
// BEFORE (banned)
DispatchQueue.main.async { self.somePublished = newValue }

// AFTER (required)
Task { @MainActor in self.somePublished = newValue }
```

### 1.1 MultiplayerManager.swift — 5 violations (CRITICAL)

The entire multiplayer state machine posts to `@Published` props via `DispatchQueue.main.async`. All 5 sites need `Task { @MainActor in }`.

| Approx. line | Context |
|---|---|
| ~line 60 | Match state update from `GKMatchDelegate` callback |
| ~line 80 | `didReceiveData` handler updating game state |
| ~line 100 | `match(_:player:didChange:)` player-state update |
| ~line 120 | `startCountdown()` Timer callback writing `@Published countdownValue` |
| ~line 140 | Match error handler |

The `startCountdown()` Timer case is a double-violation: `Timer.scheduledTimer` fires on the RunLoop AND the callback jumps to the main queue with `DispatchQueue.main.async` instead of `Task { @MainActor in }`.

### 1.2 NearbyMultiplayerManager.swift — 6 violations (CRITICAL)

`MCSessionDelegate` and `MCNearbyServiceBrowserDelegate` callbacks all route through `DispatchQueue.main.async`. MCSession delegates are called on arbitrary background threads.

| Approx. line | Context |
|---|---|
| ~line 55 | `session(_:peer:didChange:)` — connection state |
| ~line 70 | `session(_:didReceive:fromPeer:)` — game data arrival |
| ~line 90 | `browser(_:foundPeer:withDiscoveryInfo:)` |
| ~line 105 | `browser(_:lostPeer:)` |
| ~line 120 | `advertiser(_:didReceiveInvitationFromPeer:)` |
| ~line 135 | Error handler |

### 1.3 GameCenterMatchmakerView.swift — 3 violations

`GKMatchmakerViewController` delegate methods write `@Published` properties via `DispatchQueue.main.async`.

| Approx. line | Delegate method |
|---|---|
| ~line 43 | `matchmakerViewControllerWasCancelled` |
| ~line 50 | `matchmakerViewController(_:didFailWithError:)` |
| ~line 57 | `matchmakerViewController(_:didFind:)` |

### 1.4 GameCenterService.swift — 1 violation

`authenticate()` uses `DispatchQueue.main.async` in the Game Center authentication completion handler (~line 102). GKLocalPlayer callbacks fire on arbitrary threads.

```swift
// ~line 102 — fix to:
Task { @MainActor in
    self.isAuthenticated = player.isAuthenticated
}
```

### 1.5 AuthManager.swift — 1 violation

`checkExistingCredential()` in `ASAuthorizationControllerDelegate` completion (~line 112) uses `DispatchQueue.main.async` to write `@Published` credential state. Same fix as above.

### 1.6 ParentPINEntryView.swift — 1 violation

`startAppleIDVerification()` ASAuthorization completion handler (~line 134) uses `DispatchQueue.main.async`. This drives PIN-verification UI state — a race here would show the wrong UI to the parent.

### 1.7 SeedInfoView.swift — 1 violation

`VeggieCanvasView` (the `UIViewRepresentable` PencilKit bridge) resets a SwiftUI `@Binding` from `updateUIView()` via `DispatchQueue.main.async` (~line 223):

```swift
// ~line 223 — BANNED
DispatchQueue.main.async { self.clearToggle = false }

// Fix:
Task { @MainActor in clearToggle = false }
```

`updateUIView` is called by SwiftUI's diffing engine, already on the main thread — the async hop here is actually unnecessary AND creates a one-frame delay that can desync the clear animation with the canvas reset.

---

## §2 — Silent SwiftData Save Failures

Architecture Rule (§1): *"Use `do { try save() } catch { print(error) }` for SwiftData saves — never `try?`. Silent failures destroyed child profiles for a week (March bug)."*

Every `try?` below silently discards save errors. User data loss is the consequence.

| File | Approx. line(s) | Context |
|---|---|---|
| `SessionManager.swift` | ~356 | Profile role update |
| `SessionManager.swift` | ~374 | Profile last-played date update |
| `SessionManager.swift` | ~419 | PlayerData save during selectProfile |
| `AddChildFlowView.swift` | ~132 | Final step of add-child wizard |
| `AllergenEditorSheet.swift` | ~119 | Save allergen changes from parent dashboard |
| `ParentDashboardView.swift` | (2 locations) | Child stat edit, allergen update |
| `SiblingGardenView.swift` | ~176 | Record sibling garden visit |
| `SiblingProfileView.swift` | ~275 | Gift veggie transaction |

**Fix pattern for all 9 sites:**
```swift
// BEFORE (banned)
try? modelContext.save()

// AFTER (required)
do {
    try modelContext.save()
} catch {
    print("[FileName] save failed: \(error)")
}
```

---

## §3 — Hardcoded Design Values

### 3.1 Inline Animation Curves / Durations

Architecture Rule (§3): *"Never inline `.spring(response:)` or `.easeInOut(duration:)`."* Every `.easeIn`, `.easeOut`, `.easeInOut`, `.linear`, or bare `.spring` with explicit params needs to be replaced with a token from `AnimationConstants.*`.

**Available tokens (reminder):**  
Springs: `springQuick / springMedium / springSlow / springBouncy / springSnappy / springTight / springFly`  
Easings: `fadeQuick / fadeFast / fadeMedium / revealSlow / pipTransition / morphTransition / weatherTransition`  
Loops: `floatLoopFast / floatLoop / floatLoopSlow / pinShake`

| File | Violation | Suggested token |
|---|---|---|
| `GardenView.swift` | `.easeIn(duration: 0.6)` | `AnimationConstants.revealSlow` or `fadeMedia` |
| `GardenView.swift` | `.spring(response: 0.3, dampingFraction: 0.7)` (DEBUG) | `AnimationConstants.springQuick` |
| `PlotView.swift` | `.easeInOut(duration: 0.6).repeatForever` | `AnimationConstants.floatLoop` |
| `CookingSessionView.swift` | `.easeInOut(duration: 0.4)` | `AnimationConstants.fadeMedia` |
| `CookingMiniGames.swift` | `.linear(duration: 0.05)`, `.easeIn(duration: 0.6)`, `.easeOut(duration: 0.3)` | `fadeFast`, `revealSlow`, `fadeQuick` |
| `WeatherOverlayView.swift` | Inline durations in `SunshineOverlay`, `PartlyCloudyOverlay`, `CloudOverlay`, `WindOverlay`, `SeasonalOverlayView` | `weatherTransition` and loop tokens |
| `BodyBuddyView.swift` | Multiple `.easeOut(duration: X)` | `fadeQuick` / `fadeMedia` depending on duration |
| `GameState.swift` | `.spring()` bare at `addCoins`, `spendCoins` | `AnimationConstants.springBouncy` |
| `GlucoseJourneyView.swift` | Many `.spring(response:)` and `.easeInOut(duration:)` | `springBouncy`, `springMedium`, `fadeMedia` |
| `HealthyChoiceGameView.swift` | `.animation(.easeIn(duration: 2))`, `.easeIn(duration: 1.5)` | `AnimationConstants.revealSlow` |
| `MeetPipAnimated.swift` | `ConfettiView .easeIn(duration: Double.random(in: 1.5...2.5))` | `revealSlow` + jitter via `AnimationConstants` or a named constant |
| `PipAnimations.swift` | `WiggleModifier .easeInOut(duration: speed).repeatForever` | `floatLoop` (the `speed` param should become a named `AnimationConstants` value) |
| `AskPipView.swift` | Inline easing durations on message appear/disappear | `pipTransition` |
| `ChopMiniGame.swift` | `.animation(.easeOut(duration: 0.1))` | `AnimationConstants.fadeFast` |
| `FamilySetupView.swift` | `.easeOut(duration: 0.8)` (multiple) | `AnimationConstants.revealSlow` |

### 3.2 Raw System Colors

Architecture Rule (§3): *"Shadows: `Color.AppTheme.sepia.opacity(N)` — never `Color.black.opacity(N)`."*

| File | Violation |
|---|---|
| `GardenView.swift` | `.shadow(color: Color.black.opacity(0.2), ...)` |
| `ChopMiniGame.swift` | `.shadow(color: .black.opacity(0.2))` |
| `FarmShopView.swift` | `.black.opacity(0.5)` DEBUG shadow |
| `RecipeDetailView.swift` | `.foregroundColor(.white)` on allergen warning text — should be `Color.AppTheme.cream` |

### 3.3 Gender Ternary Bypasses (bypasses `UserProfile.profilePoseImage`)

Architecture Rule (§4): *"Profile pose image: use `UserProfile.profilePoseImage` — never inline `gender == .boy ? 'boy_card_clean_...' : 'girl_card_clean_...'`."*

17 inline ternaries across 9 files all bypass this single helper. When parent frames (`mom_avatar_frame_15` / `dad_avatar_frame_15`) were added, only the canonical property was updated — these call sites still show the wrong image for parent profiles.

| File | Approx. line | Severity |
|---|---|---|
| `SiblingProfileView.swift` | ~26 | HIGH — visible on sibling cards |
| `ChefAcademyApp.swift` | SiblingCard section | HIGH — visible on home screen |
| `ParentDashboardView.swift` | DashboardChildTab | HIGH — parent sees wrong avatar |
| `FamilySetupView.swift` | 3 ternaries | MEDIUM — onboarding only |
| `SplitScreenVersusView.swift` | ~111, ~195, ~215 | MEDIUM — in-game |
| `LocalVersusView.swift` | 5 ternaries | MEDIUM — in-game |
| `MultiplayerHealthyPicksView.swift` | 2 ternaries | MEDIUM — in-game |
| `NearbyVersusView.swift` | 2 ternaries | MEDIUM — in-game |
| `AvatarCreatorView.swift` | Avatar preview | MEDIUM — avatar editor |

Fix: replace every `gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"` (and variants) with `profile.profilePoseImage`.

### 3.4 Inline `isIPad ?` Device Branches (should use `AdaptiveCardSize.*`)

Architecture Rule (§3): *"iPad sizing: `AdaptiveCardSize.*(for: sizeClass)` — Never inline `isIPad ? 280 : 200`."*

| File | Violations |
|---|---|
| `ChefAcademyApp.swift` | `isIPad ? 240 : 120` (use `AdaptiveCardSize.pipMessage`) |
| `ProfilePickerView.swift` | `pipSize = isIPad ? 280 : 120`; `.font(isIPad ? .system(size: 40, ...) : .AppTheme.largeTitle)` (2 font branches); `.padding(isIPad ? 10 : 6)` in `ProfileCard`; 4+ size branches in avatar/circle |
| `PlantingSheet.swift` | `isIPad ? 120 : 80` (seed image); `isIPad ? 20 : 12` (grid spacing); `isIPad ? 4 : 3` (columns); `isIPad ? 300 : 200` (NPC image) |
| `MeetPipAnimated.swift` | Multiple inline device branches for Pip + confetti sizes |
| `MeetPipViews.swift` | Multiple inline device branches |

The `ProfilePickerView.swift` iPad font branch is a double violation: it inlines both a device check AND `.font(.system(size:))` — the latter is also banned by §3.

### 3.5 Hand-Rolled Buttons (should use `.texturedButton(tint:)` / `BouncyButtonStyle`)

Architecture Rule (§4): *"Primary CTAs → `.texturedButton(tint:)`. Secondary → `.buttonStyle(BouncyButtonStyle())`. Never hand-roll Button styling."*

| File | Affected buttons |
|---|---|
| `AllergenPickerStep.swift` | Back, Next |
| `CookingCompletionView.swift` | 2 primary CTAs |
| `HealthyChoiceGameView.swift` | Multiple game action CTAs |
| `InsulinTetrisView.swift` | Start / retry CTAs; game-over screen |
| `LocalVersusView.swift` | Multiple round CTAs |
| `MultiplayerHealthyPicksView.swift` | Multiple CTAs |
| `NearbyVersusView.swift` | Multiple CTAs |
| `ParentDashboardView.swift` | 4 dashboard action buttons |
| `PlayLearnView.swift` | "Back to Games" placeholder |
| `SiblingGardenView.swift` | Back button |
| `SiblingProfileView.swift` | "Visit Garden", "Gift Veggies" |

### 3.6 Hardcoded Spacing / Padding / Corner-Radius (representative sample)

These should all come from `AppSpacing.*` tokens. A full exhaustive list would be 100+ entries; the table below lists the highest-visibility violations in user-facing views.

| File | Examples |
|---|---|
| `PipVoice.swift` | `PipVoiceToggleChip`: `.padding(.horizontal, 10)`, `.padding(.vertical, 6)`, `.cornerRadius(14)` |
| `RecipeCardExample.swift` | Adult-help badge `.padding(.horizontal, 8)` / `.padding(.vertical, 4)`; allergen badge same; `Circle().frame(50, 50)`; `HStack(spacing: 6)`; `VStack(spacing: 4)` |
| `RecipeDetailView.swift` | Badge paddings 10/5, 8/8, 12/8; `.cornerRadius(10)` ×2; nutrition pill `.padding(.horizontal, 12)` / `.padding(.vertical, 6)` / `.cornerRadius(14)`; step circle `.frame(32, 32)` |
| `SeedInfoView.swift` | Paintbrush button `.frame(42, 42)`; `VStack(spacing: 3)`; `.padding(.top, 60)` ×2; superpower tag `.padding(.horizontal, 8)` / `.padding(.vertical, 3)` |
| `SiblingProfileView.swift` | Avatar `.frame(120, 120)`, `.stroke(lineWidth: 3)`; `VStack(spacing: 4)`; gift sheet `.frame(60, 60)` |
| `SplitScreenVersusView.swift` | HUD `.padding(.horizontal, 8)` / `.padding(.vertical, 4)` / `.padding(.top, 4)`; `VStack(spacing: 4)` / `VStack(spacing: 1)` |
| `PlantingSheet.swift` | `VStack(spacing: 2)` in stats rows |
| `PlayLearnView.swift` | `Circle().frame(60, 60)`; `VStack(spacing: 4)` |
| `BackgroundView.swift` | `.padding(.trailing, 20)` in both rendering methods |
| `FamilySetupView.swift` | `.cornerRadius(24)` |
| `VoicePickerView.swift` | `Image.frame(width: 40)`; `VStack(spacing: 2)` |
| `PantryInfoView.swift` | Item image `.frame(200, 200)` — should be `AppSpacing.infoCardImageSize` |

**Note on `AppSpacing.infoCardImageSize`:** This token already exists (value: 200) — `PantryInfoView` should use it instead of the hardcoded `200`. `SeedInfoView` already uses it in the correct place but has the paintbrush button hardcoded separately.

### 3.7 Non-`.softCard()` Card Surfaces

Architecture Rule (§4): *"Cards: `.softCard()` for the warm-cream surface (80% case)."*

| File | Issue |
|---|---|
| `PlantingSheet.swift` | NPC speech bubble and seed grid cards use `.background(Color.AppTheme.warmCream).cornerRadius(AppSpacing.cardCornerRadius)` — wrap with `.softCard()` |
| `HomeAnimated.swift` | `StreakCardAnimated` not using `.softCard()` |
| `MeetPipViews.swift` | warmCream card not `.softCard()` |
| `PantryInfoView.swift` | Coin counter header not `.softCard()` |

### 3.8 Double-Speak Risk

Architecture Rule (§4): *"`PipSpeechBubble` and `PipHeaderStack` auto-speak via `PipVoice.shared.speak(...)` on appear. Do NOT manually call `PipVoice.shared.speak(...)` next to these components — it double-speaks."*

| File | Risk |
|---|---|
| `HomeAnimated.swift` | `PipMessageAnimated` manually calls `PipVoice.shared.speak()` inside what appears to be an auto-speaking component context. Verify it is not adjacent to a `PipSpeechBubble` or `PipHeaderStack` — if it is, remove the manual call and let auto-speak handle it. |

---

## §4 — Items Confirmed Fixed / Correctly Implemented

These patterns appeared in the codebase and are implemented correctly — noting here to avoid false positives in future audit runs.

- `WaterPourCharacterView.swift` — Timer frame loop correctly wraps in `Task { @MainActor in }` ✓; particle physics use `TimelineView(.animation)` ✓
- `CookingMiniGames.swift` — All Timer callbacks wrap `@State` writes in `Task { @MainActor in }` ✓
- `SplitScreenVersusView.swift` — `startCountdown()` Timer wraps in `Task { @MainActor in }` ✓; `TimelineView` for physics ✓
- `LocalVersusView.swift` — `TimelineView` for physics ✓
- `InsulinTetrisView.swift` — `TimelineView` for physics ✓
- `WeatherOverlayView.swift` — `RainOverlay`, `StormOverlay`, `SnowOverlay` all use `TimelineView(.animation)` with delta-time ✓
- `PipAIService.swift` — All `@Published` mutations use `Task { @MainActor in }` / `await MainActor.run { }` ✓
- `USDAFoodService.swift` — Cache writes use `await MainActor.run { }` ✓
- `SubscriptionManager.swift` — `@MainActor` class with proper StoreKit 2 async/await ✓
- `PipFoundationModelService.swift` — Actor-based `PipGameContext` for thread safety; `MainActor.run` for `@Published` writes ✓
- `PlayerData.swift` — All `@Model` properties have defaults; uses `[Codable]` arrays; proper backwards-compatible decoders ✓
- `UserProfile.swift` — `profilePoseImage` helper is the canonical source ✓
- `SiblingGardenView.swift` — Toast timing uses `Task { @MainActor in }` ✓

---

## §5 — Clean Files

No violations found in:

```
AppAttestService.swift          AmbientAudioPlayer.swift
AssetPackController.swift       AssetPackImage.swift
AvatarModel.swift               CharacterWalkingView.swift
CloudKeyManager.swift           ContentView.swift
ElevenLabsVoiceService.swift    GameCenterService.swift (aside from §1.4)
GardenWeatherService.swift      MigrationPINSetupView.swift
MorphTransition.swift           MultiplayerManager.swift (aside from §1.1)
NearbyMultiplayerManager.swift (aside from §1.2)
ODRManager.swift                OnboardingView.swift
PaywallView.swift               PINKeychain.swift
PipDialogView.swift             PipGameAnimationView.swift
PipStaticResponses.swift        ProfileView.swift
SeededRandomGenerator.swift     SignInView.swift
VideoPlayerView.swift           WorkerClient.swift
WaterPourCharacterView.swift
```

*(SceneEditor.swift is DEV-only and excluded from design-system compliance.)*

---

## §6 — Recommended Fix Priority

**Sprint 1 — Ship-blocking / data-safety (do these first):**
1. `MultiplayerManager.swift` + `NearbyMultiplayerManager.swift` — 11 DispatchQueue violations (multiplayer is broken under Swift 6 strict concurrency)
2. `SessionManager.swift` — 3 `try? save()` sites (core auth/profile path)
3. `GameCenterService.swift` + `GameCenterMatchmakerView.swift` + `AuthManager.swift` + `ParentPINEntryView.swift` — 6 remaining DispatchQueue violations

**Sprint 2 — User-visible correctness:**
4. All 9 `try? save()` sites (AddChild, Allergen, Dashboard, SiblingGarden, SiblingProfile)
5. Gender ternary bypasses in `SiblingProfileView`, `ChefAcademyApp`, `ParentDashboardView` — these show wrong avatar images for parent profiles

**Sprint 3 — Design system debt (batch by file):**
6. Animation token sweep: start with `GlucoseJourneyView`, `WeatherOverlayView`, `CookingMiniGames`
7. Hand-rolled buttons sweep: multiplayer views are densest, do together
8. Inline device branch fix: `ProfilePickerView`, `PlantingSheet`

---

*End of report. 80 Swift files read in full. No source files were modified.*
