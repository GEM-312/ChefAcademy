//
//  HealthyChoiceGameView.swift
//  ChefAcademy
//
//  Pip's Healthy Choice Game!
//  Pip throws food items up — tap the HEALTHY ones, avoid the junk!
//  5 bad choices = Pip inflates like a balloon and floats away (game over).
//  Healthy choices earn coins and unlock seeds + pantry items.
//

import SwiftUI

// MARK: - Food Item Model

struct FoodChoice: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let isHealthy: Bool
    /// Asset image name (nil = use emoji instead)
    let imageName: String?
    /// If healthy, which VegetableType or PantryItem it unlocks
    let unlocksVeggie: VegetableType?
    let unlocksPantry: PantryItem?
    /// Fun fact Pip says when you get it right
    let pipFact: String
}

// MARK: - Flying Food (on-screen item)

struct FlyingFood: Identifiable {
    let id = UUID()
    let food: FoodChoice
    var x: CGFloat        // horizontal position
    var y: CGFloat        // current vertical position
    var velocity: CGFloat // upward velocity (decreases with gravity)
    var rotation: Double  // spin
    var wobblePhase: CGFloat // for sinusoidal horizontal drift
    let wobbleSpeed: CGFloat // how fast it wobbles
    let wobbleAmount: CGFloat // how wide the wobble is
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
    var tapped: Bool = false
    var resultIcon: String? = nil
}

// MARK: - Game State Machine

enum HealthyGamePhase {
    case ready      // Start screen
    case playing    // Active gameplay
    case gameOver   // Pip floated away (too many bad choices)
    case victory    // Survived all rounds!
}

// MARK: - Healthy Choice Game View

struct HealthyChoiceGameView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) private var dismiss

    // Game state
    @State private var phase: HealthyGamePhase = .ready
    @State private var flyingFoods: [FlyingFood] = []
    @State private var badChoices: Int = 0
    @State private var goodChoices: Int = 0
    @State private var coinsEarned: Int = 0
    @State private var round: Int = 0
    @State private var missedHealthy: Int = 0

    // Pip animation
    @State private var pipScale: CGFloat = 1.0
    @State private var pipOffset: CGFloat = 0
    @State private var pipRotation: Double = 0
    @State private var pipFloatingAway = false

    // Rewards tracking
    @State private var unlockedVeggies: [VegetableType] = []
    @State private var unlockedPantry: [PantryItem] = []
    @State private var recipeSuggestions: [String] = []

    // Timer
    @State private var gameTimer: Timer?
    @State private var spawnTimer: Timer?
    @State private var currentSpawnInterval: TimeInterval = 1.8

    // Gravity & physics — 60fps for smooth motion
    private let gravity: CGFloat = 0.18
    private let maxBadChoices = 5
    private let totalRounds = 25

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color.AppTheme.cream.ignoresSafeArea()

                switch phase {
                case .ready:
                    readyScreen(size: geo.size)
                case .playing:
                    gameplayView(size: geo.size)
                case .gameOver:
                    gameOverScreen(size: geo.size)
                case .victory:
                    victoryScreen(size: geo.size)
                }
            }
        }
    }

    // MARK: - Ready Screen

    func readyScreen(size: CGSize) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Pip's Healthy Picks!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            PipWavingAnimatedView(size: 150)

            VStack(spacing: AppSpacing.sm) {
                Text("Pip throws food in the air!")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.sepia)
                Text("Tap the HEALTHY foods before they fall!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                Text("But watch out — 5 bad picks and Pip floats away!")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.terracotta)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.xl)

            Button(action: { startGame(size: size) }) {
                Text("Let's Go!")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.cream)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
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

    // MARK: - Gameplay View

    func gameplayView(size: CGSize) -> some View {
        ZStack {
            // Flying food items
            ForEach(flyingFoods) { item in
                if !item.tapped {
                    foodBubble(item: item)
                        .position(x: item.x, y: item.y)
                        .onTapGesture {
                            tapFood(item)
                        }
                } else if let icon = item.resultIcon {
                    // Brief feedback icon
                    Text(icon)
                        .font(.system(size: 40))
                        .position(x: item.x, y: item.y)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // HUD (top)
            VStack {
                HStack {
                    // Close button
                    Button(action: { endGame() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.AppTheme.sepia.opacity(0.6))
                    }
                    .buttonStyle(.plain)

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

                    // Bad choice hearts
                    HStack(spacing: 4) {
                        ForEach(0..<maxBadChoices, id: \.self) { i in
                            Image(systemName: i < badChoices ? "heart.slash.fill" : "heart.fill")
                                .foregroundColor(i < badChoices ? .gray : .red)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)

                // Round progress
                ProgressView(value: Double(round), total: Double(totalRounds))
                    .tint(Color.AppTheme.sage)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer()
            }

            // Pip at the bottom (throwing food up)
            VStack {
                Spacer()

                ZStack {
                    // Pip character
                    Image("pip_neutral")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80 * pipScale, height: 80 * pipScale)
                        .rotationEffect(.degrees(pipRotation))
                        .offset(y: pipOffset)
                        .scaleEffect(pipScale)
                }
                .padding(.bottom, 60) // Clear tab bar
            }
        }
    }

    // MARK: - Food Bubble

    func foodBubble(item: FlyingFood) -> some View {
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

    // MARK: - Game Over Screen

    func gameOverScreen(size: CGSize) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Text("Oh no!")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.terracotta)

            // Pip floating away animation
            Image("pip_neutral")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .scaleEffect(1.5)
                .offset(y: pipFloatingAway ? -400 : 0)
                .opacity(pipFloatingAway ? 0 : 1)
                .animation(.easeIn(duration: 2), value: pipFloatingAway)

            Text("Pip ate too much junk food and floated away!")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            // Stats
            statsCard

            HStack(spacing: AppSpacing.md) {
                Button(action: { resetGame(size: size) }) {
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
        .onAppear { pipFloatingAway = true }
    }

    // MARK: - Victory Screen

    func victoryScreen(size: CGSize) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                Spacer().frame(height: AppSpacing.xl)

                Text("Amazing Job!")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.sage)

                PipWavingAnimatedView(size: 120)

                // Stats
                statsCard

                // Unlocked items announcement
                if !unlockedVeggies.isEmpty || !unlockedPantry.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Pip says:")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sage)

                        if !unlockedVeggies.isEmpty {
                            let veggieNames = unlockedVeggies.map { $0.displayName }.joined(separator: ", ")
                            Text("You can grow \(veggieNames) in your garden!")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        }

                        if !unlockedPantry.isEmpty {
                            let pantryNames = unlockedPantry.map { $0.displayName }.joined(separator: ", ")
                            Text("You can buy \(pantryNames) from the farm shop!")
                                .font(.AppTheme.body)
                                .foregroundColor(Color.AppTheme.darkBrown)
                        }

                        if !recipeSuggestions.isEmpty {
                            Text("Now you can cook: \(recipeSuggestions.joined(separator: ", "))!")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.cardCornerRadius)
                    .padding(.horizontal, AppSpacing.md)
                }

                HStack(spacing: AppSpacing.md) {
                    Button(action: { resetGame(size: size) }) {
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
    }

    // MARK: - Stats Card

    var statsCard: some View {
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
                Text("\(coinsEarned)")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.goldenWheat)
                Text("Coins")
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
        .padding(AppSpacing.md)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
    }

    // MARK: - Game Logic

    func startGame(size: CGSize) {
        phase = .playing
        badChoices = 0
        goodChoices = 0
        coinsEarned = 0
        round = 0
        missedHealthy = 0
        pipScale = 1.0
        pipOffset = 0
        pipRotation = 0
        pipFloatingAway = false
        flyingFoods = []
        unlockedVeggies = []
        unlockedPantry = []
        recipeSuggestions = []

        currentSpawnInterval = 1.8

        // Physics timer — 60fps for buttery smooth motion
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updatePhysics(size: size)
        }

        // Start spawn cycle
        scheduleNextSpawn(size: size)

        // Throw first food immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            spawnFood(size: size)
            round += 1
        }
    }

    func scheduleNextSpawn(size: CGSize) {
        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: currentSpawnInterval, repeats: false) { _ in
            guard self.phase == .playing else { return }
            if self.round < self.totalRounds {
                self.spawnFood(size: size)
                self.round += 1
                self.scheduleNextSpawn(size: size)
            } else if self.flyingFoods.filter({ !$0.tapped }).isEmpty {
                self.finishGame(won: true)
            }
        }
    }

    func speedUpSpawning(size: CGSize) {
        // Every 3 healthy choices, spawn faster (min 0.7s)
        let speedLevel = Double(goodChoices / 3)
        currentSpawnInterval = max(0.7, 1.8 - speedLevel * 0.2)

        // Sometimes throw 2 at once when going fast
        if goodChoices >= 8 && goodChoices % 4 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.spawnFood(size: size)
            }
        }
    }

    func spawnFood(size: CGSize) {
        guard phase == .playing else { return }

        let food = HealthyChoiceGameView.allFoods.randomElement()!
        let startX = CGFloat.random(in: size.width * 0.25 ... size.width * 0.75)
        let startY = size.height - 120 // Start from Pip's position

        let item = FlyingFood(
            food: food,
            x: startX,
            y: startY,
            velocity: -CGFloat.random(in: 9...13), // Smoother upward (halved for 60fps)
            rotation: Double.random(in: -10...10),
            wobblePhase: CGFloat.random(in: 0 ... .pi * 2),
            wobbleSpeed: CGFloat.random(in: 0.04...0.08),
            wobbleAmount: CGFloat.random(in: 15...35)
        )

        flyingFoods.append(item)

        // Pip throwing animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            pipScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pipScale = max(1.0, 1.0 + CGFloat(badChoices) * 0.12) // Stay inflated if bad choices
            }
        }
    }

    func updatePhysics(size: CGSize) {
        for i in flyingFoods.indices {
            guard !flyingFoods[i].tapped else { continue }

            // Gravity pulls down
            flyingFoods[i].velocity += gravity
            flyingFoods[i].y += flyingFoods[i].velocity

            // Sinusoidal horizontal wobble for organic feel
            flyingFoods[i].wobblePhase += flyingFoods[i].wobbleSpeed
            flyingFoods[i].x += sin(flyingFoods[i].wobblePhase) * (flyingFoods[i].wobbleAmount * 0.03)

            // Gentle continuous rotation
            flyingFoods[i].rotation += Double(flyingFoods[i].velocity) * 0.15

            // Scale: grow slightly as it rises, shrink as it falls
            let normalizedY = flyingFoods[i].y / size.height
            flyingFoods[i].scale = 0.85 + (1.0 - abs(normalizedY - 0.4)) * 0.25

            // Item fell off screen — missed it
            if flyingFoods[i].y > size.height + 50 {
                if flyingFoods[i].food.isHealthy {
                    missedHealthy += 1
                }
                flyingFoods[i].tapped = true
            }
        }

        // Clean up old items
        flyingFoods.removeAll { $0.tapped && $0.resultIcon == nil }
    }

    func tapFood(_ item: FlyingFood) {
        guard let index = flyingFoods.firstIndex(where: { $0.id == item.id }),
              !flyingFoods[index].tapped else { return }

        flyingFoods[index].tapped = true

        if item.food.isHealthy {
            // GOOD choice!
            flyingFoods[index].resultIcon = "\u{2705}" // green checkmark
            goodChoices += 1
            let reward = 5
            coinsEarned += reward

            // Track unlocks
            if let veg = item.food.unlocksVeggie, !unlockedVeggies.contains(veg) {
                unlockedVeggies.append(veg)
            }
            if let pantry = item.food.unlocksPantry, !unlockedPantry.contains(pantry) {
                unlockedPantry.append(pantry)
            }

            // Speed up spawning as kid gets better!
            speedUpSpawning(size: UIScreen.main.bounds.size)

            // Remove feedback after brief flash
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                flyingFoods.removeAll { $0.id == item.id }
            }
        } else {
            // BAD choice — Pip gets bigger!
            flyingFoods[index].resultIcon = "\u{274C}" // red X
            badChoices += 1

            // Inflate Pip
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                pipScale = 1.0 + CGFloat(badChoices) * 0.15
                pipRotation = Double.random(in: -10...10)
            }

            // Remove feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                flyingFoods.removeAll { $0.id == item.id }
            }

            // Check game over
            if badChoices >= maxBadChoices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    finishGame(won: false)
                }
            }
        }
    }

    func finishGame(won: Bool) {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        gameTimer = nil
        spawnTimer = nil

        // Award coins
        if coinsEarned > 0 {
            gameState.addCoins(coinsEarned)
        }
        gameState.addXP(goodChoices * 3)

        // Build recipe suggestions from unlocked ingredients
        buildRecipeSuggestions()

        if won {
            // Pip balloon float-away if bad choices happened
            withAnimation(.easeInOut(duration: 0.5)) {
                pipScale = 1.0
                pipRotation = 0
            }
            phase = .victory
        } else {
            // Game over — Pip floats away!
            withAnimation(.easeIn(duration: 1.5)) {
                pipOffset = -800
                pipScale = 2.0
                pipRotation = 360
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                phase = .gameOver
            }
        }
    }

    func endGame() {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        dismiss()
    }

    func resetGame(size: CGSize) {
        pipFloatingAway = false
        phase = .ready
    }

    func buildRecipeSuggestions() {
        // Check which recipes can be made with unlocked veggies
        let veggieSet = Set(unlockedVeggies)
        for recipe in GardenRecipes.all {
            let recipeVeggies = Set(recipe.gardenIngredients)
            if !recipeVeggies.isEmpty && recipeVeggies.isSubset(of: veggieSet) {
                recipeSuggestions.append(recipe.title)
            }
        }
        // Limit to 3 suggestions
        if recipeSuggestions.count > 3 {
            recipeSuggestions = Array(recipeSuggestions.prefix(3))
        }
    }

    // MARK: - Food Database

    static let allFoods: [FoodChoice] = [
        // HEALTHY — Veggies with real asset images
        FoodChoice(name: "Carrot", emoji: "\u{1F955}", isHealthy: true, imageName: "carrot_veggie",
                   unlocksVeggie: .carrot, unlocksPantry: nil,
                   pipFact: "Carrots are full of Vitamin A for super eyes!"),
        FoodChoice(name: "Broccoli", emoji: "\u{1F966}", isHealthy: true, imageName: "broccoli_veggie",
                   unlocksVeggie: .broccoli, unlocksPantry: nil,
                   pipFact: "Broccoli has more Vitamin C than an orange!"),
        FoodChoice(name: "Spinach", emoji: "\u{1F96C}", isHealthy: true, imageName: "spinach_veggie",
                   unlocksVeggie: .spinach, unlocksPantry: nil,
                   pipFact: "Spinach is packed with iron for strong muscles!"),
        FoodChoice(name: "Tomato", emoji: "\u{1F345}", isHealthy: true, imageName: "tomato_veggie",
                   unlocksVeggie: .tomato, unlocksPantry: nil,
                   pipFact: "Tomatoes have lycopene that helps your heart!"),
        FoodChoice(name: "Cucumber", emoji: "\u{1F952}", isHealthy: true, imageName: "cucumber_veggie",
                   unlocksVeggie: .cucumber, unlocksPantry: nil,
                   pipFact: "Cucumbers are 96% water — super hydrating!"),
        FoodChoice(name: "Corn", emoji: "\u{1F33D}", isHealthy: true, imageName: "corn_veggie",
                   unlocksVeggie: .corn, unlocksPantry: nil,
                   pipFact: "Corn gives you energy with healthy fiber!"),
        FoodChoice(name: "Sweet Potato", emoji: "\u{1F360}", isHealthy: true, imageName: "sweetpotato_veggie",
                   unlocksVeggie: .sweetPotato, unlocksPantry: nil,
                   pipFact: "Sweet potatoes are full of Vitamin A!"),
        FoodChoice(name: "Bell Pepper", emoji: "\u{1FAD1}", isHealthy: true, imageName: "bellpepper_red_veggie",
                   unlocksVeggie: .bellPepperRed, unlocksPantry: nil,
                   pipFact: "Red peppers have 3x more Vitamin C than oranges!"),
        FoodChoice(name: "Green Beans", emoji: "\u{1FAD8}", isHealthy: true, imageName: "greenbeans_veggie",
                   unlocksVeggie: .greenBeans, unlocksPantry: nil,
                   pipFact: "Green beans help keep your bones strong!"),
        FoodChoice(name: "Lettuce", emoji: "\u{1F96C}", isHealthy: true, imageName: "lettuce_veggie",
                   unlocksVeggie: .lettuce, unlocksPantry: nil,
                   pipFact: "Lettuce is great for staying hydrated!"),
        FoodChoice(name: "Kale", emoji: "\u{1F96C}", isHealthy: true, imageName: "kale_veggie",
                   unlocksVeggie: .kale, unlocksPantry: nil,
                   pipFact: "Kale is a superfood packed with vitamins!"),
        FoodChoice(name: "Radish", emoji: "\u{1F4A5}", isHealthy: true, imageName: "radish_veggie",
                   unlocksVeggie: .radish, unlocksPantry: nil,
                   pipFact: "Radishes grow super fast — just 25 days!"),
        FoodChoice(name: "Pumpkin", emoji: "\u{1F383}", isHealthy: true, imageName: "pumpkin_veggie",
                   unlocksVeggie: .pumpkin, unlocksPantry: nil,
                   pipFact: "Pumpkins are full of fiber and Vitamin A!"),
        FoodChoice(name: "Onion", emoji: "\u{1F9C5}", isHealthy: true, imageName: "onion_veggie",
                   unlocksVeggie: .onion, unlocksPantry: nil,
                   pipFact: "Onions have antioxidants that fight germs!"),
        FoodChoice(name: "Eggplant", emoji: "\u{1F346}", isHealthy: true, imageName: "eggplant_veggie",
                   unlocksVeggie: .eggplant, unlocksPantry: nil,
                   pipFact: "Eggplant has fiber to keep your tummy happy!"),
        FoodChoice(name: "Beet", emoji: "\u{1F4A5}", isHealthy: true, imageName: "beet_veggie",
                   unlocksVeggie: .beet, unlocksPantry: nil,
                   pipFact: "Beets give you iron for strong blood!"),

        // HEALTHY — Protein with farm assets
        FoodChoice(name: "Eggs", emoji: "\u{1F95A}", isHealthy: true, imageName: "farm_eggs",
                   unlocksVeggie: nil, unlocksPantry: .eggs,
                   pipFact: "Eggs have every vitamin except Vitamin C!"),
        FoodChoice(name: "Chicken", emoji: "\u{1F357}", isHealthy: true, imageName: "farm_chicken",
                   unlocksVeggie: nil, unlocksPantry: .chicken,
                   pipFact: "Chicken is packed with protein for strong muscles!"),
        FoodChoice(name: "Greek Yogurt", emoji: "\u{1F95B}", isHealthy: true, imageName: "farm_greekyogurt",
                   unlocksVeggie: nil, unlocksPantry: .greekYogurt,
                   pipFact: "Greek yogurt has probiotics for a happy tummy!"),
        FoodChoice(name: "Nuts", emoji: "\u{1F95C}", isHealthy: true, imageName: "farm_nuts",
                   unlocksVeggie: nil, unlocksPantry: .nuts,
                   pipFact: "Nuts have healthy fats that help your brain!"),
        FoodChoice(name: "Cheese", emoji: "\u{1F9C0}", isHealthy: true, imageName: "farm_cheese",
                   unlocksVeggie: nil, unlocksPantry: .cheese,
                   pipFact: "Cheese has calcium for strong bones!"),

        // HEALTHY — A couple fruits
        FoodChoice(name: "Strawberry", emoji: "\u{1F353}", isHealthy: true, imageName: "strawberry_veggie",
                   unlocksVeggie: .strawberry, unlocksPantry: nil,
                   pipFact: "Strawberries are bursting with Vitamin C!"),
        FoodChoice(name: "Blueberries", emoji: "\u{1FAD0}", isHealthy: true, imageName: "blueberry_veggie",
                   unlocksVeggie: .blueberry, unlocksPantry: nil,
                   pipFact: "Blueberries are brain food — full of antioxidants!"),

        // UNHEALTHY — Junk food (emoji only, no assets)
        FoodChoice(name: "Oreo", emoji: "\u{1F36A}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Cookies have lots of sugar — not great for energy!"),
        FoodChoice(name: "Candy Bar", emoji: "\u{1F36B}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Candy bars are mostly sugar and don't help your body!"),
        FoodChoice(name: "French Fries", emoji: "\u{1F35F}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Fried food has lots of unhealthy fat!"),
        FoodChoice(name: "Soda", emoji: "\u{1F964}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Soda has SO much sugar — try water instead!"),
        FoodChoice(name: "Donut", emoji: "\u{1F369}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Donuts are deep fried and full of sugar!"),
        FoodChoice(name: "Ice Cream", emoji: "\u{1F368}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Ice cream is a treat — but not every day fuel!"),
        FoodChoice(name: "Chips", emoji: "\u{1F35F}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Chips are salty and don't give your body what it needs!"),
        FoodChoice(name: "Cake", emoji: "\u{1F370}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Cake is yummy for birthdays, but not for fuel!"),
        FoodChoice(name: "Gummy Bears", emoji: "\u{1F43B}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Gummy bears are just sugar shaped like bears!"),
        FoodChoice(name: "Hot Dog", emoji: "\u{1F32D}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Hot dogs are processed — not real protein!"),
        FoodChoice(name: "Pizza", emoji: "\u{1F355}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Store pizza has lots of grease and not many veggies!"),
        FoodChoice(name: "Pop Tart", emoji: "\u{1F36E}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Pop Tarts are mostly sugar with almost no real fruit!"),
        FoodChoice(name: "Cotton Candy", emoji: "\u{1F365}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Cotton candy is literally just spun sugar!"),
        FoodChoice(name: "Milkshake", emoji: "\u{1F964}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "One milkshake can have more sugar than 5 cookies!"),
        FoodChoice(name: "Fried Chicken", emoji: "\u{1F357}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Deep frying takes away the good stuff in chicken!"),
        FoodChoice(name: "Nachos", emoji: "\u{1FAD4}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Nachos are mostly chips with fake cheese sauce!"),
        FoodChoice(name: "Pancake Syrup", emoji: "\u{1F95E}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Syrup is almost all sugar — try fruit on pancakes!"),
        FoodChoice(name: "Lollipop", emoji: "\u{1F36D}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Lollipops are pure sugar on a stick!"),
        FoodChoice(name: "Cupcake", emoji: "\u{1F9C1}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Cupcakes have frosting that's mostly butter and sugar!"),
        FoodChoice(name: "Corn Dog", emoji: "\u{1F32D}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Corn dogs are fried and processed — double trouble!"),
        FoodChoice(name: "Cheese Puffs", emoji: "\u{1F9C0}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Cheese puffs are air, fake cheese, and salt!"),
        FoodChoice(name: "Brownie", emoji: "\u{1F36B}", isHealthy: false, imageName: nil,
                   unlocksVeggie: nil, unlocksPantry: nil,
                   pipFact: "Brownies are packed with sugar and butter!"),
    ]
}

// MARK: - Preview

#Preview {
    HealthyChoiceGameView()
        .environmentObject(GameState.preview)
}
