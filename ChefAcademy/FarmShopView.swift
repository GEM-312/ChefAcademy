//
//  FarmShopView.swift
//  ChefAcademy
//
//  The Farm Shop is where players BUY pantry items!
//  Eggs, chicken, butter, cheese, rice, pasta...
//  These are needed alongside garden veggies to cook recipes.
//
//  Part of the game loop: GROW veggies → BUY pantry items → COOK recipes → FEED Body Buddy
//

import SwiftUI

// MARK: - Farm Shop View

struct FarmShopView: View {

    @EnvironmentObject var gameState: GameState
    @State private var selectedCategory: ShopCategory = .all
    @State private var showPurchaseConfirm = false
    @State private var purchasedItemName = ""
    @State private var bounceItem: PantryItem?

    // Filter items by category
    var filteredItems: [PantryItem] {
        if selectedCategory == .all {
            return PantryItem.allCases.map { $0 }
        }
        return PantryItem.allCases.filter { $0.shopCategory == selectedCategory }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.AppTheme.cream
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Header
                        shopHeader
                            .padding(.top, AppSpacing.sm)
                            .padding(.bottom, AppSpacing.sm)

                        // MARK: - Pip's Shop Tip
                        PipShopMessage()
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.md)

                        // MARK: - Category Filter
                        categoryPills
                            .padding(.bottom, AppSpacing.md)

                        // MARK: - Shop Grid
                        shopGrid
                            .padding(.horizontal, AppSpacing.md)

                        // MARK: - My Pantry Section
                        pantrySection
                            .padding(.top, AppSpacing.lg)
                            .padding(.horizontal, AppSpacing.md)

                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // Purchase success popup
        .alert("Purchased! 🛒", isPresented: $showPurchaseConfirm) {
            Button("Yay!", role: .cancel) { }
        } message: {
            Text("You bought \(purchasedItemName)! Check your pantry.")
        }
    }

    // MARK: - Shop Header

    var shopHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Farm Shop")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("Buy ingredients for your recipes!")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
            }

            Spacer()

            // Coin display
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                    .font(.system(size: 14))
                Text("\(gameState.coins)")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(20)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Category Pills

    var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(ShopCategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                            Text(category.rawValue)
                                .font(.AppTheme.caption)
                        }
                        .foregroundColor(
                            selectedCategory == category
                            ? Color.AppTheme.cream
                            : Color.AppTheme.darkBrown
                        )
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            selectedCategory == category
                            ? category.color
                            : Color.AppTheme.parchment
                        )
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Shop Grid

    var shopGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppSpacing.sm),
                GridItem(.flexible(), spacing: AppSpacing.sm),
                GridItem(.flexible(), spacing: AppSpacing.sm)
            ],
            spacing: AppSpacing.md
        ) {
            ForEach(filteredItems) { item in
                ShopItemCard(
                    item: item,
                    ownedQuantity: gameState.pantryQuantity(for: item),
                    canAfford: gameState.coins >= item.shopPrice,
                    isBouncing: bounceItem == item,
                    onBuy: {
                        buyItem(item)
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedCategory)
    }

    // MARK: - My Pantry Section

    var pantrySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("My Pantry")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.darkBrown)

            if gameState.pantryInventory.isEmpty {
                Text("Your pantry is empty! Buy some ingredients above.")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(gameState.pantryInventory) { stock in
                            PantryBadge(stock: stock)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Buy Action

    func buyItem(_ item: PantryItem) {
        if gameState.buyPantryItem(item) {
            purchasedItemName = item.displayName
            // Bounce animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                bounceItem = item
            }
            // Reset bounce after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                bounceItem = nil
            }
            showPurchaseConfirm = true
        }
    }
}

// MARK: - Shop Item Card

struct ShopItemCard: View {
    let item: PantryItem
    let ownedQuantity: Int
    let canAfford: Bool
    let isBouncing: Bool
    let onBuy: () -> Void

    var body: some View {
        Button(action: onBuy) {
            VStack(spacing: AppSpacing.xs) {
                // Farm item illustration
                Image(item.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .opacity(0.8)
                    .scaleEffect(isBouncing ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isBouncing)

                // Item name
                Text(item.displayName)
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)

                // Owned quantity
                if ownedQuantity > 0 {
                    Text("x\(ownedQuantity)")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sepia)
                }

                // Price
                HStack(spacing: 2) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                    Text("\(item.shopPrice)")
                        .font(.system(size: 10))
                }
                .foregroundColor(Color.AppTheme.lightSepia)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .opacity(canAfford ? 1.0 : 0.5)
        .disabled(!canAfford)
    }
}

// MARK: - Pantry Badge (Shows owned items)

struct PantryBadge: View {
    let stock: PantryStock

    var body: some View {
        VStack(spacing: 4) {
            Image(stock.item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)

            Text(stock.item.displayName)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)

            Text("x\(stock.quantity)")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(width: 70)
        .padding(AppSpacing.sm)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(12)
    }
}

// MARK: - Pip Shop Message

struct PipShopMessage: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Animated Pip waving (frame animation, transparent bg)
            PipWavingAnimatedView(size: 120)

            // Message bubble
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.goldenWheat)

                Text(shopTips.randomElement() ?? "Welcome to the farm shop!")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
    }

    let shopTips = [
        "Buy eggs and butter to make an omelette!",
        "You'll need chicken to make stir fry!",
        "Stock up on basics — salt and pepper go in everything!",
        "Check which recipes you can cook with your ingredients!",
        "Grow veggies in the garden, buy the rest here!",
    ]
}

// MARK: - Farm Transition View
/// Pip walks across the bg_farm scene toward the barn, then calls onComplete.
/// Tap anywhere to skip.
///
/// The image is zoomed to ~1.4x and aligned left so the barn dominates the screen.
/// Toggle the pencil icon (DEBUG) to drag waypoints with the Scene Editor.

struct FarmTransitionView: View {
    let onComplete: () -> Void

    // ==========================================
    // TWEAK THESE to adjust the farm camera:
    // ==========================================

    /// How tall the farm scene is vs screen. Bigger = more zoom.
    /// At 0.55 on iPhone, you see roughly the left half of the image (big barn).
    private let sceneHeightRatio: CGFloat = 1.03

    /// Pan the camera left/right. Negative = barn moves left on screen.
    private let panX: CGFloat = -0.73

    /// Pan the camera up/down. Negative = pull image up on screen.
    /// Try -0.1, -0.2, etc. until the ground/fence is where you want it.
    private let panY: CGFloat = -0.15

    // ==========================================

    /// Walking frame asset names
    private let walkingFrames: [String] = (1...15).map {
        String(format: "pip_walking_frame_%02d", $0)
    }

    private let walkSpeed: CGFloat = 2.2
    private let pipSize: CGFloat = 110

    // ==========================================
    // SCENE EDITOR: Pencil icon toggles edit mode.
    // Drag handles to reposition, copy values from Xcode console.
    // ==========================================
    @State private var editMode = false

    /// Waypoints for Pip's walk — positions are % of the VISIBLE area.
    /// Adjust with the Scene Editor (pencil icon, DEBUG builds only).
    @State private var farmSceneItems: [SceneItem] = [
        SceneItem(id: "walk0",  label: "Start",  icon: "1️⃣", xPercent: 0.98, yPercent: 0.66),
        SceneItem(id: "walk1",  label: "Mid 1",  icon: "2️⃣", xPercent: 0.70, yPercent: 0.57),
        SceneItem(id: "walk2",  label: "Mid 2",  icon: "3️⃣", xPercent: 0.40, yPercent: 0.58),
        SceneItem(id: "walk3",  label: "Barn",   icon: "4️⃣", xPercent: 0.21, yPercent: 0.51),
    ]

    @State private var pipPosition: CGPoint = .zero
    @State private var walkingFrameIndex: Int = 0
    @State private var tickCounter: Int = 0
    @State private var currentSegment: Int = 0
    @State private var segmentProgress: CGFloat = 0.0
    @State private var walkTimer: Timer? = nil
    @State private var hasCompleted: Bool = false

    var body: some View {
        GeometryReader { screen in
            let sceneWidth = screen.size.width
            let sceneHeight = screen.size.height * sceneHeightRatio

            ZStack {
                Color.AppTheme.cream
                    .ignoresSafeArea()

                // Farm image — .fill + .leading crops to show the big barn on the left.
                // panX shifts the viewport: negative = barn moves left on screen.
                Image("bg_farm")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .offset(x: sceneWidth * panX, y: sceneHeight * panY)
                    .frame(width: sceneWidth, height: sceneHeight, alignment: .leading)
                    .clipped()
                    .opacity(0.6)
                    .position(x: sceneWidth / 2, y: screen.size.height / 2)
                    // Tap-to-skip lives on the image only (not the pencil button)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !editMode { skip() }
                    }

                // Pip + Basket + Scene Editor — same frame, centered on screen
                ZStack {
                    if editMode {
                        SceneEditorOverlay(
                            mapWidth: sceneWidth,
                            mapHeight: sceneHeight,
                            items: $farmSceneItems,
                            editMode: true
                        )
                    } else {
                        // Walking Pip
                        Image(walkingFrames[walkingFrameIndex])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: pipSize, height: pipSize)
                            .scaleEffect(x: -1, y: 1) // Face left
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 3)
                            .position(pipPosition)
                    }
                }
                .frame(width: sceneWidth, height: sceneHeight)
                .position(x: sceneWidth / 2, y: screen.size.height / 2)
                .allowsHitTesting(editMode) // Only intercept drags in edit mode

                // Pencil toggle — sits ABOVE everything, not affected by tap-to-skip
                #if DEBUG
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            if !editMode {
                                // Entering edit: pause walk
                                walkTimer?.invalidate()
                                walkTimer = nil
                            } else {
                                // Leaving edit: restart walk from beginning
                                hasCompleted = false
                                let start = farmSceneItems[0]
                                pipPosition = CGPoint(x: sceneWidth * start.xPercent, y: sceneHeight * start.yPercent)
                                startWalking(mapWidth: sceneWidth, mapHeight: sceneHeight)
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                editMode.toggle()
                            }
                        } label: {
                            Image(systemName: editMode ? "pencil.circle.fill" : "pencil.circle")
                                .font(.system(size: 28))
                                .foregroundColor(editMode ? .red : .white)
                                .shadow(color: .black.opacity(0.5), radius: 4)
                                .padding(AppSpacing.md)
                        }
                    }
                    Spacer()
                }
                #endif

                // "Tap to skip" hint
                if !editMode && !hasCompleted {
                    VStack {
                        Spacer()
                        Text("Tap to skip")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sepia.opacity(0.6))
                            .padding(.bottom, 100)
                    }
                }
            }
            .onAppear {
                let start = farmSceneItems[0]
                pipPosition = CGPoint(x: sceneWidth * start.xPercent, y: sceneHeight * start.yPercent)
                startWalking(mapWidth: sceneWidth, mapHeight: sceneHeight)
            }
        }
        .onDisappear {
            walkTimer?.invalidate()
            walkTimer = nil
        }
    }

    private func startWalking(mapWidth w: CGFloat, mapHeight h: CGFloat) {
        let waypoints = farmSceneItems
        guard waypoints.count >= 2 else { return }

        currentSegment = 0
        segmentProgress = 0.0

        walkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            let waypoints = farmSceneItems
            guard currentSegment < waypoints.count - 1 else {
                complete()
                return
            }

            let from = waypoints[currentSegment]
            let to = waypoints[currentSegment + 1]

            let fromPt = CGPoint(x: w * from.xPercent, y: h * from.yPercent)
            let toPt = CGPoint(x: w * to.xPercent, y: h * to.yPercent)

            let dx = toPt.x - fromPt.x
            let dy = toPt.y - fromPt.y
            let segmentLength = sqrt(dx * dx + dy * dy)
            guard segmentLength > 0 else { return }

            let progressPerTick = walkSpeed / segmentLength
            segmentProgress += progressPerTick

            if segmentProgress >= 1.0 {
                currentSegment += 1
                segmentProgress = 0.0

                if currentSegment >= waypoints.count - 1 {
                    let final = waypoints[waypoints.count - 1]
                    pipPosition = CGPoint(x: w * final.xPercent, y: h * final.yPercent)
                    complete()
                    return
                }
            }

            // Interpolate current position
            let curFrom = waypoints[currentSegment]
            let curTo = waypoints[min(currentSegment + 1, waypoints.count - 1)]
            let cfPt = CGPoint(x: w * curFrom.xPercent, y: h * curFrom.yPercent)
            let ctPt = CGPoint(x: w * curTo.xPercent, y: h * curTo.yPercent)

            pipPosition = CGPoint(
                x: cfPt.x + (ctPt.x - cfPt.x) * segmentProgress,
                y: cfPt.y + (ctPt.y - cfPt.y) * segmentProgress
            )

            // Advance walking frame every 4 ticks (~8fps at 30fps timer)
            tickCounter += 1
            if tickCounter >= 4 {
                tickCounter = 0
                walkingFrameIndex = (walkingFrameIndex + 1) % walkingFrames.count
            }
        }
    }

    private func skip() {
        complete()
    }

    private func complete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        walkTimer?.invalidate()
        walkTimer = nil
        onComplete()
    }
}

// MARK: - Basket with Veggies
/// Shows harvested veggies peeking out of the basket.
/// Veggies sit BEHIND the basket rim (lower z-index), creating the illusion
/// that they're inside the basket.

struct BasketWithVeggiesView: View {
    let harvestedIngredients: [HarvestedIngredient]
    let basketSize: CGFloat

    /// Veggie image size — smaller than basket so they peek out
    private var veggieSize: CGFloat { basketSize * 0.30 }

    /// Offsets for up to 5 veggies arranged in an arc inside the basket bowl.
    /// The basket image has white space above — the actual bowl is in the bottom half.
    /// Positive y = further down toward the bowl.
    private var veggieOffsets: [(x: CGFloat, y: CGFloat)] {
        let s = basketSize
        return [
            (x: -s * 0.15, y:  s * 0.12),  // left
            (x: -s * 0.05, y:  s * 0.08),  // center-left
            (x:  s * 0.06, y:  s * 0.07),  // center
            (x:  s * 0.16, y:  s * 0.10),  // center-right
            (x:  s * 0.25, y:  s * 0.14),  // right
        ]
    }

    var body: some View {
        ZStack {
            // Veggies BEHIND the basket (lower z-index)
            ForEach(Array(harvestedIngredients.prefix(5).enumerated()), id: \.element.id) { index, ingredient in
                let offset = veggieOffsets[index]
                Image(ingredient.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: veggieSize, height: veggieSize)
                    .offset(x: offset.x, y: offset.y)
            }

            // Basket on top — rim covers the bottom of the veggies
            Image("vegetable_basket")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: basketSize, height: basketSize)
        }
    }
}

// MARK: - Farm Tab View
/// Wraps FarmTransitionView + FarmShopView. Shows walk animation on each visit,
/// then crossfades to the shop. Resets when the user leaves the tab.

struct FarmTabView: View {
    @State private var showShop = false

    var body: some View {
        ZStack {
            if showShop {
                FarmShopView()
                    .transition(.opacity)
            } else {
                FarmTransitionView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showShop = true
                    }
                }
            }
        }
        .onDisappear {
            showShop = false  // Reset so transition replays next visit
        }
    }
}

// MARK: - Preview

#Preview {
    FarmShopView()
        .environmentObject(GameState.preview)
}

#Preview("Farm Tab") {
    FarmTabView()
        .environmentObject(GameState.preview)
}
