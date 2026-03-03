//
//  ProfilePickerView.swift
//  ChefAcademy
//
//  "Who's playing today?" — profile selection at launch.
//

import SwiftUI
import SwiftData

struct ProfilePickerView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var avatarModel: AvatarModel
    @Environment(\.modelContext) private var modelContext

    @State private var showPINEntry = false
    @State private var pinPurpose: PINPurpose = .selectParentProfile
    @State private var pendingParentProfile: UserProfile?
    @State private var showAddChildFlow = false

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Pip waving
                PipWavingAnimatedView(size: 120)

                Text("Who's playing today?")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)

                // Profile cards
                if let family = sessionManager.familyProfile {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.md) {
                            // Parent card
                            if let parent = family.parentProfile(in: modelContext) {
                                ProfileCard(
                                    profile: parent,
                                    isParent: true,
                                    allProfiles: family.members(in: modelContext)
                                ) {
                                    pendingParentProfile = parent
                                    pinPurpose = .selectParentProfile
                                    showPINEntry = true
                                }
                            }

                            // Child cards
                            ForEach(family.childProfiles(in: modelContext), id: \.id) { child in
                                ProfileCard(
                                    profile: child,
                                    isParent: false,
                                    allProfiles: family.members(in: modelContext)
                                ) {
                                    sessionManager.selectProfile(child, gameState: gameState, avatarModel: avatarModel)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                }

                Spacer()

                // Add child button (PIN-gated)
                if let family = sessionManager.familyProfile, family.canAddChild(in: modelContext) {
                    Button(action: {
                        pinPurpose = .addChild
                        showPINEntry = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Little Chef")
                        }
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.sage)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                }

                Spacer().frame(height: AppSpacing.xxl)
            }
        }
        .fullScreenCover(isPresented: $showPINEntry) {
            ParentPINEntryView(
                purpose: pinPurpose,
                onSuccess: {
                    showPINEntry = false
                    handlePINSuccess()
                },
                onCancel: {
                    showPINEntry = false
                    pendingParentProfile = nil
                }
            )
            .environmentObject(sessionManager)
        }
        .fullScreenCover(isPresented: $showAddChildFlow) {
            AddChildFlowView()
                .environmentObject(sessionManager)
                .environmentObject(gameState)
                .environmentObject(avatarModel)
        }
    }

    private func handlePINSuccess() {
        switch pinPurpose {
        case .selectParentProfile:
            if let parent = pendingParentProfile {
                sessionManager.selectProfile(parent, gameState: gameState, avatarModel: avatarModel)
            }
            pendingParentProfile = nil
        case .addChild:
            showAddChildFlow = true
        case .openDashboard:
            sessionManager.route = .parentDashboard
        case .changePIN:
            break
        }
    }
}

// MARK: - Profile Card

struct ProfileCard: View {
    let profile: UserProfile
    let isParent: Bool
    let allProfiles: [UserProfile]
    let onTap: () -> Void

    private var characterImage: String {
        profile.gender == .boy ? "boy_card_frame_28" : "girl_card_frame_15"
    }

    private var isLastPlayed: Bool {
        guard let mostRecent = allProfiles.max(by: { $0.lastPlayedDate < $1.lastPlayedDate }) else {
            return false
        }
        return mostRecent.id == profile.id
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.sm) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.AppTheme.parchment)
                        .frame(width: 90, height: 90)

                    Image(characterImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                    // Crown for parent
                    if isParent {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .offset(y: -50)
                    }

                    // Lock icon for parent
                    if isParent {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.AppTheme.sepia)
                            .padding(6)
                            .background(Color.AppTheme.warmCream)
                            .clipShape(Circle())
                            .offset(x: 35, y: 35)
                    }
                }

                // Name
                Text(profile.name.isEmpty ? (isParent ? "Parent" : "Player") : profile.name)
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)

                // Last played badge
                if isLastPlayed {
                    Text("Last played")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sage)
                }
            }
            .frame(width: 120)
            .padding(AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let manager = SessionManager()
    return ProfilePickerView()
        .environmentObject(manager)
        .environmentObject(GameState())
        .environmentObject(AvatarModel())
}
