//
//  SignInView.swift
//  ChefAcademy
//
//  Sign-in screen shown to parents before they can access or create a family.
//  Uses Sign in with Apple — Apple's built-in authentication system.
//
//  WHY SIGN IN WITH APPLE?
//  - No passwords to manage (Apple handles it via Face ID / Touch ID)
//  - COPPA-safe: we never collect the child's email or personal data
//  - Required by App Store if you offer any social login
//  - Works across all Apple devices with the same Apple ID
//  - CloudKit already syncs data via iCloud — this just adds identity
//

import SwiftUI
import AuthenticationServices  // For SignInWithAppleButton

// MARK: - Sign In View

struct SignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var sessionManager: SessionManager

    // We keep the coordinator alive as @State so it doesn't get deallocated
    // while Apple's auth sheet is showing (that would crash)
    @State private var coordinator: SignInCoordinator?
    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.AppTheme.cream.ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Pip waving hello
                PipWavingAnimatedView(size: 160)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)

                // Title
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

                // Subtitle for parents
                VStack(spacing: AppSpacing.xs) {
                    Text("Parents: sign in to save your family's")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                    Text("progress across all your devices")
                        .font(.AppTheme.body)
                        .foregroundColor(Color.AppTheme.sepia)
                }
                .multilineTextAlignment(.center)
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Sign in with Apple button (Apple's official SwiftUI component)
                // Apple provides this button with strict design guidelines —
                // you MUST use their button, not a custom one.
                SignInWithAppleButton(.signIn) { request in
                    // Configure what info we want from Apple
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            authManager.handleSignInSuccess(credential: credential)
                            // SessionManager will detect auth change and route appropriately
                        }
                    case .failure(let error):
                        authManager.handleSignInError(error)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .cornerRadius(27)
                .padding(.horizontal, AppSpacing.xl)
                .opacity(showContent ? 1 : 0)

                // Error message (if sign-in failed)
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.AppTheme.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, AppSpacing.xl)
                }

                Spacer().frame(height: AppSpacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthManager())
        .environmentObject(SessionManager())
}
