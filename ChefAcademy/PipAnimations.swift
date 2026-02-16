import SwiftUI

// MARK: - Pip Waving Frame Animation
/// Cycles through 15 transparent-background PNG frames for a natural waving animation.
/// No circle, no border — Pip appears with transparent background.
struct PipWavingAnimatedView: View {
    var size: CGFloat = 200

    private let frameNames: [String] = (1...15).map { String(format: "pip_waving_frame_%02d", $0) }
    private let fps: Double = 6.0 // smooth wave
    private let pauseBetweenWaves: Double = 3.0

    @State private var currentFrame = 0
    @State private var timer: Timer?
    @State private var isPaused = false

    var body: some View {
        Image(frameNames[currentFrame])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .opacity(0.9)
            .onAppear { startAnimation() }
            .onDisappear { stopAnimation() }
    }

    private func startAnimation() {
        scheduleNextFrame()
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextFrame() {
        let delay = isPaused ? pauseBetweenWaves : (1.0 / fps)
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            if isPaused {
                isPaused = false
                currentFrame = 0
                scheduleNextFrame()
            } else {
                let nextFrame = currentFrame + 1
                if nextFrame >= frameNames.count {
                    // Wave finished — pause before next wave
                    isPaused = true
                    scheduleNextFrame()
                } else {
                    currentFrame = nextFrame
                    scheduleNextFrame()
                }
            }
        }
    }
}

// MARK: - Pip Pose Enum
enum PipPose: String, CaseIterable {
    case neutral = "pip_neutral"
    case waving = "pip_waving"
    case excited = "pip_excited"
    case cooking = "pip_cooking"
    case thinking = "pip_thinking"
    case celebrating = "pip_celebrating"
    
    /// Suggested use cases for each pose
    var description: String {
        switch self {
        case .neutral: return "Default state, listening"
        case .waving: return "Welcome, greetings"
        case .excited: return "Positive feedback, achievements"
        case .cooking: return "Recipe screens, cooking steps"
        case .thinking: return "Quiz questions, loading"
        case .celebrating: return "Badge earned, recipe complete"
        }
    }
}

// MARK: - Animated Pip Character View
struct PipCharacterView: View {
    let pose: PipPose
    var size: CGFloat = 200
    var showBounce: Bool = true
    
    @State private var isAnimating = false
    @State private var bounceOffset: CGFloat = 0
    
    var body: some View {
        Image(pose.rawValue)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .offset(y: bounceOffset)
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.0)
            .onAppear {
                // Entrance animation
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    isAnimating = true
                }
                
                // Start idle bounce if enabled
                if showBounce {
                    startIdleBounce()
                }
            }
            .onChange(of: pose) { oldPose, newPose in
                // Animate pose change
                triggerPoseChangeAnimation()
            }
    }
    
    private func startIdleBounce() {
        // Gentle breathing/idle animation
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            bounceOffset = -5
        }
    }
    
    private func triggerPoseChangeAnimation() {
        // Quick scale down and up for pose change
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            isAnimating = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Pip with Speech Bubble
struct PipWithDialogue: View {
    let pose: PipPose
    let message: String
    var pipSize: CGFloat = 180
    
    @State private var showMessage = false
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Pip Character
            PipCharacterView(pose: pose, size: pipSize)
            
            // Pip name badge
            Text("Pip")
                .font(.AppTheme.headline)
                .foregroundColor(Color.AppTheme.cream)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.AppTheme.sage)
                .cornerRadius(20)
            
            // Speech bubble
            VStack {
                Text(message)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
                    .padding(AppSpacing.md)
            }
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .opacity(showMessage ? 1 : 0)
            .offset(y: showMessage ? 0 : 20)
        }
        .onAppear {
            // Delay speech bubble appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showMessage = true
                }
            }
        }
        .onChange(of: message) { oldMessage, newMessage in
            // Animate message change
            withAnimation(.easeOut(duration: 0.15)) {
                showMessage = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeIn(duration: 0.2)) {
                    showMessage = true
                }
            }
        }
    }
}

// MARK: - Pip Reaction Animations
struct PipReactionView: View {
    @Binding var currentPose: PipPose
    var size: CGFloat = 200
    
    @State private var showSparkles = false
    @State private var sparkleRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Sparkles/celebration effects (shown for celebrating pose)
            if showSparkles {
                SparkleEffect()
                    .opacity(showSparkles ? 1 : 0)
            }
            
            // Pip character
            PipCharacterView(pose: currentPose, size: size)
        }
        .onChange(of: currentPose) { oldPose, newPose in
            if newPose == .celebrating || newPose == .excited {
                triggerCelebration()
            } else {
                showSparkles = false
            }
        }
    }
    
    private func triggerCelebration() {
        withAnimation(.easeIn(duration: 0.2)) {
            showSparkles = true
        }
        
        // Hide sparkles after a bit
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showSparkles = false
            }
        }
    }
}

// MARK: - Sparkle Effect
struct SparkleEffect: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<8) { index in
                Image(systemName: "sparkle")
                    .foregroundColor(Color.AppTheme.goldenWheat)
                    .font(.system(size: 20))
                    .offset(
                        x: isAnimating ? CGFloat.random(in: -80...80) : 0,
                        y: isAnimating ? CGFloat.random(in: -100...(-50)) : 0
                    )
                    .opacity(isAnimating ? 0 : 1)
                    .scaleEffect(isAnimating ? 1.5 : 0.5)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Bouncy Button Modifier
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Screen Transition Modifiers
extension AnyTransition {
    static var pipEntrance: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    static var slideFromBottom: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
}

// MARK: - Wiggle Animation Modifier
struct WiggleModifier: ViewModifier {
    @State private var isWiggling = false
    let amount: Double
    let speed: Double
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isWiggling ? amount : -amount))
            .animation(
                .easeInOut(duration: speed)
                .repeatForever(autoreverses: true),
                value: isWiggling
            )
            .onAppear {
                isWiggling = true
            }
    }
}

extension View {
    func wiggle(amount: Double = 3, speed: Double = 0.15) -> some View {
        modifier(WiggleModifier(amount: amount, speed: speed))
    }
}

// MARK: - Pulse Animation Modifier
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulse() -> some View {
        modifier(PulseModifier())
    }
}

// MARK: - Demo/Test View
struct PipAnimationDemoView: View {
    @State private var currentPose: PipPose = .neutral
    @State private var message = "Hello! Tap a button to see me change!"
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Pip with speech bubble
            PipWithDialogue(
                pose: currentPose,
                message: message,
                pipSize: 200
            )
            
            Spacer()
            
            // Pose buttons
            VStack(spacing: AppSpacing.sm) {
                Text("Try different poses:")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.sepia)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppSpacing.sm) {
                    ForEach(PipPose.allCases, id: \.self) { pose in
                        Button(action: {
                            changePose(to: pose)
                        }) {
                            Text(pose.rawValue.replacingOccurrences(of: "pip_", with: "").capitalized)
                                .font(.AppTheme.caption)
                                .foregroundColor(currentPose == pose ? Color.AppTheme.cream : Color.AppTheme.sepia)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(currentPose == pose ? Color.AppTheme.goldenWheat : Color.AppTheme.parchment)
                                .cornerRadius(8)
                        }
                        .buttonStyle(BouncyButtonStyle())
                    }
                }
            }
            .padding()
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.AppTheme.cream)
    }
    
    private func changePose(to pose: PipPose) {
        currentPose = pose
        
        // Update message based on pose
        switch pose {
        case .neutral:
            message = "I'm ready to help you cook!"
        case .waving:
            message = "Hello there, little chef! 👋"
        case .excited:
            message = "Wow, that's amazing! 🎉"
        case .cooking:
            message = "Let's make something delicious!"
        case .thinking:
            message = "Hmm, let me think about that... 🤔"
        case .celebrating:
            message = "You did it! I'm so proud of you! 🏆"
        }
    }
}

// MARK: - Preview
#Preview {
    PipAnimationDemoView()
}
