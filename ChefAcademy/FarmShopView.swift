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

    @Binding var selectedTab: MainTabView.Tab
    @EnvironmentObject var gameState: GameState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pipMessage = Self.shopTips.randomElement() ?? "Welcome to my shop!"
    @State private var bounceItem: PantryItem?
    @State private var selectedInfoItem: PantryItem?
    @State private var showPipBubble = false   // Pip's tip opens when he's tapped
    // Cancellable replacement for the old asyncAfter that nil'd bounceItem.
    // Prevents writing to dead @State if the view is dismissed mid-bounce.
    @State private var bounceTask: Task<Void, Never>?
    @Namespace private var shopNamespace

    static let shopTips = [
        "Tap anything on my shelves to buy it!",
        "Buy eggs and butter to make an omelette!",
        "Stock up on basics — salt and pepper go in everything!",
        "Grow veggies in the garden, buy the rest here!",
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.AppTheme.cream
                    .ignoresSafeArea()

                ScrollViewReader { scroller in
                    ScrollView {
                        VStack(spacing: 0) {

                            // MARK: - Header
                            shopHeader
                                .padding(.top, AppSpacing.sm)
                                .padding(.bottom, AppSpacing.sm)

                            // MARK: - Shop Scene (the shelves are the shop)
                            shopMapSection

                            // MARK: - My Pantry Section
                            pantrySection
                                .padding(.top, AppSpacing.lg)
                                .padding(.horizontal, AppSpacing.md)

                            Spacer(minLength: 100)
                        }
                    }
                    // Open with Pip behind the counter in the middle of the screen
                    .onAppear { scroller.scrollTo(Self.pipScrollID, anchor: .center) }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // Morph overlay — replaces .fullScreenCover for smooth matched geometry
        .overlay {
            if let item = selectedInfoItem {
                PantryInfoView(
                    item: item,
                    onDismiss: {
                        withAnimation(AnimationConstants.morphTransition) {
                            selectedInfoItem = nil
                        }
                    },
                    onBuy: {
                        // Buy first, THEN dismiss — buyItem triggers the bounce
                        // animation on the shop card, which is more satisfying
                        // when the info card is already morphing away.
                        buyItem(item)
                        withAnimation(AnimationConstants.morphTransition) {
                            selectedInfoItem = nil
                        }
                    }
                )
                .morphDestination(id: "pantry-\(item.rawValue)", in: shopNamespace)
                .dragToDismiss {
                    withAnimation(AnimationConstants.morphTransition) {
                        selectedInfoItem = nil
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .onDisappear { bounceTask?.cancel() }
        // A player's first visit: Pip explains the shop once, by himself.
        .onAppear {
            if !PipTutorial.shop.isDone(for: gameState.activeProfileID) {
                pipMessage = Self.shopTips[0]
                showPipBubble = true
                PipTutorial.shop.markDone(for: gameState.activeProfileID)
            }
        }
    }

    // MARK: - Shop Scene

    /// Where the signpost's post meets the grass, as fractions of the shop artwork.
    private static let signpostFoot = CGPoint(x: 0.84, y: 0.97)

    /// Height of the counter's top edge, as a fraction of the artwork. Everything
    /// below it is drawn again over Pip, so he stands behind the counter.
    private static let counterTopY: CGFloat = 0.512
    /// Pip's spot in the gap in the middle of the counter, and his width (fraction of the map width).
    private static let pipCounterX: CGFloat = 0.485
    private static let pipWidthFraction: CGFloat = 0.30
    /// How far Pip's centre sits above the counter edge, as a fraction of his size
    /// (the bottom 35% of him is hidden behind the counter).
    private static let pipAboveCounter: CGFloat = 0.15
    /// Height of Pip's speech bubble: the open grass between the front crates and the flowers.
    private static let bubbleY: CGFloat = 0.81
    /// Scroll id of Pip behind the counter; the Shop opens centered on him.
    private static let pipScrollID = "shopPip"

    /// One item painted in the shop artwork, and its tap area (fractions: x0, y0, x1, y1).
    private struct ShelfSpot {
        let item: PantryItem
        let area: (x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat)
    }

    /// Every pantry item, where it's painted on the stall, each in one place.
    private static let shelfSpots: [ShelfSpot] = [
        // Top shelf
        ShelfSpot(item: .salt, area: (0.095, 0.285, 0.175, 0.36)),
        ShelfSpot(item: .pepper, area: (0.175, 0.27, 0.23, 0.36)),
        ShelfSpot(item: .flour, area: (0.24, 0.275, 0.36, 0.36)),
        ShelfSpot(item: .cinnamon, area: (0.365, 0.285, 0.435, 0.36)),
        ShelfSpot(item: .paprika, area: (0.445, 0.29, 0.515, 0.36)),
        ShelfSpot(item: .cumin, area: (0.525, 0.29, 0.595, 0.36)),
        ShelfSpot(item: .garlicPowder, area: (0.60, 0.29, 0.67, 0.36)),
        ShelfSpot(item: .turmeric, area: (0.675, 0.29, 0.75, 0.36)),
        ShelfSpot(item: .butter, area: (0.75, 0.30, 0.905, 0.36)),
        // Middle shelf
        ShelfSpot(item: .eggs, area: (0.07, 0.365, 0.205, 0.42)),
        ShelfSpot(item: .milk, area: (0.205, 0.365, 0.30, 0.435)),
        ShelfSpot(item: .cheese, area: (0.30, 0.38, 0.43, 0.44)),
        ShelfSpot(item: .cream, area: (0.545, 0.38, 0.61, 0.435)),
        ShelfSpot(item: .greekYogurt, area: (0.61, 0.375, 0.71, 0.435)),
        ShelfSpot(item: .chicken, area: (0.71, 0.37, 0.815, 0.435)),
        ShelfSpot(item: .groundBeef, area: (0.815, 0.375, 0.93, 0.435)),
        // On the counter
        ShelfSpot(item: .nuts, area: (0.075, 0.44, 0.21, 0.505)),
        ShelfSpot(item: .soySauce, area: (0.21, 0.435, 0.27, 0.505)),
        ShelfSpot(item: .tomatoSauce, area: (0.27, 0.435, 0.355, 0.505)),
        ShelfSpot(item: .oliveOil, area: (0.635, 0.425, 0.69, 0.505)),
        ShelfSpot(item: .vinegar, area: (0.69, 0.425, 0.75, 0.505)),
        ShelfSpot(item: .vegetableOil, area: (0.75, 0.43, 0.81, 0.505)),
        ShelfSpot(item: .lemon, area: (0.81, 0.43, 0.955, 0.505)),
        // In front of the counter: the grains & legumes (Oct 18, 2026). These four
        // spots used to repeat milk, eggs, flour and lemon; the art is being
        // repainted to a lentil sack, a crate of chickpea jars, an oat sack and a
        // sourdough basket.
        ShelfSpot(item: .lentils, area: (0.135, 0.615, 0.26, 0.715)),
        ShelfSpot(item: .chickpeas, area: (0.255, 0.64, 0.46, 0.725)),
        ShelfSpot(item: .oats, area: (0.56, 0.625, 0.705, 0.73)),
        ShelfSpot(item: .sourdough, area: (0.705, 0.63, 0.875, 0.73)),
    ]

    /// The market stall under the oak. Pip keeps shop behind the counter, every
    /// item on the stall is a button, and the signpost stands on the grass.
    var shopMapSection: some View {
        Image("bg_shop")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .opacity(0.93)   // a light fade over the cream page (the kitchen uses 0.85; the textured shop hazes at that)
            .overlay(
                GeometryReader { mapGeo in
                    let w = mapGeo.size.width
                    let h = mapGeo.size.height
                    let pipSize = w * Self.pipWidthFraction
                    let pipCenter = CGPoint(
                        x: w * Self.pipCounterX,
                        y: h * Self.counterTopY - pipSize * Self.pipAboveCounter
                    )
                    let postHeight = AdaptiveCardSize.signpostHeight(for: sizeClass)

                    ZStack {
                        // Scroll target: a 1×1 point on Pip. The id goes BEFORE
                        // .position, or it would mark the whole map, not Pip.
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id(Self.pipScrollID)
                            .position(pipCenter)

                        PipCharacterView(pose: .neutral, size: .custom(pipSize))
                            .onTapGesture { showPipBubble = true }
                            .position(pipCenter)

                        // The counter front, drawn again on top of Pip's lower half.
                        // Faded like the background, but over solid cream so it
                        // still hides Pip (a faded copy alone would show him through).
                        ZStack {
                            Color.AppTheme.cream
                            Image("bg_shop")
                                .resizable()
                                .opacity(0.93)
                        }
                            .frame(width: w, height: h)
                            .mask(
                                VStack(spacing: 0) {
                                    Color.clear.frame(height: h * Self.counterTopY)
                                    Color.AppTheme.darkBrown
                                }
                            )
                            .allowsHitTesting(false)

                        ForEach(Self.shelfSpots.indices, id: \.self) { index in
                            let spot = Self.shelfSpots[index]
                            Button { tapShelfItem(spot.item) } label: {
                                RoundedRectangle(cornerRadius: AppSpacing.smallCornerRadius)
                                    .stroke(Color.AppTheme.goldenWheat, lineWidth: AppSpacing.strokeBold)
                                    .opacity(bounceItem == spot.item ? 1 : 0)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(spot.item.displayName), \(spot.item.shopPrice) coins")
                            .frame(width: w * (spot.area.x1 - spot.area.x0), height: h * (spot.area.y1 - spot.area.y0))
                            .position(x: w * (spot.area.x0 + spot.area.x1) / 2, y: h * (spot.area.y0 + spot.area.y1) / 2)
                        }

                        // Pip's lower half is behind the counter, so his tag sits on
                        // the counter's edge in front of him.
                        if !showPipBubble {
                            PipTapMeTag()
                                .onTapGesture { showPipBubble = true }
                                .position(x: pipCenter.x, y: h * Self.counterTopY)
                        }

                        // Pip's words go on the open grass under the counter, not beside
                        // him, so they never cover the shelves. With x 0 and no Pip
                        // half-width, the bubble starts at the scene's left edge.
                        // It opens when Pip is tapped; its ✕ closes it.
                        if showPipBubble {
                            PipFloatingBubble(
                                anchor: CGPoint(x: 0, y: h * Self.bubbleY),
                                sceneWidth: w,
                                pipHalfWidth: 0,
                                sizeClass: sizeClass,
                                message: pipMessage,
                                onClose: { showPipBubble = false }
                            )
                        }

                        StationSignpostView(destinations: [.home, .garden, .kitchen], selectedTab: $selectedTab)
                            .position(x: w * Self.signpostFoot.x, y: h * Self.signpostFoot.y - postHeight / 2)
                    }
                }
            )
    }

    /// A shelf item was tapped: Pip names it (or warns about an allergen or the
    /// price), the spot flashes, and the item card with Buy opens.
    private func tapShelfItem(_ item: PantryItem) {
        Haptic.impact(.light)
        pipMessage = shelfMessage(for: item)
        withAnimation(AnimationConstants.springBouncy) {
            bounceItem = item
        }
        bounceTask?.cancel()
        bounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            bounceItem = nil
        }
        withAnimation(AnimationConstants.morphTransition) {
            selectedInfoItem = item
        }
    }

    private func shelfMessage(for item: PantryItem) -> String {
        if let warning = allergenWarning(for: item) {
            return warning
        }
        if gameState.coins < item.shopPrice {
            return "\(item.displayName) costs \(item.shopPrice) coins. Let's earn a few more!"
        }
        return "\(item.displayName)! That's \(item.shopPrice) coins."
    }

    /// The item cards used to show the allergen badge; now Pip says it.
    private func allergenWarning(for item: PantryItem) -> String? {
        let matching = item.allergens.filter { gameState.activeAllergens.contains($0) }
        guard !matching.isEmpty else { return nil }
        let names = matching.map(\.displayName).joined(separator: " and ")
        return "Careful! \(item.displayName) has \(names) in it. Ask a grown-up first!"
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
                    .font(.AppTheme.captionLarge)
                Text("\(gameState.coins)")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(AppSpacing.largeCornerRadius)
        }
        .padding(.horizontal, AppSpacing.md)
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
                .trailingFade()
            }
        }
    }

    // MARK: - Buy Action

    /// Called by the item card's Buy button. Buys right away: tapping the item
    /// and then Buy is already two deliberate taps. (The card asks a grown-up
    /// first when the item has one of the child's allergens.)
    func buyItem(_ item: PantryItem) {
        guard gameState.buyPantryItem(item) else { return }
        // Feedback without a popup: the shelf spot flashes and the count goes
        // up in My Pantry below. Pip's line is there if the kid taps him.
        pipMessage = "You bought \(item.displayName)! It's in your pantry."
        withAnimation(AnimationConstants.springBouncy) {
            bounceItem = item
        }
        // Reset bounce after animation. Cancellable Task replaces asyncAfter so
        // the write is skipped if the view dismisses before 0.5s elapses.
        bounceTask?.cancel()
        bounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            bounceItem = nil
        }
    }
}

// MARK: - Pantry Badge (Shows owned items)

struct PantryBadge: View {
    let stock: PantryStock

    var body: some View {
        VStack(spacing: 2) {
            Image(stock.item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 65)
                .clipped()
                .opacity(0.8)

            Text(stock.item.displayName)
                .font(.AppTheme.rounded(size: 9, weight: .medium))
                .foregroundColor(Color.AppTheme.darkBrown)
                .lineLimit(1)

            Text("x\(stock.quantity)")
                .font(.AppTheme.caption)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .frame(width: 80)
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, AppSpacing.xs)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.smallCornerRadius)
    }
}

// MARK: - Basket with Veggies
/// Shows harvested veggies heaped inside a wheelbarrow.
/// Three layers: the whole wheelbarrow, then the veggies, then only its front
/// wall (`harvest_wheelbarrow_front`) — so the front covers the bottom of each
/// veggie and they look like they sit inside the tub.

struct BasketWithVeggiesView: View {
    let harvestedIngredients: [HarvestedIngredient]
    /// Width of the wheelbarrow; height follows the artwork's ratio.
    let basketSize: CGFloat

    /// Width ÷ height of the wheelbarrow artwork (1400 × 761).
    static let artAspect: CGFloat = 1400 / 761

    private var height: CGFloat { basketSize / Self.artAspect }

    private var veggieSize: CGFloat { basketSize * 0.24 }

    /// Veggie centers as fractions of the artwork, matched to the tub's rim.
    /// Drawn in order: the back row first (higher up, behind), then the front row.
    private static let slots: [(x: CGFloat, y: CGFloat)] = [
        (x: 0.33, y: 0.374), (x: 0.45, y: 0.338), (x: 0.57, y: 0.301), (x: 0.69, y: 0.265),  // front row
        (x: 0.38, y: 0.259), (x: 0.52, y: 0.216), (x: 0.66, y: 0.174),                      // back row
    ]

    var body: some View {
        let shown = Array(harvestedIngredients.prefix(Self.slots.count).enumerated())
        ZStack(alignment: .topLeading) {
            Image("harvest_wheelbarrow")
                .resizable()
                .frame(width: basketSize, height: height)

            // Back row before front row, so front veggies overlap the back ones
            ForEach(shown.reversed(), id: \.element.id) { index, ingredient in
                let slot = Self.slots[index]
                Image(ingredient.type.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: veggieSize, height: veggieSize)
                    .position(x: basketSize * slot.x, y: height * slot.y)
            }

            Image("harvest_wheelbarrow_front")
                .resizable()
                .frame(width: basketSize, height: height)
        }
        .frame(width: basketSize, height: height)
    }
}

// MARK: - Farm Tab View
/// The Shop tab. Opens the shop directly — the barn walk-in was removed
/// (Marina, 2026-10-08): the Home map already shows the shop as a market
/// stall, and the walk blocked the shop on every visit (UX review P1-5).

struct FarmTabView: View {
    @Binding var selectedTab: MainTabView.Tab

    var body: some View {
        FarmShopView(selectedTab: $selectedTab)
    }
}

// MARK: - Preview

#Preview {
    FarmShopView(selectedTab: .constant(.shop))
        .environmentObject(GameState.preview)
}

#Preview("Farm Tab") {
    FarmTabView(selectedTab: .constant(.shop))
        .environmentObject(GameState.preview)
}
