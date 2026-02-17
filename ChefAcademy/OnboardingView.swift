//
//  OnboardingView.swift
//  ChefAcademy
//
//  Created by Pollak Marina on 1/26/26.
//

import SwiftUI
import Combine

// MARK: - Onboarding Flow Manager
class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isOnboardingComplete: Bool = false

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case chooseGender = 1
        case createAvatar = 2
        case nameAvatar = 3
        case meetPip = 4
        case ready = 5
    }

    func nextStep() {
        let allSteps = OnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex < allSteps.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = allSteps[currentIndex + 1]
            }
        }
    }

    func previousStep() {
        let allSteps = OnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = allSteps[currentIndex - 1]
            }
        }
    }

    func completeOnboarding() {
        isOnboardingComplete = true
        // Save to UserDefaults
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @ObservedObject var avatarModel: AvatarModel  // Passed from App, not created here
    @Binding var isOnboardingComplete: Bool

    var body: some View {
        ZStack {
            // Background
            Color.AppTheme.cream
                .ignoresSafeArea()

            // Content based on current step
            switch onboardingManager.currentStep {
            case .welcome:
                WelcomeView(onboardingManager: onboardingManager)

            case .chooseGender:
                GenderSelectionView(
                    avatarModel: avatarModel,
                    onboardingManager: onboardingManager
                )

            case .createAvatar:
                AvatarCreatorView(
                    avatarModel: avatarModel,
                    onboardingManager: onboardingManager
                )

            case .nameAvatar:
                NameAvatarView(
                    avatarModel: avatarModel,
                    onboardingManager: onboardingManager
                )

            case .meetPip:
                MeetPipView(
                    avatarModel: avatarModel,
                    onboardingManager: onboardingManager
                )

            case .ready:
                ReadyToStartView(
                    avatarModel: avatarModel,
                    onComplete: {
                        onboardingManager.completeOnboarding()
                        isOnboardingComplete = true
                    }
                )
            }
        }
    }
}

// MARK: - Step 1: Welcome View
struct WelcomeView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var showContent = false
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Pip Static Image - Neutral pose for welcome
            VStack(spacing: AppSpacing.sm) {
                Image("pip_neutral")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: AdaptiveCardSize.pipOnboarding(for: sizeClass),
                        height: AdaptiveCardSize.pipOnboarding(for: sizeClass)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.AppTheme.sage, lineWidth: AdaptiveCardSize.pipBorderWidth(for: sizeClass))
                    )

                Text("Pip")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.cream)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.AppTheme.sage)
                    .cornerRadius(20)
            }
            .scaleEffect(showContent ? 1 : 0.5)
            .opacity(showContent ? 1 : 0)

            VStack(spacing: AppSpacing.sm) {
                Text("Welcome to")
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.sepia)

                Text("Pip's Kitchen Garden")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Text("Feed your body, fuel your adventure!")
                .font(.AppTheme.body)
                .foregroundColor(Color.AppTheme.sepia)
                .italic()
                .opacity(showContent ? 1 : 0)

            Spacer()

            // Start Button
            Button(action: {
                onboardingManager.nextStep()
            }) {
                HStack {
                    Text("Let's Begin!")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppSpacing.xl)
            .opacity(showContent ? 1 : 0)

            Spacer()
                .frame(height: AppSpacing.xxl)
        }
        .padding()
        .background(Color.AppTheme.cream)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
}

// MARK: - Step 2: Gender Selection View
struct GenderSelectionView: View {
    @ObservedObject var avatarModel: AvatarModel
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var showContent = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Header
            VStack(spacing: AppSpacing.xs) {
                Text("Who are you?")
                    .font(.AppTheme.title)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("Choose your character")
                    .font(.AppTheme.subheadline)
                    .foregroundColor(Color.AppTheme.sepia)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer()

            // Two character cards side by side
            HStack(spacing: AppSpacing.lg) {
                GenderCard(
                    gender: .boy,
                    isSelected: avatarModel.gender == .boy
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        avatarModel.gender = .boy
                    }
                }

                GenderCard(
                    gender: .girl,
                    isSelected: avatarModel.gender == .girl
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        avatarModel.gender = .girl
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)

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
                    onboardingManager.nextStep()
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.AppTheme.cream)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }
}

// MARK: - Gender Card (Animated)
struct GenderCard: View {
    let gender: Gender
    let isSelected: Bool
    let onTap: () -> Void

    // Frame animation
    @State private var frameIndex: Int = 0
    @State private var animTimer: Timer? = nil

    private var frameNames: [String] {
        if gender == .boy {
            return (1...28).map { String(format: "boy_card_frame_%02d", $0) }
        } else {
            return (1...15).map { String(format: "girl_card_frame_%02d", $0) }
        }
    }

    private var fps: Double {
        // Boy: 28 frames over ~1.15s ≈ 24fps, Girl: 15 frames over ~0.59s ≈ 24fps
        // Slow it down a bit for a gentle feel
        return 10
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.sm) {
                // Animated character from video frames
                Image(frameNames[frameIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(gender.rawValue)
                    .font(.AppTheme.title3)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.AppTheme.sage.opacity(0.2) : Color.AppTheme.warmCream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.AppTheme.sage : Color.clear, lineWidth: 3)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            animTimer?.invalidate()
            animTimer = nil
        }
    }

    private func startAnimation() {
        animTimer?.invalidate()
        frameIndex = 0
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { timer in
            if frameIndex < frameNames.count - 1 {
                frameIndex += 1
            } else {
                timer.invalidate()
                animTimer = nil
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(
        avatarModel: AvatarModel(),
        isOnboardingComplete: .constant(false)
    )
}
