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

            // Pip excited
            Image("pip_excited")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(Circle())

            VStack(spacing: AppSpacing.sm) {
                Text("Welcome Back!")
                    .font(.AppTheme.largeTitle)
                    .foregroundColor(Color.AppTheme.darkBrown)

                Text("Your game is safe! We just need\na parent PIN for family mode.")
                    .font(.AppTheme.body)
                    .foregroundColor(Color.AppTheme.sepia)
                    .multilineTextAlignment(.center)
            }

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
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Number pad
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 20) {
                        ForEach(1...3, id: \.self) { col in
                            let num = row * 3 + col
                            PINButton(label: "\(num)") { appendDigit("\(num)") }
                        }
                    }
                }

                HStack(spacing: 20) {
                    Color.clear.frame(width: 75, height: 55) // Spacer

                    PINButton(label: "0") { appendDigit("0") }

                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.AppTheme.sepia)
                            .frame(width: 75, height: 55)
                    }
                }
            }
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
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sessionManager.route = .profilePicker
                    }
                } else {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { shake = true }
                    showError = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
