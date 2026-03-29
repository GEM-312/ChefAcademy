//
//  PipVoice.swift
//  ChefAcademy
//
//  Pip reads instructions aloud — supports TWO voice backends:
//    1. Apple TTS (free) — AVSpeechSynthesizer, default/enhanced/premium
//    2. ElevenLabs (Pip Plus subscription) — custom Pip character voice
//
//  TEACHING MOMENT: Strategy Pattern again! Same speak() call, different
//  backends. The rest of the app doesn't care which voice engine is active.
//  PipDialogView, CookingSessionView, SeedInfoView all just call
//  PipVoice.shared.speak("text") — the routing happens here.
//

import AVFoundation
import SwiftUI
import Combine

// MARK: - Voice Mode
//
// TEACHING MOMENT: This enum represents which voice backend is active.
// It's persisted to UserDefaults so the choice survives app restarts.
// The .elevenLabs case requires an active subscription check.
//

enum PipVoiceMode: String, CaseIterable {
    case appleTTS = "apple"
    case elevenLabs = "elevenlabs"

    var displayName: String {
        switch self {
        case .appleTTS: return "Standard Voice"
        case .elevenLabs: return "Pip's Special Voice"
        }
    }

    var description: String {
        switch self {
        case .appleTTS: return "Built-in Apple voice (free)"
        case .elevenLabs: return "Custom Pip character voice (Pip Plus)"
        }
    }
}

// MARK: - PipVoice Service

class PipVoice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = PipVoice()

    @Published var isSpeaking: Bool = false

    /// User preference — kids or parents can mute Pip's voice
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "com.chefacademy.pipVoiceEnabled")
            if !isEnabled { stop() }
        }
    }

    /// Which voice backend to use
    @Published var voiceMode: PipVoiceMode {
        didSet {
            UserDefaults.standard.set(voiceMode.rawValue, forKey: "com.chefacademy.pipVoiceMode")
        }
    }

    /// The user's selected Apple TTS voice identifier (saved per choice)
    @Published var selectedAppleVoiceID: String? {
        didSet {
            UserDefaults.standard.set(selectedAppleVoiceID, forKey: "com.chefacademy.pipAppleVoiceID")
            // Reset cached voice so findBestVoice() picks up the new selection
            bestVoice = nil
            voiceSearchDone = false
        }
    }

    /// Whether the user has an active Pip Plus subscription
    /// TODO: Wire this to StoreKit 2 subscription status
    @Published var hasSubscription: Bool = false

    // MARK: - Private State

    private let synthesizer = AVSpeechSynthesizer()
    private let elevenLabs = ElevenLabsVoiceService.shared
    private var cancellables = Set<AnyCancellable>()

    /// Best available Apple voice — cached after first lookup
    private var bestVoice: AVSpeechSynthesisVoice?
    private var voiceSearchDone = false

    // MARK: - Init

    override init() {
        // Load saved preferences
        self.isEnabled = UserDefaults.standard.object(forKey: "com.chefacademy.pipVoiceEnabled") as? Bool ?? true

        let savedMode = UserDefaults.standard.string(forKey: "com.chefacademy.pipVoiceMode") ?? "apple"
        self.voiceMode = PipVoiceMode(rawValue: savedMode) ?? .appleTTS

        self.selectedAppleVoiceID = UserDefaults.standard.string(forKey: "com.chefacademy.pipAppleVoiceID")

        super.init()
        synthesizer.delegate = self

        // Set up audio session so speech works alongside other audio
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])

        // Forward ElevenLabs speaking state to our published property
        elevenLabs.$isSpeaking
            .receive(on: RunLoop.main)
            .sink { [weak self] speaking in
                if self?.voiceMode == .elevenLabs {
                    self?.isSpeaking = speaking
                }
            }
            .store(in: &cancellables)

        // Listen for new voices being downloaded in Settings
        //
        // TEACHING MOMENT: When a user downloads an enhanced/premium voice
        // in Settings → Accessibility → Spoken Content → Voices, iOS posts
        // this notification. We can react immediately — re-scan available
        // voices and switch to the better one if appropriate.
        //
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voicesDidChange),
            name: AVSpeechSynthesizer.availableVoicesDidChangeNotification,
            object: nil
        )
    }

    @objc private func voicesDidChange() {
        // Re-scan voices when user downloads new ones from Settings
        bestVoice = nil
        voiceSearchDone = false
        print("[PipVoice] Available voices changed — rescanning")
    }

    // MARK: - Speak (Routes to correct backend)
    //
    // TEACHING MOMENT: This is the single entry point for ALL Pip speech.
    // Every view in the app calls PipVoice.shared.speak("text").
    // The routing logic here decides whether to use Apple TTS or ElevenLabs.
    // If ElevenLabs fails (no internet, API error), we fall back to Apple.
    //

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }

        // Route based on voice mode
        if voiceMode == .elevenLabs && hasSubscription {
            speakWithElevenLabs(text)
        } else {
            speakWithAppleTTS(text)
        }
    }

    // MARK: - Apple TTS Path

    private func speakWithAppleTTS(_ text: String) {
        // Stop current speech before starting new
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)

        // Kid-friendly voice settings
        utterance.rate = 0.48          // Slightly slower than default (0.5)
        utterance.pitchMultiplier = 1.15 // Slightly higher — cute hedgehog voice
        utterance.volume = 0.9
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        // Use the best natural voice available on this device
        utterance.voice = findBestVoice()

        synthesizer.speak(utterance)
    }

    // MARK: - ElevenLabs Path

    private func speakWithElevenLabs(_ text: String) {
        // Stop any current Apple TTS
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        elevenLabs.speakSync(text)
    }

    // MARK: - Find Best Apple Voice
    //
    // TEACHING MOMENT: Apple voices come in 3 quality tiers:
    //   .default (~5 MB, always on device, robotic)
    //   .enhanced (~150 MB, user must download, much better)
    //   .premium (~400 MB, user must download, nearly human)
    //
    // We check if the user picked a specific voice first.
    // Otherwise, we auto-select the best available quality.
    //

    private func findBestVoice() -> AVSpeechSynthesisVoice? {
        if voiceSearchDone { return bestVoice }
        voiceSearchDone = true

        // User's specific selection takes priority
        if let selectedID = selectedAppleVoiceID,
           let voice = AVSpeechSynthesisVoice(identifier: selectedID) {
            bestVoice = voice
            print("[PipVoice] Using user-selected voice: \(voice.name)")
            return voice
        }

        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let englishVoices = allVoices.filter { $0.language.hasPrefix("en") }

        // Prefer Siri voices ("Voice 1", "Voice 3" are male, best quality)
        let siriVoices = englishVoices.filter { $0.name.hasPrefix("Voice") }
        if let voice = siriVoices.first(where: { $0.name == "Voice 1" })
            ?? siriVoices.first(where: { $0.name == "Voice 3" })
            ?? siriVoices.first {
            bestVoice = voice
            print("[PipVoice] Using Siri voice: \(voice.name)")
            return voice
        }

        // Fallback to any premium/enhanced
        if let voice = englishVoices.first(where: { $0.quality == .premium })
            ?? englishVoices.first(where: { $0.quality == .enhanced }) {
            bestVoice = voice
            print("[PipVoice] Using \(voice.name)")
            return voice
        }

        // Last resort
        bestVoice = AVSpeechSynthesisVoice(language: "en-US")
        print("[PipVoice] Using default voice")
        return bestVoice
    }

    // MARK: - Voice Quality Detection
    //
    // Helpers for VoicePickerView to know what's available
    //

    /// Returns the best quality tier available on this device
    var bestAvailableQuality: AVSpeechSynthesisVoiceQuality {
        let english = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }

        if english.contains(where: { $0.quality == .premium }) { return .premium }
        if english.contains(where: { $0.quality == .enhanced }) { return .enhanced }
        return .default
    }

    /// True if only default (robotic) voices are available
    var onlyDefaultVoicesAvailable: Bool {
        bestAvailableQuality == .default
    }

    /// All English US voices — logged so we can see what iOS 26 actually provides.
    var availableEnglishVoices: [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
        // Log EVERY voice so we know what to filter
        for v in all {
            print("[PipVoice] VOICE: '\(v.name)' lang=\(v.language) quality=\(v.quality.rawValue) id=\(v.identifier)")
        }
        return all
    }

    // MARK: - Stop / Pause / Resume

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        elevenLabs.stop()
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }

    // MARK: - Preview Voice (for VoicePickerView)

    /// Preview a specific Apple voice with Pip's personality settings
    func previewAppleVoice(_ voice: AVSpeechSynthesisVoice) {
        stop()
        let utterance = AVSpeechUtterance(string: "Hi! I'm Pip, your kitchen garden buddy!")
        utterance.voice = voice
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.15
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }

    /// Preview the ElevenLabs Pip voice
    func previewElevenLabsVoice() {
        stop()
        elevenLabs.speakSync("Hi! I'm Pip, your kitchen garden buddy!")
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

// MARK: - Speaker Button (Reusable View)

/// Tap to hear Pip read text aloud. Shows speaker icon with animation while speaking.
struct SpeakerButton: View {
    let text: String
    var size: CGFloat = 24

    @ObservedObject private var voice = PipVoice.shared

    var body: some View {
        Button(action: {
            if voice.isSpeaking {
                voice.stop()
            } else {
                voice.speak(text)
            }
        }) {
            Image(systemName: voice.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                .font(.system(size: size))
                .foregroundColor(Color.AppTheme.sage)
                .symbolEffect(.pulse, isActive: voice.isSpeaking)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.isSpeaking ? "Stop reading" : "Read aloud")
    }
}

// MARK: - Voice Toggle (Settings)

/// Toggle for parents to enable/disable Pip's voice
struct VoiceToggleView: View {
    @ObservedObject private var voice = PipVoice.shared

    var body: some View {
        Toggle(isOn: $voice.isEnabled) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(Color.AppTheme.sage)
                Text("Pip reads aloud")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
        }
        .tint(Color.AppTheme.sage)
    }
}

#Preview("Speaker Button") {
    VStack(spacing: 20) {
        HStack {
            Text("Carrots are full of Vitamin A!")
                .font(.AppTheme.body)
            SpeakerButton(text: "Carrots are full of Vitamin A!")
        }
        .padding()

        VoiceToggleView()
            .padding()
    }
}
