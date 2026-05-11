//
//  GlucoseJourneyView.swift
//  ChefAcademy
//
//  Post-cooking interactive journey showing how the kid's healthy meal
//  travels through the body. 3 interactive phases + Smart Snack quiz.
//
//  Based on Glucose Revolution by Jessie Inchauspe.
//

import SwiftUI

// MARK: - Snack Choice Data

struct SnackOption: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let sugarGrams: Double
    let isHealthy: Bool
    let pipExplanation: String

    var sugarCubes: Int { Int(ceil(sugarGrams / 4.0)) }
}

struct SnackQuizRound: Identifiable {
    let id = UUID()
    let healthy: SnackOption
    let unhealthy1: SnackOption
    let unhealthy2: SnackOption

    var shuffled: [SnackOption] {
        [healthy, unhealthy1, unhealthy2].shuffled()
    }
}

// MARK: - Snack Quiz Bank

struct SnackQuizBank {
    static let rounds: [SnackQuizRound] = [
        SnackQuizRound(
            healthy: SnackOption(name: "Apple slices & nuts", emoji: "🍎", sugarGrams: 11, isHealthy: true,
                                 pipExplanation: "Smart choice! Apples have natural sugar, but the fiber and nut fat keep your glucose super steady!"),
            unhealthy1: SnackOption(name: "Frosted Cornflakes", emoji: "🥣", sugarGrams: 12, isHealthy: false,
                                    pipExplanation: "Cornflakes have 12g of sugar — that's 3 sugar cubes! And almost no fiber to slow it down."),
            unhealthy2: SnackOption(name: "Chocolate bar", emoji: "🍫", sugarGrams: 24, isHealthy: false,
                                    pipExplanation: "A chocolate bar has 24g of sugar — that's 6 sugar cubes! Your mitochondria would be overwhelmed!")
        ),
        SnackQuizRound(
            healthy: SnackOption(name: "Carrot sticks & hummus", emoji: "🥕", sugarGrams: 3, isHealthy: true,
                                 pipExplanation: "Carrots have fiber AND beta-carotene for your eyes! Hummus adds protein — perfect combo!"),
            unhealthy1: SnackOption(name: "Fruit juice box", emoji: "🧃", sugarGrams: 22, isHealthy: false,
                                    pipExplanation: "Juice has 22g of sugar with NO fiber! A whole orange is way better — the fiber makes all the difference."),
            unhealthy2: SnackOption(name: "Gummy bears", emoji: "🍬", sugarGrams: 18, isHealthy: false,
                                    pipExplanation: "Gummy bears are 18g of pure sugar — no fiber, no protein, no vitamins. Just a big glucose spike!")
        ),
        SnackQuizRound(
            healthy: SnackOption(name: "Greek yogurt & berries", emoji: "🫐", sugarGrams: 9, isHealthy: true,
                                 pipExplanation: "Greek yogurt has protein to slow glucose, and berries add antioxidants! The natural sugar comes with fiber!"),
            unhealthy1: SnackOption(name: "Can of soda", emoji: "🥤", sugarGrams: 39, isHealthy: false,
                                    pipExplanation: "A can of soda has 39g of sugar — almost 10 sugar cubes! That's the biggest spike you can get!"),
            unhealthy2: SnackOption(name: "White bread & jam", emoji: "🍞", sugarGrams: 15, isHealthy: false,
                                    pipExplanation: "White bread turns into glucose fast, and jam adds more sugar on top — 15g total with barely any fiber.")
        ),
        SnackQuizRound(
            healthy: SnackOption(name: "Cucumber & cheese", emoji: "🥒", sugarGrams: 2, isHealthy: true,
                                 pipExplanation: "Only 2g of sugar! Cucumber has water and fiber, cheese has protein and fat — super smooth!"),
            unhealthy1: SnackOption(name: "Pop-Tart", emoji: "🍩", sugarGrams: 16, isHealthy: false,
                                    pipExplanation: "A Pop-Tart has 16g of sugar — 4 cubes! It's mostly refined flour and sugar."),
            unhealthy2: SnackOption(name: "Sports drink", emoji: "⚡", sugarGrams: 21, isHealthy: false,
                                    pipExplanation: "Sports drinks have 21g of sugar! They're made for athletes running marathons, not for a snack.")
        ),
        SnackQuizRound(
            healthy: SnackOption(name: "Handful of almonds", emoji: "🌰", sugarGrams: 1, isHealthy: true,
                                 pipExplanation: "Only 1g of sugar! Almonds have healthy fats and protein — steady energy for hours!"),
            unhealthy1: SnackOption(name: "Candy bar", emoji: "🍬", sugarGrams: 30, isHealthy: false,
                                    pipExplanation: "A candy bar has 30g of sugar — almost 8 sugar cubes! Most is fructose, which can only become fat."),
            unhealthy2: SnackOption(name: "Sugary cereal", emoji: "🥣", sugarGrams: 13, isHealthy: false,
                                    pipExplanation: "Sugary cereal has 13g of sugar per bowl — and you probably pour more than one serving!")
        ),
        SnackQuizRound(
            healthy: SnackOption(name: "Celery & peanut butter", emoji: "🥜", sugarGrams: 3, isHealthy: true,
                                 pipExplanation: "Celery is mostly water and fiber, peanut butter has healthy fats — glucose stays flat!"),
            unhealthy1: SnackOption(name: "Ice cream cone", emoji: "🍦", sugarGrams: 20, isHealthy: false,
                                    pipExplanation: "Ice cream has 20g of sugar — 5 cubes! The fat slows it a tiny bit, but that's still a lot."),
            unhealthy2: SnackOption(name: "Fruit roll-up", emoji: "🍭", sugarGrams: 7, isHealthy: false,
                                    pipExplanation: "Fruit roll-ups sound healthy but they're 7g of pure sugar with zero real fruit fiber!")
        ),
        SnackQuizRound(
            healthy: SnackOption(name: "Hard-boiled egg", emoji: "🥚", sugarGrams: 0, isHealthy: true,
                                 pipExplanation: "Zero sugar! Eggs are pure protein and healthy fat — your muscles and brain love them!"),
            unhealthy1: SnackOption(name: "Donut", emoji: "🍩", sugarGrams: 22, isHealthy: false,
                                    pipExplanation: "A donut has 22g of sugar PLUS refined flour — that's a double glucose spike!"),
            unhealthy2: SnackOption(name: "Chocolate milk", emoji: "🥛", sugarGrams: 24, isHealthy: false,
                                    pipExplanation: "Chocolate milk has 24g of sugar — 6 cubes! Plain milk has only 5g of natural sugar.")
        ),
        SnackQuizRound(
            healthy: SnackOption(name: "Cherry tomatoes", emoji: "🍅", sugarGrams: 3, isHealthy: true,
                                 pipExplanation: "Tomatoes have lycopene for your heart, fiber for slow glucose, and only 3g of natural sugar!"),
            unhealthy1: SnackOption(name: "Cookies (3 pack)", emoji: "🍪", sugarGrams: 18, isHealthy: false,
                                    pipExplanation: "Three cookies have 18g of sugar — fructose AND glucose hitting at the same time!"),
            unhealthy2: SnackOption(name: "Sweetened iced tea", emoji: "🧋", sugarGrams: 26, isHealthy: false,
                                    pipExplanation: "Sweetened iced tea has 26g of sugar — almost as much as soda!")
        ),
    ]

    static func randomRound() -> SnackQuizRound {
        rounds.randomElement() ?? rounds[0]
    }
}

// MARK: - Ingredient Role (for Tummy phase)

enum IngredientRole {
    case fiber      // Veggies — thickens tummy wall
    case protein    // Eggs, chicken — makes glucose queue
    case fat        // Oil, butter, cheese — coats glucose
    case acid       // Vinegar, lemon, cinnamon — Glucose Goddess hack, slows gastric emptying

    var label: String {
        switch self {
        case .fiber: return "Fiber"
        case .protein: return "Protein"
        case .fat: return "Fat"
        case .acid: return "Glucose Hack"
        }
    }

    var color: Color {
        switch self {
        case .fiber: return Color.AppTheme.sage
        case .protein: return Color.AppTheme.terracotta
        case .fat: return Color.AppTheme.goldenWheat
        case .acid: return Color.AppTheme.warmKhaki
        }
    }

    var pipTip: String {
        switch self {
        case .fiber: return "Fiber makes the tummy wall thicker! Glucose has to wait in line!"
        case .protein: return "Protein tells glucose to wait its turn! Slow and steady!"
        case .fat: return "Fat wraps around glucose so it moves nice and slow!"
        case .acid: return "This is a Glucose Goddess hack! It slows down your tummy so glucose enters slowly!"
        }
    }
}

struct DraggableIngredient: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let role: IngredientRole
    var placed: Bool = false
}

// MARK: - Free Radical Particle

struct FreeRadical: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var dx: CGFloat
    var dy: CGFloat
}

// MARK: - Glucose Journey View

struct GlucoseJourneyView: View {
    let recipe: Recipe
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss

    enum JourneyPhase: Int {
        case tummy = 0
        case cell = 1
        case freeRadicals = 2
        case quiz = 3
        case complete = 4
    }

    @State private var phase: JourneyPhase = .tummy
    @State private var earnedCoins = 0

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.AppTheme.rounded(size: 24))
                            .foregroundColor(Color.AppTheme.lightSepia)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(headerTitle)
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    Spacer()

                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)

                // Phase content
                switch phase {
                case .tummy:
                    TummyPhaseView(recipe: recipe) {
                        advancePhase()
                    }
                case .cell:
                    CellPhaseView(recipe: recipe) {
                        advancePhase()
                    }
                case .freeRadicals:
                    FreeRadicalPhaseView(gameState: gameState) {
                        earnedCoins += 10
                        advancePhase()
                    }
                case .quiz:
                    SmartSnackQuizView(gameState: gameState, earnedCoins: $earnedCoins) {
                        phase = .complete
                    }
                case .complete:
                    completePhase
                }
            }
        }
    }

    var headerTitle: String {
        switch phase {
        case .tummy: return "Your Tummy"
        case .cell: return "Inside Your Cell"
        case .freeRadicals: return "Free Radicals"
        case .quiz: return "Pip's Smart Snack"
        case .complete: return "Glucose Expert!"
        }
    }

    private func advancePhase() {
        withAnimation(AnimationConstants.fadeMedium) {
            if let next = JourneyPhase(rawValue: phase.rawValue + 1) {
                phase = next
            }
        }
    }

    var completePhase: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: AppSpacing.xl)

                PipWavingAnimatedView(size: .hero)

                Text("You're a Glucose Pro!")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("Your meal gave your body steady energy, and you know how to pick smart snacks!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)

                if earnedCoins > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                        Text("Total: +\(earnedCoins) coins")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    }
                    .padding(AppSpacing.md)
                    .background(Color.AppTheme.goldenWheat.opacity(0.15))
                    .cornerRadius(AppSpacing.smallCornerRadius)
                }

                Button(action: { dismiss() }) {
                    Text("Back to Kitchen")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 100)
            }
        }
    }
}

// MARK: - Phase 1: Tummy (Interactive Drag)

struct TummyPhaseView: View {
    let recipe: Recipe
    let onComplete: () -> Void

    @State private var ingredients: [DraggableIngredient] = []
    @State private var placedCount = 0
    @State private var wallThickness: CGFloat = 2
    @State private var gateWidth: CGFloat = 40
    @State private var glucoseSpeed: Double = 0.4
    @State private var glucosePositions: [CGFloat] = [0, -0.2, -0.4]
    @State private var showCompare = false
    @State private var compareActive = false
    @State private var showNext = false
    @State private var pipMessage = "Your food just arrived in your tummy! Drag your ingredients in!"
    @State private var glucoseTimer: Timer?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                // Pip message
                PipJourneyMessage(message: pipMessage, pose: "pip_cooking")
                    .padding(.horizontal, AppSpacing.md)

                // Tummy scene — gut wall is INSIDE the tummy
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.largeCornerRadius)
                        .fill(Color.AppTheme.parchment.opacity(0.5))
                        .frame(height: 320)

                    VStack(spacing: AppSpacing.xs) {
                        Text("Your Tummy")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.sepia)

                        // Big tummy shape with gut wall inside
                        ZStack {
                            // Tummy outline
                            Ellipse()
                                .fill(Color.AppTheme.warmKhaki.opacity(0.15))
                                .frame(width: 280, height: 220)
                                .overlay(
                                    Ellipse()
                                        .stroke(Color.AppTheme.warmKhaki, lineWidth: 2.5)
                                )

                            HStack(spacing: 0) {
                                // LEFT inside tummy: ingredients + glucose
                                VStack(spacing: 6) {
                                    // Placed ingredients
                                    HStack(spacing: 4) {
                                        ForEach(ingredients.filter { $0.placed }) { ing in
                                            Text(ing.emoji)
                                                .font(.AppTheme.recipeStep)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    .frame(height: 30)

                                    // Glucose label + balls waiting
                                    VStack(spacing: 2) {
                                        Text("Glucose")
                                            .font(.AppTheme.rounded(size: 9, weight: .bold))
                                            .foregroundColor(Color.AppTheme.goldenWheat)

                                        HStack(spacing: 4) {
                                            ForEach(0..<(compareActive ? 6 : 3), id: \.self) { _ in
                                                Circle()
                                                    .fill(Color.AppTheme.goldenWheat)
                                                    .frame(width: 10, height: 10)
                                            }
                                        }
                                    }
                                }
                                .frame(width: 100)

                                // GUT WALL inside the tummy
                                VStack(spacing: 2) {
                                    Text("Gut Wall")
                                        .font(.AppTheme.rounded(size: 8, weight: .bold))
                                        .foregroundColor(Color.AppTheme.sage)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.AppTheme.sage.opacity(compareActive ? 0.08 : 0.25))
                                            .frame(width: compareActive ? 6 : wallThickness + 10, height: 120)
                                            .animation(.spring(response: 0.5), value: wallThickness)
                                            .animation(.spring(response: 0.3), value: compareActive)

                                        // Glucose passing through gates
                                        VStack(spacing: compareActive ? 20 : max(6, 24 - CGFloat(placedCount) * 4)) {
                                            ForEach(0..<3, id: \.self) { _ in
                                                Circle()
                                                    .fill(Color.AppTheme.goldenWheat)
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                    }
                                }
                                .frame(width: 50)

                                // RIGHT inside tummy: → Blood arrow
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.right")
                                        .font(.AppTheme.callout)
                                        .foregroundColor(Color.AppTheme.terracotta.opacity(0.5))

                                    Text("→ Blood")
                                        .font(.AppTheme.rounded(size: 9, weight: .semibold))
                                        .foregroundColor(Color.AppTheme.terracotta.opacity(0.6))

                                    // Glucose that made it through
                                    VStack(spacing: 4) {
                                        ForEach(0..<(compareActive ? 6 : max(1, 3 - placedCount)), id: \.self) { _ in
                                            Circle()
                                                .fill(Color.AppTheme.goldenWheat.opacity(0.6))
                                                .frame(width: 7, height: 7)
                                        }
                                    }
                                }
                                .frame(width: 70)
                            }
                        }

                        // Speed label
                        HStack(spacing: 6) {
                            Image(systemName: compareActive ? "hare.fill" : "tortoise.fill")
                                .foregroundColor(compareActive ? Color.AppTheme.terracotta : Color.AppTheme.sage)
                            Text(compareActive ? "Glucose rushing through!" : (placedCount > 0 ? "Glucose moving slowly..." : "Glucose waiting..."))
                                .font(.AppTheme.caption)
                                .foregroundColor(compareActive ? Color.AppTheme.terracotta : Color.AppTheme.sage)
                        }
                    }
                }
                .frame(height: 320)
                .padding(.horizontal, AppSpacing.md)

                // Ingredient chips to drag
                if !ingredients.allSatisfy({ $0.placed }) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Tap ingredients to add them:")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                            .padding(.horizontal, AppSpacing.md)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(ingredients.filter { !$0.placed }) { ingredient in
                                    Button(action: { placeIngredient(ingredient) }) {
                                        HStack(spacing: 6) {
                                            Text(ingredient.emoji)
                                                .font(.AppTheme.rounded(size: 24))
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(ingredient.name)
                                                    .font(.AppTheme.caption)
                                                    .foregroundColor(Color.AppTheme.darkBrown)
                                                Text(ingredient.role.label)
                                                    .font(.AppTheme.rounded(size: 9, weight: .bold))
                                                    .foregroundColor(ingredient.role.color)
                                            }
                                        }
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, AppSpacing.xs)
                                        .background(Color.AppTheme.warmCream)
                                        .cornerRadius(AppSpacing.smallCornerRadius)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppSpacing.smallCornerRadius)
                                                .stroke(ingredient.role.color.opacity(0.4), lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(BouncyButtonStyle())
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                }

                // Compare button
                if showCompare {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            compareActive.toggle()
                        }
                        if compareActive {
                            pipMessage = "No fiber, no protein, no fat — glucose rushes straight through! That's a spike!"
                        } else {
                            pipMessage = "See how YOUR ingredients protect you? Glucose moves nice and slow!"
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: compareActive ? "arrow.uturn.backward" : "bolt.fill")
                            Text(compareActive ? "Put ingredients back" : "What if just candy?")
                        }
                        .font(.AppTheme.callout)
                        .foregroundColor(compareActive ? Color.AppTheme.sage : Color.AppTheme.terracotta)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(compareActive
                                    ? Color.AppTheme.sage.opacity(0.1)
                                    : Color.AppTheme.terracotta.opacity(0.1))
                        .cornerRadius(AppSpacing.smallCornerRadius)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }

                // Next button
                if showNext {
                    Button(action: onComplete) {
                        Text("Next: Inside Your Cells!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .padding(.horizontal, AppSpacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, AppSpacing.md)
        }
        .onAppear { buildIngredients() }
    }

    private func buildIngredients() {
        var items: [DraggableIngredient] = []
        for veg in recipe.gardenIngredients.prefix(3) {
            items.append(DraggableIngredient(name: veg.displayName, emoji: veg.emoji, role: .fiber))
        }
        for pantry in recipe.pantryIngredients.prefix(4) {
            let role: IngredientRole? = {
                switch pantry {
                // Protein sources
                case .eggs, .chicken, .greekYogurt, .groundBeef:
                    return .protein
                // Fat sources
                case .oliveOil, .vegetableOil, .butter, .cheese, .cream, .nuts:
                    return .fat
                // Glucose Goddess hacks (acid / slows gastric emptying)
                case .vinegar, .cinnamon, .lemon:
                    return .acid
                // Milk is mixed (protein + fat + carbs) — show as protein for simplicity
                case .milk:
                    return .protein
                // Skip seasonings — they add flavor but don't slow glucose
                case .salt, .pepper, .soySauce, .flour, .tomatoSauce,
                     .paprika, .cumin, .garlicPowder, .turmeric:
                    return nil
                }
            }()
            if let role {
                items.append(DraggableIngredient(name: pantry.displayName, emoji: pantry.emoji, role: role))
            }
        }
        ingredients = items
    }

    private func placeIngredient(_ ingredient: DraggableIngredient) {
        guard let idx = ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            ingredients[idx].placed = true
            placedCount += 1

            switch ingredient.role {
            case .fiber:
                wallThickness += 6
            case .acid:
                wallThickness += 4
            default:
                break
            }

            pipMessage = ingredient.role.pipTip

            // Slow down glucose speed
            glucoseSpeed = max(0.1, glucoseSpeed - 0.05)
        }

        // Check if all placed
        if ingredients.allSatisfy({ $0.placed }) {
            pipMessage = "All ingredients in! See how slowly glucose passes through? That's YOUR healthy meal!"
            withAnimation(.spring().delay(0.5)) {
                showCompare = true
            }
            withAnimation(.spring().delay(1.5)) {
                showNext = true
            }
        }
    }
}

// MARK: - Phase 2: Cell (Zoom + Tap Mitochondria)

struct CellPhaseView: View {
    let recipe: Recipe
    let onComplete: () -> Void

    enum CellStep {
        case bodyZoom
        case cellView
        case energizing
    }

    @State private var step: CellStep = .bodyZoom
    @State private var bodyScale: CGFloat = 1.0
    @State private var showCells = false
    @State private var showBigCell = false
    @State private var mitoTaps = 0
    @State private var energyBursts: [EnergyBurst] = []
    @State private var litOrgans: [String] = []
    @State private var pipEnergy: Int = 0 // 0=neutral, 1-4=energizing, 5=full energy
    @State private var showSpikeToggle = false
    @State private var spikeMode = false
    @State private var showNext = false
    @State private var pipMessage = "Let's zoom in! Your body is made of tiny cells..."

    // Which organs this recipe boosts
    private var recipeOrgans: [String] {
        var organs: Set<String> = []
        for veg in recipe.gardenIngredients {
            for nutrient in veg.nutrients {
                organs.insert(nutrient.benefitsOrgan)
            }
        }
        return Array(organs.prefix(6))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                PipJourneyMessage(message: pipMessage, pose: step == .bodyZoom ? "pip_thinking" : "pip_got_idea")
                    .padding(.horizontal, AppSpacing.md)

                // Body → Cell zoom
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.largeCornerRadius)
                        .fill(Color.AppTheme.parchment.opacity(0.3))
                        .frame(height: 320)

                    if step == .bodyZoom {
                        // Body outline with cells hint
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "figure.stand")
                                .font(.AppTheme.rounded(size: 100))
                                .foregroundColor(Color.AppTheme.sage.opacity(0.6))
                                .scaleEffect(bodyScale)

                            Text("Tap to zoom into your cells!")
                                .font(.AppTheme.callout)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        .onTapGesture { zoomIntoCells() }

                    } else if step == .cellView || step == .energizing {
                        // Big cell view
                        ZStack {
                            // Cell membrane
                            Circle()
                                .fill(Color.AppTheme.warmCream)
                                .frame(width: 240, height: 240)
                                .overlay(
                                    Circle()
                                        .stroke(Color.AppTheme.sage.opacity(0.4), lineWidth: 3)
                                )

                            // Nucleus
                            Circle()
                                .fill(Color.AppTheme.parchment)
                                .frame(width: 50, height: 50)
                                .offset(x: -40, y: -40)

                            Text("Nucleus")
                                .font(.AppTheme.rounded(size: 8, weight: .medium))
                                .foregroundColor(Color.AppTheme.lightSepia)
                                .offset(x: -40, y: -15)

                            // Mitochondria (tappable!)
                            Button(action: tapMitochondria) {
                                VStack(spacing: 2) {
                                    ZStack {
                                        // Glow when tapped
                                        if mitoTaps > 0 {
                                            Circle()
                                                .fill(Color.AppTheme.goldenWheat.opacity(0.2))
                                                .frame(width: CGFloat(60 + mitoTaps * 5), height: CGFloat(60 + mitoTaps * 5))
                                        }

                                        // Mitochondria shape
                                        Capsule()
                                            .fill(Color.AppTheme.goldenWheat.opacity(0.3))
                                            .frame(width: 55, height: 35)
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.AppTheme.goldenWheat, lineWidth: 2)
                                            )

                                        Image(systemName: "bolt.fill")
                                            .font(.AppTheme.title3)
                                            .foregroundColor(Color.AppTheme.goldenWheat)
                                    }

                                    if mitoTaps == 0 {
                                        Text("Tap me!")
                                            .font(.AppTheme.rounded(size: 10, weight: .bold))
                                            .foregroundColor(Color.AppTheme.goldenWheat)
                                    }
                                }
                            }
                            .buttonStyle(BouncyButtonStyle())
                            .offset(x: 30, y: 30)

                            // Glucose balls floating in
                            ForEach(0..<(spikeMode ? 8 : 3), id: \.self) { i in
                                Circle()
                                    .fill(Color.AppTheme.goldenWheat.opacity(0.6))
                                    .frame(width: 10, height: 10)
                                    .offset(
                                        x: CGFloat.random(in: -90...90),
                                        y: CGFloat.random(in: -90...90)
                                    )
                            }

                            // Energy bursts
                            ForEach(energyBursts) { burst in
                                Image(systemName: "sparkle")
                                    .font(.AppTheme.callout)
                                    .foregroundColor(Color.AppTheme.goldenWheat)
                                    .offset(x: burst.x, y: burst.y)
                                    .opacity(burst.opacity)
                            }

                            // Spike mode: free radicals preview
                            if spikeMode {
                                ForEach(0..<4, id: \.self) { i in
                                    Image(systemName: "staroflife.fill")
                                        .font(.AppTheme.caption)
                                        .foregroundColor(Color.AppTheme.terracotta.opacity(0.6))
                                        .offset(
                                            x: CGFloat.random(in: -70...70),
                                            y: CGFloat.random(in: -70...70)
                                        )
                                }
                            }
                        }
                        .frame(height: 260)
                    }
                }
                .frame(height: 320)
                .padding(.horizontal, AppSpacing.md)

                // Pip energy visualization — gets energized or tired
                if step == .cellView || step == .energizing {
                    VStack(spacing: AppSpacing.xs) {
                        // Pip with energy state
                        HStack(spacing: AppSpacing.md) {
                            Image(spikeMode ? "pip_upset" : (pipEnergy >= 5 ? "pip_points_up_right" : (pipEnergy > 0 ? "pip_got_idea" : "pip_thinking")))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 70, height: 70)
                                .opacity(spikeMode ? 0.5 : 1.0)
                                .scaleEffect(pipEnergy >= 5 ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3), value: pipEnergy)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pip's Energy")
                                    .font(.AppTheme.caption)
                                    .foregroundColor(Color.AppTheme.sepia)

                                // Energy bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.AppTheme.parchment)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(spikeMode ? Color.AppTheme.terracotta : Color.AppTheme.goldenWheat)
                                            .frame(width: geo.size.width * CGFloat(spikeMode ? 1 : min(pipEnergy, 5)) / 5.0)
                                            .animation(.spring(response: 0.4), value: pipEnergy)
                                            .animation(.spring(response: 0.3), value: spikeMode)
                                    }
                                }
                                .frame(height: 14)

                                Text(spikeMode
                                     ? "Overwhelmed! Too much glucose!"
                                     : (pipEnergy >= 5 ? "Full energy! Feeling great!" : "Tap mitochondria to energize Pip!"))
                                    .font(.AppTheme.rounded(size: 10, weight: .medium))
                                    .foregroundColor(spikeMode ? Color.AppTheme.terracotta : Color.AppTheme.sage)
                            }
                        }
                        .softCard(showShadow: false)
                    }
                    .padding(.horizontal, AppSpacing.md)
                }

                // Organs lighting up
                if !litOrgans.isEmpty {
                    VStack(spacing: AppSpacing.xs) {
                        Text("Powering up!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.sage)

                        HStack(spacing: AppSpacing.md) {
                            ForEach(litOrgans, id: \.self) { organ in
                                VStack(spacing: 2) {
                                    Image(systemName: organIcon(organ))
                                        .font(.AppTheme.title2)
                                        .foregroundColor(organColor(organ))
                                    Text(organ)
                                        .font(.AppTheme.rounded(size: 9, weight: .medium))
                                        .foregroundColor(Color.AppTheme.sepia)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }

                // Spike toggle
                if showSpikeToggle {
                    Button(action: {
                        withAnimation(.spring()) { spikeMode.toggle() }
                        pipMessage = spikeMode
                            ? "Too much glucose! Pip is exhausted and the mitochondria can't keep up!"
                            : "Back to steady glucose — Pip is energized again! Happy cells!"
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: spikeMode ? "arrow.uturn.backward" : "bolt.fill")
                            Text(spikeMode ? "Back to steady" : "What if too fast?")
                        }
                        .font(.AppTheme.callout)
                        .foregroundColor(spikeMode ? Color.AppTheme.sage : Color.AppTheme.terracotta)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(spikeMode
                                    ? Color.AppTheme.sage.opacity(0.1)
                                    : Color.AppTheme.terracotta.opacity(0.1))
                        .cornerRadius(AppSpacing.smallCornerRadius)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }

                // Next button
                if showNext {
                    Button(action: onComplete) {
                        Text("Next: Free Radicals!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .padding(.horizontal, AppSpacing.md)
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, AppSpacing.md)
        }
    }

    private func zoomIntoCells() {
        withAnimation(.easeInOut(duration: 0.6)) {
            bodyScale = 5.0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.springMedium) {
                step = .cellView
                pipMessage = "Each cell has a MITOCHONDRIA — a tiny power plant! Tap it to make energy!"
            }
        }
    }

    private func tapMitochondria() {
        guard !spikeMode else { return }
        mitoTaps += 1

        // Energy burst sparkle
        let burst = EnergyBurst(
            x: CGFloat.random(in: -40...40) + 30,
            y: CGFloat.random(in: -40...40) + 30,
            opacity: 1.0
        )
        withAnimation(.spring(response: 0.3)) {
            energyBursts.append(burst)
            pipEnergy = min(5, mitoTaps)
        }

        // Light up an organ
        if mitoTaps <= recipeOrgans.count {
            let organ = recipeOrgans[mitoTaps - 1]
            withAnimation(.spring(response: 0.4).delay(0.2)) {
                litOrgans.append(organ)
            }
            pipMessage = "\(organ) powered up! Pip is getting energized!"
        }

        // Pip fully energized at tap 5
        if mitoTaps == 5 {
            pipMessage = "Pip is FULL of energy! Steady glucose = happy Pip, happy body!"
            step = .energizing

            withAnimation(.spring().delay(1.0)) {
                showSpikeToggle = true
            }
            withAnimation(.spring().delay(2.0)) {
                showNext = true
            }
        }
    }

    private func organIcon(_ organ: String) -> String {
        switch organ {
        case "Brain": return "brain.head.profile"
        case "Heart", "Blood": return "heart.fill"
        case "Muscles": return "figure.strengthtraining.traditional"
        case "Bones": return "figure.stand"
        case "Immune System": return "shield.fill"
        case "Energy", "Whole Body": return "bolt.fill"
        case "Eyes": return "eye.fill"
        case "Skin": return "sparkles"
        default: return "staroflife.fill"
        }
    }

    private func organColor(_ organ: String) -> Color {
        switch organ {
        case "Brain": return Color.AppTheme.darkBrown
        case "Heart", "Blood": return Color.AppTheme.terracotta
        case "Muscles": return Color.AppTheme.goldenWheat
        case "Immune System": return Color.AppTheme.sage
        case "Energy", "Whole Body": return Color.AppTheme.goldenWheat
        case "Eyes": return Color.AppTheme.softOlive
        case "Bones": return Color.AppTheme.warmKhaki
        case "Skin": return Color.AppTheme.terracotta.opacity(0.7)
        default: return Color.AppTheme.sage
        }
    }
}

struct EnergyBurst: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    var opacity: Double
}

// MARK: - Phase 3: Free Radical Sandbox

struct FreeRadicalPhaseView: View {
    let gameState: GameState
    let onComplete: () -> Void

    @State private var sugarCubesInCell = 0
    @State private var radicalCount = 0
    @State private var radicalPositions: [(x: CGFloat, y: CGFloat)] = []
    @State private var cellHealth: Double = 100
    @State private var showQuestion = false
    @State private var answered = false
    @State private var pipMessage = "Let's experiment! Drag sugar cubes into the cell and see what happens!"

    private var healthColor: Color {
        if cellHealth > 70 { return Color.AppTheme.sage }
        if cellHealth > 40 { return Color.AppTheme.goldenWheat }
        return Color.AppTheme.terracotta
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                PipJourneyMessage(message: pipMessage, pose: sugarCubesInCell > 3 ? "pip_thinking" : "pip_cooking")
                    .padding(.horizontal, AppSpacing.md)

                // Cell health bar
                VStack(spacing: 4) {
                    HStack {
                        Text("Cell Health")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                        Spacer()
                        Text("\(Int(cellHealth))%")
                            .font(.AppTheme.headline)
                            .foregroundColor(healthColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.AppTheme.parchment)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(healthColor)
                                .frame(width: geo.size.width * cellHealth / 100)
                                .animation(.spring(response: 0.3), value: cellHealth)
                        }
                    }
                    .frame(height: 12)
                }
                .padding(.horizontal, AppSpacing.md)

                // Cell view with radicals
                ZStack {
                    // Cell
                    Circle()
                        .fill(Color.AppTheme.warmCream)
                        .frame(width: 250, height: 250)
                        .overlay(
                            Circle()
                                .stroke(healthColor.opacity(0.5), lineWidth: 3)
                        )

                    // Mitochondria (center)
                    Capsule()
                        .fill(Color.AppTheme.goldenWheat.opacity(0.3))
                        .frame(width: 50, height: 30)
                        .overlay(
                            Capsule()
                                .stroke(Color.AppTheme.goldenWheat, lineWidth: 2)
                        )

                    Image(systemName: "bolt.fill")
                        .font(.AppTheme.callout)
                        .foregroundColor(Color.AppTheme.goldenWheat)

                    // Glucose balls (proportional to sugar cubes)
                    ForEach(0..<min(sugarCubesInCell * 3, 15), id: \.self) { i in
                        Circle()
                            .fill(Color.AppTheme.goldenWheat.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .offset(
                                x: CGFloat.random(in: -90...90),
                                y: CGFloat.random(in: -90...90)
                            )
                    }

                    // Free radicals
                    ForEach(0..<radicalCount, id: \.self) { i in
                        let pos = i < radicalPositions.count
                            ? radicalPositions[i]
                            : (x: CGFloat.random(in: -80...80), y: CGFloat.random(in: -80...80))
                        Image(systemName: "staroflife.fill")
                            .font(.AppTheme.captionLarge)
                            .foregroundColor(Color.AppTheme.terracotta.opacity(0.7))
                            .offset(x: pos.x, y: pos.y)
                            .transition(.scale.combined(with: .opacity))
                    }

                    // DNA in center
                    if cellHealth < 50 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.AppTheme.title3)
                            .foregroundColor(Color.AppTheme.terracotta)
                            .offset(y: -60)
                            .transition(.scale)
                    }
                }
                .frame(height: 270)
                .padding(.horizontal, AppSpacing.md)

                // Sugar cube controls
                HStack(spacing: AppSpacing.lg) {
                    // Remove sugar
                    Button(action: removeSugar) {
                        VStack(spacing: 4) {
                            Image(systemName: "minus.circle.fill")
                                .font(.AppTheme.rounded(size: 32))
                                .foregroundColor(Color.AppTheme.sage)
                            Text("Remove")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sage)
                        }
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(sugarCubesInCell <= 0)
                    .opacity(sugarCubesInCell > 0 ? 1.0 : 0.3)

                    // Sugar cube count
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            ForEach(0..<min(sugarCubesInCell, 8), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.AppTheme.terracotta.opacity(0.4))
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(Color.AppTheme.terracotta.opacity(0.6), lineWidth: 1)
                                    )
                            }
                        }
                        Text("\(sugarCubesInCell) sugar cube\(sugarCubesInCell == 1 ? "" : "s")")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                    }

                    // Add sugar
                    Button(action: addSugar) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.AppTheme.rounded(size: 32))
                                .foregroundColor(Color.AppTheme.terracotta)
                            Text("Add sugar")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.terracotta)
                        }
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .disabled(sugarCubesInCell >= 8)
                    .opacity(sugarCubesInCell < 8 ? 1.0 : 0.3)
                }
                .padding(.horizontal, AppSpacing.md)

                // Radical counter
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "staroflife.fill")
                        .foregroundColor(Color.AppTheme.terracotta)
                    Text("Free Radicals: \(radicalCount)")
                        .font(.AppTheme.bodyBold)
                        .foregroundColor(radicalCount > 3 ? Color.AppTheme.terracotta : Color.AppTheme.sepia)
                }

                // Question — Pip asks about their meal
                if showQuestion && !answered {
                    VStack(spacing: AppSpacing.md) {
                        PipJourneyMessage(
                            message: "Now that you've seen what sugar does... How do you think YOUR meal was?",
                            pose: "pip_thinking"
                        )

                        VStack(spacing: AppSpacing.sm) {
                            Button(action: { answerQuestion("Lots of sugar") }) {
                                Text("Lots of sugar")
                                    .font(.AppTheme.bodyBold)
                                    .foregroundColor(Color.AppTheme.terracotta)
                                    .frame(maxWidth: .infinity)
                                    .padding(AppSpacing.md)
                                    .background(Color.AppTheme.terracotta.opacity(0.1))
                                    .cornerRadius(AppSpacing.cardCornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                            .stroke(Color.AppTheme.terracotta.opacity(0.3), lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(BouncyButtonStyle())

                            Button(action: { answerQuestion("A little sugar") }) {
                                Text("A little sugar")
                                    .font(.AppTheme.bodyBold)
                                    .foregroundColor(Color.AppTheme.goldenWheat)
                                    .frame(maxWidth: .infinity)
                                    .padding(AppSpacing.md)
                                    .background(Color.AppTheme.goldenWheat.opacity(0.1))
                                    .cornerRadius(AppSpacing.cardCornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                            .stroke(Color.AppTheme.goldenWheat.opacity(0.3), lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(BouncyButtonStyle())

                            Button(action: { answerQuestion("Healthy & balanced") }) {
                                Text("Healthy & balanced")
                                    .font(.AppTheme.bodyBold)
                                    .foregroundColor(Color.AppTheme.sage)
                                    .frame(maxWidth: .infinity)
                                    .padding(AppSpacing.md)
                                    .background(Color.AppTheme.sage.opacity(0.1))
                                    .cornerRadius(AppSpacing.cardCornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                            .stroke(Color.AppTheme.sage.opacity(0.3), lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Next
                if answered {
                    Button(action: onComplete) {
                        Text("Time for a snack quiz!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .padding(.horizontal, AppSpacing.md)
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, AppSpacing.md)
        }
    }

    private func addSugar() {
        guard sugarCubesInCell < 8 else { return }
        withAnimation(.spring(response: 0.3)) {
            sugarCubesInCell += 1
            radicalCount = max(0, sugarCubesInCell - 1)
            radicalPositions.append((
                x: CGFloat.random(in: -80...80),
                y: CGFloat.random(in: -80...80)
            ))
            cellHealth = max(0, 100 - Double(radicalCount) * 15)
        }

        if sugarCubesInCell == 1 {
            pipMessage = "A little glucose is fine — your mitochondria need it for energy!"
        } else if sugarCubesInCell == 3 {
            pipMessage = "Getting crowded! Free radicals are starting to appear..."
        } else if sugarCubesInCell >= 5 {
            pipMessage = "Too much sugar! Free radicals are damaging your cell!"
        }

        // Show question after kid has added enough to see radicals
        if sugarCubesInCell >= 2 && !showQuestion {
            withAnimation(.spring().delay(0.5)) {
                showQuestion = true
            }
        }
    }

    private func removeSugar() {
        guard sugarCubesInCell > 0 else { return }
        withAnimation(.spring(response: 0.3)) {
            sugarCubesInCell -= 1
            radicalCount = max(0, sugarCubesInCell - 1)
            if !radicalPositions.isEmpty { radicalPositions.removeLast() }
            cellHealth = min(100, 100 - Double(radicalCount) * 15)
        }

        if sugarCubesInCell == 0 {
            pipMessage = "All clear! Your cell is healthy again. The cell can clean up when glucose is steady!"
        } else {
            pipMessage = "Better! Less sugar = fewer free radicals. Your cell is recovering!"
        }
    }

    private func answerQuestion(_ choice: String) {
        withAnimation(.spring()) {
            answered = true
        }
        if choice == "Healthy & balanced" {
            pipMessage = "Exactly! Your meal had veggies, protein, and fat — that keeps glucose steady and your cells happy!"
            gameState.addCoins(10)
        } else {
            pipMessage = "Remember, we used veggies and protein — that keeps glucose steady! Your meal was healthy and balanced!"
        }
    }
}

// MARK: - Smart Snack Quiz View

struct SmartSnackQuizView: View {
    let gameState: GameState
    @Binding var earnedCoins: Int
    let onComplete: () -> Void

    @State private var quizRound = SnackQuizBank.randomRound()
    @State private var selectedSnack: SnackOption?
    @State private var showResult = false
    @State private var showSugarCubes = false
    @State private var shuffledOptions: [SnackOption] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                Text("Great cooking! Now pick a snack!")
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)

                PipJourneyMessage(
                    message: selectedSnack == nil
                        ? "Pick the snack that would keep your glucose smooth!"
                        : selectedSnack!.pipExplanation,
                    pose: selectedSnack == nil ? "pip_thinking" : (selectedSnack?.isHealthy == true ? "pip_points_up_right" : "pip_upset")
                )
                .padding(.horizontal, AppSpacing.md)

                if !showResult {
                    ForEach(shuffledOptions) { snack in
                        Button(action: { selectSnack(snack) }) {
                            HStack(spacing: AppSpacing.md) {
                                Text(snack.emoji).font(.AppTheme.rounded(size: 36))
                                Text(snack.name)
                                    .font(.AppTheme.bodyBold)
                                    .foregroundColor(Color.AppTheme.darkBrown)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color.AppTheme.lightSepia)
                            }
                            .softCard(showShadow: false)
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .padding(.horizontal, AppSpacing.md)
                    }
                }

                if showResult, let snack = selectedSnack {
                    VStack(spacing: AppSpacing.md) {
                        HStack(spacing: AppSpacing.md) {
                            Text(snack.emoji).font(.AppTheme.rounded(size: 44))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snack.name)
                                    .font(.AppTheme.headline)
                                    .foregroundColor(Color.AppTheme.darkBrown)
                                Text("\(String(format: "%.0f", snack.sugarGrams))g sugar")
                                    .font(.AppTheme.body)
                                    .foregroundColor(snack.isHealthy ? Color.AppTheme.sage : Color.AppTheme.terracotta)
                            }
                            Spacer()
                            Image(systemName: snack.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.AppTheme.title)
                                .foregroundColor(snack.isHealthy ? Color.AppTheme.sage : Color.AppTheme.terracotta)
                        }
                        .padding(AppSpacing.md)
                        .background(snack.isHealthy ? Color.AppTheme.sage.opacity(0.1) : Color.AppTheme.terracotta.opacity(0.1))
                        .cornerRadius(AppSpacing.cardCornerRadius)

                        if showSugarCubes && snack.sugarCubes > 0 {
                            VStack(spacing: AppSpacing.xs) {
                                Text("That's \(snack.sugarCubes) sugar cube\(snack.sugarCubes == 1 ? "" : "s")!")
                                    .font(.AppTheme.headline)
                                    .foregroundColor(Color.AppTheme.darkBrown)
                                HStack(spacing: 6) {
                                    ForEach(0..<min(snack.sugarCubes, 10), id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(snack.isHealthy ? Color.AppTheme.sage.opacity(0.3) : Color.AppTheme.terracotta.opacity(0.4))
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .stroke(snack.isHealthy ? Color.AppTheme.sage.opacity(0.5) : Color.AppTheme.terracotta.opacity(0.6), lineWidth: 1)
                                            )
                                    }
                                }
                                Text("1 cube = 1 teaspoon of sugar")
                                    .font(.AppTheme.caption)
                                    .foregroundColor(Color.AppTheme.lightSepia)
                            }
                            .softCard(showShadow: false)
                            .transition(.scale.combined(with: .opacity))
                        }

                        if !snack.isHealthy {
                            Button(action: retryQuiz) {
                                Text("Let me pick again!")
                                    .font(.AppTheme.headline)
                                    .foregroundColor(Color.AppTheme.cream)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.md)
                                    .background(Color.AppTheme.sage)
                                    .cornerRadius(AppSpacing.cardCornerRadius)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        } else {
                            Button(action: onComplete) {
                                Text("Awesome!")
                                    .font(.AppTheme.headline)
                                    .foregroundColor(Color.AppTheme.cream)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.md)
                                    .background(Color.AppTheme.sage)
                                    .cornerRadius(AppSpacing.cardCornerRadius)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, AppSpacing.md)
        }
        .onAppear {
            shuffledOptions = quizRound.shuffled
        }
    }

    private func selectSnack(_ snack: SnackOption) {
        selectedSnack = snack
        withAnimation(AnimationConstants.springMedium) {
            showResult = true
        }

        if snack.isHealthy {
            let quizID = "glucose_quiz_\(quizRound.id)"
            if gameState.claimKnowledgeReward(id: quizID, coins: 10) {
                earnedCoins += 10
            } else {
                earnedCoins += 5
                gameState.addCoins(5)
            }
        } else {
            earnedCoins += 5
            gameState.addCoins(5)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.springMedium) {
                showSugarCubes = true
            }
        }
    }

    private func retryQuiz() {
        withAnimation(AnimationConstants.fadeMedium) {
            selectedSnack = nil
            showResult = false
            showSugarCubes = false
        }
    }
}

// MARK: - Pip Journey Message

struct PipJourneyMessage: View {
    let message: String
    let pose: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(pose)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)
                Text(message)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .softCard(showShadow: false)
        }
    }
}

// MARK: - Preview

#Preview {
    GlucoseJourneyView(recipe: GardenRecipes.all[0])
        .environmentObject(GameState.preview)
}
