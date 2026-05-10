//
//  PipVoice.swift
//  ChefAcademy
//
//  Pip's voice — single backend: ElevenLabs (Pip Plus subscription).
//  Free tier reads Pip's words on screen; no synthesized audio.
//
//  TEACHING MOMENT: Why no Apple TTS?
//  Apple's built-in TTS voices sound robotic for kids. We tried them and
//  they broke immersion — better to have NO voice (silent reading) than
//  a bad one. The premium ElevenLabs voice becomes the clear upsell for
//  Pip Plus, and free users still see every word Pip says on screen.
//

import AVFoundation
import SwiftUI
import Combine

// MARK: - Voice Mode

enum PipVoiceMode: String, CaseIterable {
    case readText = "silent"        // Free: kid reads Pip's words on screen
    case elevenLabs = "elevenlabs"  // Pip Plus: custom Pip character voice

    var displayName: String {
        switch self {
        case .readText:    return "Read Text"
        case .elevenLabs:  return "Pip's Voice"
        }
    }

    var description: String {
        switch self {
        case .readText:    return "Read Pip's words on screen (free)"
        case .elevenLabs:  return "Pip talks with a real character voice (Pip Plus)"
        }
    }
}

// MARK: - PipVoice Service

class PipVoice: ObservableObject {
    static let shared = PipVoice()

    @Published var isSpeaking: Bool = false

    /// User preference — kids or parents can mute Pip's voice.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "com.chefacademy.pipVoiceEnabled")
            if !isEnabled { stop() }
        }
    }

    /// Which voice backend to use.
    @Published var voiceMode: PipVoiceMode {
        didSet {
            UserDefaults.standard.set(voiceMode.rawValue, forKey: "com.chefacademy.pipVoiceMode")
        }
    }

    /// Whether the user has an active Pip Plus subscription.
    /// TODO: Wire this to StoreKit 2 subscription status.
    @Published var hasSubscription: Bool = false

    // MARK: - Private State

    private let elevenLabs = ElevenLabsVoiceService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Load saved preferences
        self.isEnabled = UserDefaults.standard.object(forKey: "com.chefacademy.pipVoiceEnabled") as? Bool ?? true

        let savedMode = UserDefaults.standard.string(forKey: "com.chefacademy.pipVoiceMode") ?? "silent"
        self.voiceMode = PipVoiceMode(rawValue: savedMode) ?? .readText

        // Forward ElevenLabs speaking state to our published property
        elevenLabs.$isSpeaking
            .receive(on: RunLoop.main)
            .sink { [weak self] speaking in
                if self?.effectiveVoiceMode == .elevenLabs {
                    self?.isSpeaking = speaking
                }
            }
            .store(in: &cancellables)

        #if DEBUG
        print("[PipVoice] DEBUG build → ElevenLabs voice forced on (subscription gating bypassed)")
        #endif
    }

    // MARK: - Speak (single entry point)
    //
    // TEACHING MOMENT: This is the single entry point for ALL Pip speech.
    // Every view in the app calls PipVoice.shared.speak("text").
    // Free tier (.readText) returns silently — the text is rendered on
    // screen by the calling view. Pip Plus (.elevenLabs) plays the
    // synthesized character voice via the Cloudflare-proxied ElevenLabs API.

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }

        switch effectiveVoiceMode {
        case .readText:
            // Silent — kid reads text on screen. No audio.
            return
        case .elevenLabs:
            guard effectiveHasSubscription else { return }
            elevenLabs.speakSync(text)
        }
    }

    // MARK: - DEBUG override
    //
    // In Xcode-built device builds we force the ElevenLabs path on so we
    // can hear Pip speak before the Pip Plus subscription tier ships.
    // Release / TestFlight / App Store builds skip this branch entirely
    // and behave per the user's saved preferences (silent until subscribed).
    //
    // We override at READ TIME (computed property) instead of mutating
    // `voiceMode` / `hasSubscription` so the DEBUG choice never leaks into
    // UserDefaults — nothing to revert before shipping.

    private var effectiveVoiceMode: PipVoiceMode {
        #if DEBUG
        return .elevenLabs
        #else
        return voiceMode
        #endif
    }

    private var effectiveHasSubscription: Bool {
        #if DEBUG
        return true
        #else
        return hasSubscription
        #endif
    }

    // MARK: - Stop

    func stop() {
        elevenLabs.stop()
    }

    // MARK: - Preview Voice (for VoicePickerView)

    /// Preview the ElevenLabs Pip voice
    func previewElevenLabsVoice() {
        stop()
        elevenLabs.speakSync("Hi! I'm Pip, your kitchen garden buddy!")
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

/// Full-row toggle for parent settings screens.
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

/// Compact speaker chip — same shape as the Level/Coins/XP chips in
/// the Home header. Tap toggles Pip's voice on/off. Crucial for
/// devs/testers to control ElevenLabs API spend during play, and for
/// parents who want quiet time.
struct PipVoiceToggleChip: View {
    @ObservedObject private var voice = PipVoice.shared

    var body: some View {
        Button(action: {
            Haptic.selection()
            voice.isEnabled.toggle()
        }) {
            Image(systemName: voice.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.AppTheme.microLarge)
                .foregroundColor(voice.isEnabled ? Color.AppTheme.sage : Color.AppTheme.lightSepia)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.isEnabled ? "Turn off Pip's voice" : "Turn on Pip's voice")
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
