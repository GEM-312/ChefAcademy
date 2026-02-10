import SwiftUI

// MARK: - Updated Home View with Animated Pip (iPad Responsive)
struct HomeAnimatedView: View {
    @ObservedObject var avatarModel: AvatarModel
    @State private var pipPose: PipPose = .waving
    @State private var pipMessage = "Welcome back! Ready to cook something delicious today?"

    // Detect device size class
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let isCompact = sizeClass == .compact
                let maxContentWidth: CGFloat = 700
                let contentWidth = isCompact ? geometry.size.width : min(geometry.size.width - 64, maxContentWidth)
                let horizontalPadding = max((geometry.size.width - contentWidth) / 2, 0)

                ZStack {
                    // MARK: - Background
                    Color.AppTheme.cream
                        .ignoresSafeArea()

                    // MARK: - Main Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: isCompact ? AppSpacing.lg : AppSpacing.xl) {

                            // MARK: - Header with greeting
                            headerSection
                                .padding(.horizontal, horizontalPadding + AppSpacing.md)

                            // MARK: - Streak Card
                            StreakCardAnimated(streak: avatarModel.currentStreak)
                                .padding(.horizontal, horizontalPadding + AppSpacing.md)

                            // MARK: - Pip's Message
                            PipMessageAnimated(
                                pose: pipPose,
                                message: pipMessage
                            )
                            .padding(.horizontal, horizontalPadding + AppSpacing.md)
                            .onTapGesture {
                                cyclePipMessage()
                            }

                            // MARK: - Quick Actions
                            quickActionsSection(horizontalPadding: horizontalPadding, screenWidth: contentWidth)

                            // MARK: - Today's Recipe
                            todaysRecipeSection
                                .padding(.horizontal, horizontalPadding + AppSpacing.md)

                            Spacer()
                                .frame(height: 100) // Space for tab bar
                        }
                        .padding(.top, AppSpacing.md)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        // IMPORTANT: Force stack navigation on iPad (prevents sidebar layout)
        .navigationViewStyle(.stack)
    }

    // MARK: - Header Section

    var headerSection: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingMessage)
                    .font(sizeClass == .compact ? .AppTheme.headline : .AppTheme.title3)
                    .foregroundColor(Color.AppTheme.sepia)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Chef \(avatarModel.name.isEmpty ? "Little Chef" : avatarModel.name)!")
                    .font(sizeClass == .compact ? .AppTheme.title : .AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .layoutPriority(1)

            Spacer(minLength: AppSpacing.xs)

            // Avatar mini preview - larger on iPad
            ZStack {
                Circle()
                    .fill(Color.AppTheme.parchment)
                    .frame(
                        width: AdaptiveCardSize.avatarPreview(for: sizeClass),
                        height: AdaptiveCardSize.avatarPreview(for: sizeClass)
                    )

                AvatarPreviewView(avatarModel: avatarModel)
                    .scaleEffect(sizeClass == .compact ? 0.2 : 0.28)
            }
            .fixedSize()
        }
    }

    // MARK: - Quick Actions Section

    func quickActionsSection(horizontalPadding: CGFloat, screenWidth: CGFloat) -> some View {
        let isCompact = sizeClass == .compact

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("What would you like to do?")
                .font(isCompact ? .AppTheme.headline : .AppTheme.title3)
                .foregroundColor(Color.AppTheme.darkBrown)
                .padding(.horizontal, horizontalPadding + AppSpacing.md)

            // On iPad: Show all 4 cards in a grid
            // On iPhone: Horizontal scroll
            if isCompact {
                // iPhone: Horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        quickActionCards
                    }
                    .padding(.horizontal, horizontalPadding + AppSpacing.md)
                }
            } else {
                // iPad: Grid layout showing all 4
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppSpacing.lg),
                        GridItem(.flexible(), spacing: AppSpacing.lg),
                        GridItem(.flexible(), spacing: AppSpacing.lg),
                        GridItem(.flexible(), spacing: AppSpacing.lg)
                    ],
                    spacing: AppSpacing.lg
                ) {
                    quickActionCards
                }
                .padding(.horizontal, horizontalPadding + AppSpacing.md)
            }
        }
    }

    // MARK: - Quick Action Cards

    @ViewBuilder
    var quickActionCards: some View {
        QuickActionCardWithImage(
            title: "Visit Garden",
            imageName: "bg_garden",
            color: Color.AppTheme.sage,
            sizeClass: sizeClass
        ) {
            pipPose = .excited
            pipMessage = "Let's see what's growing in the garden!"
        }

        QuickActionCardWithImage(
            title: "Cook Recipe",
            imageName: "bg_kitchen",
            color: Color.AppTheme.goldenWheat,
            sizeClass: sizeClass
        ) {
            pipPose = .cooking
            pipMessage = "Time to make something yummy!"
        }

        QuickActionCardAnimated(
            icon: "🎮",
            title: "Play & Learn",
            color: Color.AppTheme.terracotta,
            sizeClass: sizeClass
        ) {
            pipPose = .thinking
            pipMessage = "Let's learn about how food helps your body!"
        }

        QuickActionCardAnimated(
            icon: "🏆",
            title: "My Badges",
            color: Color.AppTheme.sage,
            sizeClass: sizeClass
        ) {
            pipPose = .celebrating
            pipMessage = "Look at all the badges you've earned!"
        }
    }

    // MARK: - Today's Recipe Section

    var todaysRecipeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Today's Recipe")
                .font(sizeClass == .compact ? .AppTheme.headline : .AppTheme.title3)
                .foregroundColor(Color.AppTheme.darkBrown)

            RecipeCardView(
                recipe: Recipe(
                    title: "Rainbow Veggie Wrap",
                    description: "A colorful, crunchy wrap packed with fresh vegetables and hummus",
                    imageName: "recipe_wrap_rainbow_veggie",
                    category: .lunch,
                    cookTime: 15,
                    difficulty: .easy,
                    servings: 2,
                    needsAdultHelp: false,
                    nutritionFacts: ["Vitamin A", "Fiber", "Protein"]
                )
            )
        }
    }

    // MARK: - Helpers

    var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        case 17..<21: return "Good Evening,"
        default: return "Hello,"
        }
    }

    func cyclePipMessage() {
        let messages: [(String, PipPose)] = [
            ("Tap me anytime if you need help!", .waving),
            ("Did you know carrots help you see better?", .thinking),
            ("I love cooking with you!", .excited),
            ("Let's make something healthy today!", .cooking),
            ("You're doing amazing, chef!", .celebrating)
        ]

        let random = messages.randomElement()!

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            pipPose = random.1
            pipMessage = random.0
        }
    }
}

// MARK: - Animated Streak Card (iPad Responsive)

struct StreakCardAnimated: View {
    let streak: Int
    @State private var flamesAnimating = false
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🔥 Daily Streak")
                    .font(sizeClass == .compact ? .AppTheme.headline : .AppTheme.title3)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("\(streak) days")
                    .font(sizeClass == .compact ? .AppTheme.title : .AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.goldenWheat)
            }

            Spacer()

            // Animated streak flames
            HStack(spacing: sizeClass == .compact ? -5 : -3) {
                ForEach(0..<min(max(streak, 1), 7), id: \.self) { index in
                    Text("🔥")
                        .font(.system(size: sizeClass == .compact ? 20 : 28))
                        .scaleEffect(flamesAnimating ? 1.1 : 0.9)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                            value: flamesAnimating
                        )
                }
            }
        }
        .padding(sizeClass == .compact ? AppSpacing.md : AppSpacing.lg)
        .background(Color.AppTheme.warmCream)
        .cornerRadius(AppSpacing.cardCornerRadius)
        .onAppear {
            flamesAnimating = true
        }
    }
}

// MARK: - Pip Message with Animated Video (iPad Responsive)

struct PipMessageAnimated: View {
    let pose: PipPose
    let message: String

    @State private var messageVisible = true
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Animated Pip Video - larger on iPad
            VideoPlayerWithFallback(
                videoName: "pip_waving",
                fallbackImage: "pip_waving",
                size: AdaptiveCardSize.pipMessage(for: sizeClass),
                circular: true,
                borderColor: Color.AppTheme.sage,
                borderWidth: sizeClass == .compact ? 2 : 3
            )

            // Message bubble
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Pip")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sage)

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
        .onChange(of: message) { oldMessage, newMessage in
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

// MARK: - Animated Quick Action Card (iPad Responsive)

struct QuickActionCardAnimated: View {
    let icon: String
    let title: String
    let color: Color
    var sizeClass: UserInterfaceSizeClass? = .compact
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        let isCompact = sizeClass == .compact
        let cardWidth = AdaptiveCardSize.quickAction(for: sizeClass)
        let iconSize = AdaptiveCardSize.quickActionIcon(for: sizeClass)
        let emojiSize = AdaptiveCardSize.quickActionEmoji(for: sizeClass)

        Button(action: action) {
            VStack(spacing: isCompact ? AppSpacing.sm : AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: iconSize, height: iconSize)

                    Text(icon)
                        .font(.system(size: emojiSize))
                }

                Text(title)
                    .font(isCompact ? .AppTheme.caption : .AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: cardWidth)
            .padding(isCompact ? AppSpacing.sm : AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Quick Action Card with Background Image (iPad Responsive)

struct QuickActionCardWithImage: View {
    let title: String
    let imageName: String
    let color: Color
    var sizeClass: UserInterfaceSizeClass? = .compact
    let action: () -> Void

    var body: some View {
        let isCompact = sizeClass == .compact
        let cardWidth = AdaptiveCardSize.quickAction(for: sizeClass)
        let iconSize = AdaptiveCardSize.quickActionIcon(for: sizeClass)

        Button(action: action) {
            VStack(spacing: isCompact ? AppSpacing.sm : AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: iconSize, height: iconSize)

                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: iconSize - 10,
                            height: iconSize - 10
                        )
                        .clipShape(Circle())
                }

                Text(title)
                    .font(isCompact ? .AppTheme.caption : .AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: cardWidth)
            .padding(isCompact ? AppSpacing.sm : AppSpacing.md)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Preview

#Preview("iPhone") {
    HomeAnimatedView(avatarModel: {
        let model = AvatarModel()
        model.name = "Emma"
        model.currentStreak = 5
        return model
    }())
}

#Preview("iPad") {
    HomeAnimatedView(avatarModel: {
        let model = AvatarModel()
        model.name = "Emma"
        model.currentStreak = 5
        return model
    }())
    .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch)"))
}
