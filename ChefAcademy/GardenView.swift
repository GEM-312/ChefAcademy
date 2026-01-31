//
//  GardenView.swift
//  ChefAcademy
//
//  The Garden is where players GROW vegetables!
//  This is one of the 3 pillars: GROW -> COOK -> FEED
//

import SwiftUI
import Combine  // Needed for Timer.publish

// MARK: - Garden View
//
// This view shows a 2x2 grid of garden plots.
// Players can tap plots to plant seeds and harvest vegetables.
//

struct GardenView: View {

    // Access the shared game state (coins, seeds, plots, etc.)
    @EnvironmentObject var gameState: GameState
    @Environment(\.horizontalSizeClass) var sizeClass

    // @State is for LOCAL view state - things only this view cares about
    @State private var showingPlantingSheet = false
    @State private var selectedPlotIndex: Int?
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Grid layout: 2 columns that expand to fill available space
    let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let isCompact = sizeClass == .compact
                let maxContentWidth: CGFloat = 700
                let contentWidth = isCompact ? geometry.size.width : min(geometry.size.width - 64, maxContentWidth)
                let horizontalPadding = max((geometry.size.width - contentWidth) / 2, 0)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isCompact ? AppSpacing.lg : AppSpacing.xl) {

                        // MARK: - Header with coins
                        headerView
                            .padding(.horizontal, horizontalPadding)

                        // MARK: - Pip's gardening tip
                        PipGardenMessage()
                            .padding(.horizontal, horizontalPadding)

                        // MARK: - The Garden Grid!
                        gardenGrid
                            .padding(.horizontal, horizontalPadding)

                        // MARK: - Seed inventory
                        seedInventorySection
                            .padding(.horizontal, horizontalPadding)

                        // MARK: - Harvested veggies
                        harvestedSection
                            .padding(.horizontal, horizontalPadding)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, AppSpacing.md)
                }
                .background(Color.AppTheme.cream)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // This sheet slides up when player taps an empty plot
        .sheet(isPresented: $showingPlantingSheet) {
            if let plotIndex = selectedPlotIndex {
                PlantingSheet(
                    plotIndex: plotIndex,
                    isPresented: $showingPlantingSheet
                )
                .environmentObject(gameState)
            }
        }
        // Update growth progress every second
        .onReceive(timer) { _ in
            updateGrowthStates()
        }
    }

    // MARK: - Header View

    var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Garden")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("Tap a plot to plant seeds!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }

            Spacer()

            // Coin display
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                Text("\(gameState.coins)")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(20)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Garden Grid

    var gardenGrid: some View {
        // LazyVGrid creates a grid layout from an array of items
        // 'columns' defines how many columns and their sizing
        LazyVGrid(columns: columns, spacing: AppSpacing.md) {

            // ForEach loops through the garden plots
            // We use 'indices' to get both the index AND the plot
            ForEach(gameState.gardenPlots.indices, id: \.self) { index in
                PlotView(
                    plot: gameState.gardenPlots[index],
                    onTap: {
                        handlePlotTap(index: index)
                    },
                    onHarvest: {
                        harvestPlot(index: index)
                    }
                )
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Seed Inventory Section

    var seedInventorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("My Seeds")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
                .padding(.horizontal, AppSpacing.md)

            if gameState.seeds.isEmpty {
                Text("No seeds! Visit the shop to buy some.")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .padding(.horizontal, AppSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(gameState.seeds) { seed in
                            SeedBadge(seed: seed)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
            }
        }
    }

    // MARK: - Harvested Section

    var harvestedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Harvested Veggies")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
                .padding(.horizontal, AppSpacing.md)

            if gameState.harvestedIngredients.isEmpty {
                Text("Nothing harvested yet. Grow some veggies!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .padding(.horizontal, AppSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(gameState.harvestedIngredients) { ingredient in
                            IngredientBadge(ingredient: ingredient)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
            }
        }
    }

    // MARK: - Actions

    func handlePlotTap(index: Int) {
        let plot = gameState.gardenPlots[index]

        switch plot.state {
        case .empty:
            // Open planting sheet
            selectedPlotIndex = index
            showingPlantingSheet = true

        case .growing:
            // Can't do anything while growing
            break

        case .ready:
            // Harvest!
            harvestPlot(index: index)

        case .needsWater:
            // Future feature
            break
        }
    }

    func harvestPlot(index: Int) {
        guard gameState.gardenPlots[index].isReadyToHarvest,
              let vegType = gameState.gardenPlots[index].vegetable else { return }

        // Get the harvest yield
        let yield = gameState.gardenPlots[index].harvest()

        // Update the plot in gameState
        gameState.gardenPlots[index].vegetable = nil
        gameState.gardenPlots[index].plantedDate = nil
        gameState.gardenPlots[index].state = .empty

        // Add to inventory
        gameState.addHarvestedIngredient(vegType, quantity: yield)

        // Award coins!
        let coinsEarned = vegType.harvestValue * yield
        gameState.addCoins(coinsEarned)

        // Award XP
        gameState.addXP(10)
    }

    func updateGrowthStates() {
        // Check each plot and update state if plant is ready
        for index in gameState.gardenPlots.indices {
            if gameState.gardenPlots[index].state == .growing &&
               gameState.gardenPlots[index].isReadyToHarvest {
                gameState.gardenPlots[index].state = .ready
            }
        }
    }
}

// MARK: - Pip Garden Message

struct PipGardenMessage: View {
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

                Text(gardeningTips.randomElement() ?? "Happy gardening!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    let gardeningTips = [
        "Tap an empty plot to plant seeds!",
        "Watch your plants grow - they'll be ready soon!",
        "Harvest veggies to use in recipes!",
        "Different veggies take different times to grow.",
        "Lettuce grows the fastest!"
    ]
}

// MARK: - Seed Badge

struct SeedBadge: View {
    let seed: Seed

    var body: some View {
        VStack(spacing: 4) {
            Text(seed.vegetableType.emoji)
                .font(.system(size: 24))

            Text("x\(seed.quantity)")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.darkBrown)
        }
        .padding(AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(12)
    }
}

// MARK: - Ingredient Badge

struct IngredientBadge: View {
    let ingredient: HarvestedIngredient

    var body: some View {
        VStack(spacing: 4) {
            Text(ingredient.type.emoji)
                .font(.system(size: 24))

            Text("x\(ingredient.quantity)")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.darkBrown)
        }
        .padding(AppSpacing.sm)
        .background(Color.AppTheme.sage.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    GardenView()
        .environmentObject(GameState.preview)
}
