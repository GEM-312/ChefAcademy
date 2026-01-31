import SwiftUI

// MARK: - Updated Meet Pip View (with real Pip images!)
struct MeetPipAnimatedView: View {
    @ObservedObject var avatarModel: AvatarModel
    @ObservedObject var onboardingManager: OnboardingManager
    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var showPip = false
    @State private var showDialogue = false
    @State private var currentDialogueIndex = 0
    @State private var currentPose: PipPose = .waving
    
    let dialogues: [(text: String, pose: PipPose)] = [
        ("Hello there! 👋", .waving),
        ("I'm Pip, and this is my Kitchen Garden!", .neutral),
        ("I'm so excited to cook with you!", .excited),
        ("Together, we'll grow yummy vegetables...", .cooking),
        ("...cook delicious healthy meals...", .cooking),
        ("...and discover how food makes your body AMAZING! 💪", .celebrating),
        ("Are you ready to become a super chef?", .excited)
    ]
    
    var body: some View {
        ZStack {
            // MARK: - Background with cottage image
            CottageBackground()

            // MARK: - Main Content
            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Animated Pip Video
                VideoPlayerWithFallback(
                    videoName: "pip_waving",
                    fallbackImage: "pip_waving",
                    size: AdaptiveCardSize.pipOnboarding(for: sizeClass),
                    circular: true,
                    borderColor: Color.AppTheme.sage,
                    borderWidth: AdaptiveCardSize.pipBorderWidth(for: sizeClass)
                )
                .scaleEffect(showPip ? 1 : 0.3)
                .opacity(showPip ? 1 : 0)

                // Dialogue Box
                VStack(spacing: AppSpacing.md) {
                    // Pip's name tag
                    Text("Pip")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.cream)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.AppTheme.sage)
                        .cornerRadius(20)

                    // Dialogue text
                    Text(dialogueWithName)
                        .font(.AppTheme.title3)
                        .foregroundColor(Color.AppTheme.darkBrown)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 80)
                        .padding(AppSpacing.lg)
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                        .opacity(showDialogue ? 1 : 0)
                }
                .padding(.horizontal, AppSpacing.lg)

                // Tap to continue hint
                if currentDialogueIndex < dialogues.count - 1 {
                    HStack(spacing: 4) {
                        Text("Tap to continue")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.lightSepia)

                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.AppTheme.lightSepia)
                            .wiggle(amount: 5, speed: 0.3)
                    }
                    .opacity(showDialogue ? 0.7 : 0)
                }

                Spacer()

                // Continue Button (only show on last dialogue)
                if currentDialogueIndex == dialogues.count - 1 {
                    Button(action: {
                        onboardingManager.nextStep()
                    }) {
                        HStack {
                            Text("Yes! Let's Go!")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
                    .frame(height: AppSpacing.xl)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            advanceDialogue()
        }
        .onAppear {
            startAnimation()
        }
    }
    
    var dialogueWithName: String {
        let dialogue = dialogues[currentDialogueIndex].text
        // Personalize first dialogue
        if currentDialogueIndex == 0 && !avatarModel.name.isEmpty {
            return "Hello there, \(avatarModel.name)! 👋"
        }
        return dialogue
    }
    
    func startAnimation() {
        // Pip bounces in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showPip = true
        }
        
        // Speech bubble appears after Pip
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                showDialogue = true
            }
        }
    }
    
    func advanceDialogue() {
        guard currentDialogueIndex < dialogues.count - 1 else { return }
        
        // Fade out current dialogue
        withAnimation(.easeOut(duration: 0.15)) {
            showDialogue = false
        }
        
        // Change to next dialogue and pose
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentDialogueIndex += 1
            currentPose = dialogues[currentDialogueIndex].pose
            
            withAnimation(.easeIn(duration: 0.2)) {
                showDialogue = true
            }
        }
    }
}

// MARK: - Updated Ready to Start View
//
// This view appears after avatar creation, showing Pip welcoming the player.
// Now features an animated video of Pip waving!
//
struct ReadyToStartAnimatedView: View {
    @ObservedObject var avatarModel: AvatarModel
    let onComplete: () -> Void
    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var showContent = false
    @State private var showPip = false
    @State private var showAvatar = false
    @State private var showFeatures = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            // MARK: - Background with cottage image
            CottageBackground()

            // Confetti (at the top)
            if showContent {
                ConfettiView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                        .frame(height: AppSpacing.xl)

                    // Celebration Header
                    VStack(spacing: AppSpacing.sm) {
                        Text("🎉")
                            .font(.system(size: 50))
                            .scaleEffect(showContent ? 1 : 0)

                        Text("You're Ready!")
                            .font(.AppTheme.largeTitle)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        Text("Welcome to the Kitchen Garden,")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)

                        Text("Chef \(avatarModel.name.isEmpty ? "Little Chef" : avatarModel.name)!")
                            .font(.AppTheme.title)
                            .foregroundColor(Color.AppTheme.goldenWheat)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                    // Pip Waving Video - The star of the show!
                    VStack(spacing: AppSpacing.sm) {
                        // Video player with circular sage border
                        VideoPlayerWithFallback(
                            videoName: "pip_waving",
                            fallbackImage: "pip_waving",
                            size: AdaptiveCardSize.pipOnboarding(for: sizeClass),
                            circular: true,
                            borderColor: Color.AppTheme.sage,
                            borderWidth: AdaptiveCardSize.pipBorderWidth(for: sizeClass)
                        )
                        .scaleEffect(showPip ? 1 : 0.5)
                        .opacity(showPip ? 1 : 0)

                        // Pip's name badge
                        Text("Pip")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.cream)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.AppTheme.sage)
                            .cornerRadius(20)
                            .opacity(showPip ? 1 : 0)
                    }

                    // Speech bubble from Pip
                    VStack(spacing: AppSpacing.xs) {
                        Text("Hi \(avatarModel.name.isEmpty ? "friend" : avatarModel.name)! I'm so excited to cook with you!")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .multilineTextAlignment(.center)
                    }
                    .padding(AppSpacing.md)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.cardCornerRadius)
                    .padding(.horizontal, AppSpacing.lg)
                    .opacity(showPip ? 1 : 0)
                    .offset(y: showPip ? 0 : 10)

                    // What's Next
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("What's waiting for you:")
                            .font(.AppTheme.headline)
                            .foregroundColor(Color.AppTheme.darkBrown)

                        AnimatedFeatureRow(icon: "🌱", text: "Grow vegetables in Pip's garden", delay: 0)
                        AnimatedFeatureRow(icon: "🍳", text: "Cook yummy healthy recipes", delay: 0.1)
                        AnimatedFeatureRow(icon: "🎮", text: "Play fun nutrition games", delay: 0.2)
                        AnimatedFeatureRow(icon: "🏆", text: "Earn badges and rewards", delay: 0.3)
                    }
                    .padding(AppSpacing.lg)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.cardCornerRadius)
                    .padding(.horizontal, AppSpacing.lg)
                    .opacity(showFeatures ? 1 : 0)
                    .offset(y: showFeatures ? 0 : 30)

                    Spacer()
                        .frame(height: AppSpacing.lg)

                    // Let's Go Button!
                    Button(action: {
                        onComplete()
                    }) {
                        HStack(spacing: AppSpacing.sm) {
                            Text("Let's Go!")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .font(.AppTheme.title3)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.xl)
                    .scaleEffect(showButton ? 1 : 0.8)
                    .opacity(showButton ? 1 : 0)

                    Spacer()
                        .frame(height: AppSpacing.xxl)
                }
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    func startAnimationSequence() {
        // 1. Header appears
        withAnimation(.easeOut(duration: 0.5)) {
            showContent = true
        }

        // 2. Pip video appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showPip = true
            }
        }

        // 3. Features list appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFeatures = true
            }
        }

        // 4. Button bounces in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showButton = true
            }
        }
    }
}

// MARK: - Animated Feature Row
struct AnimatedFeatureRow: View {
    let icon: String
    let text: String
    let delay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(icon)
                .font(.system(size: 24))
            
            Text(text)
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = true
                }
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        ZStack {
            ForEach(confettiPieces) { piece in
                Text(piece.emoji)
                    .font(.system(size: piece.size))
                    .position(piece.position)
                    .opacity(piece.opacity)
            }
        }
        .onAppear {
            createConfetti()
        }
    }
    
    func createConfetti() {
        let emojis = ["🎉", "🎊", "⭐", "✨", "🌟", "💫"]
        
        for i in 0..<20 {
            let piece = ConfettiPiece(
                id: i,
                emoji: emojis.randomElement()!,
                size: CGFloat.random(in: 15...30),
                position: CGPoint(
                    x: CGFloat.random(in: 50...350),
                    y: CGFloat.random(in: -50...0)
                ),
                opacity: 1.0
            )
            confettiPieces.append(piece)
            
            // Animate falling
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.easeIn(duration: Double.random(in: 1.5...2.5))) {
                    if let index = confettiPieces.firstIndex(where: { $0.id == i }) {
                        confettiPieces[index].position.y += 600
                        confettiPieces[index].opacity = 0
                    }
                }
            }
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id: Int
    let emoji: String
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}

// MARK: - Preview
#Preview("Meet Pip Animated") {
    MeetPipAnimatedView(
        avatarModel: {
            let model = AvatarModel()
            model.name = "Emma"
            return model
        }(),
        onboardingManager: OnboardingManager()
    )
}

#Preview("Ready Animated") {
    ReadyToStartAnimatedView(
        avatarModel: {
            let model = AvatarModel()
            model.name = "Emma"
            return model
        }(),
        onComplete: {}
    )
}
