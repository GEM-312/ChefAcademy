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
import SwiftData
import Combine

// MARK: - GameState (The Central Manager)
//
// Think of this class like a notebook that remembers EVERYTHING about your game.
// The "@Published" keyword means: "When this value changes, update the screen!"
// "ObservableObject" lets SwiftUI watch for changes and react automatically.
//

class GameState: ObservableObject {

    // ============================================
    // SWIFTDATA PERSISTENCE
    // ============================================

    /// ModelContext for reading/writing PlayerData. Nil in previews.
    var modelContext: ModelContext?

    /// Auto-save subscription — saves whenever any @Published property changes
    private var autoSaveCancellable: AnyCancellable?

    /// Set up auto-save: debounce 0.5s so rapid changes batch into one write
    func startAutoSave() {
        autoSaveCancellable = objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveToStore()
            }
    }

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
    /// Starts empty — player buys items from the Farm Shop!
    @Published var pantryInventory: [PantryStock] = []

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
        saveToStore()
    }

    /// Spend coins (returns false if not enough)
    func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        withAnimation(.spring()) {
            coins -= amount
        }
        saveToStore()
        return true
    }

    /// Add XP and check for level up
    func addXP(_ amount: Int) {
        xp += amount
        checkLevelUp()
        saveToStore()
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
        saveToStore()
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
        saveToStore()
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
        // saveToStore() already called by addXP and spendCoins
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
        saveToStore()
        return true
    }

    /// Get quantity of a pantry item
    func pantryQuantity(for item: PantryItem) -> Int {
        pantryInventory.first(where: { $0.item == item })?.quantity ?? 0
    }

    // ============================================
    // COOKING COMPLETION
    // ============================================

    /// Complete a cooking session — award stars, coins, and XP
    func completeCooking(recipeID: String, stars: Int, coins: Int, xp: Int) {
        addCoins(coins)
        addXP(xp)
        recipeStars[recipeID] = max(recipeStars[recipeID] ?? 0, stars)
        saveToStore()
    }

    // ============================================
    // SWIFTDATA SAVE / LOAD
    // ============================================

    /// Load player progress from SwiftData (called once on app launch)
    func loadFromStore() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<PlayerData>()
        guard let saved = try? context.fetch(descriptor).first else { return }

        // Currency
        coins = saved.coins
        xp = saved.xp
        playerLevel = saved.playerLevel

        // Seeds
        seeds = saved.seedsData.compactMap { data in
            guard let veg = VegetableType(rawValue: data.vegetableRawValue) else { return nil }
            return Seed(vegetableType: veg, quantity: data.quantity)
        }

        // Harvested
        harvestedIngredients = saved.harvestedData.compactMap { data in
            guard let veg = VegetableType(rawValue: data.vegetableRawValue) else { return nil }
            return HarvestedIngredient(type: veg, quantity: data.quantity)
        }

        // Plots
        gardenPlots = saved.plotsData.map { data in
            var plot = GardenPlot(id: data.id)
            plot.state = PlotState(rawValue: data.stateRaw) ?? .empty
            if let vegRaw = data.vegetableRaw {
                plot.vegetable = VegetableType(rawValue: vegRaw)
            }
            plot.plantedDate = data.plantedDate
            return plot
        }
        // If saved plots is empty (first launch after migration), keep starter plots
        if gardenPlots.isEmpty {
            gardenPlots = GardenPlot.createStarterPlots()
        }

        // Pantry
        pantryInventory = saved.pantryData.compactMap { data in
            guard let item = PantryItem(rawValue: data.itemRawValue) else { return nil }
            return PantryStock(item: item, quantity: data.quantity)
        }

        // Recipes
        unlockedRecipeIDs = Set(saved.unlockedRecipeIDs)
        recipeStars = saved.recipeStarsData

        // Body Buddy
        brainHealth = saved.brainHealth
        muscleHealth = saved.muscleHealth
        boneHealth = saved.boneHealth
        heartHealth = saved.heartHealth
        immuneHealth = saved.immuneHealth
        energyLevel = saved.energyLevel

        // Achievements
        completedBadgeIDs = Set(saved.completedBadgeIDs)
    }

    /// Persist current state to SwiftData
    func saveToStore() {
        guard let context = modelContext else { return }

        // Fetch existing or create new
        let descriptor = FetchDescriptor<PlayerData>()
        let existing = try? context.fetch(descriptor).first
        let saved: PlayerData
        if let existing {
            saved = existing
        } else {
            saved = PlayerData()
            context.insert(saved)
        }

        // Currency
        saved.coins = coins
        saved.xp = xp
        saved.playerLevel = playerLevel

        // Seeds
        saved.seedsData = seeds.map {
            SeedData(vegetableRawValue: $0.vegetableType.rawValue, quantity: $0.quantity)
        }

        // Harvested
        saved.harvestedData = harvestedIngredients.map {
            HarvestedData(vegetableRawValue: $0.type.rawValue, quantity: $0.quantity)
        }

        // Plots
        saved.plotsData = gardenPlots.map { plot in
            PlotData(
                id: plot.id,
                stateRaw: plot.state.rawValue,
                vegetableRaw: plot.vegetable?.rawValue,
                plantedDate: plot.plantedDate
            )
        }

        // Pantry
        saved.pantryData = pantryInventory.map {
            PantryData(itemRawValue: $0.item.rawValue, quantity: $0.quantity)
        }

        // Recipes
        saved.unlockedRecipeIDs = Array(unlockedRecipeIDs)
        saved.recipeStarsData = recipeStars

        // Body Buddy
        saved.brainHealth = brainHealth
        saved.muscleHealth = muscleHealth
        saved.boneHealth = boneHealth
        saved.heartHealth = heartHealth
        saved.immuneHealth = immuneHealth
        saved.energyLevel = energyLevel

        // Achievements
        saved.completedBadgeIDs = Array(completedBadgeIDs)

        saved.lastSaved = Date()

        try? context.save()
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
    case spinach
    case bellPepperRed
    case bellPepperYellow
    case sweetPotato
    case corn
    case beet
    case eggplant
    case radish
    // Greens & Herbs
    case kale
    case basil
    case mint
    case greenBeans
    // Fruits
    case strawberry
    case watermelon
    case avocado
    case lemon
    // Berries
    case blueberry
    case raspberry
    case blackberry

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
        case .spinach: return "Spinach"
        case .bellPepperRed: return "Red Pepper"
        case .bellPepperYellow: return "Yellow Pepper"
        case .sweetPotato: return "Sweet Potato"
        case .corn: return "Corn"
        case .beet: return "Beet"
        case .eggplant: return "Eggplant"
        case .radish: return "Radish"
        case .kale: return "Kale"
        case .basil: return "Basil"
        case .mint: return "Mint"
        case .greenBeans: return "Green Beans"
        case .strawberry: return "Strawberry"
        case .watermelon: return "Watermelon"
        case .avocado: return "Avocado"
        case .lemon: return "Lemon"
        case .blueberry: return "Blueberry"
        case .raspberry: return "Raspberry"
        case .blackberry: return "Blackberry"
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
        case .spinach: return "spinach_veggie"
        case .bellPepperRed: return "bellpepper_red_veggie"
        case .bellPepperYellow: return "bellpepper_yellow_veggie"
        case .sweetPotato: return "sweetpotato_veggie"
        case .corn: return "corn_veggie"
        case .beet: return "beet_veggie"
        case .eggplant: return "eggplant_veggie"
        case .radish: return "radish_veggie"
        case .kale: return "kale_veggie"
        case .basil: return "basil_veggie"
        case .mint: return "mint_veggie"
        case .greenBeans: return "greenbeans_veggie"
        case .strawberry: return "strawberry_veggie"
        case .watermelon: return "watermelon_veggie"
        case .avocado: return "avocado_veggie"
        case .lemon: return "lemon_veggie"
        case .blueberry: return "blueberry_veggie"
        case .raspberry: return "raspberry_veggie"
        case .blackberry: return "blackberry_veggie"
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
        case .spinach: return "🥬"
        case .bellPepperRed: return "🫑"
        case .bellPepperYellow: return "🫑"
        case .sweetPotato: return "🍠"
        case .corn: return "🌽"
        case .beet: return "🟣"
        case .eggplant: return "🍆"
        case .radish: return "🔴"
        case .kale: return "🥬"
        case .basil: return "🌿"
        case .mint: return "🌿"
        case .greenBeans: return "🫛"
        case .strawberry: return "🍓"
        case .watermelon: return "🍉"
        case .avocado: return "🥑"
        case .lemon: return "🍋"
        case .blueberry: return "🫐"
        case .raspberry: return "🫐"
        case .blackberry: return "🫐"
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
        case .spinach: return 45       // 45 seconds
        case .bellPepperRed: return 100 // 1 min 40 sec
        case .bellPepperYellow: return 100
        case .sweetPotato: return 150  // 2.5 minutes
        case .corn: return 120         // 2 minutes
        case .beet: return 110         // ~2 minutes
        case .eggplant: return 130     // ~2 minutes
        case .radish: return 25        // 25 seconds (fastest!)
        case .kale: return 55          // ~1 minute
        case .basil: return 35         // 35 seconds
        case .mint: return 40          // 40 seconds
        case .greenBeans: return 70    // ~1 minute
        case .strawberry: return 90    // 1.5 minutes
        case .watermelon: return 200   // 3+ minutes (big fruit!)
        case .avocado: return 160      // ~2.5 minutes
        case .lemon: return 140        // ~2.5 minutes
        case .blueberry: return 80     // ~1.5 minutes
        case .raspberry: return 75     // ~1.25 minutes
        case .blackberry: return 85    // ~1.5 minutes
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
        case .spinach: return 3
        case .bellPepperRed: return 2
        case .bellPepperYellow: return 2
        case .sweetPotato: return 2
        case .corn: return 3
        case .beet: return 2
        case .eggplant: return 2
        case .radish: return 4
        case .kale: return 3
        case .basil: return 4
        case .mint: return 4
        case .greenBeans: return 5
        case .strawberry: return 6
        case .watermelon: return 1
        case .avocado: return 1
        case .lemon: return 2
        case .blueberry: return 8
        case .raspberry: return 6
        case .blackberry: return 6
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
        case .spinach: return 8
        case .bellPepperRed: return 18
        case .bellPepperYellow: return 18
        case .sweetPotato: return 22
        case .corn: return 12
        case .beet: return 15
        case .eggplant: return 20
        case .radish: return 5
        case .kale: return 10
        case .basil: return 8
        case .mint: return 8
        case .greenBeans: return 10
        case .strawberry: return 15
        case .watermelon: return 25
        case .avocado: return 28
        case .lemon: return 18
        case .blueberry: return 12
        case .raspberry: return 12
        case .blackberry: return 12
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
        case .spinach: return 5
        case .bellPepperRed: return 10
        case .bellPepperYellow: return 10
        case .sweetPotato: return 14
        case .corn: return 6
        case .beet: return 9
        case .eggplant: return 11
        case .radish: return 3
        case .kale: return 6
        case .basil: return 4
        case .mint: return 4
        case .greenBeans: return 5
        case .strawberry: return 8
        case .watermelon: return 15
        case .avocado: return 18
        case .lemon: return 10
        case .blueberry: return 7
        case .raspberry: return 7
        case .blackberry: return 7
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
        case .spinach: return [.iron, .vitaminK, .vitaminA]
        case .bellPepperRed: return [.vitaminC, .vitaminA]
        case .bellPepperYellow: return [.vitaminC, .vitaminB6]
        case .sweetPotato: return [.vitaminA, .fiber, .potassium]
        case .corn: return [.fiber, .vitaminB6]
        case .beet: return [.antioxidants, .iron, .fiber]
        case .eggplant: return [.fiber, .antioxidants]
        case .radish: return [.vitaminC, .fiber]
        case .kale: return [.vitaminK, .iron, .vitaminC]
        case .basil: return [.vitaminK, .antioxidants]
        case .mint: return [.vitaminA, .antioxidants]
        case .greenBeans: return [.fiber, .vitaminC, .vitaminK]
        case .strawberry: return [.vitaminC, .antioxidants]
        case .watermelon: return [.hydration, .vitaminC]
        case .avocado: return [.healthyFats, .potassium, .fiber]
        case .lemon: return [.vitaminC, .antioxidants]
        case .blueberry: return [.antioxidants, .vitaminK]
        case .raspberry: return [.fiber, .vitaminC]
        case .blackberry: return [.antioxidants, .vitaminK, .fiber]
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

    /// Create the starter garden plots (5 plots)
    static func createStarterPlots() -> [GardenPlot] {
        return (0..<5).map { GardenPlot(id: $0) }
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
