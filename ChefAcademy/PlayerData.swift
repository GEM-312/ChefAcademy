//
//  PlayerData.swift
//  ChefAcademy
//
//  SwiftData model for persisting player progress.
//  GameState reads/writes to this — views never touch it directly.
//

import Foundation
import SwiftData

// MARK: - Codable Helpers
// These use raw String values so SwiftData can store them as JSON.

struct SeedData: Codable {
    var vegetableRawValue: String
    var quantity: Int
}

struct HarvestedData: Codable {
    var vegetableRawValue: String
    var quantity: Int
}

struct PlotData: Codable {
    var id: Int
    var stateRaw: String          // PlotState.rawValue
    var vegetableRaw: String?     // VegetableType.rawValue (nil if empty)
    var plantedDate: Date?
    var pausedDate: Date?         // When watering/weeding/bugs paused growth

    // Plant care tracking (per growth cycle)
    var hasWatered: Bool = false
    var hasWeeded: Bool = false
    var hasDebugged: Bool = false
    var hasSung: Bool = false
    var weedTriggered: Bool = false
    var bugTriggered: Bool = false

    // Custom decoder so old saved data (without care fields) doesn't crash
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        stateRaw = try c.decode(String.self, forKey: .stateRaw)
        vegetableRaw = try c.decodeIfPresent(String.self, forKey: .vegetableRaw)
        plantedDate = try c.decodeIfPresent(Date.self, forKey: .plantedDate)
        pausedDate = try c.decodeIfPresent(Date.self, forKey: .pausedDate)
        hasWatered = try c.decodeIfPresent(Bool.self, forKey: .hasWatered) ?? false
        hasWeeded = try c.decodeIfPresent(Bool.self, forKey: .hasWeeded) ?? false
        hasDebugged = try c.decodeIfPresent(Bool.self, forKey: .hasDebugged) ?? false
        hasSung = try c.decodeIfPresent(Bool.self, forKey: .hasSung) ?? false
        weedTriggered = try c.decodeIfPresent(Bool.self, forKey: .weedTriggered) ?? false
        bugTriggered = try c.decodeIfPresent(Bool.self, forKey: .bugTriggered) ?? false
    }

    // Regular init for creating new PlotData in code
    init(id: Int, stateRaw: String, vegetableRaw: String? = nil, plantedDate: Date? = nil, pausedDate: Date? = nil,
         hasWatered: Bool = false, hasWeeded: Bool = false, hasDebugged: Bool = false,
         hasSung: Bool = false, weedTriggered: Bool = false, bugTriggered: Bool = false) {
        self.id = id
        self.stateRaw = stateRaw
        self.vegetableRaw = vegetableRaw
        self.plantedDate = plantedDate
        self.pausedDate = pausedDate
        self.hasWatered = hasWatered
        self.hasWeeded = hasWeeded
        self.hasDebugged = hasDebugged
        self.hasSung = hasSung
        self.weedTriggered = weedTriggered
        self.bugTriggered = bugTriggered
    }
}

struct PantryData: Codable {
    var itemRawValue: String      // PantryItem.rawValue
    var quantity: Int
}

// MARK: - Sibling Help Tracking

struct HelpEntry: Codable {
    var helperName: String
    var helperProfileID: String   // UUID string
    var actionRaw: String         // "water", "weed", "debug"
    var vegetableRaw: String      // VegetableType.rawValue
    var timestamp: Date
}

struct RecipeStarData: Codable {
    var recipeID: String
    var stars: Int
}

// MARK: - PlayerData (@Model)
// CloudKit requires ALL properties to have default values at declaration.

@Model
class PlayerData {

    // Currency
    var coins: Int = 0
    var xp: Int = 0
    var playerLevel: Int = 1

    // Garden — stored as Codable arrays
    var seedsData: [SeedData] = []
    var harvestedData: [HarvestedData] = []
    var plotsData: [PlotData] = []

    // Pantry
    var pantryData: [PantryData] = []

    // Recipes
    var unlockedRecipeIDs: [String] = ["veggie-wrap", "garden-salad"]
    var recipeStars: [RecipeStarData] = []

    // Body Buddy (0-100 scale)
    var brainHealth: Int = 50
    var muscleHealth: Int = 50
    var boneHealth: Int = 50
    var heartHealth: Int = 50
    var immuneHealth: Int = 50
    var energyLevel: Int = 50
    var eyeHealth: Int = 50
    var skinHealth: Int = 50
    var digestiveHealth: Int = 50

    // Social
    var gardenLikes: Int = 0

    // Knowledge rewards — tracks which knowledge cards have been claimed (one-time)
    // Format: "seed_carrot_vitaminA", "seed_carrot_color", "pantry_eggs_protein", etc.
    var claimedKnowledgeIDs: [String] = []

    // Achievements
    var completedBadgeIDs: [String] = []

    // Sibling Help — given (as visitor)
    var helpGivenCount: Int = 0
    var helpStreak: Int = 0
    var lastHelpDateRaw: Double = 0   // timeIntervalSince1970, 0 = never
    var giftsGivenCount: Int = 0

    // Sibling Help — received (as garden owner)
    var receivedHelp: [HelpEntry] = []
    var lastSeenHelpCount: Int = 0    // tracks which help entries owner has dismissed

    // Timestamp
    var lastSaved: Date = Date()

    // Multi-user ownership (linked by UUID, not @Relationship)
    var ownerID: UUID? = nil

    init(
        coins: Int = 0,
        xp: Int = 0,
        playerLevel: Int = 1,
        seedsData: [SeedData] = [],
        harvestedData: [HarvestedData] = [],
        plotsData: [PlotData] = [],
        pantryData: [PantryData] = [],
        unlockedRecipeIDs: [String] = ["veggie-wrap", "garden-salad"],
        recipeStars: [RecipeStarData] = [],
        brainHealth: Int = 50,
        muscleHealth: Int = 50,
        boneHealth: Int = 50,
        heartHealth: Int = 50,
        immuneHealth: Int = 50,
        energyLevel: Int = 50,
        gardenLikes: Int = 0,
        completedBadgeIDs: [String] = [],
        lastSaved: Date = Date()
    ) {
        self.coins = coins
        self.xp = xp
        self.playerLevel = playerLevel
        self.seedsData = seedsData
        self.harvestedData = harvestedData
        self.plotsData = plotsData
        self.pantryData = pantryData
        self.unlockedRecipeIDs = unlockedRecipeIDs
        self.recipeStars = recipeStars
        self.brainHealth = brainHealth
        self.muscleHealth = muscleHealth
        self.boneHealth = boneHealth
        self.heartHealth = heartHealth
        self.immuneHealth = immuneHealth
        self.energyLevel = energyLevel
        self.gardenLikes = gardenLikes
        self.completedBadgeIDs = completedBadgeIDs
        self.lastSaved = lastSaved
    }

    // MARK: - Recipe Stars Helpers

    func stars(for recipeID: String) -> Int {
        recipeStars.first { $0.recipeID == recipeID }?.stars ?? 0
    }

    func setStars(_ stars: Int, for recipeID: String) {
        if let index = recipeStars.firstIndex(where: { $0.recipeID == recipeID }) {
            recipeStars[index].stars = stars
        } else {
            recipeStars.append(RecipeStarData(recipeID: recipeID, stars: stars))
        }
    }
}
