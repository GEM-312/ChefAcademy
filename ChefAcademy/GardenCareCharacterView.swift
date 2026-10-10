//
//  GardenCareCharacterView.swift
//  ChefAcademy
//
//  One-shot kid animation for plot care: pulling a weed or rescuing a bug.
//  The frames (<boy|girl>_pulls_weed_frame_01..15 / <boy|girl>_rescues_bug_frame_01..15)
//  hold only the action — the clip's return to the idle pose was cut — so the
//  view plays them ONCE and rests on the last frame. PlotView shows it beside
//  the plot the same way it shows WaterPourCharacterView (girl on the left,
//  boy on the right) and removes it when the play is over.
//

import SwiftUI

// MARK: - Care Action

enum GardenCareAction: Equatable {
    case pullWeed
    case rescueBug

    /// Middle part of the asset names, e.g. "girl_pulls_weed_frame_01".
    fileprivate var assetStem: String {
        switch self {
        case .pullWeed:  return "pulls_weed"
        case .rescueBug: return "rescues_bug"
        }
    }
}

// MARK: - Garden Care Character View

struct GardenCareCharacterView: View {
    let gender: Gender
    let action: GardenCareAction
    /// Bump to replay from frame 1 — one play per weed pulled or bug rescued.
    let playID: Int
    var characterSize: CGFloat = 120

    @State private var frameIndex = 0
    @State private var playTask: Task<Void, Never>?

    static let frameCount = 15

    /// Seconds one full play takes at `AnimationConstants.careFPS`.
    static var playDuration: Double {
        Double(frameCount - 1) / AnimationConstants.careFPS
    }

    private var frameNames: [String] {
        let prefix = "\(gender == .girl ? "girl" : "boy")_\(action.assetStem)_frame"
        return (1...Self.frameCount).map { String(format: "\(prefix)_%02d", $0) }
    }

    var body: some View {
        Image(frameNames[frameIndex])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: characterSize, height: characterSize * 1.5)
            .onAppear { play() }
            .onChange(of: playID) { _, _ in play() }
            .onDisappear { playTask?.cancel() }
    }

    // MARK: - Frame Animation

    /// Steps through the frames once. A Task (not a Timer) so a replay or the
    /// view disappearing cancels the previous run cleanly (CLAUDE.md §2).
    private func play() {
        playTask?.cancel()
        frameIndex = 0
        playTask = Task { @MainActor in
            for index in 1..<Self.frameCount {
                try? await Task.sleep(for: .seconds(1 / AnimationConstants.careFPS))
                guard !Task.isCancelled else { return }
                frameIndex = index
            }
        }
    }
}

// MARK: - Previews

#Preview("Girl pulls weed") {
    GardenCareCharacterView(gender: .girl, action: .pullWeed, playID: 0)
}

#Preview("Boy rescues bug") {
    GardenCareCharacterView(gender: .boy, action: .rescueBug, playID: 0)
}
