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

    // Confirm-before-spend: tap "Buy & Plant" sets this; the PipDialog
    // overlay then asks the kid to confirm. Pattern (b) from the UX plan.
    @State private var pendingBuyVeg: VegetableType?

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

                // Layer 3: Confirm-spend dialog (top of stack)
                if let veg = pendingBuyVeg {
                    PipDialogView(
                        message: "Spend \(veg.seedCost) coins and plant \(veg.displayName)?",
                        choices: [
                            PipDialogChoice(label: "Yes!", style: .primary, action: {
                                let toBuy = veg
                                pendingBuyVeg = nil
                                if gameState.buySeed(toBuy) {
                                    if let seed = gameState.seeds.first(where: { $0.vegetableType == toBuy }) {
                                        plantSeed(seed)
                                    }
                                }
                            }),
                            PipDialogChoice(label: "Maybe later", style: .subtle, action: {
                                pendingBuyVeg = nil
                            })
                        ]
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .animation(AnimationConstants.fadeMedium, value: pendingBuyVeg)
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
        .presentationDetents(isIPad ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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

                // Plant Button
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
                    } else if canAfford {
                        Button("Buy & Plant \(veg.displayName)") {
                            pendingBuyVeg = veg
                        }
                        .texturedButton(tint: Color.AppTheme.goldenWheat)
                        .padding(.horizontal, isIPad ? AppSpacing.xxl : AppSpacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Text("Not enough coins!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.terracotta)
                            .transition(.opacity)
                    }
                }

                Spacer(minLength: 40)
            }
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
