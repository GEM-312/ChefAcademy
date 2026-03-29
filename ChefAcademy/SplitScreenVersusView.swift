//
//  SplitScreenVersusView.swift
//  ChefAcademy
//
//  Split-screen Healthy Picks — two players on one device, simultaneously.
//  Top half is rotated 180° so Player 1 sits across from Player 2.
//  Same food sequence on both sides (seeded RNG).
//

import SwiftUI

struct SplitScreenVersusView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var phase: SplitPhase = .pickPlayers
    @State private var gameSeed: UInt64 = 0
    @State private var player1: UserProfile?
    @State private var player2: UserProfile?

    // Player 1 state
    @State private var p1Foods: [FlyingFood] = []
    @State private var p1Bad: Int = 0
    @State private var p1Good: Int = 0
    @State private var p1Coins: Int = 0
    @State private var p1Round: Int = 0
    @State private var p1PipScale: CGFloat = 1.0
    @State private var p1Finished: Bool = false

    // Player 2 state
    @State private var p2Foods: [FlyingFood] = []
    @State private var p2Bad: Int = 0
    @State private var p2Good: Int = 0
    @State private var p2Coins: Int = 0
    @State private var p2Round: Int = 0
    @State private var p2PipScale: CGFloat = 1.0
    @State private var p2Finished: Bool = false

    // Shared
    @State private var foodSequence: [FoodChoice] = []
    @State private var spawnIntervals: [TimeInterval] = []
    @State private var gameTimer: Timer?
    @State private var spawnTimer: Timer?
    @State private var countdownValue: Int = 3

    private let gravity: CGFloat = 0.18
    private let maxBadChoices = 5
    private let totalRounds = 25

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.AppTheme.cream.ignoresSafeArea()

                switch phase {
                case .pickPlayers:
                    pickPlayersView
                case .ready:
                    readyView(size: geo.size)
                case .countdown:
                    countdownView
                case .playing:
                    splitGameView(size: geo.size)
                case .finished:
                    resultsView(size: geo.size)
                }
            }
        }
        .onDisappear { cleanup() }
    }

    // MARK: - Pick Players

    private var allChildren: [UserProfile] {
        guard let family = sessionManager.familyProfile else { return [] }
        return family.childProfiles(in: modelContext)
    }

    private var pickPlayersView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Split Screen Battle!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            PipWavingAnimatedView(size: 80)

            Text("Pick two players!")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)

            if allChildren.count < 2 {
                Text("You need at least 2 players!")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.terracotta)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: AppSpacing.sm) {
                    ForEach(allChildren, id: \.id) { child in
                        let isP1 = player1?.id == child.id
                        let isP2 = player2?.id == child.id
                        Button(action: { selectPlayer(child) }) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(isP1 || isP2 ? Color.AppTheme.sage.opacity(0.2) : Color.AppTheme.parchment)
                                        .frame(width: 60, height: 60)
                                    Image(child.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                                        .resizable().aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50).clipShape(Circle())
                                    if isP1 || isP2 {
                                        Text(isP1 ? "P1" : "P2")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color.AppTheme.cream)
                                            .padding(3)
                                            .background(isP1 ? Color.AppTheme.sage : Color.AppTheme.terracotta)
                                            .clipShape(Circle())
                                            .offset(x: 22, y: -22)
                                    }
                                }
                                Text(child.name)
                                    .font(.AppTheme.caption)
                                    .foregroundColor(Color.AppTheme.darkBrown)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            if player1 != nil && player2 != nil {
                Button(action: { phase = .ready }) {
                    Text("Next")
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
                Text("Back").font(.AppTheme.body).foregroundColor(Color.AppTheme.sepia)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .onAppear {
            // Auto-select current child as P1
            if player1 == nil, let current = sessionManager.activeProfile, !current.isParent {
                player1 = current
            }
        }
    }

    private func selectPlayer(_ child: UserProfile) {
        if player1?.id == child.id { player1 = nil }
        else if player2?.id == child.id { player2 = nil }
        else if player1 == nil { player1 = child }
        else if player2 == nil { player2 = child }
        else { player2 = child }
    }

    // MARK: - Ready

    private func readyView(size: CGSize) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Get Ready!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            Text("Sit across from each other!")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
                .multilineTextAlignment(.center)

            // Show selected players
            HStack(spacing: AppSpacing.xl) {
                VStack {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 24))
                        .foregroundColor(Color.AppTheme.sage)
                    if let p1 = player1 {
                        Image(p1.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50).clipShape(Circle())
                        Text(p1.name)
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    Text("(top)")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sepia)
                }

                Text("VS")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(Color.AppTheme.goldenWheat)

                VStack {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 24))
                        .foregroundColor(Color.AppTheme.terracotta)
                    if let p2 = player2 {
                        Image(p2.gender == .boy ? "boy_card_clean_frame_11" : "girl_card_clean_frame_06")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50).clipShape(Circle())
                        Text(p2.name)
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    Text("(bottom)")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sepia)
                }
            }

            Button(action: {
                gameSeed = UInt64.random(in: 1...UInt64.max)
                generateSequence()
                phase = .countdown
                startCountdown()
            }) {
                Text("Start!")
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

    // MARK: - Countdown

    private var countdownView: some View {
        VStack {
            Spacer()
            Text("\(countdownValue)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundColor(Color.AppTheme.goldenWheat)
            Text("Get ready!")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.sepia)
            Spacer()
        }
    }

    // MARK: - Split Game View

    private func splitGameView(size: CGSize) -> some View {
        let halfHeight = size.height / 2
        let dividerHeight: CGFloat = 44

        return ZStack {
            VStack(spacing: 0) {
                // Player 1 — TOP (rotated 180° so they sit across)
                ZStack {
                    Color.AppTheme.parchment.opacity(0.3)

                    playerGameArea(
                        foods: $p1Foods,
                        badChoices: p1Bad,
                        goodChoices: p1Good,
                        coins: p1Coins,
                        round: p1Round,
                        pipScale: p1PipScale,
                        playerNum: 1,
                        areaHeight: halfHeight - dividerHeight / 2,
                        areaWidth: size.width
                    )
                }
                .frame(height: halfHeight - dividerHeight / 2)
                .rotationEffect(.degrees(180)) // Flipped for player sitting across!

                // Score divider
                HStack {
                    // P1 score (shown right-side up for P1)
                    HStack(spacing: 4) {
                        Text(player1?.name ?? "P1")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.AppTheme.sage)
                        Text("\(p1Coins)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Color.AppTheme.sage)
                    }
                    .rotationEffect(.degrees(180))

                    Spacer()

                    Text("VS")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(Color.AppTheme.goldenWheat)

                    Spacer()

                    HStack(spacing: 4) {
                        Text(player2?.name ?? "P2")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.AppTheme.terracotta)
                        Text("\(p2Coins)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(Color.AppTheme.terracotta)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: dividerHeight)
                .background(Color.AppTheme.warmCream)

                // Player 2 — BOTTOM (normal orientation)
                ZStack {
                    Color.AppTheme.cream

                    playerGameArea(
                        foods: $p2Foods,
                        badChoices: p2Bad,
                        goodChoices: p2Good,
                        coins: p2Coins,
                        round: p2Round,
                        pipScale: p2PipScale,
                        playerNum: 2,
                        areaHeight: halfHeight - dividerHeight / 2,
                        areaWidth: size.width
                    )
                }
                .frame(height: halfHeight - dividerHeight / 2)
            }
        }
    }

    // MARK: - Player Game Area

    private func playerGameArea(
        foods: Binding<[FlyingFood]>,
        badChoices: Int,
        goodChoices: Int,
        coins: Int,
        round: Int,
        pipScale: CGFloat,
        playerNum: Int,
        areaHeight: CGFloat,
        areaWidth: CGFloat
    ) -> some View {
        ZStack {
            // Flying food
            ForEach(foods.wrappedValue) { item in
                if !item.tapped {
                    miniFood(item: item)
                        .position(x: item.x, y: item.y)
                        .onTapGesture { tapFood(item, playerNum: playerNum) }
                } else if let icon = item.resultIcon {
                    Text(icon)
                        .font(.system(size: 28))
                        .position(x: item.x, y: item.y)
                }
            }

            // HUD
            VStack {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.system(size: 10))
                        Text("+\(coins)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.AppTheme.warmCream.opacity(0.9))
                    .cornerRadius(12)

                    Spacer()

                    HStack(spacing: 3) {
                        ForEach(0..<maxBadChoices, id: \.self) { i in
                            Image(systemName: i < badChoices ? "heart.slash.fill" : "heart.fill")
                                .foregroundColor(i < badChoices ? Color.AppTheme.lightSepia : Color.AppTheme.terracotta)
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                Spacer()

                // Mini Pip at bottom
                Image("pip_neutral")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40 * pipScale, height: 40 * pipScale)
                    .scaleEffect(pipScale)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Mini Food

    private func miniFood(item: FlyingFood) -> some View {
        VStack(spacing: 1) {
            if let imgName = item.food.imageName {
                Image(imgName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            } else {
                Text(item.food.emoji)
                    .font(.system(size: 32))
            }
            Text(item.food.name)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)
        }
        .scaleEffect(item.scale)
        .opacity(item.opacity)
        .rotationEffect(.degrees(item.rotation))
    }

    // MARK: - Results

    private func resultsView(size: CGSize) -> some View {
        let p1Won = p1Coins > p2Coins
        let tied = p1Coins == p2Coins

        return VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text(tied ? "It's a Tie!" : (p1Won ? "\(player1?.name ?? "P1") Wins!" : "\(player2?.name ?? "P2") Wins!"))
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.sage)

            PipWavingAnimatedView(size: 80)

            HStack(spacing: AppSpacing.xl) {
                VStack {
                    Text(player1?.name ?? "P1").font(.AppTheme.headline).foregroundColor(Color.AppTheme.sage)
                    Text("\(p1Coins)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(p1Won || tied ? Color.AppTheme.sage : Color.AppTheme.sepia)
                    HStack(spacing: 4) {
                        Label("\(p1Good)", systemImage: "checkmark.circle.fill")
                            .font(.AppTheme.caption).foregroundColor(Color.AppTheme.sage)
                        Label("\(p1Bad)", systemImage: "xmark.circle.fill")
                            .font(.AppTheme.caption).foregroundColor(Color.AppTheme.terracotta)
                    }
                }

                Text("VS")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(Color.AppTheme.goldenWheat)

                VStack {
                    Text(player2?.name ?? "P2").font(.AppTheme.headline).foregroundColor(Color.AppTheme.terracotta)
                    Text("\(p2Coins)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(!p1Won || tied ? Color.AppTheme.terracotta : Color.AppTheme.sepia)
                    HStack(spacing: 4) {
                        Label("\(p2Good)", systemImage: "checkmark.circle.fill")
                            .font(.AppTheme.caption).foregroundColor(Color.AppTheme.sage)
                        Label("\(p2Bad)", systemImage: "xmark.circle.fill")
                            .font(.AppTheme.caption).foregroundColor(Color.AppTheme.terracotta)
                    }
                }
            }
            .padding(AppSpacing.lg)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)

            HStack(spacing: AppSpacing.md) {
                Button(action: { rematch() }) {
                    Text("Rematch!")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .buttonStyle(BouncyButtonStyle())

                Button(action: { cleanup(); dismiss() }) {
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

            Spacer()
        }
        .onAppear {
            gameState.addCoins(p1Coins + p2Coins)
        }
    }

    // MARK: - Game Logic

    private func generateSequence() {
        var gen = SeededRandomGenerator(seed: gameSeed)
        let allFoods = HealthyChoiceGameView.allFoods

        foodSequence = (0..<totalRounds).map { _ in
            allFoods[Int.random(in: 0..<allFoods.count, using: &gen)]
        }
        spawnIntervals = (0..<totalRounds).map { round in
            let base = 1.8 - Double(round) * 0.04
            let jitter = Double.random(in: -0.1...0.1, using: &gen)
            return max(0.8, base + jitter)
        }
    }

    private func startCountdown() {
        countdownValue = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdownValue -= 1
            if countdownValue <= 0 {
                timer.invalidate()
                startGame()
            }
        }
    }

    private func startGame() {
        p1Bad = 0; p1Good = 0; p1Coins = 0; p1Round = 0; p1PipScale = 1.0; p1Finished = false
        p2Bad = 0; p2Good = 0; p2Coins = 0; p2Round = 0; p2PipScale = 1.0; p2Finished = false
        p1Foods = []; p2Foods = []

        phase = .playing

        let screenSize = UIScreen.main.bounds.size
        let halfHeight = screenSize.height / 2 - 22

        // Physics timer
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updatePhysics(halfHeight: halfHeight, width: screenSize.width)
        }

        // First spawn
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            spawnForBoth(halfHeight: halfHeight, width: screenSize.width)
        }
    }

    private func spawnForBoth(halfHeight: CGFloat, width: CGFloat) {
        let currentRound = min(p1Round, p2Round)
        guard currentRound < totalRounds else { return }

        let food = foodSequence[currentRound]

        // Spawn for Player 1 (if still playing)
        if !p1Finished && p1Round <= currentRound {
            let x = CGFloat.random(in: width * 0.2 ... width * 0.8)
            p1Foods.append(FlyingFood(
                food: food, x: x, y: halfHeight - 30,
                velocity: -CGFloat.random(in: 6...9),
                rotation: Double.random(in: -10...10),
                wobblePhase: CGFloat.random(in: 0 ... .pi * 2),
                wobbleSpeed: CGFloat.random(in: 0.04...0.08),
                wobbleAmount: CGFloat.random(in: 10...25)
            ))
            p1Round += 1
            withAnimation(.spring(response: 0.2)) { p1PipScale = 1.15 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3)) {
                    p1PipScale = max(1.0, 1.0 + CGFloat(p1Bad) * 0.12)
                }
            }
        }

        // Spawn for Player 2 (same food)
        if !p2Finished && p2Round <= currentRound {
            let x = CGFloat.random(in: width * 0.2 ... width * 0.8)
            p2Foods.append(FlyingFood(
                food: food, x: x, y: halfHeight - 30,
                velocity: -CGFloat.random(in: 6...9),
                rotation: Double.random(in: -10...10),
                wobblePhase: CGFloat.random(in: 0 ... .pi * 2),
                wobbleSpeed: CGFloat.random(in: 0.04...0.08),
                wobbleAmount: CGFloat.random(in: 10...25)
            ))
            p2Round += 1
            withAnimation(.spring(response: 0.2)) { p2PipScale = 1.15 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3)) {
                    p2PipScale = max(1.0, 1.0 + CGFloat(p2Bad) * 0.12)
                }
            }
        }

        // Schedule next
        let nextRound = currentRound + 1
        if nextRound < totalRounds {
            let interval = spawnIntervals[currentRound]
            spawnTimer?.invalidate()
            spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                self.spawnForBoth(halfHeight: halfHeight, width: width)
            }
        }
    }

    private func updatePhysics(halfHeight: CGFloat, width: CGFloat) {
        // Player 1
        for i in p1Foods.indices {
            guard !p1Foods[i].tapped else { continue }
            p1Foods[i].velocity += gravity * 0.7  // Slightly less gravity for smaller area
            p1Foods[i].y += p1Foods[i].velocity
            p1Foods[i].wobblePhase += p1Foods[i].wobbleSpeed
            p1Foods[i].x += sin(p1Foods[i].wobblePhase) * (p1Foods[i].wobbleAmount * 0.03)
            p1Foods[i].rotation += Double(p1Foods[i].velocity) * 0.15
            let norm = p1Foods[i].y / halfHeight
            p1Foods[i].scale = 0.8 + (1.0 - abs(norm - 0.4)) * 0.2
            if p1Foods[i].y > halfHeight + 30 { p1Foods[i].tapped = true }
        }
        p1Foods.removeAll { $0.tapped && $0.resultIcon == nil }

        // Player 2
        for i in p2Foods.indices {
            guard !p2Foods[i].tapped else { continue }
            p2Foods[i].velocity += gravity * 0.7
            p2Foods[i].y += p2Foods[i].velocity
            p2Foods[i].wobblePhase += p2Foods[i].wobbleSpeed
            p2Foods[i].x += sin(p2Foods[i].wobblePhase) * (p2Foods[i].wobbleAmount * 0.03)
            p2Foods[i].rotation += Double(p2Foods[i].velocity) * 0.15
            let norm = p2Foods[i].y / halfHeight
            p2Foods[i].scale = 0.8 + (1.0 - abs(norm - 0.4)) * 0.2
            if p2Foods[i].y > halfHeight + 30 { p2Foods[i].tapped = true }
        }
        p2Foods.removeAll { $0.tapped && $0.resultIcon == nil }

        // Check finish
        let maxRound = max(p1Round, p2Round)
        if maxRound >= totalRounds
            && p1Foods.filter({ !$0.tapped }).isEmpty
            && p2Foods.filter({ !$0.tapped }).isEmpty {
            finishGame()
        }
    }

    private func tapFood(_ item: FlyingFood, playerNum: Int) {
        if playerNum == 1 {
            guard let idx = p1Foods.firstIndex(where: { $0.id == item.id }),
                  !p1Foods[idx].tapped else { return }
            p1Foods[idx].tapped = true
            if item.food.isHealthy {
                p1Foods[idx].resultIcon = "\u{2705}"
                p1Good += 1; p1Coins += 5
            } else {
                p1Foods[idx].resultIcon = "\u{274C}"
                p1Bad += 1
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    p1PipScale = 1.0 + CGFloat(p1Bad) * 0.15
                }
                if p1Bad >= maxBadChoices { p1Finished = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                p1Foods.removeAll { $0.id == item.id }
            }
        } else {
            guard let idx = p2Foods.firstIndex(where: { $0.id == item.id }),
                  !p2Foods[idx].tapped else { return }
            p2Foods[idx].tapped = true
            if item.food.isHealthy {
                p2Foods[idx].resultIcon = "\u{2705}"
                p2Good += 1; p2Coins += 5
            } else {
                p2Foods[idx].resultIcon = "\u{274C}"
                p2Bad += 1
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    p2PipScale = 1.0 + CGFloat(p2Bad) * 0.15
                }
                if p2Bad >= maxBadChoices { p2Finished = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                p2Foods.removeAll { $0.id == item.id }
            }
        }
    }

    private func finishGame() {
        cleanup()
        phase = .finished
    }

    private func rematch() {
        cleanup()
        gameSeed = UInt64.random(in: 1...UInt64.max)
        generateSequence()
        phase = .countdown
        startCountdown()
    }

    private func cleanup() {
        gameTimer?.invalidate(); spawnTimer?.invalidate()
        gameTimer = nil; spawnTimer = nil
    }
}

enum SplitPhase {
    case pickPlayers, ready, countdown, playing, finished
}

#Preview {
    SplitScreenVersusView()
        .environmentObject(GameState.preview)
}
