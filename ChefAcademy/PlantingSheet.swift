//
//  PlantingSheet.swift
//  ChefAcademy
//
//  A bottom sheet where players select which seed to plant.
//  This is called a "modal" - it temporarily takes over the screen.
//

import SwiftUI

// MARK: - Planting Sheet
//
// This sheet slides up when you tap an empty garden plot.
// Player selects a seed, then it gets planted!
//

struct PlantingSheet: View {

    // Which plot we're planting in
    let plotIndex: Int

    // @Binding creates a TWO-WAY connection to the parent's @State
    // When we set isPresented = false, the parent's showingPlantingSheet
    // also becomes false, and the sheet closes!
    @Binding var isPresented: Bool

    // Access the game state to get seeds and update the plot
    @EnvironmentObject var gameState: GameState

    // Track which seed the player has selected
    @State private var selectedSeed: Seed?

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.lg) {

                // MARK: - Header
                VStack(spacing: AppSpacing.xs) {
                    Text("Choose a Seed")
                        .font(.AppTheme.title)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    Text("Select what to plant in plot \(plotIndex + 1)")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                }
                .padding(.top, AppSpacing.lg)

                // MARK: - Seed Options
                if gameState.seeds.isEmpty {
                    noSeedsView
                } else {
                    seedGridView
                }

                Spacer()

                // MARK: - Plant Button
                if let seed = selectedSeed, seed.quantity > 0 {
                    plantButton(for: seed)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .background(Color.AppTheme.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color.AppTheme.sepia)
                }
            }
        }
        // This sets the sheet height to about half the screen
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - No Seeds View

    var noSeedsView: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🌱")
                .font(.system(size: 60))

            Text("No seeds available!")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            Text("Visit the shop to buy seeds.")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }

    // MARK: - Seed Grid

    var seedGridView: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: AppSpacing.md
        ) {
            ForEach(gameState.seeds) { seed in
                SeedOptionCard(
                    seed: seed,
                    isSelected: selectedSeed?.vegetableType == seed.vegetableType,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSeed = seed
                        }
                    }
                )
            }
        }
    }

    // MARK: - Plant Button

    func plantButton(for seed: Seed) -> some View {
        Button(action: {
            plantSeed(seed)
        }) {
            HStack {
                Text(seed.vegetableType.emoji)
                Text("Plant \(seed.vegetableType.displayName)")
                    .fontWeight(.semibold)
            }
            .foregroundColor(Color.AppTheme.cream)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.AppTheme.sage)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .padding(.bottom, AppSpacing.lg)
    }

    // MARK: - Plant Action

    func plantSeed(_ seed: Seed) {
        // Find the seed in inventory and reduce quantity
        if let seedIndex = gameState.seeds.firstIndex(where: { $0.vegetableType == seed.vegetableType }) {
            gameState.seeds[seedIndex].quantity -= 1

            // Remove if empty
            if gameState.seeds[seedIndex].quantity <= 0 {
                gameState.seeds.remove(at: seedIndex)
            }
        }

        // Plant in the plot
        gameState.gardenPlots[plotIndex].plant(seed.vegetableType)

        // Close the sheet
        isPresented = false
    }
}

// MARK: - Seed Option Card
//
// A tappable card showing one type of seed
//

struct SeedOptionCard: View {
    let seed: Seed
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: AppSpacing.xs) {
                // Seed emoji
                Text(seed.vegetableType.emoji)
                    .font(.system(size: 32))

                // Vegetable name
                Text(seed.vegetableType.displayName)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)

                // Quantity
                Text("x\(seed.quantity)")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)

                // Growth time
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(growthTimeText)
                        .font(.system(size: 10))
                }
                .foregroundColor(Color.AppTheme.lightSepia)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.sm)
            .background(isSelected ? Color.AppTheme.sage.opacity(0.2) : Color.AppTheme.warmCream)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.AppTheme.sage : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .opacity(seed.quantity > 0 ? 1.0 : 0.5)
        .disabled(seed.quantity <= 0)
    }

    var growthTimeText: String {
        let seconds = Int(seed.vegetableType.growthTime)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            return "\(seconds / 60)m"
        }
    }
}

// MARK: - Preview

#Preview {
    PlantingSheet(plotIndex: 0, isPresented: .constant(true))
        .environmentObject(GameState.preview)
}
