//
//  PipStaticResponses.swift
//  ChefAcademy
//
//  Pre-written Pip-voice responses for base-tier users (no subscription).
//  These let Pip still feel alive without burning API calls.
//
//  Every curated starter question has a hand-written answer here.
//  Open-ended questions ("Invent me a recipe", "Surprise me") return
//  `.requiresPremium` so the caller can present the paywall.
//
//  One dynamic answer is supported locally — "What can I cook right now?" —
//  which runs the exact same ready-recipe logic as the Kitchen, no AI needed.
//

import Foundation

// MARK: - Response

enum PipResponseMode: Equatable {
    /// A pre-written or locally-computed Pip response.
    case text(String)

    /// Question needs the AI backend. Caller should present PaywallView.
    case requiresPremium
}

// MARK: - Static Responses

enum PipStaticResponses {

    /// Look up a Pip response for a curated starter question.
    /// Returns `.requiresPremium` for questions that need real AI generation.
    static func response(for question: String, gameState: GameState) -> PipResponseMode {
        // Normalize so case and punctuation don't matter
        let key = normalize(question)

        // Dynamic: runs local game-state logic (no AI cost, no paywall)
        if key.contains("what can i cook") {
            return .text(cookableRecipesAnswer(gameState: gameState))
        }

        // Premium-gated — these need real recipe generation
        if key.contains("invent me a recipe") ||
           key.contains("surprise me with a new recipe") ||
           key.contains("surprise me with something cool") ||
           key.contains("generate a new recipe") {
            return .requiresPremium
        }

        // Static lookup
        if let response = canned[key] {
            return .text(response)
        }

        // Unknown question — if it was typed freely, that's premium territory
        return .requiresPremium
    }

    /// A random "fun food fact" for the wildcard chips.
    static func randomFunFact() -> String {
        funFacts.randomElement() ?? "Ooh, food is amazing! Did you know carrots used to be purple? 🥕"
    }

    // MARK: - Canned Answers (hand-written in Pip's voice)

    private static let canned: [String: String] = [
        // ---- Garden ----
        "what veggie grows the fastest":
            "Ooh, radishes! They go from seed to snack in about 3 weeks. 🌱 Tiny but mighty — wanna plant some?",
        "how do plants drink water":
            "Plants slurp water up through their roots, like a tiny straw! Then it travels all the way to the leaves. Cool, right?",
        "can i grow strawberries at home":
            "Totally! Strawberries love sunny spots and they're super fun to grow. The red ones you pick are actually sweeter than store-bought! 🍓",
        "why do we put seeds in dirt":
            "Dirt gives seeds a cozy home with food, water, and warmth — like a little underground hotel! Then they wake up and grow. Magical!",

        // ---- Cooking ----
        "what's the easiest thing to cook":
            "A veggie wrap! You just pile stuff on a leaf and roll it up. No fire, no waiting — instant yum! 🥬",
        "why do we wash veggies before eating":
            "To rinse off tiny dirt, bugs, and farm dust! Veggies grow outside, so they like a little shower before they join your plate. 💧",
        "how does heat cook food":
            "Heat wiggles the tiny bits inside food so fast, they change! That's why a soft egg turns firm or why onions go sweet. Science = magic!",
        "what's your favorite recipe, pip":
            "Ooh, Veggie Omelette! Eggs, peppers, cheese… all cooked together. Fluffy, warm, and SO quick. Wanna try it? 🍳",

        // ---- Fun Facts ----
        "why are carrots orange":
            "Plot twist: carrots were actually PURPLE for thousands of years! Dutch farmers bred them orange in the 1600s. 🥕 Wild, huh?",
        "what's the biggest fruit ever":
            "A jackfruit! They can grow bigger than your BACKPACK and weigh more than you. One fruit feeds a whole family!",
        "why do onions make you cry":
            "Cut onions send out a sneaky gas that tickles your eyes! Your eyes water to wash it away. Nature's super-sneeze. 🧅",
        "are tomatoes a fruit or veggie":
            "Trick question! Scientifically, tomatoes are fruit (they have seeds inside)! But we cook them like veggies. Double identity. 🍅",

        // ---- Nutrition ----
        "why is broccoli good for me":
            "Broccoli is a little tree packed with vitamin C to fight germs AND vitamin K to help you heal. Superhero of the plate! 🥦",
        "what veggies can i eat raw":
            "Carrots, cucumber, bell peppers, cherry tomatoes, snap peas, lettuce — all crunchy right off the plant! Rinse and munch!",
        "which foods make you strong":
            "Foods with PROTEIN! Eggs, chicken, beans, and cheese build your muscles. Think of it as food-fuel for your arm power! 💪",
        "what gives you the most energy":
            "Fruits and whole foods! They're slow, steady fuel — not a sugar crash. Apples and oranges keep you zooming all day!",
    ]

    // MARK: - Fun Facts Wildcard Pool

    private static let funFacts: [String] = [
        "Ooh, did you know bananas are berries but strawberries aren't? Fruit science is WEIRD! 🍌",
        "Watermelons are 92% water — basically a drink disguised as a fruit! 🍉",
        "An ear of corn has about 800 kernels in 16 rows. Always 16! Nature loves patterns. 🌽",
        "Potatoes can grow eyes — but not for seeing! Those are tiny sprouts trying to become new plants. 🥔",
        "Honey never spoils! Archaeologists found 3,000-year-old honey in Egypt… still edible. 🍯",
        "Pineapples take about TWO YEARS to grow. Worth the wait! 🍍",
        "Pumpkins are 90% water. That's why they're SO heavy! 🎃",
        "Apples float because they're 25% air inside! That's how we bob for them. 🍎",
        "A strawberry has about 200 seeds — all on the OUTSIDE! 🍓",
        "Lemons are actually heavier than limes, even though they look about the same size. Science!",
        "The world's smallest veggie? Wild baby cucumbers — tiny as your fingernail! 🥒",
        "Blueberries have a natural white powder on them — it's called 'bloom' and it protects them! 🫐",
        "Chili peppers don't actually burn you — they just trick your brain into thinking they do! 🌶️",
        "Mushrooms are more like animals than plants. They breathe in oxygen just like us! 🍄",
        "One tomato plant can make 200+ tomatoes in a season. That's a LOT of salads! 🍅",
        "Carrots grown in space taste the same as Earth carrots. Scientists checked! 🚀🥕",
        "Garlic used to be given as money in ancient Egypt. Imagine paying with onions!",
        "Avocados are technically berries. Yep — berries with one giant seed. 🥑",
        "A single cob of corn came from one tiny seed. Plants multiply HARD. 🌽",
        "Peppers get their spicy feeling from a chemical called capsaicin — pronounced 'cap-SAY-sin'!",
        "Grapes explode in the microwave. Don't try it! (But it's a cool science fact.) 🍇",
        "Ginger and turmeric are actually ROOTS, not spices — we dry them to make the powders!",
        "Celery has negative calories — meaning you burn more energy chewing than it gives you! Amazing, right?",
        "Bees have to visit about 2 million flowers to make one jar of honey. Busy little workers! 🐝🍯",
        "Cauliflower, broccoli, kale, and cabbage are all the SAME species — just bred differently!",
        "A green apple can have MORE sugar than a red one. Looks can fool you! 🍏",
        "Cinnamon comes from tree bark! We peel and dry it into those curly sticks.",
        "Vanilla is the SECOND most expensive spice in the world — because vanilla flowers bloom for just one day!",
        "Eggs come in blue, green, white, and brown — all depends on the chicken breed! 🥚",
        "Ancient Romans paid soldiers in salt — that's where the word 'salary' comes from!"
    ]

    // MARK: - Dynamic: "What can I cook right now?"

    private static func cookableRecipesAnswer(gameState: GameState) -> String {
        let harvested = gameState.harvestedIngredients
        let pantry = gameState.pantryInventory
        let allergens = gameState.activeAllergens

        let safeRecipes = GardenRecipes.all.filter { !$0.containsAllergens(allergens) }

        let ready = safeRecipes.filter {
            $0.canCookFull(harvestedIngredients: harvested, pantryInventory: pantry)
        }

        if let first = ready.first {
            if ready.count == 1 {
                return "Ooh, you can make \(first.title) right now! Want to head to the Kitchen? 🍳"
            }
            let names = ready.prefix(3).map(\.title).joined(separator: ", ")
            return "You can cook \(ready.count) recipes right now — like \(names)! Which one sounds yummy?"
        }

        // Nothing fully ready — find closest almost-ready recipe
        let almost: [(Recipe, [PantryItem])] = safeRecipes.compactMap { recipe in
            guard recipe.canCook(with: harvested),
                  !recipe.canCookFull(harvestedIngredients: harvested, pantryInventory: pantry) else {
                return nil
            }
            return (recipe, recipe.missingPantryItems(from: pantry))
        }

        if let (recipe, missing) = almost.min(by: { $0.1.count < $1.1.count }) {
            let missingNames = missing.map(\.displayName).joined(separator: " and ")
            return "You're SO close to \(recipe.title) — just need \(missingNames) from the Farm Shop! Wanna grab it?"
        }

        // Nothing at all — nudge toward garden
        return "Nothing's ready yet! Let's grow some veggies first — head to the Garden and plant a seed. 🌱"
    }

    // MARK: - Normalization

    private static func normalize(_ question: String) -> String {
        question
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ".", with: "")
    }
}
