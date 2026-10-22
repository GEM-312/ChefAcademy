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
    var tintBackground: Bool = true
    var hasTail: Bool = false
    /// Read `message` aloud when the bubble first appears AND whenever
    /// `message` changes. Default `true` because every existing call site
    /// in the app uses this for live dialog (chat replies, kitchen prompts).
    /// Pass `false` for static decorative usage where audio would be noise.
    var speakOnAppear: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.darkBrown)
            }
            .padding(AppSpacing.sm)
            .background(Color.AppTheme.warmCream)
            .cornerRadius(AppSpacing.cardCornerRadius)
            .modifier(SpeechTail(enabled: hasTail))
        }
        .onAppear {
            if speakOnAppear { PipVoice.shared.speak(message) }
        }
        .onChange(of: message) { _, new in
            if speakOnAppear { PipVoice.shared.speak(new) }
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

// MARK: - Pip "Tap me!" Tag
// Small pill under a scene Pip whose speech bubble opens when he's tapped
// (Kitchen, Home map, Shop). Same look as the kitchen station labels.
// Show it only while the bubble is closed.
struct PipTapMeTag: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Text("Tap me!")
            .font(.AppTheme.rounded(size: AdaptiveCardSize.kitchenSpotLabelSize(for: sizeClass), weight: .semibold))
            .foregroundColor(Color.AppTheme.sage)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(Color.AppTheme.warmCream.opacity(0.9))
            .cornerRadius(AppSpacing.pillCornerRadius)
            .fixedSize()   // one line, even under a small Pip
    }
}

extension View {
    /// Hangs the "Tap me!" tag just below this Pip: the tag's top edge sits on
    /// his bottom edge, so it never covers him.
    func pipTapMeTag(isShown: Bool) -> some View {
        overlay(alignment: .bottom) {
            if isShown {
                PipTapMeTag()
                    .alignmentGuide(.bottom) { $0[.top] }
            }
        }
    }
}

// MARK: - Pip Bubble Close Button
// The ✕ on a Pip speech bubble (Kitchen / Home / Shop bubbles, Garden message).
// The icon is small but the tap area is 44pt: the inner padding grows the
// button, the outer negative padding keeps it from pushing the text.
struct PipBubbleCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.AppTheme.title3)
                .foregroundColor(Color.AppTheme.lightSepia)
                .padding(AppSpacing.sm)
        }
        .buttonStyle(BouncyButtonStyle())
        .padding(-AppSpacing.sm)
        .accessibilityLabel("Close")
    }
}

// MARK: - Pip First-Time Instructions
// Pip's bubble opens by itself only the first time a player uses a feature;
// after that it waits for a tap. One flag per player profile, kept in
// UserDefaults on this device (no SwiftData field, so no model migration).
// A reinstall shows the instructions once more, which is harmless.
//
// The rawValue is part of the storage key — never rename a case (§5).
enum PipTutorial: String {
    case kitchenCooking
    case shop
    // Cooking mini-game skills: one per mini-game the kid has to learn.
    // Learned when the kid finishes that mini-game once (CookingSessionView).
    case cookHeatPan, cookAddToPan, cookWash, cookPeel, cookChop
    case cookCrack, cookStir, cookSeason, cookTimer, cookAssemble
    // Garden tools: the first time a kid needs each tool, Pip explains it.
    case gardenFork, gardenShovel, gardenWateringCan
    // Garden jobs: a spot's label ("Loosen!", "Water me!"…) guides the kid
    // until they've done that job once (GardenView marks them).
    case gardenLoosened, gardenPlanted, gardenWatered
    case gardenWeeded, gardenBugsRescued, gardenHarvested

    /// The job guide for what a garden spot needs now (nil while it grows).
    static func gardenGuide(for plot: GardenPlot) -> PipTutorial? {
        switch plot.state {
        case .empty:        return plot.soilLoosened ? .gardenPlanted : .gardenLoosened
        case .needsWater:   return .gardenWatered
        case .needsWeeding: return .gardenWeeded
        case .hasBugs:      return .gardenBugsRescued
        case .ready:        return .gardenHarvested
        case .growing:      return nil
        }
    }

    private func key(for profileID: UUID?) -> String {
        "pipTutorial_\(rawValue)_\(profileID?.uuidString ?? "legacy")"
    }

    func isDone(for profileID: UUID?) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: profileID))
    }

    func markDone(for profileID: UUID?) {
        UserDefaults.standard.set(true, forKey: key(for: profileID))
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
    /// Read `title` (and `subtitle` if provided) aloud once when shown.
    /// Onboarding / wizard headers benefit; pass `false` for static page chrome.
    var speakOnAppear: Bool = true

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
        .onAppear {
            if speakOnAppear {
                let combined = subtitle.map { "\(title). \($0)" } ?? title
                PipVoice.shared.speak(combined)
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

// MARK: - PIN Pad Components
//
// Used by ParentPINEntryView, FamilySetupView (FamilyPINStep), and MigrationPINSetupView.
// Each call site passes a `leading` view (Cancel / Back / empty spacer) and a `trailing`
// view (typically the delete button). The 3×3 digit grid and "0" key are baked in.
//

/// Single PIN digit button — sized by AppSpacing.pinButtonWidth/Height tokens.
struct PINButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.AppTheme.rounded(size: 28, weight: .medium))
                .foregroundColor(Color.AppTheme.darkBrown)
                .frame(width: AppSpacing.pinButtonWidth, height: AppSpacing.pinButtonHeight)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(AppSpacing.smallCornerRadius)
        }
        .buttonStyle(.plain)
    }
}

/// 3×3 PIN digit grid plus a bottom row with [leading] [0] [trailing].
/// Use the `leading` slot for Cancel/Back/empty spacer; `trailing` for delete.
struct PINPadGrid<Leading: View, Trailing: View>: View {
    let onDigit: (String) -> Void
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: AppSpacing.lg) {
                    ForEach(1...3, id: \.self) { col in
                        let n = row * 3 + col
                        PINButton(label: "\(n)") { onDigit("\(n)") }
                    }
                }
            }
            HStack(spacing: AppSpacing.lg) {
                leading()
                PINButton(label: "0") { onDigit("0") }
                trailing()
            }
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
