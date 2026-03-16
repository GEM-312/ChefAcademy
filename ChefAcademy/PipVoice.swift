//
//  PipVoice.swift
//  ChefAcademy
//
//  Pip reads instructions aloud using AVSpeechSynthesizer.
//  Kid-friendly voice: slightly higher pitch, slower rate.
//  Singleton — call PipVoice.shared.speak("Hello!") from anywhere.
//

import AVFoundation
import SwiftUI
import Combine

// MARK: - PipVoice Service

class PipVoice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = PipVoice()

    @Published var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    /// User preference — kids or parents can mute Pip's voice
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "com.chefacademy.pipVoiceEnabled")
            if !isEnabled { stop() }
        }
    }

    // MARK: - Init

    override init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "com.chefacademy.pipVoiceEnabled") as? Bool ?? true
        super.init()
        synthesizer.delegate = self

        // Set up audio session so speech works alongside other audio
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
    }

    // MARK: - Public API

    /// The best available voice — cached after first lookup
    private var bestVoice: AVSpeechSynthesisVoice?
    private var voiceSearchDone = false

    /// Speak text in Pip's voice. Stops any current speech first.
    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }

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

    /// Find the most natural-sounding voice available.
    /// Priority: Premium > Enhanced > Default.
    /// Samantha (premium) and Ava (premium) are the most natural on iOS.
    private func findBestVoice() -> AVSpeechSynthesisVoice? {
        if voiceSearchDone { return bestVoice }
        voiceSearchDone = true

        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let englishVoices = allVoices.filter { $0.language.hasPrefix("en") }

        // Preferred voices in order (most natural first)
        // These are Apple's premium/enhanced voices that sound human-like
        let preferred = ["Samantha", "Ava", "Zoe", "Nicky", "Fiona"]

        // Try premium quality first (.premium has the best quality)
        for name in preferred {
            if let voice = englishVoices.first(where: {
                $0.name.contains(name) && $0.quality == .premium
            }) {
                bestVoice = voice
                print("[PipVoice] Using premium voice: \(voice.name)")
                return voice
            }
        }

        // Try enhanced quality
        for name in preferred {
            if let voice = englishVoices.first(where: {
                $0.name.contains(name) && $0.quality == .enhanced
            }) {
                bestVoice = voice
                print("[PipVoice] Using enhanced voice: \(voice.name)")
                return voice
            }
        }

        // Any enhanced English voice
        if let voice = englishVoices.first(where: { $0.quality == .enhanced }) {
            bestVoice = voice
            print("[PipVoice] Using enhanced voice: \(voice.name)")
            return voice
        }

        // Fallback to default
        bestVoice = AVSpeechSynthesisVoice(language: "en-US")
        print("[PipVoice] Using default voice (download better voices in Settings → Accessibility → Spoken Content → Voices)")
        return bestVoice
    }

    /// Stop speaking immediately
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Pause current speech
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    /// Resume paused speech
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
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
