//
//  FarmShopView.swift
//  ChefAcademy
//
//  The Farm Shop is where players BUY pantry items!
//  Eggs, chicken, butter, cheese, rice, pasta...
//  These are needed alongside garden veggies to cook recipes.
//
//  Part of the game loop: GROW veggies → BUY pantry items → COOK recipes → FEED Body Buddy
//

import SwiftUI

// MARK: - Farm Shop View

struct FarmShopView: View {

    @EnvironmentObject var gameState: GameState
    @State private var selectedCategory: ShopCategory = .all
    @State private var showPurchaseConfirm = false
    @State private var purchasedItemName = ""
    @State private var bounceItem: PantryItem?
    @State private var selectedInfoItem: PantryItem?
    // Confirm-before-spend: tap "Buy" sets this; PipDialog overlay confirms.
    @State private var pendingBuyItem: PantryItem?
    // Cancellable replacement for the old asyncAfter that nil'd bounceItem.
    // Prevents writing to dead @State if the view is dismissed mid-bounce.
    @State private var bounceTask: Task<Void, Never>?
    @Namespace private var shopNamespace

    // Filter items by category
    var filteredItems: [PantryItem] {
        if selectedCategory == .all {
            return PantryItem.allCases.map { $0 }
        }
        return PantryItem.allCases.filter { $0.shopCategory == selectedCategory }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.AppTheme.cream
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // MARK: - Header
                        shopHeader
                            .padding(.top, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.sm)

                        // MARK: - Pip's Shop Tip
                        PipShopMessage()
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.md)

                        // MARK: - Category Filter
                        categoryPills
                            .padding(.bottom, AppSpacing.md)

                        // MARK: - Shop Grid
                        shopGrid
                            .padding(.horizontal, AppSpacing.md)

                        // MARK: - My Pantry Section
                        pantrySection
                            .padding(.top, AppSpacing.lg)
                            .padding(.horizontal, AppSpacing.md)

                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // Purchase success popup
        .alert("Purchased!", isPresented: $showPurchaseConfirm) {
            Button("Yay!", role: .cancel) { }
        } message: {
            Text("You bought \(purchasedItemName)! Check your pantry.")
        }
        // Morph overlay — replaces .fullScreenCover for smooth matched geometry
        .overlay {
            if let item = selectedInfoItem {
                PantryInfoView(
                    item: item,
                    onDismiss: {
                        withAnimation(AnimationConstants.morphTransition) {
                            selectedInfoItem = nil
                        }
                    },
                    onBuy: {
                        // Buy first, THEN dismiss — buyItem triggers the bounce
                        // animation on the shop card, which is more satisfying
                        // when the info card is already morphing away.
                        buyItem(item)
                        withAnimation(AnimationConstants.morphTransition) {
                            selectedInfoItem = nil
                        }
                    }
                )
                .morphDestination(id: "pantry-\(item.rawValue)", in: shopNamespace)
                .dragToDismiss {
                    withAnimation(AnimationConstants.morphTransition) {
                        selectedInfoItem = nil
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        // Confirm-before-spend overlay (top of stack)
        .overlay {
            if let item = pendingBuyItem {
                PipDialogView(
                    message: "Buy \(item.displayName) for \(item.shopPrice) coins?",
                    choices: [
                        PipDialogChoice(label: "Yes!", style: .primary, action: {
                            let toBuy = item
                            pendingBuyItem = nil
                            confirmBuyItem(toBuy)
                        }),
                        PipDialogChoice(label: "Maybe later", style: .subtle, action: {
                            pendingBuyItem = nil
                        })
                    ]
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(AnimationConstants.fadeMedium, value: pendingBuyItem)
        .onDisappear { bounceTask?.cancel() }
    }

    // MARK: - Shop Header

    var shopHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Farm Shop")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("Buy ingredients for your recipes!")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }

            Spacer()

            // Coin display
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                    .font(.AppTheme.captionLarge)
                Text("\(gameState.coins)")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(AppSpacing.largeCornerRadius)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Category Pills

    var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(ShopCategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(AnimationConstants.fadeFast) {
                            selectedCategory = category
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.AppTheme.caption)
                            Text(category.rawValue)
                                .font(.AppTheme.caption)
                        }
                        .foregroundColor(
                            selectedCategory == category
                            ? Color.AppTheme.cream
                            : Color.AppTheme.darkBrown
                        )
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            selectedCategory == category
                            ? category.color
                            : Color.AppTheme.parchment
                        )
                        .cornerRadius(AppSpacing.largeCornerRadius)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .trailingFade()
    }

    // MARK: - Shop Grid

    var shopGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppSpacing.sm),
                GridItem(.flexible(), spacing: AppSpacing.sm),
                GridItem(.flexible(), spacing: AppSpacing.sm)
            ],
            spacing: AppSpacing.md
        ) {
            ForEach(filteredItems) { item in
                let isLearned = item.nutrients.contains { nutrient in
                    gameState.isKnowledgeClaimed("pantry_\(item.rawValue)_\(nutrient.rawValue)")
                }
                ShopItemCard(
                    item: item,
                    ownedQuantity: gameState.pantryQuantity(for: item),
                    canAfford: gameState.coins >= item.shopPrice,
                    isLearned: isLearned,
                    isBouncing: bounceItem == item,
                    onBuy: {
                        buyItem(item)
                    },
                    onInfo: {
                        Haptic.impact(.light)
                        withAnimation(AnimationConstants.morphTransition) {
                            selectedInfoItem = item
                        }
                    },
                    childAllergens: gameState.activeAllergens
                )
                .morphSource(
                    id: "pantry-\(item.rawValue)",
                    in: shopNamespace,
                    isActive: selectedInfoItem == nil
                )
            }
        }
        .animation(AnimationConstants.fadeMedium, value: selectedCategory)
    }

    // MARK: - My Pantry Section

    var pantrySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("My Pantry")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            if gameState.pantryInventory.isEmpty {
                Text("Your pantry is empty! Buy some ingredients above.")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(gameState.pantryInventory) { stock in
                            PantryBadge(stock: stock)
                        }
                    }
                }
                .trailingFade()
            }
        }
    }

    // MARK: - Buy Action

    /// Called by both the shop card "Buy" tap and the info card sticky-buy.
    /// Stages a pending purchase; the PipDialog overlay confirms before spending.
    func buyItem(_ item: PantryItem) {
        pendingBuyItem = item
    }

    /// Performs the actual purchase after the kid taps "Yes!" in the dialog.
    private func confirmBuyItem(_ item: PantryItem) {
        if gameState.buyPantryItem(item) {
            purchasedItemName = item.displayName
            // Bounce animation
            withAnimation(AnimationConstants.springBouncy) {
                bounceItem = item
            }
            // Reset bounce after animation. Cancellable Task replaces asyncAfter so
            // the write is skipped if the view dismisses before 0.5s elapses.
            bounceTask?.cancel()
            bounceTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                bounceItem = nil
            }
            showPurchaseConfirm = true
        }
    }
}

// MARK: - Shop Item Card

struct ShopItemCard: View {
    let item: PantryItem
    let ownedQuantity: Int
    let canAfford: Bool
    let isLearned: Bool
    let isBouncing: Bool
    let onBuy: () -> Void
    var onInfo: (() -> Void)? = nil
    var childAllergens: [FoodAllergen] = []

    private var hasAllergen: Bool {
        !item.allergens.filter { childAllergens.contains($0) }.isEmpty
    }

    var body: some View {
        // Card tap ALWAYS opens the info card. The Buy button lives inside
        // PantryInfoView as a sticky CTA — fixes the old "I tapped, learned,
        // forgot to tap again to buy" bug by putting buying in the same
        // screen as learning (no hidden mode switch).
        Button(action: { onInfo?() }) {
            VStack(spacing: 0) {
                Image(item.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(item.shopScale)
                    .offset(y: item.shopOffset)
                    .frame(maxWidth: .infinity)
                    .frame(height: item.shopFrameHeight)
                    .clipped()
                    .opacity(0.8)
                    .scaleEffect(isBouncing ? 1.1 : 1.0)
                    .animation(AnimationConstants.springBouncy, value: isBouncing)
                    .padding(.top, 4)
                    .overlay(alignment: .topLeading) {
                        if hasAllergen {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.AppTheme.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.AppTheme.terracotta)
                                .clipShape(Circle())
                                .padding(4)
                        }
                    }

                VStack(spacing: 1) {
                    Text(item.displayName)
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .lineLimit(1)

                    if ownedQuantity > 0 {
                        Text("x\(ownedQuantity)")
                            .font(.AppTheme.micro)
                            .foregroundColor(Color.AppTheme.sepia)
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "circle.fill")
                            .font(.AppTheme.rounded(size: 8))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                        Text("\(item.shopPrice)")
                            .font(.AppTheme.micro)
                    }
                    .foregroundColor(Color.AppTheme.lightSepia)
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.smallCornerRadius)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.smallCornerRadius))
        }
        .buttonStyle(.plain)
        .opacity(isLearned && !canAfford ? 0.5 : 1.0)
        .disabled(isLearned && !canAfford)
    }
}

// MARK: - Pantry Badge (Shows owned items)

struct PantryBadge: View {
    let stock: PantryStock

    var body: some View {
        VStack(spacing: 2) {
            Image(stock.item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(2.2)
                .frame(width: 80, height: 65)
                .clipped()
                .opacity(0.8)

            Text(stock.item.displayName)
                .font(.AppTheme.rounded(size: 9, weight: .medium))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)

            Text("x\(stock.quantity)")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(width: 80)
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, AppSpacing.xs)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.smallCornerRadius)
    }
}

// MARK: - Pip Shop Message

struct PipShopMessage: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Animated Pip waving (frame animation, transparent bg)
            PipWavingAnimatedView(size: .large)

            // Message bubble
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.goldenWheat)

                Text(shopTips.randomElement() ?? "Welcome to the farm shop!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .softCard(showShadow: false)
        }
    }

    let shopTips = [
        "Buy eggs and butter to make an omelette!",
        "You'll need chicken to make stir fry!",
        "Stock up on basics — salt and pepper go in everything!",
        "Check which recipes you can cook with your ingredients!",
        "Grow veggies in the garden, buy the rest here!",
    ]
}

// MARK: - Basket with Veggies
/// Shows harvested veggies peeking out of the basket.
/// Veggies sit BEHIND the basket rim (lower z-index), creating the illusion
/// that they're inside the basket.

struct BasketWithVeggiesView: View {
    let harvestedIngredients: [HarvestedIngredient]
    let basketSize: CGFloat

    /// Veggie image size — smaller than basket so they peek out
    private var veggieSize: CGFloat { basketSize * 0.30 }

    /// Offsets for up to 5 veggies arranged in an arc inside the basket bowl.
    /// The basket image has white space above — the actual bowl is in the bottom half.
    /// Positive y = further down toward the bowl.
    private var veggieOffsets: [(x: CGFloat, y: CGFloat)] {
        let s = basketSize
        return [
            (x: -s * 0.15, y:  s * 0.12),  // left
            (x: -s * 0.05, y:  s * 0.08),  // center-left
            (x:  s * 0.06, y:  s * 0.07),  // center
            (x:  s * 0.16, y:  s * 0.10),  // center-right
            (x:  s * 0.25, y:  s * 0.14),  // right
        ]
    }

    var body: some View {
        ZStack {
            // Veggies BEHIND the basket (lower z-index)
            ForEach(Array(harvestedIngredients.prefix(5).enumerated()), id: \.element.id) { index, ingredient in
                let offset = veggieOffsets[index]
                Image(ingredient.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: veggieSize, height: veggieSize)
                    .offset(x: offset.x, y: offset.y)
            }

            // Basket on top — rim covers the bottom of the veggies
            Image("vegetable_basket")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: basketSize, height: basketSize)
        }
    }
}

// MARK: - Farm Tab View
/// The Shop tab. Opens the shop directly — the barn walk-in was removed
/// (Marina, 2026-10-08): the Home map already shows the shop as a market
/// stall, and the walk blocked the shop on every visit (UX review P1-5).

struct FarmTabView: View {
    var body: some View {
        FarmShopView()
    }
}

// MARK: - Preview

#Preview {
    FarmShopView()
        .environmentObject(GameState.preview)
}

#Preview("Farm Tab") {
    FarmTabView()
        .environmentObject(GameState.preview)
}
