//
//  ElevenLabsVoiceService.swift
//  ChefAcademy
//
//  Premium voice service for Pip using ElevenLabs TTS API.
//  Sends text → receives streaming audio → plays through speakers.
//  Requires "Pip Plus" subscription ($3.99/month).
//
//  TEACHING MOMENT: Streaming Audio vs Download-Then-Play
//  ┌──────────────────────────────────────────────────────┐
//  │ Download-Then-Play:                                   │
//  │   [Send text]──wait 2s──[Get full MP3]──[Play]       │
//  │   User waits 2 seconds before hearing anything.       │
//  │                                                       │
//  │ Streaming:                                            │
//  │   [Send text]──[Audio chunks arrive]──[Play as they   │
//  │    come]──continuous playback, ~200ms to first sound  │
//  │                                                       │
//  │ We use streaming! Same technique as Spotify/Podcasts. │
//  └──────────────────────────────────────────────────────┘
//
//  COST: ~$0.30 per 1,000 characters (Scale plan ~$0.08/1K)
//  Average Pip response: ~150 chars = ~$0.01-0.05 per utterance
//

import Foundation
import AVFoundation
import Combine

// MARK: - ElevenLabs Voice Service

class ElevenLabsVoiceService: NSObject, ObservableObject, AVAudioPlayerDelegate {

    static let shared = ElevenLabsVoiceService()

    // MARK: - Published State

    @Published var isSpeaking = false
    @Published var isLoading = false
    @Published var lastError: String?

    // MARK: - Configuration
    //
    // TEACHING MOMENT: The voice_id comes from ElevenLabs dashboard.
    // You create a custom voice (clone or design), and it gets a unique ID.
    // For Pip, we'd create a friendly, slightly high-pitched character voice.
    // The model_id controls quality vs speed:
    //   - "eleven_turbo_v2_5" = fastest, good for real-time chat
    //   - "eleven_multilingual_v2" = best quality, slower
    //

    /// ElevenLabs voice ID for Pip — created in Voice Design with hedgehog chef personality
    var pipVoiceID: String = "Vz4lAV88EflFsYHyDCAY"

    /// Model to use — turbo for real-time chat, multilingual for pre-generation
    var modelID: String = "eleven_turbo_v2_5"

    /// Voice settings — controls how Pip sounds
    /// stability: 0.0 (variable/expressive) to 1.0 (consistent/monotone)
    /// similarity_boost: 0.0 (creative) to 1.0 (stick to original voice)
    var stability: Double = 0.65
    var similarityBoost: Double = 0.75

    // MARK: - Private State

    private var audioPlayer: AVAudioPlayer?
    private var audioCache: [String: Data] = [:]
    private let cacheLimit = 50  // Max cached phrases

    // MARK: - Init

    override init() {
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.duckOthers]
        )
    }

    // MARK: - Speak (Streaming)
    //
    // TEACHING MOMENT: We download the full audio first, then play it.
    // True chunked streaming (playing while downloading) requires
    // AVAudioEngine with an audio queue, which is much more complex.
    // For Pip's short 2-3 sentence responses, the download is fast
    // enough (~200-500ms) that the UX feels nearly instant.
    //
    // For a future optimization, we could use AVAudioEngine with a
    // ring buffer to start playback after the first chunk arrives.
    //

    func speak(_ text: String) async {
        guard !text.isEmpty else { return }
        guard await WorkerClient.isReady() else {
            await MainActor.run { lastError = "Voice needs a real device (App Attest not available here)" }
            return
        }

        // Check cache first — saves API calls for repeated phrases!
        if let cached = audioCache[text] {
            await playAudio(cached)
            return
        }

        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            let audioData = try await fetchSpeech(text: text)

            // Cache for reuse (cooking instructions repeat a lot!)
            cacheAudio(text: text, data: audioData)

            await playAudio(audioData)

        } catch {
            print("[ElevenLabs] Error: \(error)")
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Synchronous speak wrapper for compatibility with existing PipVoice interface
    func speakSync(_ text: String) {
        Task { await speak(text) }
    }

    // MARK: - Stop

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        Task { @MainActor in
            isSpeaking = false
            isLoading = false
        }
    }

    // MARK: - API Call
    //
    // TEACHING MOMENT: We don't talk to ElevenLabs directly anymore — we
    // hit our Cloudflare Worker, which holds the real `xi-api-key` as a
    // server-side secret and forwards the request. The app only sends the
    // shared X-Proxy-Token header, so even a jailbroken device can't
    // exfiltrate Marina's ElevenLabs account credentials from the binary.
    //

    private func fetchSpeech(text: String) async throws -> Data {
        var request = URLRequest(url: WorkerClient.ttsURL(voiceID: pipVoiceID))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": modelID,
            "voice_settings": [
                "stability": stability,
                "similarity_boost": similarityBoost
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData

        // Bind the assertion to the exact body bytes we're about to send.
        let auth = await WorkerClient.authHeaders(for: bodyData)
        for (key, value) in auth {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.badResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJSON["detail"] as? [String: Any],
               let message = detail["message"] as? String {
                throw ElevenLabsError.apiError(message)
            }
            throw ElevenLabsError.httpError(httpResponse.statusCode)
        }

        return data
    }

    // MARK: - Audio Playback

    private func playAudio(_ data: Data) async {
        await MainActor.run { isLoading = false }

        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            self.audioPlayer = player

            await MainActor.run { isSpeaking = true }
            player.play()

        } catch {
            print("[ElevenLabs] Playback error: \(error)")
            await MainActor.run {
                self.lastError = "Couldn't play audio"
                self.isSpeaking = false
            }
        }
    }

    // MARK: - Caching
    //
    // TEACHING MOMENT: Caching is CRITICAL for controlling API costs.
    // Cooking instructions like "Stir the pan!" get spoken many times.
    // Without caching, each repetition costs ~$0.01. With caching,
    // only the first time costs money. Over thousands of users, this
    // saves hundreds of dollars per month.
    //
    // We use a simple in-memory dictionary with a size limit.
    // For production, you'd use disk caching (FileManager) so cached
    // audio survives app restarts.
    //

    private func cacheAudio(text: String, data: Data) {
        // Evict oldest if at limit
        if audioCache.count >= cacheLimit {
            audioCache.removeValue(forKey: audioCache.keys.first ?? "")
        }
        audioCache[text] = data
    }

    /// Pre-cache common phrases to reduce API calls during gameplay
    func precacheCommonPhrases() {
        let phrases = [
            "Great job!",
            "Yummy! Let's see what we made!",
            "Ooh, that looks delicious!",
            "Time to cook!",
            "Let's wash our veggies!",
            "Stir it up!",
            "Almost done!",
            "You did it! Amazing!"
        ]

        Task {
            for phrase in phrases {
                guard audioCache[phrase] == nil else { continue }
                do {
                    let data = try await fetchSpeech(text: phrase)
                    cacheAudio(text: phrase, data: data)
                    // Small delay to avoid rate limiting
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    print("[ElevenLabs] Precache failed for '\(phrase)': \(error)")
                }
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor in
            self.isSpeaking = false
            self.lastError = "Audio decode error"
        }
    }
}

// MARK: - Errors

enum ElevenLabsError: LocalizedError {
    case badResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Bad response from voice server"
        case .httpError(let code): return "Voice server error (\(code))"
        case .apiError(let message): return message
        }
    }
}
