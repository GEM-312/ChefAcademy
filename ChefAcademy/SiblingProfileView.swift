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
    let onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showGarden = false

    private var playerData: PlayerData? {
        sibling.playerData(in: modelContext)
    }

    private var characterImage: String {
        sibling.gender == .boy ? "boy_card_frame_28" : "girl_card_frame_15"
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
                            .cornerRadius(20)

                            if data.gardenLikes > 0 {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                    Text("\(data.gardenLikes) likes")
                                        .font(.AppTheme.headline)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs)
                                .background(Color.AppTheme.warmCream)
                                .cornerRadius(20)
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
                                                    .font(.system(size: 10, weight: .medium, design: .rounded))
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
                                                    .font(.system(size: 14))
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
                onBack: { showGarden = false }
            )
        }
    }
}
