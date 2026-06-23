# Weekly Code Review — 2026-06-23

> **Scope:** Full read of all 88 Swift files under `ChefAcademy/`.
> **Focus 1:** Stale UI state bugs — Timer/concurrency patterns, silent save failures, behavioral bugs.
> **Focus 2:** Hardcoded values — colors, fonts, animations, dimensions, device branches; component reuse violations.
> Rule references are to CLAUDE.md section numbers (§1–§11).

---

## 1. Summary

| Category | Count | Severity |
|---|---|---|
| `try? save()` silent failures (§1) | ~20 call sites across 8 files | **HIGH** — data loss risk |
| `DispatchQueue.main.async` (§2) | 17 sites across 7 files | **HIGH** — data race risk |
| Hardcoded spring / easing animations (§3) | 40+ inline animation values | **MED** — design debt |
| `profilePoseImage` bypasses (§4) | 15+ gender ternary sites across 8 files | **MED** — will break with parent frames |
| `Color.black` shadow violations (§3) | 5 production sites | **MED** — off-brand |
| `.font(.system(size:)` (§3) | 4 production + 10+ DEV-only | **MED** / LOW |
| Hand-rolled button/card styling (§4) | 12+ sites | **LOW** — visual inconsistency |
| Inline `isIPad ? X : Y` branches (§3) | 20+ (PlantingSheet, ProfilePickerView severe) | **MED** — iPad regressions |
| Behavioral bugs | 2 | **MED** |
| GardenWeatherService main-thread mutation | 1 | **MED** |

**Top 3 things to fix first:**
1. All `try? save()` sites → `do/catch` (prevents silent data loss).
2. `MultiplayerManager` + `NearbyMultiplayerManager` `DispatchQueue.main.async` in Timer+delegate callbacks (race conditions in game-critical paths).
3. `GlucoseJourneyView.swift` animation overhaul (18+ hardcoded `.spring()` — worst single file).

---

## 2. Files Reviewed

88 files read in full. All source files under `ChefAcademy/` covered.

**Fully clean (no violations):**
`MorphTransition`, `PINKeychain`, `Allergen`, `AppAttestService`, `AssetPackController`, `AssetPackImage`, `CloudKeyManager`, `FamilyProfile`, `SubscriptionManager`, `PipStaticResponses`, `SeededRandomGenerator`, `WorkerClient`, `AmbientAudioPlayer`, `AvatarModel`, `CharacterWalkingView`, `ODRManager`, `USDAFoodService`, `PipAIService`, `PipFoundationModelService`

**Notes on dead/legacy files:**
- `GardenHubView.swift` — orphaned dead code per §9; violations inside it are noted but not actionable.
- `ContentView.swift` — legacy root file with a template `.foregroundStyle(.tint)` leftover. Dead.
- `CloudKeyManager.swift` — scheduled for Phase 4 deletion.
- `SceneEditor.swift` — DEV-only tool; violations logged but lowest priority.

---

## 3. Critical Issues (P0)

### C-01 · Silent SwiftData save failures — ~20 sites, 8 files (§1)

The March data-loss incident was caused by exactly this pattern. Every `try?` on a save call must become `do { try X.save() } catch { print(error) }`.

**Files and lines:**

| File | Lines | Context |
|---|---|---|
| `SessionManager.swift` | 100, 206, 230, 271, 294, 355, 373, 419, 454, 465 | Profile CRUD, play time, sign out, migration |
| `FamilySetupView.swift` | 204 | `finishSetup()` — silent failure loses entire onboarding |
| `ParentDashboardView.swift` | 461, 490 | `deleteAllDataAndRestart()`, `linkAppleID()` |
| `SiblingGardenView.swift` | 36, 176 | Like garden, `handleHelpAction` |
| `SiblingProfileView.swift` | 275 | `giftVeggie()` |
| `AddChildFlowView.swift` | 132 | Child profile save — comment even says "fixes delayed appearance" |
| `AllergenEditorSheet.swift` | 119 | `saveAndDismiss()` |
| `ChefAcademyApp.swift` | 464 | App-level save |

Note: `try? modelContext.fetch(...)` with `?? []` fallback is a different risk profile (read errors rarely cause data loss) — those in `ParentDashboardView:454–456` and `FamilyProfile` are flagged for awareness but lower priority.

### C-02 · `DispatchQueue.main.async` in multiplayer managers (§2)

`MultiplayerManager` and `NearbyMultiplayerManager` use `DispatchQueue.main.async` in delegate callbacks and Timer callbacks — the banned concurrency pattern. Because these files also use `Timer.scheduledTimer` with a `DispatchQueue.main.async` inside the callback (the forbidden double-pattern), there is an active data-race risk on `@Published` properties during multiplayer sessions.

**`MultiplayerManager.swift`:**
- Line 65 — `authenticateHandler` callback → `DispatchQueue.main.async`
- Line 196 — `handleMessage` → `DispatchQueue.main.async`
- Lines 240–248 — `Timer.scheduledTimer` countdown → **`DispatchQueue.main.async` inside callback** (double violation)
- Line 297 — `match(_:player:didChange:)` → `DispatchQueue.main.async`
- Line 321 — `match(_:didFailWithError:)` → `DispatchQueue.main.async`

**`NearbyMultiplayerManager.swift`:**
- Line 155 — `handleMessage` → `DispatchQueue.main.async`
- Lines 198–209 — `Timer.scheduledTimer` countdown → **`DispatchQueue.main.async` inside callback** (double violation)
- Lines 221, 241, 286, 308 — delegate callbacks → `DispatchQueue.main.async`

**Fix:** Replace every `DispatchQueue.main.async { ... }` with `Task { @MainActor in ... }`. For the Timer+DispatchQueue double-pattern, replace with `Task { @MainActor in ... }` as the single wrapping.

**Also affected (lower severity — delegate/UIKit context):**
- `GameCenterMatchmakerView.swift:42, 50, 59` — UIViewControllerRepresentable coordinator callbacks
- `GameCenterService.swift:102` — `authenticateHandler` → `DispatchQueue.main.async`
- `ParentPINEntryView.swift:134` — Apple ID verification callback
- `AuthManager.swift:113` — credential check callback
- `SeedInfoView.swift:222` — `UIViewRepresentable.updateUIView` (lowest severity; UIKit context)

---

## 4. Focus 1 — Stale UI State

### S-01 · `GardenWeatherService.swift:360` — direct `@Published` mutation from delegate thread

`locationManager(_:didUpdateLocations:)` sets `self.currentSeason = ...` at line 360 directly in the delegate callback (which does not run on main thread by default), but then calls `fetchWeather()` inside a `Task { @MainActor in }` at line 363. The `currentSeason` mutation must be moved inside that `Task`.

```swift
// Current (line 360 — WRONG):
currentSeason = season(for: now)
Task { @MainActor in
    await fetchWeather()
}

// Fix:
Task { @MainActor in
    self.currentSeason = season(for: now)
    await fetchWeather()
}
```

### S-02 · `AddToPanMiniGame.checkDrop` — both branches identical (behavioral bug)

In `CookingMiniGames.swift`, the `if inTarget` success branch and the `else` miss branch both apply the same `dragOffset` and `itemScale` values (discovered by agent review). The miss branch should snap the item back to origin, not to the pan. Requires reading the exact line numbers to confirm values before patching.

### S-03 · `CrackEggMiniGame` — dead `@State private var eggParts: CGFloat = 0`

Unused state variable, never read or written after declaration. Remove it.

### S-04 · Timer at game frame rates without `TimelineView` (§2 physics rule)

Two animation views still use `Timer.scheduledTimer` at frame rates instead of `TimelineView(.animation)` + delta-time. Timer-based animation breaks on ProMotion 120Hz and CPU-throttled states.

| File | Timer interval | Rate |
|---|---|---|
| `PipGameAnimationView.swift:64` | `1.0 / AnimationConstants.gameFPS` | 30fps |
| `PipAnimations.swift:103` (`OneShotFrameAnimationView`) | `1.0 / fps` | variable |

These correctly wrap mutations in `Task { @MainActor in }` ✓, but should migrate to `TimelineView` + delta-time for correctness (see `CharacterWalkingView` for the canonical pattern).

### S-05 · All Timers wrapping mutations correctly (✓ verified)

The following Timer callbacks were confirmed to properly wrap `@State`/`@Published` mutations in `Task { @MainActor in }`:
`PlotView`, `WaterPourCharacterView`, `ChopMiniGame`, `SessionManager`, `FamilySetupView` (×3), `SplitScreenVersusView` (×2), `LocalVersusView`, `MultiplayerHealthyPicksView`, `NearbyVersusView`, `GardenWeatherService`, `PipAnimations` (×2), `OnboardingView`, `CookingMiniGames` (×3).

### S-06 · Physics loops using `TimelineView` + delta-time (✓ verified)

All high-frequency game physics loops confirmed compliant:
`RainOverlay`, `StormOverlay`, `SnowOverlay`, `InsulinTetrisView`, `HealthyChoiceGameView`, `WaterPourCharacterView`.

---

## 5. Focus 2 — Hardcoded Animation Values (§3)

### A-01 · `GlucoseJourneyView.swift` — worst file (18+ inline spring/easing animations)

Every animation in this file is hardcoded. These must all map to `AnimationConstants.*`:

| Pattern | Occurrences |
|---|---|
| `.spring(response: 0.3)` | Lines 390, 391, 485, 771, 787, 897, 1005, 1214, 1242 |
| `.spring(response: 0.4, dampingFraction: 0.6)` | Line 569 |
| `.spring(response: 0.4).delay(0.2)` | Line 905 |
| `.spring().delay(0.5)` | Lines 591, 1234 |
| `.spring().delay(1.0)` | Line 916 |
| `.spring().delay(1.5)` | Line 594 |
| `.spring().delay(2.0)` | Line 919 |
| `.spring()` (bare) | Lines 831, 1257 |
| `.easeInOut(duration: 0.6)` | Line 874 |
| `RoundedRectangle(cornerRadius: 4/6/2/3)` | Lines 387, 781, 783, 1000, 1002, 1092, 1096, 1346, 1350 |

Also in this file: 5× `Spacer().frame(height: 100)` at lines 297, 526, 867, 1206, 1390 — use `AppSpacing.tabBarClearance`.

### A-02 · `WeatherOverlayView.swift` — 10 inline easing animations in repeat loops

All in `onAppear` blocks for weather animations:
- Lines 81, 114, 117, 147, 150 — `.easeInOut(duration: N).repeatForever()`
- Lines 484, 487, 490 — `.easeInOut(duration: N).repeatForever().delay(N)` (seasonal overlay)
- Line 736 — `.easeInOut(duration: 3).repeatForever()` (CloudOverlay)

These should be `AnimationConstants.*` loop tokens.

### A-03 · `CookingMiniGames.swift` — 6 inline easing animations

| Line | Pattern |
|---|---|
| 469 | `.easeIn(duration: 0.6)` in `SeasonMiniGame.spawnParticle` |
| 577 | `.easeOut(duration: 0.3)` in `PeelMiniGame.handleSwipe` |
| 958 | `.easeOut(duration: 0.3)` in `WashMiniGame` |
| 963 | `.easeIn(duration: 0.3)` in `WashMiniGame.handleTap` |
| 977 | `.easeOut(duration: 0.4)` in `AssembleMiniGame` |
| 1160 | `.animation(.easeOut(duration: 0.2), value: progress)` in `CookTimerMiniGame` |
| 1219 | `.easeOut(duration: 1.0)` in `HeatPanMiniGame` |

### A-04 · Additional files with inline animation violations

| File | Lines | Patterns |
|---|---|---|
| `CookingSessionView.swift` | 523 | `.easeInOut(duration: 0.4)` |
| `FamilySetupView.swift` | 261, 1064, 1176 | `.easeOut(duration: 0.8/.0.6)` in step appear transitions |
| `GardenView.swift` | 765, 1174 | `.spring(response: 0.3, dampingFraction: 0.7)`, `.easeIn(duration: 0.6)` |
| `AskPipView.swift` | 165, 446, 806 | `.easeOut(duration: 0.3)`, `.easeInOut(duration: 0.4)`, `.easeIn(duration: 0.3)` |
| `BodyBuddyView.swift` | 92, 429, 443, 507 | `.easeOut(duration: 1.0/.0.8)` (×4) |
| `PlotView.swift` | 424 | `.easeInOut(duration: 0.6).repeatForever()` |
| `ChopMiniGame.swift` | 186 | `.easeOut(duration: 0.1)` |
| `HealthyChoiceGameView.swift` | 410, 812 | `.easeIn(duration: 2/.1.5)` |
| `MeetPipAnimated.swift` | 381 | `.easeIn(duration: Double.random(in: 1.5...2.5))` (confetti) |
| `GameState.swift` | 171, 180 | `withAnimation(.spring())` (bare, coin add/spend) |
| `PipAnimations.swift` | 489 | `.easeInOut(duration: speed)` in `WiggleModifier` |

---

## 6. Focus 2 — Color, Font, and Design Token Violations (§3)

### D-01 · `Color.black` shadow violations (production files)

Must use `Color.AppTheme.sepia.opacity(N)` per §3.

| File | Line | Pattern |
|---|---|---|
| `GardenView.swift` | 114, 352 | `.shadow(color: Color.black.opacity(0.2))` (Pip dragging/walking shadows) |
| `ChopMiniGame.swift` | 167 | `.shadow(color: .black.opacity(0.2))` on sweet spot indicator |
| `FarmShopView.swift` | 581 | `.shadow(color: .black.opacity(0.5))` on debug button |

(`SceneEditor.swift:129, 158` also has `Color.black.opacity(0.85/.0.7)` but is DEV-only.)

### D-02 · `.foregroundColor(.white)` (production)

- `RecipeDetailView.swift:78` — `.foregroundColor(.white)` on dark-background text; use `Color.AppTheme.cream`.

### D-03 · `.font(.system(size:)` (production)

- `ProfilePickerView.swift` lines 39, 86, 199, 208 — 4 occurrences; use `Font.AppTheme.*` or `Font.AppTheme.rounded(size:weight:)`.

(`SceneEditor.swift` has 10+ `.font(.system(size:)` calls — DEV-only tool, noted but low priority.)

### D-04 · Inline `isIPad ? X : Y` device branches (§3)

Must use `AdaptiveCardSize.*` or `AdaptiveValue`.

| File | Severity | Notes |
|---|---|---|
| `ProfilePickerView.swift` | **HIGH** | 14+ ternaries throughout; `pipSize`, `avatarSize`, `circleSize`, `cardWidth`, offsets, font sizes — all hardcoded |
| `PlantingSheet.swift` | **HIGH** | Pervasive — 4 adaptive size properties at top (lines 41–44) multiply into 15+ inline branches below |
| `ChefAcademyApp.swift` | MED | `PipMessageCard`: `isIPad ? 240 : 120` — use `AdaptiveCardSize.pipMessage(for:)` |
| `GardenView.swift` | MED | `isIPad ? 160 : 55` (pipSize), `cornerRadius(isIPad ? 16 : 12)` |
| `KitchenView.swift` | LOW | `.font(.AppTheme.rounded(size: isIPad ? 18 : 14))` |
| `MeetPipViews.swift` | LOW | 3× `sizeClass == .compact ? X : Y` with hardcoded sizes |

### D-05 · Hardcoded dimension magic numbers (selected egregious examples)

These are illustrative; the full list is in §5 per-file findings. Files with the most violations:

- **`ProfilePickerView.swift`** — `avatarSize 200/80`, `circleSize 220/90`, `cardWidth 280/120`, offsets behind ternaries
- **`SiblingProfileView.swift`** — `.frame(width:120,height:120)`, `lineWidth: 3` (use `AppSpacing.strokeBold`), `.frame(width:50,height:50)`, `.frame(width:60,height:60)`
- **`RecipeDetailView.swift`** — 8 hardcoded `.padding(.horizontal/vertical, N)` pairs; `.cornerRadius(10)` ×3, `cornerRadius(14)`; `.frame(height:180)`, `.frame(width:32,height:32)`; `.foregroundColor(.white)` (see D-02)
- **`BodyBuddyView.swift`** — `frame(width:50,height:50)`, `frame(width:36,height:36)`, `frame(width:70,height:70)`, `frame(width:85)`, `frame(height:300)`, `lineWidth: 4`
- **`PipVoice.swift:224–226`** — `PipVoiceToggleChip`: `.padding(.horizontal, 10)`, `.padding(.vertical, 6)`, `.cornerRadius(14)` — exact same pattern as the `HomeView` chips in `ChefAcademyApp` already flagged

**Recurring magic Spacer pattern** — `Spacer().frame(height: 100)` appears in:
`GlucoseJourneyView` (5×), `LocalVersusView`, `MultiplayerHealthyPicksView`, `HealthyChoiceGameView`, `PlayLearnView` (80pt variant).
The 100pt variants should all use `AppSpacing.tabBarClearance`.

---

## 7. Focus 2 — Component Reuse Violations (§4)

### R-01 · `profilePoseImage` bypasses — 15+ gender ternary sites across 8 production files

`UserProfile.profilePoseImage` routes parents to `mom_avatar_frame_15`/`dad_avatar_frame_15` and children to `boy/girl_card_clean_frame_N`. Every inline ternary will silently show the wrong image if a parent profile is ever rendered in these views.

| File | Lines | Count | Notes |
|---|---|---|---|
| `LocalVersusView.swift` | 199, 404, 436, 462 | 4 | All `player.profilePoseImage` |
| `SplitScreenVersusView.swift` | 111, 194, 215 | 3 | All `UserProfile.profilePoseImage` |
| `ChefAcademyApp.swift` | 669 | 1 | Sibling display in HomeView |
| `SiblingProfileView.swift` | 26 | 1 | `sibling.profilePoseImage` |
| `ParentDashboardView.swift` | 506 | 1 | `profile.profilePoseImage` |
| `NearbyVersusView.swift` | 525 | 1 | `gender == .boy` ternary in helper; UserProfile not available — architectural gap |
| `MultiplayerHealthyPicksView.swift` | 358, 601 | 2 | Network opponent + local `avatarModel` — architectural gap (AvatarModel should expose `profilePoseImage`) |
| `FamilySetupView.swift` | 373, 396 | 2 | No `UserProfile` context yet during setup — acceptable nuance, but add note |

**For the architectural gap files (`NearbyVersusView`, `MultiplayerHealthyPicksView`):** `AvatarModel` should expose a computed `profilePoseImage` property using the same logic as `UserProfile.profilePoseImage`, eliminating the inline ternary even when a `UserProfile` object is unavailable.

Dead code: `GardenHubView.swift:143` — same violation, but in the orphaned file.

### R-02 · Hand-rolled button/card styling (§4)

Primary CTAs must use `.texturedButton(tint:)`; secondary uses `BouncyButtonStyle`; cards use `.softCard()` or `.cardStyle()`. These files use manual `.background() + .cornerRadius() + .shadow()` stacks instead:

| File | Location | Fix |
|---|---|---|
| `ProfilePickerView.swift` | "Add Little Chef" button (line 88), `ProfileCard` button (line 215) | `.texturedButton(tint:)`, `.softCard()` |
| `SiblingProfileView.swift` | "Visit Garden" (line 97), "Gift Veggies" (line 114) | `.texturedButton(tint: Color.AppTheme.sage)` |
| `SplitScreenVersusView.swift` | "Next" (line 137), "Start!" (line 228), "Rematch!" (line 527), "Done" (line 538) | `.texturedButton` / `BouncyButtonStyle` |
| `ParentDashboardView.swift` | Remove/Sign Out/Link Apple ID/Delete buttons (lines 127, 247, 269, 284) | `BouncyButtonStyle` with tinted backgrounds |
| `PlayLearnView.swift` | "Back to Games" placeholder button (line 243) | `.texturedButton(tint:)` |
| `VoicePickerView.swift` | `VoiceOptionCard` (lines 151–156) | `.softCard()` |

### R-03 · `NavigationView` deprecated in production (KitchenView)

`KitchenView.swift` contains a `NavigationView { ... }` in the recipe picker sheet. The rest of the file already uses `NavigationStack` (line 87). The recipe picker sheet should be migrated to `NavigationStack` for iOS 16+ compatibility.

### R-04 · `SeedInfoView.swift:519` — tap target too small

The paintbrush button is `.frame(width: 42, height: 42)`. The UX P0 from the 05-25 audit requires ≥44pt for all interactive targets. This is 2pt under and would be flagged in App Review.

### R-05 · Duplicate organ-mapping logic (BodyBuddyView / CookingCompletionView)

`BodyBuddyView.organDisplay()` and `CookingCompletionView.boostedOrgans` both contain identical organ → (icon, color) switch statements. Extract to a shared `NutrientType.organIcon` / `NutrientType.organColor` computed property on the enum (or a static helper). When a new organ is added, both files currently need to be updated in sync.

---

## 8. Wins & Patterns to Preserve

These patterns are working well and should be held as examples when reviewing PRs:

**Concurrency:**
- Every `Timer.scheduledTimer` callback that touches `@State`/`@Published` correctly wraps in `Task { @MainActor in }` — 20+ confirmed instances.
- `PipAIService`, `USDAFoodService`, `ElevenLabsVoiceService`, `AmbientAudioPlayer` all use `await MainActor.run { }` correctly for background→main-thread state updates.
- `CookingCompletionView` was correctly migrated from `DispatchQueue.main.asyncAfter` to `Task { @MainActor in } + Task.sleep` — the canonical pattern.

**Physics loops:**
- All six high-frequency game loops use `TimelineView(.animation)` + delta-time: `RainOverlay`, `StormOverlay`, `SnowOverlay`, `InsulinTetrisView`, `HealthyChoiceGameView`, `WaterPourCharacterView`.
- Delta-time capped at 0.1s in `WaterPourCharacterView` to prevent jump after backgrounding — good defensive pattern.

**Design tokens:**
- `CharacterWalkingView` — perfectly clean: `AnimationConstants.walkingFPS`, `Color.AppTheme.sepia.opacity(0.2)` for shadow, `PipSize` for sizing.
- `AssetPackController` — all `AnimationConstants.fadeMedium`, `AppSpacing.md`, `Color.AppTheme.*` correct.
- `AllergenPickerStep` — `AnimationConstants.springQuick` used in toggle buttons ✓.

**SwiftData:**
- `FamilyProfile`, `PlayerData`, `UserProfile`, `Allergen` — all `@Model` properties have defaults, no `@Relationship` macros, UUID-based linking. §1 compliant at the model layer.

---

*Generated by weekly routine · 2026-06-23 · All 88 source files read.*
