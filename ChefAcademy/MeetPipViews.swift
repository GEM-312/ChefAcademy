//
//  MeetPipViews.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

import SwiftUI
import Combine

// MARK: - Step 3: Name Your Avatar
struct NameAvatarView: View {
    @ObservedObject var avatarModel: AvatarModel
    @ObservedObject var onboardingManager: OnboardingManager
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Avatar Preview (smaller)
            AvatarPreviewView(avatarModel: avatarModel)
                .scaleEffect(0.8)
            
            // Prompt
            VStack(spacing: AppSpacing.sm) {
                Text("What's your name,")
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.sepia)
                
                Text("Little Chef?")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            
            // Name Input Field
            VStack(spacing: AppSpacing.xs) {
                TextField("Enter your name", text: $avatarModel.name)
                    .font(.AppTheme.title3)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isNameFieldFocused)
                
                Text("This is how Pip will call you!")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.lightSepia)
            }
            .padding(.horizontal, AppSpacing.xl)
            
            Spacer()
            
            // Navigation Buttons
            HStack(spacing: AppSpacing.md) {
                Button(action: {
                    onboardingManager.previousStep()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button(action: {
                    isNameFieldFocused = false
                    onboardingManager.nextStep()
                }) {
                    HStack {
                        Text("Meet Pip!")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(avatarModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(avatarModel.name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            }
            .padding(AppSpacing.md)
        }
        .background(Color.AppTheme.cream)
        .onTapGesture {
            isNameFieldFocused = false
        }
    }
}

// MARK: - Step 4: Meet Pip
struct MeetPipView: View {
    @ObservedObject var avatarModel: AvatarModel
    @ObservedObject var onboardingManager: OnboardingManager
    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var showPip = false
    @State private var showDialogue = false
    @State private var currentDialogueIndex = 0

    let dialogues: [String] = [
        "Hello there! 👋",
        "I'm Pip, and this is my Kitchen Garden!",
        "I'm so excited to cook with you!",
        "Together, we'll grow yummy vegetables...",
        "...cook delicious healthy meals...",
        "...and discover how food makes your body AMAZING! 💪",
        "Are you ready to become a super chef?"
    ]

    var body: some View {
        ZStack {
            // Background with cottage
            CottageBackground()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Animated Pip waving (frame animation, transparent bg)
                PipWavingAnimatedView(size: AdaptiveCardSize.pipOnboarding(for: sizeClass))
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
                        .overlay(
                            // Speech bubble triangle
                            Triangle()
                                .fill(Color.AppTheme.warmCream)
                                .frame(width: 20, height: 15)
                                .rotationEffect(.degrees(180))
                                .offset(y: -7),
                            alignment: .top
                        )
                        .opacity(showDialogue ? 1 : 0)
                }
                .padding(.horizontal, AppSpacing.lg)

                // Tap to continue hint
                if currentDialogueIndex < dialogues.count - 1 {
                    Text("Tap to continue...")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.lightSepia)
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
        let dialogue = dialogues[currentDialogueIndex]
        // Personalize certain dialogues
        if currentDialogueIndex == 0 && !avatarModel.name.isEmpty {
            return "Hello there, \(avatarModel.name)! 👋"
        }
        return dialogue
    }

    func startAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showPip = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                showDialogue = true
            }
        }
    }

    func advanceDialogue() {
        guard currentDialogueIndex < dialogues.count - 1 else { return }

        withAnimation(.easeOut(duration: 0.15)) {
            showDialogue = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentDialogueIndex += 1
            withAnimation(.easeIn(duration: 0.2)) {
                showDialogue = true
            }
        }
    }
}

// MARK: - Triangle Shape for Speech Bubble
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Step 5: Ready to Start
struct ReadyToStartView: View {
    @ObservedObject var avatarModel: AvatarModel
    let onComplete: () -> Void
    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var showContent = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Background
            Color.AppTheme.cream
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Celebration Header
                VStack(spacing: AppSpacing.sm) {
                    Text("🎉")
                        .font(.system(size: 60))
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

                // Pip (left) + Avatar (right)
                HStack(spacing: sizeClass == .compact ? -20 : -30) {
                    // Animated Pip waving
                    PipWavingAnimatedView(size: AdaptiveCardSize.pipReadyScreen(for: sizeClass))

                    // User's Avatar
                    ZStack {
                        Circle()
                            .fill(Color.AppTheme.parchment)
                            .frame(
                                width: sizeClass == .compact ? 120 : 180,
                                height: sizeClass == .compact ? 120 : 180
                            )

                        AvatarPreviewView(avatarModel: avatarModel)
                            .scaleEffect(sizeClass == .compact ? 0.5 : 0.7)
                    }
                }
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

                // What's Next
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("What's waiting for you:")
                        .font(.AppTheme.headline)
                        .foregroundColor(Color.AppTheme.darkBrown)

                    FeatureRow(icon: "🌱", text: "Grow vegetables in Pip's garden")
                    FeatureRow(icon: "🍳", text: "Cook yummy healthy recipes")
                    FeatureRow(icon: "🎮", text: "Play fun nutrition games")
                    FeatureRow(icon: "🏆", text: "Earn badges and rewards")
                }
                .padding(AppSpacing.lg)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.cardCornerRadius)
                .padding(.horizontal, AppSpacing.lg)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)

                Spacer()

                // Start Button
                Button(action: {
                    onComplete()
                }) {
                    HStack {
                        Text("Let's Go!")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppSpacing.xl)
                .opacity(showContent ? 1 : 0)

                Spacer()
                    .frame(height: AppSpacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(icon)
                .font(.system(size: 24))
            
            Text(text)
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
        }
    }
}

// MARK: - Previews
#Preview("Name Avatar") {
    NameAvatarView(
        avatarModel: {
            let model = AvatarModel()
            model.name = "Emma"
            return model
        }(),
        onboardingManager: OnboardingManager()
    )
}

#Preview("Meet Pip") {
    MeetPipView(
        avatarModel: {
            let model = AvatarModel()
            model.name = "Emma"
            return model
        }(),
        onboardingManager: OnboardingManager()
    )
}

#Preview("Ready to Start") {
    ReadyToStartView(
        avatarModel: {
            let model = AvatarModel()
            model.name = "Emma"
            return model
        }(),
        onComplete: {}
    )
}
