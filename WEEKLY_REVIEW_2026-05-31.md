# Weekly Code Review — 2026-05-31

**Scope:** Full codebase pass — all 87 Swift files under `ChefAcademy/`  
**Focus:** (1) Stale-UI state bugs — concurrency rule violations; (2) Hardcoded values and missed component reuse  
**Auditor constraint:** Recommendations never introduce inline values. Every fix maps to an existing `Color.AppTheme.*` / `Font.AppTheme.*` / `AppSpacing.*` / `AnimationConstants.*` token, or recommends adding a named token to `AppTheme.swift`.

---

## Table of Contents

1. [CRITICAL — P1 Runtime Bug](#1-critical--p1-runtime-bug)
2. [HIGH — §2 Concurrency Violations (DispatchQueue.main.async)](#2-high--2-concurrency-violations)
3. [HIGH — §1 SwiftData Violations (try? save)](#3-high--1-swiftdata-violations)
4. [MEDIUM — §4 profilePoseImage Bypasses](#4-medium--4-profileposeimage-bypasses)
5. [MEDIUM — §4 Pip Bubble / Avatar Component Bypasses](#5-medium--4-pip-bubble--avatar-component-bypasses)
6. [MEDIUM — §4 CTA / Button Component Bypasses](#6-medium--4-cta--button-component-bypasses)
7. [LOW — §3 Animation Tokens Missing](#7-low--3-animation-tokens-missing)
8. [LOW — §3 Spacing / Size Tokens Missing](#8-low--3-spacing--size-tokens-missing)
9. [LOW — §3 Token Exists, Raw Value Used](#9-low--3-token-exists-raw-value-used)
10. [LOW — §3 Shadow Color Violations](#10-low--3-shadow-color-violations)
11. [LOW — §3 Deprecated API (UIScreen)](#11-low--3-deprecated-api-uiscreen)
12. [LOW — §3 Font Violations](#12-low--3-font-violations)
13. [LOW — §3 Arithmetic on Token](#13-low--3-arithmetic-on-token)
14. [Clean Files — Notable Positive Patterns](#14-clean-files--notable-positive-patterns)

---

## 1. CRITICAL — P1 Runtime Bug

### GardenView.swift L331 — Dead condition in TimelineView schedule

```swift
// CURRENT (both branches are identical — condition is never evaluated)
TimelineView(isWalking && !isDragging ? .animation : .animation) { ... }

// SHOULD BE
TimelineView(isWalking && !isDragging ? .animation : .pause) { ... }
```

**Impact:** Pip drives a full 60-fps `TimelineView` redraw of the entire garden even when idle (neither walking nor being dragged). The `.pause` schedule would cut those redraws to zero in the idle state. On lower-end devices this contributes to battery drain and thermal throttling during what should be a low-activity phase. This is likely a copy-paste regression — the intent was clearly `.pause` for the else branch.

**Fix:** Change the else branch to `.pause`.

---

## 2. HIGH — §2 Concurrency Violations

Architecture Rule §2: "ZERO inline `DispatchQueue.main.asyncAfter` in `ChefAcademy/`. Every delayed UI mutation goes through `Task { @MainActor in }`." Same applies to `DispatchQueue.main.async`.

**Pattern for every fix:**

```swift
// CURRENT
DispatchQueue.main.async {
    self.somePublishedProperty = value
}

// CORRECT
Task { @MainActor in
    self.somePublishedProperty = value
}
```

| File | Lines | Context |
|------|-------|---------|
| `AuthManager.swift` | L113 | `getCredentialState` completion handler |
| `GameCenterMatchmakerView.swift` | L42, L52, L59 | `GKMatchmakerViewControllerDelegate` callbacks |
| `GameCenterService.swift` | L102 | `authenticateHandler` closure |
| `MultiplayerManager.swift` | L65, L196, L242, L297, L321 | 5 sites: auth handler, `handleMessage`, `startCountdown` timer, `match(_:player:didChange:)`, `match(_:didFailWithError:)` |
| `NearbyMultiplayerManager.swift` | L155, L200, L221, L241, L286, L308 | 6 sites: `handleMessage`, `startCountdown` timer, `handleConnection`, `MCSessionDelegate`, `MCNearbyServiceAdvertiserDelegate`, `MCNearbyServiceBrowserDelegate` |
| `ParentPINEntryView.swift` | L134 | `startAppleIDVerification` ASCredentialIdentityStoreState callback |

**Total: 17 call sites across 6 files.**

The UIKit/GameKit/MultipeerConnectivity delegate callbacks in `GameCenterMatchmakerView`, `GameCenterService`, `MultiplayerManager`, and `NearbyMultiplayerManager` fire on framework-owned queues. Directly writing `@Published` properties there is a data race under Swift 6 strict concurrency. Each site needs the `Task { @MainActor in }` wrapper shown above.

---

## 3. HIGH — §1 SwiftData Violations

Architecture Rule §1: "Use `do { try save() } catch { print(error) }` for SwiftData saves — never `try?`. Silent failures destroyed child profiles for a week (March bug)."

| File | Line | Call site |
|------|------|-----------|
| `SessionManager.swift` | L100 | PIN migration |
| `AddChildFlowView.swift` | L133 | After inserting new child profile |
| `AllergenEditorSheet.swift` | L119 | After updating allergen list |
| `FamilySetupView.swift` | L204 | After completing setup wizard |
| `ParentDashboardView.swift` | L461 | `deleteAllDataAndRestart()` |
| `SiblingProfileView.swift` | L275 | `giftVeggie()` |

**Pattern for every fix:**

```swift
// CURRENT
try? modelContext.save()

// CORRECT
do {
    try modelContext.save()
} catch {
    print("[FileName] save failed: \(error)")
}
```

`deleteAllDataAndRestart()` in `ParentDashboardView` is especially risky — a silent save failure there means the user believes they've wiped data but the old records remain, which is actively confusing.

---

## 4. MEDIUM — §4 profilePoseImage Bypasses

Architecture Rule §4: "Use `UserProfile.profilePoseImage` — never inline `gender == .boy ? 'boy_card_clean_...' : 'girl_card_clean_...'`. The helper routes parents to mom/dad frames."

All sites below inline the gender check explicitly. Where the source is a `UserProfile`, `profile.profilePoseImage` is directly available. Where the source is a bare `Gender` enum (multiplayer opponent), flag it as a pattern inconsistency — the fix depends on whether a `UserProfile` can be passed through.

### Sites where `UserProfile` is available (clear violations):

| File | Lines | Variable |
|------|-------|----------|
| `ChefAcademyApp.swift` | L671 | `sibling` (UserProfile) |
| `LocalVersusView.swift` | L199, L404, L436, L462 | `player` (UserProfile) — 4 sites |
| `ParentDashboardView.swift` | L506 | `profile` (UserProfile) in `DashboardChildTab.characterImage` |
| `SiblingProfileView.swift` | L26 | `sibling` (UserProfile) in `characterImage` |
| `SplitScreenVersusView.swift` | L111, L194, L215 | `child`, `p1`, `p2` (UserProfile) — 3 sites |

**Total: 10 sites where `UserProfile.profilePoseImage` is available and unused.**

### Sites where only a bare `Gender` is available (pattern inconsistency):

| File | Line | Context |
|------|------|---------|
| `MultiplayerHealthyPicksView.swift` | L358 | `manager.opponentGender` is `Gender`, not `UserProfile` |
| `NearbyVersusView.swift` | L275 | Same pattern — bare `Gender` from manager |

For these two, consider whether the multiplayer managers should carry an opponent `UserProfile` snapshot (or at least a `profilePoseImage` string) rather than just `Gender`. If not, the inline ternary is technically the only option — document it as an approved exception.

---

## 5. MEDIUM — §4 Pip Bubble / Avatar Component Bypasses

Architecture Rule §4: "Pip avatars: Size via the `PipSize` enum. Never raw `Image('pip_...') .frame(width: N, height: N)`."  
Also: "`PipSpeechBubble` and `PipHeaderStack` auto-speak via `PipVoice.shared.speak(...)` on appear and message change. Do NOT manually call `PipVoice.shared.speak(...)` next to these components."

### Hand-rolled inline Pip speech patterns → should be `PipSpeechBubble(speakOnAppear: false)`

| File | What's there now | Fix |
|------|-----------------|-----|
| `BodyBuddyView.swift` | `pipMessageSection`: manual Pip avatar + warmCream bubble | Replace with `PipSpeechBubble(speakOnAppear: false, message: ...)` |
| `AskPipView.swift` L427–458 | `pipTypingIndicator`: `Image("pip_got_idea").frame(40, 40)` + manual bubble | Replace with `PipSpeechBubble(speakOnAppear: false, ...)` |
| `GlucoseJourneyView.swift` | `PipJourneyMessage`: inline Pip avatar ~80pt + warmCream container | Replace with `PipSpeechBubble(speakOnAppear: false, message: ...)` |

### Inline `Image("pip_got_idea")` without `PipSize` → use `PipSize`

| File | Line | Current | Fix |
|------|------|---------|-----|
| `MultiplayerHealthyPicksView.swift` | L563 | `Image("pip_got_idea").frame(100, 100)` | `PipWavingAnimatedView(size: .large)` or `PipSize.large.value` |
| `NearbyVersusView.swift` | L362 | `Image("pip_got_idea")...frame(80 * pipScale)` | Use `PipSize.custom(80)` for the base, apply `scaleEffect(pipScale)` |
| `NearbyVersusView.swift` | L493 | `Image("pip_got_idea").frame(100, 100)` | `PipSize.large.value` |

---

## 6. MEDIUM — §4 CTA / Button Component Bypasses

Architecture Rule §4: "Primary CTAs → `.texturedButton(tint:)` (wood-grain capsule); secondary → `.buttonStyle(BouncyButtonStyle())`. Never `.buttonStyle(.plain)` with a custom-styled label; never hand-roll `.background() + .cornerRadius() + .shadow()` on a `Button`."

| File | Buttons affected | Fix |
|------|-----------------|-----|
| `CookingCompletionView.swift` | Primary CTA (Cook Again / Continue) | `.texturedButton(tint: Color.AppTheme.sage)` for primary |
| `InsulinTetrisView.swift` | Game-over / victory CTAs | `.texturedButton(tint: Color.AppTheme.sage)` + `BouncyButtonStyle()` for secondary |
| `MultiplayerHealthyPicksView.swift` | Result screen CTAs | `.texturedButton(tint:)` / `BouncyButtonStyle()` |
| `NearbyVersusView.swift` | Result screen CTAs | Same |
| `SplitScreenVersusView.swift` L526–552 | "Rematch!" and "Done" buttons | "Rematch!" → `.texturedButton(tint: Color.AppTheme.sage)` + `BouncyButtonStyle()`; "Done" → `BouncyButtonStyle()` secondary |
| `PlayLearnView.swift` | `MiniGameRouterView.placeholderView` button | `.texturedButton(tint: Color.AppTheme.sage)` |
| `SiblingProfileView.swift` | Visit Garden + Gift Veggies buttons | `.texturedButton(tint: Color.AppTheme.sage)` |

---

## 7. LOW — §3 Animation Tokens Missing

Architecture Rule §3: "Never inline `.spring(response:)` or `.easeInOut(duration:)`. Use `AnimationConstants.*`."

The following tokens do not yet exist in `AnimationConstants` and need to be added to `AppTheme.swift`. Each entry lists the proposed token name, the inlined value it replaces, and where it's needed.

### Add to `AnimationConstants` in `AppTheme.swift`:

| Proposed token | Replace with | Files / Lines |
|----------------|-------------|---------------|
| `dropFall` | `.linear(duration: 0.05)` | `CookingMiniGames.swift` L88 |
| `peelStrip` | `.easeOut(duration: 0.3)` | `CookingMiniGames.swift` L577 |
| `completionReveal` | `.easeInOut(duration: 0.4)` | `CookingSessionView.swift` L523 |
| `knifeChop` | `.easeOut(duration: 0.1)` | `ChopMiniGame.swift` L186 |
| `organRingReveal` | `.easeOut(duration: 1.0).delay(0.3)` | `BodyBuddyView.swift` L92 |
| `scrollToBottom` | `.easeOut(duration: 0.3)` | `AskPipView.swift` L165 |
| `typingBounce` | `.easeInOut(duration: 0.4).repeatForever(autoreverses: true)` | `AskPipView.swift` L446 |
| `revealDelayed` | `.easeIn(duration: 0.3).delay(0.5)` | `AskPipView.swift` L800 |
| `waterDropFall` | `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` | `PlotView.swift` L424 |
| `wiggleDefault` | `.easeInOut(duration: speed)` (speed param) | `PipAnimations.swift` L489 — `WiggleModifier` |
| `confettiFall` | `.easeIn(duration: Double.random(in: 0.5...1.5))` | `MeetPipAnimated.swift` L381 |
| `bodyZoom` | inline `.spring(response:)` in GlucoseJourneyView | `GlucoseJourneyView.swift` (multiple) |
| `gameRevealEaseIn` | `.easeIn(duration: 0.6)` | `CookingMiniGames.swift` L469 / `GardenView.swift` L1174 |

### Weather loop tokens — add to `AnimationConstants` in `AppTheme.swift`:

| Proposed token | Usage |
|----------------|-------|
| `sunPulse` | Sun glow pulse loop in `WeatherOverlayView` |
| `cloudDriftSlow` | Slow cloud drift in `WeatherOverlayView` |
| `cloudDriftMedium` | Medium cloud drift |
| `cloudDriftFast` | Fast cloud drift |
| `windSweepSlow` | Wind streak slow pass |
| `windSweepMedium` | Wind streak medium pass |
| `windSweepFast` | Wind streak fast pass |
| `seasonalParticleDrift` | Petals / leaves / snow lateral drift loop |
| `seasonalOpacityPulse` | Overlay opacity pulse (rain, snow intensity variation) |

`WeatherOverlayView.swift` contains the densest concentration of inline `.easeInOut(duration: N)` in the project — every weather overlay type (rain, snow, storm, seasonal) inlines its own animation curves. Adding the tokens above and replacing the inline values in that one file would resolve the majority of remaining animation violations.

---

## 8. LOW — §3 Spacing / Size Tokens Missing

Add these to `AppSpacing` in `AppTheme.swift`.

| Proposed token | Value | Files / Lines |
|----------------|-------|---------------|
| `pinDotSize` | 20 | `MigrationPINSetupView.swift` L42, `ParentPINEntryView.swift` L49 — `Circle().frame(width: 20, height: 20)` |
| `pinDotSpacing` | 16 | `MigrationPINSetupView.swift` L38, `ParentPINEntryView.swift` L46 — `HStack(spacing: 16)` |
| `statusChipPaddingH` | 10 | `ChefAcademyApp.swift` stat chips, `RecipeDetailView.swift` nutrition pills, `PipVoice.swift` toggle chip |
| `statusChipPaddingV` | 6 | Same three files |
| `statusChipCornerRadius` | 14 | Same three files |
| `backgroundImageTrailingPad` | 20 | `BackgroundView.swift` L66, L145 — `.padding(.trailing, 20)` |

> **Note on `statusChipPaddingH/V/CornerRadius`:** The values `.padding(.horizontal, 10).padding(.vertical, 6).cornerRadius(14)` appear identically in at least three unrelated files (`ChefAcademyApp.swift` stat chips, `RecipeDetailView.swift` nutrition labels, `PipVoice.swift` toggle chip). This pattern should become a shared `ViewModifier` — `.statusChipStyle()` — added to `AppTheme.swift` alongside the tokens, so sites using it become `.modifier(StatusChipStyle())` or a convenience `.statusChip()` extension.

---

## 9. LOW — §3 Token Exists, Raw Value Used

`AppSpacing.tabBarClearance` equals 100 and already exists. The following sites use the raw value `100` directly instead of the token.

| File | Line | Current |
|------|------|---------|
| `ProfileView.swift` | L146 | `Spacer().frame(height: 100) // Tab bar space` |
| `SiblingProfileView.swift` | L209 | `Spacer().frame(height: 80)` ← note: this one is 80, not 100; see below |
| `PipDialogView.swift` | L70 | `.padding(.bottom, 100)` |
| `MultiplayerHealthyPicksView.swift` | L547 | `Spacer().frame(height: 100)` |
| `NearbyVersusView.swift` | L478 | `Spacer().frame(height: 100)` |
| `GlucoseJourneyView.swift` | L297 | `Spacer().frame(height: 100)` |

`SiblingProfileView.swift` L209 uses 80 — verify whether the view is presented modally (no tab bar) or in a tab context. If it can appear in-tab, replace with `AppSpacing.tabBarClearance`; if always modal, add `AppSpacing.modalScrollPad = 80` or adjust to `AppSpacing.tabBarClearance`.

---

## 10. LOW — §3 Shadow Color Violations

Architecture Rule §3: "Shadows: `Color.AppTheme.sepia.opacity(N)` — never `Color.black.opacity(N)`."

| File | Line | Current | Fix |
|------|------|---------|-----|
| `GardenView.swift` | L114 | `Color.black.opacity(0.2)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `GardenView.swift` | L353 | `Color.black.opacity(0.2)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `ChopMiniGame.swift` | L167 | `Color.black.opacity(0.2)` | `Color.AppTheme.sepia.opacity(0.2)` |
| `FarmShopView.swift` | L581 | `.shadow(color: .black.opacity(0.5))` in `#if DEBUG` block | `Color.AppTheme.sepia.opacity(0.5)` — even dev blocks should build the habit |

---

## 11. LOW — §3 Deprecated API (UIScreen)

`UIScreen.main.bounds` was deprecated in iOS 16.0 (targeted minimum). The correct pattern is `GeometryReader`.

| File | Lines | Usage |
|------|-------|-------|
| `GardenView.swift` | L1093, L1100, L1106, L1625 | `UIScreen.main.bounds.width` to size/position garden elements |

**Fix:** Wrap the enclosing view in a `GeometryReader { geo in }` and replace `UIScreen.main.bounds.width` with `geo.size.width`.

---

## 12. LOW — §3 Font Violations

Architecture Rule §3: "Fonts: `Font.AppTheme.*`. Never `.font(.system(size:))`."

| File | Lines | Current | Fix |
|------|-------|---------|-----|
| `ProfilePickerView.swift` | L39, L86 | `.font(.system(size: 40, weight: .bold, design: .rounded))` and `.font(.system(size: 22, weight: .semibold, design: .rounded))` in iPad sizing branch | `Font.AppTheme.rounded(size: 40, weight: .bold)` / `Font.AppTheme.rounded(size: 22, weight: .semibold)` |
| `ProfilePickerView.swift` (ProfileCard) | L199, L208 | Same `.font(.system(size:weight:design:))` pattern | Same fix |

`SceneEditor.swift` also contains multiple `.font(.system(size:, design: .monospaced))` uses — these are intentional in a DEV-only overlay tool (fixed-width console output) and are exempt from the design system requirement.

---

## 13. LOW — §3 Arithmetic on Token

| File | Lines | Current | Issue |
|------|-------|---------|-------|
| `KitchenView.swift` | L472–473 | `.padding(.vertical, AppSpacing.xxs - 1)` | Subtracting 1 from a spacing token produces a non-token value (3pt). If 3pt is the intended value, add `AppSpacing.xxxs = 3` to `AppSpacing`. Never compute spacing from token arithmetic in view bodies. |

---

## 14. Clean Files — Notable Positive Patterns

The following files are clean and can serve as reference implementations:

| File | Why it's a reference |
|------|---------------------|
| `PaywallView.swift` | Model CTA implementation: `texturedButton(tint:)` primary, `.secondaryButton()` restore, all tokens. |
| `CharacterWalkingView.swift` | `TimelineView(.animation)` with delta-time; `AnimationConstants.walkingFPS/wavingFPS/walkSpeed`; `Color.AppTheme.sepia.opacity(0.2)` for shadow. |
| `WaterPourCharacterView.swift` | `TimelineView(.animation)` particle physics + `Timer.scheduledTimer` wrapped in `Task { @MainActor in }`. Both §2 patterns in one file. |
| `GardenWeatherService.swift` | Timer wrapped in `Task { @MainActor in }` pattern. |
| `PipFoundationModelService.swift` | Correct `await MainActor.run` for crossing `@Published` from background; actor isolation for concurrent tool calls. |
| `ODRManager.swift` | `@MainActor final class` + KVO progress observer via `Task { @MainActor in }`. |
| `PlayerData.swift` | All `@Model` properties have defaults (§1); `decodeIfPresent` + defaults for backwards compat (§6). |
| `AllergenPickerStep.swift` | `AnimationConstants.springQuick` usage; correct `@Model` patterns. |
| `PINKeychain.swift` | Correct Keychain security patterns (`kSecAttrAccessibleAfterFirstUnlock`, iCloud sync). |
| `AmbientAudioPlayer.swift` | `@MainActor`, `Task.sleep`, `await MainActor.run` throughout. |
| `SplitScreenVersusView.swift` (physics) | Fixed-step accumulator physics via `TimelineView(.animation)`, not `Timer`. Timer countdown wrapped in `Task { @MainActor in }`. |

---

## Summary Table

| Severity | Category | Count | Files |
|----------|----------|-------|-------|
| CRITICAL / P1 | Dead TimelineView condition | 1 | GardenView |
| HIGH | §2 DispatchQueue.main.async violations | 17 call sites | AuthManager, GameCenterMatchmakerView, GameCenterService, MultiplayerManager, NearbyMultiplayerManager, ParentPINEntryView |
| HIGH | §1 try? save() violations | 6 | SessionManager, AddChildFlowView, AllergenEditorSheet, FamilySetupView, ParentDashboardView, SiblingProfileView |
| MEDIUM | §4 profilePoseImage bypasses | 10 clear sites + 2 pattern | ChefAcademyApp, LocalVersusView, MultiplayerHealthyPicksView, NearbyVersusView, ParentDashboardView, SiblingProfileView, SplitScreenVersusView |
| MEDIUM | §4 Pip bubble/avatar bypasses | 3 views + 3 pip_got_idea sites | BodyBuddyView, AskPipView, GlucoseJourneyView, MultiplayerHealthyPicksView, NearbyVersusView |
| MEDIUM | §4 CTA/button bypasses | 7 views | CookingCompletionView, InsulinTetrisView, MultiplayerHealthyPicksView, NearbyVersusView, SplitScreenVersusView, PlayLearnView, SiblingProfileView |
| LOW | §3 Animation tokens missing | ~22 tokens | AppTheme.swift (new additions needed) |
| LOW | §3 Spacing tokens missing | 6 tokens | AppTheme.swift (new additions needed) |
| LOW | §3 tabBarClearance raw value | 6 sites | ProfileView, SiblingProfileView, PipDialogView, MultiplayerHealthyPicksView, NearbyVersusView, GlucoseJourneyView |
| LOW | §3 Shadow color violations | 4 sites in 3 files | GardenView, ChopMiniGame, FarmShopView |
| LOW | §3 Deprecated UIScreen | 4 sites | GardenView |
| LOW | §3 Font violations | 4 sites | ProfilePickerView |
| LOW | §3 Token arithmetic | 1 | KitchenView |

**Highest-leverage single edit:** Fixing the 17 `DispatchQueue.main.async` sites across the multiplayer stack eliminates the most concentrated data-race risk in the codebase.

**Highest-leverage token addition:** Adding the ~9 weather animation tokens to `AnimationConstants` and applying them in `WeatherOverlayView.swift` would close the largest single cluster of §3 violations (that one file accounts for roughly a third of all remaining hardcoded animation curves).
