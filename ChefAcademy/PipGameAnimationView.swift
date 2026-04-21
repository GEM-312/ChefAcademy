//
//  PipGameAnimationView.swift
//  ChefAcademy
//
//  One-shot 30fps frame animations for Pip's game reactions
//  (throw veggie, hand-up celebrations, fat-flying fail).
//
//  Unlike WalkEngine (loops, waypoint movement), this is a simple
//  play-once sprite animator: start on appear, tick a Timer at
//  AnimationConstants.gameFPS, stop on last frame, fire onComplete.
//
//  Retrigger by bumping the `trigger` key — .id(trigger) forces SwiftUI
//  to rebuild the view so the animation restarts from frame 1 even if
//  the same animation plays twice in a row.
//

import SwiftUI

// MARK: - Pip Game Animation

enum PipGameAnimation: String, CaseIterable {
    case throwVeggie  = "pip_throw_veggie"
    case handUpLeft   = "pip_hand_up_left"
    case handUpRight  = "pip_hand_up_right"
    case fatFlying    = "pip_fat_flying"

    static let frameCount = 30

    func frameName(_ index: Int) -> String {
        String(format: "%@_frame_%02d", rawValue, index)
    }
}

// MARK: - View

struct PipGameAnimationView: View {
    let animation: PipGameAnimation
    var size: CGFloat = 120
    var loop: Bool = false
    var fps: Double = AnimationConstants.gameFPS
    var holdLastFrame: Bool = true
    var onComplete: (() -> Void)? = nil

    @State private var frameIndex: Int = 1
    @State private var timer: Timer?

    var body: some View {
        Image(animation.frameName(frameIndex))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .onAppear { startAnimation() }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }

    private func startAnimation() {
        timer?.invalidate()
        frameIndex = 1

        let interval = 1.0 / fps
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            Task { @MainActor in
                if frameIndex >= PipGameAnimation.frameCount {
                    if loop {
                        frameIndex = 1
                    } else {
                        t.invalidate()
                        if !holdLastFrame { frameIndex = 1 }
                        onComplete?()
                    }
                } else {
                    frameIndex += 1
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Throw Veggie") {
    PipGameAnimationView(animation: .throwVeggie, size: 200)
}

#Preview("Hand Up Left") {
    PipGameAnimationView(animation: .handUpLeft, size: 200)
}

#Preview("Hand Up Right") {
    PipGameAnimationView(animation: .handUpRight, size: 200)
}

#Preview("Fat Flying") {
    PipGameAnimationView(animation: .fatFlying, size: 200)
}
