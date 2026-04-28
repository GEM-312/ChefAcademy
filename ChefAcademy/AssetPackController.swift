//
//  AssetPackController.swift
//  ChefAcademy
//
//  Wrapper around Apple-Hosted Background Assets (iOS 26+).
//  Replaces ODRManager: same call-site shape, new system underneath.
//
//  TEACHING MOMENT: ODR vs Background Assets
//  ┌────────────────────┬────────────────────┬──────────────────────────────┐
//  │                    │ ODR (deprecated)   │ Apple-Hosted Asset Packs     │
//  ├────────────────────┼────────────────────┼──────────────────────────────┤
//  │ Tag location       │ Contents.json tags │ Manifest.json per pack       │
//  │ Hosted by          │ App Store CDN      │ Apple's CDN (200GB free)     │
//  │ Runtime API        │ NSBundleResource…  │ AssetPackManager.shared      │
//  │ Image() works?     │ Yes (transparent)  │ No — load file URL manually  │
//  │ Local dev          │ Xcode local server │ xcrun ba-serve mock          │
//  │ Min iOS            │ 9.0                │ 26.0                         │
//  └────────────────────┴────────────────────┴──────────────────────────────┘
//
//  WHY a wrapper over the raw AssetPackManager:
//  AssetPackManager is a system actor — every call is async and runs off
//  the main thread. Views need `@Published` state to update reactively, and
//  that has to live on the MainActor. This class is the bridge: it holds the
//  Published properties views observe, and it forwards work to the actor.
//
//  WHY this mirrors ODRManager:
//  Migration is mechanical at call sites — one line change per use.
//    Old: ODRManager.shared.request(.garden)
//    New: AssetPackController.shared.ensureAvailable(.garden)
//  The View modifier is the same shape too:
//    Old: .requestODR(.garden, .characterAnim)
//    New: .ensureAssetPacks(.garden)
//

import BackgroundAssets
import Combine
import Foundation
import SwiftUI

// MARK: - Asset Pack ID
//
// One case per .aar bundle we ship. Each pack groups assets a tab
// needs together — e.g. all veggie illustrations live in `garden`,
// all cooking-scene props in `kitchen`. The `rawValue` MUST match
// the `assetPackID` field in that pack's Manifest.json.

enum AssetPackID: String, CaseIterable, Sendable {
    case kitchen   // ~162 files: cooking scene + mini-game props
    case garden    // ~29 files: veggie illustrations + garden bg
    case farm      // ~23 files: farm scene + pantry items
    case recipes   // ~17 files: recipe card images
}

// MARK: - AssetPackController

@MainActor
@available(iOS 26.4, macOS 26.4, *)
final class AssetPackController: ObservableObject {

    // MARK: - Singleton
    //
    // TEACHING MOMENT: Why a singleton here?
    // Asset pack state (which packs are available, which are downloading,
    // download progress) is global to the app — not per-view. A singleton
    // gives every view the same up-to-date snapshot without prop drilling.
    // The actual download machinery lives in AssetPackManager.shared (an
    // actor), so we're not duplicating state — we're projecting it to the
    // MainActor for SwiftUI to bind to.

    static let shared = AssetPackController()

    // MARK: - Published State

    /// Packs whose download is currently in progress.
    @Published private(set) var activeDownloads: Set<AssetPackID> = []

    /// Download progress per pack (0.0 – 1.0).
    /// Today this jumps 0 → 1 atomically on completion. Granular progress
    /// will land when we wire `AssetPackManager.statusUpdates` (post-POC).
    @Published private(set) var progress: [AssetPackID: Double] = [:]

    /// Packs confirmed available locally (downloaded or already cached).
    @Published private(set) var availablePacks: Set<AssetPackID> = []

    /// Last error message per pack (human-readable, surfaced to UI).
    @Published private(set) var errors: [AssetPackID: String] = [:]

    // MARK: - Private

    /// Active download tasks, keyed by pack. Held so we can cancel them on
    /// release. Without this, a torn-down view leaves the download running.
    private var activeTasks: [AssetPackID: Task<Bool, Never>] = [:]

    private init() {
        // Touching AssetPackManager.shared kicks off system management.
        // We bootstrap availability so views skip the spinner for packs
        // that are already cached on disk.
        Task { await self.bootstrap() }
    }

    /// One-shot startup pass: mark any pack already on disk as available.
    /// Cheap — `assetPackIsAvailableLocally` is a synchronous lookup.
    private func bootstrap() async {
        for pack in AssetPackID.allCases {
            // assetPackIsAvailableLocally is nonisolated/synchronous on the actor —
            // it doesn't await actor state, so no `await` keyword.
            let isLocal = AssetPackManager.shared.assetPackIsAvailableLocally(withID: pack.rawValue)
            if isLocal {
                availablePacks.insert(pack)
                progress[pack] = 1.0
                debugLog("✅ '\(pack.rawValue)' already cached")
            }
        }
    }

    // MARK: - Public API

    /// Ensure a pack is downloaded and ready. Returns `true` on success.
    /// No-ops if already local; downloads otherwise.
    @discardableResult
    func ensureAvailable(_ pack: AssetPackID) async -> Bool {
        // Already local — fast path
        if availablePacks.contains(pack) { return true }

        // Already downloading — join the existing task instead of starting a second
        if let existing = activeTasks[pack] {
            return await existing.value
        }

        // Spin up a new download task. Stored so concurrent callers can join.
        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            return await self.performDownload(pack: pack)
        }
        activeTasks[pack] = task
        let result = await task.value
        activeTasks[pack] = nil
        return result
    }

    /// Ensure multiple packs in parallel. Returns when all are settled.
    func ensureAvailable(_ packs: [AssetPackID]) async {
        await withTaskGroup(of: Void.self) { group in
            for pack in packs {
                group.addTask { _ = await self.ensureAvailable(pack) }
            }
        }
    }

    /// Pre-fetch a pack at low priority. Best-effort, fire-and-forget.
    /// Use on tab prefetch (e.g. HomeView appearing → prefetch garden).
    func prefetch(_ pack: AssetPackID) {
        guard !availablePacks.contains(pack), activeTasks[pack] == nil else { return }
        Task { _ = await ensureAvailable(pack) }
    }

    /// Remove a pack from disk to reclaim space. Safe to call when the pack
    /// isn't local — `remove` no-ops in that case but logs.
    func release(_ pack: AssetPackID) async {
        do {
            try await AssetPackManager.shared.remove(assetPackWithID: pack.rawValue)
            availablePacks.remove(pack)
            progress[pack] = nil
            errors[pack] = nil
            debugLog("🗑 '\(pack.rawValue)' removed")
        } catch {
            debugLog("⚠️ release '\(pack.rawValue)' failed: \(error.localizedDescription)")
        }
    }

    /// Quick availability check without triggering a download.
    /// Useful in `task` blocks before deciding whether to show a loading UI.
    func checkAvailability(_ pack: AssetPackID) -> Bool {
        let isLocal = AssetPackManager.shared.assetPackIsAvailableLocally(withID: pack.rawValue)
        if isLocal && !availablePacks.contains(pack) {
            availablePacks.insert(pack)
            progress[pack] = 1.0
        }
        return isLocal
    }

    // MARK: - Private — Download

    private func performDownload(pack: AssetPackID) async -> Bool {
        activeDownloads.insert(pack)
        errors[pack] = nil
        progress[pack] = 0.0
        debugLog("⏳ '\(pack.rawValue)' downloading...")

        do {
            let assetPack = try await AssetPackManager.shared.assetPack(withID: pack.rawValue)
            try await AssetPackManager.shared.ensureLocalAvailability(of: assetPack, requireLatestVersion: false)

            availablePacks.insert(pack)
            activeDownloads.remove(pack)
            progress[pack] = 1.0
            debugLog("✅ '\(pack.rawValue)' downloaded")
            return true
        } catch {
            activeDownloads.remove(pack)
            errors[pack] = error.localizedDescription
            progress[pack] = nil
            debugLog("❌ '\(pack.rawValue)' failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Logging

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[AssetPack] \(message)")
        #endif
    }
}

// MARK: - View Modifier
//
// Same shape as the existing ODRRequestModifier: shows a Pip loading
// screen while assets download, then reveals the underlying view.
// Drop-in for the `.requestODR(...)` modifier on tab views.

@available(iOS 26.4, macOS 26.4, *)
struct EnsureAssetPacksModifier: ViewModifier {
    let packs: [AssetPackID]
    let releaseOnDisappear: Bool

    @StateObject private var controller = AssetPackController.shared
    @State private var ready = false

    func body(content: Content) -> some View {
        ZStack {
            if ready {
                content
            } else {
                ZStack {
                    Color.AppTheme.cream.ignoresSafeArea()
                    VStack(spacing: AppSpacing.md) {
                        PipWavingAnimatedView(size: 120)
                        Text("Getting things ready...")
                            .font(.AppTheme.body)
                            .foregroundColor(Color.AppTheme.sepia)
                        ProgressView()
                            .tint(Color.AppTheme.sage)
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            // Already cached? Skip the loading state entirely.
            let allReady = packs.allSatisfy { controller.availablePacks.contains($0) }
            if allReady {
                ready = true
                return
            }
            // Otherwise: download in parallel, then reveal.
            await controller.ensureAvailable(packs)
            withAnimation(AnimationConstants.fadeMedium) {
                ready = true
            }
        }
        .onDisappear {
            if releaseOnDisappear {
                Task {
                    for pack in packs {
                        await controller.release(pack)
                    }
                }
            }
        }
    }
}

extension View {
    /// Ensure asset packs are downloaded before revealing this view.
    /// Shows a Pip loading screen during the download.
    ///
    /// Drop-in replacement for the deprecated `.requestODR(...)` modifier.
    /// Example:
    ///     GardenView()
    ///         .ensureAssetPacks(.garden)
    @available(iOS 26.4, macOS 26.4, *)
    func ensureAssetPacks(_ packs: AssetPackID..., releaseOnDisappear: Bool = false) -> some View {
        modifier(EnsureAssetPacksModifier(packs: packs, releaseOnDisappear: releaseOnDisappear))
    }
}
