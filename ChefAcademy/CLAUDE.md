# CLAUDE.md - Pip's Kitchen Garden Project Instructions

## Project Overview

**App Name:** Pip's Kitchen Garden
**Platform:** iOS (iPhone/iPad)
**Language:** Swift / SwiftUI
**Target:** Ages 9-12
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

## Game Design Summary

```
┌─────────────────────────────────────────────────────────┐
│                   PIP'S KITCHEN GARDEN                  │
│                                                         │
│     🌱 GROW          🍳 COOK           🫀 FEED          │
│    ─────────  →    ─────────   →    ─────────          │
│    Garden          Kitchen          Body               │
│    Mini-games      Mini-games       Adventure          │
│                                                         │
│                    🏆 REWARDS                           │
│              Coins, Seeds, XP, Badges                   │
└─────────────────────────────────────────────────────────┘
```

### Three Pillars:

1. **GROW (Garden)**
   - Tap to plant seeds
   - Swipe to water plants
   - Tap bugs to defend crops
   - Pull gesture to harvest
   - Real-time or accelerated growth

2. **COOK (Kitchen)**
   - Each recipe = series of mini-games
   - Mini-game types: CHOP, CRACK, MIX, POUR, FLIP, HEAT, SPREAD, ASSEMBLE
   - Star rating (1-3) based on performance
   - Need ingredients from garden to cook

3. **FEED (Body Adventure)**
   - Animated food journey through digestive system
   - Organs light up when receiving nutrients
   - Persistent health meters for Body Buddy
   - Educational but FUN

---

## Tech Stack

- **UI Framework:** SwiftUI
- **Mini-games:** SwiftUI with gestures (or SpriteKit if needed)
- **Persistence:** UserDefaults for MVP, Core Data for full version
- **Minimum iOS:** 16.0
- **Architecture:** MVVM with ObservableObject

---

## Visual Style

**Aesthetic:** Vintage botanical watercolor
**Colors (defined in AppTheme.swift):**
- Cream: #FDF6E3 (backgrounds)
- Warm Cream: #FAF0DC
- Parchment: #F5E6C8
- Sage: #9CAF88 (primary accent)
- Golden Wheat: #DAA520
- Terracotta: #C4A484
- Sepia: #5D4E37 (text)
- Dark Brown: #3D2914 (headings)

**Fonts:**
- Headings: Georgia (serif)
- Body: System default

**UI Guidelines:**
- Rounded corners everywhere (16pt default)
- Soft shadows
- Bouncy spring animations
- NO harsh colors
- Kid-friendly, cozy, whimsical

---

## Character: Pip the Hedgehog

- Round, fluffy hedgehog with chef hat
- 6 poses available as PNG images:
  - pip_neutral.png
  - pip_waving.png
  - pip_excited.png
  - pip_cooking.png
  - pip_thinking.png
  - pip_celebrating.png
- Use circle mask (no transparent background)
- Bouncy idle animation
- Appears throughout app as guide/mascot

---

## Project File Structure

```
PipsKitchenGarden/
├── App/
│   ├── PipsKitchenGardenApp.swift    # Main app entry
│   └── MainTabView.swift              # Tab navigation
│
├── Models/
│   ├── GameState.swift                # Central game state manager
│   ├── GardenModel.swift              # Garden, plots, seeds, vegetables
│   ├── RecipeData.swift               # All recipes with ingredients/steps
│   ├── BodyBuddyModel.swift           # Body Buddy health & avatar
│   ├── QuestModel.swift               # Daily/weekly quests
│   └── BadgeModel.swift               # Achievements
│
├── Views/
│   ├── Hub/
│   │   └── HubView.swift              # Main game hub screen
│   │
│   ├── Garden/
│   │   ├── GardenView.swift           # Garden grid view
│   │   ├── PlotView.swift             # Individual plot
│   │   ├── PlantingSheet.swift        # Seed selection
│   │   └── HarvestAnimation.swift     # Harvest effects
│   │
│   ├── Kitchen/
│   │   ├── KitchenView.swift          # Recipe selection
│   │   ├── RecipeDetailView.swift     # Recipe info + start cooking
│   │   ├── CookingSessionView.swift   # Mini-game sequence manager
│   │   └── MiniGames/
│   │       ├── ChopMiniGame.swift
│   │       ├── CrackMiniGame.swift
│   │       ├── MixMiniGame.swift
│   │       ├── PourMiniGame.swift
│   │       ├── FlipMiniGame.swift
│   │       └── HeatMiniGame.swift
│   │
│   ├── Body/
│   │   ├── BodyBuddyView.swift        # Body Buddy with health meters
│   │   ├── FoodJourneyView.swift      # Animated digestion journey
│   │   └── OrganDetailView.swift      # Tap organ for info
│   │
│   ├── Profile/
│   │   ├── ProfileView.swift          # Player stats, settings
│   │   ├── BadgesView.swift           # Achievement gallery
│   │   └── InventoryView.swift        # Seeds & ingredients
│   │
│   └── Onboarding/
│       ├── OnboardingView.swift       # Flow manager
│       ├── AvatarCreatorView.swift    # Create Body Buddy
│       └── MeetPipViews.swift         # Meet Pip dialogue
│
├── Components/
│   ├── PipCharacterView.swift         # Animated Pip component
│   ├── CoinDisplay.swift              # Currency display
│   ├── XPBar.swift                    # Experience progress bar
│   ├── HealthMeter.swift              # Body Buddy health bars
│   ├── StarRating.swift               # 1-3 star display
│   └── QuestCard.swift                # Daily quest card
│
├── Animation/
│   ├── PipAnimations.swift            # Pip poses & transitions
│   └── ParticleEffects.swift          # Sparkles, confetti
│
├── Theme/
│   └── AppTheme.swift                 # Colors, fonts, spacing
│
└── Assets.xcassets/
    ├── Pip/                           # Pip character images
    ├── Vegetables/                    # Vegetable illustrations
    ├── UI/                            # Buttons, icons
    └── Body/                          # Body Buddy organs
```

---

## Key Models Reference

### GameState (Central Manager)
```swift
class GameState: ObservableObject {
    @Published var coins: Int
    @Published var xp: Int
    @Published var playerLevel: Int
    @Published var seeds: [Seed]
    @Published var harvestedIngredients: [HarvestedIngredient]
    @Published var gardenPlots: [GardenPlot]
    @Published var unlockedRecipeIDs: Set<String>
    @Published var recipeStars: [String: Int]
    @Published var dailyQuests: [Quest]
    // Body Buddy health meters (0-100)
    @Published var brainHealth: Int
    @Published var muscleHealth: Int
    @Published var boneHealth: Int
    @Published var heartHealth: Int
    @Published var immuneHealth: Int
    @Published var energyLevel: Int
}
```

### GardenPlot
```swift
struct GardenPlot: Identifiable {
    let id: Int
    var state: PlotState // .empty, .planted, .growing, .ready, .water
    var vegetable: VegetableType?
    var plantedDate: Date?
    var growthProgress: Double // 0.0 to 1.0
}
```

### VegetableType
```swift
enum VegetableType: String, CaseIterable {
    case lettuce, carrot, tomato, cucumber
    case bellPepperRed, bellPepperYellow, spinach, avocado
    
    var growthTime: TimeInterval // seconds
    var harvestYield: Int
    var seedCost: Int
    var harvestValue: Int // coins
    var nutrients: [NutrientBoost]
}
```

### Recipe (Already exists in RecipeData.swift)
- Has ingredients, steps, difficulty
- Each step links to a mini-game type
- Star rating based on mini-game performance

---

## Mini-Game Specifications

Each mini-game should:
1. Have a clear objective shown at start
2. Use intuitive gestures (tap, swipe, drag)
3. Give immediate visual/audio feedback
4. Award points based on timing/accuracy
5. Show result (Perfect! / Good! / Okay!)
6. Take 10-30 seconds to complete

### Mini-Game Types:

| Type | Gesture | Visual |
|------|---------|--------|
| CHOP | Tap at right moment | Knife cuts vegetable |
| CRACK | Tap + pull apart | Egg cracks into bowl |
| MIX | Circular swipe | Spoon stirs ingredients |
| POUR | Tilt/drag | Liquid fills to line |
| FLIP | Swipe up | Food flips in pan |
| HEAT | Slider + timing | Temperature control |
| SPREAD | Back-forth swipe | Knife spreads on bread |
| ASSEMBLE | Drag & drop | Build the final dish |

---

## Animation Guidelines

Use SwiftUI animations with these principles:
- `.spring(response: 0.5, dampingFraction: 0.6)` for bouncy
- `.easeOut` for UI appearing
- `.easeIn` for UI disappearing
- Always animate state changes
- Use `withAnimation { }` blocks
- Particle effects for celebrations (sparkles, confetti)

---

## Coding Conventions

1. **Use SwiftUI** for all views
2. **MVVM pattern** with ObservableObject
3. **@EnvironmentObject** for GameState (inject at app root)
4. **Descriptive names** - prioritize readability
5. **Comment complex logic** but don't over-comment obvious code
6. **Group related code** with `// MARK: -` sections
7. **Keep views small** - extract components when >100 lines
8. **Use AppTheme** constants for all colors, fonts, spacing

### Example View Structure:
```swift
import SwiftUI

struct ExampleView: View {
    @EnvironmentObject var gameState: GameState
    @State private var localState: Bool = false
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Content here
        }
        .background(Color.AppTheme.cream)
    }
}

#Preview {
    ExampleView()
        .environmentObject(GameState())
}
```

---

## Current Progress (What's Already Built)

### ✅ Complete:
- AppTheme.swift (colors, fonts, spacing)
- AdaptiveLayout.swift (iPhone/iPad responsive helpers)
- Onboarding flow (5 screens) - connected to HomeView
- Avatar creator (becomes Body Buddy)
- AvatarModel with UserDefaults persistence for name
- Meet Pip dialogue sequence
- PipAnimations.swift (6 poses, circle mask, bounce)
- Pip character images (6 poses from Midjourney)
- **MainTabView** with 5 tabs (Home, Garden, Recipes, Play, Profile)
- **HomeView** with greeting, streak card, Pip message, quick actions, recipe preview
- **RecipeListView** with category filtering (All, Breakfast, Lunch, Dinner, Snacks)
- RecipeCardView with images, difficulty badges, cook time
- Recipe illustrations (Rainbow Veggie Wrap, Sunny Pancakes, Garden Pasta)
- Navigation from Home → other tabs via quick action buttons
- README.md with full style guide and Leonardo.ai prompts

### 🚧 In Progress:
- GameState.swift (central manager)
- GardenModel.swift
- GardenView (placeholder exists, needs full implementation)

### ❌ Not Started:
- Vegetable illustrations (folder created: Assets.xcassets/Vegetables/)
- Garden plots with planting/watering/harvesting
- Mini-games (Chop, Mix, Pour, etc.)
- Body Adventure animation
- Quest system UI
- Badges UI
- Profile view

---

## Next Session: Garden View + Vegetables

### Tomorrow's Tasks:
1. **Upload vegetable illustrations** to Assets.xcassets/Vegetables/
   - Suggested vegetables: carrot, tomato, lettuce, cucumber, bell pepper, spinach
   - Use Leonardo.ai with style reference from Pip images

2. **Build GardenView** with:
   - Grid of 6-9 garden plots
   - PlotView component (empty, planted, growing, ready states)
   - Tap to plant seeds (show seed selection sheet)
   - Visual growth progress indicator
   - Harvest animation when ready

3. **GardenModel** data structure:
   - VegetableType enum with growth times, yields, costs
   - GardenPlot struct with state management
   - Integration with GameState for coins/inventory

### Leonardo.ai Prompt for Vegetables:
```
cute [vegetable name] illustration, soft pencil sketch on cream paper,
children's book style, gentle sepia shading, whimsical friendly,
hand-drawn feel, minimal details, cozy warm tones
```
Negative: realistic, 3d, photograph, dark, scary, detailed, complex

---

## Development Notes

### Testing Onboarding
In ChefAcademyApp.swift there's a flag:
```swift
private let resetOnboarding = true  // Set to false after testing
```
Set to `true` to reset and test onboarding flow again.

### Key File Locations:
- Main app: `ChefAcademyApp.swift`
- Home screen: `ChefAcademyApp.swift` (HomeView struct)
- Recipes: `RecipeCardExample.swift`
- Onboarding: `OnboardingView.swift`
- Avatar/User data: `AvatarModel.swift`
- Theme: `AppTheme.swift`
- Adaptive layout: `AdaptiveLayout.swift`

---

## When Building New Features

1. **Check if model exists** - Don't duplicate data structures
2. **Use GameState** - All game data goes through central manager
3. **Follow visual style** - Use AppTheme colors/fonts
4. **Make it playful** - This is a GAME for kids, add delight!
5. **Test with previews** - Every view should have #Preview
6. **Keep scope realistic** - MVP first, polish later

---

## Important Files to Reference

Before building, read these files for context:
- `/Documentation/GameDesignDocument.md` - Full game design
- `/Documentation/ProjectProposal_OnePage.md` - Quick overview
- `/Content/SavoryBreakfastRecipes.md` - Recipe content
- `/Theme/AppTheme.swift` - Visual constants
- `/Models/RecipeData.swift` - Recipe data structure

---

## Quick Commands

When asked to build something:
1. First check what files already exist
2. Reference the file structure above
3. Use existing models/components when possible
4. Create new files in the correct folders
5. Always inject GameState as @EnvironmentObject
6. Add #Preview for every new view

---

## Contact & Attribution

**Developer:** Marina Pollak
**Course:** PROG-360A, Columbia College Chicago
**Instructor:** Janell Baxter
**Nutrition Research:** Jessie Inchauspé ("Glucose Goddess")
- "Glucose Revolution" (2022)
- "The Glucose Goddess Method" (2023)

---

*Last Updated: February 1, 2026*
