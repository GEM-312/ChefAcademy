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
    @State private var refreshKey = UUID()

    // Scale factor: 1x on iPhone, ~2.5x on iPad
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    private var pipSize: CGFloat { isIPad ? 280 : 120 }

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            VStack(spacing: isIPad ? AppSpacing.xl : AppSpacing.lg) {
                Spacer()

                // Pip waving — 280pt on iPad, 120pt on iPhone
                PipWavingAnimatedView(size: pipSize)

                Text("Who's playing today?")
                    .font(isIPad ? .system(size: 40, weight: .bold, design: .rounded) : .AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)

                // Profile cards
                if let family = sessionManager.familyProfile {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isIPad ? AppSpacing.lg : AppSpacing.md) {
                            // Parent card
                            if let parent = family.parentProfile(in: modelContext) {
                                ProfileCard(
                                    profile: parent,
                                    isParent: true
                                ) {
                                    pendingParentProfile = parent
                                    pinPurpose = .selectParentProfile
                                    showPINEntry = true
                                }
                            }

                            // Child cards — .id(refreshKey) forces re-fetch after adding
                            ForEach(family.childProfiles(in: modelContext), id: \.id) { child in
                                ProfileCard(
                                    profile: child,
                                    isParent: false
                                ) {
                                    sessionManager.selectProfile(child, gameState: gameState, avatarModel: avatarModel)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    .trailingFade()
                    .id(refreshKey)
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
                        .font(isIPad ? .system(size: 22, weight: .semibold, design: .rounded) : .AppTheme.headline)
                        .foregroundColor(Color.AppTheme.sage)
                        .padding(.horizontal, isIPad ? AppSpacing.xl : AppSpacing.lg)
                        .padding(.vertical, isIPad ? AppSpacing.md : AppSpacing.sm)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .buttonStyle(.plain)
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
        .onChange(of: showAddChildFlow) { _, isShowing in
            if !isShowing {
                // Force re-fetch child profiles after AddChildFlowView dismisses
                refreshKey = UUID()
            }
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
    let onTap: () -> Void

    // Scale for iPad — everything ~2.5x bigger
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    private var avatarSize: CGFloat { isIPad ? 200 : 80 }
    private var circleSize: CGFloat { isIPad ? 220 : 90 }
    private var cardWidth: CGFloat { isIPad ? 280 : 120 }

    private var characterImage: String {
        profile.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.AppTheme.parchment)
                        .frame(width: circleSize, height: circleSize)

                    Image(characterImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())

                    // Crown for parent
                    if isParent {
                        Image(systemName: "crown.fill")
                            .font(.AppTheme.rounded(size: isIPad ? 36 : 18))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .offset(y: isIPad ? -115 : -50)
                    }

                    // Lock icon for parent
                    if isParent {
                        Image(systemName: "lock.fill")
                            .font(.AppTheme.rounded(size: isIPad ? 22 : 12))
                            .foregroundColor(Color.AppTheme.sepia)
                            .padding(isIPad ? 10 : 6)
                            .background(Color.AppTheme.warmCream)
                            .clipShape(Circle())
                            .offset(x: isIPad ? 80 : 35, y: isIPad ? 80 : 35)
                    }
                }

                // Name
                Text(profile.name.isEmpty ? (isParent ? "Parent" : "Player") : profile.name)
                    .font(isIPad ? .system(size: 22, weight: .semibold, design: .rounded) : .AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)

                // Last played relative time
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.AppTheme.rounded(size: isIPad ? 14 : 10))
                    Text(profile.lastPlayedRelative)
                        .font(isIPad ? .system(size: 15, design: .rounded) : .AppTheme.caption)
                }
                .foregroundColor(Color.AppTheme.lightSepia)
            }
            .frame(width: cardWidth)
            .padding(isIPad ? AppSpacing.lg : AppSpacing.md)
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
