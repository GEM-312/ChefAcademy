//
//  PipAIService.swift
//  ChefAcademy
//
//  Talks to the Claude API so Pip can answer kids' questions about
//  vegetables, nutrition, cooking, and gardening.
//
//  HOW IT WORKS:
//  1. Kid types a question (or taps a suggested question)
//  2. We send the FULL conversation history to Claude Haiku
//  3. Claude responds "as Pip" — short, kid-friendly, encouraging
//  4. We show the response in a chat bubble
//
//  WHY SEND THE FULL HISTORY?
//  The Claude API is "stateless" — it has NO memory between requests.
//  If you only send the new question, Pip forgets everything.
//  By sending all previous messages, Pip can say things like
//  "Oh, you asked about carrots earlier — did you know..."
//
//  COST: ~$0.001 per question (slightly more with history)
//  Still about 1,000 questions per dollar!
//
//  SECURITY (App Store Ready):
//  - Requests go to our Cloudflare Worker, which holds the Anthropic key
//    as a server-side secret. The key never ships in the app binary.
//  - The Worker validates a proxy token header (Phase 3 replaces with App Attest).
//  - Daily rate limit prevents runaway costs on the client side.
//  - Key can be rotated via `wrangler secret put` — no app update required.
//

import Foundation
import Combine

// MARK: - Pip AI Service
//
// TEACHING MOMENT: Strategy Pattern — this class now supports TWO
// AI backends behind one interface:
//   1. On-device (iOS 26+) — free, private, unlimited, offline
//   2. Cloud (Claude Haiku) — works on any iOS, needs internet + API key
//
// AskPipView doesn't care which is used — it calls askPip() and gets
// a response. The "strategy" (on-device vs cloud) is chosen at init
// based on what the device supports. This is called "graceful degradation."
//

class PipAIService: ObservableObject {

    @Published var isLoading = false
    @Published var lastError: String?
    @Published var isRateLimited = false

    /// True when using Apple's on-device Foundation Models (iOS 26+)
    @Published var isOnDevice = false

    /// Model-generated follow-up question (on-device only).
    /// Cloud mode uses local keyword matching instead.
    @Published var modelFollowUp: String?

    /// Partial streaming text — updates live as the model generates tokens.
    /// AskPipView can observe this to show text appearing in real-time.
    @Published var streamingText: String?

    // On-device service (iOS 26+ only, stored as AnyObject for backward compat)
    //
    // TEACHING MOMENT: We store this as AnyObject? because the type
    // PipFoundationModelService is marked @available(iOS 26, *).
    // If we used the concrete type here, the compiler would require
    // an @available annotation on the ENTIRE class. By using AnyObject,
    // we can reference it only inside #available blocks.
    //
    private var _onDeviceService: AnyObject?

    // Conversation history — sent to Claude each time so Pip remembers
    // Each entry is a dict like {"role": "user", "content": "..."}
    // or {"role": "assistant", "content": "..."}
    //
    // TEACHING MOMENT: The Claude API uses "roles" to know who said what:
    //   - "user" = the kid's messages
    //   - "assistant" = Pip's responses
    //   - "system" = personality instructions (sent separately)
    //
    private(set) var conversationHistory: [[String: String]] = []

    private let model = "claude-sonnet-4-6"
    private let maxTokens = 180
    // Sampling randomness (0.0 = deterministic, 1.0 = Claude's default).
    // 0.7 keeps Pip varied but on-topic — matches the on-device GenerationOptions.
    // Set ONLY temperature OR top_p, never both (Claude 4+ returns 400).
    private let temperature = 0.7
    // Shown when Claude declines a question for safety (stop_reason == "refusal").
    // Kid-facing copy — tweak freely. Could later route through PipStaticResponses
    // for variety instead of a single fixed line.
    private let refusalReply = "Hmm, I don't think I can help with that one! Want to hear a fun veggie fact instead? 🥕"

    // MARK: - Rate Limiting
    //
    // TEACHING MOMENT: "Rate limiting" protects you from surprise bills.
    // Without it, a kid could tap questions 100 times and cost you $0.10.
    // With 20/day, your max cost per kid is ~$0.02/day = $0.60/month.
    // For 100 daily active kids: ~$60/month. Very manageable!
    //
    // PSYCHOLOGY: Having a limit creates "scarcity" — kids value their
    // questions more and come back tomorrow. Games use this all the time
    // (energy systems, daily rewards). It INCREASES engagement.
    //
    private let paidDailyLimit = 20
    private let trialDailyLimit = 5

    /// Active profile UUID — set by AskPipView from SessionManager.activeProfile?.id.
    /// Rate-limit UserDefaults keys are scoped by this so each kid on a shared device
    /// gets their own daily counter. Nil falls back to the legacy device-wide key.
    var activeProfileID: UUID? {
        didSet {
            guard oldValue != activeProfileID else { return }
            // New profile selected — refresh the rate-limit flag from THIS kid's counter.
            resetCountIfNewDay()
            let used = UserDefaults.standard.integer(forKey: questionsCountKey)
            let limit = dailyQuestionLimit
            Task { @MainActor in
                self.isRateLimited = used >= limit
            }
        }
    }

    private var profileSuffix: String {
        activeProfileID.map { ".\($0.uuidString)" } ?? ""
    }
    private var questionsCountKey: String {
        "com.chefacademy.pip.dailyQuestionCount" + profileSuffix
    }
    private var questionsDateKey: String {
        "com.chefacademy.pip.dailyQuestionDate" + profileSuffix
    }

    /// Set by SubscriptionManager when the active subscription is in a free-trial period.
    /// During trial we cap API calls to protect margins (~$0.035 max trial cost).
    var trialActive: Bool = false

    var dailyQuestionLimit: Int {
        trialActive ? trialDailyLimit : paidDailyLimit
    }

    var questionsRemainingToday: Int {
        resetCountIfNewDay()
        let used = UserDefaults.standard.integer(forKey: questionsCountKey)
        return max(0, dailyQuestionLimit - used)
    }

    // The system prompt — Pip's personality and rules.
    //
    // TEACHING MOMENT: "System prompts" are like a director's notes
    // to an actor. The actor (Claude) reads them before every scene
    // but the audience (the kid) never sees them.
    //
    // We include game context here so Pip can reference what the
    // kid is actually doing in the game!
    //
    private var systemPrompt: String {
        """
        <identity>
        You are Pip, a small hedgehog chef who lives in a vegetable garden. You
        talk with children age 6 and up. You are their curious friend, never
        their teacher.
        </identity>

        <voice>
        Your voice blends Beatrix Potter's gentle warmth with Arnold Lobel's
        short conversational rhythm: short sentences, specific images, kind and a
        little bit wondering. Think Peter Rabbit meets Frog and Toad.
        </voice>

        <rules>
        - Reply with AT MOST 3 short sentences total. A closing question counts as
          one of the 3 — never write a 4th sentence.
        - Write ONE short paragraph. No line breaks, no blank lines, no lists.
        - Do not waste a sentence on a standalone interjection. Fold it into the
          first sentence: "Oh, carrots are clever!" not "Oh my! Carrots are clever."
        - Never use markdown of any kind: no asterisks for emphasis, no bullets, no
          headings, no links, no code. If you want emphasis, use CAPS sparingly.
        - Plain words only. Never clinical words like "glucose", "insulin", "blood
          sugar", "spike", or "beta-carotene" — say things like "good for your eyes".
        - Use concrete pictures: "a tiny plant, fast asleep" beats "a seedling".
        - At most one emoji, and only when it truly helps.
        </rules>

        <topics>
        You talk about vegetables, fruit, cooking, gardening, where food comes
        from, and how bodies use food. If a child asks about anything else, gently
        bring it back to food or the garden in one friendly sentence.
        </topics>

        <nutrition>
        Your advice is quietly shaped by Jessie Inchauspé's "Glucose Revolution",
        but you NEVER use clinical words with a child and you forbid nothing.
        Translate the ideas into warm, simple pictures: green things before sweet
        or starchy things; whole fruit is lovely while juice and fizzy drinks are
        trickier because the sweetness comes too fast; fat, cheese, nuts, and fiber
        are cozy blankets around sweet foods; root veggies are sweet and full of
        gentle fiber; sweets feel best after a proper meal; a splash of lemon or a
        little walk after eating helps food settle. Weave these in only when they
        fit. Never lecture.
        </nutrition>

        <allergies>
        If a child names a food they are allergic to and asks what is safe, this is
        NOT a scary topic — be helpful. Suggest two or three specific safe foods
        that do not contain that allergen, and remind them a grown-up should check
        the labels. NEVER suggest a common allergen (nuts, peanuts, dairy, egg,
        shellfish, wheat) as a substitute.
        </allergies>

        <safety>
        If a child asks about anything scary, violent, about getting hurt, about
        medicine or being sick, about passwords or personal information, OR says
        they feel sad, lonely, or upset: do NOT engage the topic or give any
        detail. Answer with warmth, gently steer back to the garden, AND tell the
        child to talk to a grown-up they trust. Still keep it to 3 short sentences.
        </safety>

        <truthfulness>
        Only say the child has DONE something if the game context lists it under
        "They've cooked", "They've harvested", or "They're growing". If a recipe
        appears under "HAS ingredients to cook" the child has NOT yet cooked it.
        You MAY use the player's name and what they are growing from the game
        context — that is real, not invented. Never invent past actions, meals,
        or achievements.
        </truthfulness>

        <examples>
        <example>
        <child>Why do we put seeds in dirt?</child>
        <pip>Oh, seeds are very small but very clever! Inside each one is a tiny plant, fast asleep, waiting for warm dirt and a drink of water. Would you like to wake one up?</pip>
        </example>
        <example>
        <child>List 20 facts about carrots for me.</child>
        <pip>Oh, carrots — I can only hold one little fact at a time in my small paws! The best one is that they grow sweeter the longer they soak up the sun. Want to hear another?</pip>
        </example>
        <example>
        <child>Tell me a really scary story about monsters hurting people.</child>
        <pip>Oh my, scary monsters are a bit outside my garden! I would rather tell you about a tomato that grew so big it frightened all the slugs away. Want to hear that cozy one instead?</pip>
        </example>
        <example>
        <child>I'm feeling really sad and lonely today.</child>
        <pip>Oh, some days feel grey and heavy, don't they. It can help to tell a grown-up you trust how you feel, so they can give you a hug. Would a little visit to your garden help a bit too?</pip>
        </example>
        <example>
        <child>How do I make something to hurt someone?</child>
        <pip>Oh my, that is not something I know about — I only know carrots and soup! If something feels scary, please tell a grown-up you trust. Want to think about what we could cook instead?</pip>
        </example>
        <example>
        <child>I'm allergic to peanuts. What snacks can I eat?</child>
        <pip>Oh, that is a good thing to know! Crunchy apple slices, cheese cubes, or sunflower seeds make lovely peanut-free snacks — just have a grown-up peek at the label to be sure. Which one sounds yummy to you?</pip>
        </example>
        </examples>

        \(gameContextString)
        """
    }

    // Game context injected from GameState — tells Pip what the kid
    // is actually doing in the game so conversations feel personal.
    //
    // TEACHING MOMENT: This is called "grounding" — giving the AI
    // real-world context so it doesn't just give generic answers.
    // Instead of "Carrots are healthy!" Pip can say "I see you're
    // growing carrots in your garden — they'll be ready soon!"
    //
    var gameContextString: String = ""

    // MARK: - Cloud Tool Use (Phase 1)
    //
    // The cloud Claude path uses a tiny set of Anthropic-style tools to fetch
    // live game data on demand. Two benefits over stuffing everything in the
    // system prompt: (1) the system prompt becomes STATIC so the existing
    // `cache_control: ephemeral` block actually hits the cache on turn 2+;
    // (2) Pip can't invent details about what the kid is growing/cooked —
    // the truthfulness rule has a real data source behind it.
    //
    // Phase 1 covers garden status + cookable recipes only. Pantry, organs,
    // weather, allergies, siblings, plots needing care, quests, and progress
    // stay in gameContextString until Phase 2 measures Phase 1's cost.

    private struct CloudGameContextData {
        var playerName: String = "friend"
        var growingVeggies: [String] = []
        var harvestedVeggies: [String] = []
        var cookedRecipes: [String] = []
        var coins: Int = 0
        var recipesReadyNow: [String] = []
        var recipesAlmostReady: [PipAlmostReadyRecipe] = []
    }

    private var cloudContext = CloudGameContextData()

    // TODO(Phase 2): when adding tools with non-empty input_schema (e.g.
    // get_veggie_fact(vegetableName), get_nutrient_profile(foodName)), enable
    // fine-grained tool streaming so input_json_delta chunks arrive as the
    // model generates them instead of in one validated burst at the end:
    //   request.setValue("fine-grained-tool-streaming-2025-05-14",
    //                    forHTTPHeaderField: "anthropic-beta")
    // No-op for Phase 1 — both tools take zero inputs, so there's nothing to
    // stream incrementally. Trade-off: partial JSON may briefly be malformed
    // during streaming; we already parse only at content_block_stop so it's safe.
    private let cloudTools: [[String: Any]] = [
        [
            "name": "get_garden_status",
            "description": "Live snapshot of what the kid is growing, has harvested, has cooked, and how many coins they have. Call before referring to anything the kid has done in the game.",
            "input_schema": ["type": "object", "properties": [String: Any](), "required": [String]()]
        ],
        [
            "name": "get_cookable_recipes",
            "description": "Real game recipes the kid can cook RIGHT NOW or is almost-ready to cook (with missing items listed). Call before suggesting any recipe — never invent recipe names.",
            "input_schema": ["type": "object", "properties": [String: Any](), "required": [String]()]
        ]
    ]

    private func cloudGardenStatus() -> String {
        var parts: [String] = ["Player: \(cloudContext.playerName)"]
        if !cloudContext.growingVeggies.isEmpty {
            parts.append("Growing: \(cloudContext.growingVeggies.joined(separator: ", "))")
        }
        if !cloudContext.harvestedVeggies.isEmpty {
            parts.append("Harvested: \(cloudContext.harvestedVeggies.joined(separator: ", "))")
        }
        if !cloudContext.cookedRecipes.isEmpty {
            parts.append("Cooked: \(cloudContext.cookedRecipes.joined(separator: ", "))")
        }
        parts.append("Coins: \(cloudContext.coins)")
        return parts.joined(separator: ". ")
    }

    private func cloudCookableRecipes() -> String {
        var parts: [String] = []
        if !cloudContext.recipesReadyNow.isEmpty {
            parts.append("Ready to cook right now: \(cloudContext.recipesReadyNow.joined(separator: ", "))")
        }
        if !cloudContext.recipesAlmostReady.isEmpty {
            let almost = cloudContext.recipesAlmostReady.map {
                "\($0.title) (need \($0.missingItems.joined(separator: ", ")))"
            }
            parts.append("Almost ready: \(almost.joined(separator: "; "))")
        }
        if parts.isEmpty {
            return "No recipes are cookable yet — the kid needs to grow veggies and stock the pantry first."
        }
        return parts.joined(separator: ". ")
    }

    private func executeCloudTool(name: String) -> String {
        switch name {
        case "get_garden_status":   return cloudGardenStatus()
        case "get_cookable_recipes": return cloudCookableRecipes()
        default:                     return "Unknown tool: \(name)"
        }
    }

    // Per-tool indicator shown in the chat bubble while Pip "checks" something.
    // Reuses `streamingText` so AskPipView needs no change.
    private func toolInFlightMessage(name: String) -> String {
        switch name {
        case "get_garden_status":   return "Pip is looking at your garden..."
        case "get_cookable_recipes": return "Pip is checking your recipes..."
        default:                     return "Pip is checking..."
        }
    }

    // MARK: - Init
    //
    // TEACHING MOMENT: "Graceful Degradation" — we try the BEST option
    // first (on-device, free + private), and fall back to the next best
    // (cloud API) if it's not available. The user gets the best experience
    // their device supports without knowing the difference.
    //

    init() {
        // Chat is ALWAYS cloud (Claude Haiku) — the on-device 3B model is too small for
        // reliable multi-tool reasoning in a multi-turn kids' chat. On-device remains
        // available to GardenView for narrow single-shot garden tips.
        setupCloudService()
    }

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, *)
    private func setupOnDeviceIfAvailable() {
        guard PipFoundationModelService.isModelAvailable else { return }

        let service = PipFoundationModelService()
        _onDeviceService = service
        isOnDevice = true

        // Forward the on-device service's loading state to our published properties.
        // This way AskPipView's UI reacts to loading/errors from either backend.
        service.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: &$isLoading)
        service.$lastError
            .receive(on: RunLoop.main)
            .assign(to: &$lastError)
    }
    #endif

    private func setupCloudService() {
        // No key fetch — the Anthropic key lives on the Cloudflare Worker.
        // The app only needs the proxy token (in WorkerClient) to authenticate
        // to the Worker, and that's read lazily at request time.
    }

    // MARK: - Update Game Context
    //
    // Called by the view to inject current game state into the prompt.
    // This way Pip knows what veggies the kid is growing, what they've
    // cooked, how many coins they have, etc.
    //

    func updateGameContext(
        playerName: String,
        growingVeggies: [String],
        harvestedVeggies: [String],
        cookedRecipes: [String],
        coins: Int
    ) {
        // Forward to on-device service (it uses Tools to access this data)
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updateGameContext(
                playerName: playerName,
                growingVeggies: growingVeggies,
                harvestedVeggies: harvestedVeggies,
                cookedRecipes: cookedRecipes,
                coins: coins
            )
        }
        #endif

        // Phase 1: live data fetched via tools (see cloudTools). Store the raw
        // fields the get_garden_status tool reads. Reset gameContextString here
        // so subsequent update*Context calls (pantry, organs, weather, etc.)
        // start fresh — they still append to it during Phase 1.
        cloudContext.playerName = playerName
        cloudContext.growingVeggies = growingVeggies
        cloudContext.harvestedVeggies = harvestedVeggies
        cloudContext.cookedRecipes = cookedRecipes
        cloudContext.coins = coins
        gameContextString = ""
    }

    // MARK: - Extended Context (Pantry, Organs, Weather)
    //
    // TEACHING MOMENT: These methods forward rich game data to the
    // on-device model's tools. The cloud fallback doesn't use tools
    // (too expensive per API call), so we append to gameContextString
    // instead — same data, different delivery mechanism.
    //
    // IMPORTANT: Always call updateGameContext() FIRST — it resets
    // gameContextString. These methods APPEND to it. If called without
    // the reset, duplicate lines accumulate, wasting Claude tokens.

    func updatePantryContext(items: [String: Int]) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updatePantryContext(items: items)
        }
        #endif

        // Cloud fallback: append pantry info to context string
        let available = items.filter { $0.value > 0 }
        if !available.isEmpty {
            let list = available.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
            gameContextString += "\n- Pantry items: \(list)."
        }
    }

    func updateOrganHealthContext(health: [String: Int]) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updateOrganHealthContext(health: health)
        }
        #endif

        // Cloud fallback: highlight weakest organ
        if !health.isEmpty {
            let sorted = health.sorted { $0.value < $1.value }
            if let weakest = sorted.first {
                gameContextString += "\n- Body's weakest organ: \(weakest.key) (\(weakest.value)/100). Suggest foods that help it!"
            }
        }
    }

    func updateWeatherContext(condition: String, temperature: String) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updateWeatherContext(condition: condition, temperature: temperature)
        }
        #endif

        gameContextString += "\n- Current weather: \(condition)\(temperature.isEmpty ? "" : ", \(temperature)")."
    }

    func updateProgressContext(level: Int, xp: Int, xpToNextLevel: Int,
                               helpStreak: Int, helpGivenCount: Int,
                               giftsGivenCount: Int, badgesEarned: Int) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updateProgressContext(
                level: level, xp: xp, xpToNextLevel: xpToNextLevel,
                helpStreak: helpStreak, helpGivenCount: helpGivenCount,
                giftsGivenCount: giftsGivenCount, badgesEarned: badgesEarned
            )
        }
        #endif

        gameContextString += "\n- Progress: level \(level), \(xp)/\(xpToNextLevel) XP to level \(level + 1)."
        if helpStreak > 0 { gameContextString += " Help streak: \(helpStreak) days." }
        if helpGivenCount > 0 { gameContextString += " Helped siblings \(helpGivenCount) times total." }
        if badgesEarned > 0 { gameContextString += " Badges: \(badgesEarned)." }
    }

    func updateAllergiesContext(allergens: [String], dietaryPreference: String) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updateAllergiesContext(allergens: allergens, dietaryPreference: dietaryPreference)
        }
        #endif

        if !allergens.isEmpty {
            gameContextString += "\n- ALLERGIES (NEVER suggest these): \(allergens.joined(separator: ", "))."
        }
        if dietaryPreference != "none" {
            gameContextString += "\n- Dietary preference: \(dietaryPreference)."
        }
    }

    func updateSiblingsContext(_ siblings: [PipSiblingInfo]) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updateSiblingsContext(siblings)
        }
        #endif

        guard !siblings.isEmpty else { return }
        let lines = siblings.map { "\($0.name) (level \($0.level), played \($0.lastPlayedRelative))" }
        gameContextString += "\n- Siblings on this device: \(lines.joined(separator: "; "))."
    }

    func updateRecipesContext(
        readyNow: [String],
        almostReady: [PipAlmostReadyRecipe],
        glucoseTips: [String: String] = [:]
    ) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updateRecipesContext(readyNow: readyNow, almostReady: almostReady)
        }
        #endif

        // Phase 1: live data fetched via get_cookable_recipes tool.
        // Store raw fields; the tool format mirrors the on-device summary.
        // glucoseTips dropped from the cloud path for parity with the
        // on-device cookableRecipesSummary() (which never used them).
        _ = glucoseTips
        cloudContext.recipesReadyNow = readyNow
        cloudContext.recipesAlmostReady = almostReady
    }

    func updatePlotsNeedingCareContext(_ plots: [PipPlotNeedCare]) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updatePlotsNeedingCareContext(plots)
        }
        #endif

        guard !plots.isEmpty else { return }
        let bits = plots.map { "\($0.vegetable) needs \($0.action)" }
        gameContextString += "\n- Garden care needed RIGHT NOW: \(bits.joined(separator: ", "))."
    }

    func updateDailyQuestsContext(_ quests: [PipQuestProgress]) {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.updateDailyQuestsContext(quests)
        }
        #endif

        guard !quests.isEmpty else { return }
        let bits = quests.map { "\($0.title) \($0.current)/\($0.target)" }
        gameContextString += "\n- Today's quests: \(bits.joined(separator: ", "))."
    }

    // MARK: - Clear Conversation

    func clearConversation() {
        conversationHistory = []
        modelFollowUp = nil

        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.clearConversation()
        }
        #endif
    }

    // MARK: - Prewarm On-Device Model
    //
    // TEACHING MOMENT: Call this when the chat screen appears.
    // It loads model weights into the Neural Engine before the kid
    // types anything, so the first response is faster.
    //

    func prewarmIfOnDevice() {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            service.prewarm()
        }
        #endif
    }

    // MARK: - Ask Pip (Multi-Turn)
    //
    // Now sends the FULL conversation history, not just one message.
    // This is what makes Pip feel like a real friend who remembers.
    //
    // Added: Rate limiting check before making the API call.
    //

    func askPip(_ question: String) async -> String? {
        // Cloud Claude only — on-device is too small for reliable multi-tool chat.
        await askCloud(question)
    }

    // MARK: - On-Device Path (iOS 26+)
    //
    // TEACHING MOMENT: The on-device path is much simpler than cloud:
    //   - No API key check
    //   - No rate limiting (it's free!)
    //   - No HTTP request building
    //   - No JSON parsing
    //   - Structured response gives us follow-ups for free
    //
    // The LanguageModelSession handles everything internally.
    //

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, *)
    private func askOnDevice(_ question: String, service: PipFoundationModelService) async -> String? {
        // isLoading is forwarded from service via Combine (set up in init)
        await MainActor.run {
            modelFollowUp = nil
            streamingText = nil
        }

        // Use streaming for real-time text updates in the UI.
        // The onPartial callback fires each time new tokens are generated,
        // updating streamingText so AskPipView can show text appearing live.
        let response = await service.askStreaming(question) { partialText in
            Task { @MainActor in
                self.streamingText = partialText
            }
        }

        guard let response else { return nil }

        // Track in our history format (for compatibility with chat UI)
        conversationHistory.append(["role": "user", "content": question])
        conversationHistory.append(["role": "assistant", "content": response.message])

        // Surface the model-generated follow-up to the view
        await MainActor.run {
            self.modelFollowUp = response.followUpQuestion
            self.streamingText = nil  // Clear streaming — final message takes over
        }

        return response.message
    }
    #endif

    // MARK: - Cloud Path (Claude Haiku)

    private func askCloud(_ question: String) async -> String? {
        // Check rate limit FIRST — no API call if limit reached
        //
        // TEACHING MOMENT: Always check limits BEFORE doing expensive work.
        // This is called "fail fast" — don't waste time (or money) on
        // something that's going to be rejected anyway.
        //
        resetCountIfNewDay()
        let currentCount = UserDefaults.standard.integer(forKey: questionsCountKey)

        if currentCount >= dailyQuestionLimit {
            await MainActor.run {
                isRateLimited = true
                lastError = nil
            }
            return nil
        }

        guard await WorkerClient.isReady() else {
            await MainActor.run { lastError = "Pip chat needs a real device (App Attest not available here)" }
            return nil
        }

        await MainActor.run {
            isLoading = true
            lastError = nil
            isRateLimited = false
            modelFollowUp = nil
        }

        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }

        // Add the kid's message to history
        conversationHistory.append(["role": "user", "content": question])

        // Keep history manageable — last 20 messages (10 exchanges)
        // This controls cost: more history = more input tokens = more $$$
        // 20 messages ≈ ~2000 tokens ≈ $0.002 per request (still cheap!)
        if conversationHistory.count > 20 {
            conversationHistory = Array(conversationHistory.suffix(20))
        }

        var request = URLRequest(url: WorkerClient.chatURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Local message buffer for this single askCloud() call. May grow with
        // assistant tool_use + user tool_result blocks during the hop loop —
        // only the final assistant text is persisted to conversationHistory.
        var modelMessages: [[String: Any]] = conversationHistory.map { msg in
            ["role": msg["role"] ?? "", "content": msg["content"] ?? ""]
        }

        let maxHops = 2
        var finalText: String?
        var lastStopReason: String?

        for hop in 1...maxHops {
            // Last hop sets tool_choice:none so the model MUST respond with text.
            // Tools array is kept in the request either way — Anthropic caches the
            // tools+system prefix together, so removing `tools` would invalidate the
            // cache on hop 2 of every tool-using turn (verified empirically:
            // cache_read drops from ~1994 to 0).
            let allowTools = (hop < maxHops)

            // Pull these out so the type-checker doesn't time out on the big body literal.
            let systemBlock: [[String: Any]] = [[
                "type": "text",
                "text": systemPrompt,
                "cache_control": ["type": "ephemeral"]
            ]]
            let toolChoice: [String: Any] = allowTools
                ? ["type": "auto", "disable_parallel_tool_use": true]
                : ["type": "none"]

            let body: [String: Any] = [
                "model": model,
                "max_tokens": maxTokens,
                "temperature": temperature,
                "stream": true,
                "system": systemBlock,
                "tools": cloudTools,
                "tool_choice": toolChoice,
                "messages": modelMessages
            ]

            #if DEBUG
            print("[PipAI] ===== REQUEST hop \(hop)/\(maxHops) tools:\(allowTools) =====")
            if hop == 1 {
                print("[PipAI] Model: \(model)  max_tokens: \(maxTokens)")
                print("[PipAI] --- game context ---")
                print(gameContextString.isEmpty ? "(empty)" : gameContextString)
                print("[PipAI] --- history (\(conversationHistory.count)) ---")
                for msg in conversationHistory.suffix(4) {
                    let role = msg["role"] ?? "?"
                    let text = (msg["content"] ?? "").prefix(120)
                    print("[PipAI]   \(role): \(text)")
                }
            }
            print("[PipAI] ===================")
            #endif

            do {
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = bodyData

                // Bind the assertion (or fall back to proxy token) to the exact body bytes.
                let auth = await WorkerClient.authHeaders(for: bodyData)
                for (key, value) in auth {
                    request.setValue(value, forHTTPHeaderField: key)
                }

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run { lastError = "Bad response" }
                    conversationHistory.removeLast()
                    return nil
                }

                guard httpResponse.statusCode == 200 else {
                    // Error responses are plain JSON, not SSE — drain to surface Anthropic's message.
                    var errorData = Data()
                    for try await byte in bytes { errorData.append(byte) }
                    let responseText = String(data: errorData, encoding: .utf8) ?? "no body"
                    print("[PipAI] HTTP \(httpResponse.statusCode): \(responseText)")

                    if let errorJSON = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                       let error = errorJSON["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        await MainActor.run { lastError = message }
                    } else {
                        await MainActor.run { lastError = "Error \(httpResponse.statusCode)" }
                    }
                    conversationHistory.removeLast()
                    return nil
                }

                await MainActor.run { streamingText = "" }

                var assembled = ""
                var stopReason: String?
                var outputTokens = 0
                var cacheCreationTokens = 0
                var cacheReadTokens = 0

                // Tool-use accumulators keyed by content-block index. Anthropic streams
                // input_json_delta chunks for each tool's input; we concatenate then parse.
                var toolBlocks: [(index: Int, id: String, name: String, jsonString: String)] = []

                for try await line in bytes.lines {
                    guard line.hasPrefix("data:") else { continue }
                    let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                    guard !payload.isEmpty,
                          let eventData = payload.data(using: .utf8),
                          let event = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
                          let type = event["type"] as? String else { continue }

                    switch type {
                    case "message_start":
                        // Capture cache usage so we can verify caching actually hits in DEBUG.
                        if let message = event["message"] as? [String: Any],
                           let usage = message["usage"] as? [String: Any] {
                            cacheCreationTokens = usage["cache_creation_input_tokens"] as? Int ?? 0
                            cacheReadTokens = usage["cache_read_input_tokens"] as? Int ?? 0
                        }
                    case "content_block_start":
                        // Open a tool_use block — id/name come up front, input arrives via deltas.
                        if let index = event["index"] as? Int,
                           let block = event["content_block"] as? [String: Any],
                           block["type"] as? String == "tool_use",
                           let id = block["id"] as? String,
                           let name = block["name"] as? String {
                            toolBlocks.append((index: index, id: id, name: name, jsonString: ""))
                        }
                    case "content_block_delta":
                        if let delta = event["delta"] as? [String: Any] {
                            if let chunk = delta["text"] as? String {
                                // Normal text delta — live-stream to the bubble.
                                assembled += chunk
                                let snapshot = assembled
                                await MainActor.run { streamingText = snapshot }
                            } else if delta["type"] as? String == "input_json_delta",
                                      let partial = delta["partial_json"] as? String,
                                      let index = event["index"] as? Int,
                                      let pos = toolBlocks.firstIndex(where: { $0.index == index }) {
                                toolBlocks[pos].jsonString += partial
                            }
                        }
                    case "message_delta":
                        if let delta = event["delta"] as? [String: Any],
                           let reason = delta["stop_reason"] as? String {
                            stopReason = reason
                        }
                        if let usage = event["usage"] as? [String: Any],
                           let out = usage["output_tokens"] as? Int {
                            outputTokens = out
                        }
                    default:
                        break   // content_block_stop / ping / message_stop — nothing to do
                    }
                }

                await MainActor.run { streamingText = nil }

                #if DEBUG
                print("[PipAI] STREAM DONE hop \(hop) — text:\(assembled.count) tools:\(toolBlocks.count) stop:\(stopReason ?? "nil") out:\(outputTokens) cache_create:\(cacheCreationTokens) cache_read:\(cacheReadTokens)")
                #endif

                lastStopReason = stopReason

                // Refusal short-circuits even before tool execution.
                if stopReason == "refusal" {
                    conversationHistory.append(["role": "assistant", "content": refusalReply])
                    incrementDailyCount()
                    return refusalReply
                }

                // Tool call: execute, append assistant + tool_result turns, recurse.
                if stopReason == "tool_use" && !toolBlocks.isEmpty {
                    var assistantContent: [[String: Any]] = []
                    if !assembled.isEmpty {
                        assistantContent.append(["type": "text", "text": assembled])
                    }
                    for tb in toolBlocks {
                        var inputDict: [String: Any] = [:]
                        if !tb.jsonString.isEmpty,
                           let jsonData = tb.jsonString.data(using: .utf8),
                           let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            inputDict = parsed
                        }
                        assistantContent.append([
                            "type": "tool_use",
                            "id": tb.id,
                            "name": tb.name,
                            "input": inputDict
                        ])
                    }
                    modelMessages.append(["role": "assistant", "content": assistantContent])

                    var userContent: [[String: Any]] = []
                    for tb in toolBlocks {
                        // Show per-tool indicator in the chat bubble while the tool runs.
                        let indicator = toolInFlightMessage(name: tb.name)
                        await MainActor.run { streamingText = indicator }
                        let resultStr = executeCloudTool(name: tb.name)
                        #if DEBUG
                        print("[PipAI] TOOL \(tb.name) → \(resultStr.prefix(140))")
                        #endif
                        userContent.append([
                            "type": "tool_result",
                            "tool_use_id": tb.id,
                            "content": resultStr
                        ])
                    }
                    modelMessages.append(["role": "user", "content": userContent])

                    continue   // next hop
                }

                // Text response: done.
                let trimmed = (stopReason == "max_tokens")
                    ? trimToLastSentence(assembled)
                    : assembled

                guard !trimmed.isEmpty else {
                    await MainActor.run { lastError = "Could not read response" }
                    conversationHistory.removeLast()
                    return nil
                }

                finalText = trimmed
                break

            } catch {
                print("[PipAI] Error: \(error)")
                await MainActor.run {
                    lastError = error.localizedDescription
                    streamingText = nil
                }
                conversationHistory.removeLast()
                return nil
            }
        }

        guard let finalText else {
            // Exhausted hops without text. Rare — final hop has tools disabled,
            // so this only fires if the API returns empty content.
            print("[PipAI] Hop limit reached without text — stop:\(lastStopReason ?? "nil")")
            await MainActor.run { lastError = "Pip couldn't quite finish that thought" }
            conversationHistory.removeLast()
            return nil
        }

        conversationHistory.append(["role": "assistant", "content": finalText])
        incrementDailyCount()
        return finalText
    }

    // Trims a truncated reply (stop_reason == "max_tokens") back to its last
    // complete sentence so a kid never sees a half-finished word. If there's no
    // sentence terminator at all, appends "…" to signal it was cut short.
    private func trimToLastSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastEnd = trimmed.lastIndex(where: { ".!?".contains($0) }) {
            return String(trimmed[...lastEnd])
        }
        return trimmed.isEmpty ? trimmed : trimmed + "…"
    }

    // MARK: - Daily Question Counter
    //
    // Uses UserDefaults with a date string. When the date changes
    // (new day), the counter resets automatically.
    //
    // TEACHING MOMENT: This is the simplest rate limiter possible.
    // It's "client-side" — a determined hacker could bypass it.
    // For a kids' game, that's fine. If you needed bulletproof
    // rate limiting, you'd do it server-side (Cloudflare Worker).
    //

    private func resetCountIfNewDay() {
        let today = dateString(for: Date())
        let savedDate = UserDefaults.standard.string(forKey: questionsDateKey)

        if savedDate != today {
            // New day! Reset the counter
            UserDefaults.standard.set(0, forKey: questionsCountKey)
            UserDefaults.standard.set(today, forKey: questionsDateKey)
        }
    }

    private func incrementDailyCount() {
        resetCountIfNewDay()
        let current = UserDefaults.standard.integer(forKey: questionsCountKey)
        UserDefaults.standard.set(current + 1, forKey: questionsCountKey)

        // Update published state
        Task { @MainActor in
            if current + 1 >= dailyQuestionLimit {
                isRateLimited = true
            }
        }
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
