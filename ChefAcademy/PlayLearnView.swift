//
//  PlayLearnView.swift
//  ChefAcademy
//
//  Play & Learn hub — mini-games for learning about food and nutrition!
//

import SwiftUI

struct PlayLearnView: View {
    @EnvironmentObject var gameState: GameState
    @State private var selectedGame: MiniGameType?

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Play & Learn")
                                .font(.AppTheme.largeTitle)
                                .foregroundColor(Color.AppTheme.darkBrown)
                            Text("Fun games about food and your body!")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Pip message
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        PipWavingAnimatedView(size: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pip")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sage)
                            Text("Pick a game to play! You'll learn cool things about food while having fun!")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        .padding(AppSpacing.sm)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Games grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppSpacing.md) {
                        MiniGameCard(
                            title: "Veggie Match",
                            icon: "square.grid.2x2.fill",
                            description: "Match pairs of veggies!",
                            color: Color.AppTheme.sage,
                            isLocked: false
                        ) { selectedGame = .veggieMatch }

                        MiniGameCard(
                            title: "Nutrition Quiz",
                            icon: "questionmark.circle.fill",
                            description: "Test your food knowledge!",
                            color: Color.AppTheme.goldenWheat,
                            isLocked: false
                        ) { selectedGame = .nutritionQuiz }

                        MiniGameCard(
                            title: "Chop Challenge",
                            icon: "scissors",
                            description: "Chop veggies to the beat!",
                            color: Color.AppTheme.terracotta,
                            isLocked: false
                        ) { selectedGame = .chopChallenge }

                        MiniGameCard(
                            title: "Body Parts",
                            icon: "figure.stand",
                            description: "Match food to body parts!",
                            color: .purple.opacity(0.7),
                            isLocked: true
                        ) { }

                        MiniGameCard(
                            title: "Seed Sorting",
                            icon: "leaf.arrow.circlepath",
                            description: "Sort seeds by season!",
                            color: Color.AppTheme.sage.opacity(0.7),
                            isLocked: true
                        ) { }

                        MiniGameCard(
                            title: "Garden Puzzle",
                            icon: "puzzlepiece.fill",
                            description: "Build a garden puzzle!",
                            color: Color.AppTheme.goldenWheat.opacity(0.7),
                            isLocked: true
                        ) { }
                    }
                    .padding(.horizontal, AppSpacing.md)

                    Spacer().frame(height: 80)
                }
                .padding(.top, AppSpacing.md)
            }
        }
        .fullScreenCover(item: $selectedGame) { game in
            MiniGameRouterView(game: game)
                .environmentObject(gameState)
        }
    }
}

// MARK: - Mini Game Types

enum MiniGameType: String, Identifiable {
    case veggieMatch
    case nutritionQuiz
    case chopChallenge
    case bodyParts
    case seedSorting
    case gardenPuzzle

    var id: String { rawValue }
}

// MARK: - Mini Game Card

struct MiniGameCard: View {
    let title: String
    let icon: String
    let description: String
    let color: Color
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: isLocked ? "lock.fill" : icon)
                        .font(.system(size: 26))
                        .foregroundColor(isLocked ? Color.AppTheme.lightSepia : color)
                }

                Text(title)
                    .font(.AppTheme.headline)
                    .foregroundColor(isLocked ? Color.AppTheme.lightSepia : Color.AppTheme.darkBrown)
                    .lineLimit(1)

                Text(isLocked ? "Coming Soon!" : description)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

// MARK: - Mini Game Router (placeholder)

struct MiniGameRouterView: View {
    let game: MiniGameType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                Text(gameName)
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("Coming soon!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)

                PipWavingAnimatedView(size: 120)

                Button(action: { dismiss() }) {
                    Text("Back to Games")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.sm)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    private var gameName: String {
        switch game {
        case .veggieMatch: return "Veggie Match"
        case .nutritionQuiz: return "Nutrition Quiz"
        case .chopChallenge: return "Chop Challenge"
        case .bodyParts: return "Body Parts"
        case .seedSorting: return "Seed Sorting"
        case .gardenPuzzle: return "Garden Puzzle"
        }
    }
}

#Preview {
    PlayLearnView()
        .environmentObject(GameState())
}
