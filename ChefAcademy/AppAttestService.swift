//
//  AppAttestService.swift
//  ChefAcademy
//
//  Apple App Attest integration. Replaces the X-Proxy-Token shared secret
//  with a hardware-backed cryptographic identity per device.
//
//  TEACHING MOMENT: What is App Attest?
//  ────────────────────────────────────
//  Every iPhone since the iPhone 7 has a Secure Enclave — a separate chip
//  inside the SoC that protects Face ID, Apple Pay, and other secrets.
//  App Attest lets your app generate a private key INSIDE that chip. The
//  key never leaves the chip, can't be extracted by jailbreaks or memory
//  dumps, and Apple cryptographically signs an "attestation" proving the
//  key was generated on a real, unmodified iOS device running a real
//  build of YOUR app (matched by team ID + bundle ID).
//
//  Server flow (this device, first launch):
//    1. App asks Worker for a random challenge nonce
//    2. App generates an App Attest key in the Secure Enclave → keyId
//    3. App calls Apple to attest the key (proves it came from real iOS)
//    4. App POSTs {keyId, attestation, challenge} to the Worker
//    5. Worker verifies the attestation against Apple's CA, extracts the
//       public key, stores {pubkey, counter:0} in KV keyed by keyId
//
//  After registration (every API request, Phase 3b — coming next session):
//    1. App fetches a fresh challenge from Worker
//    2. App computes hash = SHA256(challenge ‖ SHA256(requestBody))
//    3. App calls Apple's API to sign the hash with the Secure Enclave key
//    4. App sends {keyId, assertion, challenge} alongside the API request
//    5. Worker verifies the assertion using the stored pubkey + counter
//
//  This file ONLY implements step 1-5 of the registration flow (Phase 3a).
//  Per-request signing lands in Phase 3b.
//

import CryptoKit
import DeviceCheck
import Foundation
import Security

@MainActor
final class AppAttestService {

    // MARK: - Singleton

    static let shared = AppAttestService()

    // MARK: - Storage keys

    private static let keyIDKeychainAccount = "com.GraphicElegance.ChefAcademy.appAttestKeyID"
    private static let registeredFlagKey    = "AppAttest.deviceRegistered"

    // MARK: - Apple framework handle

    private let service = DCAppAttestService.shared

    private init() {}

    // MARK: - Capability

    /// True if App Attest works on this device.
    /// Returns false on Simulator, jailbroken devices, and the rare older
    /// iPad without Secure Enclave. We DO NOT enable App Attest on those —
    /// the app falls back to static responses (PipStaticResponses) and
    /// cached defaults instead of API access.
    var isSupported: Bool { service.isSupported }

    /// True only when the device is supported AND already registered with
    /// the Worker. `WorkerClient.authHeaders` checks this before trying to
    /// sign a request — if false, it skips the assertion path and falls
    /// back to the proxy token instead.
    var isReady: Bool {
        isSupported && isRegistered && storedKeyId != nil
    }

    // MARK: - Public entry point

    /// Idempotent. Safe to call on every app launch.
    /// Skips the network round-trip if already registered.
    func registerIfNeeded() async {
        guard isSupported else {
            #if DEBUG
            print("[AppAttest] Skipped — not supported on this device (simulator / jailbroken / no Secure Enclave)")
            #endif
            return
        }

        if isRegistered, storedKeyId != nil {
            #if DEBUG
            print("[AppAttest] Already registered — skipping")
            #endif
            return
        }

        do {
            try await register()
            isRegistered = true
            #if DEBUG
            print("[AppAttest] ✅ Device registered with Worker")
            #endif
        } catch {
            #if DEBUG
            print("[AppAttest] ❌ Registration failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Per-request signing (Phase 3b)

    /// Generate the headers a Worker request needs in order to be authenticated
    /// by an App Attest assertion. Pass the request body so the assertion is
    /// bound to the exact bytes being sent (use `Data()` for GET requests).
    ///
    /// On success returns three headers:
    ///   X-AppAttest-KeyID     — the keyId from device registration
    ///   X-AppAttest-Challenge — fresh single-use nonce from /attest/challenge
    ///   X-AppAttest-Assertion — base64-encoded CBOR assertion from the Secure Enclave
    ///
    /// Throws if not registered, if the network fails, or if Apple's API rejects.
    /// Callers (typically `WorkerClient.authHeaders`) catch and fall back to the
    /// proxy token rather than failing the user-visible request.
    func signedHeaders(for body: Data) async throws -> [String: String] {
        guard isReady, let keyId = storedKeyId else {
            throw NSError(
                domain: "AppAttestService",
                code: -10,
                userInfo: [NSLocalizedDescriptionKey: "App Attest not ready (register first)"]
            )
        }

        // 1. Fetch a one-time challenge nonce. The same challenge string we
        //    receive here gets sent in the X-AppAttest-Challenge header AND
        //    used in the data we sign — so the server can reconstruct the
        //    exact same hash and verify our signature.
        let challenge = try await fetchChallenge()

        // 2. Build the data to sign:
        //      clientData = challenge_utf8_bytes ‖ SHA256(body)
        //
        //    The body hash binds this assertion to THIS specific request body.
        //    If a man-in-the-middle modifies even one byte of the body, the
        //    server's reconstructed hash won't match → signature fails → 401.
        //
        //    We hash the body (rather than appending the body itself) so the
        //    sign-time work is constant regardless of how big the body is.
        let challengeBytes = Data(challenge.utf8)
        let bodyHash       = Data(SHA256.hash(data: body))
        var clientData     = challengeBytes
        clientData.append(bodyHash)

        // 3. Apple's API wants a SHA-256 hash, not the data itself.
        let clientDataHash = Data(SHA256.hash(data: clientData))

        // 4. Hand the hash to the Secure Enclave for signing. Only the
        //    private key inside the chip can produce a valid signature —
        //    nothing in app memory or even kernel space can forge this.
        let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)

        return [
            "X-AppAttest-KeyID":     keyId,
            "X-AppAttest-Challenge": challenge,
            "X-AppAttest-Assertion": assertion.base64EncodedString(),
        ]
    }

    // MARK: - Registration

    private func register() async throws {
        // 1. Fetch a one-time challenge nonce from the Worker.
        //    Challenges live for 5 minutes server-side and can only be used once,
        //    which is what stops an attacker from replaying a captured attestation.
        let challenge = try await fetchChallenge()

        // 2. Generate (or reuse) an App Attest key in the Secure Enclave.
        //    `generateKey` returns a base64 keyId string. The PRIVATE KEY itself
        //    never leaves the chip — we only get back an opaque identifier.
        let keyId: String
        if let existing = storedKeyId {
            keyId = existing
        } else {
            keyId = try await service.generateKey()
            storedKeyId = keyId
        }

        // 3. Hash the challenge. Apple's API requires SHA-256 of the data being
        //    attested, not the data itself. The hash binds this attestation to
        //    THIS challenge — the server later verifies the same hash matches.
        let challengeBytes = Data(challenge.utf8)
        let clientDataHash = Data(SHA256.hash(data: challengeBytes))

        // 4. Ask Apple to attest the key. This call talks to Apple's servers
        //    and returns a CBOR-encoded blob containing:
        //      - The public key (for our pubkey + signature checks later)
        //      - A certificate chain rooted in Apple's App Attest CA
        //      - An "AAGUID" identifying this is App Attest (vs WebAuthn etc.)
        //      - The hashed challenge we just supplied (proves freshness)
        let attestation = try await service.attestKey(keyId, clientDataHash: clientDataHash)

        // 5. Ship it to our Worker. The Worker validates the attestation
        //    against Apple's CA, extracts the public key, and stores it
        //    keyed by keyId. From this point on the Worker can verify any
        //    future assertion signed by this device.
        try await postAttestation(keyId: keyId, attestation: attestation, challenge: challenge)
    }

    // MARK: - Network

    private func fetchChallenge() async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: WorkerClient.attestChallengeURL)
        try Self.requireOK(response, data: data, label: "challenge")
        struct ChallengeResponse: Decodable { let challenge: String }
        return try JSONDecoder().decode(ChallengeResponse.self, from: data).challenge
    }

    private func postAttestation(keyId: String, attestation: Data, challenge: String) async throws {
        var request = URLRequest(url: WorkerClient.attestRegisterURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "keyId":       keyId,
            "attestation": attestation.base64EncodedString(),
            "challenge":   challenge,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.requireOK(response, data: data, label: "register")
    }

    private static func requireOK(_ response: URLResponse, data: Data, label: String) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "AppAttestService",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: "Worker rejected \(label): HTTP \(code) — \(body)"]
            )
        }
    }

    // MARK: - Persistence

    /// Set after a successful Worker registration.
    /// Cleared if app is reinstalled or device is restored — which is correct
    /// behavior because App Attest also wipes its key in those cases.
    private var isRegistered: Bool {
        get { UserDefaults.standard.bool(forKey: Self.registeredFlagKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.registeredFlagKey) }
    }

    /// keyId persisted in Keychain (NOT UserDefaults). Survives app updates,
    /// matching the lifetime of the underlying Secure Enclave key.
    /// Wiped on app uninstall, just like the App Attest key itself.
    private var storedKeyId: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrAccount as String: Self.keyIDKeychainAccount,
                kSecReturnData as String:  true,
                kSecMatchLimit as String:  kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess,
                  let data = result as? Data,
                  let str  = String(data: data, encoding: .utf8) else { return nil }
            return str
        }
        set {
            let baseQuery: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrAccount as String: Self.keyIDKeychainAccount,
            ]
            // Always delete first so we don't double-add.
            SecItemDelete(baseQuery as CFDictionary)

            guard let value = newValue, let data = value.data(using: .utf8) else { return }
            var attrs = baseQuery
            attrs[kSecValueData as String]      = data
            attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(attrs as CFDictionary, nil)
        }
    }
}
