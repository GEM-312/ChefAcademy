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

@main
struct ChefAcademyApp: App {
    // The four core state objects shared across the entire app
    @StateObject private var avatarModel = AvatarModel()
    @StateObject private var gameState = GameState()
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var authManager = AuthManager()

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
        if let container = try? ModelContainer(
            for: FamilyProfile.self, UserProfile.self, PlayerData.self
        ) {
            modelContainer = container
            return
        }

        // If that failed, delete the old store and retry
        print("[ChefAcademy] First ModelContainer attempt failed — deleting old store and retrying...")
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
                }
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        sessionManager.bootstrap(
                            context: modelContainer.mainContext,
                            authManager: authManager
                        )
                    }

                    gameState.startAutoSave()

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
                        PipWavingAnimatedView(size: 120)
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
        .animation(.easeInOut(duration: 0.3), value: sessionManager.route)
    }
}
// MARK: - Main Tab View
struct MainTabView: View {
    @ObservedObject var avatarModel: AvatarModel
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
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .home:
                    HomeView(avatarModel: avatarModel, selectedTab: $selectedTab)
                case .garden:
                    GardenView(selectedTab: $selectedTab, onShowFarmShop: { selectedTab = .shop })
                case .shop:
                    FarmTabView()
                case .kitchen:
                    KitchenView()
                case .bodyBuddy:
                    BodyBuddyView(selectedTab: $selectedTab)
                case .playLearn:
                    PlayLearnView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22))
                            Text(tab.rawValue)
                                .font(.AppTheme.caption)
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

// MARK: - Home View (Simple Layout for iPhone)
struct HomeView: View {
    @ObservedObject var avatarModel: AvatarModel
    @Binding var selectedTab: MainTabView.Tab
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRecipe: Recipe? = nil
    @State private var showSwitchConfirm = false
    @State private var showPINForDashboard = false
    @State private var selectedSibling: UserProfile?
    @State private var showAskPip = false

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
                                .font(.system(size: 11))
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
                                .font(.system(size: 11))
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
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(14)

                        Spacer()
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Streak Card
                StreakCard(streak: avatarModel.currentStreak)
                    .padding(.horizontal, AppSpacing.md)

                // Pip's Message
                PipMessageCard(
                    message: "Welcome back! Ready to cook something delicious today?",
                    avatarModel: avatarModel
                )
                .padding(.horizontal, AppSpacing.md)

                // Quick Actions
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("What would you like to do?")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .padding(.horizontal, AppSpacing.md)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.md) {
                            QuickActionCardWithBg(title: "Visit Garden", imageName: "bg_garden", color: Color.AppTheme.sage, action: { selectedTab = .garden })
                            QuickActionCardWithBg(title: "Cook Recipe", imageName: "bg_kitchen", color: Color.AppTheme.goldenWheat, action: { selectedTab = .kitchen })
                            QuickActionCard(icon: "🛒", title: "Farm Shop", color: Color.AppTheme.terracotta, action: { selectedTab = .shop })
                            QuickActionCard(icon: "🫀", title: "Body Buddy", color: .red.opacity(0.7), action: { selectedTab = .bodyBuddy })
                            QuickActionCard(icon: "🎮", title: "Play Games", color: .purple.opacity(0.7), action: { selectedTab = .playLearn })
                            QuickActionCard(icon: "💬", title: "Ask Pip!", color: Color.AppTheme.sage, action: { showAskPip = true })
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                }

                // Today's Recipe
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Text("Today's Recipe")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        Spacer()

                        Button(action: { selectedTab = .kitchen }) {
                            HStack(spacing: 4) {
                                Text("See All")
                                    .font(.AppTheme.subheadline)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                        .buttonStyle(.plain)
                    }

                    let todaysRecipe = GardenRecipes.all.first(where: { $0.id == "chicken-veggie-platter" }) ?? GardenRecipes.all[0]
                    RecipeCardView(recipe: todaysRecipe)
                        .onTapGesture { selectedRecipe = todaysRecipe }
                }
                .padding(.horizontal, AppSpacing.md)

                // Visit Sibling's Garden
                if !siblings.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Visit a Friend's Garden")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(siblings, id: \.id) { sibling in
                                    Button(action: { selectedSibling = sibling }) {
                                        VStack(spacing: 4) {
                                            Image(sibling.gender == .boy ? "boy_card_frame_28" : "girl_card_frame_15")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.AppTheme.sage, lineWidth: 2)
                                                )
                                            Text(sibling.name)
                                                .font(.AppTheme.caption)
                                                .foregroundColor(Color.AppTheme.darkBrown)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
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
                        .padding(AppSpacing.md)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
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
                                .padding(AppSpacing.md)
                                .background(Color.AppTheme.warmCream)
                                .cornerRadius(AppSpacing.cardCornerRadius)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { showPINForDashboard = true }) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Parent Dashboard")
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sage)
                                .padding(AppSpacing.md)
                                .background(Color.AppTheme.warmCream)
                                .cornerRadius(AppSpacing.cardCornerRadius)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Bottom spacing for tab bar
                Spacer().frame(height: 100)
            }
            .padding(.top, AppSpacing.md)
        }
        .background(Color.AppTheme.cream)
        .fullScreenCover(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe) {
                selectedTab = .kitchen
            }
        }
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
                        .font(.system(size: 20))
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
}

// MARK: - Pip Message Card
struct PipMessageCard: View {
    let message: String
    @ObservedObject var avatarModel: AvatarModel

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Animated Pip waving (frame animation, transparent bg)
            PipWavingAnimatedView(size: 120)

            // Message bubble
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)

                Text(message)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
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
                        .font(.system(size: isLarge ? 40 : 30))
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

