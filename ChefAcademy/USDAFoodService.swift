//
//  USDAFoodService.swift
//  ChefAcademy
//
//  Fetches real nutrition data from USDA FoodData Central, proxied
//  through our Cloudflare Worker so the API key stays server-side.
//  All values are per 100g. We convert to kid-friendly serving sizes.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Nutrient Profile (what we display to kids)

struct NutrientProfile: Codable {
    let foodName: String
    let calories: Double        // kcal per serving
    let protein: Double         // g
    let fiber: Double           // g
    let vitaminA: Double        // IU
    let vitaminC: Double        // mg
    let vitaminK: Double        // mcg
    let vitaminB6: Double       // mg
    let calcium: Double         // mg
    let iron: Double            // mg
    let potassium: Double       // mg
    let magnesium: Double       // mg
    let zinc: Double            // mg
    let vitaminE: Double        // mg
    let servingSizeGrams: Double

    // MARK: - Plant Pigments (USDA tracks these!)
    //
    // TEACHING MOMENT: These are the actual color compounds in plants.
    // USDA FoodData Central has nutrient numbers for them:
    //   321 = Beta-carotene (orange pigment → converts to Vitamin A)
    //   337 = Lycopene (red pigment → heart/prostate health)
    //   338 = Lutein + Zeaxanthin (yellow/green → eye health)
    // Anthocyanins (purple) are NOT in standard USDA — they're phytochemicals
    // tracked in separate research databases.
    //
    var betaCarotene: Double = 0  // mcg — USDA #321 (orange pigment)
    var lycopene: Double = 0      // mcg — USDA #337 (red pigment)
    var lutein: Double = 0        // mcg — USDA #338 (yellow/green pigment)

    /// Top nutrients for display (sorted by how "impressive" they are for kids)
    func topNutrients(count: Int = 4) -> [(name: String, value: String, organ: String, emoji: String)] {
        var results: [(name: String, value: String, organ: String, emoji: String)] = []

        // COLOR PIGMENTS FIRST — these connect to our color education system!
        if lycopene > 100 { results.append(("Lycopene", "Red power!", "Heart", "❤️")) }
        if betaCarotene > 100 { results.append(("Beta-carotene", "Orange power!", "Eyes & Skin", "👁️")) }
        if lutein > 100 { results.append(("Lutein", "Yellow-green power!", "Eyes", "👁️")) }

        // Standard nutrients
        if vitaminA > 100 { results.append(("Vitamin A", "Eye superpower!", "Eyes", "👁️")) }
        if vitaminC > 2 { results.append(("Vitamin C", "Germ-fighting superpower!", "Immune System", "🛡️")) }
        if calcium > 10 { results.append(("Calcium", "Bone-building superpower!", "Bones", "🦴")) }
        if iron > 0.3 { results.append(("Iron", "Energy superpower!", "Blood", "❤️")) }
        if potassium > 50 { results.append(("Potassium", "Heart-pumping superpower!", "Heart", "💪")) }
        if fiber > 0.5 { results.append(("Fiber", "Tummy-helping superpower!", "Tummy", "🌿")) }
        if protein > 1 { results.append(("Protein", "Muscle-building superpower!", "Muscles", "💪")) }
        if vitaminK > 5 { results.append(("Vitamin K", "Healing superpower!", "Blood", "🩸")) }
        if magnesium > 5 { results.append(("Magnesium", "Relaxation superpower!", "Muscles", "⚡")) }
        if zinc > 0.3 { results.append(("Zinc", "Shield superpower!", "Immune System", "🛡️")) }
        if vitaminE > 0.3 { results.append(("Vitamin E", "Skin-glowing superpower!", "Skin", "✨")) }
        if vitaminB6 > 0.05 { results.append(("Vitamin B6", "Brain-boosting superpower!", "Brain", "🧠")) }

        return Array(results.prefix(count))
    }
}

// MARK: - USDA API Response Models

struct USDASearchResponse: Codable {
    let foods: [USDAFood]
}

struct USDAFood: Codable {
    let fdcId: Int
    let description: String
    let foodNutrients: [USDAFoodNutrient]
}

/// Single-food endpoint nests nutrient info inside a "nutrient" object
struct USDAFoodNutrient: Codable {
    // Flat format (from /foods/search)
    let nutrientNumber: String?
    let nutrientName: String?
    let value: Double?
    let unitName: String?

    // Nested format (from /food/{id})
    let nutrient: USDANutrientDetail?
    let amount: Double?

    /// Get the nutrient number regardless of response format
    var number: String? {
        nutrientNumber ?? nutrient?.number
    }

    /// Get the nutrient value regardless of response format
    var nutrientValue: Double? {
        value ?? amount
    }
}

struct USDANutrientDetail: Codable {
    let number: String?
    let name: String?
    let unitName: String?
}

// MARK: - USDA Food Service

class USDAFoodService: ObservableObject {
    static let shared = USDAFoodService()

    private let cacheKey = "com.chefacademy.usdaNutrientCache"

    /// Cached nutrient profiles keyed by item identifier (e.g., "carrot", "eggs")
    @Published var cache: [String: NutrientProfile] = [:]

    // MARK: - FDC ID Mapping

    /// Pre-mapped FDC IDs for all game items (SR Legacy database).
    /// These are the "raw" versions of each food.
    static let fdcIDMap: [String: Int] = [
        // Vegetables (27)
        "lettuce": 169247,
        "carrot": 170393,
        "tomato": 170457,
        "cucumber": 168409,
        "broccoli": 170379,
        "zucchini": 169291,
        "onion": 170000,
        "pumpkin": 168448,
        "spinach": 168462,
        "bellPepperRed": 170108,
        "bellPepperYellow": 168578,
        "sweetPotato": 168482,
        "corn": 170288,
        "beet": 169145,
        "eggplant": 169228,
        "radish": 169276,
        "kale": 168421,
        "basil": 172232,
        "mint": 173474,
        "greenBeans": 169961,
        "strawberry": 167762,
        "watermelon": 167765,
        "avocado": 171705,
        "lemon": 167746,
        "blueberry": 171711,
        "raspberry": 167755,
        "blackberry": 173946,

        // Pantry items (19)
        "eggs": 171287,
        "salt": 170720,
        "pepper": 170931,
        "cheese": 170847,
        "oliveOil": 171413,
        "butter": 173410,
        "chicken": 171077,
        "groundBeef": 174036,
        "milk": 171265,
        "flour": 169761,
        "sugar": 169655,
        "honey": 169640,
        "garlic": 169230,
        "greekYogurt": 170886,
        "nuts": 170567,
        "cinnamon": 171320,
        "lemon_pantry": 167747,
        "tomatoSauce": 170532,
        "soySauce": 173737,
    ]

    /// Kid-friendly serving sizes in grams
    static let servingSizes: [String: Double] = [
        "lettuce": 36,       // 1 cup shredded
        "carrot": 61,        // 1 medium
        "tomato": 123,       // 1 medium
        "cucumber": 52,      // ~1/3 medium
        "broccoli": 91,      // 1 cup chopped
        "zucchini": 113,     // 1 medium
        "onion": 110,        // 1 medium
        "pumpkin": 116,      // 1 cup cubed
        "spinach": 30,       // 1 cup raw
        "bellPepperRed": 119,
        "bellPepperYellow": 119,
        "sweetPotato": 130,  // 1 medium
        "corn": 90,          // 1 ear
        "beet": 82,          // 1 medium
        "eggplant": 82,      // 1 cup cubed
        "radish": 9,         // 1 medium
        "kale": 67,          // 1 cup chopped
        "basil": 5,          // 5 leaves
        "mint": 3,           // 6 leaves
        "greenBeans": 110,   // 1 cup
        "strawberry": 152,   // 1 cup
        "watermelon": 152,   // 1 cup diced
        "avocado": 68,       // 1/2 avocado
        "lemon": 58,         // 1 medium
        "blueberry": 148,    // 1 cup
        "raspberry": 123,    // 1 cup
        "blackberry": 144,   // 1 cup
        "eggs": 50,          // 1 large
        "cheese": 28,        // 1 slice
        "chicken": 85,       // 3 oz
        "greekYogurt": 150,  // 1 container
        "nuts": 28,          // small handful
        "honey": 21,         // 1 tbsp
    ]

    // MARK: - Init

    init() {
        loadCache()
    }

    // MARK: - Public API

    /// Fetch nutrient profile for a food item. Returns cached data if available.
    func nutrientProfile(for itemKey: String) async -> NutrientProfile? {
        // Check cache first
        if let cached = cache[itemKey] {
            return cached
        }

        // Need FDC ID
        guard let fdcId = USDAFoodService.fdcIDMap[itemKey] else {
            print("[USDA] No FDC ID mapped for '\(itemKey)'")
            return nil
        }

        guard await WorkerClient.isReady() else {
            print("[USDA] Skipping fetch — App Attest not ready (running on simulator?)")
            return nil
        }

        var request = URLRequest(url: WorkerClient.usdaURL(fdcId: fdcId))
        request.timeoutInterval = 15

        // GET request → no body to bind the assertion to. Pass Data().
        let auth = await WorkerClient.authHeaders(for: Data())
        for (key, value) in auth {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let food = try JSONDecoder().decode(USDAFood.self, from: data)

            let servingGrams = USDAFoodService.servingSizes[itemKey] ?? 100
            let profile = buildProfile(from: food, servingGrams: servingGrams)

            // Cache it
            await MainActor.run {
                cache[itemKey] = profile
                saveCache()
            }

            print("[USDA] Fetched nutrients for '\(itemKey)': \(Int(profile.calories)) kcal, \(String(format: "%.1f", profile.vitaminC)) mg Vit C")
            return profile
        } catch {
            print("[USDA] Failed to fetch '\(itemKey)': \(error.localizedDescription)")
            return nil
        }
    }

    /// Batch fetch nutrients for multiple items
    func fetchAll(items: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                if cache[item] == nil {
                    group.addTask {
                        _ = await self.nutrientProfile(for: item)
                        // Small delay to respect rate limits
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    }
                }
            }
        }
    }

    // MARK: - Parse Nutrients

    private func buildProfile(from food: USDAFood, servingGrams: Double) -> NutrientProfile {
        let scale = servingGrams / 100.0 // API gives per 100g

        func nutrientValue(_ number: String) -> Double {
            (food.foodNutrients.first { $0.number == number }?.nutrientValue ?? 0) * scale
        }

        return NutrientProfile(
            foodName: food.description,
            calories: nutrientValue("208"),
            protein: nutrientValue("203"),
            fiber: nutrientValue("291"),
            vitaminA: nutrientValue("318"),
            vitaminC: nutrientValue("401"),
            vitaminK: nutrientValue("430"),
            vitaminB6: nutrientValue("415"),
            calcium: nutrientValue("301"),
            iron: nutrientValue("303"),
            potassium: nutrientValue("306"),
            magnesium: nutrientValue("304"),
            zinc: nutrientValue("309"),
            vitaminE: nutrientValue("323"),
            servingSizeGrams: servingGrams,
            // Plant pigments — the color compounds!
            betaCarotene: nutrientValue("321"),  // Orange pigment
            lycopene: nutrientValue("337"),       // Red pigment
            lutein: nutrientValue("338")          // Yellow/green pigment
        )
    }

    // MARK: - Cache

    private func saveCache() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let saved = try? JSONDecoder().decode([String: NutrientProfile].self, from: data) {
            cache = saved
        }
    }
}
