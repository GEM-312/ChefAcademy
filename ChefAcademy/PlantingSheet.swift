//
//  PlantingSheet.swift
//  ChefAcademy
//
//  Seed planting sheet — tap a seed to meet it as an NPC character!
//  Each veggie introduces itself with a personality greeting and excited animation.
//
//  TEACHING MOMENT: Two-State Morph Pattern
//
//  Instead of a traditional "select → scroll → find button" flow, this uses
//  matchedGeometryEffect to morph a small seed card into a big NPC detail view.
//  The "Plant" button is always visible — no scrolling needed.
//  This is critical for our age 6+ audience who won't discover hidden buttons.
//

import SwiftUI

// MARK: - Planting Sheet

struct PlantingSheet: View {

    // Which plot we're planting in
    let plotIndex: Int

    // Closure to dismiss the sheet
    let onDismiss: () -> Void

    // Access the game state to get seeds and update the plot
    @EnvironmentObject var gameState: GameState

    // Detect iPhone vs iPad
    @Environment(\.horizontalSizeClass) var sizeClass

    // Morph transition state
    @Namespace private var seedNamespace
    @State private var expandedVeg: VegetableType?
    @State private var npcAppeared: Bool = false

    // iPad: the sheet is as tall as the page it shows (Marina, Oct 22), not
    // the whole screen. Each page reports its content height; the bars and
    // insets are the sheet's height minus the page area's.
    @State private var contentHeight: CGFloat = 0
    @State private var sheetHeight: CGFloat = 0
    @State private var pageHeight: CGFloat = 0

    // Adaptive sizes
    private var isIPad: Bool { sizeClass != .compact }
    private var seedImageSize: CGFloat { isIPad ? 120 : 80 }
    private var gridSpacing: CGFloat { isIPad ? 20 : 12 }
    private var gridColumns: Int { isIPad ? 4 : 3 }
    private var npcImageSize: CGFloat { isIPad ? 300 : 200 }

    var body: some View {
        NavigationView {
            ZStack {
                Color.AppTheme.cream.ignoresSafeArea()

                // Layer 1: Seed Grid (visible when no seed expanded)
                if expandedVeg == nil {
                    seedGridLayer
                        .transition(.opacity)
                }

                // Layer 2: NPC Detail (visible when a seed is expanded)
                if let veg = expandedVeg {
                    npcDetailLayer(veg: veg)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if expandedVeg != nil {
                        // Back to grid
                        Button {
                            withAnimation(AnimationConstants.morphTransition) {
                                npcAppeared = false
                                expandedVeg = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Seeds")
                            }
                            .font(isIPad ? .AppTheme.headline : .AppTheme.body)
                            .foregroundColor(Color.AppTheme.sage)
                        }
                    } else {
                        // Cancel — close entire sheet
                        Button("Cancel") {
                            onDismiss()
                        }
                        .font(isIPad ? .AppTheme.headline : .AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
        // iPad: just the page's height (a taller page, like the seed grid, is
        // capped by the screen and scrolls). iPhone keeps medium / large.
        .presentationDetents(iPadSheetHeight.map { [.height($0)] } ?? [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// The page's content plus the sheet's bars and insets; nil on iPhone and
    /// until measured. Asks the DEVICE, not `isIPad`: a sheet on iPad is narrow,
    /// so its own size class reads compact (the console showed iPad=false).
    private var iPadSheetHeight: CGFloat? {
        guard DeviceInfo.isIPad, contentHeight > 0 else { return nil }
        return contentHeight + max(0, sheetHeight - pageHeight)
    }

    // MARK: - Layer 1: Seed Grid

    private var seedGridLayer: some View {
        ScrollView {
            VStack(spacing: isIPad ? AppSpacing.xl : AppSpacing.lg) {

                // Header
                VStack(spacing: AppSpacing.xs) {
                    Text("Choose a Seed")
                        .font(isIPad ? .AppTheme.largeTitle : .AppTheme.title)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    Text("Tap a seed to meet it!")
                        .font(isIPad ? .AppTheme.title3 : .AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                }
                .padding(.top, isIPad ? AppSpacing.xl : AppSpacing.lg)

                // Grid
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: gridColumns),
                    spacing: gridSpacing
                ) {
                    let owned = VegetableType.allCases.filter { veg in
                        gameState.seeds.contains(where: { $0.vegetableType == veg && $0.quantity > 0 })
                    }
                    let unowned = VegetableType.allCases.filter { veg in
                        !gameState.seeds.contains(where: { $0.vegetableType == veg && $0.quantity > 0 })
                    }

                    ForEach(owned, id: \.self) { veg in
                        seedGridCard(veg: veg, isOwned: true)
                    }

                    ForEach(unowned, id: \.self) { veg in
                        seedGridCard(veg: veg, isOwned: false)
                    }
                }
                .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)

                Spacer(minLength: 40)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
    }

    // MARK: - Seed Grid Card (simplified — image + name only)

    private func seedGridCard(veg: VegetableType, isOwned: Bool) -> some View {
        let canAfford = gameState.coins >= veg.seedCost

        return Button {
            Haptic.impact(.light)
            withAnimation(AnimationConstants.morphTransition) {
                expandedVeg = veg
            }
            // Trigger NPC entrance after morph completes
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(AnimationConstants.springBouncy) {
                    npcAppeared = true
                }
            }
        } label: {
            VStack(spacing: isIPad ? AppSpacing.sm : AppSpacing.xs) {
                Image(veg.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: seedImageSize, height: seedImageSize)
                    .opacity(isOwned || canAfford ? 0.85 : 0.4)

                Text(veg.displayName)
                    .font(isIPad ? .AppTheme.subheadline : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(isIPad ? AppSpacing.md : AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .morphSource(id: "plant-seed-\(veg.rawValue)", in: seedNamespace, isActive: expandedVeg == nil)
        .opacity(isOwned || canAfford ? 1.0 : 0.5)
        .disabled(!isOwned && !canAfford)
    }

    // MARK: - Layer 2: NPC Detail

    private func npcDetailLayer(veg: VegetableType) -> some View {
        let isOwned = gameState.seeds.contains(where: { $0.vegetableType == veg && $0.quantity > 0 })
        let seed = gameState.seeds.first(where: { $0.vegetableType == veg })
        let canAfford = gameState.coins >= veg.seedCost

        return ScrollView {
            VStack(spacing: isIPad ? AppSpacing.xl : AppSpacing.lg) {

                Spacer(minLength: isIPad ? AppSpacing.xl : AppSpacing.lg)

                // NPC Veggie Image — morphs from grid card
                Image(veg.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: npcImageSize, height: npcImageSize)
                    .morphDestination(id: "plant-seed-\(veg.rawValue)", in: seedNamespace)
                    .scaleEffect(npcAppeared ? 1.0 : 0.5)
                    .modifier(npcAppeared ? WiggleModifier(amount: 5, speed: 0.15) : WiggleModifier(amount: 0, speed: 0.15))

                // NPC Speech Bubble
                if npcAppeared {
                    VStack(spacing: AppSpacing.sm) {
                        Text(veg.npcGreeting)
                            .font(isIPad ? .AppTheme.title3 : .AppTheme.body)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .multilineTextAlignment(.center)
                            .padding(isIPad ? AppSpacing.lg : AppSpacing.md)
                            .background(Color.AppTheme.warmCream)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .padding(.horizontal, isIPad ? AppSpacing.xxl : AppSpacing.lg)
                    .onAppear { PipVoice.shared.speak(veg.npcGreeting) }
                }

                // Stats row
                if npcAppeared {
                    HStack(spacing: isIPad ? AppSpacing.xl : AppSpacing.lg) {
                        // Quantity
                        if isOwned, let seed = seed {
                            VStack(spacing: 2) {
                                Text("x\(seed.quantity)")
                                    .font(.AppTheme.title3)
                                    .foregroundColor(Color.AppTheme.darkBrown)
                                Text("In bag")
                                    .font(.AppTheme.caption)
                                    .foregroundColor(Color.AppTheme.sepia)
                            }
                        } else {
                            VStack(spacing: 2) {
                                HStack(spacing: 3) {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(Color.AppTheme.goldenWheat)
                                        .font(.AppTheme.caption)
                                    Text("\(veg.seedCost)")
                                        .font(.AppTheme.title3)
                                        .foregroundColor(Color.AppTheme.goldenWheat)
                                }
                                Text("Cost")
                                    .font(.AppTheme.caption)
                                    .foregroundColor(Color.AppTheme.sepia)
                            }
                        }

                        // Growth time
                        VStack(spacing: 2) {
                            Text(growthTimeText(for: veg))
                                .font(.AppTheme.title3)
                                .foregroundColor(Color.AppTheme.darkBrown)
                            Text("Grow time")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                        }

                        // Harvest yield
                        VStack(spacing: 2) {
                            Text("x\(veg.harvestYield)")
                                .font(.AppTheme.title3)
                                .foregroundColor(Color.AppTheme.sage)
                            Text("Harvest")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                    }
                    .transition(.opacity)
                }

                // Plant Button — single consistent affordance:
                // - Owned: green Plant button, free
                // - Not owned + affordable: gold Buy & Plant button, immediate (no confirm dialog)
                // - Not owned + broke: same gold button, but disabled + grayed out
                if npcAppeared {
                    if isOwned {
                        Button("Plant \(veg.displayName)") {
                            if let seed = seed {
                                plantSeed(seed)
                            }
                        }
                        .texturedButton(tint: Color.AppTheme.sage)
                        .padding(.horizontal, isIPad ? AppSpacing.xxl : AppSpacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button("Buy & Plant \(veg.displayName)") {
                            if gameState.buySeed(veg) {
                                if let bought = gameState.seeds.first(where: { $0.vegetableType == veg }) {
                                    plantSeed(bought)
                                }
                            }
                        }
                        .texturedButton(tint: Color.AppTheme.goldenWheat)
                        .opacity(canAfford ? 1.0 : 0.5)
                        .disabled(!canAfford)
                        .padding(.horizontal, isIPad ? AppSpacing.xxl : AppSpacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                Spacer(minLength: 40)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
    }

    // MARK: - Plant Action

    private func plantSeed(_ seed: Seed) {
        Haptic.notify(.success)

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
        PipTutorial.gardenPlanted.markDone(for: gameState.activeProfileID)   // "Plant" label retires

        // Close the sheet
        onDismiss()
    }

    // MARK: - Helpers

    private func growthTimeText(for veg: VegetableType) -> String {
        let seconds = Int(veg.growthTime)
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
