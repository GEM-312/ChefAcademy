//
//  UserProfile.swift
//  ChefAcademy
//
//  Each family member (parent or child) has a UserProfile.
//  Linked to FamilyProfile and PlayerData via UUID (no @Relationship).
//

import Foundation
import SwiftData

enum ProfileRole: String, Codable {
    case parent
    case child
}

@Model
class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var role: String = "child"
    var genderRaw: String = "Girl"
    var headCoveringRaw: String = "None"
    var outfitRaw: String = "Red Apron"
    var createdDate: Date = Date()
    var lastPlayedDate: Date = Date()
    var totalPlayTimeSeconds: Int = 0
    var familyID: UUID? = nil

    init(
        id: UUID = UUID(),
        name: String = "",
        role: ProfileRole = .child,
        gender: Gender = .girl,
        headCovering: HeadCovering = .chefHat,
        outfit: Outfit = .apronRed,
        createdDate: Date = Date(),
        lastPlayedDate: Date = Date(),
        totalPlayTimeSeconds: Int = 0
    ) {
        self.id = id
        self.name = name
        self.role = role.rawValue
        self.genderRaw = gender.rawValue
        self.headCoveringRaw = headCovering.rawValue
        self.outfitRaw = outfit.rawValue
        self.createdDate = createdDate
        self.lastPlayedDate = lastPlayedDate
        self.totalPlayTimeSeconds = totalPlayTimeSeconds
    }

    // MARK: - Computed Helpers

    var profileRole: ProfileRole {
        ProfileRole(rawValue: role) ?? .child
    }

    var gender: Gender {
        Gender(rawValue: genderRaw) ?? .girl
    }

    var headCovering: HeadCovering {
        HeadCovering.fromRaw(headCoveringRaw)
    }

    var outfit: Outfit {
        Outfit(rawValue: outfitRaw) ?? .apronRed
    }

    var isParent: Bool {
        profileRole == .parent
    }

    var formattedPlayTime: String {
        let days = totalPlayTimeSeconds / 86400
        let hours = (totalPlayTimeSeconds % 86400) / 3600
        let minutes = (totalPlayTimeSeconds % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Short formatted time for cards (e.g., "2h" or "15m")
    var shortPlayTime: String {
        let hours = totalPlayTimeSeconds / 3600
        let minutes = (totalPlayTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    /// Relative time since last played (e.g., "5m ago", "3h ago", "2d ago")
    var lastPlayedRelative: String {
        let seconds = Int(Date().timeIntervalSince(lastPlayedDate))
        if seconds < 60 {
            return "Just now"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }
        let days = hours / 24
        return "\(days)d ago"
    }

    // MARK: - PlayerData Lookup (UUID-based)

    func playerData(in context: ModelContext) -> PlayerData? {
        let profileID = self.id
        let descriptor = FetchDescriptor<PlayerData>(
            predicate: #Predicate<PlayerData> { $0.ownerID == profileID }
        )
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func createPlayerData(in context: ModelContext) -> PlayerData {
        let data = PlayerData()
        data.ownerID = self.id
        context.insert(data)
        return data
    }
}
