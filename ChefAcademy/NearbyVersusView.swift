//
//  NearbyVersusView.swift
//  ChefAcademy
//
//  Nearby multiplayer Healthy Picks — two devices in the same room
//  connect via WiFi/Bluetooth. No Game Center needed!
//

import SwiftUI

struct NearbyVersusView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var avatarModel: AvatarModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var manager = NearbyMultiplayerManager()

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

    // Seeded RNG
    @State private var rng: SeededRandomGenerator?
    @State private var foodSequence: [FoodChoice] = []
    @State private var spawnIntervals: [TimeInterval] = []
    @State private var localFinished: Bool = false

    private let gravity: CGFloat = 0.18
    private let maxBadChoices = 5
    private let totalRounds = 25

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.AppTheme.cream.ignoresSafeArea()

                switch manager.matchPhase {
                case .idle:
                    idleView
                case .searching:
                    searchingView
                case .connected:
                    lobbyView
                case .countdown(let count):
                    countdownView(count: count)
                case .playing:
                    gameplayView(size: geo.size)
                case .waitingForOpponent:
                    waitingView
                case .finished:
                    resultsView
                case .error(let msg):
                    errorView(message: msg)
                }
            }
        }
        .onAppear {
            manager.localName = avatarModel.name.isEmpty ? "Player" : avatarModel.name
            manager.localGenderRaw = avatarModel.gender.rawValue
        }
        .onDisappear {
            cleanupGame()
            manager.disconnect()
        }
        .onReceive(manager.$matchPhase) { phase in
            if case .playing = phase {
                prepareAndStartGame()
            }
        }
        .onReceive(manager.$opponentFinished) { finished in
            if finished && localFinished {
                manager.matchPhase = .finished
            }
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Nearby Battle!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            PipWavingAnimatedView(size: .large)

            Text("Play with someone nearby!\nBoth devices need the app open.")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Button(action: { manager.startSearching() }) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Find Nearby Player")
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

    // MARK: - Searching View

    private var searchingView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Animated radar effect
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.AppTheme.goldenWheat.opacity(0.3), lineWidth: 2)
                        .frame(width: CGFloat(80 + i * 40), height: CGFloat(80 + i * 40))
                }
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.AppTheme.rounded(size: 40))
                    .foregroundColor(Color.AppTheme.goldenWheat)
            }

            Text("Looking for nearby player...")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.sepia)

            Text("Make sure both devices have\nHealthy Picks open!")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.lightSepia)
                .multilineTextAlignment(.center)

            ProgressView()
                .scaleEffect(1.2)

            Button(action: {
                manager.stopSearching()
                manager.matchPhase = .idle
            }) {
                Text("Cancel")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Lobby View

    private var lobbyView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Player Found!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.sage)

            HStack(spacing: AppSpacing.xl) {
                VStack(spacing: AppSpacing.sm) {
                    playerAvatar(gender: avatarModel.gender)
                    Text(avatarModel.name.isEmpty ? "You" : avatarModel.name)
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)
                }

                Text("VS")
                    .font(.AppTheme.rounded(size: 36, weight: .black))
                    .foregroundColor(Color.AppTheme.goldenWheat)

                VStack(spacing: AppSpacing.sm) {
                    playerAvatar(gender: manager.opponentGender)
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

    // MARK: - Countdown

    private func countdownView(count: Int) -> some View {
        VStack {
            Spacer()
            Text("\(count)")
                .font(.AppTheme.rounded(size: 120, weight: .black))
                .foregroundColor(Color.AppTheme.goldenWheat)
            Text("Get ready!")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.sepia)
            Spacer()
        }
    }

    // MARK: - Gameplay

    private func gameplayView(size: CGSize) -> some View {
        ZStack {
            // Physics driver — fires updatePhysics at fixed 60Hz internally,
            // re-driven by display refresh (TimelineView pauses offscreen).
            TimelineView(.animation) { ctx in
                Color.clear
                    .onChange(of: ctx.date) { _, newDate in
                        tickPhysics(now: newDate, size: size)
                    }
            }
            .allowsHitTesting(false)
            .onAppear { startFirstSpawn(size: size) }

            ForEach(flyingFoods) { item in
                if !item.tapped {
                    foodBubble(item: item)
                        .position(x: item.x, y: item.y)
                        .onTapGesture { tapFood(item) }
                } else if let icon = item.resultIcon {
                    Text(icon)
                        .font(.AppTheme.rounded(size: 40))
                        .position(x: item.x, y: item.y)
                }
            }

            VStack(spacing: 4) {
                // Opponent bar
                HStack(spacing: AppSpacing.sm) {
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

                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.terracotta)
                            .font(.AppTheme.micro)
                        Text("+\(manager.opponentScore)")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }

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

                // Your score + hearts
                HStack {
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

                    HStack(spacing: 4) {
                        ForEach(0..<maxBadChoices, id: \.self) { i in
                            Image(systemName: i < badChoices ? "heart.slash.fill" : "heart.fill")
                                .foregroundColor(i < badChoices ? Color.AppTheme.lightSepia : Color.AppTheme.terracotta)
                                .font(.AppTheme.callout)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                ProgressView(value: Double(round), total: Double(totalRounds))
                    .tint(Color.AppTheme.sage)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer()
            }

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
    }

    // MARK: - Waiting View

    private var waitingView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Waiting for \(manager.opponentName) to finish...")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.sepia)
            Text("You scored \(coinsEarned) coins!")
                .font(.AppTheme.title)
                .foregroundColor(Color.AppTheme.goldenWheat)
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        let won = coinsEarned > manager.opponentFinalScore
        let tied = coinsEarned == manager.opponentFinalScore

        return ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: AppSpacing.xl)

                Text(won ? "You Won!" : (tied ? "It's a Tie!" : "Nice Try!"))
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(won ? Color.AppTheme.sage : (tied ? Color.AppTheme.goldenWheat : Color.AppTheme.terracotta))

                if won { PipWavingAnimatedView(size: .custom(100)) }

                // Score comparison
                HStack(spacing: AppSpacing.xl) {
                    VStack(spacing: AppSpacing.sm) {
                        playerAvatar(gender: avatarModel.gender)
                        Text("You")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                        Text("\(coinsEarned)")
                            .font(.AppTheme.rounded(size: 40, weight: .black))
                            .foregroundColor(Color.AppTheme.sage)
                    }

                    Text("VS")
                        .font(.AppTheme.rounded(size: 24, weight: .black))
                        .foregroundColor(Color.AppTheme.goldenWheat)

                    VStack(spacing: AppSpacing.sm) {
                        playerAvatar(gender: manager.opponentGender)
                        Text(manager.opponentName)
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia)
                            .lineLimit(1)
                        Text("\(manager.opponentFinalScore)")
                            .font(.AppTheme.rounded(size: 40, weight: .black))
                            .foregroundColor(Color.AppTheme.terracotta)
                    }
                }
                .padding(AppSpacing.lg)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.cardCornerRadius)

                Text(won ? "Winner bonus: +15 coins!" : (tied ? "Tie bonus: +10 coins!" : "Good game: +5 coins!"))
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.goldenWheat)

                HStack(spacing: AppSpacing.md) {
                    Button(action: {
                        cleanupGame()
                        manager.disconnect()
                        manager.startSearching()
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
            let bonus = won ? 15 : (tied ? 10 : 5)
            gameState.addCoins(coinsEarned + bonus)
            gameState.addXP(goodChoices * 3)
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
            Button(action: { manager.matchPhase = .idle }) {
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
                Text("Back").font(.AppTheme.body).foregroundColor(Color.AppTheme.sepia)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func playerAvatar(gender: Gender) -> some View {
        ZStack {
            Circle().fill(Color.AppTheme.parchment).frame(width: 70, height: 70)
            Image(gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60).clipShape(Circle())
        }
    }

    private func foodBubble(item: FlyingFood) -> some View {
        VStack(spacing: 2) {
            if let imgName = item.food.imageName {
                Image(imgName).resizable().aspectRatio(contentMode: .fit).frame(width: 60, height: 60)
            } else {
                Text(item.food.emoji).font(.AppTheme.timerDisplay)
            }
            Text(item.food.name)
                .font(.AppTheme.rounded(size: 11, weight: .bold))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1).shadow(color: Color.AppTheme.cream, radius: 2)
        }
        .scaleEffect(item.scale).opacity(item.opacity).rotationEffect(.degrees(item.rotation))
    }

    // MARK: - Game Logic

    private func prepareAndStartGame() {
        guard manager.gameSeed != 0 else { return }

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

        badChoices = 0; goodChoices = 0; coinsEarned = 0; round = 0
        pipScale = 1.0; pipOffset = 0; pipRotation = 0
        flyingFoods = []; localFinished = false
        lastPhysicsTick = nil
        physicsAccumulator = 0
    }

    private func startFirstSpawn(size: CGSize) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
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

        flyingFoods.append(FlyingFood(food: food, x: startX, y: size.height - 120,
            velocity: velocity, rotation: rotation, wobblePhase: wobblePhase,
            wobbleSpeed: wobbleSpeed, wobbleAmount: wobbleAmount))

        withAnimation(AnimationConstants.springSnappy) { pipScale = 1.15 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.springQuick) {
                pipScale = max(1.0, 1.0 + CGFloat(badChoices) * 0.12)
            }
        }

        round += 1
        if round < totalRounds {
            spawnTimer?.invalidate()
            spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnIntervals[round - 1], repeats: false) { _ in
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
            if flyingFoods[i].y > size.height + 50 { flyingFoods[i].tapped = true }
        }
        flyingFoods.removeAll { $0.tapped && $0.resultIcon == nil }
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
            goodChoices += 1; coinsEarned += 5
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }
                flyingFoods.removeAll { $0.id == item.id }
            }
        } else {
            flyingFoods[index].resultIcon = "\u{274C}"
            badChoices += 1
            withAnimation(AnimationConstants.springTight) {
                pipScale = 1.0 + CGFloat(badChoices) * 0.15
                pipRotation = Double.random(in: -10...10)
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }
                flyingFoods.removeAll { $0.id == item.id }
            }
            if badChoices >= maxBadChoices {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.5))
                    guard !Task.isCancelled else { return }
                    finishGame()
                }
            }
        }
        manager.sendScoreUpdate(score: coinsEarned, goodChoices: goodChoices, badChoices: badChoices)
    }

    private func finishGame() {
        guard !localFinished else { return }
        localFinished = true
        cleanupGame()
        manager.sendGameFinished(finalScore: coinsEarned, goodChoices: goodChoices, badChoices: badChoices)
        if manager.opponentFinished {
            manager.matchPhase = .finished
        } else {
            manager.matchPhase = .waitingForOpponent
        }
    }

    private func cleanupGame() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        lastPhysicsTick = nil
        physicsAccumulator = 0
    }
}

#Preview {
    NearbyVersusView()
        .environmentObject(GameState.preview)
        .environmentObject(AvatarModel())
}
