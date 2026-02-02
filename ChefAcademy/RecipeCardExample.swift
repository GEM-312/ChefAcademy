import SwiftUI

// MARK: - Recipe Category
enum RecipeCategory: String, CaseIterable {
    case all = "All"
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snacks = "Snacks"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .breakfast: return "sun.max"
        case .lunch: return "takeoutbag.and.cup.and.straw"
        case .dinner: return "moon.stars"
        case .snacks: return "carrot"
        }
    }
}

// MARK: - Recipe Model
struct Recipe: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let imageYOffset: CGFloat // Adjust image vertical position (negative = up)
    let category: RecipeCategory // Recipe category for filtering
    let cookTime: Int // in minutes
    let difficulty: DifficultyBadge.Level
    let servings: Int
    let needsAdultHelp: Bool
    let nutritionFacts: [String]

    // Default initializer with offset = 0
    init(title: String, description: String, imageName: String, imageYOffset: CGFloat = 0, category: RecipeCategory = .lunch, cookTime: Int, difficulty: DifficultyBadge.Level, servings: Int, needsAdultHelp: Bool, nutritionFacts: [String]) {
        self.title = title
        self.description = description
        self.imageName = imageName
        self.imageYOffset = imageYOffset
        self.category = category
        self.cookTime = cookTime
        self.difficulty = difficulty
        self.servings = servings
        self.needsAdultHelp = needsAdultHelp
        self.nutritionFacts = nutritionFacts
    }
}

// MARK: - Recipe Card View
struct RecipeCardView: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Area - Recipe illustration
            ZStack(alignment: .topTrailing) {
                // Recipe image from Assets
                Image(recipe.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .offset(y: recipe.imageYOffset)  // Adjust image position
                    .clipped()
                
                // Adult help indicator
                if recipe.needsAdultHelp {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("Adult Help")
                    }
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.cream)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.AppTheme.terracotta)
                    .cornerRadius(8)
                    .padding(8)
                }
            }
            
            // Content Area
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Title
                Text(recipe.title)
                    .font(.AppTheme.title3)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(2)
                
                // Description
                Text(recipe.description)
                    .font(.AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.sepia)
                    .lineLimit(2)
                
                // Divider
                Rectangle()
                    .fill(Color.AppTheme.sepia.opacity(0.2))
                    .frame(height: 1)
                
                // Bottom Row: Difficulty, Time, Servings
                HStack {
                    DifficultyBadge(level: recipe.difficulty)
                    
                    Spacer()
                    
                    // Cook Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("\(recipe.cookTime) min")
                    }
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.lightSepia)
                    
                    // Servings
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                        Text("\(recipe.servings)")
                    }
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.lightSepia)
                }
            }
            .padding(AppSpacing.md)
        }
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
        .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Recipe List View
struct RecipeListView: View {
    // All recipes with their categories
    let recipes: [Recipe] = [
        Recipe(
            title: "Rainbow Veggie Wrap",
            description: "A colorful, crunchy wrap packed with fresh vegetables and hummus",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .lunch,  // This is a lunch recipe
            cookTime: 15,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin A", "Fiber", "Protein"]
        ),
        Recipe(
            title: "Sunny Pancakes",
            description: "Fluffy whole wheat pancakes with fresh berries",
            imageName: "recipe_pancakes_sunny1",
            imageYOffset: -30,
            category: .breakfast,  // This is a breakfast recipe
            cookTime: 25,
            difficulty: .medium,
            servings: 4,
            needsAdultHelp: true,
            nutritionFacts: ["Whole Grains", "Antioxidants"]
        ),
        Recipe(
            title: "Garden Pasta",
            description: "Pasta with fresh tomatoes, basil, and hidden veggie sauce",
            imageName: "recipe_pasta_garden",
            category: .dinner,  // This is a dinner recipe
            cookTime: 30,
            difficulty: .medium,
            servings: 4,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin C", "Fiber", "Iron"]
        )
    ]

    // Track which category is selected
    @State private var selectedCategory: RecipeCategory = .all

    // Filter recipes based on selected category
    var filteredRecipes: [Recipe] {
        if selectedCategory == .all {
            return recipes
        }
        return recipes.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hello, Little Chef! 👋")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.sepia)
                            Text("What shall we cook today?")
                                .font(.AppTheme.title)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        }
                        Spacer()

                        // Profile/Avatar placeholder
                        Circle()
                            .fill(Color.AppTheme.parchment)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color.AppTheme.sepia)
                            )
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)

                    // Category Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(RecipeCategory.allCases, id: \.self) { category in
                                CategoryPill(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedCategory = category
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Recipe Cards - Shows filtered recipes
                    VStack(spacing: AppSpacing.md) {
                        ForEach(filteredRecipes) { recipe in
                            RecipeCardView(recipe: recipe)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, 100)  // Space for tab bar
                    .animation(.easeInOut(duration: 0.3), value: selectedCategory)
                }
            }
            .background(Color.AppTheme.cream)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Category Pill (Button for reliable tapping)
struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.AppTheme.subheadline)
            }
            .foregroundColor(isSelected ? Color.AppTheme.cream : Color.AppTheme.darkBrown)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? Color.AppTheme.goldenWheat : Color.AppTheme.parchment)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    RecipeListView()
}

//
//  RecipeCardExample.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

