//
//  HarvestCartCard.swift
//  ChefAcademy
//
//  The garden wheelbarrow's card (Oct 22 2026), opened by tapping the
//  wheelbarrow: what's in it, how many of each, and "Bring it to the pantry".
//  Harvested veggies can only be cooked once they're in the pantry
//  (GameState.bringWheelbarrowToPantry).
//

import SwiftUI

struct HarvestCartCard: View {
    let items: [HarvestedIngredient]
    let onBring: () -> Void
    let onClose: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var appeared = false
    @State private var flyingAway = false
    @State private var bringTask: Task<Void, Never>?

    private var columns: Int { sizeClass == .compact ? 3 : 4 }

    var body: some View {
        let veggieSize = AdaptiveCardSize.harvestCardVeggie(for: sizeClass)
        ZStack {
            // Dim overlay; a tap outside the card closes it
            Color.AppTheme.overlay
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: AppSpacing.md) {
                HStack {
                    Text("Your harvest!")
                        .font(.AppTheme.title)
                        .foregroundColor(Color.AppTheme.darkBrown)
                    Spacer()
                    PipBubbleCloseButton(action: close)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: columns),
                    spacing: AppSpacing.md
                ) {
                    ForEach(items) { item in
                        VStack(spacing: AppSpacing.xxs) {
                            Image(item.type.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: veggieSize, height: veggieSize)
                            Text("×\(item.quantity)")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.darkBrown)
                            Text(item.type.displayName)
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                                .lineLimit(1)
                        }
                        // Bringing them in: each veggie flies up out of the card
                        .offset(y: flyingAway ? -AppSpacing.xxl : 0)
                        .scaleEffect(flyingAway ? 0.5 : 1)
                        .opacity(flyingAway ? 0 : 1)
                        .accessibilityElement(children: .combine)
                    }
                }

                Button("Bring it to the pantry", action: bring)
                    .texturedButton(tint: Color.AppTheme.sage)
                    .disabled(flyingAway)
            }
            .softCard(padding: AppSpacing.lg)
            .frame(maxWidth: AdaptiveCardSize.harvestCardWidth(for: sizeClass))
            .padding(.horizontal, AppSpacing.md)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(AnimationConstants.springSlow) { appeared = true }
        }
        .onDisappear { bringTask?.cancel() }
    }

    /// While the veggies fly the card can't close: closing would cancel the move
    private func close() {
        guard !flyingAway else { return }
        onClose()
    }

    private func bring() {
        Haptic.notify(.success)
        withAnimation(AnimationConstants.pantryFly) { flyingAway = true }
        bringTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.pantryFlyDuration))
            guard !Task.isCancelled else { return }
            onBring()
        }
    }
}
