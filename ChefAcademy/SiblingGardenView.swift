//
//  SiblingGardenView.swift
//  ChefAcademy
//
//  Visit a sibling's garden — shows the real GardenView with their data, read-only.
//

import SwiftUI
import SwiftData

struct SiblingGardenView: View {
    let sibling: UserProfile
    let onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var siblingGameState = GameState()

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The real GardenView, loaded with sibling's data, read-only
            GardenView(
                selectedTab: .constant(.garden),
                isVisiting: true,
                visitingName: sibling.name,
                onLikeGarden: {
                    if let data = sibling.playerData(in: modelContext) {
                        data.gardenLikes += 1
                        try? modelContext.save()
                    }
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
        }
        .onAppear {
            if let data = sibling.playerData(in: modelContext) {
                siblingGameState.loadFromStore(for: data)
            }
        }
    }
}
