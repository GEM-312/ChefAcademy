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
        case createAvatar = 1
        case nameAvatar = 2
        case meetPip = 3
        case ready = 4
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
    @StateObject private var avatarModel = AvatarModel()
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

// MARK: - Preview
#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
