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
    // FARM SHOP — Pantry Inventory
    // ============================================

    /// Items bought from the farm shop (eggs, chicken, butter, etc.)
    @Published var pantryInventory: [PantryStock] = PantryStock.starterPantry

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

    // ============================================
    // PANTRY HELPERS
    // ============================================

    /// Buy a pantry item from the farm shop
    func buyPantryItem(_ item: PantryItem, quantity: Int = 1) -> Bool {
        let totalCost = item.shopPrice * quantity
        guard spendCoins(totalCost) else { return false }

        if let index = pantryInventory.firstIndex(where: { $0.item == item }) {
            pantryInventory[index].quantity += quantity
        } else {
            pantryInventory.append(PantryStock(item: item, quantity: quantity))
        }

        // Award XP for shopping!
        addXP(3 * quantity)
        return true
    }

    /// Check if player has a pantry item in stock
    func hasPantryItem(_ item: PantryItem, quantity: Int = 1) -> Bool {
        guard let stock = pantryInventory.first(where: { $0.item == item }) else {
            return false
        }
        return stock.quantity >= quantity
    }

    /// Use a pantry item (for cooking)
    func usePantryItem(_ item: PantryItem, quantity: Int = 1) -> Bool {
        guard let index = pantryInventory.firstIndex(where: { $0.item == item }),
              pantryInventory[index].quantity >= quantity else {
            return false
        }
        pantryInventory[index].quantity -= quantity
        if pantryInventory[index].quantity <= 0 {
            pantryInventory.remove(at: index)
        }
        return true
    }

    /// Get quantity of a pantry item
    func pantryQuantity(for item: PantryItem) -> Int {
        pantryInventory.first(where: { $0.item == item })?.quantity ?? 0
    }
}

// MARK: - Pantry Stock
/// Tracks how many of each pantry item the player owns

struct PantryStock: Identifiable, Equatable {
    var id: String { item.rawValue }
    let item: PantryItem
    var quantity: Int

    static func == (lhs: PantryStock, rhs: PantryStock) -> Bool {
        lhs.item == rhs.item && lhs.quantity == rhs.quantity
    }

    /// New players start with some basic pantry items!
    static let starterPantry: [PantryStock] = [
        PantryStock(item: .salt, quantity: 10),
        PantryStock(item: .pepper, quantity: 10),
        PantryStock(item: .butter, quantity: 3),
        PantryStock(item: .eggs, quantity: 6),
        PantryStock(item: .oliveOil, quantity: 2),
    ]
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
        Seed(vegetableType: .tomato, quantity: 3),
        Seed(vegetableType: .cucumber, quantity: 2),
        Seed(vegetableType: .broccoli, quantity: 2),
        Seed(vegetableType: .zucchini, quantity: 2),
        Seed(vegetableType: .onion, quantity: 2),
        Seed(vegetableType: .pumpkin, quantity: 1)
    ]
}

// MARK: - VegetableType Enum
//
// All the vegetables you can grow in your garden!
// Each one has different growth times, costs, and nutrients.
// Now uses custom illustration assets instead of emojis.
//

enum VegetableType: String, CaseIterable, Identifiable {
    case lettuce
    case carrot
    case tomato
    case cucumber
    case broccoli
    case zucchini
    case onion
    case pumpkin

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .lettuce: return "Lettuce"
        case .carrot: return "Carrot"
        case .tomato: return "Tomato"
        case .cucumber: return "Cucumber"
        case .broccoli: return "Broccoli"
        case .zucchini: return "Zucchini"
        case .onion: return "Onion"
        case .pumpkin: return "Pumpkin"
        }
    }

    /// Asset image name (matches Assets.xcassets/Vegetables/)
    var imageName: String {
        switch self {
        case .lettuce: return "lettuce_veggie"
        case .carrot: return "carrot_veggie"
        case .tomato: return "tomato_veggie"
        case .cucumber: return "cucumber_veggie"
        case .broccoli: return "broccoli_veggie"
        case .zucchini: return "zuccini_veggie"
        case .onion: return "onion_veggie"
        case .pumpkin: return "pumpkin_veggie"
        }
    }

    /// Emoji fallback for quick display
    var emoji: String {
        switch self {
        case .lettuce: return "🥬"
        case .carrot: return "🥕"
        case .tomato: return "🍅"
        case .cucumber: return "🥒"
        case .broccoli: return "🥦"
        case .zucchini: return "🥒"
        case .onion: return "🧅"
        case .pumpkin: return "🎃"
        }
    }

    /// How long to grow (in seconds) - short for testing!
    var growthTime: TimeInterval {
        switch self {
        case .lettuce: return 30       // 30 seconds (fast for testing)
        case .carrot: return 60        // 1 minute
        case .tomato: return 90        // 1.5 minutes
        case .cucumber: return 60      // 1 minute
        case .broccoli: return 120     // 2 minutes
        case .zucchini: return 75      // 1.25 minutes
        case .onion: return 90         // 1.5 minutes
        case .pumpkin: return 180      // 3 minutes (slowest)
        }
    }

    /// How many vegetables you get when harvesting
    var harvestYield: Int {
        switch self {
        case .lettuce: return 2
        case .carrot: return 3
        case .tomato: return 4
        case .cucumber: return 2
        case .broccoli: return 2
        case .zucchini: return 3
        case .onion: return 3
        case .pumpkin: return 1
        }
    }

    /// Cost to buy seeds
    var seedCost: Int {
        switch self {
        case .lettuce: return 5
        case .carrot: return 10
        case .tomato: return 15
        case .cucumber: return 10
        case .broccoli: return 20
        case .zucchini: return 12
        case .onion: return 8
        case .pumpkin: return 30
        }
    }

    /// Coins earned when selling harvest
    var harvestValue: Int {
        switch self {
        case .lettuce: return 3
        case .carrot: return 5
        case .tomato: return 8
        case .cucumber: return 5
        case .broccoli: return 12
        case .zucchini: return 7
        case .onion: return 4
        case .pumpkin: return 20
        }
    }

    /// What nutrients this vegetable provides
    var nutrients: [NutrientType] {
        switch self {
        case .lettuce: return [.fiber, .vitaminK]
        case .carrot: return [.vitaminA, .fiber]
        case .tomato: return [.vitaminC, .antioxidants]
        case .cucumber: return [.hydration, .vitaminK]
        case .broccoli: return [.vitaminC, .vitaminK, .fiber]
        case .zucchini: return [.vitaminB6, .potassium]
        case .onion: return [.vitaminC, .antioxidants]
        case .pumpkin: return [.vitaminA, .fiber, .potassium]
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
        state.pantryInventory = [
            PantryStock(item: .salt, quantity: 10),
            PantryStock(item: .pepper, quantity: 10),
            PantryStock(item: .butter, quantity: 3),
            PantryStock(item: .eggs, quantity: 6),
            PantryStock(item: .oliveOil, quantity: 2),
            PantryStock(item: .cheese, quantity: 2),
        ]
        return state
    }
}
