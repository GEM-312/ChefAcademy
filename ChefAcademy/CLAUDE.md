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

### SwiftData Rules (CloudKit Compatibility)
- ALL @Model properties MUST have default values at declaration
- NO @Relationship macros — use UUID linking instead
- NO [String: Int] dictionaries — use [CodableStruct] arrays
- `.modelContainer(modelContainer)` MUST be on WindowGroup
- `@Environment(\.modelContext)` only works if .modelContainer is set

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
**Core palette** (defined as `Color.AppTheme.*` in AppTheme.swift — never inline hex):
- `cream` #FDF6E3 (backgrounds), `warmCream` #FAF0DC, `parchment` #F5E6C8
- `sepia` #5D4E37 (text), `darkBrown` #3D2914 (headings), `lightSepia`
- `sage` #9CAF88 (primary CTAs), `goldenWheat` #DAA520, `terracotta` #C4A484, `softOlive`, `warmKhaki` #C6BA8B
- **High-energy accents** (added May 11): `brightGreen`, `brightBlue`, `sunflowerYellow` — saturated CTA pop for age 6+ visibility. Use sparingly; sage/goldenWheat/terracotta remain the botanical default.
- Weather: `weatherSunny/PartlyCloudy/Cloudy/Stormy/Snowy/Rainy`; seasons: `springGradientTop/Blossom/summerGradientTop/Warm/fallGradientTop/Mid/winterGradientMid/Bot`; particles: `springPetal`, `frostBlue`, `autumnBrown`, `rainBlue`, `sunYellow`.

**Hard rule (per `feedback_no_hardcoded_values.md`):** ZERO hardcoded colors / fonts / spacing / animation curves. Every value must come from `Color.AppTheme.*`, `Font.AppTheme.*`, `AppSpacing.*`, or `AnimationConstants.*`. Use `.softCard()`, `.texturedButton(tint:)`, `BouncyButtonStyle()`, `TexturedButtonStyle` — never hand-roll `.background()+.cornerRadius()+.shadow()` chains.

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

### Standing decisions (don't re-litigate without a memory update)

- **Free voice = silent text, paid = ElevenLabs.** Apple TTS rejected May 10. Don't re-propose it.
- **Sage palette stays botanical.** `brightGreen/brightBlue/sunflowerYellow` tokens exist for selective use; do NOT sweep all CTAs to brightGreen.
- **`Color.AppTheme.*` + `AppSpacing.*` + `AnimationConstants.*` are mandatory.** Zero hardcoded values in any new SwiftUI code. Audit before declaring done.
- **TEACHING.md gets a session block appended every working session.** Memory notes are not a substitute.
- **Read all files before changes** when asked. Don't argue context budget.

---

## Coding Conventions

1. **SwiftUI** for all views
2. **MVVM** with ObservableObject + SwiftData @Model
3. **@EnvironmentObject** for GameState, SessionManager, AvatarModel
4. **@Environment(\.modelContext)** for SwiftData queries in views
5. **UUID-based linking** between models (no @Relationship)
6. **AppTheme** constants for all colors, fonts, spacing
7. **`// MARK: -`** sections for code organization
8. **#Preview** for every new view

---

## Contact & Attribution

**Developer:** Marina Pollak
**Course:** PROG-360A, Columbia College Chicago
**Instructor:** Janell Baxter
**Nutrition Research:** Jessie Inchauspé ("Glucose Goddess")

---

*Last Updated: May 12, 2026 — architecture stable; live roadmap lives in the dated review files + memory, not here.*
