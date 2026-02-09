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

// MARK: - Pantry Item
/// Items always available in the kitchen — no need to grow these!
enum PantryItem: String, CaseIterable, Identifiable {
    // Basics
    case salt, pepper, sugar, flour
    // Oils & Fats
    case butter, oliveOil, vegetableOil
    // Dairy & Eggs
    case eggs, milk, cheese, cream
    // Protein
    case chicken, groundBeef
    // Pantry Staples
    case rice, pasta, bread, tortilla
    // Sauces & Condiments
    case soySauce, tomatoSauce, vinegar, honey

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .salt: return "Salt"
        case .pepper: return "Pepper"
        case .sugar: return "Sugar"
        case .flour: return "Flour"
        case .butter: return "Butter"
        case .oliveOil: return "Olive Oil"
        case .vegetableOil: return "Vegetable Oil"
        case .eggs: return "Eggs"
        case .milk: return "Milk"
        case .cheese: return "Cheese"
        case .cream: return "Cream"
        case .chicken: return "Chicken"
        case .groundBeef: return "Ground Beef"
        case .rice: return "Rice"
        case .pasta: return "Pasta"
        case .bread: return "Bread"
        case .tortilla: return "Tortilla"
        case .soySauce: return "Soy Sauce"
        case .tomatoSauce: return "Tomato Sauce"
        case .vinegar: return "Vinegar"
        case .honey: return "Honey"
        }
    }

    var emoji: String {
        switch self {
        case .salt: return "🧂"
        case .pepper: return "🌶️"
        case .sugar: return "🍬"
        case .flour: return "🌾"
        case .butter: return "🧈"
        case .oliveOil, .vegetableOil: return "🫒"
        case .eggs: return "🥚"
        case .milk: return "🥛"
        case .cheese: return "🧀"
        case .cream: return "🥛"
        case .chicken: return "🍗"
        case .groundBeef: return "🥩"
        case .rice: return "🍚"
        case .pasta: return "🍝"
        case .bread: return "🍞"
        case .tortilla: return "🫓"
        case .soySauce: return "🫙"
        case .tomatoSauce: return "🥫"
        case .vinegar: return "🫙"
        case .honey: return "🍯"
        }
    }

    /// Price to buy from the farm shop
    var shopPrice: Int {
        switch self {
        case .salt, .pepper: return 2
        case .sugar, .flour: return 3
        case .butter: return 5
        case .oliveOil, .vegetableOil: return 4
        case .eggs: return 5
        case .milk: return 4
        case .cheese: return 6
        case .cream: return 5
        case .chicken: return 12
        case .groundBeef: return 15
        case .rice, .pasta: return 4
        case .bread: return 3
        case .tortilla: return 3
        case .soySauce: return 3
        case .tomatoSauce: return 4
        case .vinegar: return 3
        case .honey: return 6
        }
    }

    /// Shop category for grouping items
    var shopCategory: ShopCategory {
        switch self {
        case .salt, .pepper, .sugar, .flour:
            return .basics
        case .butter, .oliveOil, .vegetableOil:
            return .oilsAndFats
        case .eggs, .milk, .cheese, .cream:
            return .dairy
        case .chicken, .groundBeef:
            return .protein
        case .rice, .pasta, .bread, .tortilla:
            return .grains
        case .soySauce, .tomatoSauce, .vinegar, .honey:
            return .sauces
        }
    }
}

// MARK: - Shop Category
enum ShopCategory: String, CaseIterable {
    case all = "All"
    case dairy = "Dairy & Eggs"
    case protein = "Meat"
    case grains = "Grains"
    case oilsAndFats = "Oils"
    case basics = "Basics"
    case sauces = "Sauces"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .dairy: return "cup.and.saucer"
        case .protein: return "fork.knife"
        case .grains: return "leaf"
        case .oilsAndFats: return "drop"
        case .basics: return "sparkles"
        case .sauces: return "flask"
        }
    }

    var color: Color {
        switch self {
        case .all: return Color.AppTheme.goldenWheat
        case .dairy: return Color.AppTheme.softOlive
        case .protein: return Color.AppTheme.terracotta
        case .grains: return Color.AppTheme.goldenWheat
        case .oilsAndFats: return Color.AppTheme.sage
        case .basics: return Color.AppTheme.lightSepia
        case .sauces: return Color.AppTheme.terracotta
        }
    }
}

// MARK: - Recipe Model
struct Recipe: Identifiable {
    let id: String  // Stable ID for tracking unlocks and stars
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
    let gardenIngredients: [VegetableType]  // Veggies you GROW — the game part!
    let pantryIngredients: [PantryItem]     // Always available in the kitchen

    // Default initializer
    init(id: String = UUID().uuidString, title: String, description: String, imageName: String, imageYOffset: CGFloat = 0, category: RecipeCategory = .lunch, cookTime: Int, difficulty: DifficultyBadge.Level, servings: Int, needsAdultHelp: Bool, nutritionFacts: [String], gardenIngredients: [VegetableType] = [], pantryIngredients: [PantryItem] = []) {
        self.id = id
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
        self.gardenIngredients = gardenIngredients
        self.pantryIngredients = pantryIngredients
    }

    /// Check if the player has all GARDEN ingredients for this recipe
    func canCook(with harvestedIngredients: [HarvestedIngredient]) -> Bool {
        for vegType in gardenIngredients {
            let available = harvestedIngredients.first(where: { $0.type == vegType })?.quantity ?? 0
            if available < 1 { return false }
        }
        return true
    }

    /// Check if player has BOTH garden AND pantry ingredients
    func canCookFull(harvestedIngredients: [HarvestedIngredient], pantryInventory: [PantryStock]) -> Bool {
        // Check garden ingredients
        for vegType in gardenIngredients {
            let available = harvestedIngredients.first(where: { $0.type == vegType })?.quantity ?? 0
            if available < 1 { return false }
        }
        // Check pantry ingredients
        for pantryItem in pantryIngredients {
            let available = pantryInventory.first(where: { $0.item == pantryItem })?.quantity ?? 0
            if available < 1 { return false }
        }
        return true
    }

    /// Get missing pantry items for this recipe
    func missingPantryItems(from pantryInventory: [PantryStock]) -> [PantryItem] {
        return pantryIngredients.filter { item in
            let available = pantryInventory.first(where: { $0.item == item })?.quantity ?? 0
            return available < 1
        }
    }
}

// MARK: - All Garden Recipes
/// Recipes that use vegetables from the garden + pantry staples!
/// Garden veggies = the game part (you grow them)
/// Pantry items = always available in the kitchen
struct GardenRecipes {
    static let all: [Recipe] = [

        // MARK: - Breakfast

        Recipe(
            id: "veggie-omelette",
            title: "Garden Veggie Omelette",
            description: "A fluffy egg omelette stuffed with fresh tomatoes, onions, and melted cheese",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .breakfast,
            cookTime: 10,
            difficulty: .easy,
            servings: 1,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin C", "Calcium"],
            gardenIngredients: [.tomato, .onion],
            pantryIngredients: [.eggs, .butter, .cheese, .salt, .pepper]
        ),
        Recipe(
            id: "veggie-scramble",
            title: "Scrambled Egg Veggie Bowl",
            description: "Scrambled eggs with broccoli and zucchini — a power breakfast!",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .breakfast,
            cookTime: 12,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin K", "Iron"],
            gardenIngredients: [.broccoli, .zucchini],
            pantryIngredients: [.eggs, .butter, .salt, .pepper]
        ),

        // MARK: - Lunch

        Recipe(
            id: "rainbow-veggie-wrap",
            title: "Rainbow Veggie Wrap",
            description: "A colorful tortilla wrap with crunchy lettuce, carrot, and cucumber",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .lunch,
            cookTime: 15,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin A", "Fiber", "Hydration"],
            gardenIngredients: [.lettuce, .carrot, .cucumber],
            pantryIngredients: [.tortilla, .cheese]
        ),
        Recipe(
            id: "garden-salad",
            title: "Fresh Garden Salad",
            description: "Crispy lettuce, juicy tomato, and crunchy cucumber with olive oil dressing",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .lunch,
            cookTime: 10,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin C", "Fiber", "Hydration"],
            gardenIngredients: [.lettuce, .tomato, .cucumber],
            pantryIngredients: [.oliveOil, .vinegar, .salt]
        ),
        Recipe(
            id: "pumpkin-soup",
            title: "Cozy Pumpkin Soup",
            description: "Creamy pumpkin soup with butter and onion — warm and cozy!",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .lunch,
            cookTime: 25,
            difficulty: .medium,
            servings: 4,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin A", "Fiber", "Potassium"],
            gardenIngredients: [.pumpkin, .onion],
            pantryIngredients: [.butter, .cream, .salt, .pepper]
        ),
        Recipe(
            id: "chicken-lettuce-wrap",
            title: "Chicken Lettuce Wrap",
            description: "Seasoned chicken in crunchy lettuce cups with carrot and onion",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .lunch,
            cookTime: 20,
            difficulty: .medium,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin A", "Fiber"],
            gardenIngredients: [.lettuce, .carrot, .onion],
            pantryIngredients: [.chicken, .soySauce, .vegetableOil, .salt]
        ),

        // MARK: - Dinner

        Recipe(
            id: "chicken-stir-fry",
            title: "Chicken Veggie Stir Fry",
            description: "Sizzling chicken with broccoli, carrot, and zucchini in soy sauce",
            imageName: "recipe_pasta_garden",
            category: .dinner,
            cookTime: 20,
            difficulty: .medium,
            servings: 3,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin C", "Vitamin K"],
            gardenIngredients: [.broccoli, .carrot, .zucchini],
            pantryIngredients: [.chicken, .soySauce, .vegetableOil, .rice, .salt, .pepper]
        ),
        Recipe(
            id: "garden-pasta",
            title: "Garden Pasta",
            description: "Pasta with fresh tomatoes, zucchini, onion, and olive oil",
            imageName: "recipe_pasta_garden",
            category: .dinner,
            cookTime: 25,
            difficulty: .medium,
            servings: 4,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin C", "Fiber", "Iron"],
            gardenIngredients: [.tomato, .zucchini, .onion],
            pantryIngredients: [.pasta, .oliveOil, .salt, .pepper, .cheese]
        ),
        Recipe(
            id: "stuffed-pumpkin",
            title: "Stuffed Pumpkin Bowl",
            description: "Roasted pumpkin filled with rice, broccoli, onion, and carrots",
            imageName: "recipe_pasta_garden",
            category: .dinner,
            cookTime: 35,
            difficulty: .hard,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin A", "Vitamin K", "Fiber"],
            gardenIngredients: [.pumpkin, .broccoli, .onion, .carrot],
            pantryIngredients: [.rice, .butter, .cheese, .salt, .pepper]
        ),
        Recipe(
            id: "beef-veggie-rice",
            title: "Beef & Veggie Rice Bowl",
            description: "Ground beef with broccoli and onion over fluffy rice",
            imageName: "recipe_pasta_garden",
            category: .dinner,
            cookTime: 25,
            difficulty: .medium,
            servings: 3,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Iron", "Vitamin K"],
            gardenIngredients: [.broccoli, .onion],
            pantryIngredients: [.groundBeef, .rice, .soySauce, .vegetableOil, .salt, .pepper]
        ),

        // MARK: - Snacks

        Recipe(
            id: "carrot-sticks",
            title: "Carrot Crunch Sticks",
            description: "Fresh carrot sticks with a honey drizzle — sweet and crunchy!",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .snacks,
            cookTime: 5,
            difficulty: .easy,
            servings: 1,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin A", "Fiber", "Beta-Carotene"],
            gardenIngredients: [.carrot],
            pantryIngredients: [.honey]
        ),
        Recipe(
            id: "cucumber-bites",
            title: "Cool Cucumber Bites",
            description: "Crispy cucumber slices with a pinch of salt — refreshing!",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .snacks,
            cookTime: 5,
            difficulty: .easy,
            servings: 1,
            needsAdultHelp: false,
            nutritionFacts: ["Hydration", "Vitamin K", "Fiber"],
            gardenIngredients: [.cucumber],
            pantryIngredients: [.salt]
        ),
        Recipe(
            id: "cheesy-broccoli-bites",
            title: "Cheesy Broccoli Bites",
            description: "Tiny broccoli florets baked with melted cheese — so yummy!",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .snacks,
            cookTime: 15,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Calcium", "Vitamin K", "Protein"],
            gardenIngredients: [.broccoli],
            pantryIngredients: [.cheese, .eggs, .flour, .salt]
        ),
        Recipe(
            id: "lettuce-cups",
            title: "Veggie Lettuce Cups",
            description: "Crunchy lettuce cups with chopped carrot, tomato, and cheese",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .snacks,
            cookTime: 10,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin A", "Vitamin C", "Fiber"],
            gardenIngredients: [.lettuce, .carrot, .tomato],
            pantryIngredients: [.cheese, .salt]
        ),
    ]

    /// Find recipes the player can make right now (checks garden ingredients only)
    static func availableRecipes(with ingredients: [HarvestedIngredient]) -> [Recipe] {
        return all.filter { $0.canCook(with: ingredients) }
    }

    /// Find recipes the player can FULLY make (checks both garden AND pantry)
    static func fullyAvailableRecipes(harvestedIngredients: [HarvestedIngredient], pantryInventory: [PantryStock]) -> [Recipe] {
        return all.filter { $0.canCookFull(harvestedIngredients: harvestedIngredients, pantryInventory: pantryInventory) }
    }

    /// Find recipes that use a specific vegetable
    static func recipes(using vegType: VegetableType) -> [Recipe] {
        return all.filter { $0.gardenIngredients.contains(vegType) }
    }
}

// MARK: - Recipe Card View
struct RecipeCardView: View {
    let recipe: Recipe
    var showIngredientStatus: Bool = false
    var harvestedIngredients: [HarvestedIngredient] = []
    var pantryInventory: [PantryStock] = []

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

                // Ingredient status (when enabled)
                if showIngredientStatus {
                    ingredientStatusRow
                }

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

    // MARK: - Ingredient Status Row

    var ingredientStatusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Garden ingredients
            if !recipe.gardenIngredients.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.AppTheme.sage)
                    ForEach(recipe.gardenIngredients, id: \.self) { veg in
                        let hasIt = harvestedIngredients.first(where: { $0.type == veg })?.quantity ?? 0 >= 1
                        Text(veg.emoji)
                            .font(.system(size: 14))
                            .opacity(hasIt ? 1.0 : 0.3)
                    }
                }
            }

            // Pantry ingredients
            if !recipe.pantryIngredients.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                    ForEach(recipe.pantryIngredients, id: \.self) { item in
                        let hasIt = pantryInventory.first(where: { $0.item == item })?.quantity ?? 0 >= 1
                        Text(item.emoji)
                            .font(.system(size: 14))
                            .opacity(hasIt ? 1.0 : 0.3)
                    }
                }
            }
        }
    }
}

// MARK: - Recipe List View
struct RecipeListView: View {
    @EnvironmentObject var gameState: GameState

    // Use garden recipes
    let recipes: [Recipe] = GardenRecipes.all

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
                            RecipeCardView(
                                recipe: recipe,
                                showIngredientStatus: true,
                                harvestedIngredients: gameState.harvestedIngredients,
                                pantryInventory: gameState.pantryInventory
                            )
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
        .environmentObject(GameState.preview)
}

//
//  RecipeCardExample.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

