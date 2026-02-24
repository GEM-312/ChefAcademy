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

// MARK: - Color Choice (Color → Nutrition mapping for Pip tips)

enum ColorChoice: String, CaseIterable {
    case red, orange, yellow, green, purple, brown

    var nutrientName: String {
        switch self {
        case .red:    return "Lycopene"
        case .orange: return "Beta-carotene"
        case .yellow: return "Vitamin C"
        case .green:  return "Chlorophyll & Folate"
        case .purple: return "Anthocyanins"
        case .brown:  return "Allicin"
        }
    }

    var pipTip: String {
        switch self {
        case .red:    return "Red foods have lycopene — it keeps your heart strong!"
        case .orange: return "Orange means beta-carotene — super power for your skin and eyes!"
        case .yellow: return "Yellow foods are packed with Vitamin C to fight off germs!"
        case .green:  return "Green is chlorophyll — it gives plants energy, and gives YOU energy too!"
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

private extension NutrientType {
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
        }
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
    @Environment(\.dismiss) var dismiss

    // Appear animation
    @State private var appeared = false

    // Coloring state
    @State private var detectedColorChoice: ColorChoice = .green
    @State private var clearCanvas = false
    @State private var showPipTip = false
    @State private var showToolPicker = false

    private var veggie: VegetableType { seed.vegetableType }

    var body: some View {
        ZStack {
            // Background
            Color.AppTheme.cream
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {

                    // MARK: - Veggie name
                    Text(veggie.displayName)
                        .font(.custom("Georgia", size: 32).bold())
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
            }

            // MARK: - Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color.AppTheme.sepia.opacity(0.6))
                            .padding(AppSpacing.md)
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showPipTip = true
                }
            }
        }
    }

    // MARK: - Drawable Veggie Section (image + canvas overlay)

    private var drawableVeggieSection: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                // The veggie image — kids draw right on top of this
                Image(veggie.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.lg)

                // PencilKit canvas overlay (transparent, same size)
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
                    },
                    clearToggle: $clearCanvas,
                    showToolPicker: $showToolPicker
                )

                // Paintbrush toggle button (bottom-right of image)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showToolPicker.toggle()
                            }
                        } label: {
                            Image(systemName: showToolPicker ? "paintbrush.fill" : "paintbrush")
                                .font(.system(size: 18))
                                .foregroundColor(showToolPicker ? Color.AppTheme.cream : Color.AppTheme.sepia)
                                .frame(width: 42, height: 42)
                                .background(showToolPicker ? Color.AppTheme.sage : Color.AppTheme.parchment)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                        }
                        .padding(AppSpacing.sm)
                    }
                }
            }
            .frame(height: 320)
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
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.AppTheme.lightSepia)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.AppTheme.parchment)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Pip Color Tip

    private var pipColorTip: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Pip avatar
            Image("pip_neutral")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 55, height: 55)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.AppTheme.sage, lineWidth: 2)
                )

            // Speech bubble
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: detectedColorChoice.organIcon)
                        .font(.system(size: 12))
                        .foregroundColor(detectedColorChoice.swiftUIColor)
                    Text(detectedColorChoice.nutrientName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.AppTheme.darkBrown)
                }

                Text(detectedColorChoice.pipTip)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Color.AppTheme.sepia)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .opacity(showPipTip ? 1 : 0)
        .offset(y: showPipTip ? 0 : 10)
    }

    // MARK: - Growth Info Section

    private var growthInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Growing Info")
                .font(.custom("Georgia", size: 20).bold())
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
                .font(.system(size: 22))
                .foregroundColor(Color.AppTheme.sage)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.lightSepia)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
        .shadow(color: Color.AppTheme.sepia.opacity(0.08), radius: 4, y: 2)
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

    // MARK: - Nutrients Section

    private var nutrientsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("What's Inside")
                .font(.custom("Georgia", size: 20).bold())
                .foregroundColor(Color.AppTheme.darkBrown)

            VStack(spacing: AppSpacing.xs) {
                ForEach(veggie.nutrients, id: \.rawValue) { nutrient in
                    nutrientRow(nutrient)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func nutrientRow(_ nutrient: NutrientType) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(nutrient.emoji)
                .font(.system(size: 26))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(nutrient.rawValue)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.AppTheme.darkBrown)

                HStack(spacing: 4) {
                    Image(systemName: nutrient.organIcon)
                        .font(.system(size: 12))
                        .foregroundColor(Color.AppTheme.sage)

                    Text("Helps your \(nutrient.benefitsOrgan)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Color.AppTheme.sepia)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(Color.AppTheme.parchment.opacity(0.6))
        .cornerRadius(12)
    }

    // MARK: - Fun Fact Section

    private var funFactSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                Text("Fun Fact!")
                    .font(.custom("Georgia", size: 20).bold())
                    .foregroundColor(Color.AppTheme.darkBrown)
            }

            Text(vegetableFunFacts[veggie] ?? "This vegetable is full of surprises!")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.AppTheme.sepia)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
        .shadow(color: Color.AppTheme.sepia.opacity(0.08), radius: 6, y: 3)
        .padding(.horizontal, AppSpacing.lg)
    }
}

// MARK: - Preview

#Preview {
    SeedInfoView(seed: Seed(vegetableType: .broccoli, quantity: 3))
}
