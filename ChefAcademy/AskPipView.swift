//
//  AskPipView.swift
//  ChefAcademy
//
//  Chat screen where kids talk to Pip about food and gardening.
//  Uses Claude Haiku API — Pip remembers the whole conversation!
//
//  DESIGN:
//  - Starter questions for young kids who can't type
//  - Dynamic follow-ups that change based on the conversation
//  - Text input for older kids
//  - Game context so Pip knows what the kid is growing/cooking
//

import SwiftUI

// MARK: - Chat Message

struct PipChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isFromPip: Bool
    let timestamp = Date()
}

// MARK: - Ask Pip View

struct AskPipView: View {

    @StateObject private var aiService = PipAIService()
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var sessionManager: SessionManager
    @State private var messages: [PipChatMessage] = []
    @State private var inputText = ""
    @State private var followUpQuestions: [String] = []
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
                                pipBubble(message.text)
                            } else {
                                kidBubble(message.text)
                            }
                        }

                        // Loading indicator
                        if aiService.isLoading {
                            pipTypingIndicator
                        }

                        // Rate limit message — kid-friendly "Pip is resting"
                        if aiService.isRateLimited {
                            pipBubble("Whew, I talked a LOT today! My voice needs a little rest. Come back tomorrow and I'll have new fun facts for you! Sweet dreams! 😴")
                        }

                        // Error
                        if let error = aiService.lastError {
                            Text("Pip says: \(error)")
                                .font(.AppTheme.caption)
                                .foregroundColor(.red.opacity(0.7))
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
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: followUpQuestions) { _ in
                    // Scroll to show follow-up chips
                    if let last = messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
        .onAppear {
            injectGameContext()
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
            return "Hey \(name)! I see you're growing \(growingCount) plants in your garden — awesome! Ask me anything about veggies, cooking, or gardening! 🌱"
        } else {
            return "Hey \(name)! I'm Pip, your garden buddy! Ask me anything about veggies, cooking, or gardening — I love talking about food! 🌱"
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
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

                // Show remaining questions — creates anticipation!
                let remaining = aiService.questionsRemainingToday
                if remaining <= 5 && remaining > 0 {
                    Text("\(remaining) questions left today")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                } else if remaining == 0 {
                    Text("Pip is resting until tomorrow")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.AppTheme.terracotta)
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
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image("pip_neutral")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .background(
                    Circle()
                        .fill(Color.AppTheme.sage.opacity(0.2))
                        .frame(width: 44, height: 44)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)

                Text(text)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(16)
            .cornerRadius(4, corners: [.topLeft])

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
                .cornerRadius(16)
                .cornerRadius(4, corners: [.topRight])
        }
    }

    // MARK: - Typing Indicator

    private var pipTypingIndicator: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image("pip_neutral")
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
            .cornerRadius(16)

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
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
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
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
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
        HStack(spacing: AppSpacing.sm) {
            TextField("Ask Pip a question...", text: $inputText)
                .font(.AppTheme.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(24)
                .submitLabel(.send)
                .onSubmit { sendTypedQuestion() }

            Button(action: sendTypedQuestion) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiService.isRateLimited
                            ? Color.AppTheme.sepia.opacity(0.3)
                            : Color.AppTheme.sage
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiService.isLoading || aiService.isRateLimited)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.AppTheme.cream)
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

        let cooked = gameState.unlockedRecipeIDs
            .compactMap { id in GardenRecipes.all.first(where: { $0.id == id })?.title }

        let name = sessionManager.activeProfile?.name ?? "Little Chef"

        aiService.updateGameContext(
            playerName: name,
            growingVeggies: growing,
            harvestedVeggies: harvested,
            cookedRecipes: cooked,
            coins: gameState.coins
        )
    }

    // MARK: - Send Question

    private func sendQuestion(_ question: String) {
        withAnimation {
            followUpQuestions = []
        }

        let kidMessage = PipChatMessage(text: question, isFromPip: false)
        messages.append(kidMessage)

        Task {
            if let response = await aiService.askPip(question) {
                let pipMessage = PipChatMessage(text: response, isFromPip: true)
                await MainActor.run {
                    messages.append(pipMessage)
                    // Generate follow-up suggestions based on Pip's response
                    withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
                        followUpQuestions = generateFollowUps(from: response, question: question)
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
}
