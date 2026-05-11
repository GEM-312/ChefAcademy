//
//  PlotView.swift
//  ChefAcademy
//
//  An individual garden plot with interactive plant care:
//  - Empty: tap to plant
//  - Growing: progress bar + small veggie
//  - Ready: full veggie + harvest badge
//  - Needs Water: HOLD to water (watering can animates)
//  - Needs Weeding: SWIPE UP to pull weeds
//  - Has Bugs: TAP bugs, ladybugs fly in
//

import SwiftUI

// MARK: - Plot View

struct PlotView: View {

    let plot: GardenPlot
    let onTap: () -> Void
    let onHarvest: () -> Void
    let onCareComplete: () -> Void
    var rewardLabel: String = "+2 XP"

    @State private var isAnimating = false

    // Watering state
    @State private var isWatering = false
    @State private var waterProgress: CGFloat = 0
    @State private var waterTimer: Timer?
    @State private var showWateringCan = false
    @State private var waterDropY: CGFloat = -20

    // Weeding state
    @State private var weedOffsets: [CGFloat] = [0, 0, 0]
    @State private var weedsRemoved: [Bool] = [false, false, false]
    @State private var currentWeedDrag: CGFloat = 0

    // Bug rescue state
    @State private var bugsRescued: [Bool] = [false, false, false]
    @State private var ladybugOffsets: [CGFloat] = [100, 100, 100]

    // Completion
    @State private var xpRewardVisible = false

    var body: some View {
        ZStack {
            plotContent
                .frame(width: 100, height: 110)

            // XP reward floating text
            if xpRewardVisible {
                Text(rewardLabel)
                    .font(.AppTheme.rounded(size: 12, weight: .bold))
                    .foregroundColor(Color.AppTheme.goldenWheat)
                    .offset(y: -60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            if plot.state == .ready {
                withAnimation(AnimationConstants.revealSlow.repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
        .onChange(of: plot.state) { _, newState in
            if newState == .ready {
                withAnimation(AnimationConstants.revealSlow.repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            } else {
                isAnimating = false
            }
            // Reset care states when plot state changes
            resetCareStates()
        }
        .onDisappear {
            waterTimer?.invalidate()
            waterTimer = nil
        }
    }

    // MARK: - Plot Content

    @ViewBuilder
    var plotContent: some View {
        switch plot.state {
        case .empty:
            emptyPlot
                .onTapGesture { onTap() }
        case .growing:
            growingPlot
        case .ready:
            readyPlot
                .onTapGesture { onHarvest() }
        case .needsWater:
            wateringPlot
        case .needsWeeding:
            weedingPlot
        case .hasBugs:
            bugRescuePlot
        }
    }

    // MARK: - Empty Plot

    var emptyPlot: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.7))
                    .frame(width: 70, height: 70)

                Circle()
                    .strokeBorder(
                        Color.AppTheme.sepia.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .frame(width: 70, height: 70)

                Image(systemName: "plus")
                    .font(.AppTheme.rounded(size: 24, weight: .medium))
                    .foregroundColor(Color.AppTheme.sage)
            }

            Text("Plant")
                .font(.AppTheme.rounded(size: 11, weight: .medium))
                .foregroundColor(Color.AppTheme.sepia)
        }
    }

    // MARK: - Growing Plot

    var growingPlot: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.85))
                    .frame(width: 80, height: 80)

                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .scaleEffect(0.6 + (plot.growthProgress * 0.4))
                        .opacity(0.5 + (plot.growthProgress * 0.5))
                }
            }

            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.AppTheme.parchment)
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.AppTheme.sage)
                            .frame(width: geo.size.width * plot.growthProgress, height: 6)
                    }
                }
                .frame(width: 70, height: 6)

                Text("\(Int(plot.growthProgress * 100))%")
                    .font(.AppTheme.rounded(size: 9, weight: .semibold))
                    .foregroundColor(Color.AppTheme.sepia)
            }
        }
    }

    // MARK: - Ready Plot

    var readyPlot: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.9))
                    .frame(width: 85, height: 85)

                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 65, height: 65)
                        .scaleEffect(isAnimating ? 1.08 : 1.0)
                }

                Text("✨")
                    .font(.AppTheme.captionLarge)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .offset(x: -40, y: -30)

                Text("✨")
                    .font(.AppTheme.microLarge)
                    .opacity(isAnimating ? 0.3 : 1.0)
                    .offset(x: 38, y: -25)
            }

            Text("Harvest!")
                .font(.AppTheme.rounded(size: 10, weight: .bold))
                .foregroundColor(Color.AppTheme.goldenWheat)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.AppTheme.warmCream.opacity(0.9))
                .cornerRadius(AppSpacing.pillCornerRadius)
        }
    }

    // MARK: - Watering Plot (HOLD to water)

    var wateringPlot: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.7))
                    .frame(width: 80, height: 80)

                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(isWatering ? 0 : -5))
                        .opacity(0.5 + (Double(waterProgress) * 0.5))
                        .scaleEffect(0.7 + (waterProgress * 0.3))
                }

                // Watering can appears when holding
                if showWateringCan {
                    Text("🚿")
                        .font(.AppTheme.rounded(size: 24))
                        .offset(x: 25, y: -35)
                        .transition(.scale.combined(with: .opacity))
                }

                // Water drops
                if isWatering {
                    ForEach(0..<3, id: \.self) { i in
                        Text("💧")
                            .font(.AppTheme.rounded(size: CGFloat(10 + i * 2)))
                            .offset(
                                x: CGFloat([-10, 5, 15][i]),
                                y: waterDropY + CGFloat(i * 8)
                            )
                            .opacity(0.7)
                    }
                }

                // Progress ring
                Circle()
                    .trim(from: 0, to: waterProgress)
                    .stroke(Color.AppTheme.sage, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 85, height: 85)
                    .rotationEffect(.degrees(-90))
            }

            Text(isWatering ? "Watering..." : "Hold me!")
                .font(.AppTheme.rounded(size: 10, weight: .bold))
                .foregroundColor(Color.AppTheme.sage)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isWatering { startWatering() }
                }
                .onEnded { _ in
                    stopWatering()
                }
        )
    }

    // MARK: - Weeding Plot (SWIPE UP to pull)

    var weedingPlot: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.7))
                    .frame(width: 80, height: 80)

                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .opacity(0.7)
                }

                // Weeds — swipe up to remove
                ForEach(0..<3, id: \.self) { i in
                    if !weedsRemoved[i] {
                        Text("🌿")
                            .font(.AppTheme.rounded(size: [14, 12, 10][i]))
                            .offset(
                                x: [-28, 25, -5][i],
                                y: [20, 22, 30][i] + weedOffsets[i]
                            )
                            .opacity(weedOffsets[i] < -30 ? 0 : 1)
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height < 0 {
                            currentWeedDrag = value.translation.height
                            // Move the first non-removed weed
                            if let idx = weedsRemoved.firstIndex(of: false) {
                                weedOffsets[idx] = value.translation.height
                            }
                        }
                    }
                    .onEnded { value in
                        if let idx = weedsRemoved.firstIndex(of: false) {
                            if value.translation.height < -40 {
                                // Pulled out!
                                withAnimation(AnimationConstants.fadeMedium) {
                                    weedOffsets[idx] = -100
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    weedsRemoved[idx] = true
                                    checkWeedingComplete()
                                }
                            } else {
                                // Snap back
                                withAnimation(AnimationConstants.springQuick) {
                                    weedOffsets[idx] = 0
                                }
                            }
                        }
                        currentWeedDrag = 0
                    }
            )

            let remaining = weedsRemoved.filter { !$0 }.count
            Text(remaining > 0 ? "Swipe up! (\(remaining) left)" : "Clean!")
                .font(.AppTheme.rounded(size: 10, weight: .bold))
                .foregroundColor(Color.AppTheme.sage)
        }
    }

    // MARK: - Bug Rescue Plot (TAP each bug)

    var bugRescuePlot: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.7))
                    .frame(width: 80, height: 80)

                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 55, height: 55)
                        .opacity(0.7)
                }

                // Bugs — tap to rescue
                ForEach(0..<3, id: \.self) { i in
                    if !bugsRescued[i] {
                        Text("🐛")
                            .font(.AppTheme.rounded(size: [12, 10, 11][i]))
                            .offset(
                                x: [-20, 22, 5][i],
                                y: [-15, 5, 25][i]
                            )
                            .onTapGesture { rescueBug(index: i) }
                    }
                }

                // Ladybugs flying in
                ForEach(0..<3, id: \.self) { i in
                    if bugsRescued[i] {
                        Text("🐞")
                            .font(.AppTheme.captionLarge)
                            .offset(
                                x: ladybugOffsets[i] == 0 ? [-20, 22, 5][i] : ladybugOffsets[i],
                                y: [-15, 5, 25][i]
                            )
                            .opacity(ladybugOffsets[i] == 0 ? 0.8 : 0)
                    }
                }
            }

            let remaining = bugsRescued.filter { !$0 }.count
            Text(remaining > 0 ? "Tap bugs! (\(remaining) left)" : "Rescued!")
                .font(.AppTheme.rounded(size: 10, weight: .bold))
                .foregroundColor(Color.AppTheme.terracotta)
        }
    }

    // MARK: - Watering Actions

    private func startWatering() {
        isWatering = true
        withAnimation(AnimationConstants.springQuick) {
            showWateringCan = true
        }
        // Animate water drops
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            waterDropY = 10
        }

        waterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                waterProgress += 0.015
                if waterProgress >= 1.0 {
                    completeWatering()
                }
            }
        }
    }

    private func stopWatering() {
        isWatering = false
        waterTimer?.invalidate()
        waterTimer = nil
        withAnimation(AnimationConstants.springQuick) {
            showWateringCan = false
        }
        // Drain a bit if not complete
        if waterProgress < 1.0 {
            withAnimation(AnimationConstants.fadeMedium) {
                waterProgress = max(0, waterProgress - 0.05)
            }
        }
    }

    private func completeWatering() {
        waterTimer?.invalidate()
        waterTimer = nil
        isWatering = false
        showXPBadge()
        onCareComplete()
    }

    // MARK: - Weeding Actions

    private func checkWeedingComplete() {
        if weedsRemoved.allSatisfy({ $0 }) {
            showXPBadge()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onCareComplete()
            }
        }
    }

    // MARK: - Bug Rescue Actions

    private func rescueBug(index: Int) {
        guard !bugsRescued[index] else { return }

        // Ladybug flies in
        withAnimation(AnimationConstants.fadeMedium) {
            ladybugOffsets[index] = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            bugsRescued[index] = true

            // Check if all rescued
            if bugsRescued.allSatisfy({ $0 }) {
                showXPBadge()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onCareComplete()
                }
            }
        }
    }

    // MARK: - Reward

    private func showXPBadge() {
        withAnimation(AnimationConstants.springMedium) {
            xpRewardVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(AnimationConstants.fadeMedium) {
                xpRewardVisible = false
            }
        }
    }

    // MARK: - Reset

    private func resetCareStates() {
        waterProgress = 0
        isWatering = false
        showWateringCan = false
        waterDropY = -20
        weedOffsets = [0, 0, 0]
        weedsRemoved = [false, false, false]
        bugsRescued = [false, false, false]
        ladybugOffsets = [100, 100, 100]
    }
}

// MARK: - Plot Button Style

struct PlotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(AnimationConstants.springQuick, value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Empty") {
    PlotView(plot: GardenPlot(id: 0), onTap: {}, onHarvest: {}, onCareComplete: {})
}

#Preview("Needs Water") {
    let plot = {
        var p = GardenPlot(id: 0)
        p.plant(.tomato)
        p.pauseForWater()
        return p
    }()
    PlotView(plot: plot, onTap: {}, onHarvest: {}, onCareComplete: {})
}

#Preview("Needs Weeding") {
    let plot = {
        var p = GardenPlot(id: 0)
        p.plant(.carrot)
        p.triggerWeeds()
        return p
    }()
    PlotView(plot: plot, onTap: {}, onHarvest: {}, onCareComplete: {})
}

#Preview("Has Bugs") {
    let plot = {
        var p = GardenPlot(id: 0)
        p.plant(.broccoli)
        p.triggerBugs()
        return p
    }()
    PlotView(plot: plot, onTap: {}, onHarvest: {}, onCareComplete: {})
}
