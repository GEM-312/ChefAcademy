//
//  AuthManager.swift
//  ChefAcademy
//
//  Handles Sign in with Apple authentication.
//
//  HOW IT WORKS:
//  1. Parent taps "Sign in with Apple" button
//  2. Apple shows its own login sheet (Face ID, password, etc.)
//  3. Apple returns a credential with a unique `user` string (the Apple User ID)
//  4. We store that ID in Keychain (encrypted, syncs via iCloud Keychain)
//  5. On next launch, we check: is there an Apple User ID in Keychain?
//     - YES → user is authenticated (no need to sign in again)
//     - NO → show sign-in screen
//  6. We also verify with Apple that the credential hasn't been revoked
//
//  WHY KEYCHAIN?
//  Same reason as the PIN — Keychain is encrypted at rest, and with
//  kSecAttrSynchronizable it syncs across the parent's devices via iCloud.
//

import AuthenticationServices  // Apple's framework for Sign in with Apple
import Combine    // For @Published (ObservableObject needs this)
import SwiftUI
import UIKit  // Needed for UIWindowScene in presentation anchor

// MARK: - Auth Keychain (stores Apple User ID securely)

enum AuthKeychain {
    // Different service name than PINKeychain so they don't collide
    private static let service = "com.graphicelegance.chefacademy.appleauth"
    private static let account = "appleUserID"

    /// Save the Apple User ID to Keychain (syncs via iCloud Keychain)
    static func saveUserID(_ userID: String) {
        let data = Data(userID.utf8)
        delete()  // Remove old value first (Keychain doesn't do upsert)

        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        service,
            kSecAttrAccount as String:        account,
            kSecValueData as String:          data,
            kSecAttrSynchronizable as String: true  // Sync across devices
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[AuthKeychain] Save failed: \(status)")
        }
    }

    /// Load the Apple User ID from Keychain
    static func loadUserID() -> String? {
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        service,
            kSecAttrAccount as String:        account,
            kSecReturnData as String:         true,
            kSecMatchLimit as String:         kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete the Apple User ID from Keychain
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        service,
            kSecAttrAccount as String:        account,
            kSecAttrSynchronizable as String: true
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Auth Manager

class AuthManager: ObservableObject {
    /// Is the parent currently authenticated?
    @Published var isAuthenticated: Bool = false

    /// The Apple User ID for the signed-in parent (nil if not signed in)
    @Published var appleUserID: String?

    /// The parent's name from Apple (only available on FIRST sign-in)
    @Published var signedInName: String?

    /// Error message to show in UI
    @Published var errorMessage: String?

    // MARK: - Check Existing Credential (called on app launch)

    /// Check if we have a saved Apple User ID and if it's still valid.
    /// Apple can revoke credentials (e.g., if user removes your app from
    /// their Apple ID settings), so we verify with Apple each launch.
    func checkExistingCredential() {
        guard let savedUserID = AuthKeychain.loadUserID() else {
            // No saved credential — user needs to sign in
            isAuthenticated = false
            appleUserID = nil
            return
        }

        // Ask Apple: "Is this credential still valid?"
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: savedUserID) { [weak self] state, _ in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    // Still valid — user is logged in
                    self?.appleUserID = savedUserID
                    self?.isAuthenticated = true

                case .revoked, .notFound:
                    // Apple revoked it or it's gone — user must sign in again
                    AuthKeychain.delete()
                    self?.appleUserID = nil
                    self?.isAuthenticated = false

                case .transferred:
                    // App ownership transferred (rare) — treat as signed out
                    AuthKeychain.delete()
                    self?.appleUserID = nil
                    self?.isAuthenticated = false

                @unknown default:
                    self?.appleUserID = savedUserID
                    self?.isAuthenticated = true
                }
            }
        }
    }

    // MARK: - Handle Sign In Result

    /// Called when the ASAuthorizationController completes successfully.
    /// We extract the Apple User ID and optional name, then save to Keychain.
    func handleSignInSuccess(credential: ASAuthorizationAppleIDCredential) {
        let userID = credential.user  // The stable, app-scoped identifier
        AuthKeychain.saveUserID(userID)
        appleUserID = userID
        isAuthenticated = true
        errorMessage = nil

        // Apple only gives us the name on the FIRST sign-in ever.
        // After that, fullName will be nil. So we grab it while we can.
        if let fullName = credential.fullName {
            let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
            if !parts.isEmpty {
                signedInName = parts.joined(separator: " ")
            }
        }

        print("[AuthManager] Signed in as: \(userID)")
    }

    /// Called when the ASAuthorizationController fails.
    func handleSignInError(_ error: Error) {
        // ASAuthorizationError.canceled means user tapped "Cancel" — not an error
        if let authError = error as? ASAuthorizationError,
           authError.code == .canceled {
            print("[AuthManager] User canceled sign-in")
            return
        }

        errorMessage = "Sign in failed. Please try again."
        print("[AuthManager] Sign-in error: \(error.localizedDescription)")
    }

    // MARK: - Sign Out

    /// Clears local auth state. Data stays in CloudKit.
    /// The parent can sign back in anytime to get their data back.
    func signOut() {
        AuthKeychain.delete()
        appleUserID = nil
        isAuthenticated = false
        signedInName = nil
        errorMessage = nil
        print("[AuthManager] Signed out")
    }

    // MARK: - Account Deletion (App Store requirement)

    /// Deletes the auth credential locally. Full account/data deletion
    /// should also remove the FamilyProfile from SwiftData.
    func deleteAccount() {
        signOut()
        // Note: To fully comply with Apple's account deletion requirement,
        // you should also revoke the token with Apple's REST API.
        // For now, we clear local data. The parent can also remove the app
        // from Settings > Apple ID > Password & Security > Apps Using Apple ID.
    }
}

// MARK: - Sign in with Apple Coordinator

/// This is the "bridge" between SwiftUI and Apple's UIKit-based auth controller.
/// SwiftUI can't directly handle ASAuthorizationController, so we use a Coordinator.
///
/// HOW ASAuthorization WORKS:
/// 1. We create an ASAuthorizationAppleIDRequest (what we want from Apple)
/// 2. We create an ASAuthorizationController (Apple's login UI)
/// 3. Apple shows Face ID / password sheet to the user
/// 4. Apple calls our delegate methods with the result
///
class SignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
                          ASAuthorizationControllerPresentationContextProviding {

    let authManager: AuthManager
    let onComplete: (() -> Void)?

    init(authManager: AuthManager, onComplete: (() -> Void)? = nil) {
        self.authManager = authManager
        self.onComplete = onComplete
    }

    /// Start the Sign in with Apple flow
    func signIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        // We ask for name (first sign-in only) — no email needed for a kids app
        request.requestedScopes = [.fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    /// Called when Apple successfully authenticates the user
    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        authManager.handleSignInSuccess(credential: credential)
        onComplete?()
    }

    /// Called when authentication fails or is canceled
    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        authManager.handleSignInError(error)
    }

    // MARK: - Presentation Context

    /// Tells Apple which window to show the sign-in sheet in
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the first active window scene's key window
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
}
