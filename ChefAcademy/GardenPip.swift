//
//  GardenPip.swift
//  ChefAcademy
//
//  Pip on the Garden map (Oct 22 2026). The one Garden Pip: he waits on the
//  path by the gate, opens his bubble when tapped, and walks to the fence to
//  point at the tool the kid needs. Same walk art and pointing pose as the
//  Kitchen Pip. Recipe suggestions and the visitor greeting open his bubble
//  by themselves (they have buttons); tips wait for a tap.
//

import SwiftUI

// MARK: - Bubble Content

/// What Pip's map bubble shows: a message and, for event prompts, buttons.
struct GardenPipBubble {
    let message: String
    var choices: [PipDialogChoice] = []
}

// MARK: - Garden Map Pip

struct GardenMapPip: View {
    /// Owned by GardenView as plain @State (not @StateObject), so only this
    /// view redraws while Pip walks, not the whole garden.
    @ObservedObject var engine: WalkEngine
    let frameSize: CGFloat
    let sceneWidth: CGFloat
    /// Standing at the fence pointing at a tool
    let isPointing: Bool
    let bubble: GardenPipBubble?
    let onTap: () -> Void
    let onCloseBubble: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    // How much of its picture each art set fills, and how far the feet sit
    // above the picture's bottom. Measured from the art (Oct 22 2026). The
    // still poses are drawn at the walker's visible height so Pip doesn't
    // change size or hop when he stops.
    private static let walkArtFill: CGFloat = 0.625
    private static let walkArtFoot: CGFloat = 0.18
    private static let neutralArtFill: CGFloat = 0.84
    private static let neutralArtFoot: CGFloat = 0.06

    /// The walk frame's center (the engine's position) for feet standing at `feet`.
    /// Garden scene spots are where his feet go, so any frame size stands right.
    static func center(feet: CGPoint, frameSize: CGFloat) -> CGPoint {
        CGPoint(x: feet.x, y: feet.y - frameSize * (0.5 - walkArtFoot))
    }

    var body: some View {
        // Runs only while he walks; standing still costs no frames
        TimelineView(.animation(minimumInterval: nil, paused: !engine.isMoving)) { context in
            ZStack {
                sprite
                    .contentShape(Rectangle())
                    .pipTapMeTag(isShown: bubble == nil)
                    .onTapGesture(perform: onTap)
                    .position(spriteCenter)

                if let bubble {
                    PipFloatingBubble(
                        anchor: CGPoint(x: engine.position.x, y: feetY),
                        sceneWidth: sceneWidth,
                        pipHalfWidth: frameSize / 2,
                        sizeClass: sizeClass,
                        message: bubble.message,
                        onClose: onCloseBubble,
                        bottomAligned: true,
                        choices: bubble.choices
                    )
                }
            }
            // Advance the walk after the frame is drawn, not inside body
            .onChange(of: context.date) { _, now in engine.update(now: now) }
        }
    }

    /// Where Pip's feet touch the ground (engine.position is the walk frame's center).
    private var feetY: CGFloat {
        engine.position.y + frameSize * (0.5 - Self.walkArtFoot)
    }

    @ViewBuilder
    private var sprite: some View {
        if engine.isMoving {
            let names = CharacterFrameSet.pipWalking.frameNames
            let i = engine.currentFrameIndex
            Image(names.indices.contains(i) ? names[i] : names[0])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: frameSize, height: frameSize)
                .scaleEffect(x: engine.facingRight ? 1 : -1, y: 1)
                .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 4, x: 0, y: 3)
        } else {
            Image(isPointing ? PipPose.pointsUpLeft.rawValue : PipPose.neutral.rawValue)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: stillHeight)
                .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 4, x: 0, y: 3)
        }
    }

    /// Height of the still picture. The pointing art fills its whole picture;
    /// the neutral pose fills 84% of a square one.
    private var stillHeight: CGFloat {
        let visible = frameSize * Self.walkArtFill
        return isPointing ? visible : visible / Self.neutralArtFill
    }

    /// Still poses are shorter than the walk frame: center them so the feet stay put.
    private var spriteCenter: CGPoint {
        guard !engine.isMoving else { return engine.position }
        let foot = isPointing ? 0 : stillHeight * Self.neutralArtFoot
        return CGPoint(x: engine.position.x, y: feetY + foot - stillHeight / 2)
    }
}
