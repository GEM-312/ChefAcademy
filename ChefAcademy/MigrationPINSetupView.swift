//
//  MigrationPINSetupView.swift
//  ChefAcademy
//
//  Shown to existing users upgrading from single-player.
//  "Welcome back! Set a parent PIN to enable family mode."
//

import SwiftUI

struct MigrationPINSetupView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var isConfirming: Bool = false
    @State private var shake: Bool = false
    @State private var showError: Bool = false

    private var currentPIN: String { isConfirming ? confirmPin : pin }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            PipHeaderStack(
                title: "Welcome Back!",
                subtitle: "Your game is safe! We just need\na parent PIN for family mode.",
                pose: .gotIdea,
                size: .large
            )

            VStack(spacing: AppSpacing.xs) {
                Text(isConfirming ? "Confirm Your PIN" : "Choose a 4-Digit PIN")
                    .font(.AppTheme.headline)
                    .foregroundColor(Color.AppTheme.darkBrown)

                // PIN dots
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < currentPIN.count ? Color.AppTheme.goldenWheat : Color.AppTheme.parchment)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1))
                    }
                }
                .offset(x: shake ? -10 : 0)

                if showError {
                    Text("PINs don't match. Try again.")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.terracotta)
                }
            }

            Spacer()

            // Number pad — empty spacer / 0 / delete (no Cancel/Back during migration)
            PINPadGrid(
                onDigit: appendDigit,
                leading: {
                    Color.clear.frame(width: AppSpacing.pinButtonWidth, height: AppSpacing.pinButtonHeight)
                },
                trailing: {
                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left.fill")
                            .font(.AppTheme.title2)
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: AppSpacing.pinButtonWidth, height: AppSpacing.pinButtonHeight)
                    }
                }
            )
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.AppTheme.cream)
    }

    private func appendDigit(_ d: String) {
        showError = false
        if isConfirming {
            guard confirmPin.count < 4 else { return }
            confirmPin += d
            if confirmPin.count == 4 {
                if confirmPin == pin {
                    sessionManager.updateParentPIN(newPIN: pin)
                    withAnimation(AnimationConstants.fadeMedium) {
                        sessionManager.route = .profilePicker
                    }
                } else {
                    withAnimation(AnimationConstants.pinShake) { shake = true }
                    showError = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        guard !Task.isCancelled else { return }
                        shake = false
                        confirmPin = ""
                        pin = ""
                        isConfirming = false
                    }
                }
            }
        } else {
            guard pin.count < 4 else { return }
            pin += d
            if pin.count == 4 {
                isConfirming = true
            }
        }
    }

    private func deleteDigit() {
        if isConfirming {
            if !confirmPin.isEmpty { confirmPin.removeLast() }
        } else {
            if !pin.isEmpty { pin.removeLast() }
        }
        showError = false
    }
}

#Preview {
    MigrationPINSetupView()
        .environmentObject(SessionManager())
}
