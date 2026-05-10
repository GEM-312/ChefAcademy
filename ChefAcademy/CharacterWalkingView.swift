//
//  CharacterWalkingView.swift
//  ChefAcademy
//
//  Generic walking animation system for any character (Pip, boy, girl, future).
//  Uses TimelineView + delta-time for smooth, battery-efficient movement.
//
//  TEACHING MOMENT: Extracting a Generic System
//
//  Before this file, we had two walking implementations:
//    1. WalkingPipView (GardenView.swift) — modern TimelineView + delta-time
//    2. FarmTransitionView (FarmShopView.swift) — legacy Timer at 30fps
//
//  Both did the same math (waypoint interpolation + frame cycling) but were
//  hardcoded to Pip's 15 frames. By extracting the common logic into WalkEngine
//  and CharacterFrameSet, we can walk ANY character with ANY frame set along
//  ANY waypoint path — Pip, boy avatar, girl avatar, or future characters.
//
//  The key abstraction: separate WHAT walks (CharacterFrameSet) from
//  HOW it walks (WalkEngine) from WHERE it walks (waypoints).
//

import SwiftUI
import Combine

// MARK: - Character Frame Sets
//
// Centralizes frame names and FPS for all character animations.
// When adding a new character animation, add a case here.

enum CharacterFrameSet {
    case pipWalking
    case pipWaving
    case boyWalking
    case girlWalking

    var frameNames: [String] {
        switch self {
        case .pipWalking:
            return (1...15).map { String(format: "pip_walking_frame_%02d", $0) }
        case .pipWaving:
            return (1...15).map { String(format: "pip_waving_frame_%02d", $0) }
        case .boyWalking:
            // 10 frames — ready when Marina draws them
            return (1...10).map { String(format: "boy_walking_frame_%02d", $0) }
        case .girlWalking:
            // 10 frames — ready when Marina draws them
            return (1...10).map { String(format: "girl_walking_frame_%02d", $0) }
        }
    }

    var fps: Double {
        switch self {
        case .pipWalking, .boyWalking, .girlWalking:
            return AnimationConstants.walkingFPS   // 8fps
        case .pipWaving:
            return AnimationConstants.wavingFPS    // 6fps
        }
    }

    var frameDuration: TimeInterval {
        1.0 / fps
    }
}

// MARK: - Walk Engine
//
// TEACHING MOMENT: Separating Logic from UI
//
// WalkEngine is an ObservableObject that handles the MATH of walking:
//   - Position interpolation between waypoints
//   - Delta-time movement (frame-rate independent)
//   - Frame cycling from elapsed time
//   - Direction detection (facing left/right)
//
// The SwiftUI view just reads the Published properties and draws.
// This makes it testable and reusable across different view layouts.

@MainActor
final class WalkEngine: ObservableObject {
    // Published state that the view reads
    @Published var position: CGPoint = .zero
    @Published var currentFrameIndex: Int = 0
    @Published var facingRight: Bool = true
    @Published private(set) var isMoving: Bool = false

    // Configuration
    let frameSet: CharacterFrameSet
    let speed: CGFloat  // points per second

    // Internal walk state
    private var waypoints: [CGPoint] = []
    private var currentWaypointIndex: Int = 0
    private var walkProgress: CGFloat = 0
    private var walkElapsed: TimeInterval = 0
    private var lastUpdate: Date = .now
    private var loops: Bool = false

    // Callbacks
    var onReachedWaypoint: ((Int) -> Void)?
    var onCompleted: (() -> Void)?

    init(frameSet: CharacterFrameSet, speed: CGFloat = AnimationConstants.walkSpeed) {
        self.frameSet = frameSet
        self.speed = speed
    }

    /// Start walking along a path of waypoints.
    /// If `loop` is true, Pip walks endlessly. If false, stops at the last waypoint.
    func start(waypoints: [CGPoint], loop: Bool = true) {
        guard waypoints.count >= 2 else { return }
        self.waypoints = waypoints
        self.loops = loop
        currentWaypointIndex = 0
        walkProgress = 0
        walkElapsed = 0
        lastUpdate = .now
        position = waypoints[0]
        isMoving = true
    }

    /// Stop walking. Character stays at current position.
    func stop() {
        isMoving = false
    }

    /// Call this from TimelineView on each frame.
    /// Uses delta-time so movement speed is consistent across 30Hz/60Hz/120Hz displays.
    func update(now: Date) {
        guard isMoving, waypoints.count >= 2 else { return }

        let dt = now.timeIntervalSince(lastUpdate)
        // Cap at 0.5s to prevent teleporting after backgrounding
        guard dt > 0, dt < 0.5 else {
            lastUpdate = now
            return
        }
        lastUpdate = now

        let delta = CGFloat(dt)

        // Current segment
        let fromIndex = currentWaypointIndex
        let toIndex = currentWaypointIndex + 1

        // If non-looping and past last segment, we're done
        guard toIndex < waypoints.count else {
            isMoving = false
            onCompleted?()
            return
        }

        let from = waypoints[fromIndex]
        let to = waypoints[toIndex]

        let dx = to.x - from.x
        let dy = to.y - from.y
        let segmentLength = sqrt(dx * dx + dy * dy)
        guard segmentLength > 0 else { return }

        // Move along segment
        let progressPerSecond = speed / segmentLength
        walkProgress += progressPerSecond * delta

        // Detect facing direction
        if dx > 1 { facingRight = true }
        else if dx < -1 { facingRight = false }

        if walkProgress >= 1.0 {
            // Reached next waypoint
            walkProgress = 0.0
            currentWaypointIndex = toIndex
            position = to
            onReachedWaypoint?(toIndex)

            // Check if we've reached the end
            if toIndex >= waypoints.count - 1 {
                if loops {
                    // Loop back to start
                    currentWaypointIndex = 0
                    position = waypoints[0]
                } else {
                    isMoving = false
                    onCompleted?()
                }
            }
        } else {
            // Interpolate between waypoints
            position = CGPoint(
                x: from.x + dx * walkProgress,
                y: from.y + dy * walkProgress
            )
        }

        // Update frame from elapsed time
        walkElapsed += dt
        currentFrameIndex = Int(walkElapsed / frameSet.frameDuration) % frameSet.frameNames.count
    }
}

// MARK: - Character Walking View
//
// A reusable SwiftUI view that displays any walking character.
// Just provide a frame set, size, and waypoints — it handles the rest.
//
// Usage:
//   CharacterWalkingView(frameSet: .pipWalking, size: 110, waypoints: path)
//   CharacterWalkingView(frameSet: .boyWalking, size: 100, waypoints: path)

struct CharacterWalkingView: View {
    /// Which character and frame set to use
    let frameSet: CharacterFrameSet

    /// Display size of the character
    let size: CGFloat

    /// Path to walk along (absolute positions)
    let waypoints: [CGPoint]

    /// Whether to start walking immediately on appear
    var autoStart: Bool = true

    /// Whether to loop or stop at the end
    var loop: Bool = true

    /// Called when the character reaches the last waypoint (non-looping)
    var onCompleted: (() -> Void)?

    /// Called when character reaches each waypoint
    var onReachedWaypoint: ((Int) -> Void)?

    @StateObject private var engine: WalkEngine

    init(
        frameSet: CharacterFrameSet,
        size: CGFloat,
        waypoints: [CGPoint],
        autoStart: Bool = true,
        loop: Bool = true,
        speed: CGFloat = AnimationConstants.walkSpeed,
        onCompleted: (() -> Void)? = nil,
        onReachedWaypoint: ((Int) -> Void)? = nil
    ) {
        self.frameSet = frameSet
        self.size = size
        self.waypoints = waypoints
        self.autoStart = autoStart
        self.loop = loop
        self.onCompleted = onCompleted
        self.onReachedWaypoint = onReachedWaypoint
        _engine = StateObject(wrappedValue: WalkEngine(frameSet: frameSet, speed: speed))
    }

    var body: some View {
        TimelineView(.animation) { context in
            let _ = engine.update(now: context.date)

            Image(currentFrameName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .scaleEffect(x: engine.facingRight ? 1 : -1, y: 1)
                .shadow(color: Color.AppTheme.sepia.opacity(0.2), radius: 4, x: 0, y: 3)
                .position(engine.position)
        }
        .onAppear {
            engine.onCompleted = onCompleted
            engine.onReachedWaypoint = onReachedWaypoint
            if autoStart {
                engine.start(waypoints: waypoints, loop: loop)
            }
        }
    }

    private var currentFrameName: String {
        let names = frameSet.frameNames
        let index = engine.currentFrameIndex
        guard index >= 0, index < names.count else { return names[0] }
        return names[index]
    }
}
