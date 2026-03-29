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
    var playerName: String = "friend"
    var growingVeggies: [String] = []
    var harvestedVeggies: [String] = []
    var cookedRecipes: [String] = []
    var coins: Int = 0

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

        Use getGardenStatus to see what the player is doing in their garden.
        Use getVeggieFact to share accurate facts about specific plants.

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

        let gardenTool = GetGardenStatusTool(context: gameContext)
        let veggieTool = GetVeggieFactTool()

        // TEACHING MOMENT: Tools are passed at session creation.
        // The model reads tool names + descriptions to learn what's
        // available, then autonomously decides when to call them
        // based on the kid's questions. We don't manually trigger tools.
        session = LanguageModelSession(
            tools: [gardenTool, veggieTool],
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
}

#endif // canImport(FoundationModels)
