//
//  SessionManager.swift
//  ChefAcademy
//
//  Central coordinator for the multi-user family system.
//  Manages routing, profile selection, play time tracking, and legacy migration.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - PIN Purpose

enum PINPurpose {
    case selectParentProfile
    case addChild
    case openDashboard
    case changePIN
}

// MARK: - App Route

enum AppRoute: Equatable {
    case loading
    case familySetup
    case migrationPINSetup
    case profilePicker
    case parentPINEntry(PINPurpose)
    case childOnboarding(UUID)      // UserProfile.id
    case mainApp(UUID)              // UserProfile.id
    case parentDashboard

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case (.familySetup, .familySetup): return true
        case (.migrationPINSetup, .migrationPINSetup): return true
        case (.profilePicker, .profilePicker): return true
        case (.parentPINEntry(let a), .parentPINEntry(let b)):
            return "\(a)" == "\(b)"
        case (.childOnboarding(let a), .childOnboarding(let b)):
            return a == b
        case (.mainApp(let a), .mainApp(let b)):
            return a == b
        case (.parentDashboard, .parentDashboard): return true
        default: return false
        }
    }
}

// MARK: - Session Manager

class SessionManager: ObservableObject {
    @Published var route: AppRoute = .loading
    @Published var activeProfile: UserProfile?
    @Published var familyProfile: FamilyProfile?

    var modelContext: ModelContext?

    // Play time tracking
    private var sessionStartTime: Date?
    private var playTimeTimer: Timer?

    // MARK: - Bootstrap (called on app launch)

    func bootstrap(context: ModelContext) {
        self.modelContext = context

        let familyDescriptor = FetchDescriptor<FamilyProfile>()
        let families = (try? context.fetch(familyDescriptor)) ?? []

        if let family = families.first {
            // Family exists — go to profile picker
            self.familyProfile = family

            // Migrate PIN from SwiftData to Keychain if needed
            if !family.parentPIN.isEmpty, PINKeychain.load() == nil {
                PINKeychain.save(pin: family.parentPIN)
                family.parentPIN = ""
                try? context.save()
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                self.route = .profilePicker
            }
        } else {
            // No family — check for legacy single-user data
            let playerDescriptor = FetchDescriptor<PlayerData>()
            let legacyPlayers = (try? context.fetch(playerDescriptor)) ?? []

            if let legacyData = legacyPlayers.first, legacyData.ownerID == nil {
                // Legacy data exists — migrate
                migrateLegacyData(legacyPlayerData: legacyData, context: context)
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.route = .migrationPINSetup
                }
            } else {
                // Brand new install
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.route = .familySetup
                }
            }
        }
    }

    // MARK: - Profile Selection

    func selectProfile(_ profile: UserProfile, gameState: GameState, avatarModel: AvatarModel) {
        // Save any existing session first
        if let current = activeProfile {
            recordPlayTime(for: current)
        }

        activeProfile = profile
        profile.lastPlayedDate = Date()

        // Load avatar data
        avatarModel.loadFrom(profile: profile)

        // Load game data
        if let ctx = modelContext, let playerData = profile.playerData(in: ctx) {
            gameState.activeProfileID = profile.id
            gameState.loadFromStore(for: playerData)
        } else if let ctx = modelContext {
            // Create new PlayerData for this profile
            profile.createPlayerData(in: ctx)
            try? ctx.save()
            gameState.activeProfileID = profile.id
            gameState.resetToDefaults()
            // Save starter data (seeds, plots, pantry) to the new PlayerData
            gameState.saveToStore()
        }

        // Start play time tracking
        startPlayTimeTracking()

        withAnimation(.easeInOut(duration: 0.3)) {
            route = .mainApp(profile.id)
        }
    }

    // MARK: - Switch to Profile Picker

    func switchToProfilePicker(gameState: GameState, avatarModel: AvatarModel) {
        // Save current state
        if let profile = activeProfile {
            avatarModel.saveTo(profile: profile)
            recordPlayTime(for: profile)
            gameState.saveToStore()
            try? modelContext?.save()
        }

        stopPlayTimeTracking()
        activeProfile = nil
        gameState.activeProfileID = nil

        withAnimation(.easeInOut(duration: 0.3)) {
            route = .profilePicker
        }
    }

    // MARK: - Add Child Profile

    func addChildProfile(
        name: String,
        gender: Gender,
        headCovering: HeadCovering,
        outfit: Outfit
    ) -> UserProfile? {
        guard let family = familyProfile, let context = modelContext,
              family.canAddChild(in: context) else {
            return nil
        }

        let profile = UserProfile(
            name: name,
            role: .child,
            gender: gender,
            headCovering: headCovering,
            outfit: outfit
        )

        context.insert(profile)
        family.addMember(profile)
        profile.createPlayerData(in: context)
        try? context.save()

        return profile
    }

    // MARK: - Remove Child Profile

    func removeChildProfile(_ profile: UserProfile) {
        guard let context = modelContext else { return }

        // If this is the active profile, clear it
        if activeProfile?.id == profile.id {
            activeProfile = nil
            stopPlayTimeTracking()
        }

        context.delete(profile)
        try? context.save()
    }

    // MARK: - PIN Verification (Keychain-backed)

    func verifyParentPIN(_ pin: String) -> Bool {
        // Read from Keychain (secure, syncs via iCloud Keychain)
        guard let storedPIN = PINKeychain.load() else {
            // Fallback: check SwiftData for legacy migration
            return familyProfile?.parentPIN == pin
        }
        return storedPIN == pin
    }

    func updateParentPIN(newPIN: String) {
        PINKeychain.save(pin: newPIN)
        // Clear from SwiftData (don't store PIN in CloudKit)
        familyProfile?.parentPIN = ""
        try? modelContext?.save()
    }

    // MARK: - Legacy Migration

    private func migrateLegacyData(legacyPlayerData: PlayerData, context: ModelContext) {
        // Create family — PIN stored in Keychain, not SwiftData
        let family = FamilyProfile(parentPIN: "")
        PINKeychain.save(pin: "0000")  // Temporary PIN, user will set real one

        // Read legacy avatar data from UserDefaults
        let legacyName = UserDefaults.standard.string(forKey: "userName") ?? "Little Chef"
        let legacyGenderRaw = UserDefaults.standard.string(forKey: "userGender") ?? Gender.girl.rawValue
        let legacyCoveringRaw = UserDefaults.standard.string(forKey: "userHeadCovering") ?? HeadCovering.none.rawValue

        let legacyGender = Gender(rawValue: legacyGenderRaw) ?? .girl
        let legacyCovering = HeadCovering(rawValue: legacyCoveringRaw) ?? .none

        // Create child profile from legacy data
        let childProfile = UserProfile(
            name: legacyName,
            role: .child,
            gender: legacyGender,
            headCovering: legacyCovering,
            outfit: .apronRed
        )

        // Link existing PlayerData to this profile via UUID
        legacyPlayerData.ownerID = childProfile.id

        // Create parent profile (empty, user will set up later)
        let parentProfile = UserProfile(
            name: "Parent",
            role: .parent,
            gender: .girl,
            headCovering: .none,
            outfit: .chefWhite
        )

        context.insert(family)
        context.insert(parentProfile)
        context.insert(childProfile)
        family.addMember(parentProfile)
        family.addMember(childProfile)
        // Create parent's PlayerData
        parentProfile.createPlayerData(in: context)
        try? context.save()

        self.familyProfile = family

        // Clean up legacy UserDefaults
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userGender")
        UserDefaults.standard.removeObject(forKey: "userHeadCovering")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Play Time Tracking

    private func startPlayTimeTracking() {
        sessionStartTime = Date()
        playTimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, let profile = self.activeProfile else { return }
            self.recordPlayTime(for: profile)
            self.sessionStartTime = Date()
        }
    }

    private func stopPlayTimeTracking() {
        playTimeTimer?.invalidate()
        playTimeTimer = nil
        sessionStartTime = nil
    }

    private func recordPlayTime(for profile: UserProfile) {
        guard let start = sessionStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        profile.totalPlayTimeSeconds += elapsed
        try? modelContext?.save()
    }

    // MARK: - App Lifecycle

    func appWillBackground(gameState: GameState, avatarModel: AvatarModel) {
        if let profile = activeProfile {
            avatarModel.saveTo(profile: profile)
            recordPlayTime(for: profile)
            sessionStartTime = Date()
            gameState.saveToStore()
            try? modelContext?.save()
        }
    }

    func appWillForeground() {
        if activeProfile != nil {
            sessionStartTime = Date()
        }
    }
}
