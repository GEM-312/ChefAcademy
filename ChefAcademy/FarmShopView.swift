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

                ScrollView(showsIndicators: false) {
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
        .alert("Purchased! 🛒", isPresented: $showPurchaseConfirm) {
            Button("Yay!", role: .cancel) { }
        } message: {
            Text("You bought \(purchasedItemName)! Check your pantry.")
        }
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
                    .font(.system(size: 14))
                Text("\(gameState.coins)")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(20)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Category Pills

    var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(ShopCategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
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
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
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
                ShopItemCard(
                    item: item,
                    ownedQuantity: gameState.pantryQuantity(for: item),
                    canAfford: gameState.coins >= item.shopPrice,
                    isBouncing: bounceItem == item,
                    onBuy: {
                        buyItem(item)
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedCategory)
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
            }
        }
    }

    // MARK: - Buy Action

    func buyItem(_ item: PantryItem) {
        if gameState.buyPantryItem(item) {
            purchasedItemName = item.displayName
            // Bounce animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                bounceItem = item
            }
            // Reset bounce after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
    let isBouncing: Bool
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            // Emoji icon
            Text(item.emoji)
                .font(.system(size: 36))
                .scaleEffect(isBouncing ? 1.3 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isBouncing)

            // Item name
            Text(item.displayName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Owned quantity
            if ownedQuantity > 0 {
                Text("Own: \(ownedQuantity)")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundColor(Color.AppTheme.sage)
            }

            // Buy button
            Button(action: onBuy) {
                HStack(spacing: 3) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(Color.AppTheme.goldenWheat)
                        .font(.system(size: 8))
                    Text("\(item.shopPrice)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(canAfford ? Color.AppTheme.cream : Color.AppTheme.lightSepia)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 6)
                .background(canAfford ? Color.AppTheme.sage : Color.AppTheme.parchment)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(12)
    }
}

// MARK: - Pantry Badge (Shows owned items)

struct PantryBadge: View {
    let stock: PantryStock

    var body: some View {
        VStack(spacing: 4) {
            Text(stock.item.emoji)
                .font(.system(size: 28))

            Text(stock.item.displayName)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)

            Text("x\(stock.quantity)")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(width: 70)
        .padding(AppSpacing.sm)
        .background(Color.AppTheme.goldenWheat.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Pip Shop Message

struct PipShopMessage: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Pip Video Animation
            VideoPlayerWithFallback(
                videoName: "pip_waving",
                fallbackImage: "pip_waving",
                size: 60,
                circular: true,
                borderColor: Color.AppTheme.goldenWheat,
                borderWidth: 2
            )

            // Message bubble
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.goldenWheat)

                Text(shopTips.randomElement() ?? "Welcome to the farm shop!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
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

// MARK: - Preview

#Preview {
    FarmShopView()
        .environmentObject(GameState.preview)
}
