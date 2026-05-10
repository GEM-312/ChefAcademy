//
//  SeedInfoView.swift
//  ChefAcademy
//
//  Full-screen educational view that appears when a child taps a seed bag.
//  Shows fun facts about the vegetable — how it grows, nutrients, and
//  which Body Buddy organs it helps!
//
//  Kids draw directly on the veggie image using PencilKit (Apple Pencil
//  or finger). The PKToolPicker provides tool, color, and opacity controls.
//  Pip reacts to the ink color with nutrition facts.
//

import SwiftUI
import PencilKit
import Combine

// MARK: - Color Choice (Color → Nutrition mapping for Pip tips)

enum ColorChoice: String, CaseIterable {
    case red, orange, yellow, green, purple, brown

    var nutrientName: String {
        switch self {
        case .red:    return "Lycopene"
        case .orange: return "Beta-carotene"
        case .yellow: return "Vitamin C"
        case .green:  return "Folate & Fiber"
        case .purple: return "Anthocyanins"
        case .brown:  return "Allicin"
        }
    }

    var pipTip: String {
        switch self {
        case .red:    return "Red foods have lycopene — it keeps your heart strong!"
        case .orange: return "Orange means beta-carotene — super power for your skin and eyes!"
        case .yellow: return "Yellow foods are packed with Vitamin C to fight off germs!"
        case .green:  return "Green veggies are packed with folate and fiber — they help your cells grow and keep your tummy healthy!"
        case .purple: return "Purple foods have anthocyanins — brain boosters for super thinking!"
        case .brown:  return "White and brown foods have allicin — your immune system's best friend!"
        }
    }

    var organIcon: String {
        switch self {
        case .red:    return "heart.fill"
        case .orange: return "eye.fill"
        case .yellow: return "shield.fill"
        case .green:  return "bolt.fill"
        case .purple: return "brain.head.profile"
        case .brown:  return "shield.fill"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .purple: return .purple
        case .brown:  return .brown
        }
    }

    /// Match a UIColor to the nearest ColorChoice by hue
    static func closest(to color: UIColor) -> ColorChoice {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        // Low saturation = brown/white
        if saturation < 0.15 { return .brown }

        // Map hue (0-1 circle) to color choice
        let degrees = hue * 360
        switch degrees {
        case 0..<20:     return .red
        case 20..<45:    return .orange
        case 45..<70:    return .yellow
        case 70..<170:   return .green
        case 170..<200:  return .green  // teal-ish
        case 200..<290:  return .purple
        case 290..<340:  return .red    // magenta-ish
        case 340...360:  return .red
        default:         return .green
        }
    }
}

// MARK: - Fun Facts Dictionary

private let vegetableFunFacts: [VegetableType: String] = [
    .lettuce: "Lettuce is one of the fastest-growing veggies in the garden! Ancient Egyptians grew it over 4,000 years ago. It's mostly water, which makes it super refreshing on a hot day.",
    .carrot: "Carrots weren't always orange! They used to be purple and yellow. The orange ones were bred in the Netherlands hundreds of years ago. Eating carrots really does help your eyes see better in dim light!",
    .tomato: "Tomatoes are actually fruits, not vegetables! They came from South America and people used to think they were poisonous. Now they're one of the most popular foods in the world.",
    .cucumber: "Cucumbers are 95% water — that's why they feel so cool! The saying \"cool as a cucumber\" is real — the inside can be up to 20 degrees cooler than the outside air.",
    .broccoli: "Broccoli is like a tiny tree you can eat! It's one of the most nutritious vegetables in the world. The word \"broccoli\" comes from Italian and means \"little arms\" or \"little sprouts.\"",
    .zucchini: "Zucchini can grow REALLY fast — sometimes almost 2 inches in a single day! The biggest zucchini ever grown was over 8 feet long. You can even make chocolate cake with zucchini!",
    .onion: "Onions make you cry because they release a tiny gas when you cut them! Ancient Egyptians worshipped onions because their round rings-inside-rings shape reminded them of eternity.",
    .pumpkin: "Pumpkins are 90% water and can grow over 1,000 pounds! Every part of a pumpkin is edible — the skin, flesh, seeds, and even the flowers. They're part of the squash family.",
    .spinach: "Spinach is loaded with iron — that's why Popeye ate it to get strong! It originally came from Persia (modern-day Iran) and can grow back after you cut it, so one plant gives you multiple harvests.",
    .bellPepperRed: "Red bell peppers are actually green peppers that stayed on the plant longer! They have 3 times more Vitamin C than an orange. The longer they ripen, the sweeter and more nutritious they get.",
    .bellPepperYellow: "Yellow bell peppers are in between green and red — sweet and crunchy! They're one of the few veggies that taste great raw or cooked. One yellow pepper has more Vitamin C than a whole glass of orange juice!",
    .sweetPotato: "Sweet potatoes aren't actually potatoes — they're from a completely different plant family! They've been grown for over 5,000 years. Their bright orange color comes from beta-carotene, which is amazing for your skin.",
    .corn: "Each ear of corn has about 800 kernels arranged in 16 rows! Corn is one of the oldest crops — people have been growing it for over 7,000 years. Every single kernel has a tiny silk thread attached to it.",
    .beet: "Beets can turn your tongue and fingers purple — and that's actually a good thing! That purple color comes from anthocyanins, powerful brain boosters. Beet juice was even used as paint in ancient times.",
    .eggplant: "Eggplants got their name because the first ones discovered in Europe were small, white, and looked just like eggs! They come in purple, white, green, and even striped varieties. The purple skin is where most of the nutrients hide.",
    .radish: "Radishes are one of the fastest-growing vegetables — some are ready to eat in just 3 weeks! They were one of the first European crops planted in the Americas. Astronauts have even grown them in space!",
    .kale: "Kale is one of the most nutrient-packed foods on Earth! One cup has more Vitamin C than an orange. It was one of the most common green veggies in Europe until the Middle Ages. You can bake it into crunchy chips!",
    .basil: "Basil means \"royal plant\" in Greek — it was considered the king of herbs! It's the star of pizza and pasta sauce. If you pinch off the flowers, the plant keeps growing more delicious leaves.",
    .mint: "Mint grows SO fast it can take over an entire garden! That fresh tingly feeling when you eat it? That's menthol — it actually tricks your brain into feeling cold. Ancient Romans used mint to freshen their breath.",
    .greenBeans: "Green beans are actually fruit — they're the pods that hold bean seeds inside! They snap when you break them, which is why they're also called \"snap beans.\" They grow by climbing up poles like tiny vines.",
    .strawberry: "Strawberries are the only fruit with seeds on the outside — about 200 on each berry! They're not actually berries (bananas are, though!). One cup of strawberries has more Vitamin C than an orange.",
    .watermelon: "Watermelon is 92% water — that's why it's so refreshing! Every part is edible, even the rind and seeds. In Japan, they grow square watermelons to fit in fridges. It's related to cucumbers!",
    .avocado: "Avocados are sometimes called \"alligator pears\" because of their bumpy green skin! They have more potassium than bananas. An avocado pit can grow into a tree if you put it in water — try it!",
    .lemon: "Lemons are so powerful they can clean pennies and power a small light bulb! Sailors used to eat them on long voyages to stay healthy. A lemon tree can produce over 600 pounds of lemons every year.",
    .blueberry: "Blueberries are called \"brain berries\" by scientists because they're SO good for your brain! They're one of the only naturally blue foods. Native Americans used them for food and medicine for thousands of years.",
    .raspberry: "Each raspberry is made up of about 100 tiny little fruits called drupelets — that's why they're so bumpy! They come in red, black, purple, and even golden yellow. The hollow middle is where they pulled off the stem.",
    .blackberry: "Blackberries change color as they ripen — green, then red, then deep purple-black! They grow on thorny bushes, so picking them is an adventure. They have one of the highest antioxidant levels of any fruit."
]

// MARK: - Nutrient Emoji Mapping

extension NutrientType {
    var emoji: String {
        switch self {
        case .vitaminA:    return "👁️"
        case .vitaminC:    return "🛡️"
        case .vitaminK:    return "🩸"
        case .vitaminB6:   return "🧠"
        case .fiber:       return "🫄"
        case .iron:        return "💪"
        case .calcium:     return "🦴"
        case .potassium:   return "❤️"
        case .healthyFats: return "🧠"
        case .antioxidants:return "✨"
        case .hydration:   return "💧"
        case .protein:     return "💪"
        case .fat:         return "⚡"
        case .carbs:       return "🔥"
        case .minerals:    return "🪨"
        case .probiotics:  return "🦠"
        case .vitaminD:    return "☀️"
        case .vitaminE:    return "🌿"
        case .omega3:      return "🐟"
        case .magnesium:   return "🧲"
        case .zinc:        return "🛡️"
        case .manganese:   return "🦴"
        }
    }

    var organIcon: String {
        switch self {
        case .vitaminA:    return "eye.fill"
        case .vitaminC:    return "shield.fill"
        case .vitaminK:    return "drop.fill"
        case .vitaminB6:   return "brain.head.profile"
        case .fiber:       return "stomach"
        case .iron:        return "drop.fill"
        case .calcium:     return "figure.stand"
        case .potassium:   return "heart.fill"
        case .healthyFats: return "brain.head.profile"
        case .antioxidants:return "shield.fill"
        case .hydration:   return "figure.run"
        case .protein:     return "figure.strengthtraining.traditional"
        case .fat:         return "bolt.fill"
        case .carbs:       return "flame.fill"
        case .minerals:    return "circle.grid.3x3.fill"
        case .probiotics:  return "stomach"
        case .vitaminD:    return "sun.max.fill"
        case .vitaminE:    return "leaf.fill"
        case .omega3:      return "brain.head.profile"
        case .magnesium:   return "figure.strengthtraining.traditional"
        case .zinc:        return "shield.fill"
        case .manganese:   return "figure.stand"
        }
    }

    /// Coin reward for tapping this nutrient knowledge card
    var coinReward: Int {
        return 5
    }
}

// MARK: - VeggieCanvasView (PencilKit + ToolPicker)

struct VeggieCanvasView: UIViewRepresentable {
    /// Called when the user changes ink color (via the tool picker)
    var onColorChange: (UIColor) -> Void
    @Binding var clearToggle: Bool
    @Binding var showToolPicker: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onColorChange: onColorChange)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput

        // Set up the PKToolPicker (hidden by default)
        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        context.coordinator.canvas = canvas
        toolPicker.addObserver(canvas)
        toolPicker.addObserver(context.coordinator)
        // Start hidden — user taps button to show
        toolPicker.setVisible(false, forFirstResponder: canvas)

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Clear drawing when toggle flips
        if clearToggle {
            canvas.drawing = PKDrawing()
            DispatchQueue.main.async {
                clearToggle = false
            }
        }

        // Toggle tool picker visibility
        if let toolPicker = context.coordinator.toolPicker {
            toolPicker.setVisible(showToolPicker, forFirstResponder: canvas)
            if showToolPicker && !canvas.isFirstResponder {
                canvas.becomeFirstResponder()
            }
        }
    }

    // MARK: Coordinator — observes tool picker changes

    class Coordinator: NSObject, PKToolPickerObserver {
        var toolPicker: PKToolPicker?
        weak var canvas: PKCanvasView?
        let onColorChange: (UIColor) -> Void

        init(onColorChange: @escaping (UIColor) -> Void) {
            self.onColorChange = onColorChange
        }

        func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
            if let inkTool = toolPicker.selectedTool as? PKInkingTool {
                onColorChange(inkTool.color)
            }
        }
    }
}

// MARK: - SeedInfoView

struct SeedInfoView: View {
    let seed: Seed
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var gameState: GameState

    // Appear animation
    @State private var appeared = false

    // Coloring state — initial color matches the veggie's actual color
    // TEACHING MOMENT: Before this fix, ALL veggies defaulted to .green
    // which meant Pip said "Folate & Fiber" even for beets (purple/anthocyanins).
    // Now Pip's initial tip matches the veggie's real nutrient color.
    @State private var detectedColorChoice: ColorChoice = .green  // set in .onAppear
    @State private var clearCanvas = false
    @State private var showPipTip = false
    @State private var showToolPicker = false

    // Coin reward animation
    @State private var showCoinReward: String? = nil
    @State private var coloringRewardClaimed = false

    // USDA real nutrition data
    @ObservedObject private var usdaService = USDAFoodService.shared
    @State private var nutrientProfile: NutrientProfile?

    private var veggie: VegetableType { seed.vegetableType }
    private var colorKnowledgeID: String { "seed_\(veggie.rawValue)_color" }

    /// Maps each veggie to its correct nutrient color so Pip's initial tip is accurate.
    /// Beets = purple (anthocyanins/brain), NOT red (lycopene/heart).
    private func initialColorForVeggie(_ veg: VegetableType) -> ColorChoice {
        switch veg {
        // Red veggies (lycopene — heart)
        case .tomato, .bellPepperRed, .strawberry, .raspberry, .watermelon:
            return .red
        // Orange veggies (beta-carotene — eyes/skin)
        case .carrot, .sweetPotato, .pumpkin:
            return .orange
        // Yellow veggies (vitamin C — immune)
        case .bellPepperYellow, .corn, .lemon:
            return .yellow
        // Green veggies (folate & fiber — energy/digestion)
        case .lettuce, .cucumber, .broccoli, .zucchini, .spinach, .kale,
             .basil, .mint, .greenBeans, .avocado:
            return .green
        // Purple veggies (anthocyanins — brain)
        case .beet, .eggplant, .blueberry, .blackberry:
            return .purple
        // Brown/white (allicin — immune)
        case .onion, .radish:
            return .brown
        }
    }
    private func nutrientKnowledgeID(_ nutrient: NutrientType) -> String {
        "seed_\(veggie.rawValue)_\(nutrient.rawValue)"
    }

    var body: some View {
        ZStack {
            // Background
            Color.AppTheme.cream
                .ignoresSafeArea()

            ScrollView(.vertical) {
                VStack(spacing: AppSpacing.lg) {

                    // MARK: - Veggie name
                    Text(veggie.displayName)
                        .font(.AppTheme.rounded(size: 32, weight: .bold))
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .scaleEffect(appeared ? 1.0 : 0.8)
                        .opacity(appeared ? 1.0 : 0)

                    // MARK: - Veggie image + drawing canvas
                    drawableVeggieSection
                        .scaleEffect(appeared ? 1.0 : 0.9)
                        .opacity(appeared ? 1.0 : 0)

                    // MARK: - Pip's color tip
                    pipColorTip
                        .padding(.horizontal, AppSpacing.lg)
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1.0 : 0)

                    // MARK: - Growth Info
                    growthInfoSection
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1.0 : 0)

                    // MARK: - Nutrients ("What's Inside")
                    nutrientsSection
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1.0 : 0)

                    // MARK: - Fun Fact
                    funFactSection
                        .offset(y: appeared ? 0 : 50)
                        .opacity(appeared ? 1.0 : 0)

                    // Extra space for tool picker at bottom
                    Spacer(minLength: 140)
                }
                .padding(.top, 60) // room for close button
                .frame(maxWidth: .infinity)
            }
            .clipped()

            // MARK: - Close Button + Coin Counter
            VStack {
                HStack {
                    // Coin display
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.AppTheme.captionLarge)
                        Text("\(gameState.coins)")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.largeCornerRadius)
                    .padding(.leading, AppSpacing.md)
                    .padding(.top, AppSpacing.md)

                    Spacer()

                    Button {
                        if let onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.AppTheme.rounded(size: 30))
                            .foregroundColor(Color.AppTheme.sepia.opacity(0.6))
                            .padding(AppSpacing.md)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // MARK: - Floating Coin Reward
            if let reward = showCoinReward {
                VStack {
                    Text(reward)
                        .font(.AppTheme.rounded(size: 28, weight: .bold))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                        .shadow(color: Color.AppTheme.sepia.opacity(0.2), radius: 4, y: 2)
                        .transition(.scale.combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
        .onAppear {
            // Set initial Pip tip to match the veggie's real color/nutrient
            detectedColorChoice = initialColorForVeggie(veggie)

            coloringRewardClaimed = gameState.isKnowledgeClaimed(colorKnowledgeID)
            withAnimation(AnimationConstants.springFly) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showPipTip = true
                }
            }
            // Fetch real nutrition data from USDA
            Task {
                let profile = await usdaService.nutrientProfile(for: veggie.rawValue)
                await MainActor.run {
                    nutrientProfile = profile
                }
                if let p = profile {
                    print("[SeedInfo] USDA loaded for \(veggie.rawValue): \(Int(p.calories)) kcal, Vit C: \(p.vitaminC) mg, Ca: \(p.calcium) mg")
                } else {
                    print("[SeedInfo] USDA returned nil for \(veggie.rawValue)")
                }
            }
        }
        .onDisappear {
            PipVoice.shared.stop()
        }
    }

    // MARK: - Drawable Veggie Section (image + canvas overlay)

    // TEACHING MOMENT: Why a fixed canvas size?
    // PencilKit stores drawing coordinates as absolute pixel positions.
    // If the canvas resizes on rotation (landscape ↔ portrait), the
    // coordinates don't move with it — so the drawing "slides away."
    // By using a FIXED size (320×280), the drawing always stays aligned
    // with the veggie image regardless of device orientation.
    private let canvasSize = CGSize(width: 320, height: 280)

    private var drawableVeggieSection: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                // The veggie image — FIXED size so drawing stays aligned on rotation
                Image(veggie.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .clipped()

                // PencilKit canvas overlay (same FIXED size as image)
                VeggieCanvasView(
                    onColorChange: { uiColor in
                        let newChoice = ColorChoice.closest(to: uiColor)
                        if newChoice != detectedColorChoice {
                            withAnimation(.easeOut(duration: 0.15)) {
                                showPipTip = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                detectedColorChoice = newChoice
                                withAnimation(.easeIn(duration: 0.2)) {
                                    showPipTip = true
                                }
                            }
                        }
                        // Reward for coloring (one-time per veggie)
                        if !coloringRewardClaimed {
                            if gameState.claimKnowledgeReward(id: colorKnowledgeID, coins: 5) {
                                coloringRewardClaimed = true
                                withAnimation(AnimationConstants.springMedium) {
                                    showCoinReward = "+5"
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation { showCoinReward = nil }
                                }
                            }
                        }
                    },
                    clearToggle: $clearCanvas,
                    showToolPicker: $showToolPicker
                )
                .frame(width: canvasSize.width, height: canvasSize.height)

                // Paintbrush toggle button (bottom-right of image)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(AnimationConstants.springQuick) {
                                showToolPicker.toggle()
                            }
                        } label: {
                            Image(systemName: showToolPicker ? "paintbrush.fill" : "paintbrush")
                                .font(.AppTheme.recipeStep)
                                .foregroundColor(showToolPicker ? Color.AppTheme.cream : Color.AppTheme.sepia)
                                .frame(width: 42, height: 42)
                                .background(showToolPicker ? Color.AppTheme.sage : Color.AppTheme.parchment)
                                .clipShape(Circle())
                                .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 4, y: 2)
                        }
                        .padding(AppSpacing.sm)
                    }
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height + 40)
            .clipped()
            .padding(.horizontal, AppSpacing.md)

            // Clear button (only show when drawing mode is active)
            if showToolPicker {
                HStack {
                    Spacer()
                    Button {
                        clearCanvas = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Clear")
                        }
                        .font(.AppTheme.rounded(size: 14, weight: .medium))
                        .foregroundColor(Color.AppTheme.lightSepia)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.AppTheme.parchment)
                        .cornerRadius(AppSpacing.largeCornerRadius)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Pip Color Tip
    //
    // TEACHING MOMENT: The color→nutrient system teaches kids about PLANT PIGMENTS.
    // Red = lycopene (the actual red pigment), purple = anthocyanins (actual purple
    // pigment), orange = beta-carotene (actual orange pigment). This is CORRECT
    // science — don't replace with generic USDA nutrients like "potassium 325mg"
    // which have nothing to do with color and mean nothing to a 6-year-old.
    //
    // The USDA data is used elsewhere (What's Inside section, Body Buddy) for
    // detailed nutrition. The Pip color tip is specifically about the visual
    // science of WHY foods are different colors.
    //

    private var pipColorTip: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Pip avatar — medium size to match pigment-science pattern
            Image(PipPose.gotIdea.rawValue)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: PipSize.medium.points, height: PipSize.medium.points)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.AppTheme.sage, lineWidth: AppSpacing.strokeMedium)
                )

            // Speech bubble — color-based pigment science (NOT generic USDA nutrients)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: detectedColorChoice.organIcon)
                        .font(.AppTheme.caption)
                        .foregroundColor(detectedColorChoice.swiftUIColor)
                    Text(detectedColorChoice.nutrientName)
                        .font(.AppTheme.rounded(size: 13, weight: .semibold))
                        .foregroundColor(Color.AppTheme.darkBrown)
                }

                Text(detectedColorChoice.pipTip)
                    .font(.AppTheme.rounded(size: 14, weight: .regular))
                    .foregroundColor(Color.AppTheme.sepia)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .softCard(showShadow: false)
        }
        .opacity(showPipTip ? 1 : 0)
        .offset(y: showPipTip ? 0 : 10)
    }

    // MARK: - Growth Info Section

    private var growthInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Growing Info")
                .font(.AppTheme.rounded(size: 20, weight: .bold))
                .foregroundColor(Color.AppTheme.darkBrown)

            HStack(spacing: AppSpacing.md) {
                growthInfoCard(
                    icon: "clock.fill",
                    label: "Grow Time",
                    value: growthTimeString
                )
                growthInfoCard(
                    icon: "leaf.fill",
                    label: "Harvest",
                    value: "\(veggie.harvestYield) veggies"
                )
                growthInfoCard(
                    icon: "circle.fill",
                    label: "Seed Cost",
                    value: "\(veggie.seedCost) coins"
                )
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func growthInfoCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.AppTheme.title2)
                .foregroundColor(Color.AppTheme.sage)

            Text(label)
                .font(.AppTheme.rounded(size: 11, weight: .medium))
                .foregroundColor(Color.AppTheme.lightSepia)

            Text(value)
                .font(.AppTheme.rounded(size: 14, weight: .semibold))
                .foregroundColor(Color.AppTheme.darkBrown)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .softCard()
    }

    private var growthTimeString: String {
        let seconds = Int(veggie.growthTime)
        if seconds < 60 {
            return "\(seconds) sec"
        } else {
            let minutes = seconds / 60
            let remaining = seconds % 60
            if remaining == 0 {
                return "\(minutes) min"
            } else {
                return "\(minutes)m \(remaining)s"
            }
        }
    }

    // MARK: - USDA Kid-Friendly Info

    /// Returns a kid-friendly superpower description based on real USDA data
    private func usdaSuperpower(for nutrient: NutrientType, profile: NutrientProfile) -> String? {
        switch nutrient {
        case .vitaminA:
            guard profile.vitaminA > 50 else { return nil }
            if profile.vitaminA > 500 { return "Super vision power!" }
            return "Helps you see in the dark!"

        case .vitaminC:
            guard profile.vitaminC > 2 else { return nil }
            if profile.vitaminC > 40 { return "Germ-fighting superpower!" }
            return "Fights off germs!"

        case .vitaminK:
            guard profile.vitaminK > 5 else { return nil }
            return "Helps your cuts heal fast!"

        case .vitaminB6:
            guard profile.vitaminB6 > 0.05 else { return nil }
            return "Brain fuel for thinking!"

        case .calcium:
            guard profile.calcium > 10 else { return nil }
            if profile.calcium > 50 { return "Super strong bones!" }
            return "Builds tough bones!"

        case .iron:
            guard profile.iron > 0.3 else { return nil }
            return "Gives your blood energy!"

        case .potassium:
            guard profile.potassium > 50 else { return nil }
            if profile.potassium > 200 { return "Heart superpower!" }
            return "Keeps your heart happy!"

        case .fiber:
            guard profile.fiber > 0.5 else { return nil }
            if profile.fiber > 2 { return "Tummy's best friend!" }
            return "Helps your tummy work!"

        case .protein:
            guard profile.protein > 1 else { return nil }
            if profile.protein > 5 { return "Muscle builder!" }
            return "Helps muscles grow!"

        case .magnesium:
            guard profile.magnesium > 5 else { return nil }
            return "Relaxes your muscles!"

        case .zinc:
            guard profile.zinc > 0.3 else { return nil }
            return "Shield for your body!"

        case .vitaminE:
            guard profile.vitaminE > 0.3 else { return nil }
            return "Keeps your skin glowing!"

        case .vitaminD:
            return "Sunshine vitamin for bones!"

        case .omega3:
            return "Brain booster power!"

        default:
            return nil
        }
    }

    /// Kid-friendly comparison based on USDA data
    private func usdaComparison(for nutrient: NutrientType, profile: NutrientProfile) -> String? {
        switch nutrient {
        case .vitaminC:
            if profile.vitaminC > 80 { return "More Vitamin C than an orange!" }
            if profile.vitaminC > 30 { return "Like half an orange of Vitamin C!" }
            return nil
        case .vitaminA:
            if profile.vitaminA > 5000 { return "More Vitamin A than 5 eggs!" }
            return nil
        case .calcium:
            if profile.calcium > 100 { return "Almost like a glass of milk!" }
            return nil
        case .iron:
            if profile.iron > 2 { return "Packed with iron like spinach!" }
            return nil
        case .fiber:
            if profile.fiber > 3 { return "More fiber than a slice of bread!" }
            return nil
        case .protein:
            if profile.protein > 10 { return "Protein power like an egg!" }
            return nil
        case .potassium:
            if profile.potassium > 300 { return "Almost as much potassium as a banana!" }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Nutrients Section

    private var nutrientsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("What's Inside")
                    .font(.AppTheme.rounded(size: 20, weight: .bold))
                    .foregroundColor(Color.AppTheme.darkBrown)
                SpeakerButton(
                    text: "\(veggie.displayName) has \(veggie.nutrients.map { $0.rawValue }.joined(separator: ", ")). Each one helps a different part of your body!",
                    size: 18
                )
                Spacer()
                Text("Tap to learn!")
                    .font(.AppTheme.rounded(size: 12, weight: .medium))
                    .foregroundColor(Color.AppTheme.goldenWheat)
            }

            VStack(spacing: AppSpacing.xs) {
                ForEach(veggie.nutrients, id: \.rawValue) { nutrient in
                    nutrientRow(nutrient)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func nutrientRow(_ nutrient: NutrientType) -> some View {
        let knowledgeID = nutrientKnowledgeID(nutrient)
        let isClaimed = gameState.isKnowledgeClaimed(knowledgeID)

        return Button(action: {
            if gameState.claimKnowledgeReward(id: knowledgeID, coins: nutrient.coinReward) {
                withAnimation(AnimationConstants.springMedium) {
                    showCoinReward = "+\(nutrient.coinReward)"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showCoinReward = nil }
                }
            }
        }) {
            HStack(spacing: AppSpacing.md) {
                Text(nutrient.emoji)
                    .font(.AppTheme.rounded(size: 26))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(nutrient.rawValue)
                        .font(.AppTheme.rounded(size: 16, weight: .semibold))
                        .foregroundColor(Color.AppTheme.darkBrown)

                    HStack(spacing: 4) {
                        Image(systemName: nutrient.organIcon)
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sage)

                        Text("Helps your \(nutrient.benefitsOrgan)")
                            .font(.AppTheme.rounded(size: 13, weight: .regular))
                            .foregroundColor(Color.AppTheme.sepia)
                    }

                    // Kid-friendly superpower from USDA data
                    if let profile = nutrientProfile,
                       let superpower = usdaSuperpower(for: nutrient, profile: profile) {
                        Text(superpower)
                            .font(.AppTheme.rounded(size: 12, weight: .semibold))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.AppTheme.goldenWheat.opacity(0.12))
                            .cornerRadius(AppSpacing.pillCornerRadius)
                    }

                    // Fun comparison
                    if let profile = nutrientProfile,
                       let comparison = usdaComparison(for: nutrient, profile: profile) {
                        Text(comparison)
                            .font(.AppTheme.rounded(size: 11, weight: .medium))
                            .foregroundColor(Color.AppTheme.sage)
                            .italic()
                    }
                }

                Spacer()

                if isClaimed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.AppTheme.sage)
                        .font(.AppTheme.recipeStep)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(Color.AppTheme.goldenWheat)
                            .font(.AppTheme.micro)
                        Text("+\(nutrient.coinReward)")
                            .font(.AppTheme.rounded(size: 13, weight: .bold))
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(isClaimed ? Color.AppTheme.sage.opacity(0.1) : Color.AppTheme.parchment.opacity(0.6))
            .cornerRadius(AppSpacing.smallCornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fun Fact Section

    private var funFactKnowledgeID: String {
        "seed_\(veggie.rawValue)_funfact"
    }

    private var funFactSection: some View {
        let isClaimed = gameState.isKnowledgeClaimed(funFactKnowledgeID)

        return Button(action: {
            if gameState.claimKnowledgeReward(id: funFactKnowledgeID, coins: 5) {
                withAnimation(AnimationConstants.springMedium) {
                    showCoinReward = "+5"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { showCoinReward = nil }
                }
            }
        }) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color.AppTheme.goldenWheat)
                    Text("Fun Fact!")
                        .font(.AppTheme.rounded(size: 20, weight: .bold))
                        .foregroundColor(Color.AppTheme.darkBrown)
                    SpeakerButton(
                        text: vegetableFunFacts[veggie] ?? "This vegetable is full of surprises!",
                        size: 18
                    )
                    Spacer()
                    if isClaimed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.AppTheme.sage)
                            .font(.AppTheme.recipeStep)
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(Color.AppTheme.goldenWheat)
                                .font(.AppTheme.micro)
                            Text("+5")
                                .font(.AppTheme.rounded(size: 13, weight: .bold))
                                .foregroundColor(Color.AppTheme.goldenWheat)
                        }
                    }
                }

                Text(vegetableFunFacts[veggie] ?? "This vegetable is full of surprises!")
                    .font(.AppTheme.rounded(size: 16, weight: .regular))
                    .foregroundColor(Color.AppTheme.sepia)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.lg)
            .background(isClaimed ? Color.AppTheme.sage.opacity(0.1) : Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .shadow(color: Color.AppTheme.sepia.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.lg)
    }
}

// MARK: - Preview

#Preview {
    SeedInfoView(seed: Seed(vegetableType: .broccoli, quantity: 3))
}
