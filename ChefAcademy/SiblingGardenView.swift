//
//  SiblingGardenView.swift
//  ChefAcademy
//
//  Visit a sibling's garden — visitors can help with plant care!
//  Watering, weeding, and bug rescue earn rewards for the helper.
//

import SwiftUI
import SwiftData

struct SiblingGardenView: View {
    let sibling: UserProfile
    let visitorGameState: GameState   // The visitor's own GameState (to update coins/XP in memory)
    let onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager

    @StateObject private var siblingGameState = GameState()

    // Reward toast
    @State private var helpRewardMessage: String? = nil
    @State private var showHelpReward = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The real GardenView, loaded with sibling's data
            GardenView(
                selectedTab: .constant(.garden),
                isVisiting: true,
                visitingName: sibling.name,
                onLikeGarden: {
                    if let data = sibling.playerData(in: modelContext) {
                        data.gardenLikes += 1
                        try? modelContext.save()
                    }
                },
                onHelpWithCare: { plotIndex, action in
                    handleHelpAction(plotIndex: plotIndex, action: action)
                }
            )
            .environmentObject(siblingGameState)

            // Back button overlay
            Button(action: {
                onBack()
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                    Text("Back")
                }
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.cream)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.AppTheme.sage)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
            .padding(.leading, AppSpacing.md)
            .padding(.top, 60)

            // Help reward toast
            if showHelpReward, let msg = helpRewardMessage {
                VStack {
                    Spacer()
                    HStack(spacing: AppSpacing.sm) {
                        PipWavingAnimatedView(size: 36)
                        Text(msg)
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .lineLimit(2)
                    }
                    .padding(AppSpacing.md)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.cardCornerRadius)
                    .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 8, y: 4)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            if let data = sibling.playerData(in: modelContext) {
                siblingGameState.modelContext = modelContext
                siblingGameState.loadFromStore(for: data)
            }
        }
    }

    // MARK: - Handle Help Action

    private func handleHelpAction(plotIndex: Int, action: CareAction) {
        guard let visitorProfile = sessionManager.activeProfile else { return }

        // 1. Save sibling's updated garden (care action already applied by GardenView)
        siblingGameState.saveToStore()

        // 2. Record help entry on sibling's PlayerData
        let vegName = siblingGameState.gardenPlots[safe: plotIndex]?.vegetable?.rawValue ?? "plant"
        let entry = HelpEntry(
            helperName: visitorProfile.name,
            helperProfileID: visitorProfile.id.uuidString,
            actionRaw: action.rawValue,
            vegetableRaw: vegName,
            timestamp: Date()
        )
        if let siblingData = sibling.playerData(in: modelContext) {
            siblingData.receivedHelp.append(entry)
        }

        // 3. Reward the visitor on their OWN PlayerData
        if let visitorData = visitorProfile.playerData(in: modelContext) {
            visitorData.coins += 5
            visitorData.xp += 3
            visitorData.helpGivenCount += 1

            // Update help streak
            let lastHelp = visitorData.lastHelpDateRaw > 0
                ? Date(timeIntervalSince1970: visitorData.lastHelpDateRaw)
                : nil
            let isConsecutiveDay = lastHelp.map {
                Calendar.current.isDate($0, inSameDayAs: Date().addingTimeInterval(-86400))
            } ?? false
            let isSameDay = lastHelp.map {
                Calendar.current.isDateInToday($0)
            } ?? false

            if isConsecutiveDay {
                visitorData.helpStreak += 1
            } else if !isSameDay {
                visitorData.helpStreak = 1
            }
            visitorData.lastHelpDateRaw = Date().timeIntervalSince1970

            // "Helping Hands" badge at 10 helps
            if visitorData.helpGivenCount >= 10 && !visitorData.completedBadgeIDs.contains("helping-hands") {
                visitorData.completedBadgeIDs.append("helping-hands")
            }

            // Gift a random seed from the sibling's inventory
            var giftedSeed: VegetableType? = nil
            if let siblingData = sibling.playerData(in: modelContext),
               let randomSeed = siblingData.seedsData.filter({ $0.quantity > 0 }).randomElement(),
               let vegType = VegetableType(rawValue: randomSeed.vegetableRawValue) {
                // Add seed to visitor's PlayerData
                if let idx = visitorData.seedsData.firstIndex(where: { $0.vegetableRawValue == vegType.rawValue }) {
                    visitorData.seedsData[idx].quantity += 1
                } else {
                    visitorData.seedsData.append(SeedData(vegetableRawValue: vegType.rawValue, quantity: 1))
                }
                giftedSeed = vegType
                helpRewardMessage = "+5 🪙 +3 XP and a \(vegType.displayName) seed from \(sibling.name)!"
            } else {
                helpRewardMessage = "+5 🪙 +3 XP for helping \(sibling.name)!"
            }

            // Update visitor's in-memory GameState to stay in sync with autoSave.
            // Set properties directly (don't call addCoins/addXP which trigger saveToStore).
            visitorGameState.coins += 5
            visitorGameState.xp += 3
            visitorGameState.helpGivenCount += 1
            visitorGameState.helpStreak = visitorData.helpStreak
            visitorGameState.lastHelpDate = Date()

            // Sync seed gift to in-memory GameState too
            if let vegType = giftedSeed {
                if let idx = visitorGameState.seeds.firstIndex(where: { $0.vegetableType == vegType }) {
                    visitorGameState.seeds[idx].quantity += 1
                } else {
                    visitorGameState.seeds.append(Seed(vegetableType: vegType, quantity: 1))
                }
            }
        }

        try? modelContext.save()

        // Show reward toast
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showHelpReward = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showHelpReward = false
            }
        }
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
