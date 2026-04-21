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

    /// Shared-secret header that the Worker checks. Stored in APIKeys.swift
    /// (gitignored) so it doesn't end up in screenshots or commits.
    static var proxyToken: String { APIKeys.proxyToken }
}
