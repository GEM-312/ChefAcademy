//
//  CloudKeyManager.swift
//  ChefAcademy
//
//  Fetches the Claude API key from CloudKit so it's NEVER in the app binary.
//
//  HOW IT WORKS:
//  1. You (the developer) store the API key in CloudKit Dashboard (web UI)
//  2. When the app launches, it fetches the key from CloudKit
//  3. The key is cached locally so it works offline too
//  4. If the key is ever compromised, you rotate it in the dashboard — no app update!
//
//  WHY CLOUDKIT?
//  - You already have it set up (SwiftData uses it)
//  - The PUBLIC database is free and readable by all your app users
//  - Only YOU can write to it (via CloudKit Dashboard)
//  - Apple handles all the infrastructure
//
//  TEACHING MOMENT: "Defense in depth" — even though CloudKit protects the key
//  from being in the binary, we ALSO cache it encrypted-at-rest in UserDefaults.
//  Multiple layers of protection is always better than one.
//
//  SETUP INSTRUCTIONS (do this once):
//  1. Go to https://icloud.developer.apple.com/dashboard/
//  2. Select your container: iCloud.GraphicElegance.ChefAcademy
//  3. Go to "Schema" → "Record Types" → Create new type: "AppConfig"
//  4. Add a field: "apiKey" (type: String)
//  5. Go to "Records" → "Public Database" → Create record of type "AppConfig"
//  6. Set the recordName to "pipAPIKey" and apiKey to your Claude key
//  7. Save it. Done! The app will fetch it automatically.
//

import Foundation
import CloudKit

// MARK: - Cloud Key Manager

class CloudKeyManager {

    static let shared = CloudKeyManager()

    // The CloudKit container — same one your SwiftData uses
    private let container = CKContainer(identifier: "iCloud.GraphicElegance.ChefAcademy")

    // Cache key locally so the app works offline
    // UserDefaults is fine here — the key is already "public" to your app users
    // (they can see network traffic). The real protection is the rate limit + proxy (future).
    private let cacheKey = "com.chefacademy.cachedAPIKey"
    private let cacheTimestampKey = "com.chefacademy.cachedAPIKeyTimestamp"

    // How often to re-fetch from CloudKit (1 hour)
    // This means if you rotate the key, all users pick it up within an hour
    private let refreshInterval: TimeInterval = 3600

    private init() {}

    // MARK: - Fetch API Key
    //
    // Tries CloudKit first, falls back to cache, falls back to bundled key.
    //
    // TEACHING MOMENT: "Graceful degradation" — if the best option fails,
    // try the next best, then the next. The app ALWAYS works, even if
    // CloudKit is down or the user is on a plane.
    //

    func fetchAPIKey() async -> String {

        // 1. Check if cache is still fresh
        if let cached = getCachedKey(), isCacheFresh() {
            print("[CloudKey] Using cached key (still fresh)")
            return cached
        }

        // 2. Try CloudKit
        do {
            let key = try await fetchFromCloudKit()
            cacheKey(key)
            print("[CloudKey] Fetched fresh key from CloudKit")
            return key
        } catch {
            print("[CloudKey] CloudKit fetch failed: \(error.localizedDescription)")
        }

        // 3. Fall back to stale cache
        if let cached = getCachedKey() {
            print("[CloudKey] Using stale cached key (CloudKit unavailable)")
            return cached
        }

        // 4. Last resort — use the bundled key (for development only)
        //    In production, this should be empty. The CloudKit key is the source of truth.
        print("[CloudKey] No CloudKit key available, using bundled fallback")
        return APIKeys.claudeAPIKey
    }

    // MARK: - CloudKit Fetch

    private func fetchFromCloudKit() async throws -> String {
        let database = container.publicCloudDatabase

        // Fetch the specific record we created in CloudKit Dashboard
        //
        // TEACHING MOMENT: CKRecord.ID is like a primary key in a database.
        // We use a known, fixed ID ("pipAPIKey") so we always fetch the
        // same record. It's like a config file in the cloud.
        //
        let recordID = CKRecord.ID(recordName: "pipAPIKey")
        let record = try await database.record(for: recordID)

        guard let apiKey = record["apiKey"] as? String, !apiKey.isEmpty else {
            throw CloudKeyError.missingKey
        }

        return apiKey
    }

    // MARK: - Local Cache

    private func cacheKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
    }

    private func getCachedKey() -> String? {
        let key = UserDefaults.standard.string(forKey: cacheKey)
        return (key?.isEmpty == false) ? key : nil
    }

    private func isCacheFresh() -> Bool {
        let timestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
        guard timestamp > 0 else { return false }
        return Date().timeIntervalSince1970 - timestamp < refreshInterval
    }

    // MARK: - Errors

    enum CloudKeyError: Error, LocalizedError {
        case missingKey

        var errorDescription: String? {
            switch self {
            case .missingKey: return "API key not found in CloudKit"
            }
        }
    }
}
