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
    @Binding var selectedTab: MainTabView.Tab
    @EnvironmentObject var gameState: GameState
    @Environment(\.horizontalSizeClass) var sizeClass

    private var isIPad: Bool { sizeClass != .compact }

    // Pip message
    @State private var pipMessage = "Welcome to my kitchen! Tap around to explore!"
    @State private var pipPose: PipPose = .cooking

    // Browse mode
    @State private var showRecipePicker = false
    @State private var showRecipeList = false
    @State private var showTodaysRecipe = false

    // Cooking mode
    @State private var cookingPhase: KitchenCookingPhase = .browsing
    @State private var cookingRecipe: Recipe? = nil
    @State private var pantryItemsNeeded: [PantryItem] = []
    @State private var currentPantryIndex: Int = 0
    @State private var itemsOnCounter: [String] = []   // image names gathered
    @State private var itemsOnStove: Bool = false
    @State private var stoveFlameOn: Bool = false

    // Allergen warning
    @State private var showAllergenWarning = false
    @State private var pendingAllergenRecipe: Recipe? = nil

    // Flying animation
    @State private var flyingImage: String? = nil
    @State private var flyingPosition: CGPoint = .zero
    @State private var flyingScale: CGFloat = 1.0
    @State private var flyingOpacity: Double = 1.0

    // Spot pulsing
    @State private var spotPulse: Bool = false

    // Mini-game
    @State private var showMiniGame: Bool = false

    // Cancellable cooking tasks.
    // Each gather/move/stove step schedules delayed follow-ups; we hold the
    // handles here so we can cancel them when the user hits the X, switches
    // tabs, or the view is dismissed mid-animation. Prevents zombie state
    // mutations from running after the view has gone away.
    @State private var cookingTasks: [Task<Void, Never>] = []

    // Pip — single, walks across kitchen, bubble anchored beside him
    @StateObject private var pipEngine = WalkEngine(frameSet: .pipWalking)
    @State private var showAskPip = false
    @State private var showPipBubble = false   // closed until Pip is tapped or a cooking step speaks

    // ==========================================
    // SCENE EDITOR
    // ==========================================
    @State private var editMode = false

    @State private var sceneItems: [SceneItem] = [
        SceneItem(id: "counter", label: "Counter", icon: "🍽️", xPercent: 0.34, yPercent: 0.68),
        SceneItem(id: "stove", label: "Stove", icon: "🔥", xPercent: 0.88, yPercent: 0.68),
        SceneItem(id: "pantry", label: "Pantry", icon: "📦", xPercent: 0.45, yPercent: 0.78),
        SceneItem(id: "pip", label: "Pip", icon: "🦔", xPercent: 0.71, yPercent: 0.90),
        SceneItem(id: "today", label: "Today's Recipe", icon: "📜", xPercent: 0.20, yPercent: 0.89),
        SceneItem(id: "signpost", label: "Signpost", icon: "🪧", xPercent: 0.86, yPercent: 0.99),
    ]

    var body: some View {
        // C11: NavigationStack (iOS 16+) replaces deprecated NavigationView.
        NavigationStack {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width

                ZStack {
                    Color.AppTheme.cream
                        .ignoresSafeArea()

                    // The kitchen map uses .aspectRatio(.fit) so its height is
                    // derived from the image's native ratio — forcing a height
                    // would shrink the picture into a tiny centered box on iPad
                    // landscape. Keep the whole screen scrollable so the map
                    // renders at full width and the bottom panel flows below.
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            kitchenHeader
                                .padding(.top, AppSpacing.sm)
                                .padding(.bottom, AppSpacing.sm)

                            kitchenMapSection(screenWidth: screenWidth)

                            bottomPanel
                                .padding(.top, AppSpacing.md)

                            Spacer(minLength: AppSpacing.xxl * 2)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        // C5: lift the spot-pulse animation to the outer root.
        // Previous: .onAppear lived inside kitchenSpot → fired 3× per kitchen load,
        // each call triggered .repeatForever on the same @State, stacking drivers.
        // Now fires once when the view first appears.
        .onAppear {
            withAnimation(AnimationConstants.pipTransition.repeatForever(autoreverses: true)) {
                spotPulse = true
            }
            // A player who has finished a dish already knows pantry → counter → stove.
            if !gameState.recipeStars.isEmpty {
                PipTutorial.kitchenCooking.markDone(for: gameState.activeProfileID)
            }
            if let aiRecipe = gameState.pendingAIRecipe {
                gameState.pendingAIRecipe = nil
                cookingRecipe = aiRecipe
                showMiniGame = true
            }
        }
        // C6: cancel any in-flight cooking Tasks when leaving the Kitchen.
        // Prevents a 1-second-delayed `showMiniGame = true` firing after the
        // user already switched to a different tab.
        .onDisappear {
            cancelCookingTasks()
        }
        .sheet(isPresented: $showRecipePicker) {
            recipePicker
                .environmentObject(gameState)
        }
        .sheet(isPresented: $showRecipeList) {
            NavigationStack {
                RecipeListView(selectedTab: .constant(.kitchen))
                    .environmentObject(gameState)
                    .ensureAssetPacks(.recipes)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showRecipeList = false }
                                .foregroundColor(Color.AppTheme.sage)
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showMiniGame) {
            if let recipe = cookingRecipe {
                CookingSessionView(recipe: recipe)
                    .environmentObject(gameState)
            }
        }
        .sheet(isPresented: $showAskPip) {
            AskPipView()
                .environmentObject(gameState)
        }
        // "Let's Cook!" dismisses the sheet first, then this closure runs.
        .sheet(isPresented: $showTodaysRecipe) {
            RecipeDetailView(
                recipe: todaysRecipe,
                onStartCooking: { cookTodaysRecipe() },
                childAllergens: gameState.activeAllergens
            )
            .ensureAssetPacks(.recipes)
        }
        .onChange(of: gameState.pendingAIRecipe) { _, newRecipe in
            if let aiRecipe = newRecipe {
                gameState.pendingAIRecipe = nil
                cookingRecipe = aiRecipe
                showMiniGame = true
            }
        }
        .onChange(of: showMiniGame) { _, showing in
            if !showing {
                resetCookingMode()
            }
        }
        .alert("Allergen Warning", isPresented: $showAllergenWarning) {
            Button("A grown-up says it's OK!") {
                if let recipe = pendingAllergenRecipe {
                    pendingAllergenRecipe = nil
                    proceedWithCooking(recipe: recipe)
                }
            }
            Button("Pick a different recipe", role: .cancel) {
                pendingAllergenRecipe = nil
            }
        } message: {
            if let recipe = pendingAllergenRecipe {
                let names = recipe.matchingAllergens(gameState.activeAllergens).map(\.displayName).joined(separator: " and ")
                Text("Hold on! This recipe has \(names) in it. Ask a grown-up if it's OK to cook this one!")
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

            // Recipe Book button
            Button(action: { showRecipeList = true }) {
                Image(systemName: "book.fill")
                    .font(.AppTheme.rounded(size: AdaptiveCardSize.kitchenHeaderIconSize(for: sizeClass)))
                    .foregroundColor(Color.AppTheme.goldenWheat)
            }
            .buttonStyle(.plain)

            #if DEBUG
            Button {
                withAnimation(AnimationConstants.springMedium) {
                    editMode.toggle()
                }
            } label: {
                Image(systemName: editMode ? "pencil.circle.fill" : "pencil.circle")
                    .font(.AppTheme.rounded(size: AdaptiveCardSize.kitchenHeaderIconSize(for: sizeClass)))
                    .foregroundColor(editMode ? Color.AppTheme.terracotta : Color.AppTheme.lightSepia)
            }
            .buttonStyle(.plain)
            #endif

            // Cancel cooking button
            if cookingPhase != .browsing {
                Button {
                    resetCookingMode()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.AppTheme.rounded(size: AdaptiveCardSize.kitchenHeaderIconSize(for: sizeClass)))
                        .foregroundColor(Color.AppTheme.terracotta)
                }
            }

            // Coin display
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "circle.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                    .font(.AppTheme.rounded(size: isIPad ? 18 : 14))
                Text("\(gameState.coins)")
                    .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, isIPad ? AppSpacing.md : AppSpacing.sm)
            .padding(.vertical, isIPad ? AppSpacing.sm : AppSpacing.xs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(AppSpacing.largeCornerRadius)
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

                        // MARK: Today's Recipe Easel
                        // A cut-out prop standing on the floor. The "today" scene
                        // point is where its feet touch, so it's lifted by half its height.
                        if cookingPhase == .browsing {
                            let propHeight = AdaptiveCardSize.kitchenTodayProp(for: sizeClass)
                            let feet = pos(for: "today", w: w, h: h)
                            Button { showTodaysRecipe = true } label: {
                                Image("todays_recipe_icon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: propHeight)
                                    .overlay(alignment: .bottom) {
                                        Text("Today's Recipe")
                                            .font(.AppTheme.rounded(size: AdaptiveCardSize.kitchenSpotLabelSize(for: sizeClass), weight: .semibold))
                                            .foregroundColor(Color.AppTheme.darkBrown)
                                            .padding(.horizontal, AppSpacing.xs)
                                            .padding(.vertical, AppSpacing.xxs)
                                            .background(Color.AppTheme.warmCream.opacity(0.9))
                                            .cornerRadius(AppSpacing.pillCornerRadius)
                                    }
                            }
                            .buttonStyle(BouncyButtonStyle())
                            .position(x: feet.x, y: feet.y - propHeight / 2)
                        }

                        // MARK: Signpost — the way to the other places
                        if cookingPhase == .browsing {
                            let postHeight = AdaptiveCardSize.signpostHeight(for: sizeClass)
                            let postFoot = pos(for: "signpost", w: w, h: h)
                            StationSignpostView(destinations: [.home, .garden, .shop], selectedTab: $selectedTab)
                                .position(x: postFoot.x, y: postFoot.y - postHeight / 2)
                        }

                        // Items gathered on counter (small images near counter)
                        if !itemsOnCounter.isEmpty {
                            let gatheredSize = AdaptiveCardSize.kitchenGatheredItem(for: sizeClass)
                            HStack(spacing: AppSpacing.xxs / 2) {
                                ForEach(itemsOnCounter.indices, id: \.self) { i in
                                    Image(itemsOnCounter[i])
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: gatheredSize, height: gatheredSize)
                                }
                            }
                            .padding(AppSpacing.xxs)
                            .background(Color.AppTheme.warmCream.opacity(0.85))
                            .cornerRadius(AppSpacing.pillCornerRadius)
                            .position(x: counterPos.x, y: counterPos.y - AppSpacing.xl)
                        }

                        // Items on stove indicator
                        if itemsOnStove {
                            Image(systemName: stoveFlameOn ? "flame.fill" : "frying.pan.fill")
                                .font(.AppTheme.title3)
                                .foregroundColor(stoveFlameOn ? Color.AppTheme.terracotta : Color.AppTheme.goldenWheat)
                                .position(x: stovePos.x, y: stovePos.y - AppSpacing.xl)
                        }

                        // Pip — walks along the floor, bubble anchored to his side
                        let pipFrameSize = AdaptiveCardSize.pipKitchenWalking(for: sizeClass)
                        TimelineView(.animation) { context in
                            let _ = pipEngine.update(now: context.date)

                            // Tap Pip to open his bubble. The tap and the tag sit
                            // before .position so only Pip himself is tappable.
                            pipSprite(frameSize: pipFrameSize)
                                .contentShape(Rectangle())
                                .pipTapMeTag(isShown: !showPipBubble)
                                .onTapGesture { showPipBubble = true }
                                .position(pipSpriteCenter(frameSize: pipFrameSize))
                        }
                        // C9: lifecycle hooks live on the always-present Pip (the
                        // bubble comes and goes). The closures capture w/h from the
                        // enclosing GeometryReader.
                        // The map's first layout pass reports a smaller size than the
                        // final one, so placing Pip once on appear left him up on the
                        // shelves. Re-place him at home whenever the size changes while idle.
                        .onChange(of: CGSize(width: w, height: h), initial: true) { _, _ in
                            if cookingPhase == .browsing && !pipEngine.isMoving {
                                pipEngine.position = pos(for: "pip", w: w, h: h)
                            }
                        }
                        .onChange(of: cookingPhase) { _, newPhase in
                            walkPipForPhase(newPhase, w: w, h: h)
                        }
                        // On a player's first cook, each step pops the bubble open
                        // so they learn the flow. After that it waits for a tap.
                        .onChange(of: pipMessage) { _, _ in
                            if cookingPhase != .browsing
                                && !PipTutorial.kitchenCooking.isDone(for: gameState.activeProfileID) {
                                showPipBubble = true
                            }
                        }

                        if showPipBubble {
                            PipFloatingBubble(
                                anchor: CGPoint(x: pipEngine.position.x, y: pipFeetY(frameSize: pipFrameSize)),
                                sceneWidth: w,
                                pipHalfWidth: pipFrameSize / 2,
                                sizeClass: sizeClass,
                                message: pipMessage,
                                onAskPip: { showAskPip = true },
                                onClose: { showPipBubble = false },
                                bottomAligned: true
                            )
                        }

                        // MARK: Flying Item
                        if let img = flyingImage {
                            let flyingSize = AdaptiveCardSize.kitchenFlyingItem(for: sizeClass)
                            Image(img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: flyingSize, height: flyingSize)
                                .scaleEffect(flyingScale)
                                .opacity(flyingOpacity)
                                .position(flyingPosition)
                        }
                    }
                }
            )
    }

    // MARK: - Pip Walking

    // How much of its square frame the walk art fills, and how far his feet sit
    // above the frame's bottom (same art as the Home map walker).
    private static let walkArtFill: CGFloat = 0.625
    private static let walkArtFoot: CGFloat = 0.18

    /// Where Pip's feet touch the floor, from the center of his walk frame.
    private func pipFeetY(frameSize: CGFloat) -> CGFloat {
        pipEngine.position.y + frameSize * (0.5 - Self.walkArtFoot)
    }

    /// Standing at a station during cooking, Pip points up at it.
    private var pipIsPointing: Bool {
        !pipEngine.isMoving && cookingPhase != .browsing
    }

    /// The walk frame, or the pointing pose at a station. The pointing art fills
    /// its whole image, so it's drawn at the walker's visible height.
    @ViewBuilder
    private func pipSprite(frameSize: CGFloat) -> some View {
        if pipIsPointing {
            Image(PipPose.pointsUpRight.rawValue)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: frameSize * Self.walkArtFill)
                .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 4, x: 0, y: 3)
        } else {
            Image(currentPipFrame)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: frameSize, height: frameSize)
                .scaleEffect(x: pipEngine.facingRight ? 1 : -1, y: 1)
                .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 4, x: 0, y: 3)
        }
    }

    /// The pointing pose is shorter than the walk frame, so its center sits
    /// higher to keep the feet on the same floor spot.
    private func pipSpriteCenter(frameSize: CGFloat) -> CGPoint {
        guard pipIsPointing else { return pipEngine.position }
        let pointHeight = frameSize * Self.walkArtFill
        return CGPoint(x: pipEngine.position.x, y: pipFeetY(frameSize: frameSize) - pointHeight / 2)
    }

    private var currentPipFrame: String {
        if pipEngine.isMoving {
            let names = CharacterFrameSet.pipWalking.frameNames
            let i = pipEngine.currentFrameIndex
            return (i >= 0 && i < names.count) ? names[i] : names[0]
        }
        return "pip_cooking"   // idle pose when not walking
    }

    private func walkPipForPhase(_ phase: KitchenCookingPhase, w: CGFloat, h: CGFloat) {
        let home = pos(for: "pip", w: w, h: h)
        let target: CGPoint
        switch phase {
        case .browsing:     target = home
        case .gatherPantry: target = floorSpot(below: "pantry", floorY: home.y, w: w, h: h)
        case .moveToStove:  target = floorSpot(below: "counter", floorY: home.y, w: w, h: h)
        case .stoveReady:   target = floorSpot(below: "stove", floorY: home.y, w: w, h: h)
        }
        pipEngine.start(waypoints: [pipEngine.position, target], loop: false)
    }

    /// Pip stays on the floor (his home height) and stops just left of a station,
    /// under it, so he can point up at it without covering its button.
    private func floorSpot(below id: String, floorY: CGFloat, w: CGFloat, h: CGFloat) -> CGPoint {
        let station = pos(for: id, w: w, h: h)
        return CGPoint(x: station.x - AdaptiveCardSize.kitchenPipStationGap(for: sizeClass), y: floorY)
    }

    // MARK: - Kitchen Spot

    func kitchenSpot(icon: String, label: String, color: Color, badgeCount: Int, isPulsing: Bool = false, action: @escaping () -> Void) -> some View {
        let ringSize = AdaptiveCardSize.kitchenSpotRing(for: sizeClass)
        let innerSize = AdaptiveCardSize.kitchenSpotInner(for: sizeClass)
        let iconSize = AdaptiveCardSize.kitchenSpotIcon(for: sizeClass)
        let badgeFontSize = AdaptiveCardSize.kitchenBadgeFontSize(for: sizeClass)
        let badgeOffset = AdaptiveCardSize.kitchenBadgeOffset(for: sizeClass)
        let labelSize = AdaptiveCardSize.kitchenSpotLabelSize(for: sizeClass)

        // C7: collapsed double-circle into a single filled circle + stroke overlay.
        // Saves ~6 layers per spot × 3 spots on the GPU composite pass. Visually
        // indistinguishable at kid-play distances.
        return Button(action: action) {
            VStack(spacing: AppSpacing.xxs) {
                Circle()
                    .fill(Color.AppTheme.warmCream.opacity(0.9))
                    .frame(width: innerSize, height: innerSize)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: (ringSize - innerSize) / 2)
                            .frame(width: ringSize, height: ringSize)
                    )
                    .scaleEffect(isPulsing && spotPulse ? 1.3 : 1.0)
                    .overlay(
                        Image(systemName: icon)
                            .font(.AppTheme.rounded(size: iconSize))
                            .foregroundColor(color)
                    )
                    .overlay(alignment: .topTrailing) {
                        if badgeCount > 0 {
                            Text("\(badgeCount)")
                                .font(.AppTheme.rounded(size: badgeFontSize, weight: .bold))
                                .foregroundColor(Color.AppTheme.cream)
                                .padding(AppSpacing.xxs)
                                .background(color)
                                .clipShape(Circle())
                                .offset(x: badgeOffset - innerSize / 2, y: -badgeOffset + innerSize / 2)
                        }
                    }

                Text(label)
                    .font(.AppTheme.rounded(size: labelSize, weight: .semibold))
                    .foregroundColor(isPulsing ? color : Color.AppTheme.darkBrown)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs - 1)
                    .background(isPulsing ? color.opacity(0.15) : Color.AppTheme.warmCream.opacity(0.9))
                    .cornerRadius(AppSpacing.pillCornerRadius)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Spot Actions

    private func handlePantryTap(pantryPos: CGPoint, counterPos: CGPoint) {
        switch cookingPhase {
        case .gatherPantry:
            gatherNextItem(pantryPos: pantryPos, counterPos: counterPos)
        default:
            // Browse mode — just show message
            withAnimation(AnimationConstants.springMedium) {
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
            withAnimation(AnimationConstants.springMedium) {
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
            withAnimation(AnimationConstants.springMedium) {
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

    // MARK: - Today's Recipe

    /// Changes once a day and cycles through every recipe.
    private var todaysRecipe: Recipe {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return GardenRecipes.all[day % GardenRecipes.all.count]
    }

    private func cookTodaysRecipe() {
        let recipe = todaysRecipe
        if recipe.canCookFull(
            harvestedIngredients: gameState.harvestedIngredients,
            pantryInventory: gameState.pantryInventory
        ) {
            startCooking(recipe: recipe)
        } else {
            withAnimation(AnimationConstants.springMedium) {
                pipPose = .thinking
                pipMessage = "We need more ingredients for \(recipe.title)! Let's visit the garden and the farm shop."
            }
        }
    }

    // MARK: - Cooking Flow

    func startCooking(recipe: Recipe) {
        // Check for allergens first
        let matching = recipe.matchingAllergens(gameState.activeAllergens)
        if !matching.isEmpty {
            pendingAllergenRecipe = recipe
            showAllergenWarning = true
            return
        }
        proceedWithCooking(recipe: recipe)
    }

    private func proceedWithCooking(recipe: Recipe) {
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

        withAnimation(AnimationConstants.springFly) {
            flyingPosition = counterPos
            flyingScale = 0.7
        }

        // Phase A — fade the flying image, drop it onto the counter stack.
        // Hops to MainActor because we mutate @State from async context.
        cookingTasks.append(Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.itemFlyDelay))
            guard !Task.isCancelled else { return }
            withAnimation(AnimationConstants.fadeFlyOut) {
                flyingOpacity = 0
            }
            withAnimation(AnimationConstants.springMedium) {
                itemsOnCounter.append(item.imageName)
            }
        })

        // Phase B — advance the step, update Pip's prompt.
        cookingTasks.append(Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.itemFlyCleanup))
            guard !Task.isCancelled else { return }
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
        })
    }

    private func moveItemsToStove(counterPos: CGPoint, stovePos: CGPoint) {
        guard flyingImage == nil else { return }

        // Fly first item image as representative
        flyingImage = itemsOnCounter.first ?? "farm_salt"
        flyingPosition = counterPos
        flyingScale = 1.0
        flyingOpacity = 1.0

        withAnimation(AnimationConstants.springFly) {
            flyingPosition = stovePos
            flyingScale = 0.7
        }

        cookingTasks.append(Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.itemFlyDelay))
            guard !Task.isCancelled else { return }
            withAnimation {
                flyingOpacity = 0
                itemsOnCounter = []
                itemsOnStove = true
            }
        })

        cookingTasks.append(Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.itemFlyCleanup))
            guard !Task.isCancelled else { return }
            flyingImage = nil
            cookingPhase = .stoveReady
            pipMessage = "Everything's on the stove! Tap it to start cooking!"
            pipPose = .excited
        })
    }

    private func activateStove() {
        stoveFlameOn = true
        pipMessage = "The stove is on! Let's cook!"
        pipPose = .celebrating
        // Reaching the stove means the kid has done pantry → counter → stove once.
        PipTutorial.kitchenCooking.markDone(for: gameState.activeProfileID)

        cookingTasks.append(Task { @MainActor in
            try? await Task.sleep(for: .seconds(AnimationConstants.stovePreRoll))
            guard !Task.isCancelled else { return }
            showMiniGame = true
        })
    }

    private func cancelCookingTasks() {
        for task in cookingTasks { task.cancel() }
        cookingTasks.removeAll()
    }

    private func resetCookingMode() {
        cancelCookingTasks()
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
        showPipBubble = false
    }

    // MARK: - Bottom Panel

    var bottomPanel: some View {
        // LazyVStack: rows below the fold don't materialize until scrolled into view.
        // Recipe rows use images + multiple layers each — lazy = big layer-count win.
        LazyVStack(spacing: AppSpacing.md) {
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
                if hasAlmostReadyRecipes {
                    almostReadySection
                        .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
                }
            }
        }
    }

    /// Gate for almostReadySection — computed here so the caller can skip
    /// rendering the section entirely (instead of wrapping it in Group{ if ... }
    /// which still creates a container layer when the branch is empty).
    private var hasAlmostReadyRecipes: Bool {
        GardenRecipes.all.contains { recipe in
            recipe.canCook(with: gameState.harvestedIngredients)
            && !recipe.canCookFull(
                harvestedIngredients: gameState.harvestedIngredients,
                pantryInventory: gameState.pantryInventory
            )
        }
    }

    // MARK: - Cooking Banner

    private func cookingBanner(recipe: Recipe) -> some View {
        HStack(spacing: AppSpacing.md) {
            AssetPackImage(recipe.imageName, in: .recipes)
                .scaledToFill()
                .frame(width: AppSpacing.largeIconSize, height: AppSpacing.largeIconSize)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.smallCornerRadius))

            VStack(alignment: .leading, spacing: AppSpacing.xxs / 2) {
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
                let readySize = AdaptiveCardSize.kitchenReadyImage(for: sizeClass)
                HStack(spacing: AppSpacing.md) {
                    AssetPackImage(recipe.imageName, in: .recipes)
                        .scaledToFill()
                        .frame(width: readySize, height: readySize)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.smallCornerRadius))

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
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

                    VStack(spacing: AppSpacing.xxs / 2) {
                        Image(systemName: "flame.fill")
                            .font(.AppTheme.rounded(size: isIPad ? 22 : 18))
                        Text("Cook!")
                            .font(.AppTheme.caption)
                    }
                    .foregroundColor(Color.AppTheme.cream)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.AppTheme.sage)
                    .cornerRadius(AppSpacing.smallCornerRadius)
                }
                .softCard(showShadow: false)
                .onTapGesture {
                    startCooking(recipe: recipe)
                }
            }
        }
    }

    // MARK: - Almost Ready Section

    // Caller gates this on `hasAlmostReadyRecipes` — so when we get here we
    // know the filter is non-empty. No more Group{} wrapper around the if.
    var almostReadySection: some View {
        let almostRecipes = GardenRecipes.all.filter { recipe in
            let hasGarden = recipe.canCook(with: gameState.harvestedIngredients)
            let hasFull = recipe.canCookFull(
                harvestedIngredients: gameState.harvestedIngredients,
                pantryInventory: gameState.pantryInventory
            )
            return hasGarden && !hasFull
        }

        return VStack(alignment: .leading, spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                Text("Almost Ready!")
                    .font(isIPad ? .AppTheme.title3 : .AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }

            ForEach(almostRecipes) { recipe in
                        let missing = recipe.missingPantryItems(from: gameState.pantryInventory)
                        let almostSize = AdaptiveCardSize.kitchenAlmostImage(for: sizeClass)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: AppSpacing.sm) {
                                AssetPackImage(recipe.imageName, in: .recipes)
                                    .scaledToFill()
                                    .frame(width: almostSize, height: almostSize)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.pillCornerRadius))

                                VStack(alignment: .leading, spacing: AppSpacing.xxs / 2) {
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
                                    .font(.AppTheme.rounded(size: 10, weight: .semibold))
                                    .foregroundColor(Color.AppTheme.goldenWheat)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, AppSpacing.xxs)
                                    .background(Color.AppTheme.goldenWheat.opacity(0.15))
                                    .cornerRadius(AppSpacing.pillCornerRadius)
                            }
                        }
                .padding(AppSpacing.sm)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.smallCornerRadius)
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


// MARK: - Pantry Staple Item

struct PantryStapleItem: View {
    let stock: PantryStock
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isIPad: Bool { sizeClass != .compact }

    var body: some View {
        let imageSize = AdaptiveCardSize.pantryBadgeImage(for: sizeClass)
        let labelSize = AdaptiveCardSize.pantryBadgeLabelSize(for: sizeClass)
        let width = AdaptiveCardSize.pantryBadgeWidth(for: sizeClass)

        return VStack(spacing: isIPad ? AppSpacing.xxs + 2 : AppSpacing.xxs) {
            Image(stock.item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
            Text(stock.item.displayName)
                .font(.AppTheme.rounded(size: labelSize, weight: .medium))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)
            Text("x\(stock.quantity)")
                .font(isIPad ? .AppTheme.body : .AppTheme.caption)
                .foregroundColor(Color.AppTheme.goldenWheat)
                .fontWeight(.bold)
        }
        .frame(width: width)
        .padding(isIPad ? AppSpacing.md : AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(isIPad ? AppSpacing.cardCornerRadius : AppSpacing.smallCornerRadius)
    }
}

// MARK: - Pip Floating Bubble
//
// Speech bubble that floats beside the walking Pip.
// Auto-flips to the opposite side when Pip is past the scene midpoint
// so the bubble never spills off the edge of the kitchen map.
// Also used by the Home map (no Ask Pip button there: pass nil).

struct PipFloatingBubble: View {
    let anchor: CGPoint
    let sceneWidth: CGFloat
    let pipHalfWidth: CGFloat
    let sizeClass: UserInterfaceSizeClass?
    let message: String
    var onAskPip: (() -> Void)? = nil
    /// Shows an ✕ that closes the bubble (the scene reopens it when Pip is tapped).
    var onClose: (() -> Void)? = nil
    /// When true, `anchor.y` is the bubble's bottom edge (Pip's feet) and the
    /// bubble grows upward, so it stays inside a scene where Pip walks the floor.
    var bottomAligned: Bool = false

    // The token width, narrowed when the space beside Pip is smaller (iPhone).
    // softCard adds AppSpacing.md padding on the outer edge, so leave room for it.
    private var bubbleWidth: CGFloat {
        let side = anchorOnLeftHalf ? sceneWidth - anchor.x : anchor.x
        let room = side - pipHalfWidth - gap - AppSpacing.md
        return min(AdaptiveCardSize.pipBubbleWidth(for: sizeClass), room)
    }
    private var gap: CGFloat { AdaptiveSpacing.padding(for: sizeClass) }

    private var anchorOnLeftHalf: Bool { anchor.x < sceneWidth / 2 }

    private var bubbleCenterX: CGFloat {
        // If Pip is on the left half, bubble sits to his right; otherwise to his left.
        let halfBubble = bubbleWidth / 2
        let offset = pipHalfWidth + gap + halfBubble
        return anchorOnLeftHalf ? anchor.x + offset : anchor.x - offset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                Text(message)
                    .font(.AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let onClose {
                    PipBubbleCloseButton(action: onClose)
                }
            }

            if let onAskPip {
                // iPhone: a small pill that hugs its text. iPad: the full-width button.
                let isCompact = sizeClass == .compact
                Button("Ask Pip") { onAskPip() }
                    .buttonStyle(TexturedButtonStyle(
                        tint: Color.AppTheme.sage,
                        height: AdaptiveCardSize.pipBubbleButtonHeight(for: sizeClass),
                        fullWidth: !isCompact,
                        font: isCompact ? .AppTheme.subheadline : .AppTheme.headline
                    ))
            }
        }
        .frame(width: bubbleWidth, alignment: .leading)
        .softCard()
        // A zero-height frame aligned to its bottom puts the card's bottom edge
        // on the anchor; the card overflows upward.
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: bottomAligned ? 0 : nil, alignment: .bottom)
        .position(x: bubbleCenterX, y: anchor.y)
        .animation(AnimationConstants.fadeMedium, value: anchorOnLeftHalf)
        .onAppear { PipVoice.shared.speak(message) }
        .onChange(of: message) { _, new in PipVoice.shared.speak(new) }
    }
}

// MARK: - Preview

#Preview {
    KitchenView(selectedTab: .constant(.kitchen))
        .environmentObject(GameState.preview)
}
