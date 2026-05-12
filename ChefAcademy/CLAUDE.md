# CLAUDE.md - Pip's Kitchen Garden Project Instructions

## Project Overview

**App Name:** Pip's Kitchen Garden
**Platform:** iOS (iPhone/iPad)
**Language:** Swift / SwiftUI
**Target:** Ages 6+ (shifted from 8-12 based on UX audit)
**Developer:** Marina Pollak
**Deadline:** May 15, 2026
**Course:** PROG-360A Project Studio, Columbia College Chicago

---

## What Is This App?

A kid-friendly mobile GAME (not just an app) where players:
1. **GROW** vegetables in a garden (simulation + mini-games)
2. **COOK** recipes through fun mini-games (like Cooking Mama)
3. **FEED** their Body Buddy and watch food travel through a cartoon body

The core loop is: **GROW → COOK → FEED → REWARDS → repeat**

---

## Architecture Rules

Canonical source for all hard rules. When statements elsewhere in this file (or in audit reports / chat) appear to relax or contradict these, the rules here win. Cite the rule's section name in code review or commit messages if you need to refer back.

### 1. SwiftData / CloudKit Compatibility

- **All `@Model` properties MUST have default values** at declaration. CloudKit requires it; missing defaults crash the schema migration.
- **NO `@Relationship` macros** — link models via `UUID` fields. `FamilyProfile` → members via `familyID` query; `UserProfile` → `PlayerData` via `ownerID`.
- **NO `[String: Int]` dictionaries on `@Model`** — use `[CodableStruct]` arrays. SwiftData doesn't reliably persist dictionary types.
- **`.modelContainer(modelContainer)` MUST be on the WindowGroup.** Required for `@Environment(\.modelContext)` to resolve in any descendant. Missing this caused an infinite loop bug.
- **Use `do { try save() } catch { print(error) }` for SwiftData saves** — never `try?`. Silent failures destroyed child profiles for a week (March bug). Always log errors so they're diagnosable.
- **Codable backwards compatibility:** every new field on a persisted struct needs `decodeIfPresent(...) ?? defaultValue`. Old saved data doesn't have the new keys → crash without it.

### 2. Concurrency & State Updates

- **ZERO inline `DispatchQueue.main.asyncAfter`** in `ChefAcademy/`. Every delayed UI mutation goes through:
  ```swift
  Task { @MainActor in
      try? await Task.sleep(for: .seconds(X))
      guard !Task.isCancelled else { return }
      // mutate @State here
  }
  ```
  Assign to a `@State var task: Task<Void, Never>?` and cancel in `.onDisappear` when cancellation matters (animation chains, repeat loops, transient cues).

- **Timer callbacks must wrap state mutations in `Task { @MainActor in }`.** `Timer.scheduledTimer` fires on the RunLoop; direct `@Published` / `@State` writes from there race with the renderer and produce data-race warnings under strict concurrency.

- **Game physics loops use `TimelineView(.animation)` with delta-time**, not `Timer.scheduledTimer` at 60fps. Pattern lives in `RainOverlay`, `StormOverlay`, `SnowOverlay`, `InsulinTetrisView`, `WaterPourCharacterView`. Timer-based physics ties speed to frame rate; ProMotion 120Hz devices and CPU throttling break it.

- **`@EnvironmentObject` propagation is selective.** `SiblingGardenView` swaps `gameState` (sibling's data) while inheriting `sessionManager` (visitor identity) — that's why visitor gender drives the right water-pour character without explicit wiring. Use this pattern when two flows share most but not all context.

- **`async/await` + `await MainActor.run { ... }` for any code touching `@Published` from a background context.** `PipAIService`, `USDAFoodService`, `ElevenLabsVoiceService` follow this.

### 3. Design System — No Hardcoded Values

Zero hardcoded colors / fonts / spacing / animation curves / stroke widths in any new SwiftUI code. Period.

| Category | Token namespace | Examples |
|---|---|---|
| **Colors** | `Color.AppTheme.*` | `cream`, `sage`, `goldenWheat`, `terracotta`, `sepia`, `darkBrown`, `weatherSunny`, `springGradientTop`. Shadows: `Color.AppTheme.sepia.opacity(N)` — never `Color.black.opacity(N)`. |
| **Fonts** | `Font.AppTheme.*` | `caption / subheadline / body / bodyBold / headline / title3 / title / largeTitle`. For one-offs: `Font.AppTheme.rounded(size: N, weight: .X)`. Never `.font(.system(size:))`. |
| **Spacing** | `AppSpacing.*` | `xxs (4) / xs (8) / sm (12) / md (16) / lg (24) / xl (32) / xxl (48)`, `buttonHeight (52)`, `pillCornerRadius (8)`, `smallCornerRadius (12)`, `cardCornerRadius (16)`, `largeCornerRadius (20)`, `strokeThin (1) / strokeMedium (2) / strokeBold (3)`, `tabBarClearance (100)`, `pinButtonWidth (75)`, `pinButtonHeight (55)`, `infoCardImageSize (200)`. |
| **iPad sizing** | `AdaptiveCardSize.*(for: sizeClass)` | `pipMessage`, `pipReadyScreen`, `kitchenSpotRing`, etc. Never inline `isIPad ? 280 : 200`. |
| **Animations** | `AnimationConstants.*` | Springs: `springQuick / Medium / Slow / Bouncy / Snappy / Tight / Fly`. Easings: `fadeQuick / Fast / Medium / revealSlow / pipTransition / morphTransition / weatherTransition`. Loops: `floatLoopFast / floatLoop / floatLoopSlow / pinShake`. Frame rates: `walkingFPS / wavingFPS / gameFPS / walkSpeed`. Never inline `.spring(response:)` or `.easeInOut(duration:)`. |

**Pre-commit audit grep** — run on your own diff before declaring done:
```
Color.black            Color.white           .font(.system(
.spring(response:      easeInOut(duration:   easeOut(duration:    easeIn(duration:
RoundedRectangle(cornerRadius:    .shadow(color: Color.black    Color(hex: "
DispatchQueue.main.asyncAfter    Timer.scheduledTimer
```
Any hit in non-AppTheme files = not done. If a needed token doesn't exist, **add it to `AppTheme.swift` / `AppSpacing` / `AnimationConstants` / `AdaptiveLayout`** with a comment explaining what it's for. Never inline as a one-off.

### 4. UI Components — Reuse Mandatory

- **Buttons:**
  - Primary CTAs → `.texturedButton(tint:)` (wood-grain capsule)
  - Secondary → `.buttonStyle(BouncyButtonStyle())`
  - Never `.buttonStyle(.plain)` with a custom-styled label. Never hand-roll `.background() + .cornerRadius() + .shadow()` on a `Button`.
- **Cards:** `.softCard()` for the warm-cream surface (80% case). `.cardStyle()` for the parchment variant (rare).
- **Pip avatars:** Size via the `PipSize` enum (`.compact 40 / .medium 80 / .large 120 / .hero 160 / .custom(N)`). Never raw `Image("pip_...")` with hardcoded `.frame(width: N, height: N)`.
- **Pip dialogue:** `PipSpeechBubble` and `PipHeaderStack` **auto-speak** via `PipVoice.shared.speak(...)` on appear and on message change. Do NOT manually call `PipVoice.shared.speak(...)` next to these components — it double-speaks. Use `speakOnAppear: false` only for decorative usage.
- **PIN UI:** Use the shared `PINPadGrid<Leading, Trailing>` and `PINButton` from `PipComponents.swift`. Three views previously had local copies — never reintroduce.
- **Horizontal carousels:** Apply `.trailingFade()` (from `AdaptiveLayout.swift`) as the at-rest scroll cue. iOS's default scrollbar only appears mid-gesture; kids don't intuit swipe without this.
- **Primary CTAs that must always be reachable:** sticky footer pattern (see `RecipeDetailView` "Let's Cook!"). Don't bury below an un-cued `ScrollView(showsIndicators: false)`.
- **Profile pose image:** use `UserProfile.profilePoseImage` — never inline `gender == .boy ? "boy_card_clean_..." : "girl_card_clean_..."`. The helper routes parents to mom/dad frames.
- **Recipe display:** look up by ID, fall back to slug — `GardenRecipes.all.first { $0.id == star.recipeID }?.title ?? star.recipeID`. Never render raw recipe-ID slugs.

### 5. Storage Keys vs Display Labels

- **`rawValue` is an immutable storage key** when an enum is persisted (coin claim records, UserDefaults keys, SwiftData rows). Coin tracking uses keys like `"seed_\(veggie)_\(nutrient.rawValue)"`. Renaming a `rawValue` invalidates every existing user's saved progress and loses their coin claim history.
- **For UI display labels, add a separate computed property.** Example: `NutrientType.kidFriendlyName` returns `"Helper Shields"` for `.antioxidants` while `rawValue` stays `"Antioxidants"`. Default branch returns `rawValue` for cases that don't need renaming.
- **Applies to all enums on `@Model` properties:** `NutrientType`, `VegetableType`, `PantryItem`, `Gender`, `Outfit`, `HeadCovering`, `FoodAllergen`. Plus enums whose rawValues key into dictionaries or analytics.

### 6. SwiftUI Coding Conventions

- **SwiftUI for all views.** No new UIKit views except UIViewControllerRepresentable bridges to legacy frameworks (`GameCenterMatchmakerView`, `VeggieCanvasView` for PencilKit).
- **MVVM + ObservableObject + SwiftData `@Model`.** No new architectures.
- **`@EnvironmentObject`** for shared state: `GameState`, `SessionManager`, `AvatarModel`. Inject via `.environmentObject(...)` at the highest reasonable ancestor.
- **`@Environment(\.modelContext)`** for SwiftData queries from views. Requires `.modelContainer` set on the WindowGroup.
- **UUID-based model linking** between `@Model`s (no `@Relationship` — see SwiftData rules above).
- **`// MARK: -`** for section breaks within any file >100 lines.
- **`#Preview`** for every new view, with at least one realistic data state.
- **`@Generable` / Apple FoundationModels** types live in `PipFoundationModelService.swift` only, gated by `#if canImport(FoundationModels)`. Don't proliferate.

### 7. Build & Verification

- **Build command:** `xcodebuild -scheme ChefAcademy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Trust `xcodebuild`, not SourceKit per-file diagnostics.** SourceKit doesn't see cross-file types — it will claim `Color.AppTheme`, `AppSpacing`, `GameState`, `Recipe` are missing in any single file. Ignore these. `xcodebuild` is authoritative.
- **Build after every Edit batch** before declaring done. Don't push commits that haven't been built.
- **Reset simulator data:** `find ~/Library/Developer/CoreSimulator/Devices -name "default.store*" -path "*/Application Support/*" -exec rm -f {} \;`

### 8. Session Protocol

- **Read all relevant files before changes** when Marina says so. No context-budget arguments. Style/architecture files (`AppTheme.swift`, `AdaptiveLayout.swift`, `PipComponents.swift`) are mandatory pre-reads before any UI work. Memory files in `~/.claude/projects/.../memory/` count as "all files."
- **Plan-first for non-trivial changes.** Surface the diff intent, token usage, risk, and reversibility before editing. Don't sweep call sites without explicit sign-off (the "tokens-first, sweep-later" pattern).
- **One focused commit per audit item / feature.** Easy to revert, easy to bisect. Bundle only when items are genuinely the same change. The May 11 batch was 5 separate commits for F-03 / L-01 / G-01 / L-02 / F-04.
- **Audit findings are hypotheses, not instructions.** Before fixing: grep that the file is still referenced, the function still exists, the rationale still holds. Several audit items have been miscalibrated (PrimaryButtonStyle dead code, GardenHubView orphaned, Apple TTS already-rejected) — don't act on them blind.
- **Append teaching moments to `TEACHING.md` before declaring a session done.** Memory notes are not a substitute. 3-7 entries per session is the right density. Each entry uses the existing 4-field format: `**Where it came up** / **What it is** / **In our code** / **Why it matters**`. Skip trivial wins (font bumps, single-line patches).

### 9. Standing Decisions (Don't Re-Litigate)

- **Free voice = silent text on screen. Paid = ElevenLabs.** Apple TTS was rejected May 10 — "Enhanced" voices sounded awful, decision is documented and intentional. Don't re-propose. Audit items recommending Apple TTS are stale.
- **Sage / goldenWheat / terracotta are the botanical default for CTAs.** `brightGreen / brightBlue / sunflowerYellow` tokens exist for selective high-energy use; don't sweep all CTAs to brightGreen. The audit's "L-01 full sweep" path was declined.
- **Gender enum is binary (boy / girl).** Parent vs child role + gender combination drives mom/dad frame selection via `UserProfile.profilePoseImage`. Non-binary expansion is K-01 on the audit; deferred pending dedicated assets.
- **ColorChoice (Lycopene / Beta-carotene / Anthocyanins / Allicin / Anthocyanins) is intentional plant-pigment-science education.** In-file teaching comment in `SeedInfoView.swift:559-562` defends this. Don't replace with generic nutrient names. The kid-friendly rename only applies to `NutrientType.rawValue`, not `ColorChoice.nutrientName`.
- **`USDAFoodService.topNutrients()` is consumed only by `PipFoundationModelService.swift:505` (AI tools layer), not user UI.** Audit recommendations targeting "kid-unfriendly" tuple labels here are misdirected. Don't apply renames.
- **`GardenHubView.swift` is orphaned dead code** (zero references in the codebase). Planned deletion. Don't add features to it; don't trust audit findings inside it.
- **`Tab.recipes` case is kept for compatibility** but hidden from the tab bar. Access via Kitchen book icon. The 6 visible tabs are Home / Garden / Shop / Kitchen / Body / Play.
- **Routine pushes use the Claude GitHub App's install token** (separate from your personal access). Failures → toggle repo access "All" → "Only select" → "All" on `github.com/settings/installations` to force token re-issue. Don't uninstall.
- **ODR is deprecated as of WWDC25.** Migrating to Apple-Hosted Asset Packs. `AssetPackController.swift` is the new path; `ODRManager.swift` stays during transition.

---

## Tech Stack

- **UI Framework:** SwiftUI
- **Persistence:** SwiftData with iCloud CloudKit sync
- **Mini-games:** SwiftUI with gestures
- **Minimum iOS:** 16.0
- **Architecture:** MVVM with ObservableObject + SwiftData @Model
- **Security:** Keychain for parent PIN (iCloud Keychain sync)

---

## Multi-User Family System (COMPLETE)

The app supports multiple players per device via a family profile system.

### Architecture
- **FamilyProfile** (@Model) — one per device, linked to UserProfiles via `familyID`
- **UserProfile** (@Model) — parent or child, linked to PlayerData via `ownerID` UUID
- **PlayerData** (@Model) — per-user game progress (coins, seeds, plots, recipes, health)
- **SessionManager** (ObservableObject) — central coordinator: routing, profile CRUD, PIN, play time
- **No @Relationship macros** — all linking via UUID fields (CloudKit compatibility)

### App Route Flow
```
App Launch → bootstrap()
  ├── Family exists → ProfilePickerView ("Who's playing today?")
  ├── Legacy data exists → MigrationPINSetupView
  └── Brand new → FamilySetupView (8-step wizard)

FamilySetupView: Welcome → Parent Name → Parent Avatar → Set PIN → Child Name → Child Avatar → Meet Pip → Ready

ProfilePickerView:
  ├── Tap child card → selectProfile() → MainTabView
  ├── Tap parent card → PIN entry → selectProfile() or ParentDashboardView
  └── Add Little Chef → PIN entry → AddChildFlowView (3 steps)
```

### Key Files
| File | Purpose |
|------|---------|
| `SessionManager.swift` | Route state machine, profile CRUD, PIN verify, play time |
| `FamilyProfile.swift` | @Model: familyID-based queries for members |
| `UserProfile.swift` | @Model: role, gender, avatar, familyID, playerData lookup |
| `PlayerData.swift` | @Model: coins, seeds, plots, pantry, recipes, health |
| `PINKeychain.swift` | Secure parent PIN via Keychain Services |
| `ProfilePickerView.swift` | "Who's playing today?" profile selection |
| `FamilySetupView.swift` | First-launch 8-step family wizard |
| `AddChildFlowView.swift` | Add subsequent children (3 steps + duplicate name check) |
| `ParentDashboardView.swift` | Child stats, play time, manage profiles |
| `ParentPINEntryView.swift` | PIN pad host (uses shared `PINPadGrid` from PipComponents) |
| `MigrationPINSetupView.swift` | Upgrade path for legacy single-user installs |

### SwiftData / PIN Rules

See **Architecture Rules → SwiftData / CloudKit Compatibility** (above) for the full list. PIN-specific rules:

### PIN System
- Stored in Keychain (not SwiftData) for security
- Syncs across devices via iCloud Keychain
- `PINKeychain.save(pin:)` / `PINKeychain.load()` / `PINKeychain.delete()`
- Parent PIN required for: accessing parent profile, adding children, dashboard, changing PIN

### Profile Data Flow
```
selectProfile() →
  ├── Existing PlayerData found → loadFromStore(for:) → MainTabView
  └── No PlayerData → createPlayerData() → resetToDefaults() → saveToStore() → MainTabView

resetToDefaults() gives: 0 coins (learn-to-earn — kids must tap nutrient cards / color seeds to earn), starter seeds (8 types), 5 garden plots, 2 unlocked recipes
loadFromStore() safety: if seeds empty → gives starter seeds automatically
```

---

## Visual Style

**Aesthetic:** Vintage botanical watercolor ("paper style")
**Core palette** (defined as `Color.AppTheme.*` in AppTheme.swift — backed by `Assets.xcassets/AppColors/` for Dark Mode support — never inline hex):
- `cream` #F5F0E1 (backgrounds), `warmCream` #FAF6EB, `parchment` #EDE6D3
- `sepia` #8B7355 (body text), `darkBrown` #5D4E37 (headlines), `lightSepia` #A89880
- `sage` #6B7B5E (primary CTAs / nature), `goldenWheat` #C9A227 (rewards / coins), `terracotta` #B87333 (warnings / heat), `softOlive` #8A9A7B (secondary accents), `warmKhaki` #C6BA8B
- **High-energy accents** (added May 11): `brightGreen`, `brightBlue`, `sunflowerYellow` — saturated CTA pop for age 6+ visibility. Use sparingly; sage/goldenWheat/terracotta remain the botanical default.
- Weather: `weatherSunny/PartlyCloudy/Cloudy/Stormy/Snowy/Rainy`; seasons: `springGradientTop/Blossom/summerGradientTop/Warm/fallGradientTop/Mid/winterGradientMid/Bot`; particles: `springPetal`, `frostBlue`, `autumnBrown`, `rainBlue`, `sunYellow`.

**Hard rule:** Zero hardcoded colors / fonts / spacing / animation curves. Full rules + token tables + pre-commit audit grep are in **Architecture Rules → Design System** (above).

---

## Character: Pip the Hedgehog

- Round, fluffy hedgehog with chef hat — kid's guide/mascot
- 13 static poses (`PipPose` enum in `PipAnimations.swift`) + walking animation + waving animation
- `PipWavingAnimatedView(size:)` — reusable animated Pip; size flows through the `PipSize` enum (`compact` 40 / `medium` 80 / `large` 120 / `hero` 160 / `.custom(N)` escape hatch)
- `PipSpeechBubble`, `PipHeaderStack` — two canonical layout components in `PipComponents.swift`; both auto-speak via `PipVoice.shared.speak(...)` on appear and on message change
- `PipDialogView` — modal confirm prompts ("Spend N coins and plant?") with `BouncyButtonStyle` choices
- Walking frames: `pip_walking_frame_01..15` at 30fps Timer-based (see `CharacterWalkingView`)

---

## Current Tab Structure (6 tabs)

| Tab | Icon | View | Purpose |
|-----|------|------|---------|
| Home | house.fill | HomeView | Main hub, sibling visits, switch player, parent dashboard |
| Garden | leaf.fill | GardenView | Plant & harvest veggies (interactive map) |
| Shop | cart.fill | FarmTabView → FarmShopView | Pip walks to barn, then seeds + pantry shop |
| Kitchen | fork.knife | KitchenView | Cook recipes with Pip; book icon opens RecipeListView |
| Body | person.fill | BodyBuddyView | "Your Body" — organ health rings + recipe impact |
| Play | gamecontroller.fill | PlayLearnView | Mini-games hub (Healthy Picks, Insulin Tetris, etc.) |

`Tab.recipes` still exists in the enum for references but is hidden from the tab bar — opened via the Kitchen book icon. `GardenHubView.swift` is orphaned dead code (zero references); planned deletion. The March audit's "merge Garden + Farm" suggestion was deferred — Garden + Shop stay separate tabs.

---

## Mini-Game System (COMPLETE)

9 mini-game types in `CookingMiniGames.swift`:
| Type | Gesture | File |
|------|---------|------|
| HeatPan | Hold finger | CookingMiniGames.swift |
| AddToPan | Drag ingredient | CookingMiniGames.swift |
| Stir | Circular swipe | CookingMiniGames.swift |
| Season | Tap sprinkle | CookingMiniGames.swift |
| Peel | Swipe down | CookingMiniGames.swift |
| CookTimer | Green zone timing | CookingMiniGames.swift |
| Wash | Tap rapidly | CookingMiniGames.swift |
| CrackEgg | Tap to crack | CookingMiniGames.swift |
| Assemble | Tap to plate | CookingMiniGames.swift |
| Chop | Tap timing | ChopMiniGame.swift |

`CookingSessionView.swift` — state machine: parses recipe steps → generates mini-game sequence → scores 0-100 per game → averages for star rating (85+=3, 60-84=2, <60=1)

---

## Key File Locations

| Category | File | Purpose |
|----------|------|---------|
| **App Entry** | `ChefAcademyApp.swift` | ModelContainer, RootRouterView, MainTabView, HomeView |
| **State** | `GameState.swift` | Central game state, SwiftData load/save, auto-save, `NutrientType` enum |
| **Theme** | `AppTheme.swift` | Colors, fonts, spacing, animation tokens, button styles |
| **Adaptive** | `AdaptiveLayout.swift` | iPhone/iPad sizing tokens, `.trailingFade()`, `AdaptiveCardSize` |
| **Pip Components** | `PipComponents.swift` | `PipSpeechBubble`, `PipHeaderStack`, `PipSize`, `PINPadGrid` |
| **Pip Animation** | `PipAnimations.swift` | `PipPose` enum, `PipWavingAnimatedView`, walking views |
| **Pip Voice** | `PipVoice.swift` | Two-tier voice (silent free / ElevenLabs paid). Apple TTS rejected May 10. |
| **Pip AI Chat** | `AskPipView.swift`, `PipAIService.swift`, `PipFoundationModelService.swift` | Claude Haiku/on-device routing, rate-limited, allergen-aware |
| **Garden** | `GardenView.swift` | Interactive map with plots + draggable Pip |
| **Plot** | `PlotView.swift` | Per-plot watering/weeding/bug rescue UX |
| **Kitchen** | `KitchenView.swift` | Interactive cooking scene map; opens RecipeListView via book icon |
| **Cooking** | `CookingSessionView.swift` | Multi-step state machine, mini-game sequencer |
| **Mini-games** | `CookingMiniGames.swift`, `ChopMiniGame.swift` | 9+ cooking mini-game views |
| **Recipes** | `RecipeCardExample.swift` | `PantryItem` enum, `Recipe` struct, `GardenRecipes.all` |
| **Recipe Detail** | `RecipeDetailView.swift` | Full-screen cookbook page with sticky "Let's Cook!" footer |
| **Shop** | `FarmShopView.swift`, `FarmTabView.swift` | Seed bags + pantry items + walk transition |
| **Body Buddy** | `BodyBuddyView.swift` | "Your Body" organ rings — cooked recipes feed organ health |
| **Play / Mini-games** | `PlayLearnView.swift`, `HealthyChoiceGameView.swift`, `InsulinTetrisView.swift`, `GlucoseJourneyView.swift`, `LocalVersusView.swift`, `NearbyVersusView.swift`, `SplitScreenVersusView.swift`, `MultiplayerHealthyPicksView.swift` | Game hub + Sugar Sorter + multiplayer modes |
| **Avatar** | `AvatarModel.swift` | `Gender`, `Outfit`, `HeadCovering` enums |
| **Avatar Creator** | `AvatarCreatorView.swift` | 2 tabs (Outfit, Covering); Hair tab removed |
| **Profile Picker** | `ProfilePickerView.swift` | "Who's playing today?" — uses `UserProfile.profilePoseImage` (mom/dad/girl/boy) |
| **Family Setup** | `FamilySetupView.swift`, `AddChildFlowView.swift` | 8-step wizard + add-child flow |
| **Parent Dashboard** | `ParentDashboardView.swift` | Child stats, play time, allergen edit |
| **Paywall** | `PaywallView.swift`, `SubscriptionManager.swift` | Pip Chat $3.99/mo subscription |
| **Onboarding** | `OnboardingView.swift`, `MeetPipAnimated.swift`, `MeetPipViews.swift` | First-launch / Meet Pip (3-dialog trim) |
| **Seed Info** | `SeedInfoView.swift` | Educational veggie pages + PencilKit coloring + coin rewards |
| **Pantry Info** | `PantryInfoView.swift` | Pantry item knowledge cards |
| **Weather** | `GardenWeatherService.swift`, `WeatherOverlayView.swift` | WeatherKit + animated overlays (rain, snow, storm, seasonal particles) |
| **Care Animations** | `WaterPourCharacterView.swift` | Kid pour animation + SwiftUI water particles |
| **Allergens** | `Allergen.swift`, `AllergenEditorSheet.swift`, `AllergenPickerStep.swift` | Allergen safety filtering |
| **Asset Packs** | `AssetPackController.swift`, `AssetPackImage.swift`, `ODRManager.swift` | Apple-Hosted Asset Packs migration (ODR deprecated WWDC25) |
| **Networking** | `WorkerClient.swift`, `AppAttestService.swift` | Cloudflare Worker + App Attest for API key security |
| **External APIs** | `USDAFoodService.swift`, `ElevenLabsVoiceService.swift`, `GameCenterService.swift`, `MultiplayerManager.swift`, `NearbyMultiplayerManager.swift` | USDA nutrition + ElevenLabs voice + Game Center + GameKit/MultipeerConnectivity |
| **Scene Editor** | `SceneEditor.swift` | Dev-only tool for positioning map items |

---

## Build & Test

```bash
# Build
xcodebuild -scheme ChefAcademy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Reset data (delete SwiftData store on simulator)
find ~/Library/Developer/CoreSimulator/Devices -name "default.store*" -path "*/Application Support/*" -exec rm -f {} \;
```

---

## Audit / Roadmap Sources of Truth

Don't enumerate live roadmap items in this file — it goes stale. Authoritative sources:

- **`UX_AUDIT_REPORT.md` / `UX_REDESIGN_PLAN.md`** — March 2026 external audit (most P0s shipped; some declined like Apple TTS free tier; rest deferred)
- **Latest `UX_REVIEW_<date>.md`** at repo root — Monday auto-routine (kid 6+ flow audit)
- **Latest `WEEKLY_REVIEW_<date>.md`** at repo root — Sun + Tue auto-routine (perf + hardcoding violations)
- **`GITHUB_ISSUES_DRAFT.md`** — current pre-launch backlog with priority tiers
- **`~/.claude/projects/.../memory/MEMORY.md`** and `project_next_priorities.md` — session-to-session priorities

When a CLAUDE.md statement contradicts one of those files, the dated file wins.

Standing decisions live in **Architecture Rules → Standing Decisions** (above). Coding conventions live in **Architecture Rules → SwiftUI Coding Conventions** (above).

---

## Contact & Attribution

**Developer:** Marina Pollak
**Course:** PROG-360A, Columbia College Chicago
**Instructor:** Janell Baxter
**Nutrition Research:** Jessie Inchauspé ("Glucose Goddess")

---

*Last Updated: May 12, 2026 — architecture stable; live roadmap lives in the dated review files + memory, not here.*
