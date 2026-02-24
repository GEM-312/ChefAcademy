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
    case salt, pepper, flour, cinnamon
    // Oils & Fats
    case butter, oliveOil, vegetableOil
    // Dairy & Eggs
    case eggs, milk, cheese, cream, greekYogurt
    // Protein & Nuts
    case chicken, groundBeef, nuts
    // (Starch items removed — all recipes are now starch-free!)
    // Sauces & Condiments
    case soySauce, tomatoSauce, vinegar, honey, lemon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .salt: return "Salt"
        case .pepper: return "Pepper"
        case .flour: return "Flour"
        case .cinnamon: return "Cinnamon"
        case .butter: return "Butter"
        case .oliveOil: return "Olive Oil"
        case .vegetableOil: return "Vegetable Oil"
        case .eggs: return "Eggs"
        case .milk: return "Milk"
        case .cheese: return "Cheese"
        case .cream: return "Cream"
        case .greekYogurt: return "Greek Yogurt"
        case .chicken: return "Chicken"
        case .groundBeef: return "Ground Beef"
        case .nuts: return "Nuts"
        case .soySauce: return "Soy Sauce"
        case .tomatoSauce: return "Tomato Sauce"
        case .vinegar: return "Vinegar"
        case .honey: return "Honey"
        case .lemon: return "Lemon"
        }
    }

    var emoji: String {
        switch self {
        case .salt: return "🧂"
        case .pepper: return "🌶️"
        case .flour: return "🌾"
        case .cinnamon: return "🫙"
        case .butter: return "🧈"
        case .oliveOil, .vegetableOil: return "🫒"
        case .eggs: return "🥚"
        case .milk: return "🥛"
        case .cheese: return "🧀"
        case .cream: return "🥛"
        case .greekYogurt: return "🥣"
        case .chicken: return "🍗"
        case .groundBeef: return "🥩"
        case .nuts: return "🥜"
        case .soySauce: return "🫙"
        case .tomatoSauce: return "🥫"
        case .vinegar: return "🫙"
        case .honey: return "🍯"
        case .lemon: return "🍋"
        }
    }

    /// Farm item illustration image name (in Assets catalog)
    var imageName: String {
        switch self {
        case .salt: return "farm_salt"
        case .pepper: return "farm_pepper"
        case .flour: return "farm_flour"
        case .cinnamon: return "farm_cinnamon"
        case .butter: return "farm_butter"
        case .oliveOil: return "farm_oliveOil"
        case .vegetableOil: return "farm_oliveOil"
        case .eggs: return "farm_eggs"
        case .milk: return "farm_milk"
        case .cheese: return "farm_cheese"
        case .cream: return "farm_cream"
        case .greekYogurt: return "farm_greekYogurt"
        case .chicken: return "farm_chicken"
        case .groundBeef: return "farm_groundBeef"
        case .nuts: return "farm_nuts"
        case .soySauce: return "farm_soySauce"
        case .tomatoSauce: return "farm_tomatoSauce"
        case .vinegar: return "farm_vinegar"
        case .honey: return "farm_honey"
        case .lemon: return "farm_lemon"
        }
    }

    /// Price to buy from the farm shop
    var shopPrice: Int {
        switch self {
        case .salt, .pepper: return 2
        case .flour: return 3
        case .cinnamon: return 2
        case .butter: return 5
        case .oliveOil, .vegetableOil: return 4
        case .eggs: return 5
        case .milk: return 4
        case .cheese: return 6
        case .cream: return 5
        case .greekYogurt: return 5
        case .chicken: return 12
        case .groundBeef: return 15
        case .nuts: return 6
        case .soySauce: return 3
        case .tomatoSauce: return 4
        case .vinegar: return 3
        case .honey: return 6
        case .lemon: return 2
        }
    }

    /// Shop category for grouping items
    var shopCategory: ShopCategory {
        switch self {
        case .salt, .pepper, .flour, .cinnamon:
            return .basics
        case .butter, .oliveOil, .vegetableOil:
            return .oilsAndFats
        case .eggs, .milk, .cheese, .cream, .greekYogurt:
            return .dairy
        case .chicken, .groundBeef, .nuts:
            return .protein
        case .soySauce, .tomatoSauce, .vinegar, .honey, .lemon:
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
    let glucoseTip: String                  // Kid-friendly Glucose Goddess nutrition tip
    let steps: [String]                      // Kid-friendly cooking instructions

    // Default initializer
    init(id: String = UUID().uuidString, title: String, description: String, imageName: String, imageYOffset: CGFloat = 0, category: RecipeCategory = .lunch, cookTime: Int, difficulty: DifficultyBadge.Level, servings: Int, needsAdultHelp: Bool, nutritionFacts: [String], gardenIngredients: [VegetableType] = [], pantryIngredients: [PantryItem] = [], glucoseTip: String = "", steps: [String] = []) {
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
        self.glucoseTip = glucoseTip
        self.steps = steps
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
            imageName: "recipe_veggie_omelette",
            category: .breakfast,
            cookTime: 10,
            difficulty: .easy,
            servings: 1,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin C", "Calcium"],
            gardenIngredients: [.tomato, .onion],
            pantryIngredients: [.eggs, .butter, .cheese, .salt, .pepper],
            glucoseTip: "This savory breakfast is perfect! Eggs + cheese give you protein and fat to keep your energy steady all morning.",
            steps: [
                "Crack 2 eggs into a bowl and whisk until fluffy.",
                "Chop the tomato and onion into small pieces.",
                "Melt butter in a pan over medium heat.",
                "Pour the eggs into the pan and cook for 1 minute.",
                "Add tomato, onion, and cheese on one half.",
                "Fold the omelette in half with a spatula.",
                "Cook 2 more minutes until cheese melts.",
                "Slide onto a plate — bon appetit!"
            ]
        ),
        Recipe(
            id: "veggie-scramble",
            title: "Scrambled Egg Veggie Bowl",
            description: "Scrambled eggs with broccoli and zucchini — a power breakfast!",
            imageName: "recipe_scrambled_egg_bowl",
            category: .breakfast,
            cookTime: 12,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin K", "Iron"],
            gardenIngredients: [.broccoli, .zucchini],
            pantryIngredients: [.eggs, .butter, .salt, .pepper],
            glucoseTip: "Veggies + eggs for breakfast means steady energy! Savory breakfasts help you focus better than sugary cereal.",
            steps: [
                "Chop the broccoli into tiny florets and dice the zucchini.",
                "Crack 3 eggs into a bowl, add salt and pepper, and whisk.",
                "Melt butter in a pan over medium heat.",
                "Add the broccoli and zucchini, cook for 3 minutes until soft.",
                "Pour the whisked eggs over the veggies.",
                "Gently stir with a spatula until eggs are fluffy and cooked.",
                "Scoop into bowls and enjoy your power breakfast!"
            ]
        ),
        Recipe(
            id: "yogurt-power-bowl",
            title: "Greek Yogurt Power Bowl",
            description: "Creamy Greek yogurt topped with crunchy nuts, cinnamon, and fresh carrot shreds",
            imageName: "recipe_yogurt_power_bowl",
            category: .breakfast,
            cookTime: 5,
            difficulty: .easy,
            servings: 1,
            needsAdultHelp: false,
            nutritionFacts: ["Protein", "Calcium", "Healthy Fats"],
            gardenIngredients: [.carrot],
            pantryIngredients: [.greekYogurt, .nuts, .cinnamon],
            glucoseTip: "Greek yogurt is packed with protein! Cinnamon adds yummy flavor without any sugar. Smart swap!",
            steps: [
                "Peel the carrot and grate it into thin shreds.",
                "Scoop Greek yogurt into a bowl.",
                "Sprinkle cinnamon on top.",
                "Add a handful of crunchy nuts.",
                "Top with the carrot shreds.",
                "Mix it all together and dig in!"
            ]
        ),

        // MARK: - Lunch

        Recipe(
            id: "chicken-veggie-platter",
            title: "Crunchy Chicken Veggie Platter",
            description: "Build-your-own veggie and chicken plate with lemon dressing — crunchy, fresh, and filling!",
            imageName: "recipe_chicken_veggie_platter",
            category: .lunch,
            cookTime: 15,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: false,
            nutritionFacts: ["Protein", "Vitamin A", "Fiber"],
            gardenIngredients: [.lettuce, .carrot, .cucumber],
            pantryIngredients: [.chicken, .cheese, .oliveOil, .lemon, .salt],
            glucoseTip: "No bread needed! Veggies + chicken + cheese give you protein, fiber, and healthy fats — the perfect energy trio.",
            steps: [
                "Wash the lettuce, carrot, and cucumber.",
                "Tear the lettuce into bite-sized pieces.",
                "Peel and slice the carrot into sticks.",
                "Cut the cucumber into rounds.",
                "Slice the chicken into strips (use pre-cooked chicken!).",
                "Arrange everything on a big plate.",
                "Squeeze lemon juice and drizzle olive oil for dressing.",
                "Sprinkle cheese and salt on top — done!"
            ]
        ),
        Recipe(
            id: "garden-salad",
            title: "Fresh Garden Salad",
            description: "Crispy lettuce, juicy tomato, and cucumber with eggs, cheese, and olive oil dressing",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .lunch,
            cookTime: 10,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin C", "Protein", "Fiber"],
            gardenIngredients: [.lettuce, .tomato, .cucumber],
            pantryIngredients: [.oliveOil, .vinegar, .eggs, .cheese, .salt],
            glucoseTip: "Starting a meal with salad is a superpower! The fiber in veggies helps your body handle everything you eat after.",
            steps: [
                "Boil 2 eggs for 10 minutes, then peel and slice them.",
                "Wash and tear the lettuce into pieces.",
                "Chop the tomato into chunks.",
                "Slice the cucumber into thin rounds.",
                "Toss all the veggies into a big bowl.",
                "Add the sliced eggs and crumbled cheese.",
                "Drizzle olive oil and a splash of vinegar.",
                "Sprinkle salt, toss gently, and serve!"
            ]
        ),
        Recipe(
            id: "pumpkin-soup",
            title: "Cozy Pumpkin Soup",
            description: "Creamy pumpkin soup with chicken, butter, and onion — warm, cozy, and filling!",
            imageName: "recipe_pumpkin_soup",
            category: .lunch,
            cookTime: 25,
            difficulty: .medium,
            servings: 4,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin A", "Protein", "Potassium"],
            gardenIngredients: [.pumpkin, .onion],
            pantryIngredients: [.chicken, .butter, .cream, .salt, .pepper],
            glucoseTip: "Adding chicken to soup gives it protein power! Your muscles love protein — it keeps you strong and full.",
            steps: [
                "Peel the pumpkin and cut it into small cubes.",
                "Chop the onion into tiny pieces.",
                "Melt butter in a big pot over medium heat.",
                "Cook the onion until it's soft and golden.",
                "Add the pumpkin cubes and stir for 2 minutes.",
                "Pour in water and add chicken pieces.",
                "Let it simmer for 15 minutes until pumpkin is soft.",
                "Blend until smooth, stir in cream, and add salt and pepper!"
            ]
        ),
        Recipe(
            id: "chicken-lettuce-wrap",
            title: "Chicken Lettuce Wrap",
            description: "Seasoned chicken in crunchy lettuce cups with carrot and onion",
            imageName: "recipe_chicken_lettuce_wrap",
            category: .lunch,
            cookTime: 20,
            difficulty: .medium,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin A", "Fiber"],
            gardenIngredients: [.lettuce, .carrot, .onion],
            pantryIngredients: [.chicken, .soySauce, .vegetableOil, .salt],
            glucoseTip: "Using lettuce instead of bread is genius! You get all the crunch with extra fiber and vitamins instead of starch.",
            steps: [
                "Chop the chicken into small pieces.",
                "Dice the onion and grate the carrot.",
                "Heat vegetable oil in a pan over medium heat.",
                "Cook the chicken pieces until golden brown.",
                "Add onion and carrot, stir for 3 minutes.",
                "Splash in soy sauce and mix well.",
                "Wash and separate big lettuce leaves for cups.",
                "Scoop the filling into lettuce cups and enjoy!"
            ]
        ),
        Recipe(
            id: "tomato-egg-soup",
            title: "Creamy Tomato Egg Soup",
            description: "Warm tomato soup with whisked eggs stirred in — high protein, cozy, and delicious!",
            imageName: "recipe_tomato_egg_soup",
            category: .lunch,
            cookTime: 20,
            difficulty: .medium,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin C", "Vitamin A"],
            gardenIngredients: [.tomato, .onion],
            pantryIngredients: [.eggs, .butter, .cream, .salt, .pepper],
            glucoseTip: "Eggs in soup? Yes! They add protein that keeps you full and your energy nice and steady.",
            steps: [
                "Chop the tomatoes and onion into small pieces.",
                "Melt butter in a pot over medium heat.",
                "Cook the onion until soft, then add tomatoes.",
                "Simmer for 10 minutes until tomatoes break down.",
                "Whisk 2 eggs in a small bowl.",
                "Slowly pour the eggs into the soup while stirring.",
                "Add cream, salt, and pepper.",
                "Stir gently and serve warm!"
            ]
        ),

        // MARK: - Dinner

        Recipe(
            id: "chicken-veggie-skillet",
            title: "Sizzling Chicken Veggie Skillet",
            description: "Sizzling chicken with broccoli, carrot, and zucchini in soy sauce — no rice needed!",
            imageName: "recipe_chicken_veggie_skillet",
            category: .dinner,
            cookTime: 20,
            difficulty: .medium,
            servings: 3,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin C", "Vitamin K"],
            gardenIngredients: [.broccoli, .carrot, .zucchini],
            pantryIngredients: [.chicken, .soySauce, .oliveOil, .salt, .pepper],
            glucoseTip: "All the sizzle, no rice needed! Your plate is full of protein and colorful veggies — that's real fuel.",
            steps: [
                "Cut the chicken into bite-sized pieces.",
                "Chop broccoli into florets, slice carrot and zucchini.",
                "Heat olive oil in a big skillet over medium-high heat.",
                "Cook the chicken pieces for 5 minutes until golden.",
                "Add all the veggies to the skillet.",
                "Stir and cook for 5 more minutes.",
                "Pour soy sauce over everything and toss.",
                "Season with salt and pepper, then serve hot!"
            ]
        ),
        Recipe(
            id: "zucchini-noodle-chicken",
            title: "Zucchini Noodle Chicken Bowl",
            description: "Spiralized zucchini noodles with chicken, tomato sauce, and melted cheese — a pasta swap!",
            imageName: "recipe_zucchini_noodle_bowl",
            category: .dinner,
            cookTime: 25,
            difficulty: .medium,
            servings: 3,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin C", "Protein", "Fiber"],
            gardenIngredients: [.zucchini, .tomato, .onion],
            pantryIngredients: [.chicken, .oliveOil, .cheese, .salt, .pepper],
            glucoseTip: "Zucchini noodles look like pasta but are made of veggies! Same fun, way more vitamins.",
            steps: [
                "Use a spiralizer or peeler to make zucchini noodles.",
                "Chop the tomato and onion into small pieces.",
                "Cut the chicken into thin strips.",
                "Heat olive oil in a pan and cook the chicken.",
                "Add onion and tomato, cook for 3 minutes.",
                "Toss in the zucchini noodles and stir gently.",
                "Cook for 2 minutes — don't overcook the noodles!",
                "Top with cheese, salt, and pepper. Twirl and enjoy!"
            ]
        ),
        Recipe(
            id: "cheesy-stuffed-pumpkin",
            title: "Cheesy Stuffed Pumpkin",
            description: "Roasted pumpkin stuffed with scrambled eggs, cheese, broccoli, and carrots — no rice needed!",
            imageName: "recipe_pasta_garden",
            category: .dinner,
            cookTime: 35,
            difficulty: .hard,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin A", "Protein", "Fiber"],
            gardenIngredients: [.pumpkin, .broccoli, .onion, .carrot],
            pantryIngredients: [.eggs, .cheese, .butter, .salt, .pepper],
            glucoseTip: "Eggs and cheese fill this pumpkin with protein instead of rice! Your muscles will thank you.",
            steps: [
                "Cut the pumpkin in half and scoop out the seeds.",
                "Brush with butter and roast at 375°F for 20 minutes.",
                "Chop broccoli, onion, and carrot into small pieces.",
                "Scramble eggs in a pan with butter.",
                "Mix the scrambled eggs with chopped veggies.",
                "Add cheese, salt, and pepper to the mixture.",
                "Scoop the filling into the roasted pumpkin halves.",
                "Bake 10 more minutes until cheese is bubbly!"
            ]
        ),
        Recipe(
            id: "beef-stuffed-zucchini",
            title: "Beef Stuffed Zucchini Boats",
            description: "Halved zucchini filled with seasoned beef, tomato sauce, and melted cheese — so good!",
            imageName: "recipe_beef_zucchini_boats",
            category: .dinner,
            cookTime: 30,
            difficulty: .medium,
            servings: 3,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Iron", "Vitamin C"],
            gardenIngredients: [.zucchini, .onion, .tomato],
            pantryIngredients: [.groundBeef, .cheese, .tomatoSauce, .salt, .pepper],
            glucoseTip: "Zucchini boats hold all the yummy beef and cheese! No starch — just protein, veggies, and flavor.",
            steps: [
                "Cut each zucchini in half lengthwise.",
                "Scoop out the middle to make little boats.",
                "Chop the onion and tomato into small pieces.",
                "Brown the ground beef in a pan over medium heat.",
                "Add onion, tomato, and tomato sauce to the beef.",
                "Cook for 5 minutes, then add salt and pepper.",
                "Fill each zucchini boat with the beef mixture.",
                "Top with cheese and bake at 375°F for 15 minutes!"
            ]
        ),

        // MARK: - Snacks

        Recipe(
            id: "carrot-sticks",
            title: "Carrot Crunch & Cheese Dip",
            description: "Fresh carrot sticks with creamy cheese dip — savory and crunchy!",
            imageName: "recipe_carrot_cheese_dip",
            category: .snacks,
            cookTime: 5,
            difficulty: .easy,
            servings: 1,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin A", "Protein", "Calcium"],
            gardenIngredients: [.carrot],
            pantryIngredients: [.cheese],
            glucoseTip: "Savory snacks are the best! Cheese gives you protein which keeps you full way longer than sweet treats.",
            steps: [
                "Wash and peel the carrots.",
                "Cut them into long, thin sticks.",
                "Put soft cheese in a small bowl.",
                "Arrange carrot sticks around the cheese dip.",
                "Dip, crunch, and enjoy!"
            ]
        ),
        Recipe(
            id: "cucumber-bites",
            title: "Cucumber & Cheese Bites",
            description: "Crispy cucumber slices topped with cheese — refreshing and filling!",
            imageName: "recipe_cucumber_cheese_bites",
            category: .snacks,
            cookTime: 5,
            difficulty: .easy,
            servings: 1,
            needsAdultHelp: false,
            nutritionFacts: ["Hydration", "Protein", "Calcium"],
            gardenIngredients: [.cucumber],
            pantryIngredients: [.cheese, .salt],
            glucoseTip: "Veggies + cheese = the perfect snack! This combo gives you hydration, fiber, AND protein all at once.",
            steps: [
                "Wash the cucumber.",
                "Slice it into thick rounds.",
                "Cut cheese into small squares.",
                "Place a cheese square on each cucumber round.",
                "Sprinkle a tiny bit of salt on top.",
                "Pop them in your mouth — so refreshing!"
            ]
        ),
        Recipe(
            id: "cheesy-broccoli-bites",
            title: "Cheesy Broccoli Bites",
            description: "Tiny broccoli florets baked with eggs and melted cheese — so yummy!",
            imageName: "recipe_wrap_rainbow_veggie",
            category: .snacks,
            cookTime: 15,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Calcium", "Vitamin K", "Protein"],
            gardenIngredients: [.broccoli],
            pantryIngredients: [.cheese, .eggs, .flour, .salt],
            glucoseTip: "The eggs and cheese \"dress\" the flour in this recipe! Protein and fat make sure your energy stays nice and steady.",
            steps: [
                "Chop broccoli into tiny, tiny florets.",
                "Crack an egg into a bowl and whisk it.",
                "Mix in a spoonful of flour and a pinch of salt.",
                "Add the broccoli and shredded cheese to the bowl.",
                "Stir everything together into a thick batter.",
                "Drop spoonfuls onto a greased baking sheet.",
                "Bake at 375°F for 12 minutes until golden.",
                "Let them cool a bit, then munch away!"
            ]
        ),
        Recipe(
            id: "zucchini-fritters",
            title: "Zucchini Cheese Fritters",
            description: "Crispy zucchini fritters with eggs and melted cheese — a savory protein snack!",
            imageName: "recipe_zucchini_fritters",
            category: .snacks,
            cookTime: 15,
            difficulty: .medium,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Protein", "Vitamin C", "Calcium"],
            gardenIngredients: [.zucchini],
            pantryIngredients: [.eggs, .cheese, .flour, .oliveOil, .salt],
            glucoseTip: "These fritters are packed with protein from eggs and cheese! Savory snacks keep you energized way better than candy.",
            steps: [
                "Grate the zucchini and squeeze out extra water.",
                "Crack an egg into a bowl and whisk it.",
                "Mix in flour, shredded cheese, and salt.",
                "Add the grated zucchini and stir well.",
                "Heat olive oil in a pan over medium heat.",
                "Drop spoonfuls of batter into the pan.",
                "Cook 3 minutes on each side until golden and crispy.",
                "Place on a paper towel to cool, then enjoy!"
            ]
        ),
        Recipe(
            id: "lettuce-cups",
            title: "Veggie Lettuce Cups",
            description: "Crunchy lettuce cups with chopped carrot, tomato, and cheese",
            imageName: "recipe_veggie_lettuce_cups",
            category: .snacks,
            cookTime: 10,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: false,
            nutritionFacts: ["Vitamin A", "Vitamin C", "Fiber"],
            gardenIngredients: [.lettuce, .carrot, .tomato],
            pantryIngredients: [.cheese, .salt],
            glucoseTip: "Lettuce cups are a fiber-first snack! The veggies and cheese keep you going strong until dinner time.",
            steps: [
                "Wash the lettuce and separate big leaves.",
                "Peel and dice the carrot into tiny pieces.",
                "Chop the tomato into small cubes.",
                "Cut cheese into small strips or crumbles.",
                "Place carrot, tomato, and cheese inside each lettuce leaf.",
                "Sprinkle a pinch of salt on top.",
                "Roll them up or eat them open — your choice!"
            ]
        ),

        // MARK: - Simple Butter Recipes (easy to cook early game!)

        Recipe(
            id: "buttered-carrots",
            title: "Honey Butter Carrots",
            description: "Sweet, tender carrots glazed with butter and a drizzle of honey",
            imageName: "recipe_honey_butter_carrots",
            category: .snacks,
            cookTime: 8,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin A", "Fiber", "Healthy Fats"],
            gardenIngredients: [.carrot],
            pantryIngredients: [.butter, .honey],
            glucoseTip: "Carrots are naturally sweet! The butter and honey make them extra yummy while the fiber keeps your tummy happy.",
            steps: [
                "Wash and peel the carrots.",
                "Cut them into thin sticks or coins.",
                "Melt a bit of butter in a pan.",
                "Add the carrots and cook until tender.",
                "Drizzle honey on top and stir.",
                "Let them cool a bit and enjoy!"
            ]
        ),

        Recipe(
            id: "buttered-zucchini",
            title: "Butter Zucchini Bites",
            description: "Golden pan-fried zucchini coins tossed in butter — simple and delicious!",
            imageName: "recipe_butter_zucchini",
            category: .snacks,
            cookTime: 8,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin B6", "Potassium", "Healthy Fats"],
            gardenIngredients: [.zucchini],
            pantryIngredients: [.butter],
            glucoseTip: "Zucchini is packed with vitamins! Cooking it in butter helps your body absorb all the good nutrients.",
            steps: [
                "Wash the zucchini.",
                "Cut it into round coins.",
                "Melt butter in a pan on medium heat.",
                "Place zucchini coins in the pan.",
                "Cook until golden on each side.",
                "Let them cool and munch away!"
            ]
        ),

        Recipe(
            id: "garden-yogurt-bowl",
            title: "Garden Yogurt Bowl",
            description: "Creamy Greek yogurt topped with grated carrots, honey, and a sprinkle of cinnamon",
            imageName: "recipe_garden_yogurt_bowl",
            category: .breakfast,
            cookTime: 5,
            difficulty: .easy,
            servings: 1,
            needsAdultHelp: false,
            nutritionFacts: ["Protein", "Vitamin A", "Calcium"],
            gardenIngredients: [.carrot],
            pantryIngredients: [.greekYogurt, .honey, .cinnamon],
            glucoseTip: "Starting with yogurt gives you protein first! Adding carrots and cinnamon keeps your energy smooth all morning.",
            steps: [
                "Scoop Greek yogurt into a bowl.",
                "Peel and grate the carrot into thin shreds.",
                "Sprinkle the carrot shreds on top.",
                "Drizzle a little honey over everything.",
                "Add a pinch of cinnamon.",
                "Mix and enjoy your garden bowl!"
            ]
        ),

        Recipe(
            id: "lettuce-butter-wraps",
            title: "Buttery Lettuce Wraps",
            description: "Crisp lettuce leaves with warm buttered carrots and onions inside",
            imageName: "recipe_lettuce_butter_wraps",
            category: .lunch,
            cookTime: 10,
            difficulty: .easy,
            servings: 2,
            needsAdultHelp: true,
            nutritionFacts: ["Vitamin A", "Fiber", "Vitamin K"],
            gardenIngredients: [.lettuce, .carrot, .onion],
            pantryIngredients: [.butter],
            glucoseTip: "Lettuce wraps are a smart choice! The veggies give you fiber first, which helps your body handle everything better.",
            steps: [
                "Wash lettuce leaves and pat dry.",
                "Peel and slice carrots into thin sticks.",
                "Dice the onion into small pieces.",
                "Melt butter in a pan and cook carrots and onions until soft.",
                "Scoop the warm veggies into lettuce leaves.",
                "Roll up and take a big crunchy bite!"
            ]
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
    @EnvironmentObject var gameState: GameState
    @Binding var selectedTab: MainTabView.Tab

    // Use garden recipes
    let recipes: [Recipe] = GardenRecipes.all

    // Track which category is selected
    @State private var selectedCategory: RecipeCategory = .all
    @State private var selectedRecipe: Recipe? = nil

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
                                .onTapGesture { selectedRecipe = recipe }
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
        .fullScreenCover(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe) {
                selectedTab = .kitchen
            }
        }
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
    RecipeListView(selectedTab: .constant(.recipes))
        .environmentObject(GameState.preview)
}

//
//  RecipeCardExample.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

