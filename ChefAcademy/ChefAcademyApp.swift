//
//  ChefAcademyApp.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

import SwiftUI
import SwiftData
import Combine
import WeatherKit
import GameKit

@main
struct ChefAcademyApp: App {
    // The five core state objects shared across the entire app
    @StateObject private var avatarModel = AvatarModel()
    @StateObject private var gameState = GameState()
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var authManager = AuthManager()
    @StateObject private var subscriptionManager = SubscriptionManager()

    // Weather service — real weather affects garden growth!
    @ObservedObject private var weatherService = GardenWeatherService.shared

    // SwiftData container — now includes FamilyProfile & UserProfile
    private let modelContainer: ModelContainer

    // Set to true to test Pip images, false for normal app flow
    private let showPipTest = false

    init() {
        // Create SwiftData container with auto-recovery.
        // If the store is corrupted or has an old schema, delete and retry.
        // On real devices CloudKit sync is enabled; on Simulator it's local only.

        // First attempt
        do {
            let container = try ModelContainer(
                for: FamilyProfile.self, UserProfile.self, PlayerData.self
            )
            modelContainer = container
            print("[ChefAcademy] ModelContainer created successfully (persistent store)")
            return
        } catch {
            print("[ChefAcademy] First ModelContainer attempt FAILED: \(error)")
        }

        // If that failed, delete the old store and retry
        print("[ChefAcademy] Deleting old store and retrying...")
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        for ext in ["default.store", "default.store-shm", "default.store-wal"] {
            try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(ext))
        }

        do {
            modelContainer = try ModelContainer(
                for: FamilyProfile.self, UserProfile.self, PlayerData.self
            )
        } catch {
            // Last resort: in-memory so the app at least launches
            print("[ChefAcademy] Disk store failed: \(error). Falling back to in-memory.")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(
                for: FamilyProfile.self, UserProfile.self, PlayerData.self,
                configurations: config
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showPipTest {
                    PipTestView()
                } else {
                    // RootRouterView switches screens based on sessionManager.route
                    RootRouterView(avatarModel: avatarModel)
                        .environmentObject(gameState)
                        .environmentObject(sessionManager)
                        .environmentObject(avatarModel)
                        .environmentObject(authManager)
                        .environmentObject(subscriptionManager)
                }
            }
            .task {
                // Fetch subscription products from App Store Connect on launch.
                // Safe to call even if products aren't set up yet — fails silently.
                await subscriptionManager.loadProducts()

                // Register this device with the Worker via App Attest, if not already.
                // No-ops on simulator, jailbroken devices, and after first successful run.
                await AppAttestService.shared.registerIfNeeded()
            }
            .onAppear {
                // Wire SwiftData context to both GameState and SessionManager
                if gameState.modelContext == nil {
                    gameState.modelContext = modelContainer.mainContext

                    // Check if parent is already signed in with Apple
                    authManager.checkExistingCredential()

                    // Give Apple a moment to verify the credential, then bootstrap.
                    // On first launch this is instant (no saved credential).
                    // On subsequent launches, Apple verifies in ~0.1-0.3s.
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        guard !Task.isCancelled else { return }
                        sessionManager.bootstrap(
                            context: modelContainer.mainContext,
                            authManager: authManager
                        )
                    }

                    gameState.startAutoSave()

                    // Prewarm images — skip in debug builds (images are bundled, no need)
                    #if !DEBUG
                    ImagePrewarmer.prewarmAll()
                    #endif

                    // Authenticate with Game Center as early as possible.
                    // This shows the "Welcome back!" banner and enables
                    // leaderboard/achievement reporting for the whole session.
                    GameCenterService.shared.authenticate()

                    // Start weather service for garden weather effects
                    weatherService.startPeriodicRefresh()

                    // Register for silent push notifications so CloudKit
                    // can tell this device when data changed on another device.
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                sessionManager.appWillBackground(gameState: gameState, avatarModel: avatarModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                sessionManager.appWillForeground()
            }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Root Router View
// This is the "traffic controller" — it looks at sessionManager.route
// and shows the correct screen. Think of it like a GPS for your app.
struct RootRouterView: View {
    @ObservedObject var avatarModel: AvatarModel
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            switch sessionManager.route {
            case .loading:
                // Simple loading screen while bootstrap runs
                ZStack {
                    Color.AppTheme.cream.ignoresSafeArea()
                    VStack {
                        PipWavingAnimatedView(size: .large)
                        Text("Loading...")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                }

            case .signIn:
                // Parent sign-in screen (Sign in with Apple)
                SignInView()
                    .onChange(of: authManager.isAuthenticated) { _, isAuth in
                        if isAuth {
                            // Parent just signed in — find or create their family
                            sessionManager.handleAuthenticationComplete(authManager: authManager)
                        }
                    }

            case .familySetup:
                FamilySetupView()

            case .migrationPINSetup:
                MigrationPINSetupView()

            case .profilePicker:
                ProfilePickerView()

            case .parentPINEntry(let purpose):
                ParentPINEntryView(
                    purpose: purpose,
                    onSuccess: { sessionManager.route = .profilePicker },
                    onCancel: { sessionManager.route = .profilePicker }
                )

            case .childOnboarding:
                // Future: per-child onboarding if needed
                ProfilePickerView()

            case .mainApp:
                MainTabView(avatarModel: avatarModel)

            case .parentDashboard:
                ParentDashboardView()
            }
        }
        .animation(AnimationConstants.fadeMedium, value: sessionManager.route)
    }
}
// MARK: - Main Tab View
struct MainTabView: View {
    @ObservedObject var avatarModel: AvatarModel
    @EnvironmentObject var gameState: GameState
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "Home"
        case garden = "Garden"
        case shop = "Shop"
        case kitchen = "Kitchen"
        case bodyBuddy = "Body"
        case playLearn = "Play"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .garden: return "leaf.fill"
            case .shop: return "cart.fill"
            case .kitchen: return "fork.knife"
            case .bodyBuddy: return "figure.stand"
            case .playLearn: return "gamecontroller.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content takes all available space
            Group {
                switch selectedTab {
                case .home:
                    HomeView(avatarModel: avatarModel, selectedTab: $selectedTab)
                        .onAppear {
                            AssetPackController.shared.prefetch(.recipes)
                            ImagePrewarmer.prewarmHome()
                        }
                case .garden:
                    GardenView(selectedTab: $selectedTab, onShowFarmShop: { selectedTab = .shop })
                        .onAppear { ImagePrewarmer.prewarmGarden() }
                case .shop:
                    FarmTabView(selectedTab: $selectedTab)
                        .onAppear { ImagePrewarmer.prewarmFarm() }
                case .kitchen:
                    KitchenView(selectedTab: $selectedTab)
                case .bodyBuddy:
                    BodyBuddyView(selectedTab: $selectedTab)
                case .playLearn:
                    PlayLearnView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tab bar at bottom — hidden on Home where the image map provides
            // navigation. Other tabs need the bar to navigate back to Home.
            if selectedTab != .home {
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: gameState.pendingAIRecipe) { _, newRecipe in
            // Pip suggested an AI recipe — switch to Kitchen tab so it auto-opens
            if newRecipe != nil {
                selectedTab = .kitchen
            }
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(AnimationConstants.fadeFast) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.AppTheme.title3)
                                .frame(width: 28, height: 28)
                            Text(tab.rawValue)
                                .font(.AppTheme.rounded(size: 10, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? Color.AppTheme.goldenWheat : Color.AppTheme.lightSepia)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isLandscape ? 2 : AppSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.AppTheme.warmCream
                .shadow(color: Color.AppTheme.sepia.opacity(0.1), radius: 10, x: 0, y: -5)
                .ignoresSafeArea(.container, edges: [.bottom, .leading, .trailing])
        )
    }
}

// MARK: - Home Image Map
//
// Layered storybook map: a background (paper, misty trees, stepping-stone
// path, six empty clearings) with each location drawn as its own cut-out
// sprite on top. Each sprite IS its tap target, so the hit area always
// matches the artwork, and any one location can be redrawn on its own.
//
// Tapping a location sends Pip walking along the stepping stones to it,
// then switches tab. The walk always takes `mapWalkDuration`, and tapping
// again while Pip walks skips straight to the tab — the walk must never
// block the kid (the June UX review flagged the shop walk for exactly that).
//
// All positions are unit fractions (0..1) of the background's size, so they
// scale to any rendered width. They were eyeballed from the 2026-10-08 art;
// retune here if the art changes.
//
// Background is 1296×2304 (portrait, aspect 0.5625).

private struct HomeImageMap: View {
    @Binding var selectedTab: MainTabView.Tab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var walkTarget: MainTabView.Tab?
    @State private var walkID = UUID()
    @State private var showPipBubble = false   // the greeting opens when Pip is tapped

    // ==========================================
    // SCENE EDITOR (DEBUG pencil, top right of the map)
    // ==========================================
    // Each station's ground point (centerX, baseY), draggable like the Kitchen
    // and Garden editors. Copy the values from the panel into `locations`.
    @State private var editMode = false
    @State private var stationSpots: [SceneItem] = HomeImageMap.locations.map {
        SceneItem(id: $0.title, label: $0.title, icon: "📍", xPercent: $0.centerX, yPercent: $0.baseY)
    }

    private struct Location {
        let tab: MainTabView.Tab?          // nil = Home, the "you are here" marker
        let title: String
        let imageName: String
        let centerX: CGFloat               // sprite centre, fraction of map width
        let baseY: CGFloat                 // where the sprite's ground sits, fraction of map height
        let widthFraction: CGFloat
        let path: [CGPoint]                // stepping-stone waypoints from Home's door to here
    }

    private static let imageAspect: CGFloat = 1296.0 / 2304.0
    private static let pipSizeFraction: CGFloat = 0.23   // Pip's width as a fraction of map width

    /// Pip waits here, at the Home cottage door.
    private static let homeDoor = CGPoint(x: 0.45, y: 0.31)

    private static let greeting = "Welcome back! What would you like to do today?"

    // How much of its square frame Pip fills, and how far his feet sit above
    // the frame's bottom, in each art set. The wave fills more of its frame than
    // the walk, so the waiting Pip is drawn smaller and lifted to match the
    // walker — no size jump or hop when he sets off.
    private static let walkArtFill: CGFloat = 0.625
    private static let walkArtFoot: CGFloat = 0.18
    private static let waveArtFill: CGFloat = 0.86
    private static let waveArtFoot: CGFloat = 0.02

    // Shared stepping stones down the middle of the map, top to bottom.
    private static let spine: [CGPoint] = [
        homeDoor, CGPoint(x: 0.51, y: 0.355), CGPoint(x: 0.54, y: 0.40),
        CGPoint(x: 0.50, y: 0.45), CGPoint(x: 0.43, y: 0.50), CGPoint(x: 0.39, y: 0.55),
        CGPoint(x: 0.47, y: 0.61), CGPoint(x: 0.55, y: 0.66), CGPoint(x: 0.42, y: 0.74),
        CGPoint(x: 0.46, y: 0.79), CGPoint(x: 0.55, y: 0.84)
    ]

    private static let locations: [Location] = [
        Location(tab: nil, title: "Home", imageName: "home_loc_home",
                 centerX: 0.48, baseY: 0.29, widthFraction: 0.36, path: []),
        // Positions set in the Home scene editor (Oct 18). Each path's last point
        // keeps its old offset from the station's ground point.
        Location(tab: .bodyBuddy, title: "Body", imageName: "home_loc_body",
                 centerX: 0.29, baseY: 0.46, widthFraction: 0.24,
                 path: Array(spine[0...4]) + [CGPoint(x: 0.34, y: 0.48)]),
        Location(tab: .playLearn, title: "Play", imageName: "home_loc_play",
                 centerX: 0.73, baseY: 0.59, widthFraction: 0.34,
                 path: Array(spine[0...6]) + [CGPoint(x: 0.64, y: 0.61)]),
        Location(tab: .kitchen, title: "Kitchen", imageName: "home_loc_kitchen",
                 centerX: 0.31, baseY: 0.74, widthFraction: 0.324,
                 path: Array(spine[0...8]) + [CGPoint(x: 0.33, y: 0.76)]),
        Location(tab: .garden, title: "Garden", imageName: "home_loc_garden",
                 centerX: 0.21, baseY: 0.93, widthFraction: 0.36,
                 path: Array(spine[0...9]) + [CGPoint(x: 0.27, y: 0.90)]),
        Location(tab: .shop, title: "Shop", imageName: "home_loc_shop",
                 centerX: 0.83, baseY: 0.93, widthFraction: 0.36,
                 path: Array(spine[0...10]) + [CGPoint(x: 0.74, y: 0.90)])
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / Self.imageAspect

            ZStack(alignment: .topLeading) {
                Image("home_map_background")
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)

                ForEach(Self.locations, id: \.title) { place in
                    locationView(place, w: w, h: h)
                }

                pip(w: w, h: h)

                if editMode {
                    SceneEditorOverlay(mapWidth: w, mapHeight: h, items: $stationSpots, editMode: true)
                        .frame(width: w, height: h)
                }
            }
            .frame(width: w, height: h)
            #if DEBUG
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(AnimationConstants.springMedium) {
                        editMode.toggle()
                    }
                } label: {
                    Image(systemName: editMode ? "pencil.circle.fill" : "pencil.circle")
                        .font(.AppTheme.rounded(size: AdaptiveCardSize.kitchenHeaderIconSize(for: sizeClass)))
                        .foregroundColor(editMode ? Color.AppTheme.terracotta : Color.AppTheme.lightSepia)
                }
                .buttonStyle(.plain)
                .padding(AppSpacing.sm)
            }
            #endif
        }
        .aspectRatio(Self.imageAspect, contentMode: .fit)
        // Leaving Home mid-walk (tab bar) stops the TimelineView, so onCompleted never
        // fires — reset so Pip is back at the door and the next tap walks again.
        .onDisappear { walkTarget = nil }
    }

    // MARK: - Locations

    @ViewBuilder
    private func locationView(_ place: Location, w: CGFloat, h: CGFloat) -> some View {
        let spriteWidth = w * place.widthFraction * AdaptiveCardSize.homeStationScale(for: sizeClass)
        // The scene editor's spot wins, so a dragged station moves live.
        let spot = stationSpots.first { $0.id == place.title }
        let centerX = spot?.xPercent ?? place.centerX
        let baseY = spot?.yPercent ?? place.baseY
        let art = Image(place.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: spriteWidth)

        VStack(spacing: AppSpacing.xxs) {
            MapLabel(text: place.title, style: place.tab == nil ? .youAreHere : .destination)
            if let tab = place.tab {
                Button { go(to: tab) } label: { art }
                    .buttonStyle(BouncyButtonStyle())
                    .accessibilityLabel(place.title)
            } else {
                art.accessibilityHidden(true)
            }
        }
        // Anchor the sprite's bottom (its ground) on baseY: a full-width,
        // bottom-aligned frame ending at baseY, shifted to centerX. (.position
        // would centre the sprite on the point instead.) Empty frame space
        // doesn't take taps — only the label and art do.
        .frame(width: w, height: h * baseY, alignment: .bottom)
        .offset(x: w * (centerX - 0.5))
    }

    // MARK: - Pip

    @ViewBuilder
    private func pip(w: CGFloat, h: CGFloat) -> some View {
        let size = w * Self.pipSizeFraction
        if let target = walkTarget,
           let place = Self.locations.first(where: { $0.tab == target }) {
            let points = place.path.map { CGPoint(x: $0.x * w, y: $0.y * h - size / 2) }
            CharacterWalkingView(
                frameSet: .pipWalking,
                size: size,
                waypoints: points,
                loop: false,
                speed: Self.length(of: points) / AnimationConstants.mapWalkDuration,
                // The engine fires this from inside TimelineView's body (a view update);
                // state set there can be dropped, leaving walkTarget stuck so every later
                // tap skips the walk. Hop to the next main-actor turn first.
                onCompleted: {
                    Task { @MainActor in arrive(at: target) }
                }
            )
            .id(walkID)
            .allowsHitTesting(false)
        } else {
            // Waiting at the door: the wave, matched to the walker's size and
            // footing. Tapping him opens his greeting beside him.
            let waveSize = size * Self.walkArtFill / Self.waveArtFill
            let feetY = h * Self.homeDoor.y - size * Self.walkArtFoot
            let center = CGPoint(x: w * Self.homeDoor.x,
                                 y: feetY + waveSize * Self.waveArtFoot - waveSize / 2)
            PipWavingAnimatedView(size: .custom(waveSize))
                .contentShape(Rectangle())
                .pipTapMeTag(isShown: !showPipBubble)
                .onTapGesture { showPipBubble = true }
                .position(center)
            if showPipBubble {
                PipFloatingBubble(
                    anchor: center,
                    sceneWidth: w,
                    pipHalfWidth: waveSize / 2,
                    sizeClass: sizeClass,
                    message: Self.greeting,
                    onClose: { showPipBubble = false }
                )
            }
        }
    }

    // MARK: - Navigation

    private func go(to tab: MainTabView.Tab) {
        // Second tap while Pip walks, or Reduce Motion: no walk, go now.
        if walkTarget != nil || reduceMotion {
            arrive(at: tab)
            return
        }
        walkID = UUID()
        walkTarget = tab
    }

    private func arrive(at tab: MainTabView.Tab) {
        walkTarget = nil
        selectedTab = tab
    }

    private static func length(of points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            total + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
    }
}

private struct MapLabel: View {
    enum Style { case destination, youAreHere }
    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(DeviceInfo.isIPad
                  ? .AppTheme.title.weight(.bold)
                  : .AppTheme.subheadline.weight(.bold))
            .foregroundColor(style == .youAreHere ? Color.AppTheme.goldenWheat : Color.AppTheme.darkBrown)
    }
}

#Preview("Home Image Map") {
    @Previewable @State var tab: MainTabView.Tab = .home
    return HomeImageMap(selectedTab: $tab)
        .padding()
        .background(Color.AppTheme.cream)
}

// MARK: - Home View (Simple Layout for iPhone)
struct HomeView: View {
    @ObservedObject var avatarModel: AvatarModel
    @Binding var selectedTab: MainTabView.Tab
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.modelContext) private var modelContext
    @State private var showSwitchConfirm = false
    @State private var showPINForDashboard = false
    @State private var selectedSibling: UserProfile?
    @State private var showAskPip = false

    // Unseen help messages for the current player
    private var newHelpMessages: [HelpEntry]? {
        guard let profile = sessionManager.activeProfile,
              let data = profile.playerData(in: modelContext) else { return nil }
        let unseen = Array(data.receivedHelp.dropFirst(data.lastSeenHelpCount))
        return unseen.isEmpty ? nil : unseen
    }

    private func dismissHelpMessages() {
        guard let profile = sessionManager.activeProfile,
              let data = profile.playerData(in: modelContext) else { return }
        data.lastSeenHelpCount = data.receivedHelp.count
        do { try modelContext.save() } catch { print("[ChefAcademyApp] dismissHelpMessages save failed: \(error)") }
    }

    private var siblings: [UserProfile] {
        guard let family = sessionManager.familyProfile,
              let activeID = sessionManager.activeProfile?.id else { return [] }
        return family.childProfiles(in: modelContext).filter { $0.id != activeID }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {

                // Header: Row 1 = greeting + avatar, Row 2 = stats
                VStack(alignment: .leading, spacing: AppSpacing.sm) {

                    // Row 1: Greeting text + Avatar on the right
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greetingMessage)
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.sepia)

                            Text("Chef \(avatarModel.name.isEmpty ? "Little Chef" : avatarModel.name)!")
                                .font(.AppTheme.title)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        }

                        Spacer()

                        // Avatar - clipped to fixed frame
                        ZStack {
                            Circle()
                                .fill(Color.AppTheme.parchment)
                                .frame(width: 96, height: 96)
                            AvatarPreviewView(avatarModel: avatarModel)
                                .scaleEffect(0.36)
                                .frame(width: 96, height: 96)
                                .clipped()
                        }
                        .frame(width: 96, height: 96)
                    }

                    // Row 2: Level + Coins + XP chips
                    HStack(spacing: AppSpacing.xs) {
                        // Level chip
                        Label {
                            Text("Lv. \(gameState.playerLevel)")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundColor(Color.AppTheme.goldenWheat)
                                .font(.AppTheme.microLarge)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(14)

                        // Coins chip
                        Label {
                            Text("\(gameState.coins)")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .foregroundColor(Color.AppTheme.goldenWheat)
                                .font(.AppTheme.microLarge)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(14)

                        // XP chip
                        Label {
                            Text("\(gameState.xp) XP")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        } icon: {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(Color.AppTheme.sage)
                                .font(.AppTheme.microLarge)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(14)

                        // Voice on/off — saves ElevenLabs credits when testing
                        PipVoiceToggleChip()

                        Spacer()
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Streak Card
                StreakCard(streak: avatarModel.currentStreak)
                    .padding(.horizontal, AppSpacing.md)

                // Map — universal across iPhone + iPad. Fills available width so
                // the artwork dominates the layout on both devices. Pip greets the
                // kid from the map (his bubble at the Home door), not a separate card.
                HomeImageMap(selectedTab: $selectedTab)
                    .padding(.horizontal, AppSpacing.md)

                // Help received messages
                if let helpMessages = newHelpMessages, !helpMessages.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Garden Help!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        ForEach(Array(helpMessages.enumerated()), id: \.offset) { _, entry in
                            HStack(spacing: AppSpacing.sm) {
                                Text(CareAction(rawValue: entry.actionRaw)?.emoji ?? "🌱")
                                    .font(.AppTheme.rounded(size: 24))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(entry.helperName) \(CareAction(rawValue: entry.actionRaw)?.displayVerb ?? "helped") your \(VegetableType(rawValue: entry.vegetableRaw)?.displayName ?? "plant")!")
                                        .font(.AppTheme.subheadline)
                                        .foregroundColor(Color.AppTheme.darkBrown)

                                    Text(entry.timestamp, style: .relative)
                                        .font(.AppTheme.caption)
                                        .foregroundColor(Color.AppTheme.sepia)
                                }
                                Spacer()
                            }
                            .padding(AppSpacing.sm)
                            .background(Color.AppTheme.warmCream)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                        }

                        Button("Dismiss") {
                            dismissHelpMessages()
                        }
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sage)
                    }
                    .padding(.horizontal, AppSpacing.md)
                }

                // Visit Sibling's Garden
                if !siblings.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Visit a Friend's Garden")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.md) {
                                ForEach(siblings, id: \.id) { sibling in
                                    Button(action: { selectedSibling = sibling }) {
                                        VStack(spacing: 6) {
                                            Image(sibling.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 90, height: 90)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.AppTheme.sage, lineWidth: 2.5)
                                                )
                                            Text(sibling.name)
                                                .font(.AppTheme.subheadline)
                                                .foregroundColor(Color.AppTheme.darkBrown)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }

                // Profile Actions
                VStack(spacing: AppSpacing.sm) {
                    Button(action: { showSwitchConfirm = true }) {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Switch Player")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                        .softCard(showShadow: false)
                    }
                    .buttonStyle(.plain)

                    if let profile = sessionManager.activeProfile {
                        if profile.isParent {
                            Button(action: {
                                sessionManager.route = .parentDashboard
                            }) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Parent Dashboard")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sage)
                                .softCard(showShadow: false)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { showPINForDashboard = true }) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Parent Dashboard")
                                    Image(systemName: "lock.fill")
                                        .font(.AppTheme.caption)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sage)
                                .softCard(showShadow: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Bottom spacing for tab bar
                Spacer().frame(height: AppSpacing.lg)
            }
            .padding(.top, AppSpacing.md)
        }
        .background(Color.AppTheme.cream)
        .alert("Switch Player?", isPresented: $showSwitchConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Switch") {
                sessionManager.switchToProfilePicker(gameState: gameState, avatarModel: avatarModel)
            }
        } message: {
            Text("Your progress will be saved.")
        }
        .fullScreenCover(isPresented: $showPINForDashboard) {
            ParentPINEntryView(
                purpose: .openDashboard,
                onSuccess: {
                    showPINForDashboard = false
                    sessionManager.route = .parentDashboard
                },
                onCancel: { showPINForDashboard = false }
            )
            .environmentObject(sessionManager)
        }
        .fullScreenCover(item: $selectedSibling) { sibling in
            SiblingProfileView(
                sibling: sibling,
                visitorGameState: gameState,
                onBack: { selectedSibling = nil }
            )
        }
        .sheet(isPresented: $showAskPip) {
            AskPipView()
        }
    }

    var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        case 17..<21: return "Good Evening,"
        default: return "Hello,"
        }
    }
}

// MARK: - Streak Card
struct StreakCard: View {
    let streak: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🔥 Daily Streak")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
                
                Text("\(streak) days")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.goldenWheat)
            }
            
            Spacer()
            
            // Streak flames
            HStack(spacing: -5) {
                ForEach(0..<min(streak, 7), id: \.self) { _ in
                    Text("🔥")
                        .font(.AppTheme.title3)
                }
            }
        }
        .softCard(showShadow: false)
    }
}

// MARK: - Quick Action Card (iPad Responsive) - Now a Button!
struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    var isLarge: Bool = false  // For iPad
    var action: (() -> Void)? = nil  // Optional tap action

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: isLarge ? AppSpacing.md : AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(
                            width: isLarge ? 80 : 60,
                            height: isLarge ? 80 : 60
                        )

                    Text(icon)
                        .font(.AppTheme.rounded(size: isLarge ? 40 : 30))
                }

                Text(title)
                    .font(isLarge ? .AppTheme.body : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: isLarge ? 120 : 90)
            .padding(isLarge ? AppSpacing.md : AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Card with Background Image
struct QuickActionCardWithBg: View {
    let title: String
    let imageName: String
    let color: Color
    var isLarge: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: isLarge ? AppSpacing.md : AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(
                            width: isLarge ? 80 : 60,
                            height: isLarge ? 80 : 60
                        )

                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: isLarge ? 70 : 50,
                            height: isLarge ? 70 : 50
                        )
                        .clipShape(Circle())
                }

                Text(title)
                    .font(isLarge ? .AppTheme.body : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: isLarge ? 120 : 90)
            .padding(isLarge ? AppSpacing.md : AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder View
struct PlaceholderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text(title)
                .font(.AppTheme.largeTitle)
            Text(subtitle)
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.AppTheme.cream)
    }
}

// MARK: - Preview
//
// Previews let you see your UI without running the full app!
// We need to provide the environment objects so the preview works.
//
#Preview {
    MainTabView(avatarModel: {
        let model = AvatarModel()
        model.name = "Emma"
        model.currentStreak = 5
        return model
    }())
    .environmentObject(GameState.preview) // Use the preview helper we created!
}

