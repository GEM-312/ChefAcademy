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
    // User's name - persisted to UserDefaults
    @Published var name: String {
        didSet {
            UserDefaults.standard.set(name, forKey: "userName")
        }
    }

    @Published var gender: Gender = .girl {
        didSet {
            UserDefaults.standard.set(gender.rawValue, forKey: "userGender")
        }
    }

    @Published var hairStyle: HairStyle = .medium
    @Published var outfit: Outfit = .apronRed
    @Published var headCovering: HeadCovering = .none {
        didSet {
            UserDefaults.standard.set(headCovering.rawValue, forKey: "userHeadCovering")
        }
    }

    // Dietary preference derived from head covering
    var dietaryPreference: DietaryPreference {
        headCovering.dietaryPreference
    }

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

    // Initialize with saved values from UserDefaults
    init() {
        self.name = UserDefaults.standard.string(forKey: "userName") ?? ""
        if let genderRaw = UserDefaults.standard.string(forKey: "userGender"),
           let saved = Gender(rawValue: genderRaw) {
            self.gender = saved
        }
        if let coveringRaw = UserDefaults.standard.string(forKey: "userHeadCovering"),
           let saved = HeadCovering(rawValue: coveringRaw) {
            self.headCovering = saved
        }
    }
}

// MARK: - Gender

enum Gender: String, CaseIterable, Identifiable {
    case boy = "Boy"
    case girl = "Girl"

    var id: String { rawValue }
}

// MARK: - Head Covering

enum HeadCovering: String, CaseIterable, Identifiable {
    case none = "None"
    case hijab = "Hijab"
    case kippah = "Kippah"
    case turban = "Turban"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .none: return "person.fill"
        case .hijab: return "person.fill"
        case .kippah: return "person.fill"
        case .turban: return "person.fill"
        }
    }

    var dietaryPreference: DietaryPreference {
        switch self {
        case .none: return .none
        case .hijab: return .halal
        case .kippah: return .kosher
        case .turban: return .none
        }
    }
}

// MARK: - Dietary Preference

enum DietaryPreference: String, CaseIterable, Identifiable {
    case none = "None"
    case halal = "Halal"
    case kosher = "Kosher"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No restrictions"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        }
    }
}

// MARK: - Hair Style

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

// MARK: - Outfit

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
