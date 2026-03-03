//
//  ParentDashboardView.swift
//  ChefAcademy
//
//  Parent-only view showing child stats and family management.
//

import SwiftUI
import SwiftData

struct ParentDashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var avatarModel: AvatarModel
    @Environment(\.modelContext) private var modelContext

    @State private var selectedChildID: UUID?
    @State private var showRemoveConfirmation = false
    @State private var childToRemove: UserProfile?
    @State private var showChangePIN = false
    @State private var showAddChild = false

    private var children: [UserProfile] {
        guard let family = sessionManager.familyProfile else { return [] }
        return family.childProfiles(in: modelContext)
    }

    private var selectedChild: UserProfile? {
        children.first { $0.id == selectedChildID }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Parent Dashboard")
                            .font(.AppTheme.largeTitle)
                            .foregroundColor(Color.AppTheme.darkBrown)
                        Text("See how your little chefs are doing!")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                // Child selector
                if !children.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(children, id: \.id) { child in
                                DashboardChildTab(
                                    profile: child,
                                    isSelected: selectedChildID == child.id
                                ) {
                                    withAnimation { selectedChildID = child.id }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                }

                // Stats for selected child
                if let child = selectedChild, let data = child.playerData(in: modelContext) {
                    VStack(spacing: AppSpacing.md) {
                        // Stats grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: AppSpacing.md) {
                            StatCard(title: "Level", value: "\(data.playerLevel)", icon: "star.fill", color: Color.AppTheme.goldenWheat)
                            StatCard(title: "Coins", value: "\(data.coins)", icon: "circle.fill", color: Color.AppTheme.goldenWheat)
                            StatCard(title: "XP", value: "\(data.xp)", icon: "bolt.fill", color: Color.AppTheme.sage)
                            StatCard(title: "Recipes", value: "\(data.recipeStars.count)", icon: "fork.knife", color: Color.AppTheme.terracotta)
                            StatCard(title: "Stars", value: "\(data.recipeStars.reduce(0) { $0 + $1.stars })", icon: "star.fill", color: Color.AppTheme.goldenWheat)
                            StatCard(title: "Veggies", value: "\(data.harvestedData.map(\.quantity).reduce(0, +))", icon: "leaf.fill", color: Color.AppTheme.sage)
                        }

                        // Time played
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(Color.AppTheme.sage)
                            Text("Time played: \(child.formattedPlayTime)")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                            Spacer()
                        }
                        .padding(AppSpacing.md)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)

                        // Last played
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(Color.AppTheme.sage)
                            Text("Last played: \(child.lastPlayedDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                            Spacer()
                        }
                        .padding(AppSpacing.md)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)

                        // Remove profile button
                        Button(action: {
                            childToRemove = child
                            showRemoveConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove \(child.name)'s Profile")
                            }
                            .font(.AppTheme.body)
                            .foregroundColor(.red.opacity(0.8))
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(AppSpacing.cardCornerRadius)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                } else if children.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Text("No little chefs yet!")
                            .font(.AppTheme.title2)
                            .foregroundColor(Color.AppTheme.sepia)
                        Text("Add a child profile to get started.")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.lightSepia)
                    }
                    .padding(.top, AppSpacing.xxl)
                }

                // Family Management
                VStack(spacing: AppSpacing.sm) {
                    Text("Family Settings")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let family = sessionManager.familyProfile, family.canAddChild(in: modelContext) {
                        Button(action: { showAddChild = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Little Chef")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sage)
                            .padding(AppSpacing.md)
                            .background(Color.AppTheme.warmCream)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                        }
                    }

                    Button(action: { showChangePIN = true }) {
                        HStack {
                            Image(systemName: "lock.rotation")
                            Text("Change Parent PIN")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                        .padding(AppSpacing.md)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Back to game
                Button(action: {
                    if let profile = sessionManager.activeProfile {
                        sessionManager.route = .mainApp(profile.id)
                    } else {
                        sessionManager.route = .profilePicker
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back to Game")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, AppSpacing.md)

                Spacer().frame(height: 40)
            }
            .padding(.top, AppSpacing.md)
        }
        .background(Color.AppTheme.cream)
        .onAppear {
            if selectedChildID == nil {
                selectedChildID = children.first?.id
            }
        }
        .alert("Remove Profile?", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { childToRemove = nil }
            Button("Remove", role: .destructive) {
                if let child = childToRemove {
                    sessionManager.removeChildProfile(child)
                    selectedChildID = children.first?.id
                }
                childToRemove = nil
            }
        } message: {
            if let child = childToRemove {
                Text("Remove \(child.name)'s profile? Their garden and recipes will be lost.")
            }
        }
        .fullScreenCover(isPresented: $showChangePIN) {
            ParentPINEntryView(
                purpose: .changePIN,
                isSetupMode: true,
                onSuccess: { showChangePIN = false },
                onCancel: { showChangePIN = false }
            )
            .environmentObject(sessionManager)
        }
        .fullScreenCover(isPresented: $showAddChild) {
            AddChildFlowView()
                .environmentObject(sessionManager)
                .environmentObject(gameState)
                .environmentObject(avatarModel)
        }
    }
}

// MARK: - Dashboard Child Tab

struct DashboardChildTab: View {
    let profile: UserProfile
    let isSelected: Bool
    let onTap: () -> Void

    private var characterImage: String {
        profile.gender == .boy ? "boy_card_frame_28" : "girl_card_frame_15"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(characterImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.AppTheme.goldenWheat : Color.clear, lineWidth: 2)
                    )

                Text(profile.name)
                    .font(.AppTheme.caption)
                    .foregroundColor(isSelected ? Color.AppTheme.darkBrown : Color.AppTheme.sepia)
            }
            .padding(AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)

            Text(value)
                .font(.AppTheme.title2)
                .foregroundColor(Color.AppTheme.darkBrown)

            Text(title)
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }
}

#Preview {
    ParentDashboardView()
        .environmentObject(SessionManager())
        .environmentObject(GameState())
        .environmentObject(AvatarModel())
}
