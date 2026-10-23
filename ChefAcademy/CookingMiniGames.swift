//
//  CookingMiniGames.swift
//  ChefAcademy
//
//  Mini-game views for the multi-step cooking system.
//  Each game calls onComplete(score: Int) with 0-100 when done.
//

import SwiftUI

/// Game-piece sizes used only by the cooking mini-games in this file.
private enum Layout {
    // Shared by several games
    static let pan: CGFloat = 180                  // frying pan image (heat, add-to-pan)
    static let progressBar: CGFloat = 12           // thin progress capsule under a game
    static let bigEmoji: CGFloat = 50              // salad in the bowl, egg in the pan
    static let smallEmoji: CGFloat = 40            // spoon, seasoning shakers
    static let propShadowOpacity = 0.3             // pans sit on the counter
    static let propShadowRadius: CGFloat = 8
    static let propShadowY: CGFloat = 4
    // Heat pan
    static let burner: CGFloat = 160               // glowing stove circle under the pan
    static let ring: CGFloat = 80                  // hold-to-heat progress ring
    static let ringStroke: CGFloat = 8
    // Add to pan
    static let dropGap: CGFloat = 60               // space between pan and the item to drag
    static let dragEmoji: CGFloat = 60
    static let dragItem: CGFloat = 80
    // Stir
    static let bowlWidth: CGFloat = 200
    static let bowlHeight: CGFloat = 140
    // Season
    static let seasonBowlWidth: CGFloat = 160
    static let seasonBowlHeight: CGFloat = 100
    static let seasonGrain: CGFloat = 4            // one falling grain
    static let tapDot: CGFloat = 8                 // sprinkles-left dots on a shaker
    // Peel
    static let peelStripWidth: CGFloat = 16
    static let peelStripHeight: CGFloat = 90
    static let peelStripCorner: CGFloat = 4
    static let veggie: CGFloat = 120
    // Cook timer
    static let flameEmoji: CGFloat = 24
    static let cookPanWidth: CGFloat = 150
    static let cookPanHeight: CGFloat = 100
    static let timerBar: CGFloat = 20
    static let timerKnob: CGFloat = 16             // the dot riding along the timer bar
    static let knobShadowRadius: CGFloat = 2
    // Wash
    static let sinkWidth: CGFloat = 300
    static let sinkHeight: CGFloat = 240
    static let washVeggie: CGFloat = 90
    static let washDirt: CGFloat = 85              // brown "dirt" circle over the veggie
    // Crack egg
    static let crackedEgg: CGFloat = 200
    static let egg: CGFloat = 150
    static let crackLineWidth: CGFloat = 2
    static let crackLineLength: CGFloat = 25
    static let eggTapDot: CGFloat = 12
    // Assemble
    static let plate: CGFloat = 220
    static let plateShadowOpacity = 0.15
}

// Haptic enum is now shared in AppTheme.swift — see ANIMATIONS.md for conventions.
//
// Quick reference:
//   Haptic.impact(.light)    — gentle tap (start action)
//   Haptic.impact(.medium)   — solid tap (mini-game interaction)
//   Haptic.impact(.heavy)    — deep thud (drop, slam)
//   Haptic.impact(.rigid)    — sharp click (perfect hit)
//   Haptic.notify(.success)  — completion buzz (3 stars, harvest)
//   Haptic.notify(.warning)  — wrong answer
//   Haptic.selection()       — subtle tick (picker change)

// MARK: - A) Heat Pan Mini Game — Tap and Hold

struct HeatPanMiniGame: View {
    let onComplete: (Int) -> Void

    @State private var progress: CGFloat = 0     // 0→1
    @State private var isHolding = false
    @State private var liftCount = 0             // Penalty for lifting
    @State private var timer: Timer?
    @State private var isDone = false
    @State private var panGlow: Double = 0

    private let holdDuration: CGFloat = 3.0      // seconds to fill

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Pan visual
            ZStack {
                // Stove burner
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.AppTheme.terracotta.opacity(panGlow * 0.6),
                                Color.AppTheme.goldenWheat.opacity(panGlow * 0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: Layout.burner, height: Layout.burner)

                // Pan image
                Image("frying_pan")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.pan, height: Layout.pan)
                    .shadow(color: Color.AppTheme.sepia.opacity(Layout.propShadowOpacity), radius: Layout.propShadowRadius, y: Layout.propShadowY)

                // Heat shimmer when warm
                if panGlow > 0.3 {
                    ForEach(0..<3, id: \.self) { i in
                        Text("~")
                            .font(.AppTheme.title3)
                            .foregroundColor(Color.AppTheme.terracotta.opacity(0.5))
                            .offset(x: CGFloat(i * 25 - 25), y: -60)
                            .opacity(panGlow)
                    }
                }
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.AppTheme.parchment, lineWidth: Layout.ringStroke)
                    .frame(width: Layout.ring, height: Layout.ring)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.AppTheme.sage, style: StrokeStyle(lineWidth: Layout.ringStroke, lineCap: .round))
                    .frame(width: Layout.ring, height: Layout.ring)
                    .rotationEffect(.degrees(-90))
                    .animation(AnimationConstants.progressTick, value: progress)

                Image(systemName: isHolding ? "flame.fill" : "flame")
                    .font(.AppTheme.title)
                    .foregroundColor(isHolding ? Color.AppTheme.terracotta : Color.AppTheme.sepia)
            }

            Text(isHolding ? "Heating up..." : "Hold to heat the pan!")
                .font(.AppTheme.callout)
                .foregroundColor(Color.AppTheme.sepia)

            Spacer()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHolding && !isDone {
                        startHolding()
                    }
                }
                .onEnded { _ in
                    if isHolding && !isDone {
                        stopHolding()
                    }
                }
        )
        .onDisappear { timer?.invalidate() }
    }

    private func startHolding() {
        isHolding = true
        Haptic.impact(.light) // gentle warmth starting
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                progress += 0.05 / holdDuration
                panGlow = Double(progress)
                if progress >= 1.0 {
                    finishGame()
                }
            }
        }
    }

    private func stopHolding() {
        isHolding = false
        liftCount += 1
        timer?.invalidate()
    }

    private func finishGame() {
        timer?.invalidate()
        isDone = true
        Haptic.notify(.success) // pan is hot!
        let score = max(0, 100 - liftCount * 10)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            onComplete(score)
        }
    }
}

// MARK: - B) Add To Pan Mini Game — Drag to Target

struct AddToPanMiniGame: View {
    let itemName: String
    let itemImage: String
    let useEmoji: Bool
    let emoji: String
    let onComplete: (Int) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var dropped = false
    @State private var itemScale: CGFloat = 1.0

    // Pan target zone
    private let panCenter = CGPoint(x: 0, y: -80)
    private let dropRadius: CGFloat = 70

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Pan target
            ZStack {
                Image("frying_pan")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.pan, height: Layout.pan)
                    .shadow(color: Color.AppTheme.sepia.opacity(Layout.propShadowOpacity), radius: Layout.propShadowRadius, y: Layout.propShadowY)

                if dropped {
                    Text("Sizzle!")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.terracotta)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Spacer().frame(height: Layout.dropGap)

            // Draggable item
            if !dropped {
                Group {
                    if useEmoji {
                        Text(emoji)
                            .font(.AppTheme.rounded(size: Layout.dragEmoji))
                    } else {
                        Image(itemImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Layout.dragItem, height: Layout.dragItem)
                    }
                }
                .scaleEffect(itemScale)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            isDragging = false
                            checkDrop(offset: value.translation)
                        }
                )

                Text("Drag \(itemName) into the pan!")
                    .font(.AppTheme.callout)
                    .foregroundColor(Color.AppTheme.sepia)
                    .padding(.top, AppSpacing.sm)
            }

            Spacer()
        }
    }

    private func checkDrop(offset: CGSize) {
        // Check if item was dragged close enough to pan center
        let distance = sqrt(pow(offset.width - panCenter.x, 2) + pow(offset.height - panCenter.y, 2))
        let inTarget = distance < dropRadius + 40 // generous hit box

        Haptic.impact(inTarget ? .medium : .soft) // sizzle thud on hit, soft miss

        withAnimation(AnimationConstants.springQuick) {
            dropped = true
            if inTarget {
                // Hit: drop into the pan and shrink as it lands
                dragOffset = CGSize(width: panCenter.x, height: panCenter.y)
                itemScale = 0.3
            } else {
                // Miss: bounce back to the start so the kid sees it didn't land
                dragOffset = .zero
                itemScale = 1.0
            }
        }

        let score = inTarget ? 100 : 50
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            onComplete(score)
        }
    }
}

// MARK: - C) Stir Mini Game — Circular Swipe

struct StirMiniGame: View {
    let onComplete: (Int) -> Void

    @State private var rotations: CGFloat = 0    // Full rotations completed
    @State private var lastAngle: CGFloat = 0
    @State private var spoonAngle: CGFloat = 0
    @State private var isDone = false

    private let targetRotations: CGFloat = 3

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                // Bowl
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.AppTheme.parchment, Color.AppTheme.warmCream.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: Layout.bowlWidth, height: Layout.bowlHeight)

                // Ingredients in bowl
                Text("🥗")
                    .font(.AppTheme.rounded(size: Layout.bigEmoji))
                    .rotationEffect(.degrees(Double(spoonAngle) * 2))

                // Spoon
                Text("🥄")
                    .font(.AppTheme.rounded(size: Layout.smallEmoji))
                    .offset(x: cos(spoonAngle) * 50, y: sin(spoonAngle) * 30)
            }
            .contentShape(Circle().size(width: 250, height: 250))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isDone else { return }
                        let center = CGPoint(x: 100, y: 70) // approx center
                        let currentAngle = atan2(value.location.y - center.y, value.location.x - center.x)

                        let delta = currentAngle - lastAngle
                        // Only count small deltas (avoid jumps)
                        if abs(delta) < .pi {
                            rotations += abs(delta) / (2 * .pi)
                            spoonAngle = currentAngle
                        }
                        lastAngle = currentAngle

                        if rotations >= targetRotations {
                            finishGame()
                        }
                    }
            )

            // Progress
            VStack(spacing: AppSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.AppTheme.parchment)
                        Capsule()
                            .fill(Color.AppTheme.sage)
                            .frame(width: geo.size.width * min(rotations / targetRotations, 1.0))
                    }
                }
                .frame(height: Layout.progressBar)

                Text("\(Int(min(rotations / targetRotations, 1.0) * 100))% stirred")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .padding(.horizontal, AppSpacing.lg)

            Text("Draw circles to stir!")
                .font(.AppTheme.callout)
                .foregroundColor(Color.AppTheme.sepia)

            Spacer()
        }
    }

    private func finishGame() {
        guard !isDone else { return }
        isDone = true
        Haptic.notify(.success) // well stirred!
        let score = min(100, Int(rotations / targetRotations * 100))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            onComplete(score)
        }
    }
}

// MARK: - D) Season Mini Game — Tap to Sprinkle

struct SeasonMiniGame: View {
    let items: [PantryItem]
    let onComplete: (Int) -> Void

    @State private var tapCounts: [String: Int] = [:]
    @State private var particles: [SeasonParticle] = []
    @State private var isDone = false

    private let tapsPerItem = 3

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Pan/bowl at center
            ZStack {
                Ellipse()
                    .fill(Color.AppTheme.sepia)
                    .frame(width: Layout.seasonBowlWidth, height: Layout.seasonBowlHeight)

                // Falling particles
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: Layout.seasonGrain, height: Layout.seasonGrain)
                        .offset(x: particle.x, y: particle.y)
                }
            }

            // Seasoning buttons
            HStack(spacing: AppSpacing.lg) {
                ForEach(items, id: \.rawValue) { item in
                    seasonButton(for: item)
                }
            }

            // Progress
            let totalTaps = tapCounts.values.reduce(0, +)
            let totalNeeded = items.count * tapsPerItem
            Text("\(totalTaps)/\(totalNeeded) sprinkles")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)

            Text("Tap each seasoning to sprinkle!")
                .font(.AppTheme.callout)
                .foregroundColor(Color.AppTheme.sepia)

            Spacer()
        }
    }

    private func seasonButton(for item: PantryItem) -> some View {
        let count = tapCounts[item.rawValue] ?? 0
        let done = count >= tapsPerItem

        return Button {
            guard !isDone, !done else { return }
            Haptic.impact(.light) // gentle sprinkle
            tapCounts[item.rawValue, default: 0] += 1
            spawnParticle(for: item)
            checkCompletion()
        } label: {
            VStack(spacing: AppSpacing.xxs) {
                Text(item.emoji)
                    .font(.AppTheme.rounded(size: Layout.smallEmoji))
                    .scaleEffect(done ? 0.8 : 1.0)
                    .opacity(done ? 0.5 : 1.0)

                Text(item.displayName)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)

                // Tap dots
                HStack(spacing: AppSpacing.xxs) {
                    ForEach(0..<tapsPerItem, id: \.self) { i in
                        Circle()
                            .fill(i < count ? Color.AppTheme.sage : Color.AppTheme.parchment)
                            .frame(width: Layout.tapDot, height: Layout.tapDot)
                    }
                }
            }
        }
        // Shared pick-card look; a shaker turns "picked" once its sprinkles are done
        .choiceCard(tint: Color.AppTheme.sage, isSelected: done,
                    cornerRadius: AppSpacing.smallCornerRadius, padding: AppSpacing.sm)
        .disabled(done)
    }

    private func spawnParticle(for item: PantryItem) {
        let color: Color = {
            switch item {
            case .salt: return Color.AppTheme.cream
            case .pepper: return Color.AppTheme.darkBrown
            case .cinnamon: return Color.AppTheme.terracotta
            default: return Color.AppTheme.sepia
            }
        }()

        for _ in 0..<5 {
            let particle = SeasonParticle(
                x: CGFloat.random(in: -40...40),
                y: -60,
                color: color
            )
            particles.append(particle)
        }
        // Cap particles to prevent unbounded growth from rapid tapping
        if particles.count > 20 {
            particles.removeFirst(particles.count - 20)
        }

        // Animate particles down
        withAnimation(AnimationConstants.particleFall) {
            for i in max(0, particles.count - 5)..<particles.count {
                particles[i].y = CGFloat.random(in: -10...20)
            }
        }
    }

    private func checkCompletion() {
        let allDone = items.allSatisfy { (tapCounts[$0.rawValue] ?? 0) >= tapsPerItem }
        if allDone {
            isDone = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                onComplete(100)
            }
        }
    }
}

struct SeasonParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
}

// MARK: - E) Peel Mini Game — Swipe Down

struct PeelMiniGame: View {
    let vegetable: VegetableType
    let onComplete: (Int) -> Void

    @State private var swipeCount = 0
    @State private var totalAccuracy: CGFloat = 0
    @State private var peelLayers: [Bool] = [true, true, true, true, true]
    @State private var isDone = false

    private let targetSwipes = 5

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Veggie with peel layers
            ZStack {
                // Peel layers (strips that disappear)
                ForEach(0..<5, id: \.self) { i in
                    if peelLayers[i] {
                        RoundedRectangle(cornerRadius: Layout.peelStripCorner)
                            .fill(Color.AppTheme.goldenWheat.opacity(0.6))
                            .frame(width: Layout.peelStripWidth, height: Layout.peelStripHeight)
                            .offset(x: CGFloat(i * 18 - 36))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Veggie image
                Image(vegetable.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.veggie, height: Layout.veggie)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard !isDone else { return }
                        let vertical = abs(value.translation.height)
                        let horizontal = abs(value.translation.width)

                        // Must be more vertical than horizontal
                        if value.translation.height > 30 && vertical > horizontal {
                            let accuracy = min(1.0, vertical / (vertical + horizontal))
                            handleSwipe(accuracy: accuracy)
                        }
                    }
            )

            // Progress
            VStack(spacing: AppSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.AppTheme.parchment)
                        Capsule()
                            .fill(Color.AppTheme.sage)
                            .frame(width: geo.size.width * CGFloat(swipeCount) / CGFloat(targetSwipes))
                    }
                }
                .frame(height: Layout.progressBar)

                Text("\(swipeCount)/\(targetSwipes) peels")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .padding(.horizontal, AppSpacing.lg)

            Text("Swipe down to peel!")
                .font(.AppTheme.callout)
                .foregroundColor(Color.AppTheme.sepia)

            Spacer()
        }
    }

    private func handleSwipe(accuracy: CGFloat) {
        Haptic.impact(.medium) // peel strip ripping off
        if swipeCount < peelLayers.count {
            withAnimation(AnimationConstants.fadeMedium) {
                peelLayers[swipeCount] = false
            }
        }
        swipeCount += 1
        totalAccuracy += accuracy

        if swipeCount >= targetSwipes {
            isDone = true
            let avgAccuracy = totalAccuracy / CGFloat(targetSwipes)
            let score = Int(avgAccuracy * 100)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                onComplete(score)
            }
        }
    }
}

// MARK: - F) Cook Timer Mini Game — Watch and Tap

struct CookTimerMiniGame: View {
    let totalSeconds: Int
    let onComplete: (Int) -> Void

    @State private var elapsed: CGFloat = 0
    @State private var timer: Timer?
    @State private var isDone = false
    @State private var flameScale: CGFloat = 1.0
    @State private var showWaitCue = false
    @State private var waitCueTask: Task<Void, Never>?

    var body: some View {
        let total = CGFloat(totalSeconds)
        let greenStart = total * 0.35
        let greenEnd = total * 0.65
        let fraction = min(elapsed / total, 1.0)

        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Pan on stove
            ZStack {
                // Flames
                HStack(spacing: AppSpacing.xs) {
                    ForEach(0..<3, id: \.self) { _ in
                        Text("🔥")
                            .font(.AppTheme.rounded(size: Layout.flameEmoji))
                            .scaleEffect(flameScale)
                    }
                }
                .offset(y: 50)

                // Pan
                Ellipse()
                    .fill(Color.AppTheme.sepia)
                    .frame(width: Layout.cookPanWidth, height: Layout.cookPanHeight)

                Text("🍳")
                    .font(.AppTheme.rounded(size: Layout.bigEmoji))
            }

            // Timer bar
            VStack(spacing: AppSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule().fill(Color.AppTheme.parchment)

                        // Green zone
                        Capsule()
                            .fill(Color.AppTheme.sage.opacity(0.3))
                            .frame(width: geo.size.width * 0.3)
                            .offset(x: geo.size.width * 0.35)

                        // Elapsed fill
                        let fillColor: Color = {
                            if elapsed < greenStart { return Color.AppTheme.goldenWheat }
                            else if elapsed <= greenEnd { return Color.AppTheme.sage }
                            else { return Color.AppTheme.terracotta }
                        }()

                        Capsule()
                            .fill(fillColor)
                            .frame(width: geo.size.width * fraction)

                        // Indicator
                        Circle()
                            .fill(Color.AppTheme.cream)
                            .frame(width: Layout.timerKnob, height: Layout.timerKnob)
                            .shadow(color: Color.AppTheme.sepia.opacity(Layout.propShadowOpacity), radius: Layout.knobShadowRadius)
                            .offset(x: geo.size.width * fraction - Layout.timerKnob / 2)
                    }
                }
                .frame(height: Layout.timerBar)

                Text(timerText)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .padding(.horizontal, AppSpacing.lg)

            // Transient "wait for green zone" cue (shown on pre-zone tap).
            if showWaitCue {
                PipSpeechBubble(
                    message: "Wait for the green zone!",
                    pose: .thinking,
                    size: .compact,
                    speakOnAppear: false
                )
                .padding(.horizontal, AppSpacing.lg)
                .transition(.opacity)
            }

            // Done button
            if !isDone {
                Button {
                    if elapsed < greenStart {
                        showWaitCueAndSpeak()
                    } else {
                        finishCooking()
                    }
                } label: {
                    Text("Done!")
                }
                // Quiet before the green zone, "go" once it's time to tap
                .buttonStyle(TexturedButtonStyle(
                    tint: elapsed >= greenStart ? Color.AppTheme.buttonGo : Color.AppTheme.buttonBack,
                    fullWidth: false))
            }

            Text("Tap Done when the timer reaches the green zone!")
                .font(.AppTheme.callout)
                .foregroundColor(Color.AppTheme.sepia)

            Spacer()
        }
        .onAppear { startTimer() }
        .onDisappear {
            timer?.invalidate()
            waitCueTask?.cancel()
        }
    }

    /// Pre-zone tap handler — speaks the cue, shows a transient bubble,
    /// and gives a warning haptic. Does NOT finish the round so the kid
    /// can keep waiting for the green zone.
    private func showWaitCueAndSpeak() {
        Haptic.notify(.warning)
        PipVoice.shared.speak("Wait for the green zone!")
        waitCueTask?.cancel()
        withAnimation(AnimationConstants.fadeQuick) { showWaitCue = true }
        waitCueTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.fadeFast) { showWaitCue = false }
        }
    }

    private var timerText: String {
        let remaining = max(0, CGFloat(totalSeconds) - elapsed)
        return String(format: "%.1fs", remaining)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 0.1
                // Flame animation
                flameScale = 1.0 + CGFloat.random(in: -0.1...0.1)

                if elapsed >= CGFloat(totalSeconds) + 2 {
                    // Auto-finish if they wait too long
                    finishCooking()
                }
            }
        }
    }

    private func finishCooking() {
        guard !isDone else { return }
        isDone = true
        timer?.invalidate()

        // Haptic: success if in green zone, warning if too early/late
        let gs = CGFloat(totalSeconds) * 0.35
        let ge = CGFloat(totalSeconds) * 0.65
        Haptic.notify(elapsed >= gs && elapsed <= ge ? .success : .warning)

        let total = CGFloat(totalSeconds)
        let greenStart = total * 0.35
        let greenEnd = total * 0.65

        let score: Int
        if elapsed >= greenStart && elapsed <= greenEnd {
            score = 100
        } else if elapsed < greenStart {
            // Too early
            let earlyness = (greenStart - elapsed) / greenStart
            score = max(30, 100 - Int(earlyness * 70))
        } else {
            // Too late
            let lateness = (elapsed - greenEnd) / total
            score = max(20, 100 - Int(lateness * 100))
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            onComplete(score)
        }
    }
}

// MARK: - G) Wash Mini Game — Tap repeatedly

struct WashMiniGame: View {
    let vegetable: VegetableType
    let onComplete: (Int) -> Void

    @State private var tapCount = 0
    @State private var bubbles: [WashBubble] = []
    @State private var splashes: [WashSplash] = []
    @State private var isDone = false
    @State private var vegScale: CGFloat = 1.0
    @State private var vegRotation: Double = 0
    @State private var vegY: CGFloat = -120        // Starts above sink
    @State private var dirtOpacity: Double = 0.5   // Brown overlay = dirt
    @State private var shineOpacity: Double = 0     // Sparkle = clean
    @State private var sinkFrame = 1
    @State private var sinkTimer: Timer?

    private let targetTaps = 6
    private let totalSinkFrames = 15

    /// How clean the veggie is (0 = dirty, 1 = sparkling)
    private var cleanProgress: CGFloat { CGFloat(tapCount) / CGFloat(targetTaps) }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()

            // Instruction
            Text(isDone ? "Sparkling clean!" : "Tap to wash the \(vegetable.displayName.lowercased())!")
                .font(.AppTheme.headline)
                .foregroundColor(isDone ? Color.AppTheme.sage : Color.AppTheme.sepia)

            // Sink + veggie scene
            ZStack {
                // Animated kitchen sink (15 frames)
                Image(String(format: "kitchen_sink_%02d", sinkFrame))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.sinkWidth, height: Layout.sinkHeight)

                // Veggie in the sink — gets cleaner with each tap
                ZStack {
                    // The veggie
                    Image(vegetable.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.washVeggie, height: Layout.washVeggie)
                        .scaleEffect(vegScale)
                        .rotationEffect(.degrees(vegRotation))

                    // Dirt overlay (brown tint that fades as you wash)
                    Circle()
                        .fill(Color.AppTheme.warmKhaki.opacity(dirtOpacity))
                        .frame(width: Layout.washDirt, height: Layout.washDirt)
                        .blendMode(.multiply)

                    // Clean sparkle (appears as veggie gets cleaner)
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .offset(
                                x: [-30, 25, -5][i],
                                y: [-25, -20, 30][i]
                            )
                            .opacity(shineOpacity)
                    }
                }
                .offset(y: vegY)

                // Water splashes on tap
                ForEach(splashes) { splash in
                    Text("💦")
                        .font(.AppTheme.rounded(size: splash.size))
                        .offset(x: splash.x, y: splash.y)
                        .opacity(splash.opacity)
                }

                // Bubbles
                ForEach(bubbles) { bubble in
                    Circle()
                        .fill(Color.AppTheme.cream.opacity(0.5))
                        .frame(width: bubble.size, height: bubble.size)
                        .offset(x: bubble.x, y: bubble.y + vegY + 40)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isDone else { return }
                handleTap()
            }

            // Progress bar
            VStack(spacing: AppSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.AppTheme.parchment)
                        Capsule()
                            .fill(Color.AppTheme.sage)
                            .frame(width: geo.size.width * cleanProgress)
                            .animation(AnimationConstants.springQuick, value: cleanProgress)
                    }
                }
                .frame(height: Layout.progressBar)

                HStack {
                    Text("🧽")
                    Text(isDone ? "Clean!" : "\(tapCount)/\(targetTaps)")
                        .font(.AppTheme.callout)
                        .foregroundColor(Color.AppTheme.sepia)
                    if isDone {
                        Text("✨")
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
        .onAppear {
            startSinkAnimation()
            // Veggie drops into sink
            withAnimation(AnimationConstants.springFly.delay(0.3)) {
                vegY = 10
            }
            // Running-water ambient while washing. CookingSessionView's
            // frying loop crossfades back in when this view disappears.
            AmbientAudioPlayer.shared.play(.washing)
        }
        .onDisappear {
            sinkTimer?.invalidate()
            AmbientAudioPlayer.shared.play(.cookingFrying)
        }
    }

    private func startSinkAnimation() {
        sinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 8.0, repeats: true) { _ in
            Task { @MainActor in
                sinkFrame = (sinkFrame % totalSinkFrames) + 1
            }
        }
    }

    private func handleTap() {
        tapCount += 1
        Haptic.impact(.soft) // water splash feel

        // Veggie bounces and rotates (like scrubbing)
        withAnimation(AnimationConstants.springSnappy) {
            vegScale = 0.85
            vegRotation = Double.random(in: -15...15)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.springSnappy) {
                vegScale = 1.0
                vegRotation = 0
            }
        }

        // Dirt fades away with each tap
        withAnimation(AnimationConstants.fadeMedium) {
            dirtOpacity = max(0, 0.5 - (Double(tapCount) / Double(targetTaps)) * 0.5)
        }

        // Shine appears as veggie gets cleaner
        withAnimation(AnimationConstants.fadeMedium) {
            shineOpacity = Double(tapCount) / Double(targetTaps) * 0.8
        }

        // Water splash effect
        let splash = WashSplash(
            x: CGFloat.random(in: -40...40),
            y: vegY + CGFloat.random(in: -20...20),
            size: CGFloat.random(in: 14...22),
            opacity: 1.0
        )
        splashes.append(splash)

        // Fade and remove splash
        withAnimation(AnimationConstants.fadeMedium) {
            if let idx = splashes.firstIndex(where: { $0.id == splash.id }) {
                splashes[idx].y -= 30
                splashes[idx].opacity = 0
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            splashes.removeAll { $0.opacity <= 0 }
        }

        // Spawn bubbles around veggie
        for _ in 0..<2 {
            bubbles.append(WashBubble(
                x: CGFloat.random(in: -50...50),
                y: CGFloat.random(in: -20...20),
                size: CGFloat.random(in: 6...16)
            ))
        }

        // Done!
        if tapCount >= targetTaps {
            isDone = true
            sinkTimer?.invalidate()

            // Final shine burst
            withAnimation(AnimationConstants.springMedium) {
                shineOpacity = 1.0
                vegScale = 1.15
                dirtOpacity = 0
            }

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                onComplete(100)
            }
        }
    }
}

struct WashSplash: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

struct WashBubble: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
}

// MARK: - H) Crack Egg Mini Game — Tap to crack

struct CrackEggMiniGame: View {
    let onComplete: (Int) -> Void

    @State private var tapCount = 0
    @State private var cracked = false
    @State private var isDone = false

    private let targetTaps = 4

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                if cracked {
                    // Cracked egg with yolk
                    Image("cracked_egg_yolk")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Layout.crackedEgg, height: Layout.crackedEgg)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Whole egg (using farm_eggs asset)
                    ZStack {
                        Image("farm_eggs")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: Layout.egg, height: Layout.egg)

                        // Crack lines appear with each tap
                        if tapCount > 0 {
                            ForEach(0..<tapCount, id: \.self) { i in
                                Rectangle()
                                    .fill(Color.AppTheme.sepia.opacity(0.6))
                                    .frame(width: Layout.crackLineWidth, height: Layout.crackLineLength)
                                    .rotationEffect(.degrees(Double(i) * 30 - 15))
                                    .offset(y: -5)
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isDone else { return }
                handleTap()
            }

            // Progress
            HStack(spacing: AppSpacing.xxs) {
                ForEach(0..<targetTaps, id: \.self) { i in
                    Circle()
                        .fill(i < tapCount ? Color.AppTheme.sage : Color.AppTheme.parchment)
                        .frame(width: Layout.eggTapDot, height: Layout.eggTapDot)
                }
            }

            Text(cracked ? "Cracked!" : "Tap to crack the egg!")
                .font(.AppTheme.callout)
                .foregroundColor(Color.AppTheme.sepia)

            Spacer()
        }
    }

    private func handleTap() {
        tapCount += 1
        if tapCount >= targetTaps {
            Haptic.impact(.heavy) // egg breaks open!
            withAnimation(AnimationConstants.springBouncy) {
                cracked = true
            }
            isDone = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled else { return }
                onComplete(100)
            }
        } else {
            Haptic.impact(.rigid) // sharp crack tap
        }
    }
}

// MARK: - I) Assemble Mini Game — Tap to finish

struct AssembleMiniGame: View {
    let instruction: String
    let onComplete: (Int) -> Void

    @State private var progress: CGFloat = 0
    @State private var isDone = false
    @State private var sparkles: [AssembleSparkle] = []

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                // Plate image
                Image("empty_plate")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.plate, height: Layout.plate)
                    .shadow(color: Color.AppTheme.sepia.opacity(Layout.plateShadowOpacity), radius: Layout.propShadowRadius, y: Layout.propShadowY)

                // Sparkles
                ForEach(sparkles) { sparkle in
                    Image(systemName: "sparkle")
                        .font(.AppTheme.rounded(size: sparkle.size))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                        .offset(x: sparkle.x, y: sparkle.y)
                        .opacity(sparkle.opacity)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.AppTheme.parchment)
                    Capsule()
                        .fill(Color.AppTheme.goldenWheat)
                        .frame(width: geo.size.width * progress)
                        .animation(AnimationConstants.fadeFast, value: progress)
                }
            }
            .frame(height: Layout.progressBar)
            .padding(.horizontal, AppSpacing.lg)

            if !isDone {
                Button {
                    handleTap()
                } label: {
                    Text("Plate it up!")
                }
                .buttonStyle(TexturedButtonStyle(tint: Color.AppTheme.buttonReward, fullWidth: false))
            } else {
                Text("Beautiful!")
                    .font(.AppTheme.title3)
                    .foregroundColor(Color.AppTheme.sage)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDone { handleTap() }
        }
    }

    private func handleTap() {
        progress += 0.35
        spawnSparkle()

        if progress >= 1.0 {
            isDone = true
            Haptic.notify(.success) // beautiful plating!
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled else { return }
                onComplete(100)
            }
        } else {
            Haptic.impact(.light) // gentle placement
        }
    }

    private func spawnSparkle() {
        let sparkle = AssembleSparkle(
            x: CGFloat.random(in: -60...60),
            y: CGFloat.random(in: -40...40),
            size: CGFloat.random(in: 10...20),
            opacity: 1.0
        )
        sparkles.append(sparkle)
        // Fade out
        withAnimation(AnimationConstants.sparkleFade) {
            if let idx = sparkles.firstIndex(where: { $0.id == sparkle.id }) {
                sparkles[idx].opacity = 0
            }
        }
    }
}

struct AssembleSparkle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

// MARK: - Previews

#Preview("Heat Pan") {
    HeatPanMiniGame { score in print("Score: \(score)") }
}

#Preview("Add To Pan") {
    AddToPanMiniGame(itemName: "Butter", itemImage: "farm_butter", useEmoji: true, emoji: "🧈") { score in print("Score: \(score)") }
}

#Preview("Stir") {
    StirMiniGame { score in print("Score: \(score)") }
}

#Preview("Season") {
    SeasonMiniGame(items: [.salt, .pepper]) { score in print("Score: \(score)") }
}

#Preview("Peel") {
    PeelMiniGame(vegetable: .carrot) { score in print("Score: \(score)") }
}

#Preview("Cook Timer") {
    CookTimerMiniGame(totalSeconds: 8) { score in print("Score: \(score)") }
}

#Preview("Wash") {
    WashMiniGame(vegetable: .lettuce) { score in print("Score: \(score)") }
}

#Preview("Crack Egg") {
    CrackEggMiniGame { score in print("Score: \(score)") }
}

#Preview("Assemble") {
    AssembleMiniGame(instruction: "Slide onto a plate!") { score in print("Score: \(score)") }
}
