//
//  KitchenView.swift
//  ChefAcademy
//
//  Pip's Kitchen! This is the COOKING SCENE - an interactive kitchen map
//  just like GardenView uses bg_garden as an interactive map.
//  bg_kitchen is the map, with interactive spots overlaid on top.
//
//  Flow: See the kitchen map → Tap spots (counter, stove, shelf) → Cook!
//

import SwiftUI

// MARK: - Kitchen View

struct KitchenView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.horizontalSizeClass) var sizeClass

    private var isIPad: Bool { sizeClass != .compact }

    @State private var pipMessage = "Welcome to my kitchen! Tap around to explore!"
    @State private var pipPose: PipPose = .cooking
    @State private var selectedRecipe: Recipe? = nil
    @State private var showRecipePicker = false
    @State private var cookingStep = 0

    // ==========================================
    // SCENE EDITOR: Set to true to drag items around and position them!
    // When done, copy the printed positions to the code below and set back to false.
    // ==========================================
    @State private var editMode = false

    // Draggable scene item positions (used by Scene Editor)
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
                    // Background color
                    Color.AppTheme.cream
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {

                            // MARK: - Header
                            kitchenHeader
                                .padding(.top, AppSpacing.sm)
                                .padding(.bottom, AppSpacing.sm)

                            // MARK: - Kitchen Map with Interactive Spots
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

            // Edit mode toggle (Scene Editor - only visible in debug/dev builds)
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

    // MARK: - Kitchen Map Section (like Garden Map)

    /// Helper to get a scene item's position by ID
    func pos(for id: String, w: CGFloat, h: CGFloat) -> CGPoint {
        guard let item = sceneItems.first(where: { $0.id == id }) else {
            return CGPoint(x: w * 0.5, y: h * 0.5)
        }
        return CGPoint(x: w * item.xPercent, y: h * item.yPercent)
    }

    func kitchenMapSection(screenWidth: CGFloat) -> some View {
        // The kitchen image is the MAP - interactive spots are overlaid on top
        Image("bg_kitchen")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .opacity(0.85)
            .overlay(
                GeometryReader { mapGeo in
                    let w = mapGeo.size.width
                    let h = mapGeo.size.height

                    if editMode {
                        // ==========================================
                        // EDIT MODE: Theatre.js-style scene editor
                        // Drag the handles to reposition items!
                        // ==========================================
                        SceneEditorOverlay(
                            mapWidth: w,
                            mapHeight: h,
                            items: $sceneItems,
                            editMode: true
                        )
                    } else {
                        // ==========================================
                        // PLAY MODE: Normal interactive kitchen
                        // Positions come from sceneItems array
                        // ==========================================

                        // Counter spot (where ALL ingredients sit — veggies + pantry)
                        kitchenSpot(
                            icon: "tray.full.fill",
                            label: "Counter",
                            color: Color.AppTheme.goldenWheat,
                            badgeCount: totalIngredientCount
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                pipPose = .thinking
                                if totalIngredientCount > 0 {
                                    pipMessage = "We have \(ingredientCount) veggies and \(pantryItemCount) pantry items!"
                                } else {
                                    pipMessage = "Counter is empty! Grow veggies and visit the farm shop."
                                }
                            }
                        }
                        .position(pos(for: "counter", w: w, h: h))

                        // Stove spot (where you cook)
                        kitchenSpot(
                            icon: "flame.fill",
                            label: "Stove",
                            color: Color.AppTheme.terracotta,
                            badgeCount: readyRecipeCount
                        ) {
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
                        .position(pos(for: "stove", w: w, h: h))

                        // Shelf spot (pantry staples)
                        kitchenSpot(
                            icon: "archivebox.fill",
                            label: "Pantry",
                            color: Color.AppTheme.sage,
                            badgeCount: pantryItemCount
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                pipPose = .cooking
                                pipMessage = pantryItemCount > 0
                                    ? "We have \(pantryItemCount) pantry staples on the shelf!"
                                    : "Pantry is empty! Visit the farm shop to stock up."
                            }
                        }
                        .position(pos(for: "pantry", w: w, h: h))

                        // Pip standing in the kitchen
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
                    }
                }
            )
    }

    // MARK: - Kitchen Spot (interactive tap point on the map)

    func kitchenSpot(icon: String, label: String, color: Color, badgeCount: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: isIPad ? 70 : 50, height: isIPad ? 70 : 50)

                    Circle()
                        .fill(Color.AppTheme.warmCream.opacity(0.9))
                        .frame(width: isIPad ? 56 : 40, height: isIPad ? 56 : 40)

                    Image(systemName: icon)
                        .font(.system(size: isIPad ? 24 : 18))
                        .foregroundColor(color)
                }
                .overlay(
                    // Badge count
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
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.AppTheme.warmCream.opacity(0.9))
                    .cornerRadius(8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Panel

    var bottomPanel: some View {
        VStack(spacing: AppSpacing.md) {
            // Pip's kitchen message
            PipKitchenMessage(pose: pipPose, message: pipMessage)
                .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)

            // Ingredients on counter
            counterSection
                .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)

            // Ready recipes
            if readyRecipeCount > 0 {
                readyRecipesSection
                    .padding(.horizontal, isIPad ? AppSpacing.lg : AppSpacing.md)
            }
        }
    }

    // MARK: - Counter Section (ingredients you have)

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
                // Garden veggies
                if !gameState.harvestedIngredients.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isIPad ? AppSpacing.md : AppSpacing.sm) {
                            ForEach(gameState.harvestedIngredients) { ingredient in
                                IngredientBadge(ingredient: ingredient, isIPad: isIPad)
                            }
                        }
                    }
                }

                // Pantry staples
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

                    // Cook button
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
                            selectedRecipe = recipe
                            showRecipePicker = false
                            pipPose = .excited
                            pipMessage = "Let's make \(recipe.title)!"
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

    /// Total of garden veggies + pantry items (everything available to cook with)
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
        if readyRecipeCount > 0 {
            return "Tap the stove to start cooking!"
        } else if ingredientCount > 0 {
            return "Almost ready! Get more ingredients to cook."
        } else {
            return "Tap around to explore the kitchen!"
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
            // Animated Pip waving (frame animation, transparent bg)
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
