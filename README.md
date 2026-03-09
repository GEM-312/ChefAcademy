<p align="center">
  <img src="ChefAcademy/Assets.xcassets/Pip/pip_waving.imageset/pip_waving.png" width="200" alt="Pip the Chef Hedgehog"/>
</p>

<h1 align="center">Pip's Kitchen Garden</h1>

<p align="center">
  <strong>A delightful iOS cooking game for kids aged 6+</strong><br>
  Grow vegetables, cook recipes, and learn about nutrition with Pip the hedgehog!
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS-blue?style=flat-square" alt="Platform"/>
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift"/>
  <img src="https://img.shields.io/badge/SwiftUI-4.0-purple?style=flat-square" alt="SwiftUI"/>
  <img src="https://img.shields.io/badge/SwiftData-1.0-red?style=flat-square" alt="SwiftData"/>
  <img src="https://img.shields.io/badge/iOS-16.0+-green?style=flat-square" alt="iOS Version"/>
</p>

---

## Meet Pip

Pip is your friendly hedgehog chef guide! With 6 adorable poses and a walking animation, Pip helps kids through every step of their cooking adventure.

<p align="center">
  <img src="ChefAcademy/Assets.xcassets/Pip/pip_neutral.imageset/pip_neutral.png" width="120" alt="Pip Neutral"/>
  <img src="ChefAcademy/Assets.xcassets/Pip/pip_waving.imageset/pip_waving.png" width="120" alt="Pip Waving"/>
  <img src="ChefAcademy/Assets.xcassets/Pip/pip_cooking.imageset/pip_cooking.png" width="120" alt="Pip Cooking"/>
  <img src="ChefAcademy/Assets.xcassets/Pip/pip_thinking.imageset/pip_thinking.png" width="120" alt="Pip Thinking"/>
  <img src="ChefAcademy/Assets.xcassets/Pip/pip_excited.imageset/pip_excited.png" width="120" alt="Pip Excited"/>
  <img src="ChefAcademy/Assets.xcassets/Pip/pip_celebrating.imageset/pip_celebrating.png" width="120" alt="Pip Celebrating"/>
</p>

<p align="center">
  <em>Neutral - Waving - Cooking - Thinking - Excited - Celebrating</em>
</p>

---

## Game Loop

```
+-----------------------------------------------------------+
|                   PIP'S KITCHEN GARDEN                     |
|                                                            |
|    GROW           COOK            FEED                     |
|   ---------  ->  ---------  ->  ---------                  |
|   Garden         Kitchen        Body Buddy                 |
|   Mini-games     Mini-games     Nutrition Viz              |
|                                                            |
|                   REWARDS                                  |
|             Coins, Seeds, XP, Badges                       |
+-----------------------------------------------------------+
```

---

## Features

| Feature | Description |
|---------|-------------|
| **Garden** | Plant, water, and harvest 27 types of vegetables with fun gestures |
| **Kitchen** | Cook 17 recipes through 10 interactive mini-games (chop, stir, season, peel, crack eggs, and more!) |
| **Farm Shop** | Buy pantry ingredients with earned coins |
| **Body Buddy** | Track how food fuels your body with organ health rings |
| **Play & Learn** | Mini-game hub with veggie match, nutrition quiz, and chop challenges |
| **Seed Info** | Educational veggie pages with PencilKit coloring and fun facts |
| **Multi-User** | Family system with up to 4 children per device, parent PIN protection |
| **Sibling Visits** | Visit your sibling's garden, see their progress, and leave likes! |
| **Progression** | Earn coins, XP, badges, and unlock new recipes |
| **Quests** | Daily challenges to keep kids engaged |

---

## Multi-User Family System

The app supports multiple players per device via a family profile system:

- **Family Setup** - 8-step onboarding wizard for first launch
- **Profile Picker** - "Who's playing today?" screen with child avatars
- **Parent PIN** - Secure Keychain-stored PIN for parent access
- **Separate Progress** - Each child has their own garden, recipes, coins, and stats
- **Parent Dashboard** - View children's stats, play time, and manage profiles
- **Avatar Creator** - Boy/girl character selection with head covering options

---

## Sibling Garden Visits

Kids can visit each other's gardens from the Home screen:

1. Tap a sibling's avatar on the Home screen
2. View their profile (level, stats, harvested veggies, recipes cooked)
3. Tap "Visit Garden" to see their real garden (read-only)
4. Pip greets the visitor with a fun message
5. Tap "Cool garden!" to leave a like that the garden owner collects

---

## Cooking System

Multi-step cooking with 10 mini-game types:

| Mini-Game | Gesture | Description |
|-----------|---------|-------------|
| **Chop** | Tap timing | Chop veggies to the beat |
| **Heat Pan** | Hold finger | Heat the pan to the right temperature |
| **Add to Pan** | Drag | Drag ingredients into the pan |
| **Stir** | Circular swipe | Stir the pot with circular gestures |
| **Season** | Tap sprinkle | Season with taps |
| **Peel** | Swipe down | Peel veggies with swipe gestures |
| **Cook Timer** | Green zone timing | Stop the timer in the green zone |
| **Wash** | Tap rapidly | Wash veggies clean |
| **Crack Egg** | Tap to crack | Crack eggs into the bowl |
| **Assemble** | Tap to plate | Plate the final dish |

Scoring: Each mini-game scores 0-100, averaged for star rating (85+ = 3 stars, 60-84 = 2 stars, <60 = 1 star).

---

## Nutrition Integration

Inspired by Jessie Inchauste's ("Glucose Goddess") research:
- 17 recipes across 4 categories: breakfast, lunch, dinner, snacks
- Zero starch-centered meals - focused on veggie-forward nutrition
- Glucose tips on recipes explaining blood sugar impact
- Color-coded nutrition education in Seed Info (PencilKit coloring maps ink colors to nutrients)

---

## Tab Structure

| Tab | Icon | View | Purpose |
|-----|------|------|---------|
| Home | house.fill | HomeView | Main hub, sibling visits, quick actions |
| Garden | leaf.fill | GardenView | Plant & harvest veggies (interactive map) |
| Shop | cart.fill | FarmTabView | Pip walks to barn, then pantry shop |
| Kitchen | fork.knife | KitchenView | Cook recipes (+ Recipe Book access) |
| Body | figure.stand | BodyBuddyView | Organ health visualization |
| Play | gamecontroller.fill | PlayLearnView | Mini-games hub |

---

## Style Guide

### Color Palette

The visual style is inspired by **vintage botanical watercolor illustrations** with a warm, whimsical, handcrafted feel.

#### Primary Colors (Backgrounds)

| Color | Hex | Usage |
|-------|-----|-------|
| **Cream** | `#F5F0E1` | Main backgrounds |
| **Warm Cream** | `#FAF6EB` | Lighter backgrounds |
| **Parchment** | `#EDE6D3` | Cards, surfaces |

#### Text Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Dark Brown** | `#5D4E37` | Headlines, emphasis |
| **Sepia** | `#8B7355` | Primary text |
| **Light Sepia** | `#A89880` | Secondary text |

#### Accent Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Golden Wheat** | `#C9A227` | Buttons, highlights, rewards |
| **Sage** | `#6B7B5E` | Nature accents, success states |
| **Soft Olive** | `#8A9A7B` | Secondary accents |
| **Terracotta** | `#B87333` | Warnings, heat indicators |
| **Warm Khaki** | `#C6BA8B` | Avatar styling, gradient accents |

### Typography

All fonts use **SF Rounded** (system) for a friendly, approachable feel.

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| **Large Title** | 34pt | Bold | Main screen titles |
| **Title** | 28pt | Semibold | Section headers |
| **Title 2** | 22pt | Semibold | Card titles |
| **Headline** | 17pt | Semibold | Button text, emphasis |
| **Body** | 17pt | Regular | Main content text |
| **Caption** | 12pt | Regular | Labels, badges |

---

## Tech Stack

- **Language:** Swift 5.9
- **UI Framework:** SwiftUI
- **Persistence:** SwiftData with iCloud CloudKit sync
- **Architecture:** MVVM with ObservableObject + SwiftData @Model
- **Security:** Keychain for parent PIN (iCloud Keychain sync)
- **Drawing:** PencilKit (Seed Info coloring)
- **Minimum iOS:** 16.0
- **Target Devices:** iPhone & iPad

---

## Project Structure

```
ChefAcademy/
+-- ChefAcademyApp.swift        # App entry, MainTabView, HomeView, CustomTabBar
+-- GameState.swift              # Central game state, SwiftData load/save, auto-save
+-- AppTheme.swift               # Colors, fonts, spacing constants
|
+-- Models/
|   +-- PlayerData.swift         # @Model: coins, seeds, plots, pantry, health, likes
|   +-- UserProfile.swift        # @Model: name, role, gender, avatar, familyID
|   +-- FamilyProfile.swift      # @Model: familyID-based member queries
|   +-- SessionManager.swift     # Route state machine, profile CRUD, PIN, play time
|   +-- PINKeychain.swift        # Secure parent PIN via Keychain Services
|   +-- AvatarModel.swift        # Gender, outfit, head covering
|
+-- Garden/
|   +-- GardenView.swift         # Interactive garden map with plots + draggable Pip
|   +-- PlantingSheet.swift      # Seed selection sheet for planting
|   +-- SeedInfoView.swift       # Educational veggie pages + PencilKit coloring
|
+-- Kitchen/
|   +-- KitchenView.swift        # Interactive cooking scene + Recipe Book button
|   +-- CookingSessionView.swift # Multi-step cooking state machine
|   +-- CookingMiniGames.swift   # 9 mini-game views
|   +-- ChopMiniGame.swift       # Original chopping mini-game
|   +-- CookingCompletionView.swift # Post-cooking results
|
+-- Farm/
|   +-- FarmTabView.swift        # Walk transition -> shop
|   +-- FarmShopView.swift       # Grid shop for pantry items
|
+-- Recipes/
|   +-- RecipeCardExample.swift  # PantryItem enum, Recipe struct, GardenRecipes.all
|   +-- RecipeDetailView.swift   # Full-screen cookbook page
|
+-- Social/
|   +-- SiblingProfileView.swift # Sibling stats, harvested veggies, visit garden
|   +-- SiblingGardenView.swift  # Read-only garden visit with Pip greeting
|   +-- PipDialogView.swift      # Game-style dialog overlay with choices
|
+-- Body & Play/
|   +-- BodyBuddyView.swift      # Organ health rings visualization
|   +-- PlayLearnView.swift      # Mini-games hub (6 game cards)
|
+-- Family Setup/
|   +-- FamilySetupView.swift    # 8-step first-launch wizard
|   +-- ProfilePickerView.swift  # "Who's playing today?" screen
|   +-- AddChildFlowView.swift   # Add subsequent children
|   +-- ParentDashboardView.swift# Child stats, play time, manage profiles
|   +-- ParentPINEntryView.swift # PIN pad (setup + verify modes)
|   +-- ProfileView.swift        # Player profile stats and badges
|
+-- Onboarding/
|   +-- OnboardingView.swift     # Original onboarding flow
|   +-- AvatarCreatorView.swift  # Character creation (2 tabs: Outfit, Covering)
|
+-- Components/
|   +-- PipAnimations.swift      # Pip character poses + waving animation
|   +-- SceneEditor.swift        # Dev tool for positioning map items
|
+-- Assets.xcassets/
    +-- Pip/                     # Character images (6 poses + 15 walking frames)
    +-- AvatarCards/             # Boy (28 frames) + Girl (15 frames) animations
    +-- Backgrounds/             # Scene backgrounds (garden, kitchen, farm)
    +-- FarmItems/               # Pantry item images (farm_salt, farm_pepper, etc.)
    +-- Vegetables/              # 27 veggie/fruit/berry images
```

---

## Getting Started

1. Clone the repository
   ```bash
   git clone https://github.com/GEM-312/ChefAcademy.git
   ```

2. Open in Xcode
   ```bash
   cd ChefAcademy
   open ChefAcademy.xcodeproj
   ```

3. Build and run on simulator or device (iOS 16.0+)
   ```bash
   xcodebuild -scheme ChefAcademy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
   ```

---

## Development Progress

### Completed
- [x] Core game loop: Grow -> Cook -> Feed -> Rewards
- [x] Interactive garden with 27 plant types and plot management
- [x] Multi-step cooking system with 10 mini-game types
- [x] 17 veggie-forward recipes (breakfast, lunch, dinner, snacks)
- [x] Farm Shop with pantry items and coin economy
- [x] Multi-user family system with SwiftData + iCloud CloudKit prep
- [x] Parent PIN protection via Keychain
- [x] Avatar creator with gender + head covering options
- [x] Seed Info educational pages with PencilKit coloring
- [x] Sibling garden visits with Pip greeting and likes system
- [x] Body Buddy organ health visualization
- [x] Play & Learn mini-games hub
- [x] Tab-based navigation (6 tabs: Home, Garden, Shop, Kitchen, Body, Play)
- [x] Landscape support with adaptive tab bar
- [x] PipDialogView game-style dialog system

### In Progress
- [ ] P0 UX Redesign: voice/audio, vibrant CTA colors, scroll cues
- [ ] Body Buddy animated food journey through organs
- [ ] Cooking mini-game visual feedback and scoring polish
- [ ] 19 missing veggie/fruit/berry image assets
- [ ] Food Encyclopedia view
- [ ] Recipe gating by garden progress

---

## Credits

**Developer:** Marina Pollak
**Course:** PROG-360A Project Studio, Columbia College Chicago
**Instructor:** Janell Baxter
**Deadline:** May 15, 2026

**Nutrition Research:**
- Jessie Inchauste ("Glucose Goddess")
- *Glucose Revolution* (2022)
- *The Glucose Goddess Method* (2023)

---

<p align="center">
  <img src="ChefAcademy/Assets.xcassets/Pip/pip_celebrating.imageset/pip_celebrating.png" width="150" alt="Pip Celebrating"/>
  <br>
  <strong>Happy Cooking!</strong>
</p>
