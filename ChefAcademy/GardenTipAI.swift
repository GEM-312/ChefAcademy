//
//  GardenTipAI.swift
//  ChefAcademy
//
//  Pip's garden tip for Pip Plus players: Claude Haiku words the tip,
//  VeggieJourney supplies the facts (Oct 23 2026). Free players, visitors
//  and offline players get the built-in tip lines instead.
//
//  TEACHING MOMENT: Context or tool?
//  A tool earns its place when the MODEL decides what to look up (chat:
//  "why is my carrot sad?" → fetch the carrot's journey). This tip always
//  needs the whole garden, so a tool would only add a second API call per
//  tap to fetch data we already have. We send the journey and the
//  code-picked focus in the one message instead: one call, about a second.
//
//  The child's name is never sent: GardenView adds it in code. Less data
//  leaves the device, and a name can't smuggle instructions into the prompt.
//

import Foundation

enum GardenTipAI {
    /// Claude's smallest, fastest model: a one-sentence tip needs no more
    static let model = "claude-haiku-5-5"

    /// Longer than this is rejected (the prompt asks for 10; Haiku runs a little long)
    private static let maxWords = 16

    private static let systemPrompt = """
    You are Pip, a cheerful hedgehog gardener talking to a 6-year-old in a cooking game.

    <task>
    Write ONE short sentence (10 words max) telling the kid what to do next in the garden.
    Talk about the step in <focus>. If there is no <focus>, share a happy fact about a veggie in <garden_facts>.
    Start with the veggie or the action, never with a name or a greeting.
    </task>

    <truthfulness>
    Use ONLY what <garden_facts> says. Never invent veggies, never mention spots by number.
    Garden tools: the fork loosens soil, the shovel plants and digs up, the watering can waters; weeds and bugs are done by hand.
    </truthfulness>

    <safety>
    Always gentle and happy. Plants never die, hurt or suffer; bugs are just visiting.
    Everything happens in the game: never suggest real tools, real digging, eating from a garden, or anything outside the game.
    No markdown. One emoji max.
    </safety>
    """

    /// One sentence for Pip's bubble, or nil (no network, App Attest not
    /// ready, refusal, timeout, or the guardrail tripped) so the caller uses a
    /// built-in tip.
    static func tip(journeys: [VeggieJourney], focus: String?, previous: String?) async -> String? {
        guard await WorkerClient.isReady() else { return nil }

        let facts = journeys.isEmpty
            ? "No veggies yet: no seeds and nothing planted."
            : journeys.map(\.toolLine).joined(separator: "\n")
        var message = "<garden_facts>\n\(facts)\n</garden_facts>"
        if let focus { message += "\n<focus>\(focus)</focus>" }
        if let previous { message += "\n<previous_tip>\(previous)</previous_tip>\nSay something different from <previous_tip>." }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 200,
            // A one-sentence tip needs no reasoning; also keeps it fast
            "thinking": ["type": "disabled"],
            "system": systemPrompt,
            "messages": [["role": "user", "content": message]],
        ]

        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            var request = URLRequest(url: WorkerClient.chatURL)
            request.httpMethod = "POST"
            // A slow network falls back to a built-in tip instead of a silent Pip
            request.timeoutInterval = 5
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
            for (key, value) in await WorkerClient.authHeaders(for: bodyData) {
                request.setValue(value, forHTTPHeaderField: key)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                #if DEBUG
                print("[GardenTipAI] HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")")
                #endif
                return nil
            }
            // Refusal or a cut-off sentence: use a built-in tip instead
            guard json["stop_reason"] as? String == "end_turn",
                  let content = json["content"] as? [[String: Any]] else { return nil }
            let text = content
                .filter { $0["type"] as? String == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let ok = passesGuardrail(text, journeys: journeys, previous: previous)
            #if DEBUG
            print("[GardenTipAI] \(ok ? "ok" : "REJECTED"): \(text)")
            #endif
            return ok ? text : nil
        } catch {
            #if DEBUG
            print(Task.isCancelled ? "[GardenTipAI] cancelled" : "[GardenTipAI] Error: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Guardrail

    /// Cheap checks on the model's sentence: the right shape for a kid's
    /// bubble, and no veggie the kid hasn't touched. It can't check that the
    /// action matches the focus (e.g. "plant" for a veggie that's ready);
    /// the code-picked focus in the prompt is what prevents that.
    static func passesGuardrail(_ text: String, journeys: [VeggieJourney], previous: String?) -> Bool {
        guard !text.isEmpty, text != previous,
              text.split(whereSeparator: \.isWhitespace).count <= maxWords,
              text.range(of: #"\bspots?\s*#?\d"#, options: [.regularExpression, .caseInsensitive]) == nil,  // "spot 3"
              !text.contains("*"), !text.contains("#"),   // markdown
              text.filter({ isEmoji($0) }).count <= 1 else { return false }

        let known = Set(journeys.map(\.veggie))
        return !VegetableType.allCases.contains { veg in
            !known.contains(veg) && mentions(veg, in: text)
        }
    }

    /// Whole-word match, plurals included: "strawberries" matches strawberry,
    /// "beetle" does not match beet, "corner" does not match corn.
    private static func mentions(_ veg: VegetableType, in text: String) -> Bool {
        let name = NSRegularExpression.escapedPattern(for: veg.displayName.lowercased())
        let word = name.hasSuffix("y")
            ? "\(name.dropLast())(y|ies)"
            : "\(name)(s|es)?"
        return text.lowercased().range(of: "\\b\(word)\\b", options: .regularExpression) != nil
    }

    private static func isEmoji(_ c: Character) -> Bool {
        c.unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }
}
