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
import Combine  // NotificationCenter publisher → .onReceive
#if canImport(FoundationModels)
import FoundationModels
#endif

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

    /// Pip's size — 2x on iPad
    private var pipSize: CGFloat { isIPad ? 160 : 55 }

    /// How close Pip needs to be to a plot to harvest — bigger on iPad
    private var harvestRadius: CGFloat { isIPad ? 160 : 60 }

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
            Image("pip_got_idea")  // Clean pose — replace with walking sprite later
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
                                .font(.AppTheme.rounded(size: 9, weight: .semibold))
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
        .animation(AnimationConstants.springMedium, value: isVisible)
        .onAppear {
            // Start idle bounce animation
            withAnimation(AnimationConstants.floatLoopFast) {
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

        withAnimation(AnimationConstants.fadeQuick) {
            nearbyPlotIndex = closestReady
        }
    }

    // MARK: - Trigger Harvest

    private func triggerHarvest(plotIndex: Int) {
        // Burst animation
        withAnimation(AnimationConstants.springTight) {
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

    private var pipSize: CGFloat { isIPad ? 160 : 55 }
    private var harvestRadius: CGFloat { isIPad ? 160 : 60 }

    /// How many points Pip moves per tick (1/30s)
    private let walkSpeed: CGFloat = 1.8

    private var pipDisplaySize: CGFloat { isIPad ? 220 : 110 }

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
    @State private var lastWalkUpdate: Date = .now
    @State private var walkElapsed: TimeInterval = 0  // total walk time for frame calc
    @State private var isWalking: Bool = false

    /// Pip's display position (walk position or idle, plus drag offset)
    private var pipCenter: CGPoint {
        CGPoint(
            x: pipPosition.x + dragOffset.width,
            y: pipPosition.y + dragOffset.height
        )
    }

    // TEACHING MOMENT: TimelineView for Walking Animation
    //
    // The old approach used Timer.scheduledTimer at 30fps — this runs on
    // the RunLoop and fires even when the app is off-screen or the view
    // is hidden. TimelineView is SwiftUI-native: it only triggers redraws
    // when the system is actually compositing frames, and automatically
    // pauses when the view leaves the hierarchy.
    //
    // We use .animation schedule (not .periodic) because it syncs with
    // the display refresh rate. On a 60Hz display, we get ~60 updates/sec.
    // On a 120Hz ProMotion display, we get ~120 updates/sec. But since
    // we use delta-time math, the walk speed is the SAME on both devices.
    //
    // The walking frame image still changes at ~8fps (every 0.125s) —
    // we compute that from elapsed time, not a tick counter.

    var body: some View {
        // TimelineView drives walk updates; when not walking, it idles
        // (SwiftUI skips redraws when the schedule produces no new dates)
        TimelineView(isWalking && !isDragging ? .animation : .animation) { context in
            let now = context.date
            let _ = updateWalkIfNeeded(now: now)

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

                // Pip character — frame computed from elapsed time
                Image(currentPipImage)
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
                    .offset(y: (!isDragging && !isWalking && idleBounce) ? -4 : 0)
                    .position(pipCenter)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation
                                if value.translation.width > 5 {
                                    facingRight = true
                                } else if value.translation.width < -5 {
                                    facingRight = false
                                }
                                checkNearbyPlots()
                            }
                            .onEnded { _ in
                                isDragging = false
                                if let plotIndex = nearbyPlotIndex {
                                    triggerHarvest(plotIndex: plotIndex)
                                }
                                dragOffset = .zero
                            }
                    )
                    .overlay(
                        Group {
                            if !isDragging && nearbyPlotIndex == nil && !isWalking {
                                Text("Drag me!")
                                    .font(.AppTheme.rounded(size: 9, weight: .semibold))
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
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(AnimationConstants.springMedium, value: isVisible)
        .onAppear {
            pipPosition = idlePosition
            withAnimation(AnimationConstants.floatLoopFast) {
                idleBounce = true
            }
        }
        .onChange(of: isGrowing) { _, growing in
            if growing {
                startWalking()
            } else {
                stopWalking()
            }
        }
    }

    /// The current Pip image name — walking frame or neutral
    private var currentPipImage: String {
        if isWalking && !isDragging {
            return walkingFrames[walkingFrameIndex]
        }
        return "pip_got_idea"
    }

    // MARK: - Walking Engine (TimelineView-Driven)
    //
    // TEACHING MOMENT: Delta-Time Movement
    //
    // Old approach: move 1.8 points per Timer tick (30fps) = 54 pts/sec.
    // Problem: if Timer fires late (CPU busy), Pip stutters.
    //
    // New approach: move (walkSpeed * deltaTime) points per frame.
    // If frame takes 0.033s (30fps): 54 * 0.033 = 1.78 pts — same!
    // If frame takes 0.016s (60fps): 54 * 0.016 = 0.89 pts — smoother!
    // If frame takes 0.1s (lag): 54 * 0.1 = 5.4 pts — catches up!
    //
    // The walk speed is now in POINTS PER SECOND, not per tick.

    /// Walk speed in points per second (old: 1.8 pts/tick * 30 ticks = 54 pts/sec)
    private let walkPointsPerSecond: CGFloat = 54.0

    /// Frame duration for walking sprite (~8fps)
    private let walkFrameDuration: TimeInterval = 0.125

    private func updateWalkIfNeeded(now: Date) {
        guard isWalking, !isDragging, waypoints.count >= 2 else { return }

        let dt = now.timeIntervalSince(lastWalkUpdate)
        guard dt > 0, dt < 0.5 else { // cap at 0.5s to prevent jumps after backgrounding
            lastWalkUpdate = now
            return
        }
        lastWalkUpdate = now

        let delta = CGFloat(dt)

        // Update walk position
        let fromIndex = currentWaypointIndex
        let toIndex = (currentWaypointIndex + 1) % waypoints.count
        let from = waypoints[fromIndex]
        let to = waypoints[toIndex]

        let dx = to.x - from.x
        let dy = to.y - from.y
        let segmentLength = sqrt(dx * dx + dy * dy)
        guard segmentLength > 0 else { return }

        let progressPerSecond = walkPointsPerSecond / segmentLength
        walkProgress += progressPerSecond * delta

        if dx > 1 { facingRight = true }
        else if dx < -1 { facingRight = false }

        if walkProgress >= 1.0 {
            walkProgress = 0.0
            currentWaypointIndex = toIndex
            pipPosition = to
        } else {
            pipPosition = CGPoint(
                x: from.x + dx * walkProgress,
                y: from.y + dy * walkProgress
            )
        }

        // Update walking frame from elapsed time (~8fps)
        walkElapsed += dt
        walkingFrameIndex = Int(walkElapsed / walkFrameDuration) % walkingFrames.count
    }

    private func startWalking() {
        guard waypoints.count >= 2 else { return }
        currentWaypointIndex = 0
        walkProgress = 0.0
        walkElapsed = 0
        walkingFrameIndex = 0
        pipPosition = waypoints[0]
        lastWalkUpdate = .now
        isWalking = true
    }

    private func stopWalking() {
        isWalking = false
        walkingFrameIndex = 0

        withAnimation(AnimationConstants.springSlow) {
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

        withAnimation(AnimationConstants.fadeQuick) {
            nearbyPlotIndex = closestReady
        }
    }

    private func triggerHarvest(plotIndex: Int) {
        withAnimation(AnimationConstants.springTight) {
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
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.horizontalSizeClass) var sizeClass

    // Weather service — real weather affects plant growth!
    @ObservedObject private var weatherService = GardenWeatherService.shared

    // Tab navigation binding — so we can switch to Kitchen after harvest
    @Binding var selectedTab: MainTabView.Tab
    // Callback to switch to Farm Shop within the GardenHub
    var onShowFarmShop: (() -> Void)? = nil
    // When visiting a sibling's garden — disables planting, harvesting, Pip dialog
    var isVisiting: Bool = false
    var visitingName: String = ""
    var onLikeGarden: (() -> Void)? = nil
    var onHelpWithCare: ((Int, CareAction) -> Void)? = nil

    // Adaptive: detect iPad
    private var isIPad: Bool { sizeClass != .compact }

    // @State is for LOCAL view state - things only this view cares about
    @State private var selectedPlotIndex: SelectedPlot?
    @State private var suggestedRecipe: Recipe?
    @State private var showRecipeSuggestion = false

    // Seed info full-screen cover
    @State private var selectedSeed: Seed?

    // Visitor greeting
    @State private var showVisitorGreeting = false

    // Ask Pip chat (opens when kid taps "Tell me!" on a question tip)
    @State private var showAskPip = false

    // AI-generated Pip garden tip (Foundation Models on-device)
    @State private var smartPipTip: String? = nil
    @State private var isLoadingTip = false

    // Falling veggie animation
    @State private var fallingVeggie: VegetableType? = nil
    @State private var fallingOffset: CGFloat = -200
    @State private var fallingOpacity: Double = 1.0

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
        // Update growth progress every second (only while view is visible).
        //
        // BUGFIX (May 2): the previous implementation used Timer.publish + manual
        // .connect()/.cancel() inside onAppear/onDisappear. Because SwiftUI
        // re-creates the View struct on every render, a NEW TimerPublisher value
        // was constructed each render. .onReceive resubscribed to that new
        // publisher, but only the FIRST publisher had ever been .connect()ed
        // (via .onAppear, which doesn't fire on re-renders). After the first
        // render, .onReceive was listening to publishers that were never
        // connected → no ticks → updateGrowthStates never ran → plots stayed
        // at .growing forever even after crossing 100%. Symptom: harvest UI
        // only appeared after navigating away and back (which re-fired
        // .onAppear and re-connected the publisher).
        //
        // .task is the modern fix: one Task per view appearance, auto-cancels
        // on disappear, runs on the @MainActor by default (so @Published
        // mutations publish on the right thread), no publisher gymnastics.
        .task {
            while !Task.isCancelled {
                updateGrowthStates()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            }
        }
        // Rain auto-waters all thirsty plants!
        .onReceive(NotificationCenter.default.publisher(for: .gardenRainEvent)) { _ in
            for index in gameState.gardenPlots.indices {
                if gameState.gardenPlots[index].state == .needsWater {
                    gameState.gardenPlots[index].water()
                }
            }
        }
        // Recipe suggestion is now handled inline by PipGardenMessage in bottomPanel
        // Visitor greeting is now handled inline by PipGardenMessage in bottomPanel
        .onAppear {
            if isVisiting {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showVisitorGreeting = true
                }
            }
            // Fetch weather & request location on first garden visit
            weatherService.requestLocationPermission()
            Task { await weatherService.fetchWeather() }

            // Pip stays quiet until tapped — no auto tip on appear

            // Start the right ambient loop for the current weather.
            // Crossfades automatically when weather changes (see .onChange below).
            AmbientAudioPlayer.shared.play(ambientTrackForWeather(weatherService.currentWeather))
        }
        .onChange(of: weatherService.currentWeather) { _, newWeather in
            AmbientAudioPlayer.shared.play(ambientTrackForWeather(newWeather))
        }
        .onDisappear {
            // Garden tab gone → fade out ambient. Other tabs may have their
            // own ambient (kitchen hum, farm bell) wired later.
            AmbientAudioPlayer.shared.stop()
        }
    }

    /// Map the weather enum to the matching ambient loop.
    /// Rainy + stormy share the rain track; everything else uses the
    /// peaceful garden track.
    private func ambientTrackForWeather(_ weather: GardenWeather) -> AmbientTrack {
        switch weather {
        case .rainy, .stormy: return .rainAmbient
        default:              return .gardenAmbient
        }
    }

    // MARK: - Header View

    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(isVisiting ? "\(visitingName)'s Garden" : "My Garden")
                    .font(isIPad ? .AppTheme.largeTitle : .AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text(isVisiting ? "You're visiting!" : gardenHint)
                    .font(isIPad ? .AppTheme.body : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
                if !isVisiting && gameState.gardenLikes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(Color.AppTheme.terracotta.opacity(0.7))
                            .font(.AppTheme.caption)
                        Text("\(gameState.gardenLikes)")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                }
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
                    .font(.AppTheme.rounded(size: isIPad ? 24 : 20))
                    .foregroundColor(editMode ? Color.AppTheme.terracotta : Color.AppTheme.lightSepia)
            }
            .buttonStyle(.plain)
            #endif

            // Weather badge
            WeatherBadge(weatherService: weatherService, isIPad: isIPad)

            // Coin display
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                    .font(.AppTheme.rounded(size: isIPad ? 18 : 14))
                Text("\(gameState.coins)")
                    .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, isIPad ? AppSpacing.md : AppSpacing.sm)
            .padding(.vertical, isIPad ? AppSpacing.sm : AppSpacing.xs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(AppSpacing.largeCornerRadius)
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

                        // Pip removed from map — one Pip only, shown in PipGardenMessage below
                        // Walking/draggable Pip will return once speaking animation is ready
                    }
                }
            )
            // Seasonal gradient overlay — shifts garden mood by season
            .overlay(
                GeometryReader { geo in
                    SeasonalOverlayView(
                        season: weatherService.currentSeason,
                        mapWidth: geo.size.width,
                        mapHeight: geo.size.height
                    )
                }
            )
            // Weather overlay — rain, snow, sunshine effects!
            .overlay(
                GeometryReader { geo in
                    WeatherOverlayView(
                        weather: weatherService.currentWeather,
                        mapWidth: geo.size.width,
                        mapHeight: geo.size.height
                    )
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
                    },
                    onCareComplete: {
                        // Care interaction handled inside PlotView — just apply state changes
                        let state = gameState.gardenPlots[index].state
                        let careAction: CareAction?
                        switch state {
                        case .needsWater:
                            gameState.gardenPlots[index].water()
                            gameState.gardenPlots[index].hasWatered = true
                            gameState.addXP(2)
                            careAction = .water
                        case .needsWeeding:
                            gameState.gardenPlots[index].weed()
                            gameState.addXP(2)
                            careAction = .weed
                        case .hasBugs:
                            gameState.gardenPlots[index].releaseLadybugs()
                            gameState.addXP(2)
                            careAction = .debug
                        default:
                            careAction = nil
                        }

                        // If visiting, notify parent view to reward the visitor
                        if isVisiting, let action = careAction {
                            onHelpWithCare?(index, action)
                        }
                    },
                    rewardLabel: isVisiting ? "+5 🪙" : "+2 XP"
                )
                .frame(width: isIPad ? 160 : 100, height: isIPad ? 160 : 100)
                .scaleEffect(isIPad ? 1.4 : 1.0)
            }
        }
    }

    // MARK: - Bottom Panel (Seeds + Harvested)

    var bottomPanel: some View {
        VStack(spacing: AppSpacing.md) {
            // Pip's message — shows recipe suggestion with buttons, or a random tip
            if showRecipeSuggestion, let recipe = suggestedRecipe {
                let missing = recipe.missingPantryItems(from: gameState.pantryInventory)
                let isFullMatch = missing.isEmpty
                let message = isFullMatch
                    ? "You have everything for \(recipe.title)! Want to cook it now?"
                    : "You can almost make \(recipe.title)! Just need \(missing.map(\.displayName).joined(separator: ", ")) from the Farm Shop."

                PipGardenMessage(
                    recipeMessage: message,
                    choices: isFullMatch
                        ? [
                            PipDialogChoice(label: "Yes, let's cook!", style: .primary) {
                                showRecipeSuggestion = false
                                selectedTab = .kitchen
                            },
                            PipDialogChoice(label: "Not yet", style: .secondary) {
                                showRecipeSuggestion = false
                            },
                            PipDialogChoice(label: "Keep gardening", style: .subtle) {
                                showRecipeSuggestion = false
                            },
                        ]
                        : [
                            PipDialogChoice(label: "Go to Farm Shop!", style: .primary) {
                                showRecipeSuggestion = false
                                onShowFarmShop?()
                            },
                            PipDialogChoice(label: "Go to Kitchen", style: .secondary) {
                                showRecipeSuggestion = false
                                selectedTab = .kitchen
                            },
                            PipDialogChoice(label: "Keep gardening", style: .subtle) {
                                showRecipeSuggestion = false
                            },
                        ]
                )
            } else if isVisiting && showVisitorGreeting {
                PipGardenMessage(
                    recipeMessage: [
                        "Welcome to \(visitingName)'s garden! Look around and see what they're growing!",
                        "Glad to see you here! \(visitingName) has been working hard in the garden!",
                        "Hey there! Take a look at \(visitingName)'s awesome garden!",
                    ].randomElement(),
                    choices: [
                        PipDialogChoice(label: "Cool garden!", style: .primary) {
                            onLikeGarden?()
                            showVisitorGreeting = false
                        },
                        PipDialogChoice(label: "Let me look around", style: .secondary) {
                            showVisitorGreeting = false
                        },
                    ]
                )
            } else {
                let tip = smartPipTip
                let isQuestion = tip?.hasSuffix("?") ?? false
                PipGardenMessage(
                    recipeMessage: tip,
                    choices: isQuestion ? [
                        PipDialogChoice(label: "Tell me!", style: .primary) {
                            showAskPip = true
                        },
                        PipDialogChoice(label: "Maybe later", style: .subtle) {
                            fetchSmartPipTip()
                        }
                    ] : [],
                    gardenPlots: gameState.gardenPlots,
                    onPipTap: {
                        // Tap Pip → get the next tip
                        fetchSmartPipTip()
                    }
                )
            }

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Show ALL veggies — owned first, then buyable
                    let owned = VegetableType.allCases.filter { veg in
                        gameState.seeds.contains(where: { $0.vegetableType == veg && $0.quantity > 0 })
                    }
                    let unowned = VegetableType.allCases.filter { veg in
                        !gameState.seeds.contains(where: { $0.vegetableType == veg && $0.quantity > 0 })
                    }

                    ForEach(owned, id: \.self) { veg in
                        let seed = gameState.seeds.first(where: { $0.vegetableType == veg })!
                        SeedBadge(seed: seed, isIPad: isIPad)
                            .onTapGesture { selectedSeed = seed }
                    }

                    ForEach(unowned, id: \.self) { veg in
                        // Create a placeholder seed for display
                        let placeholderSeed = Seed(vegetableType: veg, quantity: 0)
                        SeedBadge(seed: placeholderSeed, isIPad: isIPad, showPrice: true)
                            .onTapGesture { selectedSeed = placeholderSeed }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedSeed) { seed in
            SeedInfoView(seed: seed)
                .environmentObject(gameState)
        }
        .sheet(isPresented: $showAskPip) {
            AskPipView()
                .environmentObject(gameState)
                .environmentObject(sessionManager)
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
                // Empty basket + hint text
                GeometryReader { geo in
                    VStack(spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
                        Image("vegetable_basket")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width * 0.9)
                            .opacity(0.3)

                        Text("Nothing harvested yet. Grow some veggies!")
                            .font(isIPad ? .AppTheme.headline : .AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                    .frame(width: geo.size.width, height: geo.size.width * 0.7)
                }
                .frame(height: UIScreen.main.bounds.width * 0.7)
                .padding(.vertical, isIPad ? AppSpacing.md : AppSpacing.sm)
            } else {
                // Basket with veggies + falling animation
                ZStack {
                    BasketWithVeggiesView(
                        harvestedIngredients: gameState.harvestedIngredients,
                        basketSize: UIScreen.main.bounds.width * 0.85
                    )
                    .opacity(0.75)

                    // Falling veggie animation overlay
                    if let veggie = fallingVeggie {
                        let sz = UIScreen.main.bounds.width * 0.17
                        Image(veggie.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: sz, height: sz)
                            .offset(y: fallingOffset)
                            .opacity(fallingOpacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isIPad ? AppSpacing.sm : AppSpacing.xs)

                // Ingredient badges grid below basket
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
            guard !isVisiting else { return }  // Can't plant in sibling's garden
            selectedPlotIndex = SelectedPlot(index: index)

        case .growing:
            break

        case .ready:
            guard !isVisiting else { return }  // Can't harvest sibling's plants
            harvestPlot(index: index)

        case .needsWater, .needsWeeding, .hasBugs:
            // Allowed for visitors! PlotView's built-in gestures handle it
            break
        }
    }

    func harvestPlot(index: Int) {
        guard !isVisiting else { return }
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

        // Trigger falling veggie animation
        fallingVeggie = vegType
        fallingOffset = -200
        fallingOpacity = 1.0
        withAnimation(.easeIn(duration: 0.6)) {
            fallingOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                fallingOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            fallingVeggie = nil
        }

        // Award coins!
        let coinsEarned = vegType.harvestValue * yield
        gameState.addCoins(coinsEarned)

        // Award XP
        gameState.addXP(10)

        // Check if any recipe can now be cooked — prefer recipes using MOST harvested veggies
        let harvested = gameState.harvestedIngredients
        let pantry = gameState.pantryInventory
        let fullMatch = GardenRecipes.fullyAvailableRecipes(
            harvestedIngredients: harvested,
            pantryInventory: pantry
        )
        let gardenMatch = fullMatch.isEmpty
            ? GardenRecipes.availableRecipes(with: harvested)
            : []
        // Sort by most garden ingredients used — suggest the recipe that uses the most of what you grew
        let availableRecipes = (fullMatch.isEmpty ? gardenMatch : fullMatch)
            .sorted { $0.gardenIngredients.count > $1.gardenIngredients.count }
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
        // Sync current weather to GardenPlot (per-veggie multipliers calculated inside)
        GardenPlot.currentWeather = weatherService.currentWeather

        // Check if plants need water (no rain for 5+ minutes)
        let needsWateringCheck = weatherService.timeSinceLastRain > 300

        // Check each plot and update state
        for index in gameState.gardenPlots.indices {
            let plot = gameState.gardenPlots[index]

            guard plot.state == .growing else { continue }

            if plot.isReadyToHarvest {
                gameState.gardenPlots[index].state = .ready
            } else if needsWateringCheck && plot.growthProgress > 0.5 && !plot.hasWatered {
                // Plant is thirsty! Needs watering at 50%+ growth
                gameState.gardenPlots[index].pauseForWater()
            } else if plot.growthProgress > 0.2 && plot.growthProgress < 0.35 && !plot.weedTriggered {
                // Random weeds at ~25% growth (30% chance)
                if Double.random(in: 0...1) < 0.3 {
                    gameState.gardenPlots[index].triggerWeeds()
                } else {
                    gameState.gardenPlots[index].weedTriggered = true // Skip this cycle
                }
            } else if plot.growthProgress > 0.7 && plot.growthProgress < 0.85 && !plot.bugTriggered {
                // Random bugs at ~75% growth (25% chance)
                if Double.random(in: 0...1) < 0.25 {
                    gameState.gardenPlots[index].triggerBugs()
                } else {
                    gameState.gardenPlots[index].bugTriggered = true // Skip this cycle
                }
            }
        }

        // No auto-update — Pip only speaks when tapped
    }

    // MARK: - Smart Pip Tip (Foundation Models)
    //
    // TEACHING MOMENT: On-Device AI for Dynamic UI
    // Instead of picking from a static list, we ask the on-device model to
    // generate a tip based on the ACTUAL garden state. This makes Pip feel
    // alive — "Your carrots are 70% grown, almost ready!" instead of
    // generic "Harvest veggies to use in recipes!"
    //
    // If Foundation Models isn't available (older device), we fall back to
    // the context-aware static tips in PipGardenMessage.gardeningTips.

    // TEACHING MOMENT: State Hashing for Change Detection
    // Instead of re-calling the AI every 5 seconds (wasteful), we compute
    // a simple "hash" of all plot states. If the hash is the same as last
    // time, nothing changed — skip the update. If it changed (a plant grew
    // to ready, or needs water now), THEN we refresh the tip.
    // This is the same principle behind SwiftUI's own diffing engine.

    // TEACHING MOMENT: Grounding AI with Real Data
    //
    // The first attempt hallucinated because we used tools (async context
    // that wasn't populated yet). The fix: embed the garden state DIRECTLY
    // in the prompt text. The model can't ignore data that's literally in
    // its input. We also add "ONLY mention veggies listed above" as a
    // hard constraint to prevent hallucination.
    //
    // If FM isn't available, we fall back to static tips (also data-driven).

    private func fetchSmartPipTip() {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *), PipFoundationModelService.isModelAvailable {
            Task {
                let tip = await generateAITip()
                if let tip {
                    await MainActor.run { smartPipTip = tip }
                } else {
                    await MainActor.run { smartPipTip = generateStaticTip() }
                }
            }
            return
        }
        #endif
        smartPipTip = generateStaticTip()
    }

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, *)
    private func generateAITip() async -> String? {
        let plots = gameState.gardenPlots
        let weather = GardenWeatherService.shared

        // Build EXACT state — the model must ONLY reference what's here
        var state = "EXACT GARDEN STATE (do NOT invent veggies not listed here):\n"
        var hasAnything = false
        for (i, plot) in plots.enumerated() {
            switch plot.state {
            case .empty:
                state += "- Plot \(i+1): EMPTY (nothing planted)\n"
            case .growing:
                let name = plot.vegetable?.displayName ?? "plant"
                let pct = Int(plot.growthProgress * 100)
                state += "- Plot \(i+1): \(name) growing (\(pct)%)\n"
                hasAnything = true
            case .ready:
                let name = plot.vegetable?.displayName ?? "plant"
                state += "- Plot \(i+1): \(name) READY to harvest\n"
                hasAnything = true
            case .needsWater:
                let name = plot.vegetable?.displayName ?? "plant"
                state += "- Plot \(i+1): \(name) NEEDS WATER\n"
                hasAnything = true
            case .needsWeeding:
                let name = plot.vegetable?.displayName ?? "plant"
                state += "- Plot \(i+1): \(name) HAS WEEDS\n"
                hasAnything = true
            case .hasBugs:
                let name = plot.vegetable?.displayName ?? "plant"
                state += "- Plot \(i+1): \(name) HAS BUGS\n"
                hasAnything = true
            }
        }
        state += "Weather: \(weather.currentWeather.displayName), \(weather.temperature)°F\n"

        let playerName = await MainActor.run { sessionManager.activeProfile?.name ?? "" }
        let nameNote = playerName.isEmpty ? "" : "The kid's name is \(playerName) — use it sometimes.\n"

        let prompt = """
        You are Pip, a cheerful hedgehog gardener talking to a 6-year-old.
        Give ONE tip (2 sentences max) based ONLY on the garden state below.
        ONLY mention veggies that are actually listed. If all plots are empty, \
        encourage the kid to plant something. Be fun and encouraging. One emoji max.
        Do NOT say "Hello" or greet — you already know each other.
        \(nameNote)
        \(state)
        """

        let session = LanguageModelSession(instructions: "You are Pip, a friendly hedgehog chef for kids aged 6+. Keep responses to 2 sentences max.")
        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
    #endif

    /// Generate a context-aware tip without AI — reads actual plot states.
    /// Rotates through different tip types so Pip doesn't repeat himself.
    @State private var tipRotation: Int = 0

    private func generateStaticTip() -> String {
        let plots = gameState.gardenPlots
        let name = sessionManager.activeProfile?.name ?? ""
        let namePrefix = name.isEmpty ? "" : "\(name), "
        let ready = plots.filter { $0.state == .ready }
        let thirsty = plots.filter { $0.state == .needsWater }
        let weedy = plots.filter { $0.state == .needsWeeding }
        let buggy = plots.filter { $0.state == .hasBugs }
        let growing = plots.filter { $0.state == .growing }
        let empty = plots.filter { $0.state == .empty }

        // Urgent care tips always come first (no rotation)
        if let plot = thirsty.first, let veg = plot.vegetable {
            return "\(namePrefix)your \(veg.displayName.lowercased()) is thirsty! Hold on the plot to water it!"
        }
        if let plot = buggy.first, let veg = plot.vegetable {
            return "Oh no \(namePrefix)bugs are munching on your \(veg.displayName.lowercased())! Tap to call the ladybugs!"
        }
        if let plot = weedy.first, let veg = plot.vegetable {
            return "\(namePrefix)weeds are crowding your \(veg.displayName.lowercased())! Swipe up to pull them out!"
        }
        if let plot = ready.first, let veg = plot.vegetable {
            return "\(namePrefix)your \(veg.displayName.lowercased()) \(ready.count == 1 ? "is" : "are") ready to pick! Drag me over to harvest!"
        }

        // Non-urgent: ROTATE between growing info, empty plots, and fun facts
        var pool: [String] = []

        // Growing veggies — progress + fun facts
        for plot in growing {
            if let veg = plot.vegetable {
                let pct = Int(plot.growthProgress * 100)
                pool.append("\(namePrefix)your \(veg.displayName.lowercased()) is \(pct)% grown! \(pct > 70 ? "Almost there!" : "Keep watching — good things take time!")")
                if let fact = veggieGardenFact(veg) {
                    pool.append(fact)
                }
            }
        }

        // Empty plot reminders
        if !empty.isEmpty {
            pool.append("\(namePrefix)you have \(empty.count) empty plot\(empty.count == 1 ? "" : "s") — tap one to plant something new!")
            pool.append("Your garden has room for more! Try planting different veggies to unlock new recipes!")
        }

        // General tips (no greetings — kid already knows Pip)
        pool.append("Different veggies take different times to grow. Lettuce is the fastest!")
        pool.append("Harvest veggies and take them to the kitchen to cook yummy recipes!")

        if pool.isEmpty {
            return "\(namePrefix)your garden is looking great! Tap me for more tips!"
        }

        tipRotation += 1
        return pool[tipRotation % pool.count]
    }

    /// Fun garden facts about specific veggies — makes Pip feel knowledgeable
    private func veggieGardenFact(_ veg: VegetableType) -> String? {
        switch veg {
        case .carrot:    return "Did you know carrots were originally purple? Want to know what makes them good for your eyes?"
        case .tomato:    return "Tomatoes are actually berries! They're packed with lycopene — a superpower for your heart!"
        case .pumpkin:   return "Pumpkins can grow up to 2,000 pounds! Yours is getting bigger every minute!"
        case .broccoli:  return "Broccoli is actually a flower that hasn't bloomed yet! It's full of vitamins!"
        case .lettuce:   return "Lettuce is part of the sunflower family! It grows super fast!"
        case .cucumber:  return "Cucumbers are 95% water — they're nature's water bottle!"
        case .zucchini:  return "The biggest zucchini ever was over 8 feet long! How big will yours get?"
        case .onion:     return "Onions make you cry because they release a tiny gas. But they're so tasty in recipes!"
        case .spinach:   return "Spinach makes your muscles strong — just like Popeye says!"
        case .corn:      return "An ear of corn has about 800 tiny kernels! Want to know what's inside each one?"
        case .sweetPotato: return "Sweet potatoes aren't related to regular potatoes at all! They're packed with vitamin A!"
        case .strawberry: return "Strawberries are the only fruit with seeds on the outside — about 200 per berry!"
        case .avocado:   return "Avocados are actually berries! They have healthy fats that are great for your brain!"
        case .blueberry: return "Blueberries are one of the only naturally blue foods in the world! They boost your brain power!"
        default:         return nil
        }
    }
}

// MARK: - Pip Garden Message

struct PipGardenMessage: View {
    var recipeMessage: String? = nil
    var choices: [PipDialogChoice] = []
    var gardenPlots: [GardenPlot] = []
    var onPipTap: (() -> Void)? = nil
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    // Resolved random tip — captured once per appearance so the displayed
    // and spoken text always match (and the tip doesn't reshuffle on every
    // re-render of this view).
    @State private var resolvedTip: String = ""

    private var displayedMessage: String {
        recipeMessage ?? (resolvedTip.isEmpty ? "Happy gardening!" : resolvedTip)
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Static Pip (transparent bg) — will switch to speaking animation once ready
            Image("pip_waving_frame_01")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: isIPad ? 200 : 100, height: isIPad ? 200 : 100)
                .onTapGesture { onPipTap?() }
                .overlay(alignment: .bottom) {
                    if onPipTap != nil {
                        Text("Tap me!")
                            .font(.AppTheme.rounded(size: 9, weight: .semibold))
                            .foregroundColor(Color.AppTheme.sage)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.AppTheme.warmCream.opacity(0.9))
                            .cornerRadius(6)
                            .offset(y: 4)
                    }
                }

            // Message bubble — compact, doesn't fill full width
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)

                Text(displayedMessage)
                    .font(isIPad ? .AppTheme.body : .AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.darkBrown)

                // Action buttons (shown for recipe suggestions)
                if !choices.isEmpty {
                    let actionChoices = choices.filter { $0.style != .subtle }
                    let subtleChoices = choices.filter { $0.style == .subtle }

                    // Primary + secondary side by side with wood texture
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(actionChoices.indices, id: \.self) { index in
                            let choice = actionChoices[index]
                            Button(choice.label, action: choice.action)
                                .buttonStyle(TexturedButtonStyle(
                                    tint: choice.style == .primary ? Color.AppTheme.sage : Color.AppTheme.warmKhaki,
                                    height: 38,
                                    font: .AppTheme.caption
                                ))
                        }
                    }
                    .padding(.top, AppSpacing.xs)

                    // "Keep gardening" as plain text link below
                    ForEach(subtleChoices.indices, id: \.self) { index in
                        let choice = subtleChoices[index]
                        Button(action: choice.action) {
                            Text(choice.label)
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(isIPad ? AppSpacing.md : AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .frame(maxWidth: isIPad ? 500 : .infinity)
        .padding(.horizontal, AppSpacing.md)
        .onAppear {
            // Pick the random fallback tip exactly once per appearance.
            if resolvedTip.isEmpty {
                resolvedTip = gardeningTips.randomElement() ?? "Happy gardening!"
            }
            PipVoice.shared.speak(displayedMessage)
        }
        .onChange(of: recipeMessage) { _, _ in
            // Smart-tip updates (Apple Intelligence regen on Pip tap) flow
            // through `recipeMessage`. Re-speak whenever it changes.
            PipVoice.shared.speak(displayedMessage)
        }
    }

    // TEACHING MOMENT: Context-Aware Tips
    // Instead of always showing "Tap an empty plot" (even when no plots are empty),
    // Pip's tips now change based on what's actually happening in the garden.
    // This makes Pip feel like a real companion who SEES what you're doing.
    var gardeningTips: [String] {
        let weather = GardenWeatherService.shared.currentWeather
        var tips: [String] = []

        let emptyPlots = gardenPlots.filter { $0.state == .empty }
        let growingPlots = gardenPlots.filter { $0.state == .growing }
        let readyPlots = gardenPlots.filter { $0.state == .ready }
        let thirstyPlots = gardenPlots.filter { $0.state == .needsWater }
        let weedyPlots = gardenPlots.filter { $0.state == .needsWeeding }
        let buggyPlots = gardenPlots.filter { $0.state == .hasBugs }

        // Context-specific tips based on actual garden state
        if !readyPlots.isEmpty {
            let vegName = readyPlots.first?.vegetable?.displayName ?? "veggies"
            tips.append("Your \(vegName) \(readyPlots.count == 1 ? "is" : "are") ready to harvest! Drag Pip over to pick!")
        }
        if !thirstyPlots.isEmpty {
            tips.append("Some plants are thirsty! Hold on a plot to water it!")
        }
        if !weedyPlots.isEmpty {
            tips.append("I see weeds! Swipe up on the plot to pull them!")
        }
        if !buggyPlots.isEmpty {
            tips.append("Bugs are munching on your plants! Tap to rescue them!")
        }
        if !emptyPlots.isEmpty {
            tips.append("You have \(emptyPlots.count) empty plot\(emptyPlots.count == 1 ? "" : "s") — tap to plant seeds!")
        }
        if !growingPlots.isEmpty && emptyPlots.isEmpty {
            let vegNames = growingPlots.compactMap { $0.vegetable?.displayName }
            let unique = Array(Set(vegNames))
            if unique.count <= 2 {
                tips.append("Your \(unique.joined(separator: " and ")) \(unique.count == 1 ? "is" : "are") growing nicely!")
            } else {
                tips.append("All \(growingPlots.count) plots are growing — garden is full!")
            }
        }

        // General tips (always available)
        tips.append("Different veggies take different times to grow.")
        tips.append("Lettuce grows the fastest!")
        tips.append("Harvest veggies to use in recipes!")

        // Weather-specific tips
        tips.append(contentsOf: weather.pipMessages)
        return tips
    }
}

// MARK: - Seed Badge

struct SeedBadge: View {
    let seed: Seed
    var isIPad: Bool = false
    var showPrice: Bool = false

    // Badge size — 1.5x on iPad, capped so it doesn't blow up on huge screens
    private var badgeWidth: CGFloat {
        let screenBased = UIScreen.main.bounds.width * 3 / 8
        return isIPad ? min(screenBased, 240) : screenBased
    }
    private var imgSize: CGFloat { badgeWidth * 0.43 }
    private var badgeHeight: CGFloat { badgeWidth * 1.5 }

    private var isOwned: Bool { seed.quantity > 0 }

    // TEACHING MOMENT: .fixedSize() vs .frame()
    // A ZStack sizes to fit ALL its children. If the VStack inside is taller
    // than badgeHeight (e.g., because of offset(y:25) pushing content down),
    // the ZStack grows and the bag looks bigger. By putting .frame() + .clipped()
    // on the OUTER ZStack, we force every bag to be exactly the same size,
    // regardless of content height. .contentShape ensures taps still work.
    var body: some View {
        ZStack {
            // Bag background
            Image("seed_bag_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: badgeWidth, height: badgeHeight)
                .clipped()
                .opacity(isOwned ? 0.5 : 0.35)

            // Content on top of the bag
            VStack(spacing: 2) {
                Image(seed.vegetableType.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imgSize, height: imgSize)
                    .opacity(0.85)
                    .offset(y: 25)

                Text(seed.vegetableType.displayName)
                    .font(.AppTheme.rounded(size: isIPad ? 18 : 14, weight: .medium))
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .offset(y: 20)

                if isOwned {
                    Text("x\(seed.quantity)")
                        .font(.AppTheme.rounded(size: isIPad ? 18 : 15, weight: .semibold))
                        .foregroundColor(Color.AppTheme.sepia)
                        .offset(y: 20)
                } else if showPrice {
                    HStack(spacing: 3) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.AppTheme.micro)
                        Text("\(seed.vegetableType.seedCost)")
                            .font(.AppTheme.rounded(size: isIPad ? 16 : 13, weight: .semibold))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    }
                    .offset(y: 20)
                }
            }
            .frame(width: badgeWidth, height: badgeHeight)
        }
        .frame(width: badgeWidth, height: badgeHeight)
        .clipped()
        .contentShape(Rectangle())
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
                .font(.AppTheme.rounded(size: isIPad ? 13 : 9, weight: .medium))
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
