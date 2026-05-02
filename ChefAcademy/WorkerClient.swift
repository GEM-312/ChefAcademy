//
//  WorkerClient.swift
//  ChefAcademy
//
//  Central config for our Cloudflare Worker proxy. The Worker forwards
//  Claude, USDA, and ElevenLabs requests so our API keys never ship in
//  the app binary.
//
//  Auth is App Attest only (Phase 3c). Every Worker request is signed by
//  the device's Secure Enclave key. The legacy `X-Proxy-Token` shared
//  secret was retired — old IPAs that still have it baked in lose API
//  access on the next app launch.
//

import Foundation

enum WorkerClient {

    /// Cloudflare Worker base URL — not secret, safe to hardcode.
    static let baseURL = URL(string: "https://chefacademy-api.pollak.workers.dev")!

    static var chatURL: URL { baseURL.appendingPathComponent("chat") }

    /// USDA FoodData Central single-food lookup, proxied through the Worker.
    static func usdaURL(fdcId: Int) -> URL {
        baseURL.appendingPathComponent("usda/\(fdcId)")
    }

    /// ElevenLabs text-to-speech, proxied through the Worker.
    static func ttsURL(voiceID: String) -> URL {
        baseURL.appendingPathComponent("tts/\(voiceID)")
    }

    // MARK: App Attest

    /// One-time challenge nonce for the App Attest registration flow.
    static var attestChallengeURL: URL { baseURL.appendingPathComponent("attest/challenge") }

    /// Submit a generated attestation to register a device's pubkey with the Worker.
    static var attestRegisterURL: URL { baseURL.appendingPathComponent("attest/register") }

    /// True if App Attest is wired up and the device is registered with
    /// the Worker. Services should guard their network calls on this so
    /// they fail fast on simulator / pre-registration instead of paying
    /// for a round-trip that's guaranteed to 401.
    static func isReady() async -> Bool {
        await AppAttestService.shared.isReady
    }

    /// Returns the authentication headers to attach to a Worker request.
    /// Pass the JSON-encoded request body so the assertion is bound to it
    /// (use `Data()` for GET requests).
    ///
    /// Returns an empty dictionary when App Attest isn't usable on this
    /// device (simulator, jailbroken, Apple's API errored). Callers should
    /// short-circuit on `isReady()` before calling this so the Worker
    /// never sees an unsigned request.
    static func authHeaders(for body: Data) async -> [String: String] {
        do {
            return try await AppAttestService.shared.signedHeaders(for: body)
        } catch {
            #if DEBUG
            print("[WorkerClient] Could not sign request: \(error.localizedDescription)")
            #endif
            return [:]
        }
    }
}
