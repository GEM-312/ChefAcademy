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

// MARK: - PlayerData (@Model)

@Model
class PlayerData {

    // Currency
    var coins: Int
    var xp: Int
    var playerLevel: Int

    // Garden — stored as Codable arrays
    var seedsData: [SeedData]
    var harvestedData: [HarvestedData]
    var plotsData: [PlotData]

    // Pantry
    var pantryData: [PantryData]

    // Recipes
    var unlockedRecipeIDs: [String]
    var recipeStarsData: [String: Int]

    // Body Buddy (0-100 scale)
    var brainHealth: Int
    var muscleHealth: Int
    var boneHealth: Int
    var heartHealth: Int
    var immuneHealth: Int
    var energyLevel: Int

    // Achievements
    var completedBadgeIDs: [String]

    // Timestamp
    var lastSaved: Date

    init(
        coins: Int = 100,
        xp: Int = 0,
        playerLevel: Int = 1,
        seedsData: [SeedData] = [],
        harvestedData: [HarvestedData] = [],
        plotsData: [PlotData] = [],
        pantryData: [PantryData] = [],
        unlockedRecipeIDs: [String] = ["veggie-wrap", "garden-salad"],
        recipeStarsData: [String: Int] = [:],
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
        self.recipeStarsData = recipeStarsData
        self.brainHealth = brainHealth
        self.muscleHealth = muscleHealth
        self.boneHealth = boneHealth
        self.heartHealth = heartHealth
        self.immuneHealth = immuneHealth
        self.energyLevel = energyLevel
        self.completedBadgeIDs = completedBadgeIDs
        self.lastSaved = lastSaved
    }
}
