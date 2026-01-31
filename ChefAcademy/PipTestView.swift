//
//  PipTestView.swift
//  ChefAcademy
//
//  A test view to display all 6 Pip poses in a grid.
//  Tap any Pip to see the breathing/idle animation!
//

import SwiftUI

struct PipTestView: View {

    // Track which Pip is currently selected (has active animation)
    @State private var selectedPose: PipPose? = nil

    // Grid layout: 2 columns
    let columns = [
        GridItem(.flexible(), spacing: AppSpacing.lg),
        GridItem(.flexible(), spacing: AppSpacing.lg)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // Header
                    Text("Tap a Pip to see the breathing animation!")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Grid of all Pip poses
                    LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                        ForEach(PipPose.allCases, id: \.self) { pose in
                            PipGridItem(
                                pose: pose,
                                isSelected: selectedPose == pose,
                                onTap: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPose = pose
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Selected pose info
                    if let pose = selectedPose {
                        VStack(spacing: AppSpacing.xs) {
                            Text("Selected: \(pose.rawValue.replacingOccurrences(of: "pip_", with: "").capitalized)")
                                .font(.AppTheme.headline)
                                .foregroundColor(Color.AppTheme.darkBrown)

                            Text(pose.description)
                                .font(.AppTheme.caption)
                                .foregroundColor(Color.AppTheme.sepia)
                        }
                        .padding()
                        .background(Color.AppTheme.warmCream)
                        .cornerRadius(AppSpacing.cardCornerRadius)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer(minLength: 50)
                }
                .padding(.top, AppSpacing.md)
            }
            .background(Color.AppTheme.cream)
            .navigationTitle("Meet Pip!")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Pip Grid Item
//
// Individual Pip in the grid with circle mask and sage border
//

struct PipGridItem: View {
    let pose: PipPose
    let isSelected: Bool
    let onTap: () -> Void

    // Breathing animation state
    @State private var breatheOffset: CGFloat = 0
    @State private var isBreathing = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.sm) {

                // Pip image with circle mask
                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.AppTheme.warmCream)
                        .frame(width: 130, height: 130)

                    // Pip image
                    Image(pose.rawValue)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .offset(y: isSelected ? breatheOffset : 0)

                    // Sage green border
                    Circle()
                        .stroke(
                            isSelected ? Color.AppTheme.sage : Color.AppTheme.sage.opacity(0.5),
                            lineWidth: isSelected ? 4 : 2
                        )
                        .frame(width: 130, height: 130)
                }
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .shadow(
                    color: isSelected ? Color.AppTheme.sage.opacity(0.3) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )

                // Pose name
                Text(poseName)
                    .font(.AppTheme.headline)
                    .foregroundColor(isSelected ? Color.AppTheme.darkBrown : Color.AppTheme.sepia)

                // Emoji indicator for selected
                if isSelected {
                    Text(poseEmoji)
                        .font(.system(size: 20))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                startBreathingAnimation()
            } else {
                stopBreathingAnimation()
            }
        }
    }

    // MARK: - Breathing Animation

    private func startBreathingAnimation() {
        isBreathing = true
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            breatheOffset = -6
        }
    }

    private func stopBreathingAnimation() {
        isBreathing = false
        withAnimation(.easeOut(duration: 0.3)) {
            breatheOffset = 0
        }
    }

    // MARK: - Helpers

    var poseName: String {
        pose.rawValue
            .replacingOccurrences(of: "pip_", with: "")
            .capitalized
    }

    var poseEmoji: String {
        switch pose {
        case .neutral: return "😊"
        case .waving: return "👋"
        case .excited: return "🎉"
        case .cooking: return "👨‍🍳"
        case .thinking: return "🤔"
        case .celebrating: return "🏆"
        }
    }
}

// MARK: - Preview

#Preview {
    PipTestView()
}
