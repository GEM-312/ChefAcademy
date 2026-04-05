//
//  LocalVersusView.swift
//  ChefAcademy
//
//  Local 2-player Healthy Picks — siblings take turns on the same device.
//  Both play the exact same food sequence (seeded RNG), then compare scores.
//

import SwiftUI
import SwiftData

// MARK: - Local Versus Mode

struct LocalVersusView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Flow phases
    @State private var phase: LocalVersusPhase = .pickPlayers
    @State private var player1: UserProfile?
    @State private var player2: UserProfile?

    // Game results
    @State private var player1Score: Int = 0
    @State private var player1Good: Int = 0
    @State private var player1Bad: Int = 0
    @State private var player2Score: Int = 0
    @State private var player2Good: Int = 0
    @State private var player2Bad: Int = 0

    // Shared seed so both players get the same food
    @State private var gameSeed: UInt64 = 0

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            switch phase {
            case .pickPlayers:
                pickPlayersView
                    .onAppear {
                        // Auto-select current child as Player 1
                        if player1 == nil, let current = currentProfile, !current.isParent {
                            player1 = current
                        }
                    }
            case .player1Ready:
                if let p1 = player1 {
                    playerReadyView(player: p1, playerNum: 1)
                }
            case .player1Playing:
                LocalVersusGameView(
                    seed: gameSeed,
                    playerName: player1?.name ?? "Player 1",
                    playerNum: 1,
                    onFinish: { score, good, bad in
                        player1Score = score
                        player1Good = good
                        player1Bad = bad
                        phase = .player2Ready
                    }
                )
            case .player2Ready:
                if let p2 = player2 {
                    playerReadyView(player: p2, playerNum: 2)
                }
            case .player2Playing:
                LocalVersusGameView(
                    seed: gameSeed,
                    playerName: player2?.name ?? "Player 2",
                    playerNum: 2,
                    onFinish: { score, good, bad in
                        player2Score = score
                        player2Good = good
                        player2Bad = bad
                        phase = .results
                    }
                )
            case .results:
                resultsView
            }
        }
    }

    // MARK: - Pick Players

    /// All children in the family (including parent if they want to play)
    private var allPlayers: [UserProfile] {
        guard let family = sessionManager.familyProfile else { return [] }
        return family.childProfiles(in: modelContext)
    }

    /// The currently active profile (auto-selected as Player 1 if they're a child)
    private var currentProfile: UserProfile? {
        sessionManager.activeProfile
    }

    private var pickPlayersView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Different text depending on if current user is already Player 1
            if player1 != nil && player1?.id == currentProfile?.id {
                Text("Who do you want to play?")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)
            } else {
                Text("Pick Two Players!")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }

            PipWavingAnimatedView(size: 100)

            if allPlayers.count < 2 {
                Text("You need at least 2 players!")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.terracotta)
                    .padding()

                Text("Add another Little Chef in the Parent Dashboard.")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            } else {
                // If current user is auto-selected, only show siblings to pick
                if player1 != nil && player1?.id == currentProfile?.id {
                    Text("Pick your opponent:")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.sepia)
                }

                // Player selection grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: AppSpacing.md) {
                    ForEach(allPlayers, id: \.id) { child in
                        playerSelectCard(child: child)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            // Selected players display
            if player1 != nil || player2 != nil {
                HStack(spacing: AppSpacing.lg) {
                    selectedPlayerChip(player: player1, label: "Player 1")
                    Text("VS")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                    selectedPlayerChip(player: player2, label: "Player 2")
                }
                .padding(.vertical, AppSpacing.sm)
            }

            // Start button
            if player1 != nil && player2 != nil {
                Button(action: {
                    gameSeed = UInt64.random(in: 1...UInt64.max)
                    phase = .player1Ready
                }) {
                    Text("Start Game!")
                        .font(.AppTheme.title)
                        .foregroundColor(Color.AppTheme.cream)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .buttonStyle(BouncyButtonStyle())
            }

            Button(action: { dismiss() }) {
                Text("Back")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Player Ready Screen

    private func playerReadyView(player: UserProfile, playerNum: Int) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("\(player.name)'s Turn!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            // Avatar
            ZStack {
                Circle()
                    .fill(Color.AppTheme.parchment)
                    .frame(width: 120, height: 120)

                Image(player.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            }

            Text(playerNum == 1 ? "You go first! Get ready!" : "Your turn! Can you beat \(player1?.name ?? "them")?")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.sepia)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            if playerNum == 2 {
                // Show Player 1's score as the target
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(Color.AppTheme.goldenWheat)
                        .font(.system(size: 14))
                    Text("\(player1?.name ?? "Player 1") scored \(player1Score) coins")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.goldenWheat)
                }
                .padding(AppSpacing.sm)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.cardCornerRadius)
            }

            Text("Hand the device to \(player.name)!")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.terracotta)
                .italic()

            Button(action: {
                phase = playerNum == 1 ? .player1Playing : .player2Playing
            }) {
                Text("Ready!")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.cream)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color.AppTheme.sage)
                    .cornerRadius(AppSpacing.cardCornerRadius)
            }
            .buttonStyle(BouncyButtonStyle())

            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        let p1Won = player1Score > player2Score
        let tied = player1Score == player2Score
        let winnerName = p1Won ? (player1?.name ?? "Player 1") : (player2?.name ?? "Player 2")

        return ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: AppSpacing.xl)

                Text(tied ? "It's a Tie!" : "\(winnerName) Wins!")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(tied ? Color.AppTheme.goldenWheat : Color.AppTheme.sage)

                PipWavingAnimatedView(size: 100)

                // Score comparison
                HStack(spacing: AppSpacing.xl) {
                    // Player 1
                    VStack(spacing: AppSpacing.sm) {
                        playerAvatarSmall(player: player1)
                        Text(player1?.name ?? "P1")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .lineLimit(1)
                        Text("\(player1Score)")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(p1Won || tied ? Color.AppTheme.sage : Color.AppTheme.sepia)
                        Text("coins")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)

                        HStack(spacing: AppSpacing.sm) {
                            Label("\(player1Good)", systemImage: "checkmark.circle.fill")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sage)
                            Label("\(player1Bad)", systemImage: "xmark.circle.fill")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.terracotta)
                        }
                    }

                    Text("VS")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(Color.AppTheme.goldenWheat)

                    // Player 2
                    VStack(spacing: AppSpacing.sm) {
                        playerAvatarSmall(player: player2)
                        Text(player2?.name ?? "P2")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .lineLimit(1)
                        Text("\(player2Score)")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(!p1Won || tied ? Color.AppTheme.sage : Color.AppTheme.sepia)
                        Text("coins")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)

                        HStack(spacing: AppSpacing.sm) {
                            Label("\(player2Good)", systemImage: "checkmark.circle.fill")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sage)
                            Label("\(player2Bad)", systemImage: "xmark.circle.fill")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.terracotta)
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.cardCornerRadius)
                .padding(.horizontal, AppSpacing.md)

                // Both players earn their coins
                Text("Both players earned their coins!")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.goldenWheat)

                // Buttons
                HStack(spacing: AppSpacing.md) {
                    Button(action: {
                        // Reset for rematch
                        player1Score = 0; player1Good = 0; player1Bad = 0
                        player2Score = 0; player2Good = 0; player2Bad = 0
                        gameSeed = UInt64.random(in: 1...UInt64.max)
                        phase = .player1Ready
                    }) {
                        Text("Rematch!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.sm)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .buttonStyle(BouncyButtonStyle())

                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.sepia)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.sm)
                            .background(Color.AppTheme.warmCream)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                    .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 100)
            }
        }
        .onAppear {
            // Award coins to both players' profiles
            // Player 1 coins added to their GameState when they were playing
            // For now, coins are just displayed — proper per-profile saving would need
            // loading each player's GameState separately
            let bonus = tied ? 10 : 5
            gameState.addCoins(player1Score + player2Score + bonus)
        }
    }

    // MARK: - Helper Views

    private func playerSelectCard(child: UserProfile) -> some View {
        let isSelected = player1?.id == child.id || player2?.id == child.id
        let slot = player1?.id == child.id ? "P1" : (player2?.id == child.id ? "P2" : nil)

        return Button(action: {
            selectPlayer(child)
        }) {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.AppTheme.sage.opacity(0.2) : Color.AppTheme.parchment)
                        .frame(width: 70, height: 70)

                    Image(child.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())

                    if let slot = slot {
                        Text(slot)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.AppTheme.cream)
                            .padding(4)
                            .background(Color.AppTheme.sage)
                            .clipShape(Circle())
                            .offset(x: 25, y: -25)
                    }
                }

                Text(child.name)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)
            }
            .padding(AppSpacing.sm)
            .background(isSelected ? Color.AppTheme.sage.opacity(0.1) : Color.clear)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }

    private func selectedPlayerChip(player: UserProfile?, label: String) -> some View {
        VStack(spacing: 4) {
            if let player = player {
                Image(player.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                Text(player.name)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
            } else {
                Circle()
                    .fill(Color.AppTheme.lightSepia.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(Text("?").font(.AppTheme.headline).foregroundColor(Color.AppTheme.sepia))
                Text(label)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }
        }
    }

    private func playerAvatarSmall(player: UserProfile?) -> some View {
        ZStack {
            Circle()
                .fill(Color.AppTheme.parchment)
                .frame(width: 60, height: 60)
            if let player = player {
                Image(player.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }
        }
    }

    private func selectPlayer(_ child: UserProfile) {
        if player1?.id == child.id {
            player1 = nil
        } else if player2?.id == child.id {
            player2 = nil
        } else if player1 == nil {
            player1 = child
        } else if player2 == nil {
            player2 = child
        } else {
            // Both slots full — replace player 2
            player2 = child
        }
    }
}

// MARK: - Phase Enum

enum LocalVersusPhase {
    case pickPlayers
    case player1Ready
    case player1Playing
    case player2Ready
    case player2Playing
    case results
}

// MARK: - Local Versus Game View (single player's turn)

struct LocalVersusGameView: View {
    let seed: UInt64
    let playerName: String
    let playerNum: Int
    let onFinish: (Int, Int, Int) -> Void // (score, good, bad)

    // Game state
    @State private var flyingFoods: [FlyingFood] = []
    @State private var badChoices: Int = 0
    @State private var goodChoices: Int = 0
    @State private var coinsEarned: Int = 0
    @State private var round: Int = 0

    // Pip animation
    @State private var pipScale: CGFloat = 1.0
    @State private var pipOffset: CGFloat = 0
    @State private var pipRotation: Double = 0

    // Timers
    @State private var gameTimer: Timer?
    @State private var spawnTimer: Timer?

    // Deterministic sequence
    @State private var rng: SeededRandomGenerator?
    @State private var foodSequence: [FoodChoice] = []
    @State private var spawnIntervals: [TimeInterval] = []
    @State private var gameFinished: Bool = false

    private let gravity: CGFloat = 0.18
    private let maxBadChoices = 5
    private let totalRounds = 25

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.AppTheme.cream.ignoresSafeArea()

                // Flying food
                ForEach(flyingFoods) { item in
                    if !item.tapped {
                        foodBubble(item: item)
                            .position(x: item.x, y: item.y)
                            .onTapGesture { tapFood(item) }
                    } else if let icon = item.resultIcon {
                        Text(icon)
                            .font(.system(size: 40))
                            .position(x: item.x, y: item.y)
                    }
                }

                // HUD
                VStack(spacing: 4) {
                    HStack {
                        // Player name badge
                        Text("\(playerName)")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(12)

                        Spacer()

                        // Score
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(Color.AppTheme.goldenWheat)
                                .font(.system(size: 14))
                            Text("+\(coinsEarned)")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.AppTheme.warmCream.opacity(0.9))
                        .cornerRadius(20)

                        Spacer()

                        // Hearts
                        HStack(spacing: 4) {
                            ForEach(0..<maxBadChoices, id: \.self) { i in
                                Image(systemName: i < badChoices ? "heart.slash.fill" : "heart.fill")
                                    .foregroundColor(i < badChoices ? Color.AppTheme.lightSepia : Color.AppTheme.terracotta)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)

                    ProgressView(value: Double(round), total: Double(totalRounds))
                        .tint(Color.AppTheme.sage)
                        .padding(.horizontal, AppSpacing.xl)

                    Spacer()
                }

                // Pip
                VStack {
                    Spacer()
                    Image("pip_got_idea")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80 * pipScale, height: 80 * pipScale)
                        .rotationEffect(.degrees(pipRotation))
                        .offset(y: pipOffset)
                        .scaleEffect(pipScale)
                        .padding(.bottom, 60)
                }
            }
            .onAppear { startGame(size: geo.size) }
            .onDisappear { cleanup() }
        }
    }

    // MARK: - Food Bubble

    private func foodBubble(item: FlyingFood) -> some View {
        VStack(spacing: 2) {
            if let imgName = item.food.imageName {
                Image(imgName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            } else {
                Text(item.food.emoji)
                    .font(.system(size: 48))
            }
            Text(item.food.name)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)
                .shadow(color: .white, radius: 2)
        }
        .scaleEffect(item.scale)
        .opacity(item.opacity)
        .rotationEffect(.degrees(item.rotation))
    }

    // MARK: - Game Logic

    private func startGame(size: CGSize) {
        var gen = SeededRandomGenerator(seed: seed)
        let allFoods = HealthyChoiceGameView.allFoods

        foodSequence = (0..<totalRounds).map { _ in
            allFoods[Int.random(in: 0..<allFoods.count, using: &gen)]
        }
        spawnIntervals = (0..<totalRounds).map { round in
            let base = 1.8 - Double(round) * 0.04
            let jitter = Double.random(in: -0.1...0.1, using: &gen)
            return max(0.7, base + jitter)
        }
        rng = gen

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updatePhysics(size: size)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            spawnNextFood(size: size)
        }
    }

    private func spawnNextFood(size: CGSize) {
        guard round < totalRounds, !gameFinished else { return }

        let food = foodSequence[round]
        var gen = rng ?? SeededRandomGenerator(seed: seed)

        let startX = CGFloat.random(in: size.width * 0.25 ... size.width * 0.75, using: &gen)
        let velocity = -CGFloat.random(in: 9...13, using: &gen)
        let rotation = Double.random(in: -10...10, using: &gen)
        let wobblePhase = CGFloat.random(in: 0 ... .pi * 2, using: &gen)
        let wobbleSpeed = CGFloat.random(in: 0.04...0.08, using: &gen)
        let wobbleAmount = CGFloat.random(in: 15...35, using: &gen)

        rng = gen

        let item = FlyingFood(
            food: food,
            x: startX,
            y: size.height - 120,
            velocity: velocity,
            rotation: rotation,
            wobblePhase: wobblePhase,
            wobbleSpeed: wobbleSpeed,
            wobbleAmount: wobbleAmount
        )

        flyingFoods.append(item)

        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pipScale = 1.15 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pipScale = max(1.0, 1.0 + CGFloat(badChoices) * 0.12)
            }
        }

        round += 1

        if round < totalRounds {
            let interval = spawnIntervals[round - 1]
            spawnTimer?.invalidate()
            spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                self.spawnNextFood(size: size)
            }
        }
    }

    private func updatePhysics(size: CGSize) {
        for i in flyingFoods.indices {
            guard !flyingFoods[i].tapped else { continue }
            flyingFoods[i].velocity += gravity
            flyingFoods[i].y += flyingFoods[i].velocity
            flyingFoods[i].wobblePhase += flyingFoods[i].wobbleSpeed
            flyingFoods[i].x += sin(flyingFoods[i].wobblePhase) * (flyingFoods[i].wobbleAmount * 0.03)
            flyingFoods[i].rotation += Double(flyingFoods[i].velocity) * 0.15
            let normalizedY = flyingFoods[i].y / size.height
            flyingFoods[i].scale = 0.85 + (1.0 - abs(normalizedY - 0.4)) * 0.25

            if flyingFoods[i].y > size.height + 50 {
                flyingFoods[i].tapped = true
            }
        }

        flyingFoods.removeAll { $0.tapped && $0.resultIcon == nil }

        if round >= totalRounds && flyingFoods.filter({ !$0.tapped }).isEmpty && !gameFinished {
            finishGame()
        }
    }

    private func tapFood(_ item: FlyingFood) {
        guard let index = flyingFoods.firstIndex(where: { $0.id == item.id }),
              !flyingFoods[index].tapped else { return }

        flyingFoods[index].tapped = true

        if item.food.isHealthy {
            flyingFoods[index].resultIcon = "\u{2705}"
            goodChoices += 1
            coinsEarned += 5

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                flyingFoods.removeAll { $0.id == item.id }
            }
        } else {
            flyingFoods[index].resultIcon = "\u{274C}"
            badChoices += 1

            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                pipScale = 1.0 + CGFloat(badChoices) * 0.15
                pipRotation = Double.random(in: -10...10)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                flyingFoods.removeAll { $0.id == item.id }
            }

            if badChoices >= maxBadChoices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    finishGame()
                }
            }
        }
    }

    private func finishGame() {
        guard !gameFinished else { return }
        gameFinished = true
        cleanup()

        // Brief delay so player sees their final score
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onFinish(coinsEarned, goodChoices, badChoices)
        }
    }

    private func cleanup() {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        gameTimer = nil
        spawnTimer = nil
    }
}

// MARK: - Preview

#Preview {
    LocalVersusView()
        .environmentObject(GameState.preview)
        .environmentObject(SessionManager())
        .environmentObject(AvatarModel())
}
