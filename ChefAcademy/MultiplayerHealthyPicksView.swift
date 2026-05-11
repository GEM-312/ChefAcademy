//
//  MultiplayerHealthyPicksView.swift
//  ChefAcademy
//
//  Real-time multiplayer Healthy Picks — two kids on separate devices
//  race to tap healthy foods. Uses GameKit for matchmaking + sync.
//

import SwiftUI
import GameKit

struct MultiplayerHealthyPicksView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var avatarModel: AvatarModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var manager = MultiplayerManager()

    // Local game state
    @State private var flyingFoods: [FlyingFood] = []
    @State private var badChoices: Int = 0
    @State private var goodChoices: Int = 0
    @State private var coinsEarned: Int = 0
    @State private var round: Int = 0

    // Pip animation
    @State private var pipScale: CGFloat = 1.0
    @State private var pipOffset: CGFloat = 0
    @State private var pipRotation: Double = 0

    // Physics driver (TimelineView fixed-timestep accumulator)
    @State private var lastPhysicsTick: Date?
    @State private var physicsAccumulator: TimeInterval = 0
    @State private var spawnTimer: Timer?

    // Seeded RNG for deterministic food sequence
    @State private var rng: SeededRandomGenerator?
    @State private var foodSequence: [FoodChoice] = []
    @State private var spawnIntervals: [TimeInterval] = []
    @State private var localFinished: Bool = false

    // Constants
    private let gravity: CGFloat = 0.18
    private let maxBadChoices = 5
    private let totalRounds = 25

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.AppTheme.cream.ignoresSafeArea()

                switch manager.matchPhase {
                case .idle, .authenticating:
                    authOrIdleView
                case .matchmaking:
                    matchmakingView
                case .connected:
                    lobbyView
                case .countdown(let count):
                    countdownView(count: count)
                case .playing:
                    gameplayView(size: geo.size)
                case .finished:
                    resultsView
                case .error(let message):
                    errorView(message: message)
                }
            }
        }
        .onAppear {
            // Set local player info from profile for opponent display
            manager.setLocalPlayerInfo(
                name: avatarModel.name,
                gender: avatarModel.gender,
                level: gameState.playerLevel
            )
            if !GKLocalPlayer.local.isAuthenticated {
                manager.authenticateLocalPlayer()
            }
        }
        .onDisappear {
            cleanupGame()
            manager.disconnect()
        }
        .sheet(isPresented: $manager.showMatchmaker) {
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            return GameCenterMatchmakerView(matchRequest: request, manager: manager)
        }
        .sheet(item: Binding(
            get: { manager.authViewController.map { IdentifiableVC(vc: $0) } },
            set: { _ in manager.authViewController = nil }
        )) { item in
            GameCenterAuthView(viewController: item.vc)
        }
        .onReceive(manager.$matchPhase) { newPhase in
            if case .playing = newPhase {
                prepareAndStartGame()
            }
        }
        .onReceive(manager.$opponentFinished) { finished in
            if finished && localFinished {
                manager.matchPhase = .finished
            }
        }
    }

    // MARK: - Auth / Idle View

    private var authOrIdleView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Play with a Friend!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            PipWavingAnimatedView(size: .large)

            Text("Challenge another kid to a Healthy Picks race!")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Button(action: { manager.startMatchmaking() }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                    Text("Find a Player")
                }
                .font(.AppTheme.title)
                .foregroundColor(Color.AppTheme.cream)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
                .background(Color.AppTheme.goldenWheat)
                .cornerRadius(AppSpacing.cardCornerRadius)
            }
            .buttonStyle(BouncyButtonStyle())

            Button(action: { dismiss() }) {
                Text("Back")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Matchmaking View

    private var matchmakingView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Looking for a player...")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.sepia)
            Spacer()
        }
    }

    // MARK: - Lobby View (Both Connected)

    private var lobbyView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Player Found!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.sage)

            // VS display
            HStack(spacing: AppSpacing.xl) {
                // Local player
                VStack(spacing: AppSpacing.sm) {
                    playerAvatar(isLocal: true)
                    Text("You")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)
                }

                Text("VS")
                    .font(.AppTheme.rounded(size: 36, weight: .black))
                    .foregroundColor(Color.AppTheme.goldenWheat)

                // Opponent
                VStack(spacing: AppSpacing.sm) {
                    playerAvatar(isLocal: false)
                    Text(manager.opponentName.isEmpty ? "..." : manager.opponentName)
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .lineLimit(1)
                }
            }

            Button(action: { manager.sendReady() }) {
                Text(manager.localReady ? "Waiting..." : "Ready!")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.cream)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(manager.localReady ? Color.AppTheme.lightSepia : Color.AppTheme.sage)
                    .cornerRadius(AppSpacing.cardCornerRadius)
            }
            .buttonStyle(BouncyButtonStyle())
            .disabled(manager.localReady)

            if manager.localReady && !manager.opponentReady {
                Text("Waiting for your friend...")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }

            Spacer()
        }
    }

    // MARK: - Countdown View

    private func countdownView(count: Int) -> some View {
        VStack {
            Spacer()
            Text("\(count)")
                .font(.AppTheme.rounded(size: 120, weight: .black))
                .foregroundColor(Color.AppTheme.goldenWheat)
                .scaleEffect(1.0)
                .animation(AnimationConstants.springBouncy, value: count)
            Text("Get ready!")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.sepia)
            Spacer()
        }
    }

    // MARK: - Gameplay View

    private func gameplayView(size: CGSize) -> some View {
        ZStack {
            // Physics driver — fixed 60Hz accumulator, re-driven by display refresh.
            TimelineView(.animation) { ctx in
                Color.clear
                    .onChange(of: ctx.date) { _, newDate in
                        tickPhysics(now: newDate, size: size)
                    }
            }
            .allowsHitTesting(false)
            .onAppear { startFirstSpawn(size: size) }

            // Flying food items
            ForEach(flyingFoods) { item in
                if !item.tapped {
                    foodBubble(item: item)
                        .position(x: item.x, y: item.y)
                        .onTapGesture { tapFood(item) }
                } else if let icon = item.resultIcon {
                    Text(icon)
                        .font(.AppTheme.rounded(size: 40))
                        .position(x: item.x, y: item.y)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // HUD
            VStack(spacing: 4) {
                // Opponent bar (top)
                opponentScoreBar

                // Player score + hearts
                HStack {
                    // Close button
                    Button(action: {
                        cleanupGame()
                        manager.disconnect()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.AppTheme.title)
                            .foregroundColor(Color.AppTheme.sepia.opacity(0.6))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Your score
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.AppTheme.captionLarge)
                        Text("+\(coinsEarned)")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.AppTheme.warmCream.opacity(0.9))
                    .cornerRadius(AppSpacing.largeCornerRadius)

                    Spacer()

                    // Hearts
                    HStack(spacing: 4) {
                        ForEach(0..<maxBadChoices, id: \.self) { i in
                            Image(systemName: i < badChoices ? "heart.slash.fill" : "heart.fill")
                                .foregroundColor(i < badChoices ? Color.AppTheme.lightSepia : Color.AppTheme.terracotta)
                                .font(.AppTheme.callout)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                // Round progress
                ProgressView(value: Double(round), total: Double(totalRounds))
                    .tint(Color.AppTheme.sage)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer()
            }

            // Pip at the bottom — loops throw_veggie during play, progressive
            // fat frame after bad choices, full fat_flying on game-over cap.
            VStack {
                Spacer()
                onlineGamePip(size: 120)
                    .rotationEffect(.degrees(pipRotation))
                    .offset(y: pipOffset)
                    .scaleEffect(pipScale)
                    .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Online Game Pip (animated sprite selector)

    @ViewBuilder
    private func onlineGamePip(size: CGFloat) -> some View {
        if badChoices >= maxBadChoices {
            PipGameAnimationView(animation: .fatFlying, size: size, loop: false, fps: 15)
        } else if badChoices > 0 {
            let frameIdx = min(30, badChoices * 6)
            Image(String(format: "pip_fat_flying_frame_%02d", frameIdx))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            PipGameAnimationView(animation: .throwVeggie, size: size, loop: true, fps: 15)
        }
    }

    // MARK: - Opponent Score Bar

    private var opponentScoreBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // Opponent avatar (small)
            Image(manager.opponentGender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.AppTheme.terracotta, lineWidth: 1.5))

            Text(manager.opponentName)
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)

            Spacer()

            // Opponent score
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .foregroundColor(Color.AppTheme.terracotta)
                    .font(.AppTheme.micro)
                Text("+\(manager.opponentScore)")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }

            // Opponent hearts (compact)
            HStack(spacing: 2) {
                ForEach(0..<maxBadChoices, id: \.self) { i in
                    Circle()
                        .fill(i < manager.opponentBadChoices ? Color.AppTheme.lightSepia : Color.AppTheme.terracotta)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.AppTheme.terracotta.opacity(0.15))
        .cornerRadius(AppSpacing.smallCornerRadius)
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Results View

    private var resultsView: some View {
        let won = coinsEarned > manager.opponentFinalScore
        let tied = coinsEarned == manager.opponentFinalScore

        return ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: AppSpacing.xl)

                // Result title
                Text(won ? "You Won!" : (tied ? "It's a Tie!" : "Nice Try!"))
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(won ? Color.AppTheme.sage : (tied ? Color.AppTheme.goldenWheat : Color.AppTheme.terracotta))

                // Online result celebration — you are "on the right" from Pip's
                // perspective (you tap on your device → handUpRight).
                // Loss shows the fat-flying fail, tie stays neutral.
                if won {
                    PipGameAnimationView(
                        animation: .handUpRight,
                        size: 140,
                        loop: true,
                        fps: 15
                    )
                } else if tied {
                    PipWavingAnimatedView(size: .large)
                } else {
                    PipGameAnimationView(
                        animation: .fatFlying,
                        size: 140,
                        loop: false,
                        fps: 15
                    )
                }

                // Score comparison
                HStack(spacing: AppSpacing.xl) {
                    // You
                    VStack(spacing: AppSpacing.sm) {
                        playerAvatar(isLocal: true)
                        Text("You")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                        Text("\(coinsEarned)")
                            .font(.AppTheme.largeTitle)
                            .foregroundColor(Color.AppTheme.sage)
                        Text("coins")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                    }

                    VStack {
                        Text("VS")
                            .font(.AppTheme.rounded(size: 24, weight: .black))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    }

                    // Opponent
                    VStack(spacing: AppSpacing.sm) {
                        playerAvatar(isLocal: false)
                        Text(manager.opponentName)
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                            .lineLimit(1)
                        Text("\(manager.opponentFinalScore)")
                            .font(.AppTheme.largeTitle)
                            .foregroundColor(Color.AppTheme.terracotta)
                        Text("coins")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                }
                .softCard(showShadow: false)

                // Stats
                HStack(spacing: AppSpacing.lg) {
                    VStack {
                        Text("\(goodChoices)")
                            .font(.AppTheme.title)
                            .foregroundColor(Color.AppTheme.sage)
                        Text("Healthy")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                    }

                    VStack {
                        Text("\(coinsEarned + (won ? 15 : (tied ? 10 : 5)))")
                            .font(.AppTheme.title)
                            .foregroundColor(Color.AppTheme.goldenWheat)
                        Text("Total Coins")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                    }

                    VStack {
                        Text("\(badChoices)")
                            .font(.AppTheme.title)
                            .foregroundColor(Color.AppTheme.terracotta)
                        Text("Oops")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                    }
                }
                .softCard(showShadow: false)

                // Bonus message
                Text(won ? "Winner bonus: +15 coins!" : (tied ? "Tie bonus: +10 coins!" : "Good game bonus: +5 coins!"))
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.goldenWheat)

                // Buttons
                HStack(spacing: AppSpacing.md) {
                    Button(action: {
                        manager.disconnect()
                        resetForRematch()
                        manager.startMatchmaking()
                    }) {
                        Text("Play Again!")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.sm)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                    .buttonStyle(BouncyButtonStyle())

                    Button(action: {
                        cleanupGame()
                        manager.disconnect()
                        dismiss()
                    }) {
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
            awardCoins(won: won, tied: tied)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image("pip_got_idea")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)

            Text(message)
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.terracotta)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Button(action: {
                manager.matchPhase = .idle
            }) {
                Text("Try Again")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.cream)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.AppTheme.sage)
                    .cornerRadius(AppSpacing.cardCornerRadius)
            }
            .buttonStyle(BouncyButtonStyle())

            Button(action: { dismiss() }) {
                Text("Back")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Avatar Helper

    private func playerAvatar(isLocal: Bool) -> some View {
        let gender: Gender = isLocal ? avatarModel.gender : manager.opponentGender
        let imageName = gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06"

        return ZStack {
            Circle()
                .fill(Color.AppTheme.parchment)
                .frame(width: 70, height: 70)

            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .clipShape(Circle())
        }
    }

    // MARK: - Food Bubble

    private func foodBubble(item: FlyingFood) -> some View {
        VStack(spacing: 2) {
            if let imgName = item.food.imageName,
               UIImage(named: imgName) != nil {
                Image(imgName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            } else {
                Text(item.food.emoji)
                    .font(.AppTheme.timerDisplay)
            }
            Text(item.food.name)
                .font(.AppTheme.rounded(size: 11, weight: .bold))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)
                .shadow(color: Color.AppTheme.cream, radius: 2)
        }
        .scaleEffect(item.scale)
        .opacity(item.opacity)
        .rotationEffect(.degrees(item.rotation))
    }

    // MARK: - Game Logic

    private func prepareAndStartGame() {
        guard manager.gameSeed != 0 else { return }

        // Generate deterministic food sequence and spawn intervals
        var gen = SeededRandomGenerator(seed: manager.gameSeed)
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

        // Reset game state
        badChoices = 0
        goodChoices = 0
        coinsEarned = 0
        round = 0
        pipScale = 1.0
        pipOffset = 0
        pipRotation = 0
        flyingFoods = []
        localFinished = false

        lastPhysicsTick = nil
        physicsAccumulator = 0
    }

    private func startFirstSpawn(size: CGSize) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            spawnNextFood(size: size)
        }
    }

    private let physicsStep: TimeInterval = 1.0 / 60.0

    private func tickPhysics(now: Date, size: CGSize) {
        guard let last = lastPhysicsTick else {
            lastPhysicsTick = now
            return
        }
        let dt = min(now.timeIntervalSince(last), 0.1)
        lastPhysicsTick = now
        physicsAccumulator += dt
        while physicsAccumulator >= physicsStep {
            updatePhysics(size: size)
            physicsAccumulator -= physicsStep
        }
    }

    private func spawnNextFood(size: CGSize) {
        guard round < totalRounds, case .playing = manager.matchPhase else { return }

        let food = foodSequence[round]
        var gen = rng ?? SeededRandomGenerator(seed: manager.gameSeed)

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

        // Pip throw animation
        withAnimation(AnimationConstants.springSnappy) {
            pipScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(AnimationConstants.springQuick) {
                pipScale = max(1.0, 1.0 + CGFloat(badChoices) * 0.12)
            }
        }

        round += 1

        // Schedule next spawn using deterministic interval
        if round < totalRounds {
            let interval = spawnIntervals[round - 1]
            spawnTimer?.invalidate()
            spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                Task { @MainActor in
                    self.spawnNextFood(size: size)
                }
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

        // Check if all rounds spawned and no food left
        if round >= totalRounds && flyingFoods.filter({ !$0.tapped }).isEmpty && !localFinished {
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

            withAnimation(AnimationConstants.springTight) {
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

        // Send score update to opponent
        manager.sendScoreUpdate(score: coinsEarned, goodChoices: goodChoices, badChoices: badChoices)
    }

    private func finishGame() {
        guard !localFinished else { return }
        localFinished = true

        spawnTimer?.invalidate()
        spawnTimer = nil
        lastPhysicsTick = nil
        physicsAccumulator = 0

        manager.sendGameFinished(finalScore: coinsEarned, goodChoices: goodChoices, badChoices: badChoices)

        // If opponent already finished, go to results
        if manager.opponentFinished {
            manager.matchPhase = .finished
        } else {
            // Safety timeout — if opponent never reports, end after 15 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [self] in
                if localFinished && !manager.opponentFinished {
                    print("[Multiplayer] Opponent timeout — ending game")
                    manager.opponentFinalScore = manager.opponentScore
                    manager.opponentFinished = true
                    manager.matchPhase = .finished
                }
            }
        }
    }

    private func awardCoins(won: Bool, tied: Bool) {
        let bonus = won ? 15 : (tied ? 10 : 5)
        let total = coinsEarned + bonus
        gameState.addCoins(total)
        gameState.addXP(goodChoices * 3)

        // Report multiplayer achievements to Game Center
        let gc = GameCenterService.shared
        gc.reportAchievement(AchievementID.firstMultiplayer)
        gc.reportScore(total, leaderboardID: LeaderboardID.healthyPicks)
        gc.checkAchievements(gameState: gameState)
    }

    private func cleanupGame() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        lastPhysicsTick = nil
        physicsAccumulator = 0
    }

    private func resetForRematch() {
        cleanupGame()
        flyingFoods = []
        badChoices = 0
        goodChoices = 0
        coinsEarned = 0
        round = 0
        pipScale = 1.0
        pipOffset = 0
        pipRotation = 0
        localFinished = false
        rng = nil
        foodSequence = []
        spawnIntervals = []
    }
}

// MARK: - Identifiable wrapper for UIViewController

struct IdentifiableVC: Identifiable {
    let id = UUID()
    let vc: UIViewController
}

// MARK: - Game Center Auth UIKit Wrapper

struct GameCenterAuthView: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    MultiplayerHealthyPicksView()
        .environmentObject(GameState.preview)
        .environmentObject(AvatarModel())
}
