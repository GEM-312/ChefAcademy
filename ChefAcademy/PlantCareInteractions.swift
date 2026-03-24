//
//  PlantCareInteractions.swift
//  ChefAcademy
//
//  Interactive plant care gestures:
//  - Watering: tap and hold, water fills up
//  - Weeding: swipe up on each weed to pull it
//  - Bug rescue: tap each bug, ladybug flies in
//
//  These replace the simple "tap to fix" with engaging mini-interactions.
//

import SwiftUI

// MARK: - Plant Care Overlay (Router)

/// Shows the appropriate care interaction based on plot state.
/// Presented as a fullScreenCover from GardenView.
struct PlantCareOverlay: View {
    let plotIndex: Int
    let careType: PlotState  // .needsWater, .needsWeeding, or .hasBugs
    let vegetable: VegetableType
    let onComplete: () -> Void
    @EnvironmentObject var gameState: GameState

    var body: some View {
        ZStack {
            // Dim background
            Color.AppTheme.darkBrown.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { } // Block taps through

            VStack {
                Spacer()

                switch careType {
                case .needsWater:
                    WateringInteraction(vegetable: vegetable, onComplete: {
                        gameState.gardenPlots[plotIndex].water()
                        gameState.gardenPlots[plotIndex].hasWatered = true
                        gameState.addXP(2)
                        onComplete()
                    })
                case .needsWeeding:
                    WeedingInteraction(vegetable: vegetable, onComplete: {
                        gameState.gardenPlots[plotIndex].weed()
                        gameState.addXP(2)
                        onComplete()
                    })
                case .hasBugs:
                    BugRescueInteraction(vegetable: vegetable, onComplete: {
                        gameState.gardenPlots[plotIndex].releaseLadybugs()
                        gameState.addXP(2)
                        onComplete()
                    })
                default:
                    EmptyView()
                }

                Spacer()
            }
        }
    }
}

// MARK: - Watering Interaction (Tap & Hold)

struct WateringInteraction: View {
    let vegetable: VegetableType
    let onComplete: () -> Void

    @State private var isHolding = false
    @State private var waterProgress: CGFloat = 0
    @State private var waterDrops: [WaterDrop] = []
    @State private var plantScale: CGFloat = 0.7
    @State private var plantOpacity: Double = 0.5
    @State private var completed = false
    @State private var holdTimer: Timer?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Pip tip
            PipJourneyMessage(
                message: completed ? "Great watering! Your plant is happy again!" : "Hold to water your plant!",
                pose: completed ? "pip_celebrating" : "pip_cooking"
            )
            .padding(.horizontal, AppSpacing.md)

            // Plant + water area
            ZStack {
                // Background card
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.AppTheme.warmCream)
                    .frame(width: 280, height: 320)
                    .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 12, y: 6)

                VStack(spacing: AppSpacing.md) {
                    // Plant image
                    ZStack {
                        Image(vegetable.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .scaleEffect(plantScale)
                            .opacity(plantOpacity)
                            .rotationEffect(.degrees(completed ? 0 : -5))

                        // Water drops falling
                        ForEach(waterDrops) { drop in
                            Text("💧")
                                .font(.system(size: drop.size))
                                .offset(x: drop.x, y: drop.y)
                                .opacity(drop.opacity)
                        }
                    }

                    // Progress bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.AppTheme.parchment)
                            .frame(width: 200, height: 12)

                        Capsule()
                            .fill(Color.AppTheme.sage)
                            .frame(width: 200 * waterProgress, height: 12)
                            .animation(.linear(duration: 0.1), value: waterProgress)
                    }

                    // Hold button
                    if !completed {
                        Text(isHolding ? "Watering..." : "Hold here!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .frame(width: 200)
                            .padding(.vertical, AppSpacing.md)
                            .background(isHolding ? Color.AppTheme.sage : Color.AppTheme.goldenWheat)
                            .cornerRadius(16)
                            .scaleEffect(isHolding ? 0.95 : 1.0)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !isHolding { startWatering() }
                                    }
                                    .onEnded { _ in
                                        stopWatering()
                                    }
                            )
                    } else {
                        // Done!
                        HStack(spacing: 6) {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(Color.AppTheme.goldenWheat)
                            Text("+2 XP")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
    }

    private func startWatering() {
        isHolding = true
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            waterProgress += 0.02
            spawnDrop()

            // Revive plant as water fills
            withAnimation(.easeOut(duration: 0.1)) {
                plantScale = 0.7 + (waterProgress * 0.3)
                plantOpacity = 0.5 + (waterProgress * 0.5)
            }

            if waterProgress >= 1.0 {
                completeWatering()
            }
        }
    }

    private func stopWatering() {
        isHolding = false
        holdTimer?.invalidate()
        holdTimer = nil
        // Water drains slowly if not finished
        if !completed && waterProgress > 0 {
            withAnimation(.easeOut(duration: 0.5)) {
                waterProgress = max(0, waterProgress - 0.1)
            }
        }
    }

    private func completeWatering() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            completed = true
            plantScale = 1.0
            plantOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }

    private func spawnDrop() {
        let drop = WaterDrop(
            x: CGFloat.random(in: -40...40),
            y: CGFloat.random(in: -60...(-20)),
            size: CGFloat.random(in: 10...16),
            opacity: 0.8
        )
        waterDrops.append(drop)

        // Animate drop falling
        withAnimation(.easeIn(duration: 0.5)) {
            if let idx = waterDrops.firstIndex(where: { $0.id == drop.id }) {
                waterDrops[idx].y += 80
                waterDrops[idx].opacity = 0
            }
        }

        // Clean up old drops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            waterDrops.removeAll { $0.opacity <= 0 }
        }
    }
}

struct WaterDrop: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

// MARK: - Weeding Interaction (Swipe Up)

struct WeedingInteraction: View {
    let vegetable: VegetableType
    let onComplete: () -> Void

    @State private var weeds: [WeedItem] = [
        WeedItem(x: -35, y: 25, rotation: -15),
        WeedItem(x: 30, y: 30, rotation: 10),
        WeedItem(x: -5, y: 35, rotation: 5),
    ]
    @State private var completed = false
    @State private var plantScale: CGFloat = 0.7

    private var weedsRemaining: Int { weeds.filter { !$0.removed }.count }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            PipJourneyMessage(
                message: completed ? "All weeds gone! Your plant can breathe now!" : "Swipe up on each weed to pull it out!",
                pose: completed ? "pip_celebrating" : "pip_cooking"
            )
            .padding(.horizontal, AppSpacing.md)

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.AppTheme.warmCream)
                    .frame(width: 280, height: 320)
                    .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 12, y: 6)

                VStack(spacing: AppSpacing.sm) {
                    // Plant + weeds
                    ZStack {
                        // Plant
                        Image(vegetable.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .scaleEffect(plantScale)
                            .opacity(completed ? 1.0 : 0.6)

                        // Weeds — swipeable
                        ForEach($weeds) { $weed in
                            if !weed.removed {
                                Text("🌿")
                                    .font(.system(size: 28))
                                    .rotationEffect(.degrees(weed.rotation))
                                    .offset(x: weed.x, y: weed.y + weed.dragOffset)
                                    .opacity(weed.fadeOut ? 0 : 1)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                // Only allow upward swipes
                                                if value.translation.height < 0 {
                                                    weed.dragOffset = value.translation.height
                                                }
                                            }
                                            .onEnded { value in
                                                if value.translation.height < -50 {
                                                    // Pulled out!
                                                    pullWeed(id: weed.id)
                                                } else {
                                                    // Snap back
                                                    withAnimation(.spring(response: 0.3)) {
                                                        weed.dragOffset = 0
                                                    }
                                                }
                                            }
                                    )
                            }
                        }
                    }
                    .frame(height: 180)

                    // Counter
                    if !completed {
                        Text("\(weedsRemaining) weed\(weedsRemaining == 1 ? "" : "s") left")
                            .font(.AppTheme.callout)
                            .foregroundColor(Color.AppTheme.sepia)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(Color.AppTheme.goldenWheat)
                            Text("+2 XP")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
    }

    private func pullWeed(id: UUID) {
        guard let idx = weeds.firstIndex(where: { $0.id == id }) else { return }

        // Fly up + fade
        withAnimation(.easeOut(duration: 0.3)) {
            weeds[idx].dragOffset = -150
            weeds[idx].fadeOut = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            weeds[idx].removed = true

            // Plant grows as weeds are removed
            let remaining = weeds.filter { !$0.removed }.count
            withAnimation(.spring(response: 0.4)) {
                plantScale = 0.7 + (CGFloat(3 - remaining) / 3.0) * 0.3
            }

            if remaining == 0 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    completed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onComplete()
                }
            }
        }
    }
}

struct WeedItem: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    var dragOffset: CGFloat = 0
    var fadeOut: Bool = false
    var removed: Bool = false
}

// MARK: - Bug Rescue Interaction (Tap Bugs)

struct BugRescueInteraction: View {
    let vegetable: VegetableType
    let onComplete: () -> Void

    @State private var bugs: [BugItem] = [
        BugItem(x: -25, y: -15, emoji: "🐛"),
        BugItem(x: 20, y: 10, emoji: "🐛"),
        BugItem(x: -10, y: 25, emoji: "🐛"),
    ]
    @State private var ladybugs: [LadybugFly] = []
    @State private var completed = false
    @State private var plantScale: CGFloat = 0.7

    private var bugsRemaining: Int { bugs.filter { !$0.rescued }.count }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            PipJourneyMessage(
                message: completed ? "Ladybugs to the rescue! Your plant is safe!" : "Tap each bug — ladybugs will come help!",
                pose: completed ? "pip_celebrating" : "pip_excited"
            )
            .padding(.horizontal, AppSpacing.md)

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.AppTheme.warmCream)
                    .frame(width: 280, height: 320)
                    .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 12, y: 6)

                VStack(spacing: AppSpacing.sm) {
                    ZStack {
                        // Plant
                        Image(vegetable.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .scaleEffect(plantScale)
                            .opacity(completed ? 1.0 : 0.6)

                        // Aphid bugs — tappable
                        ForEach(bugs) { bug in
                            if !bug.rescued {
                                Text(bug.emoji)
                                    .font(.system(size: 22))
                                    .offset(x: bug.x + bug.shakeOffset, y: bug.y)
                                    .onTapGesture {
                                        rescueBug(id: bug.id)
                                    }
                                    .onAppear {
                                        // Wiggle the bugs
                                        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                                            if let idx = bugs.firstIndex(where: { $0.id == bug.id }) {
                                                bugs[idx].shakeOffset = CGFloat.random(in: -3...3)
                                            }
                                        }
                                    }
                            }
                        }

                        // Ladybugs flying in
                        ForEach(ladybugs) { ladybug in
                            Text("🐞")
                                .font(.system(size: 20))
                                .offset(x: ladybug.x, y: ladybug.y)
                                .opacity(ladybug.opacity)
                        }
                    }
                    .frame(height: 180)

                    // Counter
                    if !completed {
                        Text("\(bugsRemaining) bug\(bugsRemaining == 1 ? "" : "s") left")
                            .font(.AppTheme.callout)
                            .foregroundColor(Color.AppTheme.terracotta)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(Color.AppTheme.goldenWheat)
                            Text("+2 XP")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
    }

    private func rescueBug(id: UUID) {
        guard let idx = bugs.firstIndex(where: { $0.id == id }) else { return }

        let bug = bugs[idx]

        // Ladybug flies in from the side
        var ladybug = LadybugFly(
            x: 140,  // Start from right edge
            y: CGFloat.random(in: -20...20),
            opacity: 1.0
        )
        ladybugs.append(ladybug)

        // Animate ladybug flying to the bug
        withAnimation(.easeIn(duration: 0.4)) {
            if let lIdx = ladybugs.firstIndex(where: { $0.id == ladybug.id }) {
                ladybugs[lIdx].x = bug.x
                ladybugs[lIdx].y = bug.y
            }
        }

        // Bug disappears after ladybug arrives
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                bugs[idx].rescued = true
                // Ladybug fades
                if let lIdx = ladybugs.firstIndex(where: { $0.id == ladybug.id }) {
                    ladybugs[lIdx].opacity = 0
                }
            }

            // Plant recovers
            let remaining = bugs.filter { !$0.rescued }.count
            withAnimation(.spring(response: 0.4)) {
                plantScale = 0.7 + (CGFloat(3 - remaining) / 3.0) * 0.3
            }

            if remaining == 0 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    completed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onComplete()
                }
            }
        }
    }
}

struct BugItem: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let emoji: String
    var shakeOffset: CGFloat = 0
    var rescued: Bool = false
}

struct LadybugFly: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
}

// MARK: - Preview

#Preview("Watering") {
    WateringInteraction(vegetable: .tomato, onComplete: {})
}

#Preview("Weeding") {
    WeedingInteraction(vegetable: .carrot, onComplete: {})
}

#Preview("Bug Rescue") {
    BugRescueInteraction(vegetable: .broccoli, onComplete: {})
}
