//
//  WaterPourCharacterView.swift
//  ChefAcademy
//
//  Animated kid character pouring water onto a plant. The source frames
//  (boy_pours_water_frame_01..15 / girl_pours_water_frame_01..15) capture
//  only the character + watering can — the actual water stream is rendered
//  in SwiftUI via Canvas + TimelineView particle physics so the water
//  visibly flows toward the plot being watered.
//
//  Layout convention (per Marina): girl enters from the LEFT of the plot,
//  boy from the RIGHT. Particles flow diagonally toward the plot center.
//
//  Used by PlotView during hold-to-water and inherited by SiblingGardenView
//  (which renders GardenView with the visitor's profile, so the visitor's
//  gender drives this view).
//

import SwiftUI

// MARK: - Water Pour Character View

struct WaterPourCharacterView: View {
    let gender: Gender
    let isActive: Bool
    var characterSize: CGFloat = 120

    @State private var frameIndex: Int = 0
    @State private var frameTimer: Timer?
    @State private var drops: [WaterDrop] = []
    @State private var lastUpdate: Date = .now

    /// 15 frame names for the chosen gender.
    private var frameNames: [String] {
        let prefix = gender == .girl ? "girl_pours_water_frame" : "boy_pours_water_frame"
        return (1...15).map { String(format: "\(prefix)_%02d", $0) }
    }

    /// Spout anchor in normalized coords (relative to character image bounding box).
    /// Eyeballed from frame 08 of each source video.
    private var spoutAnchor: CGPoint {
        switch gender {
        case .girl: return CGPoint(x: 0.58, y: 0.78)   // watering can at right hip
        case .boy:  return CGPoint(x: 0.40, y: 0.70)   // hands at waist, slight left
        }
    }

    /// Horizontal velocity sign: girl pours right (toward plot on her right),
    /// boy pours left (toward plot on his left).
    private var pourDirection: CGFloat {
        gender == .girl ? 1 : -1
    }

    var body: some View {
        ZStack {
            // Character frame
            Image(frameNames[min(frameIndex, frameNames.count - 1)])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: characterSize, height: characterSize * 1.5)

            // Water particle stream overlaid on the character
            TimelineView(.animation) { context in
                let now = context.date
                Canvas { ctx, size in
                    for drop in drops {
                        let rect = CGRect(
                            x: drop.x - drop.size / 2,
                            y: drop.y - drop.size * 1.5,
                            width: drop.size,
                            height: drop.size * 3
                        )
                        ctx.fill(
                            Capsule().path(in: rect),
                            with: .color(Color.AppTheme.rainBlue.opacity(drop.alpha))
                        )
                    }
                }
                .onChange(of: now) { _, newDate in
                    let dt = newDate.timeIntervalSince(lastUpdate)
                    updateDrops(dt: dt, canvasSize: CGSize(width: characterSize, height: characterSize * 1.5))
                    lastUpdate = newDate
                }
            }
            .frame(width: characterSize, height: characterSize * 1.5)
            .allowsHitTesting(false)
        }
        .onAppear {
            startFrameAnimation()
            lastUpdate = .now
        }
        .onChange(of: isActive) { _, active in
            if active {
                startFrameAnimation()
            } else {
                stopFrameAnimation()
            }
        }
        .onDisappear { stopFrameAnimation() }
    }

    // MARK: - Frame Animation

    /// Loops the 15 frames at ~10fps while `isActive`. Slower than the
    /// 30fps walking convention because pouring is a more deliberate motion.
    private func startFrameAnimation() {
        guard isActive else { return }
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                frameIndex = (frameIndex + 1) % frameNames.count
            }
        }
    }

    private func stopFrameAnimation() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    // MARK: - Particle Physics

    /// Spawns new drops at the spout while active and advances existing
    /// drops with gravity + horizontal velocity. Drops fade and despawn
    /// when they fall off the bottom or their alpha reaches zero.
    private func updateDrops(dt: TimeInterval, canvasSize: CGSize) {
        let delta = CGFloat(min(dt, 0.1))   // cap to prevent jumps after backgrounding

        // Spawn new drops at the spout (~6 drops/second while active)
        if isActive, drops.count < 18, CGFloat.random(in: 0...1) < delta * 6 {
            let spoutX = canvasSize.width * spoutAnchor.x
            let spoutY = canvasSize.height * spoutAnchor.y
            drops.append(WaterDrop(
                x: spoutX + CGFloat.random(in: -3...3),
                y: spoutY,
                vx: pourDirection * CGFloat.random(in: 25...50),  // horizontal velocity toward plot
                vy: CGFloat.random(in: 60...100),                  // initial downward velocity
                size: CGFloat.random(in: 3...5),
                alpha: 1.0
            ))
        }

        // Advance drops (gravity + drift + fade)
        var updated = drops
        for i in updated.indices {
            updated[i].vy += 250 * delta   // gravity
            updated[i].x += updated[i].vx * delta
            updated[i].y += updated[i].vy * delta
            updated[i].alpha -= delta * 0.8   // ~1.25s fade lifetime
        }

        // Remove off-screen or fully faded drops
        updated.removeAll { $0.alpha <= 0 || $0.y > canvasSize.height + 20 }
        drops = updated
    }
}

// MARK: - Particle Data

private struct WaterDrop {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat   // horizontal velocity (points/sec)
    var vy: CGFloat   // vertical velocity (points/sec)
    let size: CGFloat
    var alpha: Double
}

// MARK: - Preview

#Preview("Girl Pouring") {
    WaterPourCharacterView(gender: .girl, isActive: true)
        .background(Color.AppTheme.cream)
}

#Preview("Boy Pouring") {
    WaterPourCharacterView(gender: .boy, isActive: true)
        .background(Color.AppTheme.cream)
}
