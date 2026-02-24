//
//  CookingSessionView.swift
//  ChefAcademy
//
//  Multi-step cooking session with real cooking order.
//  Each recipe generates a sequence of mini-game steps:
//  Heat → Fat → Prep → Add → Stir → Season → Cook → Assemble
//

import SwiftUI

// MARK: - Cooking Step Type

enum CookingStepType {
    case heatPan
    case addFat(PantryItem)
    case wash(VegetableType)
    case peel(VegetableType)
    case chop(VegetableType)
    case slice(VegetableType)
    case grate(VegetableType)
    case dice(VegetableType)
    case crack(PantryItem)
    case addToPan(String, String)   // (item name, image name)
    case stir
    case season([PantryItem])
    case cook(Int)                  // timer seconds
    case assemble(String)           // final instruction
}

// MARK: - Cooking Step

struct CookingStep: Identifiable {
    let id = UUID()
    let type: CookingStepType
    let instruction: String
    let pipMessage: String
}

// MARK: - Step Generation

extension Recipe {

    /// Generate cooking steps from the recipe's steps array and ingredients.
    /// Follows real cooking order: heat → fat → prep → crack → add to pan → stir → season → cook → assemble
    func generateCookingSteps() -> [CookingStep] {
        var result: [CookingStep] = []
        let lowSteps = steps.map { $0.lowercased() }
        let isNoCook = cookTime <= 5

        // --- Fats in pantry ---
        let fats: [PantryItem] = [.butter, .oliveOil, .vegetableOil]
        let recipeFat = pantryIngredients.first(where: { fats.contains($0) })

        // --- Seasonings ---
        let seasoningItems: [PantryItem] = [.salt, .pepper, .cinnamon, .soySauce]
        let recipeSeasonings = pantryIngredients.filter { seasoningItems.contains($0) }

        // --- Aromatics (go in pan first) ---
        let aromaticTypes: [VegetableType] = [.onion]

        // 1. HEAT PAN (skip for no-cook)
        if !isNoCook && (recipeFat != nil || hasAnyCookingStep(lowSteps)) {
            result.append(CookingStep(
                type: .heatPan,
                instruction: "Heat up the pan!",
                pipMessage: "Hold your finger on the pan to warm it up!"
            ))
        }

        // 2. ADD FAT (skip for no-cook)
        if !isNoCook, let fat = recipeFat {
            let stepText = lowSteps.first(where: { $0.contains("melt") || $0.contains("heat") || $0.contains("oil") }) ?? "Add \(fat.displayName) to the pan."
            result.append(CookingStep(
                type: .addFat(fat),
                instruction: capitalizedStep(stepText),
                pipMessage: "Drop the \(fat.displayName.lowercased()) into the pan!"
            ))
        }

        // 3. PREP VEGGIES — parse verbs from steps
        for step in steps {
            let low = step.lowercased()
            for veg in gardenIngredients {
                let vegName = veg.displayName.lowercased()
                guard low.contains(vegName) || matchesVeggieAlias(low, veg) else { continue }

                if low.contains("wash") {
                    result.append(CookingStep(
                        type: .wash(veg),
                        instruction: step,
                        pipMessage: "Wash the \(veg.displayName.lowercased()) nice and clean!"
                    ))
                } else if low.contains("peel") {
                    result.append(CookingStep(
                        type: .peel(veg),
                        instruction: step,
                        pipMessage: "Swipe down to peel the \(veg.displayName.lowercased())!"
                    ))
                } else if low.contains("grate") || low.contains("shred") {
                    result.append(CookingStep(
                        type: .grate(veg),
                        instruction: step,
                        pipMessage: "Grate the \(veg.displayName.lowercased()) into little shreds!"
                    ))
                } else if low.contains("dice") {
                    result.append(CookingStep(
                        type: .dice(veg),
                        instruction: step,
                        pipMessage: "Dice the \(veg.displayName.lowercased()) into tiny cubes!"
                    ))
                } else if low.contains("slice") {
                    result.append(CookingStep(
                        type: .slice(veg),
                        instruction: step,
                        pipMessage: "Slice the \(veg.displayName.lowercased()) carefully!"
                    ))
                } else if low.contains("chop") || low.contains("cut") || low.contains("tear") {
                    result.append(CookingStep(
                        type: .chop(veg),
                        instruction: step,
                        pipMessage: "Chop chop chop! Let's cut the \(veg.displayName.lowercased())!"
                    ))
                }
            }
        }

        // 4. CRACK EGGS
        if pantryIngredients.contains(.eggs) {
            let eggStep = lowSteps.first(where: { $0.contains("crack") || $0.contains("whisk") })
            result.append(CookingStep(
                type: .crack(.eggs),
                instruction: eggStep.map { capitalizedStep($0) } ?? "Crack the eggs into a bowl.",
                pipMessage: "Tap to crack the eggs!"
            ))
        }

        // 5. ADD TO PAN (skip for no-cook)
        if !isNoCook {
            // Aromatics first
            for veg in gardenIngredients where aromaticTypes.contains(veg) {
                result.append(CookingStep(
                    type: .addToPan(veg.displayName, veg.imageName),
                    instruction: "Add the \(veg.displayName.lowercased()) to the pan.",
                    pipMessage: "In goes the \(veg.displayName.lowercased())!"
                ))
            }
            // Other veggies
            for veg in gardenIngredients where !aromaticTypes.contains(veg) {
                // Only add to pan if there's a cooking step mentioning it
                let mentioned = lowSteps.contains(where: {
                    ($0.contains("add") || $0.contains("pour") || $0.contains("toss")) &&
                    ($0.contains(veg.displayName.lowercased()) || matchesVeggieAlias($0, veg))
                })
                if mentioned {
                    result.append(CookingStep(
                        type: .addToPan(veg.displayName, veg.imageName),
                        instruction: "Add the \(veg.displayName.lowercased()) to the pan.",
                        pipMessage: "In goes the \(veg.displayName.lowercased())!"
                    ))
                }
            }
            // Protein
            if pantryIngredients.contains(.chicken) {
                let mentioned = lowSteps.contains(where: { $0.contains("chicken") && ($0.contains("cook") || $0.contains("add") || $0.contains("pour")) })
                if mentioned {
                    result.append(CookingStep(
                        type: .addToPan("Chicken", PantryItem.chicken.imageName),
                        instruction: "Add the chicken to the pan.",
                        pipMessage: "The chicken goes in — sizzle!"
                    ))
                }
            }
            if pantryIngredients.contains(.groundBeef) {
                let mentioned = lowSteps.contains(where: { $0.contains("beef") && ($0.contains("brown") || $0.contains("cook") || $0.contains("add")) })
                if mentioned {
                    result.append(CookingStep(
                        type: .addToPan("Ground Beef", PantryItem.groundBeef.imageName),
                        instruction: "Add the ground beef to the pan.",
                        pipMessage: "Brown that beef!"
                    ))
                }
            }
        }

        // 6. STIR (skip for no-cook)
        if !isNoCook && lowSteps.contains(where: { $0.contains("stir") || $0.contains("toss") || $0.contains("mix") }) {
            result.append(CookingStep(
                type: .stir,
                instruction: "Stir everything together!",
                pipMessage: "Draw circles to stir it all up!"
            ))
        }

        // 7. SEASON
        if !recipeSeasonings.isEmpty {
            let names = recipeSeasonings.map { $0.displayName.lowercased() }.joined(separator: " and ")
            result.append(CookingStep(
                type: .season(recipeSeasonings),
                instruction: "Add a pinch of \(names)!",
                pipMessage: "Tap to sprinkle the \(names)!"
            ))
        }

        // 8. COOK TIMER (skip for no-cook)
        if !isNoCook {
            let timerSeconds: Int
            switch difficulty {
            case .easy: timerSeconds = 5
            case .medium: timerSeconds = 8
            case .hard: timerSeconds = 12
            }
            result.append(CookingStep(
                type: .cook(timerSeconds),
                instruction: "Let it cook — watch the timer!",
                pipMessage: "Take it off at just the right moment!"
            ))
        }

        // 9. ASSEMBLE — last step from recipe
        if let lastStep = steps.last {
            result.append(CookingStep(
                type: .assemble(lastStep),
                instruction: lastStep,
                pipMessage: "Almost done — let's finish this dish!"
            ))
        }

        // Remove duplicate veggies that appear in multiple verb matches
        return deduplicateSteps(result)
    }

    // MARK: - Helpers

    private func hasAnyCookingStep(_ lowSteps: [String]) -> Bool {
        lowSteps.contains(where: {
            $0.contains("cook") || $0.contains("heat") || $0.contains("melt") ||
            $0.contains("bake") || $0.contains("roast") || $0.contains("fry") ||
            $0.contains("simmer") || $0.contains("boil")
        })
    }

    private func matchesVeggieAlias(_ text: String, _ veg: VegetableType) -> Bool {
        switch veg {
        case .broccoli: return text.contains("broccoli") || text.contains("floret")
        case .bellPepperRed: return text.contains("red pepper") || text.contains("bell pepper")
        case .bellPepperYellow: return text.contains("yellow pepper") || text.contains("bell pepper")
        case .greenBeans: return text.contains("green bean")
        case .sweetPotato: return text.contains("sweet potato")
        default: return false
        }
    }

    private func capitalizedStep(_ step: String) -> String {
        guard let first = step.first else { return step }
        return String(first).uppercased() + step.dropFirst()
    }

    /// Remove steps where the same veggie appears for the same action type
    private func deduplicateSteps(_ steps: [CookingStep]) -> [CookingStep] {
        var seen = Set<String>()
        return steps.filter { step in
            let key: String
            switch step.type {
            case .wash(let v): key = "wash-\(v.rawValue)"
            case .peel(let v): key = "peel-\(v.rawValue)"
            case .chop(let v): key = "chop-\(v.rawValue)"
            case .slice(let v): key = "slice-\(v.rawValue)"
            case .grate(let v): key = "grate-\(v.rawValue)"
            case .dice(let v): key = "dice-\(v.rawValue)"
            case .addToPan(let name, _): key = "addToPan-\(name)"
            default: key = UUID().uuidString // always unique
            }
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}

// MARK: - Cooking Session View

struct CookingSessionView: View {
    let recipe: Recipe
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss

    // Step state machine
    @State private var steps: [CookingStep] = []
    @State private var currentStepIndex = 0
    @State private var stepScores: [Int] = []
    @State private var showCompletion = false
    @State private var transitioning = false

    // Rewards
    @State private var earnedStars = 0
    @State private var earnedCoins = 0
    @State private var earnedXP = 0

    // Pip encouragement between steps
    @State private var showPipTransition = false
    @State private var pipTransitionText = ""

    private let pipEncouragements = [
        "Nice work!", "Keep going!", "You're a natural!",
        "Almost there!", "Smells delicious!", "Great job, chef!",
        "Looking good!", "Yummy!", "Pip approves!"
    ]

    var body: some View {
        ZStack {
            Color.AppTheme.cream
                .ignoresSafeArea()

            if showCompletion {
                CookingCompletionView(
                    recipe: recipe,
                    stars: earnedStars,
                    coins: earnedCoins,
                    xp: earnedXP,
                    onDismiss: { dismiss() }
                )
            } else if steps.isEmpty {
                // Loading
                ProgressView("Preparing kitchen...")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            } else {
                VStack(spacing: 0) {
                    // Header with progress
                    headerView

                    // Instruction text
                    if !transitioning, let step = currentStep {
                        Text(step.instruction)
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.xs)
                            .transition(.opacity)
                    }

                    // Mini-game area
                    if showPipTransition {
                        pipTransitionView
                            .transition(.opacity)
                    } else if let step = currentStep {
                        miniGameView(for: step)
                            .id(step.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }

                    // Pip message
                    if !transitioning, let step = currentStep {
                        pipMessageView(step.pipMessage)
                    }
                }
            }
        }
        .onAppear {
            steps = recipe.generateCookingSteps()
        }
    }

    // MARK: - Current Step

    private var currentStep: CookingStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.md) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.AppTheme.sepia.opacity(0.6))
                }

                Image(recipe.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(recipe.title)
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)

                Spacer()

                Text("Step \(currentStepIndex + 1)/\(steps.count)")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.AppTheme.parchment)
                    Capsule()
                        .fill(Color.AppTheme.sage)
                        .frame(width: geo.size.width * progressFraction)
                        .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xs)
        }
    }

    private var progressFraction: CGFloat {
        guard !steps.isEmpty else { return 0 }
        return CGFloat(currentStepIndex) / CGFloat(steps.count)
    }

    // MARK: - Mini Game Router

    @ViewBuilder
    private func miniGameView(for step: CookingStep) -> some View {
        switch step.type {
        case .heatPan:
            HeatPanMiniGame(onComplete: handleStepComplete)

        case .addFat(let item):
            AddToPanMiniGame(
                itemName: item.displayName,
                itemImage: item.imageName,
                useEmoji: true,
                emoji: item.emoji,
                onComplete: handleStepComplete
            )

        case .wash(let veg):
            WashMiniGame(vegetable: veg, onComplete: handleStepComplete)

        case .peel(let veg):
            PeelMiniGame(vegetable: veg, onComplete: handleStepComplete)

        case .chop(let veg), .dice(let veg):
            ChopMiniGame(
                vegetable: veg,
                targetChops: difficulty == .easy ? 3 : 5,
                onComplete: handleStepComplete
            )

        case .slice(let veg):
            ChopMiniGame(
                vegetable: veg,
                targetChops: difficulty == .easy ? 3 : 4,
                onComplete: handleStepComplete
            )

        case .grate(let veg):
            PeelMiniGame(vegetable: veg, onComplete: handleStepComplete)

        case .crack:
            CrackEggMiniGame(onComplete: handleStepComplete)

        case .addToPan(let name, let image):
            AddToPanMiniGame(
                itemName: name,
                itemImage: image,
                useEmoji: false,
                emoji: "",
                onComplete: handleStepComplete
            )

        case .stir:
            StirMiniGame(onComplete: handleStepComplete)

        case .season(let items):
            SeasonMiniGame(items: items, onComplete: handleStepComplete)

        case .cook(let seconds):
            CookTimerMiniGame(totalSeconds: seconds, onComplete: handleStepComplete)

        case .assemble(let instruction):
            AssembleMiniGame(instruction: instruction, onComplete: handleStepComplete)
        }
    }

    private var difficulty: DifficultyBadge.Level { recipe.difficulty }

    // MARK: - Step Completion

    private func handleStepComplete(_ score: Int) {
        stepScores.append(score)

        if currentStepIndex >= steps.count - 1 {
            // All steps done
            let avgScore = stepScores.reduce(0, +) / max(stepScores.count, 1)
            calculateRewards(score: avgScore)
            withAnimation(.easeInOut(duration: 0.4)) {
                showCompletion = true
            }
        } else {
            // Show Pip transition, then advance
            pipTransitionText = pipEncouragements.randomElement() ?? "Nice!"
            withAnimation(.easeInOut(duration: 0.3)) {
                showPipTransition = true
                transitioning = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStepIndex += 1
                    showPipTransition = false
                    transitioning = false
                }
            }
        }
    }

    // MARK: - Pip Transition

    private var pipTransitionView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            PipWavingAnimatedView(size: 100)
            Text(pipTransitionText)
                .font(.AppTheme.title3)
                .foregroundColor(Color.AppTheme.darkBrown)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pip Message

    private func pipMessageView(_ message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            PipWavingAnimatedView(size: 44)
            Text(message)
                .font(.AppTheme.callout)
                .foregroundColor(Color.AppTheme.sepia)
                .lineLimit(2)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(16)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    // MARK: - Calculate Rewards

    private func calculateRewards(score: Int) {
        if score >= 85 {
            earnedStars = 3
            earnedCoins = 50
            earnedXP = 45
        } else if score >= 60 {
            earnedStars = 2
            earnedCoins = 40
            earnedXP = 35
        } else {
            earnedStars = 1
            earnedCoins = 30
            earnedXP = 25
        }

        gameState.completeCooking(
            recipeID: recipe.id,
            stars: earnedStars,
            coins: earnedCoins,
            xp: earnedXP
        )
    }
}

// MARK: - Preview

#Preview {
    CookingSessionView(recipe: GardenRecipes.all[0])
        .environmentObject(GameState.preview)
}
