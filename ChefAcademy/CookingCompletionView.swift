//
//  CookingCompletionView.swift
//  ChefAcademy
//
//  Celebration screen after completing a cooking session!
//  Shows star rating, rewards, and a celebrating Pip.
//

import SwiftUI

struct CookingCompletionView: View {
    let recipe: Recipe
    let stars: Int       // 1-3
    let coins: Int
    let xp: Int
    let onDismiss: () -> Void

    @State private var starStates: [Bool] = [false, false, false]
    @State private var showRewards = false
    @State private var showHealthBoost = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            // Background
            Color.AppTheme.cream
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Recipe image (circle, gold border)
                Image(recipe.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.AppTheme.goldenWheat, lineWidth: 4)
                    )
                    .shadow(color: Color.AppTheme.goldenWheat.opacity(0.4), radius: 10, x: 0, y: 4)

                // Recipe title
                Text(recipe.title)
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                // Stars
                HStack(spacing: AppSpacing.md) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: starStates[index] ? "star.fill" : "star")
                            .font(.system(size: 44))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .scaleEffect(starStates[index] ? 1.0 : 0.3)
                            .rotationEffect(.degrees(starStates[index] ? 0 : -30))
                            .opacity(starStates[index] ? 1.0 : 0.3)
                    }
                }

                // Star message
                Text(starMessage)
                    .font(.AppTheme.title3)
                    .foregroundColor(Color.AppTheme.sepia)

                // Celebrating Pip
                PipWavingAnimatedView(size: 140)

                // Reward chips
                if showRewards {
                    HStack(spacing: AppSpacing.lg) {
                        rewardChip(icon: "circle.fill", value: "+\(coins)", color: Color.AppTheme.goldenWheat)
                        rewardChip(icon: "star.circle.fill", value: "+\(xp) XP", color: Color.AppTheme.sage)
                    }
                    .transition(.opacity)
                }

                // Body Buddy health boost summary
                if showHealthBoost {
                    VStack(spacing: AppSpacing.xs) {
                        Text("Body Buddy Boost!")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color.AppTheme.darkBrown)

                        HStack(spacing: AppSpacing.sm) {
                            ForEach(boostedOrgans, id: \.name) { organ in
                                VStack(spacing: 2) {
                                    Image(systemName: organ.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(organ.color)
                                    Text("+\(organ.boost)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(organ.color)
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.cardCornerRadius)
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Back to Kitchen button
                if showButton {
                    Button(action: onDismiss) {
                        Text("Back to Kitchen")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(16)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .padding(.horizontal, AppSpacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: AppSpacing.lg)
            }
        }
        .onAppear {
            animateStars()
        }
    }

    // MARK: - Star Message

    var starMessage: String {
        switch stars {
        case 3: return "Perfect Chef!"
        case 2: return "Great Job!"
        default: return "Good Try!"
        }
    }

    // MARK: - Boosted Organs

    struct OrganBoost: Hashable {
        let name: String
        let icon: String
        let color: Color
        let boost: Int

        func hash(into hasher: inout Hasher) { hasher.combine(name) }
        static func == (lhs: OrganBoost, rhs: OrganBoost) -> Bool { lhs.name == rhs.name }
    }

    var boostedOrgans: [OrganBoost] {
        var organs: [String: Int] = [:]

        // Collect nutrients from all recipe ingredients
        for vegType in recipe.gardenIngredients {
            for nutrient in vegType.nutrients {
                let organ = nutrient.benefitsOrgan
                organs[organ, default: 0] += stars
            }
        }
        for pantryItem in recipe.pantryIngredients {
            for nutrient in pantryItem.nutrients {
                let organ = nutrient.benefitsOrgan
                organs[organ, default: 0] += stars
            }
        }

        // Map to display data (top 4 organs)
        return organs.sorted { $0.value > $1.value }.prefix(4).map { organ, boost in
            let (icon, color): (String, Color) = {
                switch organ {
                case "Brain": return ("brain.head.profile", .purple)
                case "Heart", "Blood": return ("heart.fill", .red)
                case "Muscles": return ("figure.strengthtraining.traditional", .orange)
                case "Bones": return ("figure.stand", .brown)
                case "Immune System": return ("shield.fill", .blue)
                case "Energy", "Whole Body": return ("bolt.fill", .yellow)
                case "Eyes": return ("eye.fill", .cyan)
                case "Skin": return ("sparkles", .pink)
                default: return ("staroflife.fill", Color.AppTheme.sage)
                }
            }()
            return OrganBoost(name: organ, icon: icon, color: color, boost: boost)
        }
    }

    // MARK: - Reward Chip

    private func rewardChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(20)
    }

    // MARK: - Animate Stars Sequentially

    private func animateStars() {
        for i in 0..<stars {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3 + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    starStates[i] = true
                }
            }
        }

        // Show rewards after stars
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(stars) * 0.3 + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showRewards = true
            }
        }

        // Show health boost after rewards
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(stars) * 0.3 + 1.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showHealthBoost = true
            }
        }

        // Show button after health boost
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(stars) * 0.3 + 1.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showButton = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CookingCompletionView(
        recipe: GardenRecipes.all[0],
        stars: 3,
        coins: 50,
        xp: 45,
        onDismiss: {}
    )
}
