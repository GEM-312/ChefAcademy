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
| `ParentPINEntryView.swift` | Reusable PIN pad (setup + verify modes) |
| `ProfileView.swift` | Me tab: stats, badges, switch player, dashboard |
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

resetToDefaults() gives: 100 coins, starter seeds (8 types), 5 garden plots, 2 unlocked recipes
loadFromStore() safety: if seeds empty → gives starter seeds automatically
```

---

## Visual Style

**Aesthetic:** Vintage botanical watercolor ("paper style")
**Colors (defined in AppTheme.swift):**
- Cream: #FDF6E3 (backgrounds)
- Warm Cream: #FAF0DC
- Parchment: #F5E6C8
- Sage: #9CAF88 (primary accent)
- Golden Wheat: #DAA520
- Terracotta: #C4A484
- Sepia: #5D4E37 (text)
- Dark Brown: #3D2914 (headings)
- Warm Khaki: #C6BA8B

**UX Audit Feedback:** Palette described as "gray/adult/sad" — needs vibrant accent colors for CTAs (see UX_REDESIGN_PLAN.md)

---

## Character: Pip the Hedgehog

- Round, fluffy hedgehog with chef hat
- 6 static poses + 15-frame walking animation + waving animation
- `PipWavingAnimatedView(size:)` — reusable animated Pip component
- Walking frames: pip_walking_frame_01 through 15 (30fps Timer-based)
- Appears throughout app as interactive guide/mascot

---

## Current Tab Structure (6 tabs)

| Tab | Icon | View | Purpose |
|-----|------|------|---------|
| Home | house.fill | HomeView | Main hub, quick actions |
| Garden | leaf.fill | GardenView | Plant & harvest veggies (interactive map) |
| Kitchen | fork.knife | KitchenView | Cook recipes with Pip (interactive map) |
| Farm | cart.fill | FarmTabView → FarmShopView | Pip walks to barn, then shop |
| Recipes | book.fill | RecipeListView | Browse all recipes |
| Me | person.fill | ProfileView | Stats, badges, switch player, dashboard |

**UX Audit Recommendation:** Merge Garden + Farm into one tab (see UX_REDESIGN_PLAN.md)

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
| **State** | `GameState.swift` | Central game state, SwiftData load/save, auto-save |
| **Theme** | `AppTheme.swift` | Colors, fonts, spacing constants |
| **Garden** | `GardenView.swift` | Interactive map with plots + draggable Pip |
| **Kitchen** | `KitchenView.swift` | Interactive cooking scene map |
| **Cooking** | `CookingSessionView.swift` | Mini-game sequence manager |
| **Mini-games** | `CookingMiniGames.swift` | 9 mini-game views |
| **Recipes** | `RecipeCardExample.swift` | PantryItem enum, Recipe struct, GardenRecipes.all |
| **Recipe Detail** | `RecipeDetailView.swift` | Full-screen cookbook page |
| **Farm** | `FarmShopView.swift` | Grid shop for pantry items |
| **Farm Anim** | `FarmTabView.swift` | Walk transition → shop |
| **Avatar** | `AvatarModel.swift` | Gender, outfit, head covering, profile load/save |
| **Onboarding** | `OnboardingView.swift` | Original onboarding flow manager |
| **Seed Info** | `SeedInfoView.swift` | Educational veggie pages + PencilKit coloring |
| **Scene Editor** | `SceneEditor.swift` | Dev tool for positioning map items |

---

## Build & Test

```bash
# Build
xcodebuild -scheme ChefAcademy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Reset data (delete SwiftData store on simulator)
find ~/Library/Developer/CoreSimulator/Devices -name "default.store*" -path "*/Application Support/*" -exec rm -f {} \;
```

---

## UX Audit & Redesign (March 2026)

External UX audit identified critical changes needed for 6+ audience:
- **Full report:** `UX_AUDIT_REPORT.md`
- **Implementation plan:** `UX_REDESIGN_PLAN.md`
- **Test plans:** `PROTOTYPE_TEST_PLAN.md`, `TestingPlan_PipsKitchenGarden.md`

### Top Priority Changes (P0):
1. Reduce text density — add voice (AVSpeechSynthesizer), max 4 steps
2. Brighten color palette — vibrant CTAs against paper backgrounds
3. Scroll-down cues on all scrollable areas
4. Make Pip bigger and interactive (tap to bounce, drag)
5. Fix typography consistency (unified bold child-friendly font)
6. Fix asset masking (transparent character PNGs)

### Next Priority Changes (P1):
7. Condense Garden + Farm into single tab
8. Kid-friendly recipe names (verb-object: "Sizzling Veggie Pan" not "Stir Fry")
9. Non-binary gender option
10. Pantry "grab all" / quantity stepper
11. Skippable animations after first viewing

---

## Next Session Priorities

### Multi-User Polish
- [ ] Test full flow on clean simulator: fresh install → family setup → play → switch profiles → verify data persists
- [ ] Verify parent dashboard shows correct child stats
- [ ] Test adding/removing child profiles
- [ ] Verify starter seeds work for all new profiles

### Game & UX Improvements
- [ ] Begin P0 UX redesign items (voice, colors, Pip scaling)
- [ ] Body Buddy — post-cooking flow: BodyBuddyView → animated food journey → organ highlights
- [ ] Polish cooking mini-games (visual feedback, scoring balance)
- [ ] Generate missing veggie/fruit/berry image assets (19 of 27 needed)
- [ ] Food Encyclopedia view
- [ ] Recipe gating by garden progress

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

*Last Updated: March 3, 2026*
