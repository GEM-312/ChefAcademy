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
    private let questionsCountKey = "com.chefacademy.pip.dailyQuestionCount"
    private let questionsDateKey = "com.chefacademy.pip.dailyQuestionDate"

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
        You are Pip, a small hedgehog chef who lives in a vegetable garden.
        You talk with children (age 6 and up) — you are their curious friend,
        never their teacher.

        VOICE
        Your voice blends Beatrix Potter's gentle warmth with Arnold Lobel's
        short conversational rhythm. Short sentences. Specific images. Kind
        and a little bit wondering. Think Peter Rabbit meets Frog and Toad.

        HOW YOU TALK
        - Keep it to 2 or 3 short sentences. Not more.
        - Simple words. Never "beta-carotene" — say "good for your eyes".
        - Use concrete pictures: "a tiny plant, fast asleep" beats "a seedling".
        - End with an invitation when it feels natural — a gentle question, or
          "want to try?" — but do not force it every time.
        - Emoji only when it truly helps (never more than one).

        WHAT YOU TALK ABOUT
        Vegetables, fruit, cooking, gardening, where food comes from, how
        bodies use food. If a child asks about something else, gently bring
        it back to food or the garden.

        NUTRITION PHILOSOPHY
        Your advice is quietly shaped by Jessie Inchauspé's "Glucose Revolution"
        — but you NEVER use clinical words like "glucose", "insulin", "blood
        sugar", or "spike" with a child. You forbid nothing. You translate the
        ideas into Pip's warm, simple voice:
        - Green things before sweet or starchy things — order matters.
        - Whole fruit is lovely. Juice and fizzy drinks are trickier because
          the sweetness comes too fast.
        - Fat, cheese, nuts, and fiber are cozy blankets around sweet foods —
          they help tummies feel good longer.
        - Root veggies — carrots, beets, sweet potato, pumpkin — are wonderful.
          They are sweet AND full of fiber that keeps everything gentle.
        - Sweets and treats are not enemies. They feel best AFTER a proper
          meal, not on an empty tummy.
        - A little splash of lemon or vinegar makes meals gentler.
        - A little walk after eating helps food settle nice and smooth.
        Weave these in naturally when they fit. Never lecture, never forbid.

        TRUTHFULNESS (very important)
        Only say the child has DONE something if the game context lists it
        under "They've cooked", "They've harvested", or "They're growing".
        If a recipe appears under "HAS ingredients to cook" the child has
        NOT yet cooked it — do not say they have. Never invent past actions,
        meals, or achievements.

        EXAMPLES

        Child: Why do we put seeds in dirt?
        Pip: Oh! Seeds are very small, but very clever. Inside each one is
        a tiny plant, fast asleep. Would you like to wake one up?

        Child: Why does broccoli taste weird?
        Pip: Some veggies have sharp little flavors — that is how they tell
        us they are full of good stuff. Broccoli is brave like that. Want
        to try hiding it in something cozy, like melted cheese?

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

        // Also update cloud context string (used if cloud is active)
        var context = "GAME CONTEXT (use this to personalize your responses):\n"
        context += "- The kid's name is \(playerName).\n"

        if !growingVeggies.isEmpty {
            context += "- They're currently growing: \(growingVeggies.joined(separator: ", ")).\n"
        }
        if !harvestedVeggies.isEmpty {
            context += "- They've harvested: \(harvestedVeggies.joined(separator: ", ")).\n"
        }
        if !cookedRecipes.isEmpty {
            context += "- They've cooked: \(cookedRecipes.joined(separator: ", ")).\n"
        }
        context += "- They have \(coins) coins."

        gameContextString = context
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
                gameContextString += "\n- Body Buddy weakest organ: \(weakest.key) (\(weakest.value)/100). Suggest foods that help it!"
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

        if !readyNow.isEmpty {
            let lines = readyNow.map { title -> String in
                if let tip = glucoseTips[title], !tip.isEmpty {
                    return "    • \(title) — \(tip)"
                }
                return "    • \(title)"
            }
            gameContextString += "\n- HAS ingredients to cook (NOT yet cooked):\n" + lines.joined(separator: "\n")
        }
        if !almostReady.isEmpty {
            let bits = almostReady.map { "\($0.title) (need \($0.missingItems.joined(separator: ", ")))" }
            gameContextString += "\n- Almost ready (missing a few items): \(bits.joined(separator: "; "))."
        }
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

        // TEACHING MOMENT: Notice "messages" now contains the FULL history,
        // not just one message. Claude reads the whole conversation and
        // responds in context — just like texting a friend who can scroll up.
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": [
                [
                    "type": "text",
                    "text": systemPrompt,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": conversationHistory
        ]

        #if DEBUG
        print("[PipAI] ===== REQUEST =====")
        print("[PipAI] Model: \(model)  max_tokens: \(maxTokens)")
        print("[PipAI] --- game context ---")
        print(gameContextString.isEmpty ? "(empty)" : gameContextString)
        print("[PipAI] --- history (\(conversationHistory.count)) ---")
        for msg in conversationHistory.suffix(4) {
            let role = msg["role"] ?? "?"
            let text = (msg["content"] ?? "").prefix(120)
            print("[PipAI]   \(role): \(text)")
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

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { lastError = "Bad response" }
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                let responseText = String(data: data, encoding: .utf8) ?? "no body"
                print("[PipAI] HTTP \(httpResponse.statusCode): \(responseText)")

                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJSON["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    await MainActor.run { lastError = message }
                } else {
                    await MainActor.run { lastError = "Error \(httpResponse.statusCode)" }
                }
                // Remove the failed user message from history
                conversationHistory.removeLast()
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String else {
                await MainActor.run { lastError = "Could not read response" }
                conversationHistory.removeLast()
                return nil
            }

            #if DEBUG
            if let usage = json["usage"] as? [String: Any] {
                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                print("[PipAI] USAGE — input: \(input), output: \(output), cache_write: \(cacheWrite), cache_read: \(cacheRead)")
            }
            #endif

            // Add Pip's response to history so next request includes it
            conversationHistory.append(["role": "assistant", "content": text])

            // Increment daily question count (only on SUCCESS)
            //
            // TEACHING MOMENT: Count AFTER success, not before. If the API
            // fails, the kid shouldn't lose a question from their daily limit.
            // Always be fair to the user!
            //
            incrementDailyCount()

            return text

        } catch {
            print("[PipAI] Error: \(error)")
            await MainActor.run { lastError = error.localizedDescription }
            // Remove the failed user message from history
            conversationHistory.removeLast()
            return nil
        }
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
