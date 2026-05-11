//
//  AskPipView.swift
//  ChefAcademy
//
//  Chat screen where kids talk to Pip about food and gardening.
//  Supports TWO AI backends (chosen automatically):
//    - On-device (iOS 26+): Free, private, unlimited, works offline
//    - Cloud (Claude Haiku): Works on any iOS, needs internet
//
//  DESIGN:
//  - Starter questions for young kids who can't type
//  - Dynamic follow-ups that change based on the conversation
//  - Text input for older kids
//  - Game context so Pip knows what the kid is growing/cooking
//

import SwiftUI

// MARK: - Parsed Recipe (from AI response)

struct ParsedRecipeSuggestion: Equatable {
    let name: String
    let description: String
    let ingredients: [String]
    let nutritionFact: String
    let steps: [String]
}

// MARK: - Chat Message

struct PipChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isFromPip: Bool
    let timestamp = Date()
    var recipeSuggestion: ParsedRecipeSuggestion? = nil
}

// MARK: - Ask Pip View

struct AskPipView: View {

    @StateObject private var aiService = PipAIService()
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var messages: [PipChatMessage] = []
    @State private var inputText = ""
    @State private var followUpQuestions: [String] = []
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    // Starter questions — shown before the first message.
    // Organized by topic so kids can explore what interests them.
    //
    // PSYCHOLOGY TRICK: "Curiosity gap" — questions that hint at
    // a surprising answer make kids WANT to tap them.
    // "Why do onions make you cry?" is way more tempting than
    // "Tell me about onions."
    //
    private let starterQuestions: [(topic: String, questions: [String])] = [
        ("Garden", [
            "What veggie grows the fastest?",
            "How do plants drink water?",
            "Can I grow strawberries at home?",
            "Why do we put seeds in dirt?"
        ]),
        ("Cooking", [
            "What's the easiest thing to cook?",
            "Why do we wash veggies before eating?",
            "How does heat cook food?",
            "What's your favorite recipe, Pip?"
        ]),
        ("Fun Facts", [
            "Why are carrots orange?",
            "What's the biggest fruit ever?",
            "Why do onions make you cry?",
            "Are tomatoes a fruit or veggie?"
        ]),
        ("Nutrition", [
            "Why is broccoli good for me?",
            "What veggies can I eat raw?",
            "Which foods make you strong?",
            "What gives you the most energy?"
        ]),
        ("Create", [
            "Invent me a recipe with what I have!",
            "What can I cook right now?",
            "Surprise me with a new recipe!"
        ])
    ]

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header
            headerBar

            Divider()

            // MARK: - Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {

                        // Welcome message
                        pipBubble(welcomeMessage)
                            .id("welcome")

                        // Starter questions (before first message)
                        if messages.isEmpty {
                            starterQuestionsView
                                .transition(.opacity)
                        }

                        // Chat messages
                        ForEach(messages) { message in
                            if message.isFromPip {
                                if let recipe = message.recipeSuggestion {
                                    recipeSuggestionCard(recipe: recipe, pipMessage: message.text)
                                } else {
                                    pipBubble(message.text)
                                }
                            } else {
                                kidBubble(message.text)
                            }
                        }

                        // Streaming text — shows words appearing in real-time!
                        // TEACHING MOMENT: When the on-device model is streaming,
                        // we show partial text instead of bouncing dots. This
                        // makes the response feel instant even though the model
                        // is still generating. It's the same trick ChatGPT uses.
                        if let streamingText = aiService.streamingText {
                            pipBubble(streamingText)
                                .id("streaming")
                        } else if aiService.isLoading {
                            // Fallback: bouncing dots for cloud mode (no streaming)
                            pipTypingIndicator
                        }

                        // Rate limit message — only for cloud mode (on-device is unlimited!)
                        if aiService.isRateLimited && !aiService.isOnDevice {
                            pipBubble("Whew, I talked a LOT today! My voice needs a little rest. Come back tomorrow and I'll have new fun facts for you! Sweet dreams! 😴")
                        }

                        // Error
                        if let error = aiService.lastError {
                            Text("Pip says: \(error)")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.terracotta.opacity(0.7))
                                .padding(.horizontal, AppSpacing.md)
                        }

                        // Follow-up question chips (after Pip responds)
                        if !followUpQuestions.isEmpty && !aiService.isLoading {
                            followUpChips
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(AppSpacing.md)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: followUpQuestions) { _, _ in
                    // Scroll to show follow-up chips
                    if let last = messages.last {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.2))
                            guard !Task.isCancelled else { return }
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .top)
                            }
                        }
                    }
                }
            }

            Divider()

            // MARK: - Input Bar
            inputBar
        }
        .background(Color.AppTheme.cream)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
        .onAppear {
            injectGameContext()
            // Sync trial state → PipAIService's daily limit tightens during trial (5 Q/day)
            aiService.trialActive = subscriptionManager.isInTrial
        }
        .onChange(of: subscriptionManager.isInTrial) { _, newValue in
            aiService.trialActive = newValue
        }
    }

    // MARK: - Welcome Message
    //
    // Personalized based on what the kid is doing in the game!
    //

    private var welcomeMessage: String {
        let name = sessionManager.activeProfile?.name ?? "friend"

        let growingCount = gameState.gardenPlots.filter { $0.state == .growing }.count
        if growingCount > 0 {
            return "Hey \(name)! I see you're growing \(growingCount) plants in your garden — awesome! Tap a question below or ask me anything about veggies, cooking, or gardening! 🌱"
        } else {
            return "Hey \(name)! I'm Pip, your garden buddy! Tap a question below to get started! 🌱"
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.sepia.opacity(0.5))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Chat with Pip")
                    .font(.AppTheme.title3)
                    .foregroundColor(Color.AppTheme.darkBrown)

                if !messages.isEmpty {
                    Button("New Chat") {
                        withAnimation {
                            messages = []
                            followUpQuestions = []
                            aiService.clearConversation()
                        }
                    }
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)
                }

                if subscriptionManager.isPremium {
                    // Premium badge — show questions remaining for transparency
                    let remaining = aiService.questionsRemainingToday
                    if remaining <= 5 && remaining > 0 {
                        Text("\(remaining) questions left today")
                            .font(.AppTheme.rounded(size: 10, weight: .medium))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    } else if remaining == 0 {
                        Text("Pip is resting until tomorrow")
                            .font(.AppTheme.rounded(size: 10, weight: .medium))
                            .foregroundColor(Color.AppTheme.terracotta)
                    } else {
                        Label("Pip Chat", systemImage: "sparkles")
                            .font(.AppTheme.rounded(size: 10, weight: .medium))
                            .foregroundColor(Color.AppTheme.sage)
                    }
                } else {
                    // Upgrade chip for base users
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Upgrade", systemImage: "sparkles")
                            .font(.AppTheme.rounded(size: 10, weight: .medium))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Pip Bubble

    private func pipBubble(_ text: String) -> some View {
        HStack {
            PipSpeechBubble(message: text, hasTail: true)
            Spacer(minLength: 40)
        }
    }

    // MARK: - Kid Bubble

    private func kidBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)

            Text(text)
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.cream)
                .padding(AppSpacing.sm)
                .background(Color.AppTheme.sage)
                .cornerRadius(AppSpacing.cardCornerRadius)
                .cornerRadius(4, corners: [.topRight])
        }
    }

    // MARK: - Recipe Suggestion Card

    private func recipeSuggestionCard(recipe: ParsedRecipeSuggestion, pipMessage: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Pip's intro message
            HStack {
                PipSpeechBubble(message: pipMessage, pose: .wavingFrame01, showsLabel: false)
                Spacer(minLength: 20)
            }

            // Recipe card
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Recipe name
                Text(recipe.name)
                    .font(.AppTheme.title3)
                    .foregroundColor(Color.AppTheme.darkBrown)

                // Description
                Text(recipe.description)
                    .font(.AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.sepia)

                Divider()

                // Ingredients
                Text("Ingredients")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)

                FlowLayout(spacing: 6) {
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        Text(ingredient)
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.AppTheme.parchment)
                            .cornerRadius(AppSpacing.pillCornerRadius)
                    }
                }

                // Nutrition fact
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(Color.AppTheme.goldenWheat)
                        .font(.AppTheme.caption)
                    Text(recipe.nutritionFact)
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sepia)
                }
                .padding(AppSpacing.sm)
                .background(Color.AppTheme.parchment.opacity(0.5))
                .cornerRadius(AppSpacing.pillCornerRadius)

                // Let's Cook button
                Button("Let's Cook This!") {
                    let tempRecipe = Recipe.fromAISuggestion(
                        name: recipe.name,
                        description: recipe.description,
                        ingredients: recipe.ingredients,
                        nutritionFact: recipe.nutritionFact,
                        steps: recipe.steps
                    )
                    gameState.pendingAIRecipe = tempRecipe
                    dismiss()
                }
                .texturedButton(tint: Color.AppTheme.sage)
            }
            .softCard()
        }
    }

    // MARK: - Recipe Parsing

    /// Try to parse a recipe from Pip's text response.
    /// Looks for patterns like recipe name, ingredients list, and numbered steps.
    private func parseRecipe(from text: String) -> ParsedRecipeSuggestion? {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard lines.count >= 4 else { return nil }

        // Look for numbered steps (1., 2., 3.)
        let stepLines = lines.filter { $0.hasPrefix("1.") || $0.hasPrefix("2.") || $0.hasPrefix("3.") || $0.hasPrefix("4.") || $0.hasPrefix("5.") || $0.hasPrefix("6.") }
        guard stepLines.count >= 2 else { return nil }

        // First non-step line is likely the recipe name/intro
        let nonStepLines = lines.filter { !stepLines.contains($0) }

        let name = nonStepLines.first ?? "Pip's Recipe"
        let description = nonStepLines.count > 1 ? nonStepLines[1] : "A recipe created just for you!"

        // Extract ingredient mentions (lines with commas or "and" before the steps)
        let ingredientLine = nonStepLines.first(where: { $0.contains(",") || $0.lowercased().contains("ingredient") }) ?? ""
        let ingredients = ingredientLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0.count < 30 }

        let steps = stepLines.map { line in
            // Remove the "1. " prefix
            if let dotIndex = line.firstIndex(of: ".") {
                return String(line[line.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
            }
            return line
        }

        let nutritionFact = nonStepLines.last(where: { $0.lowercased().contains("vitamin") || $0.lowercased().contains("nutrient") || $0.lowercased().contains("healthy") || $0.lowercased().contains("energy") }) ?? "Packed with vitamins and goodness!"

        return ParsedRecipeSuggestion(
            name: name,
            description: description,
            ingredients: ingredients.isEmpty ? ["Fresh ingredients"] : ingredients,
            nutritionFact: nutritionFact,
            steps: steps
        )
    }

    // MARK: - Typing Indicator

    private var pipTypingIndicator: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image("pip_got_idea")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .background(
                    Circle()
                        .fill(Color.AppTheme.sage.opacity(0.2))
                        .frame(width: 44, height: 44)
                )

            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.AppTheme.sepia.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .offset(y: aiService.isLoading ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                            value: aiService.isLoading
                        )
                }
            }
            .padding(AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)

            Spacer()
        }
    }

    // MARK: - Starter Questions (shown before first message)
    //
    // Organized by topic with colored headers so kids can
    // browse what interests them.
    //

    private var starterQuestionsView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(starterQuestions, id: \.topic) { section in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(section.topic)
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sage)
                        .fontWeight(.semibold)
                        .padding(.leading, 50)

                    FlowLayout(spacing: 8) {
                        ForEach(section.questions, id: \.self) { question in
                            Button(action: { sendQuestion(question) }) {
                                Text(question)
                                    .font(.AppTheme.caption)
                                    .foregroundColor(Color.AppTheme.darkBrown)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.AppTheme.warmCream)
                                    .cornerRadius(AppSpacing.largeCornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSpacing.largeCornerRadius)
                                            .stroke(Color.AppTheme.sage.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.leading, 50)
                }
            }
        }
    }

    // MARK: - Follow-Up Chips
    //
    // TEACHING MOMENT: "Dynamic suggestions" — instead of showing the
    // same questions every time, we generate follow-ups based on what
    // Pip just talked about. This creates a "conversation flow" that
    // feels natural, like talking to a friend who says "Oh, and also..."
    //

    private var followUpChips: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Keep chatting:")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
                .padding(.leading, 50)

            FlowLayout(spacing: 8) {
                ForEach(followUpQuestions, id: \.self) { question in
                    Button(action: { sendQuestion(question) }) {
                        Text(question)
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.AppTheme.sage.opacity(0.1))
                            .cornerRadius(AppSpacing.largeCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.largeCornerRadius)
                                    .stroke(Color.AppTheme.sage.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.leading, 50)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        Group {
            if subscriptionManager.isPremium {
                premiumInputBar
            } else {
                lockedInputBar
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.AppTheme.cream)
    }

    /// Full-featured input for paid subscribers.
    private var premiumInputBar: some View {
        HStack(spacing: AppSpacing.sm) {
            TextField("Ask Pip a question...", text: $inputText)
                .font(.AppTheme.body)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.largeCornerRadius)
                .submitLabel(.send)
                .onSubmit { sendTypedQuestion() }

            Button(action: sendTypedQuestion) {
                let isEmpty = inputText.trimmingCharacters(in: .whitespaces).isEmpty
                Image(systemName: "arrow.up.circle.fill")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(
                        isEmpty || aiService.isRateLimited
                            ? Color.AppTheme.sepia.opacity(0.3)
                            : Color.AppTheme.sage
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                      || aiService.isLoading
                      || aiService.isRateLimited)
        }
    }

    /// Tap-to-upgrade bar for base users. Looks like the input but opens the paywall.
    private var lockedInputBar: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                Text("Unlock Pip Chat to ask anything")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.AppTheme.sage)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.largeCornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inject Game Context
    //
    // Pulls data from GameState and tells Pip what the kid is up to.
    // This runs when the view appears.
    //

    private func injectGameContext() {
        let growing = gameState.gardenPlots
            .filter { $0.state == .growing }
            .compactMap { $0.vegetable?.displayName }

        let harvested = gameState.harvestedIngredients
            .map { "\($0.type.displayName) x\($0.quantity)" }

        // Only recipes the kid has ACTUALLY cooked (earned stars for).
        // `unlockedRecipeIDs` includes starter recipes available to cook but
        // not yet attempted — passing those to Claude as "cooked" made Pip
        // congratulate kids for meals they never made. `recipeStars` is the
        // real cooking record, shared with GameCenterService.
        let cooked = gameState.recipeStars.keys
            .compactMap { id in GardenRecipes.all.first(where: { $0.id == id })?.title }

        let name = sessionManager.activeProfile?.name ?? "Little Chef"

        // Basic context (player, garden, recipes, coins)
        aiService.updateGameContext(
            playerName: name,
            growingVeggies: growing,
            harvestedVeggies: harvested,
            cookedRecipes: cooked,
            coins: gameState.coins
        )

        // Pantry inventory — what's in the cupboard
        var pantryItems: [String: Int] = [:]
        for stock in gameState.pantryInventory where stock.quantity > 0 {
            pantryItems[stock.item.displayName] = stock.quantity
        }
        aiService.updatePantryContext(items: pantryItems)

        // Body Buddy organ health — so Pip can suggest foods for weak organs
        let organHealth: [String: Int] = [
            "Brain": gameState.brainHealth,
            "Heart": gameState.heartHealth,
            "Muscles": gameState.muscleHealth,
            "Bones": gameState.boneHealth,
            "Immune": gameState.immuneHealth,
            "Energy": gameState.energyLevel,
            "Eyes": gameState.eyeHealth,
            "Skin": gameState.skinHealth,
            "Digestion": gameState.digestiveHealth
        ]
        aiService.updateOrganHealthContext(health: organHealth)

        // Weather — from WeatherKit for seasonal planting advice
        let weather = GardenWeatherService.shared
        let condition = weather.currentWeather.displayName
        let temp = "\(weather.temperature)°F"
        aiService.updateWeatherContext(condition: condition, temperature: temp)

        // Allergies + dietary preference (from active UserProfile)
        let activeProfile = sessionManager.activeProfile
        let allergenStrings = (activeProfile?.allergens ?? []).map { $0.rawValue }
        let dietaryRaw = activeProfile?.headCovering.dietaryPreference.rawValue.lowercased() ?? "none"
        aiService.updateAllergiesContext(allergens: allergenStrings, dietaryPreference: dietaryRaw)

        // Siblings — query the family for other children, exclude active profile
        if let context = sessionManager.modelContext,
           let family = sessionManager.familyProfile {
            let allChildren = family.childProfiles(in: context)
            let siblings = allChildren
                .filter { $0.id != activeProfile?.id }
                .map { sibling -> PipSiblingInfo in
                    // Sibling level lives on PlayerData, not UserProfile
                    let level = sibling.playerData(in: context)?.playerLevel ?? 1
                    return PipSiblingInfo(
                        name: sibling.name,
                        level: level,
                        lastPlayedRelative: sibling.lastPlayedRelative
                    )
                }
            aiService.updateSiblingsContext(siblings)
        }

        // Cookable + almost-ready recipes — cross-reference inventory with real game recipes
        // Filter out anything that contains the active player's allergens
        let activeAllergens = activeProfile?.allergens ?? []
        let safeRecipes = GardenRecipes.all.filter { !$0.containsAllergens(activeAllergens) }

        let readyRecipes = safeRecipes
            .filter { $0.canCookFull(harvestedIngredients: gameState.harvestedIngredients,
                                     pantryInventory: gameState.pantryInventory) }
        let readyTitles = readyRecipes.map { $0.title }
        let glucoseTips: [String: String] = Dictionary(
            uniqueKeysWithValues: readyRecipes
                .filter { !$0.glucoseTip.isEmpty }
                .map { ($0.title, $0.glucoseTip) }
        )

        let almostReady: [PipAlmostReadyRecipe] = safeRecipes
            .filter { recipe in
                let hasGarden = recipe.canCook(with: gameState.harvestedIngredients)
                let hasFull = recipe.canCookFull(
                    harvestedIngredients: gameState.harvestedIngredients,
                    pantryInventory: gameState.pantryInventory
                )
                return hasGarden && !hasFull
            }
            .map { recipe in
                PipAlmostReadyRecipe(
                    title: recipe.title,
                    missingItems: recipe.missingPantryItems(from: gameState.pantryInventory)
                        .map(\.displayName)
                )
            }
        aiService.updateRecipesContext(
            readyNow: readyTitles,
            almostReady: almostReady,
            glucoseTips: glucoseTips
        )

        // Garden care — only plots that need attention right now
        let careNeeds: [PipPlotNeedCare] = gameState.gardenPlots.compactMap { plot in
            guard let veg = plot.vegetable else { return nil }
            switch plot.state {
            case .needsWater:   return PipPlotNeedCare(vegetable: veg.displayName, action: "water")
            case .needsWeeding: return PipPlotNeedCare(vegetable: veg.displayName, action: "weed")
            case .hasBugs:      return PipPlotNeedCare(vegetable: veg.displayName, action: "release ladybugs")
            default:            return nil
            }
        }
        aiService.updatePlotsNeedingCareContext(careNeeds)

        // Player progress — XP-to-next, helping streak, badges
        let xpForLevel = gameState.playerLevel * 100
        aiService.updateProgressContext(
            level: gameState.playerLevel,
            xp: gameState.xp,
            xpToNextLevel: xpForLevel,
            helpStreak: gameState.helpStreak,
            helpGivenCount: gameState.helpGivenCount,
            giftsGivenCount: gameState.giftsGivenCount,
            badgesEarned: gameState.completedBadgeIDs.count
        )

        // Daily quests — current progress for milestone celebrations
        let questProgress = gameState.dailyQuests.map { quest in
            PipQuestProgress(
                title: quest.title,
                current: quest.currentCount,
                target: quest.targetCount
            )
        }
        aiService.updateDailyQuestsContext(questProgress)
    }

    // MARK: - Send Question

    private func sendQuestion(_ question: String) {
        withAnimation { followUpQuestions = [] }

        // Base tier: route through static responses.
        // Premium-required questions present the paywall; curated questions get instant local answers.
        if !subscriptionManager.isPremium {
            let mode = PipStaticResponses.response(for: question, gameState: gameState)
            switch mode {
            case .requiresPremium:
                showPaywall = true
                return
            case .text(let reply):
                let kidMessage = PipChatMessage(text: question, isFromPip: false)
                messages.append(kidMessage)
                let delay = AnimationConstants.fadeMedium
                withAnimation(delay.delay(0.3)) {
                    let pipMessage = PipChatMessage(text: reply, isFromPip: true)
                    messages.append(pipMessage)
                }
                return
            }
        }

        // Premium tier — real Claude chat
        let kidMessage = PipChatMessage(text: question, isFromPip: false)
        messages.append(kidMessage)

        Task {
            if let response = await aiService.askPip(question) {
                // Try to detect if Pip generated a recipe
                let recipe = parseRecipe(from: response)
                let pipMessage = PipChatMessage(text: response, isFromPip: true, recipeSuggestion: recipe)
                await MainActor.run {
                    messages.append(pipMessage)

                    // Generate follow-up suggestions
                    // On-device: use the model-generated follow-up (from @Generable)
                    // Cloud: use local keyword matching (free, no extra API call)
                    withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
                        if let modelFollowUp = aiService.modelFollowUp {
                            // On-device model gave us a contextual follow-up!
                            let wildcards = [
                                "Tell me a fun food fact!",
                                "What's the weirdest veggie ever?",
                                "Surprise me with something cool!",
                                "What should I grow next?",
                                "Tell me a food joke!"
                            ]
                            followUpQuestions = [modelFollowUp, wildcards.randomElement()!]
                        } else {
                            followUpQuestions = generateFollowUps(from: response, question: question)
                        }
                    }
                }
            }

            // Keep last 20 messages visible
            await MainActor.run {
                if messages.count > 20 {
                    messages = Array(messages.suffix(20))
                }
            }
        }
    }

    private func sendTypedQuestion() {
        let question = inputText.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty else { return }
        inputText = ""
        sendQuestion(question)
    }

    // MARK: - Generate Follow-Up Suggestions
    //
    // TEACHING MOMENT: Instead of asking Claude for follow-ups
    // (which would cost extra API calls), we generate them locally
    // by detecting topics in Pip's response. Smart and free!
    //
    // This is a common pattern: use AI for the hard stuff (natural
    // language responses) and simple code for the easy stuff (topic detection).
    //

    private func generateFollowUps(from response: String, question: String) -> [String] {
        let text = (response + " " + question).lowercased()
        var suggestions: [String] = []

        // Topic-based follow-ups
        let topicFollowUps: [(keywords: [String], questions: [String])] = [
            (["carrot", "orange", "root"],
             ["What other veggies grow underground?", "Tell me more about orange foods!"]),
            (["tomato", "fruit", "berry"],
             ["What other foods are secretly fruits?", "How do tomatoes grow?"]),
            (["water", "rain", "drink", "roots"],
             ["How much water do plants need?", "What happens if you water too much?"]),
            (["seed", "plant", "grow", "garden"],
             ["What's the easiest thing to grow?", "How long do seeds take to sprout?"]),
            (["cook", "recipe", "kitchen", "heat"],
             ["What can I cook with veggies?", "Why does cooking change how food tastes?"]),
            (["vitamin", "healthy", "strong", "energy", "good for"],
             ["Which veggie has the most vitamins?", "What foods give you super energy?"]),
            (["broccoli", "green", "leaf"],
             ["Why are so many veggies green?", "What's the most nutritious green veggie?"]),
            (["strawberry", "berry", "sweet", "fruit"],
             ["Can I grow berries at home?", "What makes fruit sweet?"]),
            (["onion", "cry", "garlic"],
             ["Why does garlic smell so strong?", "What veggies are in the same family?"]),
            (["potato", "sweet potato", "underground"],
             ["What's the difference between potatoes and sweet potatoes?", "What grows underground?"]),
            (["color", "red", "purple", "yellow"],
             ["Do different colored veggies do different things?", "What's the most colorful veggie?"]),
            (["bug", "insect", "worm", "bee"],
             ["Do bees help gardens grow?", "Are worms good for gardens?"]),
            (["sun", "light", "sunshine"],
             ["Why do plants need sunlight?", "Can plants grow in the dark?"]),
        ]

        for topic in topicFollowUps {
            if topic.keywords.contains(where: { text.contains($0) }) {
                suggestions.append(contentsOf: topic.questions)
            }
        }

        // Always have a fun wildcard option
        let wildcards = [
            "Tell me a fun food fact!",
            "What's the weirdest veggie ever?",
            "Surprise me with something cool!",
            "What should I grow next?",
            "Tell me a food joke!"
        ]

        // Pick 2-3 topic suggestions + 1 wildcard
        suggestions = Array(Set(suggestions)).shuffled()
        let topicPicks = Array(suggestions.prefix(2))
        let wildcard = wildcards.randomElement()!

        var result = topicPicks
        result.append(wildcard)
        return result
    }
}

// FlowLayout and cornerRadius(_:corners:) are defined in RecipeDetailView.swift

// MARK: - Preview

#Preview {
    AskPipView()
        .environmentObject(GameState.preview)
        .environmentObject(SessionManager())
}
