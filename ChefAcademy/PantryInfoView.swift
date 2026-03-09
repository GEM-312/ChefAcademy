//
//  PantryInfoView.swift
//  ChefAcademy
//
//  Full-screen educational view for pantry items.
//  Kids tap nutrient cards to learn about nutrition and earn coins.
//

import SwiftUI

struct PantryInfoView: View {
    let item: PantryItem
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var gameState: GameState

    @State private var appeared = false
    @State private var showCoinReward: String? = nil

    private func nutrientKnowledgeID(_ nutrient: NutrientType) -> String {
        "pantry_\(item.rawValue)_\(nutrient.rawValue)"
    }

    private var funFactKnowledgeID: String {
        "pantry_\(item.rawValue)_funfact"
    }

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    // Item name
                    Text(item.displayName)
                        .font(.custom("Georgia", size: 32).bold())
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .scaleEffect(appeared ? 1.0 : 0.8)
                        .opacity(appeared ? 1.0 : 0)

                    // Item image
                    Image(item.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding(AppSpacing.lg)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                        .shadow(color: Color.AppTheme.sepia.opacity(0.1), radius: 8, y: 4)
                        .scaleEffect(appeared ? 1.0 : 0.9)
                        .opacity(appeared ? 1.0 : 0)

                    // Price info
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.system(size: 16))
                        Text("\(item.shopPrice) coins")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(20)
                    .opacity(appeared ? 1.0 : 0)

                    // Nutrients ("What's Inside")
                    nutrientsSection
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1.0 : 0)

                    // Fun Fact
                    funFactSection
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1.0 : 0)

                    Spacer(minLength: 80)
                }
                .padding(.top, 60)
            }

            // Close Button + Coin Counter
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.system(size: 14))
                        Text("\(gameState.coins)")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(20)
                    .padding(.leading, AppSpacing.md)
                    .padding(.top, AppSpacing.md)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color.AppTheme.sepia.opacity(0.6))
                            .padding(AppSpacing.md)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // Floating Coin Reward
            if let reward = showCoinReward {
                VStack {
                    Text(reward)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .transition(.scale.combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    // MARK: - Nutrients Section

    private var nutrientsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("What's Inside")
                    .font(.custom("Georgia", size: 20).bold())
                    .foregroundColor(Color.AppTheme.darkBrown)
                Spacer()
                Text("Tap to learn!")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.AppTheme.goldenWheat)
            }

            VStack(spacing: AppSpacing.xs) {
                ForEach(item.nutrients, id: \.rawValue) { nutrient in
                    nutrientRow(nutrient)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func nutrientRow(_ nutrient: NutrientType) -> some View {
        let knowledgeID = nutrientKnowledgeID(nutrient)
        let isClaimed = gameState.isKnowledgeClaimed(knowledgeID)

        return Button(action: {
            if gameState.claimKnowledgeReward(id: knowledgeID, coins: nutrient.coinReward) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showCoinReward = "+\(nutrient.coinReward)"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showCoinReward = nil }
                }
            }
        }) {
            HStack(spacing: AppSpacing.md) {
                Text(nutrient.emoji)
                    .font(.system(size: 26))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(nutrient.rawValue)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.AppTheme.darkBrown)

                    HStack(spacing: 4) {
                        Image(systemName: nutrient.organIcon)
                            .font(.system(size: 12))
                            .foregroundColor(Color.AppTheme.sage)

                        Text("Helps your \(nutrient.benefitsOrgan)")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                }

                Spacer()

                if isClaimed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.AppTheme.sage)
                        .font(.system(size: 18))
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.system(size: 10))
                        Text("+\(nutrient.coinReward)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(isClaimed ? Color.AppTheme.sage.opacity(0.1) : Color.AppTheme.parchment.opacity(0.6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fun Fact Section

    private var funFactSection: some View {
        let isClaimed = gameState.isKnowledgeClaimed(funFactKnowledgeID)

        return Button(action: {
            if gameState.claimKnowledgeReward(id: funFactKnowledgeID, coins: 5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showCoinReward = "+5"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showCoinReward = nil }
                }
            }
        }) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color.AppTheme.goldenWheat)
                    Text("Fun Fact!")
                        .font(.custom("Georgia", size: 20).bold())
                        .foregroundColor(Color.AppTheme.darkBrown)
                    Spacer()
                    if isClaimed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.AppTheme.sage)
                            .font(.system(size: 18))
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(Color.AppTheme.goldenWheat)
                                .font(.system(size: 10))
                            Text("+5")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                    }
                }

                Text(item.funFact)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(Color.AppTheme.sepia)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.lg)
            .background(isClaimed ? Color.AppTheme.sage.opacity(0.1) : Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .shadow(color: Color.AppTheme.sepia.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.lg)
    }
}

#Preview {
    PantryInfoView(item: .eggs)
        .environmentObject(GameState())
}
