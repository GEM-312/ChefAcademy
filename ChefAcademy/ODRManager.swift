import Combine
import Foundation
import SwiftUI
import UIKit

// MARK: - ODR Resource Tags

/// All On-Demand Resource tags used in the app.
/// Each tag maps to a group of assets that are downloaded together.
enum ODRTag: String, CaseIterable {
    case kitchen        // KitchenSink frames, stove flame, cooking assets (~147 MB)
    case garden         // Vegetables, garden backgrounds (~50 MB)
    case farm           // FarmItems, farm backgrounds (~15 MB)
    case recipes        // Recipe card images (~20 MB)
    case characterAnim = "character-anim"  // Avatar animation frames (~12 MB)
}

// MARK: - ODRManager

/// Manages On-Demand Resource downloads.
///
/// **How ODR works:** When you upload to App Store Connect, Apple separates
/// tagged assets from the initial download. At runtime, you call
/// `NSBundleResourceRequest(tags:)` to download them before use.
/// The system caches them and can purge when storage is low.
///
/// In the Simulator and debug builds, ALL assets are always available
/// (ODR only applies to App Store / TestFlight builds).
@MainActor
final class ODRManager: ObservableObject {

    static let shared = ODRManager()

    // MARK: - Published State

    /// Tags currently being downloaded
    @Published private(set) var activeDownloads: Set<ODRTag> = []

    /// Download progress per tag (0.0 – 1.0)
    @Published private(set) var progress: [ODRTag: Double] = [:]

    /// Tags confirmed available (downloaded or always-bundled)
    @Published private(set) var availableTags: Set<ODRTag> = []

    /// Last error per tag
    @Published private(set) var errors: [ODRTag: String] = [:]

    // MARK: - Private

    /// Active resource requests — keep strong reference so system doesn't purge mid-use
    private var activeRequests: [ODRTag: NSBundleResourceRequest] = [:]

    /// Observation tokens for KVO on fractionCompleted
    private var observations: [ODRTag: NSKeyValueObservation] = [:]

    private init() {}

    // MARK: - Public API

    /// Request a tag's resources. Downloads if needed, no-ops if already available.
    /// Returns `true` when resources are ready to use.
    @discardableResult
    func request(_ tag: ODRTag) async -> Bool {
        // Already available — nothing to do
        if availableTags.contains(tag) { return true }

        // Already downloading — wait for it
        if activeDownloads.contains(tag), let req = activeRequests[tag] {
            return await waitForRequest(req, tag: tag)
        }

        let request = NSBundleResourceRequest(tags: [tag.rawValue])
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        activeRequests[tag] = request
        activeDownloads.insert(tag)
        errors[tag] = nil

        // Observe download progress
        let observation = request.progress.observe(\.fractionCompleted) { [weak self] prog, _ in
            Task { @MainActor in
                self?.progress[tag] = prog.fractionCompleted
            }
        }
        observations[tag] = observation

        let success = await waitForRequest(request, tag: tag)
        observations[tag]?.invalidate()
        observations[tag] = nil
        return success
    }

    /// Request multiple tags in parallel. Returns when all are ready.
    func request(_ tags: [ODRTag]) async {
        await withTaskGroup(of: Void.self) { group in
            for tag in tags {
                group.addTask { _ = await self.request(tag) }
            }
        }
    }

    /// Prefetch a tag at low priority (best-effort, doesn't block).
    /// Good for pre-loading the next likely screen.
    func prefetch(_ tag: ODRTag) {
        guard !availableTags.contains(tag), !activeDownloads.contains(tag) else { return }

        let request = NSBundleResourceRequest(tags: [tag.rawValue])
        request.loadingPriority = 0.5  // Low priority — won't compete with urgent requests
        activeRequests[tag] = request

        Task {
            let cached = await request.conditionallyBeginAccessingResources()
            if cached {
                availableTags.insert(tag)
            } else {
                // Not cached — start background download
                do {
                    try await request.beginAccessingResources()
                    availableTags.insert(tag)
                } catch {
                    // Best-effort — silently ignore prefetch failures
                }
            }
        }
    }

    /// Release resources when no longer needed (e.g., leaving a tab).
    /// The system may purge them from disk to reclaim storage.
    func release(_ tag: ODRTag) {
        activeRequests[tag]?.endAccessingResources()
        activeRequests[tag] = nil
        availableTags.remove(tag)
        activeDownloads.remove(tag)
        progress[tag] = nil
    }

    /// Check if a tag is immediately available (cached or bundled) without downloading.
    func checkAvailability(_ tag: ODRTag) async -> Bool {
        if availableTags.contains(tag) { return true }

        let request = NSBundleResourceRequest(tags: [tag.rawValue])
        let available = await request.conditionallyBeginAccessingResources()
        if available {
            availableTags.insert(tag)
            activeRequests[tag] = request
        }
        return available
    }

    // MARK: - Private Helpers

    private func waitForRequest(_ request: NSBundleResourceRequest, tag: ODRTag) async -> Bool {
        do {
            try await request.beginAccessingResources()
            availableTags.insert(tag)
            activeDownloads.remove(tag)
            progress[tag] = 1.0
            return true
        } catch {
            activeDownloads.remove(tag)
            activeRequests[tag] = nil
            errors[tag] = error.localizedDescription
            print("[ODR] Failed to load \(tag.rawValue): \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Image Prewarming

/// Preloads images into the system cache on a background thread.
/// Once cached, SwiftUI's Image("name") displays them instantly — no lazy load delay.
enum ImagePrewarmer {

    /// Prewarm a list of asset names with timing diagnostics.
    static func prewarm(_ names: [String], label: String = "") {
        Task.detached(priority: .utility) {
            let batchStart = CFAbsoluteTimeGetCurrent()
            var slowImages: [(String, Double)] = []

            for name in names {
                let start = CFAbsoluteTimeGetCurrent()
                let img = UIImage(named: name)
                let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000

                if ms > 10 { // Log anything over 10ms
                    slowImages.append((name, ms))
                }
                if img == nil {
                    print("[Prewarm] MISSING: \(name)")
                }
            }

            let totalMs = (CFAbsoluteTimeGetCurrent() - batchStart) * 1000
            print("[Prewarm] \(label.isEmpty ? "" : "\(label): ")\(names.count) images in \(String(format: "%.0f", totalMs))ms")
            for (name, ms) in slowImages.sorted(by: { $1 < $0 }) {
                print("[Prewarm]   SLOW: \(name) — \(String(format: "%.0f", ms))ms")
            }
        }
    }

    /// Prewarm images needed on the Home screen
    static func prewarmHome() {
        prewarm([
            "recipe_chicken_veggie_platter",
            "bg_garden", "bg_kitchen", "bg_farm",
            "pip_neutral", "pip_waving",
        ], label: "Home")
    }

    /// Prewarm images needed for the Garden tab
    static func prewarmGarden() {
        prewarm([
            "bg_garden", "seed_bag_background", "vegetable_basket",
        ] + (1...15).map { String(format: "pip_walking_frame_%02d", $0) }, label: "Garden")
    }

    /// Prewarm images needed for the Farm/Shop tab
    static func prewarmFarm() {
        prewarm([
            "bg_farm", "bg_farm_open_doors",
        ] + (1...15).map { String(format: "pip_walking_frame_%02d", $0) }, label: "Farm")
    }

    /// Prewarm ALL heavy images at app launch — call once from app startup
    static func prewarmAll() {
        prewarm([
            // Backgrounds
            "bg_garden", "bg_kitchen", "bg_farm", "bg_farm_open_doors", "bg_cottage",
            // Pip frames
            "pip_neutral", "pip_waving", "pip_cooking", "pip_thinking",
            "pip_excited", "pip_celebrating",
            "pip_got_idea", "pip_important", "pip_misses_you",
            "pip_points_right", "pip_points_up_left", "pip_points_up_right", "pip_upset",
            // Recipe images
            "recipe_chicken_veggie_platter", "recipe_veggie_omelette",
            "recipe_scrambled_egg_bowl", "recipe_pumpkin_soup",
            // Walking frames
        ] + (1...15).map { String(format: "pip_walking_frame_%02d", $0) }
         + (1...15).map { String(format: "pip_waving_frame_%02d", $0) }, label: "ALL")
    }
}

// MARK: - ODRImageView

/// Drop-in replacement for `Image()` that waits for ODR resources before displaying.
/// Shows a placeholder shimmer while the tag downloads.
struct ODRImageView: View {
    let name: String
    let tag: ODRTag

    @StateObject private var odr = ODRManager.shared
    @State private var isReady = false

    var body: some View {
        Group {
            if isReady {
                Image(name)
                    .resizable()
            } else {
                // Placeholder shimmer
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.AppTheme.warmCream)
                    .overlay {
                        if let prog = odr.progress[tag], prog < 1.0 {
                            ProgressView(value: prog)
                                .tint(Color.AppTheme.sage)
                                .padding()
                        } else {
                            ProgressView()
                                .tint(Color.AppTheme.sage)
                        }
                    }
            }
        }
        .task {
            if odr.availableTags.contains(tag) {
                isReady = true
            } else {
                let success = await odr.request(tag)
                isReady = success
            }
        }
    }
}

// MARK: - View Modifier for Tab Entry

/// Requests ODR tags when a view appears. Shows Pip loading screen until assets are ready.
struct ODRRequestModifier: ViewModifier {
    let tags: [ODRTag]
    let releaseOnDisappear: Bool

    @StateObject private var odr = ODRManager.shared
    @State private var ready = false

    func body(content: Content) -> some View {
        ZStack {
            if ready {
                content
            } else {
                // Pip loading screen while ODR downloads
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
            // Check if already available first (instant)
            let allReady = tags.allSatisfy { odr.availableTags.contains($0) }
            if allReady {
                ready = true
                return
            }
            // Download and wait
            await odr.request(tags)
            withAnimation(.easeInOut(duration: 0.3)) {
                ready = true
            }
        }
        .onDisappear {
            if releaseOnDisappear {
                for tag in tags {
                    odr.release(tag)
                }
            }
        }
    }
}

extension View {
    /// Request ODR resources when this view appears.
    /// Shows Pip loading screen until assets are downloaded, then reveals content.
    func requestODR(_ tags: ODRTag..., releaseOnDisappear: Bool = false) -> some View {
        modifier(ODRRequestModifier(tags: tags, releaseOnDisappear: releaseOnDisappear))
    }
}
