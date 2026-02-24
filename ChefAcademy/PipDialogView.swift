//
//  PipDialogView.swift
//  ChefAcademy
//
//  Reusable game-style dialog overlay with Pip + speech bubble + choice buttons.
//  Replaces system alerts with a whimsical, in-game dialog box.
//

import SwiftUI

// MARK: - Dialog Choice

struct PipDialogChoice {
    let label: String
    let style: Style
    let action: () -> Void

    enum Style {
        case primary    // sage bg + cream text
        case secondary  // warmCream bg + border
        case subtle     // transparent + sepia text
    }
}

// MARK: - Pip Dialog View

struct PipDialogView: View {
    let message: String
    let choices: [PipDialogChoice]

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dim overlay — blocks taps behind
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Dialog box at bottom
                HStack(alignment: .bottom, spacing: AppSpacing.md) {
                    // Pip sprite (left)
                    PipWavingAnimatedView(size: 120)
                        .offset(y: 10)

                    // Speech bubble + buttons
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        // Message
                        Text(message)
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.darkBrown)
                            .fixedSize(horizontal: false, vertical: true)

                        // Choice buttons stacked
                        VStack(spacing: AppSpacing.sm) {
                            ForEach(choices.indices, id: \.self) { index in
                                choiceButton(choices[index])
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.AppTheme.warmCream)
                    .cornerRadius(AppSpacing.cardCornerRadius)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
                .scaleEffect(appeared ? 1.0 : 0.8)
                .opacity(appeared ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    // MARK: - Choice Button

    @ViewBuilder
    private func choiceButton(_ choice: PipDialogChoice) -> some View {
        Button(action: choice.action) {
            Text(choice.label)
                .font(.AppTheme.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .foregroundColor(foregroundColor(for: choice.style))
                .background(backgroundColor(for: choice.style))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor(for: choice.style), lineWidth: choice.style == .secondary ? 1.5 : 0)
                )
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func foregroundColor(for style: PipDialogChoice.Style) -> Color {
        switch style {
        case .primary: return Color.AppTheme.cream
        case .secondary: return Color.AppTheme.darkBrown
        case .subtle: return Color.AppTheme.sepia
        }
    }

    private func backgroundColor(for style: PipDialogChoice.Style) -> Color {
        switch style {
        case .primary: return Color.AppTheme.sage
        case .secondary: return Color.AppTheme.warmCream
        case .subtle: return Color.clear
        }
    }

    private func borderColor(for style: PipDialogChoice.Style) -> Color {
        switch style {
        case .secondary: return Color.AppTheme.sepia.opacity(0.3)
        default: return Color.clear
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.AppTheme.cream.ignoresSafeArea()

        PipDialogView(
            message: "You have all the ingredients for Rainbow Veggie Wrap! Want to cook it now?",
            choices: [
                PipDialogChoice(label: "Yes, let's cook!", style: .primary, action: {}),
                PipDialogChoice(label: "Not yet", style: .secondary, action: {}),
                PipDialogChoice(label: "Keep gardening", style: .subtle, action: {}),
            ]
        )
    }
}
