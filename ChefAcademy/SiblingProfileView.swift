//
//  SiblingProfileView.swift
//  ChefAcademy
//
//  View a sibling's profile — stats, recipes, and a button to visit their garden.
//

import SwiftUI
import SwiftData

struct SiblingProfileView: View {
    let sibling: UserProfile
    let visitorGameState: GameState
    let onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showGarden = false
    @State private var showGiftSheet = false
    @State private var giftMessage: String? = nil
    @State private var showGiftToast = false

    private var playerData: PlayerData? {
        sibling.playerData(in: modelContext)
    }

    private var characterImage: String {
        sibling.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"
    }

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    // Header with back button
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sage)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Avatar + Name
                    VStack(spacing: AppSpacing.sm) {
                        Image(characterImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.AppTheme.goldenWheat, lineWidth: 3)
                            )

                        Text(sibling.name)
                            .font(.AppTheme.largeTitle)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        if let data = playerData {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(Color.AppTheme.goldenWheat)
                                Text("Level \(data.playerLevel)")
                                    .font(.AppTheme.headline)
                                    .foregroundColor(Color.AppTheme.darkBrown)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.AppTheme.warmCream)
                            .cornerRadius(AppSpacing.largeCornerRadius)

                            if data.gardenLikes > 0 {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Color.AppTheme.terracotta.opacity(0.7))
                                    Text("\(data.gardenLikes) likes")
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs)
                                .background(Color.AppTheme.warmCream)
                                .cornerRadius(AppSpacing.largeCornerRadius)
                            }
                        }
                    }

                    // Visit Garden button
                    Button(action: { showGarden = true }) {
                        HStack {
                            Image(systemName: "leaf.fill")
                            Text("Visit \(sibling.name)'s Garden")
                        }
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.md)

                    // Gift Veggies button
                    if !visitorGameState.harvestedIngredients.isEmpty {
                        Button(action: { showGiftSheet = true }) {
                            HStack {
                                Image(systemName: "gift.fill")
                                Text("Gift Veggies to \(sibling.name)")
                            }
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.md)
                            .background(Color.AppTheme.goldenWheat)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppSpacing.md)
                    }

                    if let data = playerData {
                        // Stats grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: AppSpacing.md) {
                            StatCard(title: "Coins", value: "\(data.coins)", icon: "circle.fill", color: Color.AppTheme.goldenWheat)
                            StatCard(title: "XP", value: "\(data.xp)", icon: "bolt.fill", color: Color.AppTheme.sage)
                            StatCard(title: "Recipes", value: "\(data.recipeStars.count)", icon: "fork.knife", color: Color.AppTheme.terracotta)
                            StatCard(title: "Veggies", value: "\(data.harvestedData.map(\.quantity).reduce(0, +))", icon: "leaf.fill", color: Color.AppTheme.sage)
                        }
                        .padding(.horizontal, AppSpacing.md)

                        // Harvested veggies
                        if !data.harvestedData.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Harvested Veggies")
                                    .font(.AppTheme.headline)
                                    .foregroundColor(Color.AppTheme.darkBrown)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: AppSpacing.sm) {
                                    ForEach(data.harvestedData, id: \.vegetableRawValue) { harvest in
                                        if let vegType = VegetableType(rawValue: harvest.vegetableRawValue) {
                                            VStack(spacing: 4) {
                                                Image(vegType.imageName)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                Text(vegType.displayName)
                                                    .font(.AppTheme.rounded(size: 10, weight: .medium))
                                                    .foregroundColor(Color.AppTheme.darkBrown)
                                                Text("x\(harvest.quantity)")
                                                    .font(.AppTheme.caption)
                                                    .foregroundColor(Color.AppTheme.sepia)
                                            }
                                            .padding(AppSpacing.xs)
                                            .background(Color.AppTheme.warmCream)
                                            .cornerRadius(AppSpacing.cardCornerRadius)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }

                        // Recipes cooked
                        if !data.recipeStars.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Recipes Cooked")
                                    .font(.AppTheme.headline)
                                    .foregroundColor(Color.AppTheme.darkBrown)

                                ForEach(data.recipeStars, id: \.recipeID) { star in
                                    HStack {
                                        Text(star.recipeID)
                                            .font(.AppTheme.body)
                                            .foregroundColor(Color.AppTheme.sepia)
                                        Spacer()
                                        HStack(spacing: 2) {
                                            ForEach(0..<3, id: \.self) { i in
                                                Image(systemName: i < star.stars ? "star.fill" : "star")
                                                    .font(.AppTheme.captionLarge)
                                                    .foregroundColor(Color.AppTheme.goldenWheat)
                                            }
                                        }
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(Color.AppTheme.warmCream)
                                    .cornerRadius(AppSpacing.cardCornerRadius)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.top, AppSpacing.md)
            }
        }
        .fullScreenCover(isPresented: $showGarden) {
            SiblingGardenView(
                sibling: sibling,
                visitorGameState: visitorGameState,
                onBack: { showGarden = false }
            )
        }
        .sheet(isPresented: $showGiftSheet) {
            GiftVeggieSheet(
                visitorGameState: visitorGameState,
                sibling: sibling,
                onGift: { vegType in
                    giftVeggie(vegType)
                }
            )
        }
        .overlay {
            if showGiftToast, let msg = giftMessage {
                VStack {
                    Spacer()
                    HStack(spacing: AppSpacing.sm) {
                        PipWavingAnimatedView(size: .custom(36))
                        Text(msg)
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .lineLimit(2)
                    }
                    .softCard()
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Gift Veggie

    private func giftVeggie(_ vegType: VegetableType) {
        // Remove from visitor's inventory
        if let idx = visitorGameState.harvestedIngredients.firstIndex(where: { $0.type == vegType && $0.quantity > 0 }) {
            visitorGameState.harvestedIngredients[idx].quantity -= 1
            if visitorGameState.harvestedIngredients[idx].quantity <= 0 {
                visitorGameState.harvestedIngredients.remove(at: idx)
            }
        }

        // Add to sibling's PlayerData
        if let siblingData = sibling.playerData(in: modelContext) {
            if let idx = siblingData.harvestedData.firstIndex(where: { $0.vegetableRawValue == vegType.rawValue }) {
                siblingData.harvestedData[idx].quantity += 1
            } else {
                siblingData.harvestedData.append(HarvestedData(vegetableRawValue: vegType.rawValue, quantity: 1))
            }
        }

        // Track gift count on visitor
        visitorGameState.giftsGivenCount += 1

        // Persist
        visitorGameState.saveToStore()
        try? modelContext.save()

        // Report achievement
        GameCenterService.shared.reportAchievement(AchievementID.generousChef)
        GameCenterService.shared.checkAchievements(gameState: visitorGameState)

        // Show toast
        showGiftSheet = false
        giftMessage = "You gave \(sibling.name) a \(vegType.displayName)!"
        withAnimation(AnimationConstants.springMedium) {
            showGiftToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.fadeMedium) {
                showGiftToast = false
            }
        }
    }
}

// MARK: - Gift Veggie Sheet

struct GiftVeggieSheet: View {
    let visitorGameState: GameState
    let sibling: UserProfile
    let onGift: (VegetableType) -> Void
    @Environment(\.dismiss) private var dismiss

    // Confirm-before-gift: tap a veggie sets this; PipDialog confirms.
    // Gifting is irreversible, so this guard matters more than purchase confirms.
    @State private var pendingGiftVeg: VegetableType?

    private var availableVeggies: [HarvestedIngredient] {
        visitorGameState.harvestedIngredients.filter { $0.quantity > 0 }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.AppTheme.cream.ignoresSafeArea()

                if availableVeggies.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "leaf.arrow.triangle.circlepath")
                            .font(.AppTheme.timerDisplay)
                            .foregroundColor(Color.AppTheme.sage.opacity(0.5))
                        Text("No veggies to gift!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.sepia)
                        Text("Harvest some from your garden first.")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: AppSpacing.md) {
                            ForEach(availableVeggies, id: \.type) { item in
                                Button(action: { pendingGiftVeg = item.type }) {
                                    VStack(spacing: 4) {
                                        Image(item.type.imageName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 60)
                                        Text(item.type.displayName)
                                            .font(.AppTheme.rounded(size: 12, weight: .medium))
                                            .foregroundColor(Color.AppTheme.darkBrown)
                                        Text("x\(item.quantity)")
                                            .font(.AppTheme.caption)
                                            .foregroundColor(Color.AppTheme.sepia)
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(Color.AppTheme.warmCream)
                                    .cornerRadius(AppSpacing.cardCornerRadius)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .navigationTitle("Gift to \(sibling.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.AppTheme.sage)
                }
            }
            // Confirm-before-gift overlay — gifting is irreversible
            .overlay {
                if let veg = pendingGiftVeg {
                    PipDialogView(
                        message: "Give your \(veg.displayName) to \(sibling.name)? You can't get it back!",
                        choices: [
                            PipDialogChoice(label: "Yes, gift it!", style: .primary, action: {
                                let toGift = veg
                                pendingGiftVeg = nil
                                onGift(toGift)
                            }),
                            PipDialogChoice(label: "Maybe not", style: .subtle, action: {
                                pendingGiftVeg = nil
                            })
                        ]
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .animation(AnimationConstants.fadeMedium, value: pendingGiftVeg)
        }
    }
}
