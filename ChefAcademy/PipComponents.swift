//
//  PipComponents.swift
//  ChefAcademy
//
//  Reusable Pip mascot UI components.
//  Replaces 25+ inline `Image("pip_...")` + text layouts scattered across views.
//

import SwiftUI

// Uses PipPose enum from PipAnimations.swift (13 poses).
// Its .rawValue IS the imageset name (e.g. "pip_got_idea").

// MARK: - Pip Size
// Canonical mascot sizes — keeps Pip visually consistent across the app.
// Before: 36/40/55/60/80/90/100/120/160 pt (all different).
// After:  4 standard sizes. Per-site .custom(...) escape hatch for outliers.
enum PipSize {
    case compact  // 40pt — chat bubbles, inline nudges
    case medium   // 80pt — versus-screen headers, mid-scene cues
    case large    // 120pt — wizard headers, game-over cards
    case hero     // 160pt — welcome / celebration moments
    case custom(CGFloat)

    var points: CGFloat {
        switch self {
        case .compact:      return 40
        case .medium:       return 80
        case .large:        return 120
        case .hero:         return 160
        case .custom(let v): return v
        }
    }
}

// MARK: - Pip Speech Bubble (Pattern A — inline)
// Pip avatar on the left, speech card on the right.
// Used in chat views, toast messages, inline dialog cues.
//
// Example:
//   PipSpeechBubble(message: "Great job!")
//   PipSpeechBubble(message: "Hmm...", pose: .thinking, hasTail: true)
//
struct PipSpeechBubble: View {
    let message: String
    var pose: PipPose = .gotIdea
    var size: PipSize = .compact
    var showsLabel: Bool = true
    var tintBackground: Bool = true
    var hasTail: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                if showsLabel {
                    Text("Pip")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sage)
                }
                Text(message)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .modifier(SpeechTail(enabled: hasTail))
        }
    }

    @ViewBuilder
    private var avatar: some View {
        let d = size.points
        Image(pose.rawValue)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: d, height: d)
            .clipShape(Circle())
            .background(
                Group {
                    if tintBackground {
                        Circle()
                            .fill(Color.AppTheme.sage.opacity(0.2))
                            .frame(width: d + 4, height: d + 4)
                    }
                }
            )
    }
}

// Tail notch — only applied when enabled. Uses the existing
// cornerRadius(_:corners:) extension defined in AvatarCreatorView.swift.
private struct SpeechTail: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.cornerRadius(4, corners: [.topLeft])
        } else {
            content
        }
    }
}

// MARK: - Pip Header Stack (Pattern B — big Pip above title)
// Used in wizard screens, intros, onboarding, welcome moments.
//
// Example:
//   PipHeaderStack(title: "Welcome Back!", subtitle: "Ready to cook?")
//   PipHeaderStack(title: "Meet Pip!", pose: .waving, size: .hero)
//
struct PipHeaderStack: View {
    let title: String
    var subtitle: String? = nil
    var pose: PipPose = .gotIdea
    var size: PipSize = .large
    var clipToCircle: Bool = true
    var strokeBorder: Bool = false

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            avatar
            Text(title)
                .font(.AppTheme.title)
                .foregroundColor(Color.AppTheme.darkBrown)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        let d = size.points
        let img = Image(pose.rawValue)
            .resizable()
            .aspectRatio(contentMode: clipToCircle ? .fill : .fit)
            .frame(width: d, height: d)
        if clipToCircle {
            if strokeBorder {
                img
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.AppTheme.sage, lineWidth: AppSpacing.strokeBold))
            } else {
                img.clipShape(Circle())
            }
        } else {
            img
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: AppSpacing.xl) {
            Text("Pip Components")
                .font(.AppTheme.largeTitle)
                .foregroundColor(Color.AppTheme.darkBrown)

            // Speech Bubble variants
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Speech Bubbles (.compact)")
                    .font(.AppTheme.headline)
                PipSpeechBubble(message: "Great job on that recipe!")
                PipSpeechBubble(message: "Hmm, let me think...", pose: .thinking)
                PipSpeechBubble(message: "Ready to cook?", pose: .cooking, hasTail: true)
                PipSpeechBubble(message: "No label version.", showsLabel: false)
                PipSpeechBubble(message: "No tint.", tintBackground: false)
            }
            .padding(AppSpacing.md)

            // Header Stack variants
            VStack(spacing: AppSpacing.md) {
                Text("Header Stacks")
                    .font(.AppTheme.headline)

                PipHeaderStack(
                    title: "Welcome Back!",
                    subtitle: "Your garden is waiting.",
                    pose: .gotIdea
                )

                PipHeaderStack(
                    title: "Meet Pip!",
                    subtitle: "Your cooking buddy.",
                    pose: .waving,
                    size: .hero
                )

                PipHeaderStack(title: "Enter your PIN", pose: .thinking, size: .medium)
            }
            .padding(AppSpacing.md)
        }
    }
    .background(Color.AppTheme.cream)
}
