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
    /// Gender of the active player — drives which kid character renders
    /// during the watering animation (girl from the left, boy from the right).
    var playerGender: Gender = .girl
    var rewardLabel: String = "+2 XP"
    /// Called when the care kid appears (true) or leaves (false), so the
    /// garden can draw this spot above its row neighbours while he's here.
    var onKidVisibleChange: (Bool) -> Void = { _ in }
    /// Show the job label ("Loosen!", "Water me!"…): only until the kid has
    /// done this job once (PipTutorial.gardenGuide).
    var showsGuide: Bool = true
    /// Garden tools: watering needs a full can (weeds and bugs are by hand).
    /// Loosening, planting and harvest taps are checked by GardenView.
    var heldTool: GardenTool? = nil
    var canIsFull: Bool = false
    /// The kid tried to water without a full can.
    var onNeedTool: (GardenTool) -> Void = { _ in }

    @State private var isAnimating = false

    // Watering state
    @State private var isWatering = false
    @State private var waterProgress: CGFloat = 0
    @State private var waterTimer: Timer?
    @State private var showWateringCan = false
    @State private var waterDropY: CGFloat = -20
    @State private var askedForTool = false   // one "need the can" per press
    @State private var soilBounce = false      // the spot hops when the fork loosens it

    // Soil effects (GardenEffects.swift). After a harvest the plot no longer
    // knows its veggie, so the last one is remembered for the pop.
    @State private var lastVegetable: VegetableType?
    @State private var showPuff = false
    @State private var puffID = 0
    @State private var harvestPopVeg: VegetableType?
    @State private var harvestPopID = 0
    @State private var seedDropping = false    // the new seed starts above the soil

    // Weeding state
    @State private var weedOffsets: [CGFloat] = [0, 0, 0]
    @State private var weedsRemoved: [Bool] = [false, false, false]
    @State private var currentWeedDrag: CGFloat = 0

    // Bug rescue state
    @State private var bugsRescued: [Bool] = [false, false, false]
    @State private var ladybugOffsets: [CGFloat] = [100, 100, 100]

    // Kid care animation (weed pull / bug rescue) — one play per action
    @State private var careAction: GardenCareAction?
    @State private var carePlayID = 0
    @State private var careHideTask: Task<Void, Never>?

    // Completion
    @State private var xpRewardVisible = false

    /// The kid shows while watering and during a weed / bug care animation.
    private var isKidVisible: Bool { isWatering || careAction != nil }

    var body: some View {
        ZStack {
            plotContent
                .frame(width: 100, height: 110)
                .overlay(alignment: playerGender == .girl ? .leading : .trailing) {
                    // Same side placement as the watering kid. Lives on the
                    // outer frame, not inside weedingPlot/bugRescuePlot, so the
                    // last pull keeps playing after the plot flips to growing.
                    if let careAction {
                        GardenCareCharacterView(gender: playerGender, action: careAction, playID: carePlayID)
                            .offset(x: playerGender == .girl ? -110 : 110)
                            .allowsHitTesting(false)
                            .transition(
                                .move(edge: playerGender == .girl ? .leading : .trailing)
                                    .combined(with: .opacity)
                            )
                    }
                }
                .animation(AnimationConstants.springQuick, value: careAction)

            // Soil effects: dirt puff (loosen / plant / harvest) and the
            // harvested veggie jumping out of the soil
            if showPuff {
                DirtPuffView().id(puffID)
            }
            if let veg = harvestPopVeg {
                VeggiePopView(imageName: veg.imageName, size: 65).id(harvestPopID)
            }

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
            lastVegetable = plot.vegetable
            if plot.state == .ready {
                withAnimation(AnimationConstants.revealSlow.repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
        .onChange(of: plot.vegetable) { _, veg in
            if let veg { lastVegetable = veg }
        }
        .onChange(of: plot.state) { oldState, newState in
            if oldState == .ready && newState == .empty { playHarvestPop() }
            if oldState == .empty && newState == .growing { playSeedDrop() }
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
        .onChange(of: isKidVisible) { _, visible in
            onKidVisibleChange(visible)
        }
        .onDisappear {
            waterTimer?.invalidate()
            waterTimer = nil
            careHideTask?.cancel()
            if isKidVisible { onKidVisibleChange(false) }
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

    /// Hard soil says "Loosen!" (fork first); loosened soil says "Plant" (shovel).
    var emptyPlot: some View {
        VStack(spacing: 6) {
            ZStack {
                Image(systemName: "plus")
                    .font(.AppTheme.rounded(size: 24, weight: .bold))
                    .foregroundColor(Color.AppTheme.leafGreen)
                    .padding(AppSpacing.xs)
                    .background(Circle().fill(Color.AppTheme.warmCream.opacity(0.9)))
            }

            if showsGuide {
                jobLabel(plot.soilLoosened ? "Plant" : "Loosen!", color: Color.AppTheme.leafGreen)
            }
        }
        .scaleEffect(soilBounce ? AnimationConstants.soilLoosenScale : 1)
        // The whole spot takes the tap, not just the "+" and its label
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onChange(of: plot.soilLoosened) { _, loosened in
            guard loosened else { return }
            puff()
            withAnimation(AnimationConstants.springBouncy) { soilBounce = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(AnimationConstants.springBouncy) { soilBounce = false }
            }
        }
    }

    // MARK: - Growing Plot

    var growingPlot: some View {
        VStack(spacing: 4) {
            ZStack {
                growthStageSprite
            }

            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.AppTheme.parchment)
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.AppTheme.leafGreen)
                            .frame(width: geo.size.width * plot.growthProgress, height: 6)
                    }
                }
                .frame(width: 70, height: 6)

                Text("\(Int(plot.growthProgress * 100))%")
                    .font(.AppTheme.rounded(size: 12, weight: .semibold))
                    .foregroundColor(Color.AppTheme.sepia)
            }
        }
    }

    // MARK: - Plot Art
    //
    // A plot is ONE planting spot. GardenView draws the soil row under each
    // group of three spots (10 rows × 3 spots, Marina 2026-10-08), so a spot
    // draws only its plant.

    /// Relative heights of growth stages 1–4, as a fraction of `plantHeight`.
    /// Not true-to-life scale: each step must read clearly to a 6-year-old.
    private static let growthStageHeights: [CGFloat] = [0.25, 0.40, 0.55, 0.75]
    private static let plantHeight: CGFloat = 80

    /// Seed → sprout → seedling → young plant, picked from growthProgress.
    /// Only for .growing — growthProgress reads 0 while a plot waits for care,
    /// so care states keep showing the vegetable instead.
    private var growthStageSprite: some View {
        let count = Self.growthStageHeights.count
        let stage = min(count - 1, Int(plot.growthProgress * Double(count)))
        let height = Self.plantHeight * Self.growthStageHeights[stage]
        return Image("garden_growth_stage_\(stage + 1)")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .offset(y: -height / 2)   // stand on the soil row instead of centring on it
            // Just planted: the seed falls into the soil (playSeedDrop)
            .offset(y: seedDropping ? -AnimationConstants.seedDropHeight : 0)
            .opacity(seedDropping ? 0 : 1)
    }

    // MARK: - Ready Plot

    var readyPlot: some View {
        VStack(spacing: 4) {
            ZStack {
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

            if showsGuide {
                jobLabel("Harvest!", color: Color.AppTheme.goldenWheat)
            }
        }
    }

    /// A spot's job word on a cream pill, so it reads on the dark soil.
    private func jobLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.AppTheme.rounded(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(AppSpacing.pillCornerRadius)
    }

    // MARK: - Watering Plot (HOLD to water)

    var wateringPlot: some View {
        VStack(spacing: 4) {
            ZStack {
                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(isWatering ? 0 : -5))
                        .scaleEffect(0.7 + (waterProgress * 0.3))   // grows as it drinks
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
                    .stroke(Color.AppTheme.leafGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 85, height: 85)
                    .rotationEffect(.degrees(-90))
            }

            if showsGuide {
                jobLabel(isWatering ? "Watering..." : "Water me!", color: Color.AppTheme.leafGreen)
            }
        }
        .overlay(alignment: playerGender == .girl ? .leading : .trailing) {
            // Kid character pours from the side — girl enters from the LEFT,
            // boy from the RIGHT. Particles flow diagonally toward the plot
            // center. Overlay is hit-test transparent so adjacent plot taps
            // still pass through.
            if isWatering {
                WaterPourCharacterView(gender: playerGender, isActive: isWatering)
                    .offset(x: playerGender == .girl ? -110 : 110)
                    .allowsHitTesting(false)
                    .transition(
                        .move(edge: playerGender == .girl ? .leading : .trailing)
                            .combined(with: .opacity)
                    )
            }
        }
        .animation(AnimationConstants.springQuick, value: isWatering)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isWatering, !askedForTool else { return }
                    if heldTool == .wateringCan && canIsFull {
                        startWatering()
                    } else {
                        askedForTool = true
                        onNeedTool(.wateringCan)
                    }
                }
                .onEnded { _ in
                    askedForTool = false
                    stopWatering()
                }
        )
    }

    // MARK: - Weeding Plot (SWIPE UP to pull)

    var weedingPlot: some View {
        VStack(spacing: 4) {
            ZStack {
                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                }

                // Weeds — swipe up to remove (the DragGesture below covers the
                // whole 80pt circle, so these glyphs just need to be visible).
                ForEach(0..<3, id: \.self) { i in
                    if !weedsRemoved[i] {
                        Text("🌿")
                            .font(.AppTheme.rounded(size: 28))
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
                                playCareAnimation(.pullWeed)
                                withAnimation(AnimationConstants.fadeMedium) {
                                    weedOffsets[idx] = -100
                                }
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(0.3))
                                    guard !Task.isCancelled else { return }
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
            if showsGuide {
                jobLabel(remaining > 0 ? "Swipe up! (\(remaining) left)" : "Clean!", color: Color.AppTheme.leafGreen)
            }
        }
    }

    // MARK: - Bug Rescue Plot (TAP each bug)

    var bugRescuePlot: some View {
        VStack(spacing: 4) {
            ZStack {
                if let veg = plot.vegetable {
                    Image(veg.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 55, height: 55)
                }

                // Bugs — tap to rescue. Glyph sits inside a ≥44pt frame so the
                // whole HIG-minimum area is tappable, not just the tiny emoji.
                ForEach(0..<3, id: \.self) { i in
                    if !bugsRescued[i] {
                        Text("🐛")
                            .font(.AppTheme.rounded(size: 30))
                            .frame(width: AppSpacing.minTapTarget, height: AppSpacing.minTapTarget)
                            .contentShape(Rectangle())
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
            // Far garden rows are drawn smaller, which can shrink a bug's
            // 44pt target below the HIG minimum. Tapping anywhere on the plot
            // rescues the next bug, so a small far-away bug is never hard to hit.
            .frame(width: AppSpacing.minTapTarget * 2, height: AppSpacing.minTapTarget * 2)
            .contentShape(Rectangle())
            .onTapGesture {
                if let next = bugsRescued.firstIndex(of: false) { rescueBug(index: next) }
            }

            let remaining = bugsRescued.filter { !$0 }.count
            if showsGuide {
                jobLabel(remaining > 0 ? "Tap bugs! (\(remaining) left)" : "Rescued!", color: Color.AppTheme.carrotOrange)
            }
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
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                onCareComplete()
            }
        }
    }

    // MARK: - Bug Rescue Actions

    private func rescueBug(index: Int) {
        guard !bugsRescued[index] else { return }
        playCareAnimation(.rescueBug)

        // Ladybug flies in
        withAnimation(AnimationConstants.fadeMedium) {
            ladybugOffsets[index] = 0
        }
        // Sequential: 0.3s for ladybug to land, then if all rescued, 0.5s more
        // before completing care. Single Task for the whole chain.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            bugsRescued[index] = true

            // Check if all rescued
            if bugsRescued.allSatisfy({ $0 }) {
                showXPBadge()
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                onCareComplete()
            }
        }
    }

    // MARK: - Kid Care Animation

    /// Slides the kid in (or replays if already showing), then removes them a
    /// beat after the one-shot play ends. Rapid taps restart the play and push
    /// the hide back, so the kid stays while the player keeps working.
    private func playCareAnimation(_ action: GardenCareAction) {
        careAction = action
        carePlayID += 1
        careHideTask?.cancel()
        careHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(GardenCareCharacterView.playDuration + 0.4))
            guard !Task.isCancelled else { return }
            careAction = nil
        }
    }

    // MARK: - Soil Effects

    /// A fresh dirt puff (a new id restarts its animation), hidden when done.
    private func puff() {
        puffID += 1
        showPuff = true
        let id = puffID
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.dirtPuffDuration))
            guard !Task.isCancelled, puffID == id else { return }
            showPuff = false
        }
    }

    /// Harvest: the veggie jumps out of the soil with a dirt puff.
    private func playHarvestPop() {
        guard let veg = lastVegetable else { return }
        harvestPopID += 1
        harvestPopVeg = veg
        puff()
        let id = harvestPopID
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.harvestPopDuration))
            guard !Task.isCancelled, harvestPopID == id else { return }
            harvestPopVeg = nil
        }
    }

    /// Planting: once the planting sheet has closed, the seed drops into the
    /// soil and dirt puffs where it lands.
    private func playSeedDrop() {
        seedDropping = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.seedDropDelay))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.springBouncy) { seedDropping = false }
            try? await Task.sleep(for: .seconds(AnimationConstants.seedLandDelay))
            guard !Task.isCancelled else { return }
            puff()
        }
    }

    // MARK: - Reward

    private func showXPBadge() {
        withAnimation(AnimationConstants.springMedium) {
            xpRewardVisible = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
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
