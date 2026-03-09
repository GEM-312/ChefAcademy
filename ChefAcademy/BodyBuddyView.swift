//
//  BodyBuddyView.swift
//  ChefAcademy
//
//  Body Buddy — see how food travels through your body!
//  Shows health stats from cooking and eating.
//

import SwiftUI

struct BodyBuddyView: View {
    @EnvironmentObject var gameState: GameState
    @Binding var selectedTab: MainTabView.Tab

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Body Buddy")
                                .font(.AppTheme.largeTitle)
                                .foregroundColor(Color.AppTheme.darkBrown)
                            Text("See how food helps your body!")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Body figure with health rings
                    VStack(spacing: AppSpacing.md) {
                        // Cartoon body placeholder
                        ZStack {
                            Image(systemName: "figure.stand")
                                .font(.system(size: 120))
                                .foregroundColor(Color.AppTheme.sepia.opacity(0.3))

                            // Organ health indicators positioned on body
                            VStack(spacing: 0) {
                                // Brain
                                HealthOrb(
                                    icon: "brain.head.profile",
                                    label: "Brain",
                                    value: gameState.brainHealth,
                                    color: .purple
                                )

                                HStack(spacing: 40) {
                                    // Heart
                                    HealthOrb(
                                        icon: "heart.fill",
                                        label: "Heart",
                                        value: gameState.heartHealth,
                                        color: .red
                                    )
                                    // Lungs / Immune
                                    HealthOrb(
                                        icon: "shield.fill",
                                        label: "Immune",
                                        value: gameState.immuneHealth,
                                        color: .blue
                                    )
                                }

                                HStack(spacing: 40) {
                                    // Muscles
                                    HealthOrb(
                                        icon: "figure.strengthtraining.traditional",
                                        label: "Muscles",
                                        value: gameState.muscleHealth,
                                        color: .orange
                                    )
                                    // Bones
                                    HealthOrb(
                                        icon: "bone.fill",
                                        label: "Bones",
                                        value: gameState.boneHealth,
                                        color: Color.AppTheme.warmKhaki
                                    )
                                }

                                // Energy
                                HealthOrb(
                                    icon: "bolt.fill",
                                    label: "Energy",
                                    value: gameState.energyLevel,
                                    color: Color.AppTheme.goldenWheat
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.lg)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Pip message
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        PipWavingAnimatedView(size: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pip")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sage)
                            Text("Cook healthy recipes to make your Body Buddy stronger! Each veggie and ingredient helps different parts of your body.")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        .padding(AppSpacing.sm)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Cook something button
                    Button(action: { selectedTab = .kitchen }) {
                        HStack {
                            Image(systemName: "fork.knife")
                            Text("Cook Something!")
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

                    Spacer().frame(height: 80)
                }
                .padding(.top, AppSpacing.md)
            }
        }
    }
}

// MARK: - Health Orb

struct HealthOrb: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color

    private var progress: Double {
        min(Double(value) / 100.0, 1.0)
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.sepia)
        }
    }
}

#Preview {
    BodyBuddyView(selectedTab: .constant(.bodyBuddy))
        .environmentObject(GameState())
}
