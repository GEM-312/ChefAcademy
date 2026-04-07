//
//  Allergen.swift
//  ChefAcademy
//
//  FDA top 9 food allergens — used to warn kids before cooking.
//  Stored as raw strings on UserProfile for CloudKit compatibility.
//

import SwiftUI

// MARK: - Food Allergen

enum FoodAllergen: String, CaseIterable, Codable, Identifiable {
    case milk
    case eggs
    case peanuts
    case treeNuts
    case wheat
    case soy
    case fish
    case shellfish
    case sesame

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .milk:      return "Milk & Dairy"
        case .eggs:      return "Eggs"
        case .peanuts:   return "Peanuts"
        case .treeNuts:  return "Tree Nuts"
        case .wheat:     return "Wheat & Gluten"
        case .soy:       return "Soy"
        case .fish:      return "Fish"
        case .shellfish: return "Shellfish"
        case .sesame:    return "Sesame"
        }
    }

    var emoji: String {
        switch self {
        case .milk:      return "\u{1F95B}" // milk glass
        case .eggs:      return "\u{1F95A}" // egg
        case .peanuts:   return "\u{1F95C}" // peanuts
        case .treeNuts:  return "\u{1F330}" // chestnut
        case .wheat:     return "\u{1F33E}" // wheat sheaf
        case .soy:       return "\u{1FAD8}" // beans
        case .fish:      return "\u{1F41F}" // fish
        case .shellfish: return "\u{1F990}" // shrimp
        case .sesame:    return "\u{1FAD8}" // beans (closest)
        }
    }

    var icon: String {
        switch self {
        case .milk:      return "drop.fill"
        case .eggs:      return "oval.fill"
        case .peanuts:   return "leaf.fill"
        case .treeNuts:  return "tree.fill"
        case .wheat:     return "leaf.arrow.circlepath"
        case .soy:       return "cup.and.saucer.fill"
        case .fish:      return "fish.fill"
        case .shellfish: return "tortoise.fill"
        case .sesame:    return "circle.grid.3x3.fill"
        }
    }

    var kidExplanation: String {
        switch self {
        case .milk:      return "This has milk or things made from milk, like cheese and butter"
        case .eggs:      return "This has eggs in it"
        case .peanuts:   return "This has peanuts in it"
        case .treeNuts:  return "This has tree nuts like almonds, walnuts, or cashews"
        case .wheat:     return "This has wheat or flour in it"
        case .soy:       return "This has soy, like soy sauce"
        case .fish:      return "This has fish in it"
        case .shellfish: return "This has shellfish like shrimp or crab"
        case .sesame:    return "This has sesame seeds in it"
        }
    }
}
