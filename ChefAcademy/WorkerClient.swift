//
//  WorkerClient.swift
//  ChefAcademy
//
//  Central config for our Cloudflare Worker proxy. The Worker forwards
//  Claude and USDA requests so our API keys never ship in the app binary.
//
//  The proxy token is a temporary shared secret — it proves "this request
//  came from our app" in a weak way (it's still embedded in the binary).
//  Phase 3 of the migration replaces it with Apple App Attest for
//  cryptographic proof.
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

    /// Shared-secret header that the Worker checks. Stored in APIKeys.swift
    /// (gitignored) so it doesn't end up in screenshots or commits.
    static var proxyToken: String { APIKeys.proxyToken }

    /// True once the proxy token has been pasted into APIKeys.swift.
    /// Use this to short-circuit network calls before they hit the wire.
    static var isConfigured: Bool {
        !proxyToken.isEmpty && proxyToken != "PASTE_YOUR_HEX_TOKEN_HERE"
    }
}
