//
//  AmbientAudioPlayer.swift
//  ChefAcademy
//
//  Loops a low-volume background ambient track underneath the game.
//  Crossfades smoothly when the active track changes (e.g. weather
//  switches from sunny to rainy).
//
//  TEACHING MOMENT: Why a separate audio player from PipVoice?
//  ─────────────────────────────────────────────────────────────
//  PipVoice handles SHORT, ON-DEMAND speech (one utterance at a time,
//  triggered by events). Ambient sound is the OPPOSITE: it loops
//  continuously, runs in the background, lives at a much lower volume.
//  Two different players means we can tune them independently — Pip's
//  voice ducks the ambient track automatically via AVAudioSession.
//
//  TEACHING MOMENT: Why crossfade vs stop+start?
//  ─────────────────────────────────────────────────────────────
//  When weather flips from sunny to rainy, hard-cutting the ambient
//  track sounds jarring. Crossfading (fade out the old, fade in the
//  new over ~1.5s) is what TV / film does — the listener barely
//  notices the switch.
//

import AVFoundation
import Combine    // @Published, ObservableObject — Swift 6 strict mode requires explicit import
import Foundation
import SwiftUI

// MARK: - Ambient Track

/// One case per bundled .mp3 in `ChefAcademy/Sounds/`.
/// Add a new case + a new file to extend; everything else is generic.
enum AmbientTrack: String {
    case gardenAmbient  = "garden_ambient"
    case rainAmbient    = "rain_ambient"
    case cookingFrying  = "cooking_frying"
    case chopping       = "chopping"
    case washing        = "washing"

    /// Per-track target volume. All stay quiet — they're a backdrop,
    /// not a focus. Pip's voice (1.0) sits on top of these comfortably.
    var targetVolume: Float {
        switch self {
        case .gardenAmbient: return 0.35
        case .rainAmbient:   return 0.45 // Rain reads slightly louder to feel weather-y
        case .cookingFrying: return 0.40 // Frying — present without drowning out cues
        case .chopping:      return 0.55 // Chopping — physical, percussive, sits closer to foreground
        case .washing:       return 0.50 // Running water — present without drowning the splash SFX
        }
    }
}

// MARK: - Player

@MainActor
final class AmbientAudioPlayer: ObservableObject {

    static let shared = AmbientAudioPlayer()

    /// Current track playing (nil = silent).
    @Published private(set) var currentTrack: AmbientTrack?

    /// Master mute. UI surface this with a toggle when ready; for now
    /// it follows the same UserDefaults key pattern as PipVoice so a
    /// future "Audio settings" view can flip both with one switch.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled { stop(fade: 0.5) }
            else if let track = pendingResume { play(track) }
        }
    }

    /// If the user mutes mid-track, remember which track to resume on unmute.
    private var pendingResume: AmbientTrack?

    private static let enabledKey = "AmbientAudioPlayer.isEnabled"

    /// Two players so we can crossfade — `current` is what's audible,
    /// `next` ramps in while `current` ramps out.
    private var current: AVAudioPlayer?
    private var next: AVAudioPlayer?
    private var fadeTask: Task<Void, Never>?

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        // Use the same audio session category as PipVoice so the two
        // backends coexist cleanly. .duckOthers means external audio
        // (Apple Music, podcasts) gets quieted while we play.
        try? AVAudioSession.sharedInstance().setCategory(
            .ambient,
            mode: .default,
            options: [.mixWithOthers]
        )
    }

    // MARK: - Public API

    /// Switch to `track`. If already playing it, no-op. If a different
    /// track is playing, crossfade. If silent, fade in.
    func play(_ track: AmbientTrack, fade: TimeInterval = 1.5) {
        guard isEnabled else {
            // Stash so a later toggle-on resumes the right track.
            pendingResume = track
            return
        }
        guard track != currentTrack else { return }

        // Try Sounds/ subdirectory first (folder reference), fall back to
        // bundle root (group flattening). Whichever Xcode chose, we find it.
        let url = Bundle.main.url(forResource: track.rawValue, withExtension: "mp3", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: track.rawValue, withExtension: "mp3")
        guard let url else {
            #if DEBUG
            print("[Ambient] Missing file: \(track.rawValue).mp3 — drag the file into the Xcode project under ChefAcademy/Sounds/.")
            #endif
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1   // Loop forever
            newPlayer.volume = 0           // Start silent — fade in below
            newPlayer.prepareToPlay()
            newPlayer.play()

            // Cancel any in-flight fade so we don't fight ourselves.
            fadeTask?.cancel()

            let outgoing = current
            current = newPlayer
            next = nil
            currentTrack = track
            pendingResume = nil

            fadeTask = Task { [weak self, target = track.targetVolume] in
                await self?.crossfade(out: outgoing, in: newPlayer, target: target, duration: fade)
            }
        } catch {
            #if DEBUG
            print("[Ambient] Failed to load \(track.rawValue): \(error)")
            #endif
        }
    }

    /// Fade out and stop. Use when leaving the Garden / Kitchen / etc.
    func stop(fade: TimeInterval = 1.0) {
        let outgoing = current
        current = nil
        currentTrack = nil
        fadeTask?.cancel()

        guard let outgoing else { return }
        fadeTask = Task {
            await Self.fade(player: outgoing, from: outgoing.volume, to: 0, duration: fade)
            outgoing.stop()
        }
    }

    // MARK: - Crossfade implementation

    private func crossfade(
        out: AVAudioPlayer?,
        in newPlayer: AVAudioPlayer,
        target: Float,
        duration: TimeInterval
    ) async {
        async let fadeOut: Void = {
            guard let out else { return }
            await Self.fade(player: out, from: out.volume, to: 0, duration: duration)
            out.stop()
        }()
        async let fadeIn: Void = Self.fade(
            player: newPlayer,
            from: 0,
            to: target,
            duration: duration
        )
        _ = await (fadeOut, fadeIn)
    }

    /// Manual ramp because AVAudioPlayer.setVolume(_:fadeDuration:) is
    /// flaky on iOS — sometimes ignores the fadeDuration entirely. Doing
    /// it ourselves at ~30 fps gives a consistent linear ramp.
    private static func fade(
        player: AVAudioPlayer,
        from start: Float,
        to end: Float,
        duration: TimeInterval
    ) async {
        let steps = max(1, Int(duration * 30))   // ~30 ticks/sec
        let stepDelay = UInt64(duration / Double(steps) * 1_000_000_000)
        for i in 1...steps {
            if Task.isCancelled { return }
            let t = Float(i) / Float(steps)
            await MainActor.run { player.volume = start + (end - start) * t }
            try? await Task.sleep(nanoseconds: stepDelay)
        }
    }
}
