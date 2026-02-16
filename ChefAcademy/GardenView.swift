//
//  GardenView.swift
//  ChefAcademy
//
//  The Garden is where players GROW vegetables!
//  This is one of the 3 pillars: GROW -> COOK -> FEED
//
//  Now features a garden map background with plot spots overlaid!
//

import SwiftUI
import Combine  // Needed for Timer.publish

// MARK: - Selected Plot (for sheet(item:))

struct SelectedPlot: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Draggable Pip View
/// The player drags Pip around the garden to check on plants and harvest!
/// Pip only appears once something is planted.
/// Drag Pip over a READY plot to harvest it.
///
/// HOW TO TWEAK:
/// - pipSize: how big Pip is (default 55)
/// - harvestRadius: how close Pip needs to be to a plot to harvest (default 60)
/// - idlePosition: where Pip stands when not being dragged (bottom-center)
/// - Replace "pip_neutral" with a walking sprite image later!

struct DraggablePipView: View {
    let mapWidth: CGFloat
    let mapHeight: CGFloat
    let isVisible: Bool  // Only show when something is planted
    var isIPad: Bool = false  // Scale up for iPad

    /// Plot positions so Pip knows where the plots are
    /// Must match the plot positions in gardenMapSection!
    let plotPositions: [CGPoint]

    /// Which plots are ready to harvest (by index)
    let readyPlotIndices: [Int]

    /// Called when Pip reaches a ready plot — passes the plot index
    let onHarvestPlot: (Int) -> Void

    // ==========================================
    // TWEAK THESE:
    // ==========================================

    /// Pip's size — bigger on iPad
    private var pipSize: CGFloat { isIPad ? 80 : 55 }

    /// How close Pip needs to be to a plot to harvest — bigger on iPad
    private var harvestRadius: CGFloat { isIPad ? 100 : 60 }

    // ==========================================
    // STATE
    // ==========================================

    @State private var pipOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var idleBounce: Bool = false
    @State private var nearbyPlotIndex: Int? = nil
    @State private var showHarvestBurst: Bool = false
    @State private var facingRight: Bool = true

    /// Where Pip stands idle (bottom-center of map)
    private var idlePosition: CGPoint {
        CGPoint(x: mapWidth * 0.50, y: mapHeight * 0.90)
    }

    /// Pip's current center position based on idle + drag offset
    private var pipCenter: CGPoint {
        CGPoint(
            x: idlePosition.x + pipOffset.width,
            y: idlePosition.y + pipOffset.height
        )
    }

    var body: some View {
        ZStack {
            // Glow ring under Pip when near a harvestable plot
            if nearbyPlotIndex != nil {
                Circle()
                    .fill(Color.AppTheme.goldenWheat.opacity(0.3))
                    .frame(width: pipSize + 20, height: pipSize + 20)
                    .scaleEffect(showHarvestBurst ? 1.5 : 1.0)
                    .opacity(showHarvestBurst ? 0 : 0.6)
                    .position(pipCenter)
            }

            // Pip character
            Image("pip_neutral")  // <-- Replace with walking sprite later!
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: pipSize, height: pipSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            nearbyPlotIndex != nil
                            ? Color.AppTheme.goldenWheat
                            : Color.AppTheme.sage,
                            lineWidth: 2.5
                        )
                )
                .shadow(
                    color: isDragging ? Color.AppTheme.sage.opacity(0.4) : Color.black.opacity(0.2),
                    radius: isDragging ? 8 : 4,
                    x: 0,
                    y: isDragging ? 6 : 3
                )
                // Flip to face drag direction
                .scaleEffect(x: facingRight ? 1 : -1, y: 1)
                // Scale up slightly when dragging
                .scaleEffect(isDragging ? 1.1 : 1.0)
                // Idle bounce when not dragging
                .offset(y: (!isDragging && idleBounce) ? -4 : 0)
                .position(pipCenter)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true

                            // Update position
                            pipOffset = CGSize(
                                width: lastDragOffset.width + value.translation.width,
                                height: lastDragOffset.height + value.translation.height
                            )

                            // Flip Pip to face drag direction
                            if value.translation.width > 5 {
                                facingRight = true
                            } else if value.translation.width < -5 {
                                facingRight = false
                            }

                            // Check if near any ready plot
                            checkNearbyPlots()
                        }
                        .onEnded { _ in
                            isDragging = false
                            lastDragOffset = pipOffset

                            // If near a ready plot, harvest it!
                            if let plotIndex = nearbyPlotIndex {
                                triggerHarvest(plotIndex: plotIndex)
                            }
                        }
                )
                // Hint text
                .overlay(
                    Group {
                        if !isDragging && nearbyPlotIndex == nil {
                            Text("Drag me!")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.AppTheme.sage)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.AppTheme.warmCream.opacity(0.9))
                                .cornerRadius(6)
                                .offset(y: pipSize / 2 + 10)
                                .position(pipCenter)
                                .opacity(idleBounce ? 1.0 : 0.5)
                        }
                    }
                )
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            // Start idle bounce animation
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                idleBounce = true
            }
        }
    }

    // MARK: - Check Nearby Plots

    private func checkNearbyPlots() {
        var closestReady: Int? = nil
        var closestDist: CGFloat = .infinity

        for index in readyPlotIndices {
            guard index < plotPositions.count else { continue }
            let plotPos = plotPositions[index]
            let dist = distance(from: pipCenter, to: plotPos)

            if dist < harvestRadius && dist < closestDist {
                closestDist = dist
                closestReady = index
            }
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            nearbyPlotIndex = closestReady
        }
    }

    // MARK: - Trigger Harvest

    private func triggerHarvest(plotIndex: Int) {
        // Burst animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            showHarvestBurst = true
        }

        // Do the harvest
        onHarvestPlot(plotIndex)

        // Reset burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showHarvestBurst = false
            nearbyPlotIndex = nil
        }
    }

    // MARK: - Distance Helper

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// MARK: - Walking Pip View
/// Pip walks between waypoints when plants are growing, idles when garden is empty.
/// Drag Pip over a READY plot to harvest it (same as DraggablePipView).
///
/// Three modes:
/// - **idle**: pip_neutral with bounce, shown when nothing is growing
/// - **walking**: cycles through pip_walking_frame_XX at ~8fps, interpolates between waypoints
/// - **dragging**: user drags Pip to harvest, pauses walking

struct WalkingPipView: View {
    let mapWidth: CGFloat
    let mapHeight: CGFloat
    let isVisible: Bool
    var isIPad: Bool = false

    /// Absolute positions for each waypoint (from walk SceneItems)
    let waypoints: [CGPoint]

    /// Pip's idle position (from "pip" SceneItem)
    let idlePosition: CGPoint

    /// True when any plot is .growing
    let isGrowing: Bool

    /// Plot positions for harvest detection
    let plotPositions: [CGPoint]

    /// Which plots are ready to harvest
    let readyPlotIndices: [Int]

    /// Called when Pip reaches a ready plot
    let onHarvestPlot: (Int) -> Void

    // ==========================================
    // TWEAK THESE:
    // ==========================================

    private var pipSize: CGFloat { isIPad ? 80 : 55 }
    private var harvestRadius: CGFloat { isIPad ? 100 : 60 }

    /// How many points Pip moves per tick (1/30s)
    private let walkSpeed: CGFloat = 1.8

    private var pipDisplaySize: CGFloat { isIPad ? 160 : 110 }

    /// Walking frame names
    private let walkingFrames: [String] = (1...15).map {
        String(format: "pip_walking_frame_%02d", $0)
    }

    // ==========================================
    // STATE
    // ==========================================

    @State private var pipPosition: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var idleBounce: Bool = false
    @State private var nearbyPlotIndex: Int? = nil
    @State private var showHarvestBurst: Bool = false
    @State private var facingRight: Bool = true

    // Walking state
    @State private var currentWaypointIndex: Int = 0
    @State private var walkProgress: CGFloat = 0.0
    @State private var walkingFrameIndex: Int = 0
    @State private var tickCounter: Int = 0
    @State private var walkTimer: Timer? = nil
    @State private var wasGrowing: Bool = false

    /// Pip's display position (walk position or idle, plus drag offset)
    private var pipCenter: CGPoint {
        CGPoint(
            x: pipPosition.x + dragOffset.width,
            y: pipPosition.y + dragOffset.height
        )
    }

    var body: some View {
        ZStack {
            // Glow ring when near a harvestable plot
            if nearbyPlotIndex != nil {
                Circle()
                    .fill(Color.AppTheme.goldenWheat.opacity(0.3))
                    .frame(width: pipDisplaySize + 20, height: pipDisplaySize + 20)
                    .scaleEffect(showHarvestBurst ? 1.5 : 1.0)
                    .opacity(showHarvestBurst ? 0 : 0.6)
                    .position(pipCenter)
            }

            // Pip character
            Image(isGrowing && !isDragging ? walkingFrames[walkingFrameIndex] : "pip_neutral")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: pipDisplaySize, height: pipDisplaySize)
                .shadow(
                    color: isDragging ? Color.AppTheme.sage.opacity(0.4) : Color.black.opacity(0.2),
                    radius: isDragging ? 8 : 4,
                    x: 0,
                    y: isDragging ? 6 : 3
                )
                .scaleEffect(x: facingRight ? 1 : -1, y: 1)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                // Idle bounce when not walking and not dragging
                .offset(y: (!isDragging && !isGrowing && idleBounce) ? -4 : 0)
                .position(pipCenter)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation

                            // Flip Pip to face drag direction
                            if value.translation.width > 5 {
                                facingRight = true
                            } else if value.translation.width < -5 {
                                facingRight = false
                            }

                            checkNearbyPlots()
                        }
                        .onEnded { _ in
                            isDragging = false

                            // If near a ready plot, harvest it!
                            if let plotIndex = nearbyPlotIndex {
                                triggerHarvest(plotIndex: plotIndex)
                            }

                            // Snap back — reset drag offset, keep walk position
                            dragOffset = .zero
                        }
                )
                // Hint text
                .overlay(
                    Group {
                        if !isDragging && nearbyPlotIndex == nil && !isGrowing {
                            Text("Drag me!")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.AppTheme.sage)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.AppTheme.warmCream.opacity(0.9))
                                .cornerRadius(6)
                                .offset(y: pipDisplaySize / 2 + 10)
                                .position(pipCenter)
                                .opacity(idleBounce ? 1.0 : 0.5)
                        }
                    }
                )
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            pipPosition = idlePosition
            // Start idle bounce
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                idleBounce = true
            }
        }
        .onChange(of: isGrowing) { growing in
            if growing {
                startWalking()
            } else {
                stopWalking()
            }
        }
    }

    // MARK: - Walking Engine

    private func startWalking() {
        guard waypoints.count >= 2 else { return }
        guard walkTimer == nil else { return }

        // Start from nearest waypoint
        currentWaypointIndex = 0
        walkProgress = 0.0
        pipPosition = waypoints[0]

        walkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            guard !isDragging else { return }

            let fromIndex = currentWaypointIndex
            let toIndex = (currentWaypointIndex + 1) % waypoints.count
            let from = waypoints[fromIndex]
            let to = waypoints[toIndex]

            // Distance between waypoints
            let dx = to.x - from.x
            let dy = to.y - from.y
            let segmentLength = sqrt(dx * dx + dy * dy)
            guard segmentLength > 0 else { return }

            // Advance progress
            let progressPerTick = walkSpeed / segmentLength
            walkProgress += progressPerTick

            // Update facing direction based on horizontal movement
            if dx > 1 {
                facingRight = true
            } else if dx < -1 {
                facingRight = false
            }

            if walkProgress >= 1.0 {
                // Reached waypoint — advance to next
                walkProgress = 0.0
                currentWaypointIndex = toIndex
                pipPosition = to
            } else {
                // Interpolate position
                pipPosition = CGPoint(
                    x: from.x + dx * walkProgress,
                    y: from.y + dy * walkProgress
                )
            }

            // Advance walking frame every 4 ticks (~8fps at 30fps timer)
            tickCounter += 1
            if tickCounter >= 4 {
                tickCounter = 0
                walkingFrameIndex = (walkingFrameIndex + 1) % walkingFrames.count
            }
        }
    }

    private func stopWalking() {
        walkTimer?.invalidate()
        walkTimer = nil
        tickCounter = 0
        walkingFrameIndex = 0

        // Animate back to idle position
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            pipPosition = idlePosition
        }
    }

    // MARK: - Harvest Detection

    private func checkNearbyPlots() {
        var closestReady: Int? = nil
        var closestDist: CGFloat = .infinity

        for index in readyPlotIndices {
            guard index < plotPositions.count else { continue }
            let plotPos = plotPositions[index]
            let dist = distance(from: pipCenter, to: plotPos)

            if dist < harvestRadius && dist < closestDist {
                closestDist = dist
                closestReady = index
            }
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            nearbyPlotIndex = closestReady
        }
    }

    private func triggerHarvest(plotIndex: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            showHarvestBurst = true
        }

        onHarvestPlot(plotIndex)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showHarvestBurst = false
            nearbyPlotIndex = nil
        }
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// MARK: - Garden View
//
// This view shows a garden map background image with
// tappable plot spots positioned over the garden patches.
//

struct GardenView: View {

    // Access the shared game state (coins, seeds, plots, etc.)
    @EnvironmentObject var gameState: GameState
    @Environment(\.horizontalSizeClass) var sizeClass

    // Tab navigation binding — so we can switch to Kitchen after harvest
    @Binding var selectedTab: MainTabView.Tab

    // Adaptive: detect iPad
    private var isIPad: Bool { sizeClass != .compact }

    // @State is for LOCAL view state - things only this view cares about
    @State private var selectedPlotIndex: SelectedPlot?
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var suggestedRecipe: Recipe?
    @State private var showRecipeSuggestion = false

    // ==========================================
    // SCENE EDITOR: Set to true to drag plot positions!
    // Drag handles around, then copy printed values to code.
    // ==========================================
    @State private var editMode = false

    @State private var gardenSceneItems: [SceneItem] = [
        SceneItem(id: "plot0", label: "Plot 0", icon: "🌱", xPercent: 0.45, yPercent: 0.66),
        SceneItem(id: "plot1", label: "Plot 1", icon: "🌱", xPercent: 0.79, yPercent: 0.63),
        SceneItem(id: "plot2", label: "Plot 2", icon: "🌱", xPercent: 0.32, yPercent: 0.78),
        SceneItem(id: "plot3", label: "Plot 3", icon: "🌱", xPercent: 0.73, yPercent: 0.78),
        SceneItem(id: "plot4", label: "Plot 4", icon: "🌱", xPercent: 0.82, yPercent: 0.88),
        SceneItem(id: "pip", label: "Pip Idle", icon: "🦔", xPercent: 0.50, yPercent: 0.90),
        SceneItem(id: "walk0", label: "Walk 0", icon: "👣", xPercent: 0.25, yPercent: 0.88),
        SceneItem(id: "walk1", label: "Walk 1", icon: "👣", xPercent: 0.38, yPercent: 0.72),
        SceneItem(id: "walk2", label: "Walk 2", icon: "👣", xPercent: 0.60, yPercent: 0.65),
        SceneItem(id: "walk3", label: "Walk 3", icon: "👣", xPercent: 0.82, yPercent: 0.72),
        SceneItem(id: "walk4", label: "Walk 4", icon: "👣", xPercent: 0.75, yPercent: 0.90),
        SceneItem(id: "basket", label: "Basket", icon: "🧺", xPercent: 0.50, yPercent: 0.52),
    ]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width

                ZStack {
                    // MARK: - Garden Map Background
                    Color.AppTheme.cream
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {

                            // MARK: - Header (overlays the top of the map)
                            headerView
                                .padding(.top, AppSpacing.sm)
                                .padding(.bottom, AppSpacing.sm)

                            // MARK: - Garden Map with Plot Spots
                            gardenMapSection(screenWidth: screenWidth)

                            // MARK: - Bottom Panel: Seeds & Harvest
                            bottomPanel
                                .padding(.top, AppSpacing.md)

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // Planting sheet slides up when player taps an empty plot
        .sheet(item: $selectedPlotIndex) { selected in
            PlantingSheet(
                plotIndex: selected.index,
                onDismiss: { selectedPlotIndex = nil }
            )
            .environmentObject(gameState)
        }
        // Update growth progress every second
        .onReceive(timer) { _ in
            updateGrowthStates()
        }
        // Recipe suggestion popup after harvest
        .alert("Recipe Unlocked! 🍳", isPresented: $showRecipeSuggestion) {
            Button("Let's Cook!") {
                selectedTab = .kitchen
            }
            Button("Later", role: .cancel) { }
        } message: {
            if let recipe = suggestedRecipe {
                Text("You have all the ingredients for \(recipe.title)! Want to cook it now?")
            }
        }
    }

    // MARK: - Header View

    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Garden")
                    .font(isIPad ? .AppTheme.largeTitle : .AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text(gardenHint)
                    .font(isIPad ? .AppTheme.body : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }

            Spacer()

            // Edit mode toggle (Scene Editor - only visible in debug/dev builds)
            #if DEBUG
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    editMode.toggle()
                }
            } label: {
                Image(systemName: editMode ? "pencil.circle.fill" : "pencil.circle")
                    .font(.system(size: isIPad ? 24 : 20))
                    .foregroundColor(editMode ? .red : Color.AppTheme.lightSepia)
            }
            #endif

            // Coin display
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                    .font(.system(size: isIPad ? 18 : 14))
                Text("\(gameState.coins)")
                    .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, isIPad ? AppSpacing.md : AppSpacing.sm)
            .padding(.vertical, isIPad ? AppSpacing.sm : AppSpacing.xs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(20)
        }
        .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
    }

    // MARK: - Helper: get scene item position by ID

    func plotPos(for id: String, w: CGFloat, h: CGFloat) -> CGPoint {
        guard let item = gardenSceneItems.first(where: { $0.id == id }) else {
            return CGPoint(x: w * 0.5, y: h * 0.5)
        }
        return CGPoint(x: w * item.xPercent, y: h * item.yPercent)
    }

    // MARK: - Garden Map Section

    func gardenMapSection(screenWidth: CGFloat) -> some View {
        // The map image fills the width, plots are positioned on top using overlay
        Image("bg_garden")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .opacity(0.8)
            .overlay(
                GeometryReader { mapGeo in
                    let w = mapGeo.size.width
                    let h = mapGeo.size.height

                    if editMode {
                        // ==========================================
                        // EDIT MODE: Drag plot handles to reposition!
                        // ==========================================
                        SceneEditorOverlay(
                            mapWidth: w,
                            mapHeight: h,
                            items: $gardenSceneItems,
                            editMode: true
                        )
                    } else {
                        // ==========================================
                        // PLAY MODE: Normal garden with plots
                        // Positions come from gardenSceneItems
                        // ==========================================

                        // Plot positions from scene items
                        let plotPositions: [CGPoint] = [
                            plotPos(for: "plot0", w: w, h: h),
                            plotPos(for: "plot1", w: w, h: h),
                            plotPos(for: "plot2", w: w, h: h),
                            plotPos(for: "plot3", w: w, h: h),
                            plotPos(for: "plot4", w: w, h: h),
                        ]

                        // Plot spots (the garden patches)
                        gardenPlotSpot(index: 0)
                            .position(plotPositions[0])

                        gardenPlotSpot(index: 1)
                            .position(plotPositions[1])

                        gardenPlotSpot(index: 2)
                            .position(plotPositions[2])

                        gardenPlotSpot(index: 3)
                            .position(plotPositions[3])

                        gardenPlotSpot(index: 4)
                            .position(plotPositions[4])

                        // Walking Pip — walks between waypoints when plants grow!
                        let waypointPositions: [CGPoint] = (0...4).map { i in
                            plotPos(for: "walk\(i)", w: w, h: h)
                        }
                        let pipIdlePos = plotPos(for: "pip", w: w, h: h)
                        let anyGrowing = gameState.gardenPlots.contains(where: { $0.state == .growing })

                        WalkingPipView(
                            mapWidth: w,
                            mapHeight: h,
                            isVisible: gameState.gardenPlots.contains(where: { $0.state != .empty }),
                            isIPad: isIPad,
                            waypoints: waypointPositions,
                            idlePosition: pipIdlePos,
                            isGrowing: anyGrowing,
                            plotPositions: plotPositions,
                            readyPlotIndices: gameState.gardenPlots.indices.filter { gameState.gardenPlots[$0].state == .ready },
                            onHarvestPlot: { index in
                                harvestPlot(index: index)
                            }
                        )

                        // Harvest basket — shows collected veggies
                        if !gameState.harvestedIngredients.isEmpty {
                            let basketPos = plotPos(for: "basket", w: w, h: h)
                            BasketWithVeggiesView(
                                harvestedIngredients: gameState.harvestedIngredients,
                                basketSize: isIPad ? 350 : 280
                            )
                            .position(basketPos)
                        }
                    }
                }
            )
    }

    // MARK: - Individual Garden Plot Spot

    func gardenPlotSpot(index: Int) -> some View {
        Group {
            if index < gameState.gardenPlots.count {
                PlotView(
                    plot: gameState.gardenPlots[index],
                    onTap: {
                        handlePlotTap(index: index)
                    },
                    onHarvest: {
                        harvestPlot(index: index)
                    }
                )
                .frame(width: isIPad ? 160 : 100, height: isIPad ? 160 : 100)
                .scaleEffect(isIPad ? 1.4 : 1.0)
            }
        }
    }

    // MARK: - Bottom Panel (Seeds + Harvested)

    var bottomPanel: some View {
        VStack(spacing: AppSpacing.md) {
            // Pip's gardening tip
            PipGardenMessage()

            // Seed inventory
            seedInventorySection

            // Harvested veggies
            harvestedSection
        }
    }

    // MARK: - Seed Inventory Section

    var seedInventorySection: some View {
        VStack(alignment: .leading, spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
            Text("My Seeds")
                .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
                .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)

            if gameState.seeds.isEmpty {
                Text("No seeds! Visit the shop to buy some.")
                    .font(isIPad ? .AppTheme.headline : .AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
                        ForEach(gameState.seeds) { seed in
                            SeedBadge(seed: seed, isIPad: isIPad)
                        }
                    }
                    .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
                }
            }
        }
    }

    // MARK: - Harvested Section

    var harvestedSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
            Text("Harvested Veggies")
                .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
                .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)

            if gameState.harvestedIngredients.isEmpty {
                Text("Nothing harvested yet. Grow some veggies!")
                    .font(isIPad ? .AppTheme.headline : .AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
                        ForEach(gameState.harvestedIngredients) { ingredient in
                            IngredientBadge(ingredient: ingredient, isIPad: isIPad)
                        }
                    }
                    .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
                }
            }
        }
    }

    // MARK: - Actions

    func handlePlotTap(index: Int) {
        let plot = gameState.gardenPlots[index]

        switch plot.state {
        case .empty:
            // Open planting sheet — using sheet(item:) so it's always ready
            selectedPlotIndex = SelectedPlot(index: index)

        case .growing:
            // Can't do anything while growing
            break

        case .ready:
            // Harvest!
            harvestPlot(index: index)

        case .needsWater:
            // Future feature
            break
        }
    }

    func harvestPlot(index: Int) {
        guard gameState.gardenPlots[index].isReadyToHarvest,
              let vegType = gameState.gardenPlots[index].vegetable else { return }

        // Get the harvest yield
        let yield = gameState.gardenPlots[index].harvest()

        // Update the plot in gameState
        gameState.gardenPlots[index].vegetable = nil
        gameState.gardenPlots[index].plantedDate = nil
        gameState.gardenPlots[index].state = .empty

        // Add to inventory
        gameState.addHarvestedIngredient(vegType, quantity: yield)

        // Award coins!
        let coinsEarned = vegType.harvestValue * yield
        gameState.addCoins(coinsEarned)

        // Award XP
        gameState.addXP(10)

        // Check if any recipe can now be cooked with harvested ingredients
        let availableRecipes = GardenRecipes.availableRecipes(with: gameState.harvestedIngredients)
        if let recipe = availableRecipes.first {
            suggestedRecipe = recipe
            // Small delay so harvest animation plays first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showRecipeSuggestion = true
            }
        }
    }

    /// Dynamic hint text based on garden state
    var gardenHint: String {
        let hasReady = gameState.gardenPlots.contains(where: { $0.state == .ready })
        let hasGrowing = gameState.gardenPlots.contains(where: { $0.state == .growing })

        if hasReady {
            return "Drag Pip to a glowing plot to harvest!"
        } else if hasGrowing {
            return "Pip is patrolling the garden while your plants grow!"
        } else {
            return "Tap a plot to plant seeds!"
        }
    }

    func updateGrowthStates() {
        // Check each plot and update state if plant is ready
        for index in gameState.gardenPlots.indices {
            if gameState.gardenPlots[index].state == .growing &&
               gameState.gardenPlots[index].isReadyToHarvest {
                gameState.gardenPlots[index].state = .ready
            }
        }
    }
}

// MARK: - Pip Garden Message

struct PipGardenMessage: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Animated Pip waving (frame animation, transparent bg)
            PipWavingAnimatedView(size: 120)

            // Message bubble
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)

                Text(gardeningTips.randomElement() ?? "Happy gardening!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    let gardeningTips = [
        "Tap an empty plot to plant seeds!",
        "Watch your plants grow - they'll be ready soon!",
        "Harvest veggies to use in recipes!",
        "Different veggies take different times to grow.",
        "Lettuce grows the fastest!"
    ]
}

// MARK: - Seed Badge

struct SeedBadge: View {
    let seed: Seed
    var isIPad: Bool = false

    private var imgSize: CGFloat { isIPad ? 60 : 36 }
    private var badgeWidth: CGFloat { isIPad ? 110 : 70 }

    var body: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            Image(seed.vegetableType.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imgSize, height: imgSize)

            Text(seed.vegetableType.displayName)
                .font(.system(size: isIPad ? 13 : 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)

            Text("x\(seed.quantity)")
                .font(isIPad ? .AppTheme.body : .AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(width: badgeWidth)
        .padding(isIPad ? AppSpacing.md : AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Ingredient Badge

struct IngredientBadge: View {
    let ingredient: HarvestedIngredient
    var isIPad: Bool = false

    private var imgSize: CGFloat { isIPad ? 60 : 36 }
    private var badgeWidth: CGFloat { isIPad ? 110 : 70 }

    var body: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            Image(ingredient.type.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imgSize, height: imgSize)

            Text(ingredient.type.displayName)
                .font(.system(size: isIPad ? 13 : 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)

            Text("x\(ingredient.quantity)")
                .font(isIPad ? .AppTheme.body : .AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(width: badgeWidth)
        .padding(isIPad ? AppSpacing.md : AppSpacing.sm)
        .background(Color.AppTheme.sage.opacity(0.2))
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Preview

#Preview {
    GardenView(selectedTab: .constant(.garden))
        .environmentObject(GameState.preview)
}
