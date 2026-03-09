//
//  GardenHubView.swift
//  ChefAcademy
//
//  Merged Garden + Farm Shop in one tab with a toggle.
//

import SwiftUI
import SwiftData

enum GardenHubMode: String {
    case garden = "My Garden"
    case shop = "Farm Shop"
    case siblingVisit = "Visit"
}

struct GardenHubView: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var gardenMode: GardenHubMode
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var gameState: GameState
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSibling: UserProfile?

    private var siblings: [UserProfile] {
        guard let family = sessionManager.familyProfile,
              let activeID = sessionManager.activeProfile?.id else { return [] }
        return family.childProfiles(in: modelContext).filter { $0.id != activeID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle bar
            HStack(spacing: AppSpacing.sm) {
                GardenModeButton(
                    title: "Garden",
                    icon: "leaf.fill",
                    isSelected: gardenMode == .garden
                ) { gardenMode = .garden }

                GardenModeButton(
                    title: "Shop",
                    icon: "cart.fill",
                    isSelected: gardenMode == .shop
                ) { gardenMode = .shop }

                // Sibling visit button (only if siblings exist)
                if !siblings.isEmpty {
                    GardenModeButton(
                        title: "Visit",
                        icon: "person.2.fill",
                        isSelected: gardenMode == .siblingVisit
                    ) { gardenMode = .siblingVisit }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.AppTheme.warmCream)

            // Content
            switch gardenMode {
            case .garden:
                GardenView(
                    selectedTab: $selectedTab,
                    onShowFarmShop: { gardenMode = .shop }
                )
            case .shop:
                FarmTabView()
            case .siblingVisit:
                SiblingPickerView(
                    siblings: siblings,
                    selectedSibling: $selectedSibling
                )
            }
        }
    }
}

// MARK: - Mode Toggle Button

struct GardenModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.AppTheme.caption)
            }
            .foregroundColor(isSelected ? Color.AppTheme.cream : Color.AppTheme.sepia)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background(isSelected ? Color.AppTheme.sage : Color.AppTheme.parchment)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sibling Picker

struct SiblingPickerView: View {
    let siblings: [UserProfile]
    @Binding var selectedSibling: UserProfile?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            if let sibling = selectedSibling {
                SiblingGardenView(
                    sibling: sibling,
                    onBack: { selectedSibling = nil }
                )
            } else {
                VStack(spacing: AppSpacing.lg) {
                    Spacer()

                    PipWavingAnimatedView(size: 100)

                    Text("Visit a Friend's Garden!")
                        .font(.AppTheme.title2)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    Text("See what your siblings are growing")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)

                    // Sibling cards
                    HStack(spacing: AppSpacing.md) {
                        ForEach(siblings, id: \.id) { sibling in
                            Button(action: { selectedSibling = sibling }) {
                                VStack(spacing: AppSpacing.xs) {
                                    Image(sibling.gender == .boy ? "boy_card_frame_28" : "girl_card_frame_15")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.AppTheme.sage, lineWidth: 2)
                                        )

                                    Text(sibling.name)
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)

                                    if let data = sibling.playerData(in: modelContext) {
                                        Text("Lv. \(data.playerLevel)")
                                            .font(.AppTheme.caption)
                                            .foregroundColor(Color.AppTheme.sepia)
                                    }
                                }
                                .padding(AppSpacing.md)
                                .background(Color.AppTheme.warmCream)
                                .cornerRadius(AppSpacing.cardCornerRadius)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    GardenHubView(
        selectedTab: .constant(.garden),
        gardenMode: .constant(.garden)
    )
    .environmentObject(SessionManager())
    .environmentObject(GameState())
}
