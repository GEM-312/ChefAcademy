//
//  KitchenView.swift
//  ChefAcademy
//
//  Pip's Kitchen! Interactive kitchen map with cooking flow.
//  Tap Pantry → items fly to Counter → tap Counter → items fly to Stove → mini-game!
//

import SwiftUI

// MARK: - Kitchen Cooking Phase

enum KitchenCookingPhase {
    case browsing       // Exploring the kitchen, no recipe selected
    case gatherPantry   // Tap pantry to send items to counter one by one
    case moveToStove    // Tap counter to send everything to stove
    case stoveReady     // Tap stove to turn on and start cooking
}

// MARK: - Kitchen View

struct KitchenView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.horizontalSizeClass) var sizeClass

    private var isIPad: Bool { sizeClass != .compact }

    // Pip message
    @State private var pipMessage = "Welcome to my kitchen! Tap around to explore!"
    @State private var pipPose: PipPose = .cooking

    // Browse mode
    @State private var showRecipePicker = false

    // Cooking mode
    @State private var cookingPhase: KitchenCookingPhase = .browsing
    @State private var cookingRecipe: Recipe? = nil
    @State private var pantryItemsNeeded: [PantryItem] = []
    @State private var currentPantryIndex: Int = 0
    @State private var itemsOnCounter: [String] = []   // image names gathered
    @State private var itemsOnStove: Bool = false
    @State private var stoveFlameOn: Bool = false

    // Flying animation
    @State private var flyingImage: String? = nil
    @State private var flyingPosition: CGPoint = .zero
    @State private var flyingScale: CGFloat = 1.0
    @State private var flyingOpacity: Double = 1.0

    // Spot pulsing
    @State private var spotPulse: Bool = false

    // Mini-game
    @State private var showMiniGame: Bool = false

    // ==========================================
    // SCENE EDITOR
    // ==========================================
    @State private var editMode = false

    @State private var sceneItems: [SceneItem] = [
        SceneItem(id: "counter", label: "Counter", icon: "🍽️", xPercent: 0.34, yPercent: 0.68),
        SceneItem(id: "stove", label: "Stove", icon: "🔥", xPercent: 0.88, yPercent: 0.68),
        SceneItem(id: "pantry", label: "Pantry", icon: "📦", xPercent: 0.45, yPercent: 0.78),
        SceneItem(id: "pip", label: "Pip", icon: "🦔", xPercent: 0.71, yPercent: 0.90),
    ]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width

                ZStack {
                    Color.AppTheme.cream
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {

                            // MARK: - Header
                            kitchenHeader
                                .padding(.top, AppSpacing.sm)
                                .padding(.bottom, AppSpacing.sm)

                            // MARK: - Kitchen Map
                            kitchenMapSection(screenWidth: screenWidth)

                            // MARK: - Bottom Panel
                            bottomPanel
                                .padding(.top, AppSpacing.md)

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showRecipePicker) {
            recipePicker
                .environmentObject(gameState)
        }
        .fullScreenCover(isPresented: $showMiniGame) {
            if let recipe = cookingRecipe {
                CookingSessionView(recipe: recipe)
                    .environmentObject(gameState)
            }
        }
        .onChange(of: showMiniGame) { _, showing in
            if !showing {
                // Returned from mini-game — reset cooking
                resetCookingMode()
            }
        }
    }

    // MARK: - Kitchen Header

    var kitchenHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pip's Kitchen")
                    .font(isIPad ? .AppTheme.largeTitle : .AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text(kitchenHint)
                    .font(isIPad ? .AppTheme.body : .AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }

            Spacer()

            #if DEBUG
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    editMode.toggle()
                }
            } label: {
                Image(systemName: editMode ? "pencil.circle.fill" : "pencil.circle")
                    .font(.system(size: isIPad ? 24 : 20))
                    .foregroundColor(editMode ? .red : Color.AppTheme.lightSepia)
            }
            #endif

            // Cancel cooking button
            if cookingPhase != .browsing {
                Button {
                    resetCookingMode()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: isIPad ? 24 : 20))
                        .foregroundColor(Color.AppTheme.terracotta)
                }
            }

            // Coin display
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                    .font(.system(size: isIPad ? 18 : 14))
                Text("\(gameState.coins)")
                    .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, isIPad ? AppSpacing.md : AppSpacing.sm)
            .padding(.vertical, isIPad ? AppSpacing.sm : AppSpacing.xs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(20)
        }
        .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
    }

    // MARK: - Kitchen Map Section

    func pos(for id: String, w: CGFloat, h: CGFloat) -> CGPoint {
        guard let item = sceneItems.first(where: { $0.id == id }) else {
            return CGPoint(x: w * 0.5, y: h * 0.5)
        }
        return CGPoint(x: w * item.xPercent, y: h * item.yPercent)
    }

    func kitchenMapSection(screenWidth: CGFloat) -> some View {
        Image("bg_kitchen")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .opacity(0.85)
            .overlay(
                GeometryReader { mapGeo in
                    let w = mapGeo.size.width
                    let h = mapGeo.size.height
                    let pantryPos = pos(for: "pantry", w: w, h: h)
                    let counterPos = pos(for: "counter", w: w, h: h)
                    let stovePos = pos(for: "stove", w: w, h: h)

                    if editMode {
                        SceneEditorOverlay(
                            mapWidth: w,
                            mapHeight: h,
                            items: $sceneItems,
                            editMode: true
                        )
                    } else {
                        // MARK: Counter Spot
                        kitchenSpot(
                            icon: "tray.full.fill",
                            label: cookingPhase == .moveToStove ? "Tap me!" : "Counter",
                            color: Color.AppTheme.goldenWheat,
                            badgeCount: cookingPhase != .browsing ? itemsOnCounter.count : totalIngredientCount,
                            isPulsing: cookingPhase == .moveToStove
                        ) {
                            handleCounterTap(counterPos: counterPos, stovePos: stovePos)
                        }
                        .position(counterPos)

                        // MARK: Stove Spot
                        kitchenSpot(
                            icon: stoveFlameOn ? "flame.fill" : "flame",
                            label: cookingPhase == .stoveReady ? "Tap me!" : "Stove",
                            color: Color.AppTheme.terracotta,
                            badgeCount: cookingPhase == .browsing ? readyRecipeCount : 0,
                            isPulsing: cookingPhase == .stoveReady
                        ) {
                            handleStoveTap()
                        }
                        .position(stovePos)

                        // MARK: Pantry Spot
                        kitchenSpot(
                            icon: "archivebox.fill",
                            label: cookingPhase == .gatherPantry ? "Tap me!" : "Pantry",
                            color: Color.AppTheme.sage,
                            badgeCount: cookingPhase == .gatherPantry
                                ? (pantryItemsNeeded.count - currentPantryIndex)
                                : pantryItemCount,
                            isPulsing: cookingPhase == .gatherPantry
                        ) {
                            handlePantryTap(pantryPos: pantryPos, counterPos: counterPos)
                        }
                        .position(pantryPos)

                        // Items gathered on counter (small images near counter)
                        if !itemsOnCounter.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(itemsOnCounter.indices, id: \.self) { i in
                                    Image(itemsOnCounter[i])
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                }
                            }
                            .padding(4)
                            .background(Color.AppTheme.warmCream.opacity(0.85))
                            .cornerRadius(8)
                            .position(x: counterPos.x, y: counterPos.y - 35)
                        }

                        // Items on stove indicator
                        if itemsOnStove {
                            Image(systemName: stoveFlameOn ? "flame.fill" : "frying.pan.fill")
                                .font(.system(size: 20))
                                .foregroundColor(stoveFlameOn ? Color.AppTheme.terracotta : Color.AppTheme.goldenWheat)
                                .position(x: stovePos.x, y: stovePos.y - 35)
                        }

                        // Pip in kitchen
                        Image("pip_cooking")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: isIPad ? 90 : 60, height: isIPad ? 90 : 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.AppTheme.goldenWheat, lineWidth: 2.5)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 3)
                            .position(pos(for: "pip", w: w, h: h))

                        // MARK: Flying Item
                        if let img = flyingImage {
                            Image(img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .scaleEffect(flyingScale)
                                .opacity(flyingOpacity)
                                .position(flyingPosition)
                        }
                    }
                }
            )
    }

    // MARK: - Kitchen Spot

    func kitchenSpot(icon: String, label: String, color: Color, badgeCount: Int, isPulsing: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: isIPad ? 70 : 50, height: isIPad ? 70 : 50)
                        .scaleEffect(isPulsing && spotPulse ? 1.3 : 1.0)

                    Circle()
                        .fill(Color.AppTheme.warmCream.opacity(0.9))
                        .frame(width: isIPad ? 56 : 40, height: isIPad ? 56 : 40)

                    Image(systemName: icon)
                        .font(.system(size: isIPad ? 24 : 18))
                        .foregroundColor(color)
                }
                .overlay(
                    badgeCount > 0 ?
                        Text("\(badgeCount)")
                            .font(.system(size: isIPad ? 12 : 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(color)
                            .clipShape(Circle())
                            .offset(x: isIPad ? 22 : 16, y: isIPad ? -22 : -16)
                    : nil
                )

                Text(label)
                    .font(.system(size: isIPad ? 13 : 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isPulsing ? color : Color.AppTheme.darkBrown)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isPulsing ? color.opacity(0.15) : Color.AppTheme.warmCream.opacity(0.9))
                    .cornerRadius(8)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                spotPulse = true
            }
        }
    }

    // MARK: - Spot Actions

    private func handlePantryTap(pantryPos: CGPoint, counterPos: CGPoint) {
        switch cookingPhase {
        case .gatherPantry:
            gatherNextItem(pantryPos: pantryPos, counterPos: counterPos)
        default:
            // Browse mode — just show message
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pipPose = .cooking
                pipMessage = pantryItemCount > 0
                    ? "We have \(pantryItemCount) pantry staples on the shelf!"
                    : "Pantry is empty! Visit the farm shop to stock up."
            }
        }
    }

    private func handleCounterTap(counterPos: CGPoint, stovePos: CGPoint) {
        switch cookingPhase {
        case .moveToStove:
            moveItemsToStove(counterPos: counterPos, stovePos: stovePos)
        default:
            // Browse mode
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pipPose = .thinking
                if totalIngredientCount > 0 {
                    pipMessage = "We have \(ingredientCount) veggies and \(pantryItemCount) pantry items!"
                } else {
                    pipMessage = "Counter is empty! Grow veggies and visit the farm shop."
                }
            }
        }
    }

    private func handleStoveTap() {
        switch cookingPhase {
        case .stoveReady:
            activateStove()
        default:
            // Browse mode — open recipe picker
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if readyRecipeCount > 0 {
                    pipPose = .excited
                    pipMessage = "\(readyRecipeCount) recipes ready to cook! Let's go!"
                    showRecipePicker = true
                } else {
                    pipPose = .thinking
                    pipMessage = "We need ingredients before we can cook! Visit the garden."
                }
            }
        }
    }

    // MARK: - Cooking Flow

    func startCooking(recipe: Recipe) {
        cookingRecipe = recipe

        // Consume garden ingredients
        for veg in recipe.gardenIngredients {
            _ = gameState.useIngredient(veg)
        }

        // Set up pantry gathering
        pantryItemsNeeded = recipe.pantryIngredients
        currentPantryIndex = 0
        itemsOnCounter = []
        itemsOnStove = false
        stoveFlameOn = false

        if pantryItemsNeeded.isEmpty {
            // No pantry items needed — go straight to stove
            cookingPhase = .stoveReady
            pipMessage = "Ingredients ready! Tap the stove to cook!"
            pipPose = .excited
        } else {
            cookingPhase = .gatherPantry
            pipMessage = "Grab \(pantryItemsNeeded[0].displayName) from the pantry!"
            pipPose = .cooking
        }
    }

    private func gatherNextItem(pantryPos: CGPoint, counterPos: CGPoint) {
        guard currentPantryIndex < pantryItemsNeeded.count else { return }
        guard flyingImage == nil else { return } // prevent double-tap

        let item = pantryItemsNeeded[currentPantryIndex]

        // Consume from inventory
        _ = gameState.usePantryItem(item)

        // Start fly animation: pantry → counter
        flyingImage = item.imageName
        flyingPosition = pantryPos
        flyingScale = 1.2
        flyingOpacity = 1.0

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            flyingPosition = counterPos
            flyingScale = 0.7
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.15)) {
                flyingOpacity = 0
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                itemsOnCounter.append(item.imageName)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            flyingImage = nil
            currentPantryIndex += 1

            if currentPantryIndex >= pantryItemsNeeded.count {
                cookingPhase = .moveToStove
                pipMessage = "All ingredients on the counter! Tap the counter to move them to the stove!"
                pipPose = .excited
            } else {
                let nextItem = pantryItemsNeeded[currentPantryIndex]
                pipMessage = "Great! Now grab the \(nextItem.displayName)!"
            }
        }
    }

    private func moveItemsToStove(counterPos: CGPoint, stovePos: CGPoint) {
        guard flyingImage == nil else { return }

        // Fly first item image as representative
        flyingImage = itemsOnCounter.first ?? "farm_salt"
        flyingPosition = counterPos
        flyingScale = 1.0
        flyingOpacity = 1.0

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            flyingPosition = stovePos
            flyingScale = 0.7
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation {
                flyingOpacity = 0
                itemsOnCounter = []
                itemsOnStove = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            flyingImage = nil
            cookingPhase = .stoveReady
            pipMessage = "Everything's on the stove! Tap it to start cooking!"
            pipPose = .excited
        }
    }

    private func activateStove() {
        stoveFlameOn = true
        pipMessage = "The stove is on! Let's cook!"
        pipPose = .celebrating

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showMiniGame = true
        }
    }

    private func resetCookingMode() {
        cookingPhase = .browsing
        cookingRecipe = nil
        pantryItemsNeeded = []
        currentPantryIndex = 0
        itemsOnCounter = []
        itemsOnStove = false
        stoveFlameOn = false
        flyingImage = nil
        pipMessage = "Welcome to my kitchen! Tap around to explore!"
        pipPose = .cooking
    }

    // MARK: - Bottom Panel

    var bottomPanel: some View {
        VStack(spacing: AppSpacing.md) {
            // Pip's kitchen message
            PipKitchenMessage(pose: pipPose, message: pipMessage)
                .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)

            // Cooking mode banner
            if let recipe = cookingRecipe {
                cookingBanner(recipe: recipe)
                    .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
            } else {
                // Browse mode — show counter contents, ready recipes, and almost-ready
                counterSection
                    .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)

                if readyRecipeCount > 0 {
                    readyRecipesSection
                        .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
                }

                // Almost ready recipes (have garden veggies, missing some pantry)
                almostReadySection
                    .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
            }
        }
    }

    // MARK: - Cooking Banner

    private func cookingBanner(recipe: Recipe) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(recipe.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Cooking: \(recipe.title)")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text(cookingPhaseLabel)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(Color.AppTheme.goldenWheat.opacity(0.15))
        .cornerRadius(AppSpacing.cardCornerRadius)
    }

    private var cookingPhaseLabel: String {
        switch cookingPhase {
        case .browsing: return ""
        case .gatherPantry: return "Tap the pantry to grab ingredients"
        case .moveToStove: return "Tap the counter to move to stove"
        case .stoveReady: return "Tap the stove to start cooking!"
        }
    }

    // MARK: - Counter Section

    var counterSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
            Text("On the Counter")
                .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            if gameState.harvestedIngredients.isEmpty && gameState.pantryInventory.isEmpty {
                Text("Nothing here yet! Grow veggies and visit the farm shop.")
                    .font(isIPad ? .AppTheme.headline : .AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            } else {
                if !gameState.harvestedIngredients.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
                            ForEach(gameState.harvestedIngredients) { ingredient in
                                IngredientBadge(ingredient: ingredient, isIPad: isIPad)
                            }
                        }
                    }
                }

                if !gameState.pantryInventory.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
                            ForEach(gameState.pantryInventory) { stock in
                                PantryStapleItem(stock: stock)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ready Recipes Section

    var readyRecipesSection: some View {
        let readyRecipes = GardenRecipes.all.filter {
            $0.canCookFull(
                harvestedIngredients: gameState.harvestedIngredients,
                pantryInventory: gameState.pantryInventory
            )
        }

        return VStack(alignment: .leading, spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.AppTheme.sage)
                Text("Ready to Cook!")
                    .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }

            ForEach(readyRecipes) { recipe in
                HStack(spacing: AppSpacing.md) {
                    Image(recipe.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: isIPad ? 80 : 60, height: isIPad ? 80 : 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(isIPad ? .AppTheme.headline : .AppTheme.bodyBold)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .lineLimit(1)

                        HStack(spacing: AppSpacing.sm) {
                            Label("\(recipe.cookTime) min", systemImage: "clock")
                            Label(recipe.difficulty.rawValue, systemImage: "chart.bar.fill")
                        }
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sepia)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: isIPad ? 22 : 18))
                        Text("Cook!")
                            .font(.AppTheme.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.AppTheme.sage)
                    .cornerRadius(12)
                }
                .padding(AppSpacing.md)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.cardCornerRadius)
                .onTapGesture {
                    startCooking(recipe: recipe)
                }
            }
        }
    }

    // MARK: - Almost Ready Section

    var almostReadySection: some View {
        // Recipes where we have the garden veggies but missing some pantry items
        let almostRecipes = GardenRecipes.all.filter { recipe in
            let hasGarden = recipe.canCook(with: gameState.harvestedIngredients)
            let hasFull = recipe.canCookFull(
                harvestedIngredients: gameState.harvestedIngredients,
                pantryInventory: gameState.pantryInventory
            )
            return hasGarden && !hasFull
        }

        return Group {
            if !almostRecipes.isEmpty {
                VStack(alignment: .leading, spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
                    HStack {
                        Image(systemName: "cart.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                        Text("Almost Ready!")
                            .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }

                    ForEach(almostRecipes) { recipe in
                        let missing = recipe.missingPantryItems(from: gameState.pantryInventory)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(recipe.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: isIPad ? 60 : 44, height: isIPad ? 60 : 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.title)
                                        .font(.AppTheme.bodyBold)
                                        .foregroundColor(Color.AppTheme.darkBrown)
                                        .lineLimit(1)

                                    Text("Need: \(missing.map(\.displayName).joined(separator: ", "))")
                                        .font(.AppTheme.caption)
                                        .foregroundColor(Color.AppTheme.terracotta)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Text("Farm Shop")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.AppTheme.goldenWheat)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.AppTheme.goldenWheat.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(AppSpacing.sm)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Recipe Picker Sheet

    var recipePicker: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    let readyRecipes = GardenRecipes.all.filter {
                        $0.canCookFull(
                            harvestedIngredients: gameState.harvestedIngredients,
                            pantryInventory: gameState.pantryInventory
                        )
                    }

                    ForEach(readyRecipes) { recipe in
                        RecipeCardView(recipe: recipe)
                        .onTapGesture {
                            showRecipePicker = false
                            startCooking(recipe: recipe)
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.AppTheme.cream)
            .navigationTitle("Pick a Recipe")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    var ingredientCount: Int {
        gameState.harvestedIngredients.reduce(0) { $0 + $1.quantity }
    }

    var pantryItemCount: Int {
        gameState.pantryInventory.reduce(0) { $0 + $1.quantity }
    }

    var totalIngredientCount: Int {
        ingredientCount + pantryItemCount
    }

    var readyRecipeCount: Int {
        GardenRecipes.all.filter {
            $0.canCookFull(
                harvestedIngredients: gameState.harvestedIngredients,
                pantryInventory: gameState.pantryInventory
            )
        }.count
    }

    var kitchenHint: String {
        switch cookingPhase {
        case .gatherPantry: return "Tap the pantry to grab ingredients!"
        case .moveToStove: return "Tap the counter to move to stove!"
        case .stoveReady: return "Tap the stove to start cooking!"
        default:
            if readyRecipeCount > 0 {
                return "Tap the stove to start cooking!"
            } else if ingredientCount > 0 {
                return "Almost ready! Get more ingredients to cook."
            } else {
                return "Tap around to explore the kitchen!"
            }
        }
    }
}

// MARK: - Pip Kitchen Message

struct PipKitchenMessage: View {
    let pose: PipPose
    let message: String

    @State private var messageVisible = true
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            PipWavingAnimatedView(size: AdaptiveCardSize.pipMessage(for: sizeClass))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Chef Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.goldenWheat)

                Text(message)
                    .font(sizeClass == .compact ? .AppTheme.body : .AppTheme.title3)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .opacity(messageVisible ? 1 : 0)
            }
            .padding(sizeClass == .compact ? AppSpacing.md : AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .onChange(of: message) { _, _ in
            withAnimation(.easeOut(duration: 0.1)) {
                messageVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeIn(duration: 0.2)) {
                    messageVisible = true
                }
            }
        }
    }
}

// MARK: - Pantry Staple Item

struct PantryStapleItem: View {
    let stock: PantryStock
    var isIPad: Bool = false

    private var badgeWidth: CGFloat { isIPad ? 110 : 70 }

    var body: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            Image(stock.item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: isIPad ? 40 : 30, height: isIPad ? 40 : 30)
            Text(stock.item.displayName)
                .font(.system(size: isIPad ? 13 : 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)
            Text("x\(stock.quantity)")
                .font(isIPad ? .AppTheme.body : .AppTheme.caption)
                .foregroundColor(Color.AppTheme.goldenWheat)
                .fontWeight(.bold)
        }
        .frame(width: badgeWidth)
        .padding(isIPad ? AppSpacing.md : AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(isIPad ? 16 : 12)
    }
}

// MARK: - Preview

#Preview {
    KitchenView()
        .environmentObject(GameState.preview)
}
