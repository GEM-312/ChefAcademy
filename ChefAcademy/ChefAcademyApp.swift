//
//  ChefAcademyApp.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

import SwiftUI
import SwiftData
import Combine

@main
struct ChefAcademyApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    // @StateObject creates the object ONCE and keeps it alive
    // This is the "brain" of your game - all data lives here!
    @StateObject private var avatarModel = AvatarModel()
    @StateObject private var gameState = GameState()

    // SwiftData container for persisting player progress
    private let modelContainer: ModelContainer

    // Set to true to test Pip images, false for normal app flow
    private let showPipTest = false

    // TEMPORARY: Set to true to reset onboarding for testing, then set back to false
    private let resetOnboarding = true

    init() {
        if resetOnboarding {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "userName")
        }

        // Create SwiftData container for PlayerData
        do {
            modelContainer = try ModelContainer(for: PlayerData.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showPipTest {
                    // TEMPORARY: Show PipTestView to check all Pip images
                    PipTestView()
                } else if hasCompletedOnboarding {
                    // Main app view
                    MainTabView(avatarModel: avatarModel)
                        // .environmentObject() makes gameState available to ALL child views
                        // Any view can access it with @EnvironmentObject var gameState: GameState
                        .environmentObject(gameState)
                } else {
                    OnboardingView(
                        avatarModel: avatarModel,
                        isOnboardingComplete: $hasCompletedOnboarding
                    )
                    .environmentObject(gameState)
                }
            }
            .onAppear {
                // Wire SwiftData to GameState and load saved progress
                if gameState.modelContext == nil {
                    gameState.modelContext = modelContainer.mainContext
                    gameState.loadFromStore()
                    gameState.startAutoSave()
                }
            }
        }
    }
}
// MARK: - Main Tab View
struct MainTabView: View {
    @ObservedObject var avatarModel: AvatarModel
    @State private var selectedTab: Tab = .home
    
    enum Tab: String, CaseIterable {
        case home = "Home"
        case garden = "Garden"
        case kitchen = "Kitchen"
        case farm = "Farm"
        case recipes = "Recipes"
        case profile = "Me"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .garden: return "leaf.fill"
            case .kitchen: return "fork.knife"
            case .farm: return "cart.fill"
            case .recipes: return "book.fill"
            case .profile: return "person.fill"
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
                    GardenView(selectedTab: $selectedTab) // Our garden!
                case .kitchen:
                    KitchenView() // Pip's Kitchen - cook recipes!
                case .farm:
                    FarmTabView() // Pip walks to barn, then Farm Shop!
                case .recipes:
                    RecipeListView(selectedTab: $selectedTab) // Browse all recipes
                case .profile:
                    PlaceholderView(title: "👤 My Profile", subtitle: "Coming soon!")
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
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
        }
        .background(
            Color.AppTheme.warmCream
                .shadow(color: Color.AppTheme.sepia.opacity(0.1), radius: 10, x: 0, y: -5)
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }
}

// MARK: - Home View (Simple Layout for iPhone)
struct HomeView: View {
    @ObservedObject var avatarModel: AvatarModel
    @Binding var selectedTab: MainTabView.Tab
    @EnvironmentObject var gameState: GameState
    @State private var selectedRecipe: Recipe? = nil

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
                            QuickActionCard(icon: "🛒", title: "Farm Shop", color: Color.AppTheme.terracotta, action: { selectedTab = .farm })
                            QuickActionCard(icon: "🏆", title: "My Badges", color: Color.AppTheme.sage, action: { selectedTab = .profile })
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

                        Button(action: { selectedTab = .recipes }) {
                            HStack(spacing: 4) {
                                Text("See All")
                                    .font(.AppTheme.subheadline)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                    }

                    let todaysRecipe = GardenRecipes.all.first(where: { $0.id == "chicken-veggie-platter" }) ?? GardenRecipes.all[0]
                    RecipeCardView(recipe: todaysRecipe)
                        .onTapGesture { selectedRecipe = todaysRecipe }
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

