//
//  PINKeychain.swift
//  ChefAcademy
//
//  Securely stores the parent PIN in the Keychain instead of SwiftData.
//  Uses iCloud Keychain sync (kSecAttrSynchronizable) so the PIN
//  works across all family devices automatically.
//
//  WHY KEYCHAIN?
//  - SwiftData + CloudKit would store the PIN as a plaintext string
//    in the CloudKit database. That's bad security practice.
//  - The Keychain encrypts data at rest and in transit.
//  - iCloud Keychain is end-to-end encrypted — even Apple can't read it.
//

import Foundation
import Security

enum PINKeychain {

    private static let service = "com.graphicelegance.chefacademy.parentpin"
    private static let account = "parentPIN"

    /// Save a PIN to the Keychain (syncs via iCloud Keychain)
    static func save(pin: String) {
        let data = Data(pin.utf8)

        // First, try to delete any existing item
        delete()

        // Build the query dictionary
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecValueData as String:        data,
            kSecAttrSynchronizable as String: true  // Sync via iCloud Keychain
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[PINKeychain] Save failed with status: \(status)")
        }
    }

    /// Load the PIN from the Keychain
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete the PIN from the Keychain
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecAttrSynchronizable as String: true
        ]

        SecItemDelete(query as CFDictionary)
    }
}
