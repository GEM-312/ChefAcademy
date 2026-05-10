//
//  ChopMiniGame.swift
//  ChefAcademy
//
//  CHOP MINI-GAME: Tap at the right moment to chop vegetables!
//  This is one of the cooking mini-games in the COOK phase.
//
//  How it works:
//  1. A knife moves back and forth above a vegetable
//  2. There's a "sweet spot" in the center
//  3. Tap when the knife is in the sweet spot for Perfect!
//  4. Chop multiple times to complete the recipe step
//

import SwiftUI


// MARK: - Chop Mini Game

struct ChopMiniGame: View {

    // What vegetable are we chopping?
    let vegetable: VegetableType

    // How many chops needed to complete?
    let targetChops: Int

    // Called when the mini-game is complete with a score (0-100)
    let onComplete: (Int) -> Void

    // MARK: - Game State

    // How many successful chops so far
    @State private var chopCount = 0

    // Total score accumulated
    @State private var totalScore = 0

    // Knife position (0.0 = left, 0.5 = center, 1.0 = right)
    @State private var knifePosition: CGFloat = 0.0

    // Is the knife moving right? (for oscillation)
    @State private var movingRight = true

    // Current result text ("Perfect!", "Good!", etc.)
    @State private var resultText = ""
    @State private var showResult = false

    // Is the game complete?
    @State private var isComplete = false

    // Animation timer
    @State private var timer: Timer?

    // Did the vegetable just get chopped? (for animation)
    @State private var justChopped = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {

            // MARK: - Header
            headerView

            // MARK: - Game Area
            gameArea

            // MARK: - Progress
            progressView

            // MARK: - Instructions
            if !isComplete {
                instructionText
            }
        }
        .padding()
        .background(Color.AppTheme.cream)
        .onAppear {
            startGame()
            // Switch the cooking ambient to the chopping loop while
            // this mini-game is active. CookingSessionView restored it
            // to the frying ambient when this view disappears.
            AmbientAudioPlayer.shared.play(.chopping)
        }
        .onDisappear {
            timer?.invalidate()
            // Hand the ambient back to the cooking session's frying loop.
            AmbientAudioPlayer.shared.play(.cookingFrying)
        }
    }

    // MARK: - Header View

    var headerView: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("Chop the \(vegetable.displayName)!")
                .font(.AppTheme.title)
                .foregroundColor(Color.AppTheme.darkBrown)

            // Star rating hint
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { star in
                    Image(systemName: starImageName(for: star))
                        .foregroundColor(Color.AppTheme.goldenWheat)
                }
            }
        }
    }

    // MARK: - Game Area

    var gameArea: some View {
        ZStack {
            // Background - cutting board image
            Image("cutting_board")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.largeCornerRadius))
                .shadow(color: Color.AppTheme.sepia.opacity(0.15), radius: 6, y: 3)

            VStack(spacing: 0) {
                // MARK: Sweet Spot Indicator
                sweetSpotIndicator
                    .padding(.bottom, AppSpacing.sm)

                // MARK: Knife
                knifeView
                    .padding(.bottom, AppSpacing.md)

                // MARK: Vegetable
                vegetableView
            }

            // MARK: Result Popup
            if showResult {
                resultPopup
            }
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            if !isComplete {
                handleChop()
            }
        }
    }

    // MARK: - Sweet Spot Indicator

    var sweetSpotIndicator: some View {
        GeometryReader { geometry in
            ZStack {
                // Track background
                Capsule()
                    .fill(Color.AppTheme.sepia.opacity(0.3))
                    .frame(height: 8)

                // Sweet spot (center green zone)
                Capsule()
                    .fill(Color.AppTheme.sage)
                    .frame(width: geometry.size.width * 0.2, height: 8)

                // Current position indicator
                Circle()
                    .fill(Color.AppTheme.goldenWheat)
                    .frame(width: 16, height: 16)
                    .offset(x: (knifePosition - 0.5) * geometry.size.width)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
        .frame(height: 16)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Knife View

    var knifeView: some View {
        GeometryReader { geometry in
            Image("knife")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 50)
                .rotationEffect(.degrees(-45))
                .shadow(color: Color.AppTheme.sepia.opacity(0.3), radius: 3, y: 2)
                .offset(x: (knifePosition - 0.5) * (geometry.size.width - 60))
                .offset(y: justChopped ? 20 : 0) // Chop animation
                .animation(.easeOut(duration: 0.1), value: justChopped)
        }
        .frame(height: 60)
    }

    // MARK: - Vegetable View

    var vegetableView: some View {
        HStack(spacing: 4) {
            // Show chopped pieces based on progress
            ForEach(0..<min(chopCount, targetChops), id: \.self) { _ in
                Image(vegetable.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .opacity(0.6)
            }

            // Remaining whole vegetable (if not all chopped)
            if chopCount < targetChops {
                Image(vegetable.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .scaleEffect(justChopped ? 0.8 : 1.0)
                    .animation(AnimationConstants.springSnappy, value: justChopped)
            }
        }
        .frame(height: 60)
    }

    // MARK: - Result Popup

    var resultPopup: some View {
        Text(resultText)
            .font(.AppTheme.title)
            .fontWeight(.bold)
            .foregroundColor(resultColor)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.AppTheme.cream.opacity(0.9))
            .cornerRadius(AppSpacing.smallCornerRadius)
            .scaleEffect(showResult ? 1.0 : 0.5)
            .opacity(showResult ? 1.0 : 0.0)
            .animation(AnimationConstants.springQuick, value: showResult)
    }

    // MARK: - Progress View

    var progressView: some View {
        VStack(spacing: AppSpacing.xs) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.AppTheme.parchment)

                    // Progress fill
                    Capsule()
                        .fill(Color.AppTheme.sage)
                        .frame(width: geometry.size.width * CGFloat(chopCount) / CGFloat(targetChops))
                }
            }
            .frame(height: 12)

            // Chop count
            Text("\(chopCount) / \(targetChops) chops")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Instruction Text

    var instructionText: some View {
        Text("Tap when the marker is in the green zone!")
            .font(.AppTheme.callout)
            .foregroundColor(Color.AppTheme.sepia)
            .multilineTextAlignment(.center)
    }

    // MARK: - Game Logic

    func startGame() {
        // Start the knife oscillation.
        // Mutations to @State (knifePosition, movingRight) inside updateKnifePosition()
        // must run on the main actor — Timer callbacks fire on an unspecified thread.
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            Task { @MainActor in
                updateKnifePosition()
            }
        }
    }

    func updateKnifePosition() {
        // Move knife back and forth
        let speed: CGFloat = 0.015

        if movingRight {
            knifePosition += speed
            if knifePosition >= 1.0 {
                movingRight = false
            }
        } else {
            knifePosition -= speed
            if knifePosition <= 0.0 {
                movingRight = true
            }
        }
    }

    func handleChop() {
        // Calculate score based on position
        // Perfect: within 0.1 of center (0.5)
        // Good: within 0.2 of center
        // Okay: within 0.3 of center
        // Miss: outside 0.3

        let distanceFromCenter = abs(knifePosition - 0.5)

        var chopScore: Int
        var result: String

        if distanceFromCenter <= 0.1 {
            chopScore = 100
            result = "Perfect!"
            Haptic.impact(.rigid)   // sharp perfect chop
        } else if distanceFromCenter <= 0.2 {
            chopScore = 75
            result = "Great!"
            Haptic.impact(.heavy)   // solid chop
        } else if distanceFromCenter <= 0.3 {
            chopScore = 50
            result = "Good!"
            Haptic.impact(.medium)
        } else {
            chopScore = 25
            result = "Okay"
            Haptic.impact(.light)   // weak chop
        }

        // Update state
        chopCount += 1
        totalScore += chopScore
        resultText = result

        // Trigger animations
        withAnimation {
            showResult = true
            justChopped = true
        }

        // Hide result after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showResult = false
                justChopped = false
            }
        }

        // Check if complete
        if chopCount >= targetChops {
            completeGame()
        }
    }

    func completeGame() {
        timer?.invalidate()
        isComplete = true

        // Calculate final score (average)
        let finalScore = totalScore / targetChops

        // Delay then call completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onComplete(finalScore)
        }
    }

    // MARK: - Helpers

    var resultColor: Color {
        switch resultText {
        case "Perfect!": return Color.AppTheme.sage
        case "Great!": return Color.AppTheme.goldenWheat
        case "Good!": return Color.AppTheme.terracotta
        default: return Color.AppTheme.sepia
        }
    }

    func starImageName(for index: Int) -> String {
        let averageScore = chopCount > 0 ? totalScore / chopCount : 0

        if index == 0 {
            return averageScore >= 25 ? "star.fill" : "star"
        } else if index == 1 {
            return averageScore >= 60 ? "star.fill" : "star"
        } else {
            return averageScore >= 85 ? "star.fill" : "star"
        }
    }
}

// MARK: - Preview

#Preview {
    ChopMiniGame(
        vegetable: .carrot,
        targetChops: 5,
        onComplete: { score in
            print("Game complete! Score: \(score)")
        }
    )
}
