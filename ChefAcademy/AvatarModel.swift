//
//  AvatarModel.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

import SwiftUI
import Combine

// MARK: - Avatar Model
class AvatarModel: ObservableObject {
    @Published var name: String = ""
    @Published var skinTone: SkinTone = .medium
    @Published var hairStyle: HairStyle = .short
    @Published var hairColor: HairColor = .brown
    @Published var outfit: Outfit = .apronRed
    
    // Stats (will be affected by nutrition later)
    @Published var energyLevel: Double = 100
    @Published var happinessLevel: Double = 100
    
    // Nutrition status for body parts
    @Published var eyesHealth: Double = 50      // Vitamin A
    @Published var muscleHealth: Double = 50    // Protein
    @Published var boneHealth: Double = 50      // Calcium
    @Published var brainHealth: Double = 50     // Omega-3
    @Published var energyHealth: Double = 50    // Carbs
    
    // Streaks & Progress
    @Published var currentStreak: Int = 0
    @Published var totalDaysVisited: Int = 0
    @Published var recipesCompleted: Int = 0
    @Published var badges: [Badge] = []
}

// MARK: - Customization Options

enum SkinTone: String, CaseIterable, Identifiable {
    case light = "Light"
    case lightMedium = "Light Medium"
    case medium = "Medium"
    case mediumDark = "Medium Dark"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .light: return Color(hex: "FFE0BD")
        case .lightMedium: return Color(hex: "F1C27D")
        case .medium: return Color(hex: "E0AC69")
        case .mediumDark: return Color(hex: "C68642")
        case .dark: return Color(hex: "8D5524")
        }
    }
}

enum HairStyle: String, CaseIterable, Identifiable {
    case short = "Short"
    case medium = "Medium"
    case long = "Long"
    case curly = "Curly"
    case braids = "Braids"
    case bun = "Bun"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .short: return "person.fill"
        case .medium: return "person.fill"
        case .long: return "person.fill"
        case .curly: return "person.fill"
        case .braids: return "person.fill"
        case .bun: return "person.fill"
        }
    }
}

enum HairColor: String, CaseIterable, Identifiable {
    case black = "Black"
    case brown = "Brown"
    case blonde = "Blonde"
    case red = "Red"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .black: return Color(hex: "2C2C2C")
        case .brown: return Color(hex: "6B4423")
        case .blonde: return Color(hex: "D4A853")
        case .red: return Color(hex: "A52A2A")
        case .blue: return Color(hex: "4A90D9")
        case .purple: return Color(hex: "8B5CF6")
        case .pink: return Color(hex: "EC4899")
        }
    }
}

enum Outfit: String, CaseIterable, Identifiable {
    case apronRed = "Red Apron"
    case apronBlue = "Blue Apron"
    case apronGreen = "Green Apron"
    case apronYellow = "Yellow Apron"
    case chefWhite = "Chef Coat"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .apronRed: return Color(hex: "E53E3E")
        case .apronBlue: return Color(hex: "3182CE")
        case .apronGreen: return Color(hex: "38A169")
        case .apronYellow: return Color.AppTheme.goldenWheat
        case .chefWhite: return Color(hex: "F7FAFC")
        }
    }
}

// MARK: - Badge Model
struct Badge: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let iconName: String
    let category: BadgeCategory
    var isEarned: Bool = false
    var earnedDate: Date?
    
    enum BadgeCategory: String {
        case streak = "Streak"
        case nutrition = "Nutrition"
        case cooking = "Cooking"
        case learning = "Learning"
    }
}

// MARK: - Predefined Badges
extension Badge {
    static let allBadges: [Badge] = [
        // Streak Badges
        Badge(name: "Sprout Chef", description: "Visit Pip for 3 days", iconName: "leaf.fill", category: .streak),
        Badge(name: "Veggie Visitor", description: "Visit Pip for 7 days", iconName: "carrot.fill", category: .streak),
        Badge(name: "Kitchen Regular", description: "Visit Pip for 14 days", iconName: "flame.fill", category: .streak),
        Badge(name: "Pip's Best Friend", description: "Visit Pip for 30 days", iconName: "star.fill", category: .streak),
        
        // Nutrition Badges
        Badge(name: "Eye Spy", description: "Learn about Vitamin A", iconName: "eye.fill", category: .nutrition),
        Badge(name: "Muscle Builder", description: "Learn about Protein", iconName: "figure.strengthtraining.traditional", category: .nutrition),
        Badge(name: "Bone Boss", description: "Learn about Calcium", iconName: "figure.stand", category: .nutrition),
        Badge(name: "Brain Booster", description: "Learn about Omega-3", iconName: "brain.head.profile", category: .nutrition),
        Badge(name: "Energy Expert", description: "Learn about Carbohydrates", iconName: "bolt.fill", category: .nutrition),
        
        // Cooking Badges
        Badge(name: "First Flip", description: "Complete your first recipe", iconName: "frying.pan.fill", category: .cooking),
        Badge(name: "Salad Star", description: "Make 3 salads", iconName: "leaf.circle.fill", category: .cooking),
        Badge(name: "Breakfast Champ", description: "Make 5 breakfasts", iconName: "sun.max.fill", category: .cooking),
        Badge(name: "Junior Chef", description: "Complete 10 recipes", iconName: "fork.knife", category: .cooking),
        Badge(name: "Rainbow Eater", description: "Eat all colors of veggies", iconName: "rainbow", category: .cooking),
    ]
}
