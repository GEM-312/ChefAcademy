import SwiftUI

// MARK: - Recipe Model
struct Recipe: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let cookTime: Int // in minutes
    let difficulty: DifficultyBadge.Level
    let servings: Int
    let needsAdultHelp: Bool
    let nutritionFacts: [String]
}

// MARK: - Recipe Card View
struct RecipeCardView: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Area (placeholder for Midjourney illustrations)
            ZStack(alignment: .topTrailing) {
                // Placeholder - replace with Image(recipe.imageName)
                Rectangle()
                    .fill(Color.AppTheme.parchment)
                    .frame(height: 160)
                    .overlay(
                        VStack {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 40))
                                .foregroundColor(Color.AppTheme.lightSepia)
                            Text("Illustration Here")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.lightSepia)
                        }
                    )
                
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
    let recipes: [Recipe] = [
        Recipe(
            title: "Rainbow Veggie Wrap",
            description: "A colorful, crunchy wrap packed with fresh vegetables and hummus",
            imageName: "rainbow-wrap",
            cookTime: 15,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin A", "Fiber", "Protein"]
        ),
        Recipe(
            title: "Sunny Pancakes",
            description: "Fluffy whole wheat pancakes with fresh berries",
            imageName: "pancakes",
            cookTime: 25,
            difficulty: .medium,
            servings: 4,
            needsAdultHelp: true,
            nutritionFacts: ["Whole Grains", "Antioxidants"]
        ),
        Recipe(
            title: "Garden Pasta",
            description: "Pasta with fresh tomatoes, basil, and hidden veggie sauce",
            imageName: "garden-pasta",
            cookTime: 30,
            difficulty: .medium,
            servings: 4,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin C", "Fiber", "Iron"]
        )
    ]
    
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
                            CategoryPill(title: "All", icon: "square.grid.2x2", isSelected: true)
                            CategoryPill(title: "Breakfast", icon: "sun.max", isSelected: false)
                            CategoryPill(title: "Lunch", icon: "takeoutbag.and.cup.and.straw", isSelected: false)
                            CategoryPill(title: "Dinner", icon: "moon.stars", isSelected: false)
                            CategoryPill(title: "Snacks", icon: "carrot", isSelected: false)
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                    
                    // Recipe Cards
                    VStack(spacing: AppSpacing.md) {
                        ForEach(recipes) { recipe in
                            RecipeCardView(recipe: recipe)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .background(Color.AppTheme.cream)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
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
}

// MARK: - Preview
#Preview {
    RecipeListView()
}//
//  RecipeCardExample.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

