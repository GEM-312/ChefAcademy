//
//  ParentPINEntryView.swift
//  ChefAcademy
//
//  Reusable 4-digit PIN pad for parent access.
//

import SwiftUI

struct ParentPINEntryView: View {
    let purpose: PINPurpose
    var isSetupMode: Bool = false
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject var sessionManager: SessionManager
    @State private var enteredPIN: String = ""
    @State private var shake: Bool = false
    @State private var showError: Bool = false
    @State private var confirmPIN: String = ""
    @State private var isConfirming: Bool = false

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
            Spacer()

            // Pip thinking
            Image("pip_thinking")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())

            // Title
            VStack(spacing: AppSpacing.xs) {
                Text(titleText)
                    .font(.AppTheme.title2)
                    .foregroundColor(Color.AppTheme.darkBrown)
                    .multilineTextAlignment(.center)

                Text(subtitleText)
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .multilineTextAlignment(.center)
            }
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
                Text(isSetupMode ? "PINs don't match. Try again." : "Wrong PIN. Try again!")
                    .font(.AppTheme.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }

            Spacer()

            // Number pad
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 20) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            PINButton(label: "\(number)") {
                                appendDigit("\(number)")
                            }
                        }
                    }
                }

                // Bottom row: cancel, 0, backspace
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: 75, height: 55)
                    }
                    .buttonStyle(.plain)

                    PINButton(label: "0") {
                        appendDigit("0")
                    }

                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: 75, height: 55)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, AppSpacing.xl)
        }
        }
    }

    // MARK: - Computed

    private var currentPIN: String {
        isConfirming ? confirmPIN : enteredPIN
    }

    private var titleText: String {
        if isSetupMode {
            return isConfirming ? "Confirm Your PIN" : "Set a Parent PIN"
        }
        return "This is for grown-ups!"
    }

    private var subtitleText: String {
        if isSetupMode {
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
                if isSetupMode {
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
        withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
            shake = true
        }
        showError = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            shake = false
            if !isSetupMode {
                enteredPIN = ""
            }
        }
    }
}

// MARK: - PIN Button

struct PINButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundColor(Color.AppTheme.darkBrown)
                .frame(width: 75, height: 55)
                .background(Color.AppTheme.warmCream)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ParentPINEntryView(
        purpose: .selectParentProfile,
        onSuccess: {},
        onCancel: {}
    )
    .environmentObject(SessionManager())
}
