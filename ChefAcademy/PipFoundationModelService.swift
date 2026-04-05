//
//  PipFoundationModelService.swift
//  ChefAcademy
//
//  On-device AI for Pip using Apple's Foundation Models framework (iOS 26+).
//  Runs entirely on the device's Neural Engine — zero API costs, unlimited
//  questions, works offline, and conversations never leave the phone.
//
//  TEACHING MOMENT: Cloud AI vs On-Device AI
//  ┌─────────────────────┬──────────────────┬───────────────────┐
//  │                     │ Cloud (Claude)    │ On-Device (Apple) │
//  ├─────────────────────┼──────────────────┼───────────────────┤
//  │ Cost per question   │ ~$0.001          │ FREE              │
//  │ Internet needed?    │ YES              │ NO                │
//  │ Privacy             │ Data sent to API │ Stays on device   │
//  │ Rate limits         │ 20/day           │ Unlimited         │
//  │ API key needed?     │ YES (CloudKit)   │ NO                │
//  │ Response quality    │ Higher (big GPU) │ Good (Neural Eng) │
//  │ Availability        │ Any iOS          │ iOS 26+ only      │
//  └─────────────────────┴──────────────────┴───────────────────┘
//
//  KEY CONCEPTS:
//
//  1. @Generable — Instead of parsing raw text, the model outputs a typed
//     Swift struct. Apple calls this "Constrained Decoding": during token
//     generation, invalid tokens are masked based on your struct schema.
//     No parsing errors, no hallucinated JSON keys. Type safety for AI!
//
//  2. Tool Protocol — Bridges the model's training data to YOUR app's live
//     data. The model can't know what THIS kid is growing — but Tools let
//     it ask your app on demand. The model decides WHEN to call them.
//
//  3. Token Budgeting — Every word in instructions costs processing time
//     on the local Neural Engine. Shorter = faster first response.
//     Compare our Claude prompt (~400 tokens) to this one (~150 tokens).
//

import Foundation
import Combine

// MARK: - Compile-Time Guard
//
// TEACHING MOMENT: #if canImport checks at COMPILE TIME whether the
// FoundationModels framework exists in the SDK. If someone builds
// with an older Xcode (before Xcode 17), this whole file is skipped
// gracefully. The @available checks inside handle RUNTIME availability
// (does this iPhone actually support on-device AI?).
//

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Structured Response
//
// TEACHING MOMENT: @Generable tells the compiler to create a schema
// that constrains the model's output. Properties are generated in
// declaration order — "message" first, then "followUpQuestion" can
// reference what was just said (the model has the preceding context).
//
// This is WAY better than parsing raw text. With @Generable:
//   - The model CANNOT output random text — it MUST fill these fields
//   - We get typed Swift values, not strings to parse
//   - Follow-up questions come free (no extra API call!)
//

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct PipChatResponse {
    /// Pip's cheerful response — generated first so followUp has context
    @Guide(description: "Pip's cheerful 2-3 sentence response. Use simple words a 6-year-old understands. One emoji max. Be encouraging about veggies and cooking.")
    var message: String

    /// Model-generated follow-up — replaces our keyword matching!
    @Guide(description: "A fun follow-up question to keep the kid chatting about food or gardening, or nil if the conversation is wrapping up naturally")
    var followUpQuestion: String?
}

// MARK: - Game Context (Thread-Safe)
//
// TEACHING MOMENT: This is an "actor" — Swift's built-in thread safety.
// The Foundation Models framework may call tools IN PARALLEL. If two
// tools read game context simultaneously, we need protection.
// An actor automatically serializes access — only one caller at a time.
//
// Think of it like a bathroom with a lock: one person at a time,
// others wait their turn. No crashes from simultaneous access!
//

@available(iOS 26.0, macOS 26.0, *)
actor PipGameContext {
    // Basic player info
    var playerName: String = "friend"
    var growingVeggies: [String] = []
    var harvestedVeggies: [String] = []
    var cookedRecipes: [String] = []
    var coins: Int = 0

    // Pantry inventory — what the player bought from the farm shop
    var pantryItems: [String: Int] = [:]  // displayName → quantity

    // Body Buddy organ health (0-100 scale)
    var organHealth: [String: Int] = [:]

    // Weather — from WeatherKit
    var weatherCondition: String = "sunny"
    var temperature: String = ""

    func update(
        playerName: String,
        growingVeggies: [String],
        harvestedVeggies: [String],
        cookedRecipes: [String],
        coins: Int
    ) {
        self.playerName = playerName
        self.growingVeggies = growingVeggies
        self.harvestedVeggies = harvestedVeggies
        self.cookedRecipes = cookedRecipes
        self.coins = coins
    }

    // TEACHING MOMENT: Separate update methods keep concerns clean.
    // The caller decides WHAT data to push; the actor just stores it safely.
    // This avoids a single giant update() with 15+ parameters.

    func updatePantry(_ items: [String: Int]) {
        self.pantryItems = items
    }

    func updateOrganHealth(_ health: [String: Int]) {
        self.organHealth = health
    }

    func updateWeather(condition: String, temperature: String) {
        self.weatherCondition = condition
        self.temperature = temperature
    }

    func summary() -> String {
        var parts: [String] = ["Player: \(playerName)"]
        if !growingVeggies.isEmpty {
            parts.append("Growing: \(growingVeggies.joined(separator: ", "))")
        }
        if !harvestedVeggies.isEmpty {
            parts.append("Harvested: \(harvestedVeggies.joined(separator: ", "))")
        }
        if !cookedRecipes.isEmpty {
            parts.append("Cooked: \(cookedRecipes.joined(separator: ", "))")
        }
        parts.append("Coins: \(coins)")
        return parts.joined(separator: ". ")
    }

    func ingredientSummary() -> String {
        var parts: [String] = []
        if !harvestedVeggies.isEmpty {
            parts.append("Garden veggies: \(harvestedVeggies.joined(separator: ", "))")
        }
        let available = pantryItems.filter { $0.value > 0 }
        if !available.isEmpty {
            let pantryList = available.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            parts.append("Pantry: \(pantryList)")
        }
        return parts.isEmpty ? "No ingredients yet — grow some veggies and visit the farm shop!" : parts.joined(separator: ". ")
    }

    func organHealthSummary() -> String {
        if organHealth.isEmpty { return "No health data yet — cook recipes to power up your body!" }
        let sorted = organHealth.sorted { $0.value < $1.value }
        var parts: [String] = []
        // Highlight the weakest and strongest organs
        if let weakest = sorted.first {
            parts.append("Needs attention: \(weakest.key) (\(weakest.value)/100)")
        }
        if let strongest = sorted.last, sorted.count > 1 {
            parts.append("Strongest: \(strongest.key) (\(strongest.value)/100)")
        }
        let all = organHealth.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        parts.append("All organs: \(all)")
        return parts.joined(separator: ". ")
    }

    func weatherSummary() -> String {
        var result = "Weather: \(weatherCondition)"
        if !temperature.isEmpty { result += ", \(temperature)" }
        // Add month for seasonal context
        let month = Calendar.current.component(.month, from: Date())
        let monthNames = ["January","February","March","April","May","June",
                          "July","August","September","October","November","December"]
        result += ". Month: \(monthNames[month - 1])"
        return result
    }
}

// MARK: - Tool: Get Garden Status
//
// TEACHING MOMENT: Tools follow a protocol with 4 requirements:
//   1. name — short verb-based identifier (inserted into the prompt)
//   2. description — one sentence explaining what it does
//   3. Arguments — @Generable struct (the model fills this in)
//   4. call() — your code that runs when the model invokes the tool
//
// The model reads the name + description to decide WHEN to call it.
// Brief names save tokens = less latency. "getGardenStatus" not
// "retrieveCurrentGardenStatusForActivePlayer".
//
// The call() method is `@concurrent` (Swift 6.3) because the framework
// may call it from any thread, potentially in parallel with other tools.
// The return type is String (conforms to PromptRepresentable) — NOT a
// special "ToolOutput" type. The model reads this string as context.
//

@available(iOS 26.0, macOS 26.0, *)
struct GetGardenStatusTool: Tool {
    let name = "getGardenStatus"
    let description = "Get what vegetables the player is currently growing and has harvested"

    /// No input needed — we return everything about the player's garden
    @Generable
    struct Arguments {}

    let context: PipGameContext

    @concurrent func call(arguments: Arguments) async throws -> String {
        let summary = await context.summary()
        return summary
    }
}

// MARK: - Tool: Get Veggie Fact
//
// TEACHING MOMENT: This tool gives the model access to OUR curated
// facts database. The on-device model has general knowledge, but our
// hand-picked facts are kid-friendly and match our game's tone.
// The model can call this when a kid asks about a specific veggie.
//

@available(iOS 26.0, macOS 26.0, *)
struct GetVeggieFactTool: Tool {
    let name = "getVeggieFact"
    let description = "Look up a fun kid-friendly fact about a specific vegetable or fruit"

    @Generable
    struct Arguments {
        @Guide(description: "The vegetable or fruit name to look up")
        var vegetableName: String
    }

    @concurrent func call(arguments: Arguments) async throws -> String {
        let key = arguments.vegetableName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fact = Self.facts[key]
            ?? "That's a cool plant! Every veggie has its own special story."
        return fact
    }

    // Our curated facts — kid-friendly, matches all 27 VegetableType entries
    private static let facts: [String: String] = [
        "carrot": "Carrots were originally purple! Orange carrots were bred in the Netherlands in the 1600s.",
        "tomato": "Tomatoes are technically berries! People used to think they were poisonous.",
        "broccoli": "Broccoli is actually a flower that hasn't bloomed yet!",
        "lettuce": "Lettuce is part of the sunflower family. Ancient Egyptians thought it was sacred!",
        "cucumber": "Cucumbers are 95% water — they're nature's water bottle!",
        "pumpkin": "Every part of a pumpkin is edible — flowers, leaves, seeds, and flesh!",
        "onion": "Onions make you cry because they release a gas that reacts with water in your eyes!",
        "zucchini": "The biggest zucchini ever grown was over 8 feet long!",
        "spinach": "Spinach loses about 90% of its vitamin C within 24 hours of being picked!",
        "corn": "An average ear of corn has about 800 kernels arranged in 16 rows!",
        "strawberry": "Strawberries are the only fruit with seeds on the outside — about 200 per berry!",
        "watermelon": "Watermelons are 92% water and are related to cucumbers and pumpkins!",
        "avocado": "Avocados are actually berries! And they ripen only AFTER being picked.",
        "lemon": "Lemons float in water but limes sink! Lemons are less dense.",
        "blueberry": "Blueberries are one of the only naturally blue foods in the world!",
        "basil": "Basil means 'king' in Greek — ancient Greeks thought only kings should harvest it!",
        "mint": "Mint grows so fast it can take over an entire garden if you're not careful!",
        "beet": "Beets can be used as natural dye — they make beautiful pink and red colors!",
        "eggplant": "Eggplant got its name because early varieties were white and looked like eggs!",
        "radish": "Radishes were so valued in ancient Greece they made gold replicas of them!",
        "kale": "Kale can survive freezing temperatures and actually tastes sweeter after frost!",
        "sweet potato": "Sweet potatoes aren't actually related to regular potatoes at all!",
        "bell pepper": "All bell peppers start green and change color as they ripen — green to yellow to red!",
        "green beans": "Green beans are one of the few veggies that are great eaten raw or cooked!",
        "raspberry": "Each raspberry is made up of about 100 tiny individual fruits called drupelets!",
        "blackberry": "Blackberries change from green to red to black as they ripen!"
    ]
}

// MARK: - Tool: Get Nutrient Profile
//
// TEACHING MOMENT: This tool bridges AI to REAL nutrition data.
// The on-device model knows general facts about food, but our USDA
// integration has precise, kid-friendly nutrient profiles. When a
// kid asks "what's in broccoli?", the model calls this tool and gets
// back real science data — then translates it into kid-speak.
//
// The tool checks our local CACHE first (instant), then falls back
// to the USDA API if uncached. This keeps tool calls fast — the model
// waits for tool results before generating a response, so speed matters.
//

@available(iOS 26.0, macOS 26.0, *)
struct GetNutrientProfileTool: Tool {
    let name = "getNutrientProfile"
    let description = "Get real nutrition data for a food (vitamins, minerals, fiber, protein). Use when a kid asks what's healthy about a food."

    @Generable
    struct Arguments {
        @Guide(description: "Food name to look up, e.g. 'carrot', 'eggs', 'chicken'")
        var foodName: String
    }

    // TEACHING MOMENT: Thread Safety with @Published Properties
    //
    // USDAFoodService.cache is @Published, which means it's meant to be
    // read/written on the Main Actor (SwiftUI observes it from the main
    // thread). But this tool runs on a background thread (@concurrent).
    // Reading @Published from a background thread = data race.
    //
    // Fix: wrap the cache read in MainActor.run. This hops to the main
    // thread just for the dictionary lookup (microseconds), then hops back.
    // The actual USDA API fetch is async and already handles its own threading.

    @concurrent func call(arguments: Arguments) async throws -> String {
        let key = arguments.foodName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Handle plurals: "carrots" → "carrot", but verify the result is a known key
        let singular = key.hasSuffix("s") ? String(key.dropLast()) : key
        let lookupKey = USDAFoodService.fdcIDMap.keys.contains(singular) ? singular : key

        // Check USDA cache on MainActor (thread-safe access to @Published)
        let cached: NutrientProfile? = await MainActor.run {
            USDAFoodService.shared.cache[lookupKey]
        }
        if let profile = cached {
            return formatProfile(profile)
        }

        // Fetch from USDA API (async, handles its own threading)
        if let profile = await USDAFoodService.shared.nutrientProfile(for: lookupKey) {
            return formatProfile(profile)
        }

        return "I don't have detailed nutrition data for \(arguments.foodName) yet, but it's part of a healthy diet!"
    }

    private func formatProfile(_ p: NutrientProfile) -> String {
        let top = p.topNutrients(count: 5)
        var parts = ["\(p.foodName) per kid serving (\(Int(p.servingSizeGrams))g):"]
        parts.append("Calories: \(Int(p.calories))")
        if p.protein > 0.5 { parts.append("Protein: \(String(format: "%.1f", p.protein))g") }
        if p.fiber > 0.2 { parts.append("Fiber: \(String(format: "%.1f", p.fiber))g") }
        for n in top {
            parts.append("\(n.emoji) \(n.name): \(n.value) (\(n.organ))")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Tool: Get Available Ingredients
//
// TEACHING MOMENT: This is a "what can I do?" tool. The model uses it
// to answer questions like "what can I cook?" or "do I have enough to
// make pancakes?". It reads the player's LIVE inventory — both garden
// harvests and shop purchases. The model then cross-references this
// with recipe requirements to give personalized suggestions.
//

@available(iOS 26.0, macOS 26.0, *)
struct GetAvailableIngredientsTool: Tool {
    let name = "getAvailableIngredients"
    let description = "Get what ingredients the player currently has — harvested veggies and pantry items bought from the shop"

    @Generable
    struct Arguments {}

    let context: PipGameContext

    @concurrent func call(arguments: Arguments) async throws -> String {
        await context.ingredientSummary()
    }
}

// MARK: - Tool: Get Body Buddy Status
//
// TEACHING MOMENT: Personalized health advice! When a kid asks "how
// is my body doing?" or "what should I eat?", the model calls this
// tool to see which organs are weak. Then it suggests foods that
// target the weakest organ. This creates a FEEDBACK LOOP:
//   Cook recipe → organ health improves → Pip notices → suggests next goal
// The kid feels like Pip is a real nutritionist paying attention to THEM.
//

@available(iOS 26.0, macOS 26.0, *)
struct GetBodyBuddyStatusTool: Tool {
    let name = "getBodyBuddyStatus"
    let description = "Get the player's Body Buddy organ health levels (brain, heart, muscles, bones, immune, energy, eyes, skin, digestion). Use to give personalized nutrition advice."

    @Generable
    struct Arguments {}

    let context: PipGameContext

    @concurrent func call(arguments: Arguments) async throws -> String {
        await context.organHealthSummary()
    }
}

// MARK: - Generable Recipe Suggestion
//
// TEACHING MOMENT: @Generable here creates a TYPE-SAFE recipe output.
// Instead of the model returning free-form text like "you could make
// a salad with...", it fills a STRUCTURED recipe object. This means:
//   - We can render it as a proper recipe card in the UI later
//   - The model MUST provide all fields (no missing ingredients)
//   - We validate at compile time, not runtime
//
// The @Guide descriptions help the model understand what each field expects.
// Think of them as form labels on a recipe card the model is filling out.
//

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedRecipeSuggestion {
    @Guide(description: "Fun kid-friendly recipe name like 'Rainbow Veggie Bowl' or 'Superhero Scramble'")
    var name: String

    @Guide(description: "What makes this recipe special, in 1 sentence")
    var description: String

    @Guide(description: "List of ingredients the player already has that go into this recipe")
    var ingredients: [String]

    @Guide(description: "One cool nutrition fact about this recipe for a 6-year-old")
    var nutritionFact: String

    @Guide(description: "3-4 simple cooking steps for a kid")
    var steps: [String]
}

// MARK: - Tool: Generate Recipe
//
// TEACHING MOMENT: Tool chaining in action! The model might:
//   1. Call getAvailableIngredients → sees "carrot, tomato, eggs, cheese"
//   2. Call generateRecipe → suggests "Cheesy Veggie Scramble"
// The model decides the order automatically — we don't code the flow.
// Apple's framework handles multi-tool orchestration behind the scenes.
//

@available(iOS 26.0, macOS 26.0, *)
struct GenerateRecipeTool: Tool {
    let name = "generateRecipe"
    let description = "Suggest a kid-friendly recipe using the player's available ingredients. Call getAvailableIngredients first to know what they have."

    @Generable
    struct Arguments {
        @Guide(description: "Comma-separated list of available ingredients to use")
        var availableIngredients: String
    }

    @concurrent func call(arguments: Arguments) async throws -> String {
        // The model generates the recipe — this tool just provides
        // constraints. We return the ingredients back so the model
        // knows what to work with in its structured response.
        let items = arguments.availableIngredients
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if items.isEmpty {
            return "No ingredients provided. Suggest the player grow some veggies or visit the farm shop first!"
        }

        return "Available ingredients: \(items.joined(separator: ", ")). Suggest a simple, healthy, kid-friendly recipe using some or all of these. Keep it Glucose Goddess approved — veggies first, protein included, minimal starch."
    }
}

// MARK: - Tool: Get Seasonal Advice
//
// TEACHING MOMENT: This tool combines TWO data sources — WeatherKit
// (current conditions) and the calendar (month/season). The model
// uses both to give hyper-personalized planting advice like:
//   "It's March and 45°F — perfect for starting indoor seedlings!"
// vs "It's July and sunny — your tomatoes must be loving this!"
//
// Without this tool, the model would give GENERIC advice based on
// its training data. WITH the tool, it knows YOUR weather RIGHT NOW.
//

@available(iOS 26.0, macOS 26.0, *)
struct GetSeasonalAdviceTool: Tool {
    let name = "getSeasonalAdvice"
    let description = "Get current weather and season info for personalized planting and gardening advice"

    @Generable
    struct Arguments {}

    let context: PipGameContext

    @concurrent func call(arguments: Arguments) async throws -> String {
        await context.weatherSummary()
    }
}

// MARK: - Foundation Model Service
//
// TEACHING MOMENT: This class manages the on-device AI session.
// Unlike PipAIService (cloud), there's NO API key, NO network calls,
// NO rate limiting. The LanguageModelSession talks directly to the
// Neural Engine on the device. Apple handles all the model loading,
// memory management, and inference optimization.
//

@available(iOS 26.0, macOS 26.0, *)
class PipFoundationModelService: ObservableObject {

    @Published var isLoading = false
    @Published var lastError: String?

    private var session: LanguageModelSession?
    let gameContext = PipGameContext()

    // MARK: - Pip's Instructions (Token-Budgeted)
    //
    // TEACHING MOMENT: Token Budgeting — every character in these
    // instructions is processed BEFORE the first response token.
    // On a cloud GPU, this is fast. On a phone's Neural Engine,
    // instruction density directly impacts latency.
    //
    // Our Claude system prompt is ~400 tokens. This one is ~150 tokens.
    // Same Pip personality, half the wait time. We achieve this by:
    //   - Cutting redundant phrasing ("PERSONALITY:" → just describe it)
    //   - Removing rules the safety guardrails handle (no scary content)
    //   - Trusting the model's training for basic behavior
    //

    // TEACHING MOMENT: Tool Instructions — The model reads these descriptions
    // to learn WHEN to call each tool. Good instructions = the model picks
    // the right tool automatically. Bad instructions = wrong tool or no tool.
    // We keep it concise because every token costs Neural Engine processing time.
    //
    // Notice the "Use X when..." pattern — this gives the model clear
    // decision criteria. It's like teaching a new chef: "Use the big knife
    // for chopping, the small one for peeling."

    private let pipInstructions = """
        You are Pip, a cheerful hedgehog chef in a kids' kitchen garden game (ages 6+).
        Be excited about veggies and cooking! Say "Ooh!" and "Wow!" naturally.

        Rules:
        - 2-3 sentences max
        - Simple words: "good for your eyes" not "beta-carotene"
        - Topics: vegetables, fruits, cooking, gardening, nutrition, food science
        - Off-topic? Gently redirect with a food fact
        - One emoji per response max
        - End with something inviting: a question, teaser, or "wanna know more?"

        Tools — use them to give personalized answers:
        - getGardenStatus: what the player is growing and has done
        - getVeggieFact: fun facts about a specific plant
        - getNutrientProfile: real nutrition data (vitamins, minerals) for any food
        - getAvailableIngredients: what ingredients the player has right now
        - getBodyBuddyStatus: the player's organ health levels — suggest foods for weak organs
        - generateRecipe: suggest a recipe from available ingredients
        - getSeasonalAdvice: current weather and season for planting tips

        Combine tools! If asked "what should I cook?":
        1. getAvailableIngredients → see what they have
        2. getBodyBuddyStatus → see what organs need help
        3. generateRecipe → suggest something that uses their ingredients AND helps weak organs

        Example response WITH a follow-up question:
        message: "Ooh, carrots are amazing! They were actually purple before people in the Netherlands made them orange. 🥕"
        followUpQuestion: "Want to know what makes carrots good for your eyes?"

        Example response WITHOUT a follow-up (conversation wrapping up):
        message: "You're welcome! Have fun in your garden — your plants are going to love the sunshine! 🌱"
        followUpQuestion: null
        """

    // MARK: - Generation Options
    //
    // TEACHING MOMENT: GenerationOptions controls HOW the model generates text.
    //
    //   temperature — Controls randomness/creativity (0.0 to 2.0):
    //     0.0 = Deterministic: same input → same output (good for data extraction)
    //     0.7 = Balanced: varied but coherent (good for chat!)
    //     2.0 = Very random: wild, unpredictable (too chaotic for kids)
    //
    //   maximumResponseTokens — Caps output length. Fewer tokens = faster response.
    //     150 tokens ≈ 2-3 sentences, which matches Pip's personality perfectly.
    //     Without this cap, the model might ramble on, wasting Neural Engine time.
    //
    //   sampling — Controls token selection strategy:
    //     .greedy = Always picks the most likely token (deterministic, boring)
    //     .random(top: k) = Picks from top-k most likely tokens (varied, natural)
    //

    private let generationOptions = GenerationOptions(
        temperature: 0.7,
        maximumResponseTokens: 150
    )

    // MARK: - Availability Check
    //
    // TEACHING MOMENT: On-device AI is hardware-dependent. Three things
    // must be true:
    //   1. Device has A17 Pro or M-series chip (hardware capable)
    //   2. User enabled "Apple Intelligence" in Settings (opt-in)
    //   3. Model files are downloaded and ready (can take time)
    //
    // We check all three with SystemLanguageModel.default.availability.
    // If ANY condition fails, we fall back to cloud Claude seamlessly.
    //

    static var modelAvailability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    static var isModelAvailable: Bool {
        if case .available = modelAvailability { return true }
        return false
    }

    /// Human-readable message explaining why on-device AI isn't available
    static var unavailableReason: String {
        switch modelAvailability {
        case .available:
            return "On-device AI is ready!"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to chat with Pip offline!"
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support on-device AI."
        case .unavailable(.modelNotReady):
            return "Pip's brain is still downloading... try again soon!"
        default:
            return "On-device AI isn't available right now."
        }
    }

    // MARK: - Init

    init() {
        setupSession()
    }

    private func setupSession() {
        guard Self.isModelAvailable else {
            lastError = Self.unavailableReason
            return
        }

        // TEACHING MOMENT: Tools are passed at session creation.
        // The model reads tool names + descriptions to learn what's
        // available, then autonomously decides when to call them
        // based on the kid's questions. We don't manually trigger tools.
        //
        // With 7 tools, the model becomes a real personal nutritionist:
        //   - Garden + Veggie facts → knowledge base
        //   - Nutrients + Body Buddy → personalized health advice
        //   - Ingredients + Recipe gen → "what can I cook?" answers
        //   - Seasonal advice → "what should I plant?" answers
        //
        // The model can CHAIN tools — e.g., check ingredients → check
        // body health → suggest a recipe that fills both needs. We don't
        // code this logic; the model figures it out from the descriptions.

        let gardenTool = GetGardenStatusTool(context: gameContext)
        let veggieTool = GetVeggieFactTool()
        let nutrientTool = GetNutrientProfileTool()
        let ingredientsTool = GetAvailableIngredientsTool(context: gameContext)
        let bodyBuddyTool = GetBodyBuddyStatusTool(context: gameContext)
        let recipeTool = GenerateRecipeTool()
        let seasonalTool = GetSeasonalAdviceTool(context: gameContext)

        session = LanguageModelSession(
            tools: [
                gardenTool, veggieTool, nutrientTool,
                ingredientsTool, bodyBuddyTool, recipeTool, seasonalTool
            ],
            instructions: pipInstructions
        )
    }

    // MARK: - Prewarm
    //
    // TEACHING MOMENT: Like preheating an oven! Loading the AI model
    // into memory takes time. By calling prewarm() when the chat screen
    // appears (before the kid types anything), the first response comes
    // faster. It loads model weights into the Neural Engine during idle time.
    //
    // The promptPrefix parameter gives the model a HEAD START on processing.
    // We pass a typical kid question so the model pre-computes the token
    // embeddings it'll likely need. Think of it like a chef prepping
    // ingredients before the dinner rush — when the real order comes,
    // half the work is already done.
    //

    func prewarm() {
        // Pass a typical question prefix so the model pre-computes
        // token embeddings it'll likely need for food/garden questions
        let prefix = Prompt { "Tell me about" }
        session?.prewarm(promptPrefix: prefix)
    }

    // MARK: - Ask Pip (Optimized Structured Generation)
    //
    // TEACHING MOMENT: Three optimizations working together here:
    //
    //   1. includeSchemaInPrompt: false — Normally the framework injects
    //      the @Generable struct schema into the prompt (adding ~50 tokens).
    //      Setting this to false skips that injection, which means FEWER
    //      input tokens = FASTER time-to-first-token. The trade-off: we
    //      MUST include examples in our instructions showing optional
    //      properties as both populated and nil. (We did that above!)
    //
    //   2. GenerationOptions — temperature 0.7 keeps responses varied but
    //      coherent, and maximumResponseTokens: 150 prevents rambling.
    //
    //   3. Constrained Decoding — The @Generable schema still constrains
    //      the output structure even without being in the prompt. The
    //      framework enforces it at the token-masking level, not the
    //      prompt level. Schema-in-prompt is just a hint; the real
    //      enforcement happens in the decoding loop.
    //

    func ask(_ question: String) async -> PipChatResponse? {
        guard let session else {
            await MainActor.run { lastError = "Session not available" }
            return nil
        }

        await MainActor.run { isLoading = true; lastError = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response = try await session.respond(
                to: question,
                generating: PipChatResponse.self,
                includeSchemaInPrompt: false,
                options: generationOptions
            )
            return response.content

        } catch let error as LanguageModelSession.GenerationError {
            let needsReset = await MainActor.run { self.handleGenerationError(error) }
            if needsReset { setupSession() }
            return nil

        } catch {
            // Fallback: try plain text (tools still work, just no structured output)
            do {
                let plainResponse = try await session.respond(
                    to: question,
                    options: generationOptions
                )
                return PipChatResponse(
                    message: plainResponse.content,
                    followUpQuestion: nil
                )
            } catch {
                await MainActor.run {
                    self.lastError = "Something went wrong. Try again!"
                }
                return nil
            }
        }
    }

    // MARK: - Streaming Response
    //
    // TEACHING MOMENT: Streaming is the #1 UX optimization for AI chat.
    // Instead of waiting 2-3 seconds for the FULL response, we show each
    // word as it's generated. The kid sees text appearing in real-time,
    // like watching someone type. Perceived latency drops to near-zero.
    //
    // How it works with @Generable:
    //   - PipChatResponse.PartiallyGenerated makes ALL properties optional
    //   - As the model generates tokens, `message` fills in incrementally
    //   - `followUpQuestion` stays nil until the model starts generating it
    //   - We yield partial results so the UI can update live
    //
    // The stream is an AsyncSequence — perfect for SwiftUI's task/await.
    //

    func askStreaming(
        _ question: String,
        onPartial: @escaping (String) -> Void
    ) async -> PipChatResponse? {
        guard let session else {
            await MainActor.run { lastError = "Session not available" }
            return nil
        }

        await MainActor.run { isLoading = true; lastError = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let stream = session.streamResponse(
                to: question,
                generating: PipChatResponse.self,
                includeSchemaInPrompt: false,
                options: generationOptions
            )

            var finalResponse: PipChatResponse?

            for try await partial in stream {
                // partial.content is PipChatResponse.PartiallyGenerated
                // where .message is String? (filling incrementally)
                if let partialMessage = partial.content.message {
                    await MainActor.run { onPartial(partialMessage) }
                }
                // Try to extract a complete response from the partial
                if let msg = partial.content.message {
                    finalResponse = PipChatResponse(
                        message: msg,
                        followUpQuestion: partial.content.followUpQuestion
                    )
                }
            }

            return finalResponse

        } catch let error as LanguageModelSession.GenerationError {
            let needsReset = await MainActor.run { self.handleGenerationError(error) }
            if needsReset { setupSession() }
            return nil
        } catch {
            await MainActor.run {
                self.lastError = "Something went wrong. Try again!"
            }
            return nil
        }
    }

    // MARK: - Error Handling

    /// Returns true if the session needs to be recreated (context overflow)
    private func handleGenerationError(_ error: LanguageModelSession.GenerationError) -> Bool {
        switch error {
        case .guardrailViolation, .refusal:
            self.lastError = "Pip can't talk about that topic! Let's chat about veggies instead."
            return false
        case .exceededContextWindowSize:
            // Don't call setupSession() here — we're inside MainActor.run.
            // Creating a LanguageModelSession on the main thread could block.
            // Return true so the caller can recreate the session outside MainActor.
            self.lastError = "Whew, we chatted a LOT! Let's start fresh."
            return true
        case .rateLimited:
            self.lastError = "Pip needs a quick breather. Try again in a moment!"
            return false
        default:
            self.lastError = "Pip got a little confused. Try asking again!"
            return false
        }
    }

    // MARK: - Clear Conversation
    //
    // TEACHING MOMENT: Unlike the Claude API where we manually manage
    // a conversationHistory array, LanguageModelSession has a built-in
    // transcript. To "clear" the conversation, we create a new session.
    // The old session and its transcript are garbage collected automatically.
    //

    func clearConversation() {
        setupSession()
    }

    // MARK: - Update Game Context
    //
    // TEACHING MOMENT: We have separate update methods now instead of
    // one giant method with 15+ parameters. This follows the "Single
    // Responsibility" principle — each method updates one concern.
    // The AskPipView calls all of them on appear, but they could also
    // be called independently (e.g., weather changes mid-session).

    func updateGameContext(
        playerName: String,
        growingVeggies: [String],
        harvestedVeggies: [String],
        cookedRecipes: [String],
        coins: Int
    ) {
        Task {
            await gameContext.update(
                playerName: playerName,
                growingVeggies: growingVeggies,
                harvestedVeggies: harvestedVeggies,
                cookedRecipes: cookedRecipes,
                coins: coins
            )
        }
    }

    func updatePantryContext(items: [String: Int]) {
        Task { await gameContext.updatePantry(items) }
    }

    func updateOrganHealthContext(health: [String: Int]) {
        Task { await gameContext.updateOrganHealth(health) }
    }

    func updateWeatherContext(condition: String, temperature: String) {
        Task { await gameContext.updateWeather(condition: condition, temperature: temperature) }
    }
}

#endif // canImport(FoundationModels)
