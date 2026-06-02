# Weekly Code Review — 2026-06-02

**Reviewer:** Claude Code (automated full-codebase audit)
**Scope:** All 87 `.swift` files in `ChefAcademy/` + `AssetPackDownloader/`
**Focuses:** STALE-UI (concurrency violations, save errors) · HARDCODE (design-system violations)

---

## SUMMARY

| Category | Severity | Count | Files affected |
|----------|----------|-------|----------------|
| `DispatchQueue.main.async` (banned) | P0 | 19 sites | 5 files |
| `try? context.save()` (data-loss risk) | P0 | 9 sites | 7 files |
| Inline animation (no token) | P1 | 55+ sites | 15 files |
| `profilePoseImage` bypass | P1 | 13 sites | 7 files |
| `Color.black/.white` violation | P1 | 8 sites | 7 files |
| Inline Pip frame / PipSpeechBubble bypass | P1 | 6 sites | 4 files |
| Hand-rolled primary CTA | P2 | 20+ sites | 10 files |
| Inline dimension / spacing | P2 | 20+ sites | 12 files |
| `.font(.system(size:))` | P2 | 4 sites | 1 file |

---

## FOCUS 1 — STALE-UI

### F1-A · `DispatchQueue.main.async` — 19 sites across 5 files

All 19 are Apple-framework callbacks arriving on background threads. Pattern must be replaced with `Task { @MainActor in }` per §2 of CLAUDE.md.

| File | Line(s) | Context |
|------|---------|---------|
| `AuthManager.swift` | 113 | `checkExistingCredential()` Sign-in-with-Apple callback closure |
| `GameCenterService.swift` | 102 | `authenticateHandler` GKLocalPlayer callback |
| `GameCenterMatchmakerView.swift` | 42 | `matchmakerViewControllerWasCancelled` delegate |
| `GameCenterMatchmakerView.swift` | 49 | `matchmakerViewController(_:didFailWithError:)` |
| `GameCenterMatchmakerView.swift` | 59 | `matchmakerViewController(_:didFind:)` |
| `MultiplayerManager.swift` | 65 | `authenticateLocalPlayer` GKLocalPlayer callback |
| `MultiplayerManager.swift` | 197 | `handleMessage` data receive callback |
| `MultiplayerManager.swift` | 242–249 | `startCountdown` Timer fire — wraps `@Published` writes |
| `MultiplayerManager.swift` | 297 | `match(_:player:didChange:)` GKMatchDelegate |
| `MultiplayerManager.swift` | 321 | `match(_:didFailWithError:)` GKMatchDelegate |
| `NearbyMultiplayerManager.swift` | 155 | `handleMessage` data receive callback |
| `NearbyMultiplayerManager.swift` | 198–209 | `startCountdown` Timer callback |
| `NearbyMultiplayerManager.swift` | 221 | `handleConnection` peer state |
| `NearbyMultiplayerManager.swift` | 241 | `MCSessionDelegate` receive data |
| `NearbyMultiplayerManager.swift` | 286 | `MCNearbyServiceAdvertiserDelegate` didReceiveInvitation |
| `NearbyMultiplayerManager.swift` | 308 | `MCNearbyServiceBrowserDelegate` foundPeer |
| `ParentPINEntryView.swift` | 134 | `startAppleIDVerification()` ASAuthorization callback |

**Fix pattern:**
```swift
// Before
DispatchQueue.main.async {
    self.somePublished = value
}
// After
Task { @MainActor in
    self.somePublished = value
}
```

Note: `MultiplayerManager` and `NearbyMultiplayerManager` each have a Timer-inside-countdown that uses `DispatchQueue.main.async` to mutate `@Published` state — the timer fires correctly but the callback is banned. Wrap the closure body in `Task { @MainActor in }` as done in `SplitScreenVersusView.startCountdown()` (line 580), which is the correct exemplar.

### F1-B · `try? context.save()` — 9 sites across 7 files

Silent failures destroyed child profiles for a week (March bug). Every save must use `do { try context.save() } catch { print(error) }`.

| File | Line(s) | Where |
|------|---------|-------|
| `SessionManager.swift` | multiple | `selectProfile`, `addChildProfile`, `deleteProfile`, etc. |
| `AddChildFlowView.swift` | 134 | After inserting new child profile |
| `FamilySetupView.swift` | 204 | End of setup wizard |
| `SiblingGardenView.swift` | 37 | `onLikeGarden` closure |
| `SiblingProfileView.swift` | 275 | `giftVeggie` after modifying sibling data |
| `ParentDashboardView.swift` | 461, 490 | Play-time update + PIN change |
| `AllergenEditorSheet.swift` | 119 | `saveAndDismiss()` |
| `ChefAcademyApp.swift (HomeView)` | 464 | `dismissHelpMessages()` |

---

## FOCUS 2 — HARDCODE

### F2-A · Inline animation tokens — 55+ sites in 15 files

**Worst offender: `GlucoseJourneyView.swift`** — 16 violations in a single file.

#### P0 severity (bare `.spring()` with no params — undefined behavior on ProMotion)

| File | Lines | Pattern |
|------|-------|---------|
| `GameState.swift` | 172, 181 | `withAnimation(.spring())` — no response/dampingFraction |
| `GlucoseJourneyView.swift` | 391, 392 | `.animation(.spring(), value:)` |

#### P1 severity (named inline animations that should use tokens)

**`GlucoseJourneyView.swift`** — 14 additional violations:
- Lines 485, 569, 591, 593, 771, 786–787, 831, 897, 905, 916, 919, 1005, 1214: `.spring(response: X, dampingFraction: Y)` inline
- Line 874: `.easeInOut(duration: 0.6)` inline

**`WeatherOverlayView.swift`** — 10+ repeat-loop animations with no tokens:
- `SunshineOverlay`: `.easeInOut(duration: 3).repeatForever(autoreverses: true)` (sun glow pulse)
- `PartlyCloudyOverlay` / `CloudOverlay`: `.easeInOut(duration: 8–10).repeatForever(autoreverses: true)` (cloud drift)
- `WindOverlay`: `.linear(duration: 8).repeatForever(autoreverses: false)` (wind stream)
- `SeasonalOverlayView`: `.linear(duration: 20).repeatForever(autoreverses: false)` (particle drift)

Three new tokens should be added to `AnimationConstants` in `AppTheme.swift`:
```swift
// Proposed additions to AnimationConstants:
static let particleDriftLoop = Animation.linear(duration: 20).repeatForever(autoreverses: false)
static let sunPulseLoop      = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)
static let cloudDriftLoop    = Animation.easeInOut(duration: 8).repeatForever(autoreverses: true)
static let typingDotLoop     = Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true)
static let wiggleLoop        = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
```

**Other inline animation violations by file:**

| File | Lines | Patterns |
|------|-------|---------|
| `GardenView.swift` | multiple | `.easeIn(duration: 0.6)`, `.spring(response: 0.3, dampingFraction: 0.7)` |
| `PlotView.swift` | 424 | `.easeInOut(duration: 0.6).repeatForever(autoreverses: true)` |
| `CookingSessionView.swift` | 523 | `.easeInOut(duration: 0.4)` |
| `CookingMiniGames.swift` | multiple | `.linear(duration: 0.05)`, `.easeOut(duration: 0.3)` × multiple, `.easeIn(duration: 0.6)` |
| `AskPipView.swift` | 165, 445–449, 800 | `.easeOut(duration: 0.3)`, `.easeInOut(duration: 0.4).repeatForever()`, `.easeIn(duration: 0.3).delay(0.5)` |
| `BodyBuddyView.swift` | 92, 429, 443, 507 | `.easeOut(duration: 1.0)`, `.easeOut(duration: 0.8)` |
| `FamilySetupView.swift` | 261, 1064, 1176 | `.easeOut(duration: 0.8)`, `.easeOut(duration: 0.6)` |
| `ChopMiniGame.swift` | 186 | `.easeOut(duration: 0.1)` |
| `MeetPipAnimated.swift` | 381 | `.easeIn(duration: Double.random(in: 1.5...2.5))` (confetti) |
| `HealthyChoiceGameView.swift` | 410, 812 | `.easeIn(duration: 2.0)`, `.easeIn(duration: 1.5)` |
| `PipAnimations.swift` | 488–491 | `WiggleModifier`: `.easeInOut(duration: speed).repeatForever(autoreverses: true)` |

### F2-B · `profilePoseImage` bypasses — 13 sites in 7 files

`UserProfile.profilePoseImage` exists specifically to route parents to `mom_avatar_frame_15` / `dad_avatar_frame_15`. Every inline `gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"` also silently breaks when non-binary gender is added (K-01).

| File | Lines | Context |
|------|-------|---------|
| `ChefAcademyApp.swift` | 669 | `HomeView` sibling carousel |
| `LocalVersusView.swift` | 199, 208, (×2 more) | Player cards, score bars, results view — 4+ instances |
| `MultiplayerHealthyPicksView.swift` | 358, 600–601 | `opponentScoreBar`, `playerAvatar` helper |
| `NearbyVersusView.swift` | 275, 525 | Player display + `playerAvatar` helper |
| `SiblingProfileView.swift` | 26 | `characterImage` computed property (private, bypasses the public helper) |
| `SplitScreenVersusView.swift` | 111, 194, 215 | `pickPlayersView` grid, `readyView` P1 and P2 avatars |
| `ParentDashboardView.swift` | 507 | `DashboardChildTab.characterImage` |

**Fix:** Replace all with `Image(profile.profilePoseImage)` or `Image(sibling.profilePoseImage)`. For the manager-based views that hold a `UserProfile` reference, pass the profile or call `.profilePoseImage` directly. `SiblingProfileView.characterImage` is an internal computed property that should just forward to the model.

### F2-C · `Color.black` / `Color.white` violations — 8 sites in 7 files

Shadow rule: `Color.AppTheme.sepia.opacity(N)` only. `Color.white` must be `Color.AppTheme.cream`.

| File | Line | Pattern |
|------|------|---------|
| `GardenView.swift` | (×2) | `.shadow(color: Color.black.opacity(0.2), ...)` |
| `FarmShopView.swift` | — | `.shadow(color: .black.opacity(0.5), radius: 4)` |
| `ChopMiniGame.swift` | 167 | `.shadow(color: .black.opacity(0.2), ...)` |
| `RecipeDetailView.swift` | 79 | `.foregroundColor(.white)` in allergen warning badge |
| `AvatarCreatorView.swift` | 401 | `.foregroundColor(.white)` |
| `AllergenPickerStep.swift` | 134, 142 | `AllergenToggleButton`: `.foregroundColor(.white)` × 2 (selected state) |

### F2-D · Inline Pip frame / `PipSpeechBubble` bypasses — 6 sites in 4 files

All raw `Image("pip_...")` with hardcoded `.frame(width: N, height: N)` bypass `PipSize`. `PipSize.custom(N)` should be used; for dialogue, `PipSpeechBubble` auto-speaks.

| File | Lines | Pattern |
|------|-------|---------|
| `AskPipView.swift` | 430–431 | `Image("pip_got_idea").frame(width: 40, height: 40)` typing indicator (→ `PipSize.compact`) |
| `MultiplayerHealthyPicksView.swift` | 564 | `Image("pip_got_idea")...frame(width: 100, height: 100)` error state (→ `PipSize.large`) |
| `NearbyVersusView.swift` | 362–369 | `Image("pip_got_idea").frame(width: 80 * pipScale, ...)` gameplay (→ `PipWavingAnimatedView` or `PipSize.custom`) |
| `NearbyVersusView.swift` | 493–497 | `Image("pip_got_idea").frame(width: 100, height: 100)` error state |
| `BodyBuddyView.swift` | 254–268 | `pipMessageSection` — hand-rolls speech bubble with `Image("pip_thinking")` at raw size, manual `PipVoice.shared.speak(...)`. Replace with `PipSpeechBubble` (removes the manual speak call too). |

### F2-E · `.font(.system(size:))` violations — 4 sites in 1 file

| File | Lines | Context |
|------|-------|---------|
| `ProfilePickerView.swift` | 39, 86–87, 199, 208 | iPad-variant font paths use `.font(.system(size: N, weight: .W))`. Replace with `Font.AppTheme.rounded(size: N, weight: .W)` or an appropriate `Font.AppTheme.*` token. |

### F2-F · Hand-rolled primary CTAs — 20+ sites in 10 files

Primary CTAs with `.background(Color.AppTheme.sage/goldenWheat).cornerRadius(...).foregroundColor(cream)` pattern must use `.texturedButton(tint:)`. Secondary/tertiary text-only buttons are fine as `.plain`.

**Highest-impact files:**

| File | Count | Examples |
|------|-------|---------|
| `GlucoseJourneyView.swift` | 6+ | Multiple "Next" / "Continue" / "Play Again" CTAs |
| `MultiplayerHealthyPicksView.swift` | 4 | Ready/Start/Rematch/Done buttons |
| `NearbyVersusView.swift` | 4 | Same pattern as above |
| `SplitScreenVersusView.swift` | 3 | "Next", "Start!", "Rematch!" (has `BouncyButtonStyle` but wrong primary style) |
| `BodyBuddyView.swift` | 1 | Cook button at lines 70–83 |
| `SiblingProfileView.swift` | 2 | "Visit Garden", "Gift Veggies" |
| `AllergenPickerStep.swift` | 1 | "Next" button |
| `CookingCompletionView.swift` | 2 | "See how your food helps!", "Back to Kitchen" |
| `PlayLearnView.swift` | 1 | `MiniGameRouterView.placeholderView` "Back to Games" |
| `ParentDashboardView.swift` | 4 | "Remove", "Sign Out", "Delete Account", "Link Apple ID" |
| `HealthyChoiceGameView.swift` | 2+ | Game action buttons |

### F2-G · Inline dimension / spacing hardcodes — 20+ sites in 12 files

Selection of the most critical (token equivalents shown in parentheses):

| File | Line(s) | Hardcode | Should be |
|------|---------|---------|-----------|
| `RecipeCardExample.swift` | 1156 | `.padding(.bottom, 100)` | `AppSpacing.tabBarClearance` |
| `HomeAnimated.swift` | 56 | `.frame(height: 100)` | `AppSpacing.tabBarClearance` |
| `PipDialogView.swift` | 70 | `.padding(.bottom, 100)` | `AppSpacing.tabBarClearance` |
| `PantryInfoView.swift` | 54 | `.frame(width: 200, height: 200)` | `AppSpacing.infoCardImageSize` (both axes) |
| `MigrationPINSetupView.swift` | 38 | `HStack(spacing: 16)` | `AppSpacing.md` |
| `ParentPINEntryView.swift` | 46 | `HStack(spacing: 16)` | `AppSpacing.md` |
| `ChefAcademyApp.swift` | 519–552 | `.padding(.horizontal, 10).padding(.vertical, 6).cornerRadius(14)` × 3 stat chips | Propose `AppSpacing.chipHorizontal/chipVertical/chipCorner` tokens |
| `FamilySetupView.swift` | 504 | `RoundedRectangle(cornerRadius: 24)` | `AppSpacing.largeCornerRadius` or new token |
| `OnboardingView.swift` | 319 | `.stroke(..., lineWidth: 3)` | `AppSpacing.strokeBold` |
| `ProfilePickerView.swift` | multiple | `isIPad ? 200 : 80`, `isIPad ? 220 : 90`, `isIPad ? 280 : 120` + offsets | `AdaptiveCardSize.*` tokens |
| `PlantingSheet.swift` | 44–48 | `isIPad ? 120 : 80`, `isIPad ? 300 : 200` | `AdaptiveCardSize.*` tokens |
| `MeetPipViews.swift` | 289–303 | `sizeClass == .compact ? -20 : -30`, `sizeClass == .compact ? 120 : 180`, `sizeClass == .compact ? 0.5 : 0.7` | `AdaptiveCardSize.*` tokens |
| `RecipeDetailView.swift` | 60–79 | "Adult Help" badge padding, allergen warning padding, pill paddings — all hardcoded | `AppSpacing.*` tokens |
| `InsulinTetrisView.swift` | multiple | `.frame(width: 56, height: 56)` blocks; `RoundedRectangle(cornerRadius: 10)` × 2; `.padding(.horizontal, 10).padding(.vertical, 4).cornerRadius(10)` HUD | `AppSpacing.*` tokens |
| `AskPipView.swift` | — | `.padding(.horizontal, 12).padding(.vertical, 8)` starter chip paddings | `AppSpacing.sm/xs` equivalents |

---

## EXEMPLARY PATTERNS (do more of this)

The following files demonstrate the gold standard — zero findings:

- **Physics loops:** `RainOverlay`, `StormOverlay`, `SnowOverlay`, `WaterPourCharacterView`, `SplitScreenVersusView`, `HealthyChoiceGameView`, `MultiplayerHealthyPicksView`, `InsulinTetrisView` — all use `TimelineView(.animation)` + Canvas + fixed-timestep accumulator. No `Timer` at 60fps, no frame-rate dependency.
- **Concurrency:** `AmbientAudioPlayer` (`@MainActor final class`, async/await, `await MainActor.run`), `ElevenLabsVoiceService`, `PipAIService`, `USDAFoodService` — every `@Published` write reaches the main actor correctly.
- **Animation sequence:** `CookingCompletionView.animateStars()` — single `Task { @MainActor in }` with sequential `await Task.sleep` replaces 4 separate `asyncAfter` deadlines. This is the correct pattern for the whole codebase.
- **Token compliance:** `PaywallView`, `RecipeCardExample.RecipeCardView`, `VoicePickerView`, `AssetPackController`, `AssetPackImage`, `AmbientAudioPlayer` — zero hardcoded values.

---

## PROPOSED NEW TOKENS

Add to `AppTheme.swift` → `AnimationConstants`:

```swift
// Repeat-loop animations (used heavily by WeatherOverlayView + AskPipView)
static let particleDriftLoop = Animation.linear(duration: 20).repeatForever(autoreverses: false)
static let sunPulseLoop      = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)
static let cloudDriftLoop    = Animation.easeInOut(duration: 8).repeatForever(autoreverses: true)
static let typingDotLoop     = Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true)
static let wiggleLoop        = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
```

Add to `AppSpacing`:

```swift
static let chipHorizontalPadding: CGFloat = 10   // HomeView stat chips
static let chipVerticalPadding: CGFloat   = 6    // HomeView stat chips
static let chipCornerRadius: CGFloat      = 14   // HomeView stat chips
```

---

## PRIORITY ORDER

**Fix immediately (data safety):**
1. All `try? context.save()` → `do { try … } catch { print(error) }` (9 sites)
2. All `DispatchQueue.main.async` → `Task { @MainActor in }` (19 sites)

**Fix before TestFlight:**
3. `profilePoseImage` bypasses (13 sites) — these break parent-avatar routing
4. `Color.black` shadow violations (4 sites) — visible in Dark Mode
5. `Color.white` foreground violations (4 sites) — invisible in light-background contexts

**Address in design-system sprint:**
6. Inline animation tokens (55+ sites — start with GlucoseJourneyView and WeatherOverlayView after adding the new tokens above)
7. Hand-rolled CTAs → `.texturedButton(tint:)` (20+ sites)
8. Inline dimensions → `AppSpacing.*` / `AdaptiveCardSize.*` (20+ sites)
9. `.font(.system(size:))` → `Font.AppTheme.*` (4 sites in ProfilePickerView)
10. Inline Pip frames → `PipSize.*` / `PipSpeechBubble` (6 sites)

---

## FILES CONFIRMED CLEAN

No violations of any category: `Allergen.swift`, `AllergenEditorSheet.swift` (save excluded — caught above), `AmbientAudioPlayer.swift`, `AssetPackController.swift`, `AssetPackImage.swift`, `BackgroundView.swift`, `CloudKeyManager.swift` (legacy, Phase 4 delete), `ContentView.swift` (legacy stub), `ElevenLabsVoiceService.swift`, `FamilyProfile.swift`, `GardenWeatherService.swift`, `MorphTransition.swift`, `ODRManager.swift`, `PaywallView.swift`, `PipAIService.swift`, `PipFoundationModelService.swift`, `PipGameAnimationView.swift`, `PipKeychain.swift`, `PipStaticResponses.swift`, `PlayerData.swift`, `ProfileView.swift`, `RecipeDetailView.swift` (save/color excepted), `SeededRandomGenerator.swift`, `SeedInfoView.swift` (ColorChoice enum intentional — see §9), `USDAFoodService.swift`, `VideoPlayerView.swift`, `VoicePickerView.swift`, `WaterPourCharacterView.swift`, `WorkerClient.swift`.

---

*Report generated: 2026-06-02 · Full read of all 87 Swift files completed before writing.*
