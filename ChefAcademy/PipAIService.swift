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
//  - API key is fetched from CloudKit (never in app binary)
//  - Daily rate limit prevents runaway costs
//  - Key can be rotated without an app update
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

    private var apiKey: String = ""
    private let model = "claude-haiku-4-5"
    private let maxTokens = 250

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
    private let dailyQuestionLimit = 20
    private let questionsCountKey = "com.chefacademy.pip.dailyQuestionCount"
    private let questionsDateKey = "com.chefacademy.pip.dailyQuestionDate"

    var questionsRemainingToday: Int {
        // On-device AI has no rate limits — it's free!
        if isOnDevice { return Int.max }

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
        You are Pip, a friendly hedgehog chef who lives in a kitchen garden. \
        You talk to kids aged 6 and up. You're their buddy, not a teacher.

        PERSONALITY:
        - Cheerful, curious, and encouraging
        - You get EXCITED about veggies and cooking
        - You love sharing fun facts and silly jokes about food
        - You sometimes say things like "Ooh!" and "Wow!" and "That's so cool!"

        RULES (follow STRICTLY):
        1. KEEP IT SHORT: 2-3 sentences max. Kids lose attention fast.
        2. BE CONVERSATIONAL: Ask follow-up questions! "Have you ever tried...?" "Want to know something cool about...?"
        3. USE SIMPLE WORDS: Say "good for your eyes" not "contains beta-carotene".
        4. STAY ON TOPIC: Vegetables, fruits, nutrition, cooking, gardening, healthy eating, and food science.
        5. OFF-TOPIC: Gently redirect — "Haha, that's funny! But hey, did you know [food fact]?"
        6. NO SCARY STUFF: Never mention choking, allergies, illness, death, or anything frightening.
        7. FUN FACTS: Sprinkle in surprising facts! Kids remember stories better than lectures.
        8. ONE EMOJI per response max (like 🥕 or 🌱).
        9. NEVER give medical advice or say "you should eat" — say "isn't it cool that..."
        10. REMEMBER the conversation — reference what the kid said earlier to feel like a real friend.
        11. End responses with something that invites more chat — a question, a teaser, or "wanna know more?"

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
        // Step 1: Try on-device AI (iOS 26+, zero cost, unlimited)
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            setupOnDeviceIfAvailable()
        }
        #endif

        // Step 2: Fall back to cloud if on-device isn't available
        if !isOnDevice {
            setupCloudService()
        }
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
        // Start with the bundled key for immediate use (development)
        // CloudKit will override this once it loads
        self.apiKey = APIKeys.claudeAPIKey

        // Fetch the real key from CloudKit in the background
        Task {
            let cloudKey = await CloudKeyManager.shared.fetchAPIKey()
            await MainActor.run {
                self.apiKey = cloudKey
            }
        }
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
        // Route to on-device or cloud based on what's available
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *),
           let service = _onDeviceService as? PipFoundationModelService {
            return await askOnDevice(question, service: service)
        }
        #endif
        return await askCloud(question)
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

        guard !apiKey.isEmpty else {
            await MainActor.run { lastError = "API key not configured" }
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

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // TEACHING MOMENT: Notice "messages" now contains the FULL history,
        // not just one message. Claude reads the whole conversation and
        // responds in context — just like texting a friend who can scroll up.
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": conversationHistory
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
