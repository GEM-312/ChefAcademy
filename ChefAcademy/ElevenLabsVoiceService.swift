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
import CryptoKit

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

    /// The line being fetched or played. A new line cancels it ("newest wins"),
    /// so lines can't pile up into parallel requests that cut each other off.
    private var speakTask: Task<Void, Never>?

    /// On-device voice cache: Library/Caches/pip_voice/<sha256>.mp3
    private let cacheDirectory: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("pip_voice", isDirectory: true)
    private let cacheByteLimit = 30 * 1024 * 1024  // ~600 short lines

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

        // Check the on-device cache first. A saved line needs no network,
        // no App Attest, no Worker call (no KV ops) and no ElevenLabs
        // characters, so it plays offline and on the simulator too.
        if let cached = cachedAudio(for: text) {
            #if DEBUG
            print("[ElevenLabs] cache hit: \(text.prefix(40))")
            #endif
            guard !Task.isCancelled else { return }
            await playAudio(cached)
            return
        }

        guard await WorkerClient.isReady() else {
            await MainActor.run { lastError = "Voice needs a real device (App Attest not available here)" }
            return
        }

        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            let audioData = try await fetchSpeech(text: text)

            // Save for reuse (cooking instructions repeat a lot!)
            cacheAudio(text: text, data: audioData)
            #if DEBUG
            print("[ElevenLabs] fetched + saved: \(text.prefix(40))")
            #endif

            // A newer line replaced this one while it downloaded: keep the
            // saved audio for next time, but don't play over the newer line
            guard !Task.isCancelled else { return }
            await playAudio(audioData)

        } catch {
            if Task.isCancelled {
                // Replaced by a newer line, not a real failure
                await MainActor.run { self.isLoading = false }
                return
            }
            print("[ElevenLabs] Error: \(error)")
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Synchronous speak wrapper for compatibility with existing PipVoice interface.
    /// Newest wins: cancels the line still downloading and stops the one playing.
    func speakSync(_ text: String) {
        stop()
        speakTask = Task { await speak(text) }
    }

    // MARK: - Stop

    func stop() {
        speakTask?.cancel()
        speakTask = nil
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
            self.audioPlayer?.stop()
            self.audioPlayer = player
            #if DEBUG
            print("[ElevenLabs] playing with audio category: \(AVAudioSession.sharedInstance().category.rawValue)")
            #endif

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
    // The cache lives on disk (Library/Caches), so a line is fetched once
    // per device, not once per launch. The file name is a SHA-256 of the
    // voice + model + settings + text: change Pip's voice and every line
    // is fetched fresh instead of playing the old voice. iOS may empty
    // Caches when storage is low; then lines are simply fetched again.
    //

    private func cacheURL(for text: String) -> URL {
        let key = "\(pipVoiceID)|\(modelID)|\(stability)|\(similarityBoost)|\(text)"
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(name).mp3")
    }

    private func cachedAudio(for text: String) -> Data? {
        let url = cacheURL(for: text)
        guard let data = try? Data(contentsOf: url) else { return nil }
        // Mark as recently played, so trimming deletes lines nobody hears anymore
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    private func cacheAudio(text: String, data: Data) {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try data.write(to: cacheURL(for: text), options: .atomic)
        } catch {
            print("[ElevenLabs] Couldn't save voice cache: \(error)")
            return
        }
        trimCache()
    }

    /// Delete the least recently played lines once the folder passes `cacheByteLimit`.
    private func trimCache() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: keys) else { return }

        let entries = files.compactMap { url -> (url: URL, size: Int, date: Date)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > cacheByteLimit else { return }

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            guard total > cacheByteLimit else { break }
            do {
                try FileManager.default.removeItem(at: entry.url)
                total -= entry.size
            } catch {
                print("[ElevenLabs] Couldn't trim voice cache: \(error)")
            }
        }
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
                guard cachedAudio(for: phrase) == nil else { continue }
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
