//
//  CookingMiniGames.swift
//  ChefAcademy
//
//  Mini-game views for the multi-step cooking system.
//  Each game calls onComplete(score: Int) with 0-100 when done.
//

import SwiftUI

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
                    .frame(width: 160, height: 160)

                // Pan image
                Image("frying_pan")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .shadow(color: Color.AppTheme.sepia.opacity(0.3), radius: 8, y: 4)

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
                    .stroke(Color.AppTheme.parchment, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.AppTheme.sage, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: progress)

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
            progress += 0.05 / holdDuration
            panGlow = Double(progress)
            if progress >= 1.0 {
                finishGame()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                    .frame(width: 180, height: 180)
                    .shadow(color: Color.AppTheme.sepia.opacity(0.3), radius: 8, y: 4)

                if dropped {
                    Text("Sizzle!")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.terracotta)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Spacer().frame(height: 60)

            // Draggable item
            if !dropped {
                Group {
                    if useEmoji {
                        Text(emoji)
                            .font(.AppTheme.rounded(size: 60))
                    } else {
                        Image(itemImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
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

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            dropped = true
            if inTarget {
                dragOffset = CGSize(width: panCenter.x, height: panCenter.y)
                itemScale = 0.3
            } else {
                dragOffset = CGSize(width: panCenter.x, height: panCenter.y)
                itemScale = 0.3
            }
        }

        let score = inTarget ? 100 : 50
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
                            colors: [Color(white: 0.85), Color(white: 0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 200, height: 140)

                // Ingredients in bowl
                Text("🥗")
                    .font(.AppTheme.rounded(size: 50))
                    .rotationEffect(.degrees(Double(spoonAngle) * 2))

                // Spoon
                Text("🥄")
                    .font(.AppTheme.rounded(size: 40))
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
                .frame(height: 12)

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                    .fill(Color(white: 0.3))
                    .frame(width: 160, height: 100)

                // Falling particles
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: 4, height: 4)
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
            VStack(spacing: 4) {
                Text(item.emoji)
                    .font(.AppTheme.rounded(size: 40))
                    .scaleEffect(done ? 0.8 : 1.0)
                    .opacity(done ? 0.5 : 1.0)

                Text(item.displayName)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)

                // Tap dots
                HStack(spacing: 3) {
                    ForEach(0..<tapsPerItem, id: \.self) { i in
                        Circle()
                            .fill(i < count ? Color.AppTheme.sage : Color.AppTheme.parchment)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.smallCornerRadius)
        }
        .buttonStyle(.plain)
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
        withAnimation(.easeIn(duration: 0.6)) {
            for i in max(0, particles.count - 5)..<particles.count {
                particles[i].y = CGFloat.random(in: -10...20)
            }
        }
    }

    private func checkCompletion() {
        let allDone = items.allSatisfy { (tapCounts[$0.rawValue] ?? 0) >= tapsPerItem }
        if allDone {
            isDone = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.AppTheme.goldenWheat.opacity(0.6))
                            .frame(width: 16, height: 90)
                            .offset(x: CGFloat(i * 18 - 36))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Veggie image
                Image(vegetable.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
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
                .frame(height: 12)

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
            withAnimation(.easeOut(duration: 0.3)) {
                peelLayers[swipeCount] = false
            }
        }
        swipeCount += 1
        totalAccuracy += accuracy

        if swipeCount >= targetSwipes {
            isDone = true
            let avgAccuracy = totalAccuracy / CGFloat(targetSwipes)
            let score = Int(avgAccuracy * 100)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Text("🔥")
                            .font(.AppTheme.rounded(size: 24))
                            .scaleEffect(flameScale)
                    }
                }
                .offset(y: 50)

                // Pan
                Ellipse()
                    .fill(Color(white: 0.3))
                    .frame(width: 150, height: 100)

                Text("🍳")
                    .font(.AppTheme.rounded(size: 50))
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
                            .frame(width: 16, height: 16)
                            .shadow(radius: 2)
                            .offset(x: geo.size.width * fraction - 8)
                    }
                }
                .frame(height: 20)

                Text(timerText)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .padding(.horizontal, AppSpacing.lg)

            // Done button
            if !isDone {
                Button {
                    finishCooking()
                } label: {
                    Text("Done!")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .frame(width: 120)
                        .padding(.vertical, AppSpacing.sm)
                        .background(elapsed >= greenStart ? Color.AppTheme.sage : Color.AppTheme.sepia.opacity(0.3))
                        .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .buttonStyle(BouncyButtonStyle())
            }

            Text("Tap Done when the timer reaches the green zone!")
                .font(.AppTheme.callout)
                .foregroundColor(Color.AppTheme.sepia)

            Spacer()
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private var timerText: String {
        let remaining = max(0, CGFloat(totalSeconds) - elapsed)
        return String(format: "%.1fs", remaining)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1
            // Flame animation
            flameScale = 1.0 + CGFloat.random(in: -0.1...0.1)

            if elapsed >= CGFloat(totalSeconds) + 2 {
                // Auto-finish if they wait too long
                finishCooking()
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                    .frame(width: 300, height: 240)

                // Veggie in the sink — gets cleaner with each tap
                ZStack {
                    // The veggie
                    Image(vegetable.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .scaleEffect(vegScale)
                        .rotationEffect(.degrees(vegRotation))

                    // Dirt overlay (brown tint that fades as you wash)
                    Circle()
                        .fill(Color.AppTheme.warmKhaki.opacity(dirtOpacity))
                        .frame(width: 85, height: 85)
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
                        .font(.system(size: splash.size))
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
                            .animation(.spring(response: 0.3), value: cleanProgress)
                    }
                }
                .frame(height: 12)

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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3)) {
                vegY = 10
            }
        }
        .onDisappear { sinkTimer?.invalidate() }
    }

    private func startSinkAnimation() {
        sinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 8.0, repeats: true) { _ in
            sinkFrame = (sinkFrame % totalSinkFrames) + 1
        }
    }

    private func handleTap() {
        tapCount += 1
        Haptic.impact(.soft) // water splash feel

        // Veggie bounces and rotates (like scrubbing)
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            vegScale = 0.85
            vegRotation = Double.random(in: -15...15)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                vegScale = 1.0
                vegRotation = 0
            }
        }

        // Dirt fades away with each tap
        withAnimation(.easeOut(duration: 0.3)) {
            dirtOpacity = max(0, 0.5 - (Double(tapCount) / Double(targetTaps)) * 0.5)
        }

        // Shine appears as veggie gets cleaner
        withAnimation(.easeIn(duration: 0.3)) {
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
        withAnimation(.easeOut(duration: 0.4)) {
            if let idx = splashes.firstIndex(where: { $0.id == splash.id }) {
                splashes[idx].y -= 30
                splashes[idx].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                shineOpacity = 1.0
                vegScale = 1.15
                dirtOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
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
    @State private var eggParts: CGFloat = 0 // 0→1
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
                        .frame(width: 200, height: 200)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Whole egg (using farm_eggs asset)
                    ZStack {
                        Image("farm_eggs")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)

                        // Crack lines appear with each tap
                        if tapCount > 0 {
                            ForEach(0..<tapCount, id: \.self) { i in
                                Rectangle()
                                    .fill(Color.AppTheme.sepia.opacity(0.6))
                                    .frame(width: 2, height: 25)
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
            HStack(spacing: 4) {
                ForEach(0..<targetTaps, id: \.self) { i in
                    Circle()
                        .fill(i < tapCount ? Color.AppTheme.sage : Color.AppTheme.parchment)
                        .frame(width: 12, height: 12)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                cracked = true
            }
            isDone = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 8, y: 4)

                // Sparkles
                ForEach(sparkles) { sparkle in
                    Image(systemName: "sparkle")
                        .font(.system(size: sparkle.size))
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
                        .animation(.easeOut(duration: 0.2), value: progress)
                }
            }
            .frame(height: 12)
            .padding(.horizontal, AppSpacing.lg)

            if !isDone {
                Button {
                    handleTap()
                } label: {
                    Text("Plate it up!")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .buttonStyle(BouncyButtonStyle())
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
        withAnimation(.easeOut(duration: 1.0)) {
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
