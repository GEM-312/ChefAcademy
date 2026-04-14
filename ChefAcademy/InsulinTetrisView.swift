//
//  InsulinTetrisView.swift
//  ChefAcademy
//
//  Insulin Tetris — drag falling glucose blocks into body storage bins!
//  Teaches: liver (100g) → muscles (400g) → fat (unlimited).
//  Fructose blocks can ONLY go to fat. Fiber blocks slow everything down.
//
//  Based on Glucose Revolution by Jessie Inchauspe:
//  "Insulin stashes glucose in storage units like playing Tetris"
//
//  TEACHING MOMENT: Game Architecture
//  This file follows the same pattern as HealthyChoiceGameView:
//    1. Data models (structs/enums) at the top
//    2. Main view with state machine (ready → playing → victory/gameOver)
//    3. Sub-views extracted as methods
//    4. Game logic in private methods at the bottom
//    5. Static data (Pip messages) at the very end
//
//  The physics loop uses TimelineView (not Timer) for efficiency —
//  it only runs when the view is on-screen and syncs with the display.

import SwiftUI

// Haptic enum is now shared in AppTheme.swift

// MARK: - Block Type
//
// TEACHING MOMENT: Associated Values on Enums
// The `.fiber` case carries a VegetableType — this tells us WHICH veggie
// from the kid's garden produced this fiber block. We can show the actual
// veggie image on the block, making the garden→game connection tangible.

enum GlucoseBlockType: Equatable {
    case glucose
    case fructose
    case fiber(VegetableType)

    var color: Color {
        switch self {
        case .glucose:  return Color.AppTheme.goldenWheat
        case .fructose: return Color.AppTheme.terracotta
        case .fiber:    return Color.AppTheme.sage
        }
    }

    var label: String {
        switch self {
        case .glucose:  return "Glucose"
        case .fructose: return "Fructose"
        case .fiber(let veg): return veg.displayName
        }
    }

    var emoji: String {
        switch self {
        case .glucose:  return "G"
        case .fructose: return "F"
        case .fiber:    return "🌿"
        }
    }

    var isFiber: Bool {
        if case .fiber = self { return true }
        return false
    }
}

// MARK: - Storage Bin Type

enum StorageBinType: String, CaseIterable {
    case liver
    case muscles
    case fat

    var displayName: String {
        switch self {
        case .liver:   return "Liver"
        case .muscles: return "Muscles"
        case .fat:     return "Fat"
        }
    }

    var capacity: CGFloat {
        switch self {
        case .liver:   return 100
        case .muscles: return 400
        case .fat:     return .infinity // unlimited
        }
    }

    var icon: String {
        switch self {
        case .liver:   return "cross.vial.fill"
        case .muscles: return "figure.strengthtraining.traditional"
        case .fat:     return "balloon.fill"
        }
    }

    var color: Color {
        switch self {
        case .liver:   return Color.AppTheme.goldenWheat
        case .muscles: return Color.AppTheme.sage
        case .fat:     return Color.AppTheme.terracotta
        }
    }

    /// Grams per block stored
    var gramsPerBlock: CGFloat {
        switch self {
        case .liver:   return 12.5  // 100g / 8 blocks to fill
        case .muscles: return 25.0  // 400g / 16 blocks to fill
        case .fat:     return 10.0  // arbitrary, just inflates
        }
    }
}

// MARK: - Falling Block

struct FallingBlock: Identifiable {
    let id = UUID()
    let type: GlucoseBlockType
    var x: CGFloat
    var y: CGFloat
    var fallSpeed: CGFloat     // points per second
    var rotation: Double = 0
    var wobblePhase: CGFloat = CGFloat.random(in: 0 ... .pi * 2)
    var isDragging: Bool = false
    var dragOffset: CGSize = .zero
    var isStored: Bool = false // animated into bin
    var isRejected: Bool = false
}

// MARK: - Storage Bin State

struct StorageBinState {
    let type: StorageBinType
    var currentGrams: CGFloat = 0
    var blocksStored: Int = 0

    var isFull: Bool {
        type != .fat && currentGrams >= type.capacity
    }

    var fillFraction: CGFloat {
        guard type != .fat else { return 0 }
        return min(currentGrams / type.capacity, 1.0)
    }
}

// MARK: - Game Phase

enum InsulinTetrisPhase {
    case ready
    case playing
    case gameOver
    case victory
}

// MARK: - Insulin Tetris View

struct InsulinTetrisView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) private var dismiss

    // State machine
    @State private var phase: InsulinTetrisPhase = .ready

    // Blocks
    @State private var fallingBlocks: [FallingBlock] = []
    @State private var blockSequence: [GlucoseBlockType] = []
    @State private var blocksSpawned: Int = 0
    private let totalBlocks = 30

    // Bins
    @State private var liverBin = StorageBinState(type: .liver)
    @State private var muscleBin = StorageBinState(type: .muscles)
    @State private var fatBin = StorageBinState(type: .fat)

    // Scoring
    @State private var score: Int = 0
    @State private var blocksInFat: Int = 0
    @State private var fiberTapped: Int = 0
    @State private var blocksMissed: Int = 0
    private let maxMissed = 5

    // Speed
    @State private var speedMultiplier: CGFloat = 1.0
    @State private var fiberSlowdownEnd: Date? = nil

    // Physics
    @State private var lastUpdateDate: Date = .now
    @State private var nextSpawnTime: Date = .now
    @State private var spawnInterval: TimeInterval = 2.5

    // Pip
    @State private var pipMessage: String? = nil
    @State private var pipMessageTimer: DispatchWorkItem? = nil

    // Drag
    @State private var activeDragID: UUID? = nil

    // Bin rects for drop detection (updated by GeometryReader)
    // TEACHING MOMENT: Coordinate Spaces
    // SwiftUI views live in nested coordinate systems. A block's `.position(x:y:)`
    // is relative to its parent ZStack. But `geo.frame(in: .named(gameCoordSpace))` gives screen
    // coordinates (includes safe area offsets). To compare them, we need both in
    // the SAME coordinate space. We define a named space on the game ZStack and
    // capture all bin rects in that space. Then drop point math works correctly.
    @State private var binRects: [StorageBinType: CGRect] = [:]
    private let gameCoordSpace = "gameArea"

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.AppTheme.cream.ignoresSafeArea()

                switch phase {
                case .ready:    readyScreen(size: geo.size)
                case .playing:  gameplayView(size: geo.size)
                case .gameOver: gameOverScreen
                case .victory:  victoryScreen
                }
            }
        }
    }

    // MARK: - Fiber Veggies from Garden
    //
    // TEACHING MOMENT: This connects the GARDEN to the GAME.
    // Kids who grew fiber-rich veggies get MORE fiber blocks, making
    // the game easier. This rewards the GROW → PLAY feedback loop.

    private var fiberVeggiesGrown: [VegetableType] {
        let fiberTypes: [VegetableType] = [
            .lettuce, .carrot, .broccoli, .pumpkin, .sweetPotato,
            .corn, .beet, .greenBeans, .avocado, .raspberry, .blackberry
        ]
        return fiberTypes.filter { veg in
            gameState.harvestedIngredients.contains { $0.type == veg && $0.quantity > 0 }
        }
    }

    private var fiberBlockCount: Int {
        switch fiberVeggiesGrown.count {
        case 0...3:  return 2
        case 4...7:  return 3
        default:     return 4
        }
    }

    // MARK: - Ready Screen

    private func readyScreen(size: CGSize) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: AppSpacing.xl)

                Text("Insulin Tetris")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)

                PipWavingAnimatedView(size: 130)

                // Instructions
                VStack(spacing: AppSpacing.sm) {
                    Text("Glucose blocks are falling!")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    Text("Drag them into the right bins before they overflow!")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                        .multilineTextAlignment(.center)

                    Text("Fill the liver first, then muscles. Fat is the last resort!")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.lightSepia)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.lg)

                // Bin preview
                HStack(spacing: AppSpacing.lg) {
                    ForEach(StorageBinType.allCases, id: \.rawValue) { bin in
                        VStack(spacing: 6) {
                            Image(systemName: bin.icon)
                                .font(.system(size: 30))
                                .foregroundColor(bin.color)
                            Text(bin.displayName)
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                            Text(bin == .fat ? "Unlimited" : "\(Int(bin.capacity))g")
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.lightSepia)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.cardCornerRadius)

                // Start button
                Button(action: { startGame(size: size) }) {
                    Text("Let's Go!")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.horizontal, AppSpacing.xl)

                Button(action: { dismiss() }) {
                    Text("Back")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                }

                Spacer().frame(height: AppSpacing.xl)
            }
        }
    }

    // MARK: - Gameplay View
    //
    // TEACHING MOMENT: TimelineView(.animation) syncs with the display
    // refresh rate. On a 60Hz iPhone, we get ~60 updates/sec. On a 120Hz
    // ProMotion iPad, we get ~120/sec. But because we use delta-time math
    // (speed * dt), blocks fall at the SAME real-world speed on both.

    private func gameplayView(size: CGSize) -> some View {
        TimelineView(.animation) { context in
            let now = context.date

            ZStack {
                // Bins at bottom
                VStack {
                    Spacer()
                    binsRow(size: size)
                }

                // Falling blocks
                ForEach(fallingBlocks.filter { !$0.isStored }) { block in
                    blockView(block: block)
                        .position(
                            x: block.isDragging ? block.x + block.dragOffset.width : block.x,
                            y: block.isDragging ? block.y + block.dragOffset.height : block.y
                        )
                        .gesture(block.type.isFiber ? nil : dragGesture(for: block, size: size))
                        .onTapGesture {
                            if case .fiber = block.type {
                                activateFiber(block: block)
                            }
                        }
                }

                // HUD
                hudOverlay

                // Pip message toast
                if let msg = pipMessage {
                    VStack {
                        Spacer()
                        pipToast(msg)
                            .padding(.bottom, 200)
                    }
                }
            }
            .coordinateSpace(name: gameCoordSpace)
            .onChange(of: now) { _, newDate in
                updateGame(now: newDate, size: size)
            }
        }
        .onDisappear {
            pipMessageTimer?.cancel()
            pipMessageTimer = nil
        }
    }

    // MARK: - Block View

    private func blockView(block: FallingBlock) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(block.type.color)
                .frame(width: 56, height: 56)
                .shadow(color: Color.AppTheme.sepia.opacity(0.2), radius: 4, y: 2)

            // Label
            switch block.type {
            case .glucose:
                Text("G")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.AppTheme.darkBrown.opacity(0.6))
            case .fructose:
                Text("F")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.AppTheme.cream.opacity(0.8))
            case .fiber(let veg):
                Image(veg.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            }
        }
        .rotationEffect(.degrees(block.rotation))
        .scaleEffect(block.isDragging ? 1.2 : 1.0)
        .opacity(block.isRejected ? 0.5 : 1.0)
        .animation(.spring(response: 0.2), value: block.isDragging)
    }

    // MARK: - Bins Row

    private func binsRow(size: CGSize) -> some View {
        HStack(spacing: AppSpacing.sm) {
            binView(bin: liverBin, size: size)
            binView(bin: muscleBin, size: size)
            fatBinView(size: size)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xl)
    }

    private func binView(bin: StorageBinState, size: CGSize) -> some View {
        let binWidth = (size.width - AppSpacing.md * 2 - AppSpacing.sm * 2) / 3

        return VStack(spacing: 4) {
            // Bin container with fill
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(bin.type.color.opacity(0.5), lineWidth: 2)
                    .frame(width: binWidth, height: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.AppTheme.warmCream)
                    )

                // Fill level
                RoundedRectangle(cornerRadius: 10)
                    .fill(bin.type.color.opacity(0.4))
                    .frame(width: binWidth - 4, height: 126 * bin.fillFraction)
                    .animation(.spring(response: 0.4), value: bin.fillFraction)

                // Icon
                Image(systemName: bin.type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(bin.type.color)
                    .padding(.bottom, 8)
            }
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            let frame = geo.frame(in: .named(gameCoordSpace))
                            binRects[bin.type] = frame
                        }
                        .onChange(of: geo.size) { _, _ in
                            binRects[bin.type] = geo.frame(in: .named(gameCoordSpace))
                        }
                }
            )

            // Label
            Text(bin.type.displayName)
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)

            // Capacity
            Text(bin.isFull ? "FULL" : "\(Int(bin.currentGrams))/\(Int(bin.type.capacity))g")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(bin.isFull ? Color.AppTheme.terracotta : Color.AppTheme.lightSepia)
        }
    }

    // Fat bin is special — it inflates like a balloon
    private func fatBinView(size: CGSize) -> some View {
        let binWidth = (size.width - AppSpacing.md * 2 - AppSpacing.sm * 2) / 3
        let balloonScale = 1.0 + CGFloat(blocksInFat) * 0.08

        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(StorageBinType.fat.color.opacity(0.5), lineWidth: 2)
                    .frame(width: binWidth, height: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.AppTheme.warmCream)
                    )

                // Balloon that inflates
                Circle()
                    .fill(StorageBinType.fat.color.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .scaleEffect(balloonScale)
                    .animation(.spring(response: 0.4), value: balloonScale)

                Image(systemName: "balloon.fill")
                    .font(.system(size: 28))
                    .foregroundColor(StorageBinType.fat.color)
                    .scaleEffect(balloonScale * 0.8)
            }
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { binRects[.fat] = geo.frame(in: .named(gameCoordSpace)) }
                        .onChange(of: geo.size) { _, _ in
                            binRects[.fat] = geo.frame(in: .named(gameCoordSpace))
                        }
                }
            )

            Text("Fat")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)

            Text(blocksInFat > 0 ? "\(blocksInFat) blocks" : "Empty")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(blocksInFat > 3 ? Color.AppTheme.terracotta : Color.AppTheme.lightSepia)
        }
    }

    // MARK: - HUD

    private var hudOverlay: some View {
        VStack {
            HStack {
                // Score
                Label {
                    Text("\(score)")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color.AppTheme.goldenWheat)
                }

                Spacer()

                // Blocks remaining
                Text("\(blocksSpawned)/\(totalBlocks)")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(10)

                Spacer()

                // Missed counter
                HStack(spacing: 3) {
                    ForEach(0..<maxMissed, id: \.self) { i in
                        Circle()
                            .fill(i < blocksMissed ? Color.AppTheme.terracotta : Color.AppTheme.parchment)
                            .frame(width: 10, height: 10)
                    }
                }

                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.AppTheme.sepia.opacity(0.4))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            // Fiber slow-down indicator
            if fiberSlowdownEnd != nil {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Color.AppTheme.sage)
                    Text("Fiber slowdown active!")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sage)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.AppTheme.sage.opacity(0.15))
                .cornerRadius(12)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()
        }
    }

    // MARK: - Pip Toast

    private func pipToast(_ message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image("pip_got_idea")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            Text(message)
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.darkBrown)
        }
        .padding(AppSpacing.sm)
        .background(Color.AppTheme.warmCream.opacity(0.95))
        .cornerRadius(20)
        .shadow(color: Color.AppTheme.sepia.opacity(0.1), radius: 4, y: 2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Game Over Screen

    private var gameOverScreen: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Glucose Overflow!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.terracotta)

            Image("pip_got_idea")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)

            Text("Too many blocks fell through! The glucose overwhelmed your body.")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            statsCard

            HStack(spacing: AppSpacing.md) {
                Button(action: { resetGame() }) {
                    Text("Try Again!")
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
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                .stroke(Color.AppTheme.sepia.opacity(0.2), lineWidth: 1)
                        )
                }
            }

            Spacer()
        }
    }

    // MARK: - Victory Screen

    private var victoryScreen: some View {
        let stars = starRating
        let coins = coinsEarned

        return ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: AppSpacing.xl)

                Text("Amazing Job!")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.sage)

                PipWavingAnimatedView(size: 100)

                // Stars
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < stars ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    }
                }

                // Teaching recap
                VStack(spacing: 6) {
                    Text("Your liver stored \(Int(liverBin.currentGrams))g")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.goldenWheat)
                    Text("Your muscles stored \(Int(muscleBin.currentGrams))g")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sage)
                    if blocksInFat > 0 {
                        Text("Only \(blocksInFat) block\(blocksInFat == 1 ? "" : "s") went to fat!")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.terracotta)
                    } else {
                        Text("Zero fat! Perfect sorting!")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sage)
                    }
                }

                statsCard

                // Reward
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(Color.AppTheme.goldenWheat)
                    Text("+\(coins) coins")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.goldenWheat)
                }

                HStack(spacing: AppSpacing.md) {
                    Button(action: { resetGame() }) {
                        Text("Play Again!")
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
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.sm)
                            .background(Color.AppTheme.warmCream)
                            .cornerRadius(AppSpacing.cardCornerRadius)
                    }
                }

                Spacer().frame(height: AppSpacing.xl)
            }
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: AppSpacing.lg) {
            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.goldenWheat)
                Text("Score")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            VStack(spacing: 4) {
                Text("\(liverBin.blocksStored + muscleBin.blocksStored)")
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.sage)
                Text("Stored")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            VStack(spacing: 4) {
                Text("\(blocksInFat)")
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.terracotta)
                Text("Fat")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }

    // MARK: - Scoring Helpers

    private var starRating: Int {
        switch blocksInFat {
        case 0...3: return 3
        case 4...7: return 2
        default:    return 1
        }
    }

    private var coinsEarned: Int {
        let base: Int
        switch starRating {
        case 3: base = 30
        case 2: base = 20
        default: base = 10
        }
        return base + fiberTapped * 2
    }

    // MARK: - Game Logic

    private func startGame(size: CGSize) {
        // Generate block sequence
        blockSequence = generateBlockSequence()
        blocksSpawned = 0
        blocksMissed = 0
        score = 0
        blocksInFat = 0
        fiberTapped = 0
        speedMultiplier = 1.0
        fiberSlowdownEnd = nil
        fallingBlocks = []
        liverBin = StorageBinState(type: .liver)
        muscleBin = StorageBinState(type: .muscles)
        fatBin = StorageBinState(type: .fat)
        lastUpdateDate = .now
        nextSpawnTime = .now.addingTimeInterval(1.0) // first block after 1s
        spawnInterval = 2.5

        showPipMessage("Drag glucose blocks into the bins!")

        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .playing
        }
    }

    private func resetGame() {
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .ready
        }
    }

    // MARK: - Block Sequence Generator

    private func generateBlockSequence() -> [GlucoseBlockType] {
        let fiberCount = fiberBlockCount
        let fructoseCount = 3
        let glucoseCount = totalBlocks - fiberCount - fructoseCount

        var seq: [GlucoseBlockType] = []

        // Glucose blocks
        seq += Array(repeating: GlucoseBlockType.glucose, count: glucoseCount)

        // Fructose blocks
        seq += Array(repeating: GlucoseBlockType.fructose, count: fructoseCount)

        // Fiber blocks — use actual grown veggies if possible
        let fiberVeggies = fiberVeggiesGrown
        for i in 0..<fiberCount {
            if fiberVeggies.isEmpty {
                seq.append(.fiber(.broccoli)) // fallback
            } else {
                seq.append(.fiber(fiberVeggies[i % fiberVeggies.count]))
            }
        }

        // Shuffle with constraints: first 8 blocks are always glucose (tutorial zone)
        var first8 = Array(repeating: GlucoseBlockType.glucose, count: min(8, glucoseCount))
        var rest = seq.dropFirst(first8.count).shuffled()

        return first8 + rest
    }

    // MARK: - Speed Ramp

    private func speedForBlock(_ n: Int) -> CGFloat {
        switch n {
        case 0..<9:   return 40
        case 9..<16:  return 60
        case 16..<23: return 85
        default:      return 110
        }
    }

    // MARK: - Game Update Loop (called by TimelineView)

    private func updateGame(now: Date, size: CGSize) {
        guard phase == .playing else { return }

        let dt = now.timeIntervalSince(lastUpdateDate)
        guard dt > 0, dt < 0.5 else {
            lastUpdateDate = now
            return
        }
        lastUpdateDate = now

        // Check fiber slowdown expiry
        if let end = fiberSlowdownEnd, now > end {
            withAnimation { fiberSlowdownEnd = nil }
            speedMultiplier = 1.0
        }

        let delta = CGFloat(dt)

        // Update falling blocks
        var updated = fallingBlocks
        var newMissed = 0
        for i in updated.indices {
            guard !updated[i].isDragging, !updated[i].isStored else { continue }

            // Fall
            updated[i].y += updated[i].fallSpeed * speedMultiplier * delta

            // Wobble
            updated[i].wobblePhase += 1.5 * delta
            updated[i].x += sin(updated[i].wobblePhase) * 0.3

            // Rotation
            updated[i].rotation += Double(updated[i].fallSpeed * delta * 0.3)

            // Off screen?
            if updated[i].y > size.height + 40 {
                updated[i].isStored = true // remove from view
                newMissed += 1
            }
        }
        fallingBlocks = updated

        // Handle missed blocks
        if newMissed > 0 {
            blocksMissed += newMissed
            score = max(0, score - newMissed * 5)
            Haptic.notify(.warning)

            if blocksMissed >= maxMissed {
                finishGame(won: false)
                return
            }
        }

        // Remove stored/missed blocks
        fallingBlocks.removeAll { $0.isStored }

        // Spawn new block?
        if now >= nextSpawnTime, blocksSpawned < totalBlocks {
            spawnNextBlock(size: size)
        }

        // Check if all blocks handled
        if blocksSpawned >= totalBlocks && fallingBlocks.isEmpty {
            finishGame(won: true)
        }
    }

    // MARK: - Spawn

    private func spawnNextBlock(size: CGSize) {
        guard blocksSpawned < blockSequence.count else { return }

        let type = blockSequence[blocksSpawned]
        let speed = speedForBlock(blocksSpawned)

        let block = FallingBlock(
            type: type,
            x: CGFloat.random(in: size.width * 0.2 ... size.width * 0.8),
            y: -30,
            fallSpeed: speed
        )

        fallingBlocks.append(block)
        blocksSpawned += 1

        // Decrease spawn interval
        spawnInterval = max(1.0, spawnInterval - 0.05)
        nextSpawnTime = .now.addingTimeInterval(spawnInterval)

        // Pip messages at milestones
        if blocksSpawned == 9 {
            showPipMessage("Glucose spike! Things are getting faster!")
        }
    }

    // MARK: - Drag Gesture

    private func dragGesture(for block: FallingBlock, size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard activeDragID == nil || activeDragID == block.id else { return }
                activeDragID = block.id
                if let idx = fallingBlocks.firstIndex(where: { $0.id == block.id }) {
                    fallingBlocks[idx].isDragging = true
                    fallingBlocks[idx].dragOffset = value.translation
                }
            }
            .onEnded { value in
                activeDragID = nil
                handleDrop(blockID: block.id, translation: value.translation, size: size)
            }
    }

    // MARK: - Drop Handling

    private func handleDrop(blockID: UUID, translation: CGSize, size: CGSize) {
        guard let idx = fallingBlocks.firstIndex(where: { $0.id == blockID }) else { return }
        let block = fallingBlocks[idx]
        let dropPoint = CGPoint(
            x: block.x + translation.width,
            y: block.y + translation.height
        )

        // Convert drop point to global coords (rough approximation)
        // Check which bin rect contains the drop point
        for (binType, rect) in binRects {
            // Expand hit box by 20pt for forgiving kid-friendly interaction
            let expanded = rect.insetBy(dx: -20, dy: -20)
            if expanded.contains(dropPoint) {
                attemptStore(blockIndex: idx, binType: binType)
                return
            }
        }

        // Missed all bins — resume falling
        fallingBlocks[idx].isDragging = false
        fallingBlocks[idx].dragOffset = .zero
    }

    // MARK: - Store / Reject

    private func attemptStore(blockIndex: Int, binType: StorageBinType) {
        let block = fallingBlocks[blockIndex]

        // Fructose can ONLY go to fat
        if case .fructose = block.type, binType != .fat {
            rejectBlock(at: blockIndex, reason: "Fructose can only become fat!")
            return
        }

        // Check if bin is full
        switch binType {
        case .liver:
            if liverBin.isFull {
                rejectBlock(at: blockIndex, reason: "Liver is full! Try muscles!")
                return
            }
            liverBin.currentGrams += StorageBinType.liver.gramsPerBlock
            liverBin.blocksStored += 1
            score += 15 // optimal: liver first
            if liverBin.isFull { showPipMessage("Liver's full! It can only hold 100 grams!") }

        case .muscles:
            if muscleBin.isFull {
                rejectBlock(at: blockIndex, reason: "Muscles are full too!")
                return
            }
            muscleBin.currentGrams += StorageBinType.muscles.gramsPerBlock
            muscleBin.blocksStored += 1
            score += liverBin.isFull ? 15 : 10 // bonus if liver was filled first
            if muscleBin.isFull { showPipMessage("Muscles stored 400 grams! Only fat cells are left...") }

        case .fat:
            fatBin.blocksStored += 1
            blocksInFat += 1
            score += 2
            if blocksInFat == 4 {
                showPipMessage("The fat balloons are getting big!")
            }
        }

        Haptic.impact(.medium)
        withAnimation(.spring(response: 0.3)) {
            fallingBlocks[blockIndex].isStored = true
        }
    }

    private func rejectBlock(at index: Int, reason: String) {
        let blockID = fallingBlocks[index].id // capture stable ID, not index

        Haptic.notify(.warning)
        showPipMessage(reason)

        // Bounce back
        withAnimation(.spring(response: 0.4, dampingFraction: 0.3)) {
            fallingBlocks[index].isDragging = false
            fallingBlocks[index].dragOffset = .zero
            fallingBlocks[index].isRejected = true
        }

        // Clear rejected state after brief flash — find by ID, not stale index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let idx = fallingBlocks.firstIndex(where: { $0.id == blockID }) {
                fallingBlocks[idx].isRejected = false
            }
        }
    }

    // MARK: - Fiber Activation

    private func activateFiber(block: FallingBlock) {
        guard let idx = fallingBlocks.firstIndex(where: { $0.id == block.id }) else { return }

        Haptic.impact(.light)
        fiberTapped += 1
        score += 15

        // Remove the fiber block
        withAnimation(.spring(response: 0.3)) {
            fallingBlocks[idx].isStored = true
        }

        // Activate slowdown
        speedMultiplier = 0.5
        withAnimation { fiberSlowdownEnd = .now.addingTimeInterval(5.0) }

        if case .fiber(let veg) = block.type {
            showPipMessage("Fiber from your \(veg.displayName.lowercased()) slows glucose down!")
        }
    }

    // MARK: - Finish Game

    private func finishGame(won: Bool) {
        if won {
            Haptic.notify(.success)
            gameState.addCoins(coinsEarned)
            gameState.addXP(starRating * 5)
        } else {
            Haptic.notify(.error)
        }

        // Report to Game Center leaderboard + achievements
        let gc = GameCenterService.shared
        gc.reportScore(score, leaderboardID: LeaderboardID.insulinTetris)
        if starRating >= 3 {
            gc.reportAchievement(AchievementID.insulinPro)
        }
        if blocksInFat == 0 && won {
            gc.reportAchievement(AchievementID.noFatStorage)
        }
        if fiberTapped >= 4 {
            gc.reportAchievement(AchievementID.fiberFriend)
        }
        gc.checkAchievements(gameState: gameState)

        withAnimation(.easeInOut(duration: 0.5)) {
            phase = won ? .victory : .gameOver
        }
    }

    // MARK: - Pip Messages

    private func showPipMessage(_ message: String) {
        pipMessageTimer?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            pipMessage = message
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.3)) {
                pipMessage = nil
            }
        }
        pipMessageTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
}


// MARK: - Preview

#Preview {
    InsulinTetrisView()
        .environmentObject(GameState())
}
