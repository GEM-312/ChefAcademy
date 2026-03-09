//
//  ProfileView.swift
//  ChefAcademy
//
//  Me tab content — shows player stats, badges, and profile actions.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var avatarModel: AvatarModel
    @Binding var selectedTab: MainTabView.Tab

    @State private var showDashboard = false
    @State private var showPINForDashboard = false
    @State private var showSwitchConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                // Avatar + Name header
                VStack(spacing: AppSpacing.sm) {
                    AvatarPreviewView(avatarModel: avatarModel)
                        .frame(height: 180)

                    Text(avatarModel.name.isEmpty ? "Little Chef" : avatarModel.name)
                        .font(.AppTheme.largeTitle)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    // Level badge
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "star.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                        Text("Level \(gameState.playerLevel)")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(20)
                }
                .padding(.top, AppSpacing.md)

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppSpacing.md) {
                    StatCard(title: "Coins", value: "\(gameState.coins)", icon: "circle.fill", color: Color.AppTheme.goldenWheat)
                    StatCard(title: "XP", value: "\(gameState.xp)", icon: "bolt.fill", color: Color.AppTheme.sage)
                    StatCard(title: "Recipes", value: "\(gameState.recipeStars.count)", icon: "fork.knife", color: Color.AppTheme.terracotta)
                    StatCard(title: "Veggies", value: "\(totalVeggiesGrown)", icon: "leaf.fill", color: Color.AppTheme.sage)
                }
                .padding(.horizontal, AppSpacing.md)

                // Play time
                if let profile = sessionManager.activeProfile {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Color.AppTheme.sage)
                        Text("Time played: \(profile.formattedPlayTime)")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.cardCornerRadius)
                    .padding(.horizontal, AppSpacing.md)
                }

                // Badges earned
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Badges Earned")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    if gameState.completedBadgeIDs.isEmpty {
                        Text("No badges yet. Keep playing to earn some!")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.lightSepia)
                    } else {
                        Text("\(gameState.completedBadgeIDs.count) badges earned")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.cardCornerRadius)
                .padding(.horizontal, AppSpacing.md)

                // Actions
                VStack(spacing: AppSpacing.sm) {
                    // Switch Player
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

                    // Parent Dashboard (only show for parents, or require PIN for children)
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

                Spacer().frame(height: 100) // Tab bar space
            }
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
    }

    private var totalVeggiesGrown: Int {
        gameState.harvestedIngredients.map(\.quantity).reduce(0, +)
    }
}

#Preview {
    ProfileView(selectedTab: .constant(.home))
        .environmentObject(SessionManager())
        .environmentObject(GameState.preview)
        .environmentObject(AvatarModel())
}
