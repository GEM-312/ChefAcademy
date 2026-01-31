//
//  GameState.swift
//  ChefAcademy
//
//  Created by Marina Pollak - Learning SwiftUI!
//
//  This is the "BRAIN" of your game!
//  It keeps track of everything: coins, seeds, garden plots, recipes, etc.
//

import SwiftUI
import Combine

// MARK: - GameState (The Central Manager)
//
// Think of this class like a notebook that remembers EVERYTHING about your game.
// The "@Published" keyword means: "When this value changes, update the screen!"
// "ObservableObject" lets SwiftUI watch for changes and react automatically.
//

class GameState: ObservableObject {

    // ============================================
    // CURRENCY & PROGRESSION
    // ============================================

    /// Coins are earned by harvesting vegetables and completing recipes
    @Published var coins: Int = 100  // Start with some coins!

    /// XP (Experience Points) - earn by doing activities
    @Published var xp: Int = 0

    /// Player level - increases as you gain XP
    @Published var playerLevel: Int = 1

    // ============================================
    // GARDEN DATA
    // ============================================

    /// The seeds you own and can plant
    @Published var seeds: [Seed] = Seed.starterSeeds

    /// Vegetables you've harvested from the garden
    @Published var harvestedIngredients: [HarvestedIngredient] = []

    /// The 4 garden plots (2x2 grid)
    @Published var gardenPlots: [GardenPlot] = GardenPlot.createStarterPlots()

    // ============================================
    // RECIPE PROGRESS
    // ============================================

    /// Which recipes are unlocked (by ID)
    @Published var unlockedRecipeIDs: Set<String> = ["veggie-wrap", "garden-salad"]

    /// Star ratings for completed recipes (recipeID: stars)
    @Published var recipeStars: [String: Int] = [:]

    // ============================================
    // BODY BUDDY HEALTH (0-100 scale)
    // ============================================

    @Published var brainHealth: Int = 50
    @Published var muscleHealth: Int = 50
    @Published var boneHealth: Int = 50
    @Published var heartHealth: Int = 50
    @Published var immuneHealth: Int = 50
    @Published var energyLevel: Int = 50

    // ============================================
    // QUESTS & ACHIEVEMENTS
    // ============================================

    @Published var dailyQuests: [Quest] = Quest.generateDailyQuests()
    @Published var completedBadgeIDs: Set<String> = []

    // ============================================
    // HELPER METHODS
    // ============================================

    /// Add coins with a fun animation trigger
    func addCoins(_ amount: Int) {
        withAnimation(.spring()) {
            coins += amount
        }
    }

    /// Spend coins (returns false if not enough)
    func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        withAnimation(.spring()) {
            coins -= amount
        }
        return true
    }

    /// Add XP and check for level up
    func addXP(_ amount: Int) {
        xp += amount
        checkLevelUp()
    }

    /// Check if player should level up
    private func checkLevelUp() {
        let xpNeeded = playerLevel * 100  // Each level needs 100 more XP
        if xp >= xpNeeded {
            xp -= xpNeeded
            playerLevel += 1
        }
    }

    /// Add harvested ingredient to inventory
    func addHarvestedIngredient(_ type: VegetableType, quantity: Int = 1) {
        if let index = harvestedIngredients.firstIndex(where: { $0.type == type }) {
            harvestedIngredients[index].quantity += quantity
        } else {
            harvestedIngredients.append(HarvestedIngredient(type: type, quantity: quantity))
        }
    }

    /// Check if player has enough of an ingredient
    func hasIngredient(_ type: VegetableType, quantity: Int = 1) -> Bool {
        guard let ingredient = harvestedIngredients.first(where: { $0.type == type }) else {
            return false
        }
        return ingredient.quantity >= quantity
    }

    /// Use an ingredient (for cooking)
    func useIngredient(_ type: VegetableType, quantity: Int = 1) -> Bool {
        guard let index = harvestedIngredients.firstIndex(where: { $0.type == type }),
              harvestedIngredients[index].quantity >= quantity else {
            return false
        }
        harvestedIngredients[index].quantity -= quantity
        if harvestedIngredients[index].quantity <= 0 {
            harvestedIngredients.remove(at: index)
        }
        return true
    }
}

// MARK: - Seed Model
//
// Seeds are what you plant in the garden!
// Each seed type grows into a specific vegetable.
//

struct Seed: Identifiable, Equatable {
    let id = UUID()
    let vegetableType: VegetableType
    var quantity: Int

    /// Starting seeds for new players
    static let starterSeeds: [Seed] = [
        Seed(vegetableType: .lettuce, quantity: 5),
        Seed(vegetableType: .carrot, quantity: 3),
        Seed(vegetableType: .tomato, quantity: 3)
    ]
}

// MARK: - VegetableType Enum
//
// All the vegetables you can grow in your garden!
// Each one has different growth times, costs, and nutrients.
//

enum VegetableType: String, CaseIterable, Identifiable {
    case lettuce
    case carrot
    case tomato
    case cucumber
    case bellPepperRed
    case bellPepperYellow
    case spinach
    case avocado

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .lettuce: return "Lettuce"
        case .carrot: return "Carrot"
        case .tomato: return "Tomato"
        case .cucumber: return "Cucumber"
        case .bellPepperRed: return "Red Pepper"
        case .bellPepperYellow: return "Yellow Pepper"
        case .spinach: return "Spinach"
        case .avocado: return "Avocado"
        }
    }

    /// Emoji for quick display
    var emoji: String {
        switch self {
        case .lettuce: return "🥬"
        case .carrot: return "🥕"
        case .tomato: return "🍅"
        case .cucumber: return "🥒"
        case .bellPepperRed: return "🫑"
        case .bellPepperYellow: return "🫑"
        case .spinach: return "🥬"
        case .avocado: return "🥑"
        }
    }

    /// How long to grow (in seconds) - short for testing!
    var growthTime: TimeInterval {
        switch self {
        case .lettuce: return 30      // 30 seconds (fast for testing)
        case .carrot: return 60       // 1 minute
        case .tomato: return 90       // 1.5 minutes
        case .cucumber: return 60
        case .bellPepperRed: return 120
        case .bellPepperYellow: return 120
        case .spinach: return 45
        case .avocado: return 180     // 3 minutes (slowest)
        }
    }

    /// How many vegetables you get when harvesting
    var harvestYield: Int {
        switch self {
        case .lettuce: return 2
        case .carrot: return 3
        case .tomato: return 4
        case .cucumber: return 2
        case .bellPepperRed: return 2
        case .bellPepperYellow: return 2
        case .spinach: return 3
        case .avocado: return 1
        }
    }

    /// Cost to buy seeds
    var seedCost: Int {
        switch self {
        case .lettuce: return 5
        case .carrot: return 10
        case .tomato: return 15
        case .cucumber: return 10
        case .bellPepperRed: return 20
        case .bellPepperYellow: return 20
        case .spinach: return 10
        case .avocado: return 30
        }
    }

    /// Coins earned when selling harvest
    var harvestValue: Int {
        switch self {
        case .lettuce: return 3
        case .carrot: return 5
        case .tomato: return 8
        case .cucumber: return 5
        case .bellPepperRed: return 12
        case .bellPepperYellow: return 12
        case .spinach: return 6
        case .avocado: return 20
        }
    }

    /// What nutrients this vegetable provides
    var nutrients: [NutrientType] {
        switch self {
        case .lettuce: return [.fiber, .vitaminK]
        case .carrot: return [.vitaminA, .fiber]
        case .tomato: return [.vitaminC, .antioxidants]
        case .cucumber: return [.hydration, .vitaminK]
        case .bellPepperRed: return [.vitaminC, .vitaminA]
        case .bellPepperYellow: return [.vitaminC, .vitaminB6]
        case .spinach: return [.iron, .vitaminK, .calcium]
        case .avocado: return [.healthyFats, .potassium, .fiber]
        }
    }
}

// MARK: - Nutrient Types

enum NutrientType: String {
    case vitaminA = "Vitamin A"
    case vitaminC = "Vitamin C"
    case vitaminK = "Vitamin K"
    case vitaminB6 = "Vitamin B6"
    case fiber = "Fiber"
    case iron = "Iron"
    case calcium = "Calcium"
    case potassium = "Potassium"
    case healthyFats = "Healthy Fats"
    case antioxidants = "Antioxidants"
    case hydration = "Hydration"

    /// Which Body Buddy organ this helps
    var benefitsOrgan: String {
        switch self {
        case .vitaminA: return "Eyes"
        case .vitaminC: return "Immune System"
        case .vitaminK: return "Blood"
        case .vitaminB6: return "Brain"
        case .fiber: return "Digestive System"
        case .iron: return "Blood"
        case .calcium: return "Bones"
        case .potassium: return "Heart"
        case .healthyFats: return "Brain"
        case .antioxidants: return "Immune System"
        case .hydration: return "Whole Body"
        }
    }
}

// MARK: - Harvested Ingredient

struct HarvestedIngredient: Identifiable, Equatable {
    let id = UUID()
    let type: VegetableType
    var quantity: Int
}

// MARK: - Garden Plot
//
// Each plot in your garden can hold one plant.
// Plants go through stages: empty -> planted -> growing -> ready
//

struct GardenPlot: Identifiable {
    let id: Int
    var state: PlotState = .empty
    var vegetable: VegetableType?
    var plantedDate: Date?

    /// Progress from 0.0 (just planted) to 1.0 (ready to harvest)
    var growthProgress: Double {
        guard let planted = plantedDate,
              let veg = vegetable,
              state == .growing || state == .ready else {
            return 0.0
        }

        let elapsed = Date().timeIntervalSince(planted)
        let progress = min(elapsed / veg.growthTime, 1.0)
        return progress
    }

    /// Check if plant is ready to harvest
    var isReadyToHarvest: Bool {
        growthProgress >= 1.0
    }

    /// Create the starter 2x2 grid of plots
    static func createStarterPlots() -> [GardenPlot] {
        return (0..<4).map { GardenPlot(id: $0) }
    }

    /// Plant a seed in this plot
    mutating func plant(_ type: VegetableType) {
        vegetable = type
        plantedDate = Date()
        state = .growing
    }

    /// Harvest the plant
    mutating func harvest() -> Int {
        guard let veg = vegetable, isReadyToHarvest else { return 0 }
        let yield = veg.harvestYield

        // Reset the plot
        vegetable = nil
        plantedDate = nil
        state = .empty

        return yield
    }
}

// MARK: - Plot State

enum PlotState: String {
    case empty       // Nothing planted
    case growing     // Plant is growing
    case ready       // Ready to harvest!
    case needsWater  // Needs watering (future feature)
}

// MARK: - Quest Model
//
// Daily quests give players goals and rewards!
//

struct Quest: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let targetCount: Int
    var currentCount: Int = 0
    let rewardCoins: Int
    let rewardXP: Int

    var isCompleted: Bool {
        currentCount >= targetCount
    }

    var progressPercent: Double {
        Double(currentCount) / Double(targetCount)
    }

    /// Generate random daily quests
    static func generateDailyQuests() -> [Quest] {
        return [
            Quest(
                title: "Green Thumb",
                description: "Plant 2 seeds in your garden",
                icon: "🌱",
                targetCount: 2,
                rewardCoins: 20,
                rewardXP: 15
            ),
            Quest(
                title: "Harvest Time",
                description: "Harvest 1 vegetable",
                icon: "🥕",
                targetCount: 1,
                rewardCoins: 15,
                rewardXP: 10
            ),
            Quest(
                title: "Junior Chef",
                description: "Complete 1 recipe",
                icon: "👨‍🍳",
                targetCount: 1,
                rewardCoins: 30,
                rewardXP: 25
            )
        ]
    }
}

// MARK: - Preview Helper

extension GameState {
    /// Create a GameState with sample data for previews
    static var preview: GameState {
        let state = GameState()
        state.coins = 250
        state.xp = 75
        state.playerLevel = 2
        state.harvestedIngredients = [
            HarvestedIngredient(type: .carrot, quantity: 5),
            HarvestedIngredient(type: .tomato, quantity: 3)
        ]
        return state
    }
}
