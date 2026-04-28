//
//  AssetPackImage.swift
//  ChefAcademy
//
//  SwiftUI view that displays an image from an Apple-Hosted Asset Pack.
//  Drop-in replacement for `Image("name")` when the asset has been moved
//  out of `Assets.xcassets` into a pack folder.
//
//  TEACHING MOMENT: Why we can't just use Image("name")
//  ─────────────────────────────────────────────────────
//  SwiftUI's `Image(_ name: String)` looks up assets in the compiled
//  asset catalog (`.car` file) inside the main bundle. Asset packs ship
//  outside the catalog as raw .png files in the system's pack storage.
//  The catalog has no entry for them, so `Image("cucumber_veggie")`
//  returns a "no image found" placeholder.
//
//  We have to:
//    1. Ask AssetPackManager for the file URL on disk
//    2. Read the bytes (off the main thread — file I/O is slow)
//    3. Decode into a UIImage
//    4. Hand the UIImage to `Image(uiImage:)`
//
//  USAGE:
//      AssetPackImage("recipe_veggie_omelette", in: .recipes)
//          .scaledToFill()
//          .frame(width: 60, height: 60)
//          .clipShape(RoundedRectangle(cornerRadius: 12))
//

import BackgroundAssets
import SwiftUI
import System
import UIKit

@available(iOS 26.4, macOS 26.4, *)
struct AssetPackImage: View {

    /// Filename without extension (e.g. `"cucumber_veggie"` for `cucumber_veggie.png`).
    /// Matches the asset name used in the original `Image("...")` call.
    let name: String

    /// The pack this asset lives in. Determines which manifest the system searches.
    let pack: AssetPackID

    // Convenience init so call sites read like the old Image(_:):
    //   AssetPackImage("recipe_veggie_omelette", in: .recipes)
    init(_ name: String, in pack: AssetPackID) {
        self.name = name
        self.pack = pack
    }

    // MARK: - State

    @State private var uiImage: UIImage?
    @State private var loadFailed = false

    @ObservedObject private var controller = AssetPackController.shared

    // MARK: - Body

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                placeholder
            }
        }
        // task(id:) — re-runs when `name` changes. Necessary because
        // the same AssetPackImage view can be reused with different names
        // (e.g., scrolling through recipe cards in a list).
        .task(id: name) {
            await loadImage()
        }
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        Color.AppTheme.warmCream
            .overlay {
                if loadFailed {
                    // Quiet failure indicator — doesn't scream at kids
                    Image(systemName: "photo")
                        .font(.AppTheme.title3)
                        .foregroundColor(Color.AppTheme.lightSepia)
                } else {
                    ProgressView()
                        .tint(Color.AppTheme.sage)
                }
            }
    }

    // MARK: - Load

    private func loadImage() async {
        // Reset prior render — handles the .task(id:) re-run when name changes
        await MainActor.run {
            self.uiImage = nil
            self.loadFailed = false
        }

        // Step 1 — make sure the pack is on disk
        let packReady = controller.availablePacks.contains(pack)
            ? true
            : await controller.ensureAvailable(pack)

        guard packReady else {
            await MainActor.run { self.loadFailed = true }
            return
        }

        // Step 2 — get the file URL from the system
        let filename = "\(name).png"
        guard let url = await fileURL(filename: filename) else {
            #if DEBUG
            print("[AssetPackImage] missing file: \(filename) in '\(pack.rawValue)'")
            #endif
            await MainActor.run { self.loadFailed = true }
            return
        }

        // Step 3 — decode UIImage off-main, hop back to publish
        //
        // TEACHING MOMENT: Why detached?
        // UIImage(contentsOfFile:) does sync disk read + image decode —
        // both can take 1-50ms. Doing it on the main thread blocks scrolling
        // and animations. `Task.detached` runs on a background pool; the
        // `MainActor.run` at the end is the only main-thread hop.
        let loaded = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: url.path)
        }.value

        await MainActor.run {
            if let loaded {
                self.uiImage = loaded
            } else {
                self.loadFailed = true
            }
        }
    }

    /// Look up the file URL via AssetPackManager. Returns nil on any error.
    private func fileURL(filename: String) async -> URL? {
        do {
            return try await AssetPackManager.shared.url(for: FilePath(filename))
        } catch {
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: AppSpacing.md) {
        AssetPackImage("recipe_veggie_omelette", in: .recipes)
            .aspectRatio(contentMode: .fit)
            .frame(height: 200)

        AssetPackImage("missing_asset_for_demo", in: .recipes)
            .aspectRatio(contentMode: .fit)
            .frame(height: 100)
    }
    .padding()
    .background(Color.AppTheme.cream)
}
