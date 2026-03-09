//
//  FamilyProfile.swift
//  ChefAcademy
//
//  Multi-user family system — one family per device.
//  Linked to UserProfiles via familyID on UserProfile (no @Relationship).
//

import Foundation
import SwiftData

@Model
class FamilyProfile {
    var id: UUID = UUID()
    var parentPIN: String = ""
    var createdDate: Date = Date()

    // Links this family to a parent's Apple ID.
    // This is an opaque string from Apple (not email, not name) — safe to store.
    // When the parent signs in on a new device, we match by this ID.
    var appleUserID: String = ""

    init(
        id: UUID = UUID(),
        parentPIN: String = "0000",
        createdDate: Date = Date(),
        appleUserID: String = ""
    ) {
        self.id = id
        self.parentPIN = parentPIN
        self.createdDate = createdDate
        self.appleUserID = appleUserID
    }

    // MARK: - Helpers (query by familyID on UserProfile)

    func members(in context: ModelContext) -> [UserProfile] {
        let famID = self.id
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { $0.familyID == famID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func parentProfile(in context: ModelContext) -> UserProfile? {
        let famID = self.id
        let parentRole = ProfileRole.parent.rawValue
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { $0.familyID == famID && $0.role == parentRole }
        )
        return (try? context.fetch(descriptor))?.first
    }

    func childProfiles(in context: ModelContext) -> [UserProfile] {
        let famID = self.id
        let childRole = ProfileRole.child.rawValue
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { $0.familyID == famID && $0.role == childRole }
        )
        return ((try? context.fetch(descriptor)) ?? []).sorted { $0.createdDate < $1.createdDate }
    }

    func canAddChild(in context: ModelContext) -> Bool {
        childProfiles(in: context).count < 4
    }

    func addMember(_ profile: UserProfile) {
        profile.familyID = self.id
    }
}
