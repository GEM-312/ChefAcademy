//
//  ChefAcademyApp.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

import SwiftUI
import Combine

@main
struct ChefAcademyApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    // @StateObject creates the object ONCE and keeps it alive
    // This is the "brain" of your game - all data lives here!
    @StateObject private var avatarModel = AvatarModel()
    @StateObject private var gameState = GameState()

    // Set to true to test Pip images, false for normal app flow
    private let showPipTest = false

    // TEMPORARY: Set to true to reset onboarding for testing, then set back to false
    private let resetOnboarding = true

    init() {
        if resetOnboarding {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "userName")
        }
    }

    var body: some Scene {
        WindowGroup {
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
    }
}
// MARK: - Main Tab View
struct MainTabView: View {
    @ObservedObject var avatarModel: AvatarModel
    @State private var selectedTab: Tab = .home
    
    enum Tab: String, CaseIterable {
        case home = "Home"
        case garden = "Garden"
        case recipes = "Recipes"
        case play = "Play"
        case profile = "Me"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .garden: return "leaf.fill"
            case .recipes: return "book.fill"
            case .play: return "gamecontroller.fill"
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
                    GardenView() // Our new garden!
                case .recipes:
                    RecipeListView()
                case .play:
                    PlaceholderView(title: "🎮 Learn & Play", subtitle: "Coming soon!")
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {

                // Header with greeting and coins
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greetingMessage)
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.sepia)
                            .lineLimit(1)

                        Text("Chef \(avatarModel.name.isEmpty ? "Little Chef" : avatarModel.name)!")
                            .font(.AppTheme.title)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)

                    Spacer()

                    // Coin display
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.system(size: 14))
                        Text("\(gameState.coins)")
                            .font(.AppTheme.subheadline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(16)

                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.AppTheme.parchment)
                            .frame(width: 44, height: 44)
                        AvatarPreviewView(avatarModel: avatarModel)
                            .scaleEffect(0.18)
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
                            QuickActionCard(icon: "🌱", title: "Visit Garden", color: Color.AppTheme.sage, action: { selectedTab = .garden })
                            QuickActionCard(icon: "🍳", title: "Cook Recipe", color: Color.AppTheme.goldenWheat, action: { selectedTab = .recipes })
                            QuickActionCard(icon: "🎮", title: "Play & Learn", color: Color.AppTheme.terracotta, action: { selectedTab = .play })
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

                    RecipeCardView(
                        recipe: Recipe(
                            title: "Rainbow Veggie Wrap",
                            description: "A colorful, crunchy wrap packed with fresh vegetables and hummus",
                            imageName: "recipe_wrap_rainbow_veggie",
                            category: .lunch,
                            cookTime: 15,
                            difficulty: .easy,
                            servings: 2,
                            needsAdultHelp: false,
                            nutritionFacts: ["Vitamin A", "Fiber", "Protein"]
                        )
                    )
                    .onTapGesture { selectedTab = .recipes }
                }
                .padding(.horizontal, AppSpacing.md)

                // Bottom spacing for tab bar
                Spacer().frame(height: 100)
            }
            .padding(.top, AppSpacing.md)
        }
        .background(Color.AppTheme.cream)
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
            // Pip Video Animation - small size for message card
            VideoPlayerWithFallback(
                videoName: "pip_waving",
                fallbackImage: "pip_waving",
                size: 60,
                circular: true,
                borderColor: Color.AppTheme.sage,
                borderWidth: 2
            )

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

