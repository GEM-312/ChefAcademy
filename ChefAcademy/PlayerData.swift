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
}

struct PantryData: Codable {
    var itemRawValue: String      // PantryItem.rawValue
    var quantity: Int
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
    var coins: Int = 100
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

    // Achievements
    var completedBadgeIDs: [String] = []

    // Timestamp
    var lastSaved: Date = Date()

    // Multi-user ownership (linked by UUID, not @Relationship)
    var ownerID: UUID? = nil

    init(
        coins: Int = 100,
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
