//
//  BodyBuddyView.swift
//  ChefAcademy
//
//  Body Buddy — see how food travels through your body!
//  Shows health stats from cooking, cooked recipe history,
//  and how each organ system benefits from what you eat.
//

import SwiftUI

struct BodyBuddyView: View {
    @EnvironmentObject var gameState: GameState
    @Binding var selectedTab: MainTabView.Tab

    @State private var animateRings = false
    @State private var selectedRecipeID: String?

    /// Recipes this player has cooked (with stars)
    private var cookedRecipes: [(recipe: Recipe, stars: Int)] {
        GardenRecipes.all.compactMap { recipe in
            let stars = gameState.recipeStars[recipe.id] ?? 0
            guard stars > 0 else { return nil }
            return (recipe, stars)
        }
    }

    /// Has the player cooked anything?
    private var hasCookedSomething: Bool {
        !cookedRecipes.isEmpty
    }

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Body Buddy")
                                .font(.AppTheme.largeTitle)
                                .foregroundColor(Color.AppTheme.darkBrown)
                            Text(hasCookedSomething
                                 ? "You've cooked \(cookedRecipes.count) recipe\(cookedRecipes.count == 1 ? "" : "s")!"
                                 : "Cook recipes to power up your body!")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Body figure with ALL organ systems
                    organSystemsSection
                        .padding(.horizontal, AppSpacing.md)

                    // Cooked recipes section
                    if hasCookedSomething {
                        cookedRecipesSection
                    }

                    // Pip message — context-aware
                    pipMessageSection
                        .padding(.horizontal, AppSpacing.md)

                    // Cook button
                    Button(action: { selectedTab = .kitchen }) {
                        HStack {
                            Image(systemName: "fork.knife")
                            Text(hasCookedSomething ? "Cook More!" : "Cook Something!")
                        }
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.md)

                    Spacer().frame(height: 80)
                }
                .padding(.top, AppSpacing.md)
            }
        }
        .onAppear {
            // Animate rings when view appears
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animateRings = true
            }
        }
    }

    // MARK: - Organ Systems (animated bar style)

    private struct OrganData: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let value: Int
        let color: Color
    }

    /// Calculate organ values from what was actually cooked
    private var allOrgans: [OrganData] {
        // Calculate Eyes/Digestion/Skin from actual recipe nutrients
        var eyesScore = 50
        var digestionScore = 50
        var skinScore = 50

        for recipe in cookedRecipes {
            for vegType in recipe.recipe.gardenIngredients {
                for nutrient in vegType.nutrients {
                    switch nutrient {
                    case .vitaminA: eyesScore = min(100, eyesScore + recipe.stars * 2)
                    case .vitaminE: skinScore = min(100, skinScore + recipe.stars * 2)
                    case .fiber, .probiotics: digestionScore = min(100, digestionScore + recipe.stars * 2)
                    default: break
                    }
                }
            }
            for pantryItem in recipe.recipe.pantryIngredients {
                for nutrient in pantryItem.nutrients {
                    switch nutrient {
                    case .vitaminA: eyesScore = min(100, eyesScore + recipe.stars)
                    case .vitaminE: skinScore = min(100, skinScore + recipe.stars)
                    case .fiber, .probiotics: digestionScore = min(100, digestionScore + recipe.stars)
                    default: break
                    }
                }
            }
        }

        return [
            OrganData(icon: "brain.head.profile", label: "Brain", value: gameState.brainHealth, color: Color.AppTheme.darkBrown),
            OrganData(icon: "heart.fill", label: "Heart", value: gameState.heartHealth, color: Color.AppTheme.terracotta),
            OrganData(icon: "shield.fill", label: "Immune", value: gameState.immuneHealth, color: Color.AppTheme.sage),
            OrganData(icon: "figure.strengthtraining.traditional", label: "Muscles", value: gameState.muscleHealth, color: Color.AppTheme.goldenWheat),
            OrganData(icon: "bone.fill", label: "Bones", value: gameState.boneHealth, color: Color.AppTheme.warmKhaki),
            OrganData(icon: "bolt.fill", label: "Energy", value: gameState.energyLevel, color: Color.AppTheme.goldenWheat),
            OrganData(icon: "eye.fill", label: "Eyes", value: eyesScore, color: Color.AppTheme.softOlive),
            OrganData(icon: "leaf.fill", label: "Digestion", value: digestionScore, color: Color.AppTheme.sage),
            OrganData(icon: "sparkles", label: "Skin", value: skinScore, color: Color.AppTheme.terracotta),
        ]
    }

    private var organSystemsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            // Big body figure with small health orbs around it
            ZStack {
                // Large body silhouette
                Image(systemName: "figure.stand")
                    .font(.system(size: 200))
                    .foregroundColor(Color.AppTheme.sepia.opacity(0.08))

                // Health orbs positioned around the body
                let organs = allOrgans

                // Brain — top center
                HealthOrb(icon: organs[0].icon, label: organs[0].label,
                          value: organs[0].value, color: organs[0].color, animate: animateRings)
                    .offset(y: -110)

                // Heart — left chest
                HealthOrb(icon: organs[1].icon, label: organs[1].label,
                          value: organs[1].value, color: organs[1].color, animate: animateRings)
                    .offset(x: -70, y: -40)

                // Immune — right chest
                HealthOrb(icon: organs[2].icon, label: organs[2].label,
                          value: organs[2].value, color: organs[2].color, animate: animateRings)
                    .offset(x: 70, y: -40)

                // Muscles — left mid
                HealthOrb(icon: organs[3].icon, label: organs[3].label,
                          value: organs[3].value, color: organs[3].color, animate: animateRings)
                    .offset(x: -80, y: 30)

                // Bones — right mid
                HealthOrb(icon: organs[4].icon, label: organs[4].label,
                          value: organs[4].value, color: organs[4].color, animate: animateRings)
                    .offset(x: 80, y: 30)

                // Energy — bottom center
                HealthOrb(icon: organs[5].icon, label: organs[5].label,
                          value: organs[5].value, color: organs[5].color, animate: animateRings)
                    .offset(y: 100)
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)

            // Additional systems as mini row
            HStack(spacing: AppSpacing.lg) {
                let organs = allOrgans
                if organs.count > 6 {
                    MiniOrb(icon: organs[6].icon, label: organs[6].label, color: organs[6].color)
                    MiniOrb(icon: organs[7].icon, label: organs[7].label, color: organs[7].color)
                    MiniOrb(icon: organs[8].icon, label: organs[8].label, color: organs[8].color)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }

    // MARK: - Cooked Recipes Section

    private var cookedRecipesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("What You've Cooked")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
                .padding(.horizontal, AppSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(cookedRecipes, id: \.recipe.id) { item in
                        CookedRecipeCard(
                            recipe: item.recipe,
                            stars: item.stars,
                            isSelected: selectedRecipeID == item.recipe.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                if selectedRecipeID == item.recipe.id {
                                    selectedRecipeID = nil
                                } else {
                                    selectedRecipeID = item.recipe.id
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }

            // Show nutrient breakdown for selected recipe
            if let recipeID = selectedRecipeID,
               let recipe = GardenRecipes.all.first(where: { $0.id == recipeID }) {
                RecipeNutrientBreakdown(recipe: recipe, stars: gameState.recipeStars[recipeID] ?? 1)
                    .padding(.horizontal, AppSpacing.md)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Pip Message

    private var pipMessageSection: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            PipWavingAnimatedView(size: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)
                Text(pipMessage)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .padding(AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
    }

    private var pipMessage: String {
        if !hasCookedSomething {
            return "Cook healthy recipes to make your Body Buddy stronger! Each veggie helps different parts of your body."
        } else if gameState.brainHealth >= 80 && gameState.heartHealth >= 80 {
            return "Your Body Buddy is super strong! Keep cooking to stay healthy!"
        } else {
            // Find weakest organ
            let organs = [
                ("Brain", gameState.brainHealth), ("Heart", gameState.heartHealth),
                ("Muscles", gameState.muscleHealth), ("Bones", gameState.boneHealth),
                ("Immune System", gameState.immuneHealth), ("Energy", gameState.energyLevel)
            ]
            if let weakest = organs.min(by: { $0.1 < $1.1 }) {
                return "Your \(weakest.0) could use a boost! Try cooking recipes with veggies that help your \(weakest.0.lowercased())."
            }
            return "Keep cooking to power up your Body Buddy!"
        }
    }
}

// MARK: - Cooked Recipe Card

struct CookedRecipeCard: View {
    let recipe: Recipe
    let stars: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(recipe.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(recipe.title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 1) {
                ForEach(0..<stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                }
            }
        }
        .frame(width: 85)
        .padding(AppSpacing.xs)
        .background(isSelected ? Color.AppTheme.sage.opacity(0.15) : Color.AppTheme.warmCream)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.AppTheme.sage : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Recipe Nutrient Breakdown (shown when tapping a cooked recipe)

struct RecipeNutrientBreakdown: View {
    let recipe: Recipe
    let stars: Int

    @State private var animateOrgans = false

    /// Organs boosted by this recipe
    private var organBoosts: [(organ: String, icon: String, color: Color, boost: Int)] {
        var organs: [String: Int] = [:]

        for vegType in recipe.gardenIngredients {
            for nutrient in vegType.nutrients {
                organs[nutrient.benefitsOrgan, default: 0] += stars
            }
        }
        for pantryItem in recipe.pantryIngredients {
            for nutrient in pantryItem.nutrients {
                organs[nutrient.benefitsOrgan, default: 0] += stars
            }
        }

        return organs.sorted { $0.value > $1.value }.map { organ, boost in
            let (icon, color): (String, Color) = organDisplay(organ)
            return (organ, icon, color, boost)
        }
    }

    private func organDisplay(_ organ: String) -> (String, Color) {
        switch organ {
        case "Brain": return ("brain.head.profile", Color.AppTheme.darkBrown)
        case "Heart": return ("heart.fill", Color.AppTheme.terracotta)
        case "Blood": return ("drop.fill", Color.AppTheme.terracotta)
        case "Muscles": return ("figure.strengthtraining.traditional", Color.AppTheme.goldenWheat)
        case "Bones": return ("bone.fill", Color.AppTheme.warmKhaki)
        case "Immune System": return ("shield.fill", Color.AppTheme.sage)
        case "Energy", "Whole Body": return ("bolt.fill", Color.AppTheme.goldenWheat)
        case "Eyes": return ("eye.fill", Color.AppTheme.softOlive)
        case "Skin": return ("sparkles", Color.AppTheme.terracotta)
        case "Digestive System": return ("leaf.fill", Color.AppTheme.sage)
        default: return ("staroflife.fill", Color.AppTheme.sage)
        }
    }

    @ObservedObject private var usdaService = USDAFoodService.shared
    @State private var usdaProfiles: [String: NutrientProfile] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("This recipe powers up:")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)

            // Animated organ boost bars with USDA superpowers
            ForEach(Array(organBoosts.enumerated()), id: \.element.organ) { index, item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16))
                            .foregroundColor(item.color)
                            .frame(width: 24)

                        Text(item.organ)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: 70, alignment: .leading)

                        // Animated bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(item.color.opacity(0.15))

                                Capsule()
                                    .fill(item.color)
                                    .frame(width: animateOrgans ? geo.size.width * min(Double(item.boost) / 15.0, 1.0) : 0)
                            }
                        }
                        .frame(height: 10)

                        Text("+\(item.boost)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(item.color)
                            .frame(width: 30)
                    }

                    // USDA kid-friendly superpower for this organ
                    if let superpower = superpowerForOrgan(item.organ) {
                        Text(superpower)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .padding(.leading, 36)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateOrgans = true
            }
            // Fetch USDA data for recipe ingredients
            Task {
                for vegType in recipe.gardenIngredients {
                    if let profile = await usdaService.nutrientProfile(for: vegType.rawValue) {
                        await MainActor.run { usdaProfiles[vegType.rawValue] = profile }
                    }
                }
            }
        }
        .onChange(of: organBoosts.map(\.organ).joined()) { _, _ in
            animateOrgans = false
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateOrgans = true
            }
        }
    }

    /// Kid-friendly superpower text for each organ based on USDA data
    private func superpowerForOrgan(_ organ: String) -> String? {
        // Check if any ingredient has strong amounts for this organ's nutrients
        for (_, profile) in usdaProfiles {
            switch organ {
            case "Brain":
                if profile.vitaminB6 > 0.1 { return "Brain fuel for super thinking!" }
            case "Heart":
                if profile.potassium > 100 { return "Keeps your heart beating strong!" }
            case "Immune System":
                if profile.vitaminC > 20 { return "Germ-fighting superpower!" }
                if profile.zinc > 0.5 { return "Shield for your body!" }
            case "Muscles":
                if profile.protein > 3 { return "Muscle builder!" }
                if profile.magnesium > 10 { return "Helps muscles work!" }
            case "Bones":
                if profile.calcium > 20 { return "Makes bones super strong!" }
                if profile.vitaminK > 10 { return "Helps bones grow!" }
            case "Energy":
                if profile.calories > 30 { return "Power fuel for your day!" }
            case "Eyes":
                if profile.vitaminA > 100 { return "Helps you see in the dark!" }
            case "Digestive System":
                if profile.fiber > 1 { return "Tummy's best friend!" }
            case "Skin":
                if profile.vitaminE > 0.3 { return "Keeps your skin glowing!" }
            default: break
            }
        }
        return nil
    }
}

// MARK: - Health Orb (animated ring)

struct HealthOrb: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    var animate: Bool = false

    private var progress: Double {
        min(Double(value) / 100.0, 1.0)
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: animate ? progress : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: animate)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.sepia)
        }
    }
}

// MARK: - Mini Orb (for additional systems — no ring, just icon + label)

struct MiniOrb: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.sepia)
        }
    }
}

#Preview {
    BodyBuddyView(selectedTab: .constant(.bodyBuddy))
        .environmentObject(GameState())
}
