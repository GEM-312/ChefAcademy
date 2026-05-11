//
//  ParentPINEntryView.swift
//  ChefAcademy
//
//  Reusable 4-digit PIN pad for parent access.
//

import SwiftUI
import AuthenticationServices

struct ParentPINEntryView: View {
    let purpose: PINPurpose
    var isSetupMode: Bool = false
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var authManager: AuthManager
    @State private var enteredPIN: String = ""
    @State private var shake: Bool = false
    @State private var showError: Bool = false
    @State private var confirmPIN: String = ""
    @State private var isConfirming: Bool = false
    @State private var showForgotPIN: Bool = false
    @State private var isResettingPIN: Bool = false  // true after Apple ID verified
    @State private var signInCoordinator: SignInCoordinator?

    /// Effective setup mode — either passed in OR activated by PIN reset
    private var effectiveSetupMode: Bool { isSetupMode || isResettingPIN }

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
            Spacer()

            PipHeaderStack(
                title: titleText,
                subtitle: subtitleText,
                pose: .thinking
            )
            .padding(.horizontal, AppSpacing.lg)

            // PIN dots
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < currentPIN.count ? Color.AppTheme.goldenWheat : Color.AppTheme.parchment)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.AppTheme.sepia.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .offset(x: shake ? -10 : 0)

            // Error message
            if showError {
                Text(effectiveSetupMode ? "PINs don't match. Try again." : "Wrong PIN. Try again!")
                    .font(.AppTheme.caption)
                    .foregroundColor(Color.AppTheme.terracotta)
                    .transition(.opacity)
            }

            // Forgot PIN — verify with Apple ID to reset
            if !isSetupMode {
                if isResettingPIN {
                    // Show new PIN setup inline
                    Text("Set your new PIN")
                        .font(.AppTheme.caption)
                        .foregroundColor(Color.AppTheme.sage)
                } else {
                    Button(action: { showForgotPIN = true }) {
                        Text("Forgot PIN?")
                            .font(.AppTheme.caption)
                            .foregroundColor(Color.AppTheme.sage)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, AppSpacing.xs)
                }
            }

            Spacer()

            // Number pad — Cancel / 0 / delete
            PINPadGrid(
                onDigit: appendDigit,
                leading: {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: AppSpacing.pinButtonWidth, height: AppSpacing.pinButtonHeight)
                    }
                    .buttonStyle(.plain)
                },
                trailing: {
                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left.fill")
                            .font(.AppTheme.title2)
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: AppSpacing.pinButtonWidth, height: AppSpacing.pinButtonHeight)
                    }
                    .buttonStyle(.plain)
                }
            )
            .padding(.bottom, AppSpacing.xl)
        }
        }
        .alert("Forgot PIN?", isPresented: $showForgotPIN) {
            Button("Cancel", role: .cancel) { }
            Button("Verify with Apple ID") {
                startAppleIDVerification()
            }
        } message: {
            Text("Sign in with your Apple ID to reset your PIN.")
        }
    }

    // MARK: - Forgot PIN → Apple ID Verification
    //
    // TEACHING MOMENT: PIN Recovery Flow
    // 1. Parent taps "Forgot PIN?"
    // 2. Alert explains they need to verify with Apple ID
    // 3. Apple's Sign in with Apple sheet appears (Face ID / password)
    // 4. On success: switch to PIN setup mode so they pick a new PIN
    // This is the same pattern banks use — verify identity, then reset.

    private func startAppleIDVerification() {
        let coordinator = SignInCoordinator(authManager: authManager) {
            // Apple verified the parent's identity — switch to new PIN setup
            DispatchQueue.main.async {
                isResettingPIN = true  // effectiveSetupMode becomes true
                enteredPIN = ""
                confirmPIN = ""
                isConfirming = false
                showError = false
            }
        }
        signInCoordinator = coordinator
        coordinator.signIn()
    }

    // MARK: - Computed

    private var currentPIN: String {
        isConfirming ? confirmPIN : enteredPIN
    }

    private var titleText: String {
        if effectiveSetupMode {
            return isConfirming ? "Confirm Your PIN" : (isResettingPIN ? "Set a New PIN" : "Set a Parent PIN")
        }
        return "This is for grown-ups!"
    }

    private var subtitleText: String {
        if effectiveSetupMode {
            return isConfirming ? "Enter the same 4 digits again" : "Choose 4 digits you'll remember"
        }
        return "Enter the 4-digit parent PIN"
    }

    // MARK: - Actions

    private func appendDigit(_ digit: String) {
        showError = false

        if isConfirming {
            guard confirmPIN.count < 4 else { return }
            confirmPIN += digit
            if confirmPIN.count == 4 {
                checkSetupConfirmation()
            }
        } else {
            guard enteredPIN.count < 4 else { return }
            enteredPIN += digit
            if enteredPIN.count == 4 {
                if effectiveSetupMode {
                    // Move to confirm step
                    isConfirming = true
                } else {
                    verifyPIN()
                }
            }
        }
    }

    private func deleteDigit() {
        if isConfirming {
            if !confirmPIN.isEmpty { confirmPIN.removeLast() }
        } else {
            if !enteredPIN.isEmpty { enteredPIN.removeLast() }
        }
        showError = false
    }

    private func verifyPIN() {
        if sessionManager.verifyParentPIN(enteredPIN) {
            onSuccess()
        } else {
            triggerError()
        }
    }

    private func checkSetupConfirmation() {
        if confirmPIN == enteredPIN {
            sessionManager.updateParentPIN(newPIN: enteredPIN)
            onSuccess()
        } else {
            triggerError()
            confirmPIN = ""
            enteredPIN = ""
            isConfirming = false
        }
    }

    private func triggerError() {
        withAnimation(AnimationConstants.pinShake) {
            shake = true
        }
        showError = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            shake = false
            if !effectiveSetupMode {
                enteredPIN = ""
            }
        }
    }
}

// PINButton + PINPadGrid moved to PipComponents.swift (Pass E dedup, May 10).

#Preview {
    ParentPINEntryView(
        purpose: .selectParentProfile,
        onSuccess: {},
        onCancel: {}
    )
    .environmentObject(SessionManager())
}
