//
//  AppAudioSession.swift
//  ChefAcademy
//
//  The ONE place the app's audio session is set up. Pip's voice
//  (ElevenLabsVoiceService) and the garden/kitchen sounds
//  (AmbientAudioPlayer) share a single iOS audio session, so they
//  must not each pick their own category: before, whichever started
//  last won, and the silent switch muted Pip or not depending on
//  which screen opened first.
//
//  TEACHING MOMENT: Why off the main thread?
//  Turning the audio session on talks to the system audio daemon and
//  can block while it's busy (another app playing, headphones
//  connecting). On the main thread that freezes the screen, so Apple
//  logs "AVAudioSession Hang Risk". We activate it once at launch on a
//  background task; after that, AVAudioPlayer.play() finds it already
//  on and has nothing slow left to do.
//

import AVFoundation

enum AppAudioSession {
    /// Call once at launch.
    /// .playback: Pip still talks with the silent switch on (decided Oct 23 2026),
    /// so kids who can't read yet always hear him.
    /// .mixWithOthers: the player's own music keeps playing underneath.
    static func configure() {
        Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                #if DEBUG
                print("[Audio] Session ready: \(session.category.rawValue)")
                #endif
            } catch {
                print("[Audio] Session setup failed: \(error)")
            }
        }
    }
}
