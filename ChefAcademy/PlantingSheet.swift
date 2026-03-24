//
//  PlantingSheet.swift
//  ChefAcademy
//
//  A bottom sheet where players select which seed to plant.
//  This is called a "modal" - it temporarily takes over the screen.
//  Now responsive for both iPhone and iPad!
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

    // Closure to dismiss the sheet
    let onDismiss: () -> Void

    // Access the game state to get seeds and update the plot
    @EnvironmentObject var gameState: GameState

    // Detect iPhone vs iPad
    @Environment(\.horizontalSizeClass) var sizeClass

    // Track which seed the player has selected (owned or buyable)
    @State private var selectedSeed: Seed?
    @State private var selectedBuyable: VegetableType?

    // Adaptive sizes
    private var isIPad: Bool { sizeClass != .compact }
    private var seedImageSize: CGFloat { isIPad ? 120 : 80 }
    private var gridSpacing: CGFloat { isIPad ? 24 : 16 }
    private var gridColumns: Int { isIPad ? 4 : 3 }
    private var titleFont: Font { isIPad ? .AppTheme.largeTitle : .AppTheme.title }
    private var bodyFont: Font { isIPad ? .AppTheme.title3 : .AppTheme.body }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: isIPad ? AppSpacing.xl : AppSpacing.lg) {

                    // MARK: - Header
                    VStack(spacing: AppSpacing.xs) {
                        Text("Choose a Seed")
                            .font(titleFont)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        Text("Select what to plant in plot \(plotIndex + 1)")
                            .font(bodyFont)
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                    .padding(.top, isIPad ? AppSpacing.xl : AppSpacing.lg)

                    // MARK: - Seed Options (owned + buyable)
                    seedGridView

                    // MARK: - Plant Button (owned seed selected)
                    if let seed = selectedSeed, seed.quantity > 0 {
                        plantButton(for: seed)
                    }

                    // MARK: - Buy & Plant Button (buyable seed selected)
                    if let vegType = selectedBuyable {
                        buyAndPlantButton(for: vegType)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, isIPad ? AppSpacing.xl : AppSpacing.md)
            }
            .background(Color.AppTheme.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(isIPad ? .AppTheme.headline : .AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                }
            }
        }
        // iPad gets a larger sheet
        .presentationDetents(isIPad ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - No Seeds View

    var noSeedsView: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🌱")
                .font(.system(size: isIPad ? 80 : 60))

            Text("No seeds available!")
                .font(isIPad ? .AppTheme.title2 : .AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            Text("Visit the shop to buy seeds.")
                .font(bodyFont)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(maxWidth: .infinity)
        .padding(isIPad ? AppSpacing.xxl : AppSpacing.xl)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }

    // MARK: - Seed Grid

    var seedGridView: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: gridColumns),
            spacing: gridSpacing
        ) {
            // Owned seeds first, then unowned
            let owned = VegetableType.allCases.filter { veg in
                gameState.seeds.contains(where: { $0.vegetableType == veg && $0.quantity > 0 })
            }
            let unowned = VegetableType.allCases.filter { veg in
                !gameState.seeds.contains(where: { $0.vegetableType == veg && $0.quantity > 0 })
            }

            ForEach(owned, id: \.self) { veg in
                let seed = gameState.seeds.first(where: { $0.vegetableType == veg })!
                SeedOptionCard(
                    seed: seed,
                    isSelected: selectedSeed?.vegetableType == veg,
                    imageSize: seedImageSize,
                    isIPad: isIPad,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSeed = seed
                            selectedBuyable = nil  // clear buyable selection
                        }
                    }
                )
            }

            ForEach(unowned, id: \.self) { veg in
                BuyableSeedCard(
                    vegType: veg,
                    imageSize: seedImageSize,
                    isIPad: isIPad,
                    canAfford: gameState.coins >= veg.seedCost,
                    isSelected: selectedBuyable == veg,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedBuyable = veg
                            selectedSeed = nil  // clear owned selection
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
            Text("Plant \(seed.vegetableType.displayName)")
                .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.AppTheme.cream)
                .frame(maxWidth: isIPad ? 400 : .infinity)
                .padding(isIPad ? AppSpacing.lg : AppSpacing.md)
                .background(Color.AppTheme.sage)
                .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .padding(.bottom, AppSpacing.lg)
    }

    // MARK: - Buy & Plant Button

    func buyAndPlantButton(for vegType: VegetableType) -> some View {
        let canAfford = gameState.coins >= vegType.seedCost
        return Button(action: {
            if gameState.buySeed(vegType) {
                if let seed = gameState.seeds.first(where: { $0.vegetableType == vegType }) {
                    plantSeed(seed)
                }
            }
        }) {
            HStack(spacing: AppSpacing.xs) {
                Text("Buy & Plant \(vegType.displayName)")
                    .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                    .fontWeight(.semibold)

                HStack(spacing: 3) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                    Text("\(vegType.seedCost)")
                        .font(isIPad ? .AppTheme.headline : .AppTheme.bodyBold)
                }
            }
            .foregroundColor(Color.AppTheme.cream)
            .frame(maxWidth: isIPad ? 400 : .infinity)
            .padding(isIPad ? AppSpacing.lg : AppSpacing.md)
            .background(canAfford ? Color.AppTheme.goldenWheat : Color.AppTheme.lightSepia)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .disabled(!canAfford)
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
        onDismiss()
    }
}

// MARK: - Seed Option Card
//
// A tappable card showing one type of seed
// Now adaptive for iPhone/iPad
//

struct SeedOptionCard: View {
    let seed: Seed
    let isSelected: Bool
    var imageSize: CGFloat = 80
    var isIPad: Bool = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: isIPad ? AppSpacing.sm : AppSpacing.xs) {
                // Vegetable illustration — full color when owned
                Image(seed.vegetableType.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize, height: imageSize)

                // Vegetable name
                Text(seed.vegetableType.displayName)
                    .font(isIPad ? .AppTheme.headline : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)

                // Quantity
                Text("x\(seed.quantity)")
                    .font(isIPad ? .AppTheme.body : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)

                // Growth time
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: isIPad ? 14 : 10))
                    Text(growthTimeText)
                        .font(.system(size: isIPad ? 14 : 10))
                }
                .foregroundColor(Color.AppTheme.lightSepia)
            }
            .frame(maxWidth: .infinity)
            .padding(isIPad ? AppSpacing.md : AppSpacing.sm)
            .background(isSelected ? Color.AppTheme.sage.opacity(0.2) : Color.AppTheme.warmCream)
            .cornerRadius(isIPad ? 16 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                    .stroke(isSelected ? Color.AppTheme.sage : Color.clear, lineWidth: isIPad ? 3 : 2)
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

// MARK: - Buyable Seed Card

struct BuyableSeedCard: View {
    let vegType: VegetableType
    var imageSize: CGFloat = 80
    var isIPad: Bool = false
    let canAfford: Bool
    var isSelected: Bool = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: isIPad ? AppSpacing.sm : AppSpacing.xs) {
                Image(vegType.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize, height: imageSize)
                    .opacity(canAfford ? 0.9 : 0.4)
                    .saturation(canAfford ? 1.0 : 0.3)

                Text(vegType.displayName)
                    .font(isIPad ? .AppTheme.headline : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)

                // Price tag
                HStack(spacing: 3) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(Color.AppTheme.goldenWheat)
                        .font(.system(size: isIPad ? 12 : 10))
                    Text("\(vegType.seedCost)")
                        .font(.system(size: isIPad ? 14 : 12, weight: .semibold, design: .rounded))
                        .foregroundColor(canAfford ? Color.AppTheme.goldenWheat : Color.AppTheme.sepia.opacity(0.5))
                }

                // Growth time
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: isIPad ? 14 : 10))
                    Text(growthTimeText)
                        .font(.system(size: isIPad ? 14 : 10))
                }
                .foregroundColor(Color.AppTheme.lightSepia)
            }
            .frame(maxWidth: .infinity)
            .padding(isIPad ? AppSpacing.md : AppSpacing.sm)
            .background(isSelected ? Color.AppTheme.goldenWheat.opacity(0.15) : Color.AppTheme.warmCream.opacity(0.5))
            .cornerRadius(isIPad ? 16 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                    .stroke(isSelected ? Color.AppTheme.goldenWheat : Color.AppTheme.sepia.opacity(0.2),
                            lineWidth: isSelected ? (isIPad ? 3 : 2) : 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(canAfford ? 1.0 : 0.5)
        .disabled(!canAfford)
    }

    var growthTimeText: String {
        let seconds = Int(vegType.growthTime)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            return "\(seconds / 60)m"
        }
    }
}

// MARK: - Preview

#Preview {
    PlantingSheet(plotIndex: 0, onDismiss: {})
        .environmentObject(GameState.preview)
}
