# Apple-Hosted Background Assets — Implementation Guide

A step-by-step guide for migrating off On-Demand Resources (ODR) to Apple-Hosted Background Assets in any iOS app.

Based on real implementation in ChefAcademy (Apr 2026). Every gotcha listed under "Pitfalls" is one we actually hit.

---

## What this gets you

- Off-device asset hosting on Apple's CDN (200 GB free with Developer Program)
- Smaller IPA at install time
- Replaces ODR (deprecated as of WWDC25)
- Asset packs version independently of app builds

## What this is NOT

- Not a hot-update mechanism for code or non-resource files
- Not a CDN for arbitrary files (only image / video / audio / font / data resources)
- Not free of friction during dev — local testing is genuinely painful (see Pitfalls)

---

## Prerequisites

| Requirement | Why |
|---|---|
| iOS 26.4+ deployment target | `assetPackIsAvailableLocally` and related APIs ship in 26.4, NOT 26.0 as the high-level docs imply |
| Xcode 26.x | `xcrun ba-package` and `xcrun ba-serve` ship with Xcode |
| Apple Developer Program | Required for App ID, App Group, Apple-hosted CDN |
| App Store Connect access | The only way to test asset pack downloads is via TestFlight (see Pitfall #6) |
| App ID registered with Apple | Standard requirement |

---

## Step 1 — Register an App Group (Apple Developer Portal)

The main app and the download extension share state through an App Group container.

1. Go to [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers)
2. Top dropdown: change "App IDs" → **App Groups**
3. Click "+" → Continue
4. Description: e.g. `MyApp Asset Packs`
5. Identifier: `group.<your.bundle.id>` (must start with `group.`)
6. Continue → Register

In Xcode's Signing & Capabilities tab for both the main app and the extension target, add the **App Groups** capability and tick the new group.

---

## Step 2 — Project build settings

Open `*.xcodeproj/project.pbxproj` (or use Xcode UI). For the main app target:

| Setting | Value |
|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | `26.4` |
| `ENABLE_ON_DEMAND_RESOURCES` | `NO` |
| `GENERATE_INFOPLIST_FILE` | `NO` |
| `INFOPLIST_FILE` | `Info.plist` (path relative to project root) |

The `INFOPLIST_FILE` path is **critical** — see Pitfall #2.

---

## Step 3 — Info.plist (project root, NOT inside the synced source folder)

Create `Info.plist` at the **project root level**, not inside your `MyApp/` source folder.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Background Assets — REQUIRED -->
    <key>BAAppGroupID</key>
    <string>group.your.bundle.id</string>
    <key>BAHasManagedAssetPacks</key>
    <true/>
    <key>BAUsesAppleHosting</key>
    <true/>

    <!-- Standard bundle metadata — required because GENERATE_INFOPLIST_FILE=NO
         disables Xcode's automatic merging. List every key your app needs. -->
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>

    <key>LSRequiresIPhoneOS</key>
    <true/>

    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>

    <key>UILaunchScreen</key>
    <dict/>

    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>

    <!-- Add any usage descriptions, custom URL schemes, etc. that your app needs.
         With GENERATE_INFOPLIST_FILE=NO, INFOPLIST_KEY_* build settings are
         ignored — every key must be in this file explicitly. -->
</dict>
</plist>
```

**Why these three BA keys:**

- `BAAppGroupID` — tells the system which App Group container to write downloaded packs into
- `BAHasManagedAssetPacks` — opts you into the managed asset pack system (vs. self-hosted Background Assets)
- `BAUsesAppleHosting` — tells the system to fetch from Apple's CDN (vs. your own server)

---

## Step 4 — Entitlements (main app)

In `MyApp.entitlements`:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.your.bundle.id</string>
</array>
```

Plus any other entitlements your app already needs (CloudKit, push, Game Center, etc.).

---

## Step 5 — Add the download extension target

This is the single most error-prone step. **Do not pick the wrong template.**

1. In Xcode: **File → New → Target**
2. Filter: type "background"
3. **CHOOSE: "Background Download"** (icon: a downward arrow)
4. **DO NOT CHOOSE: "Background Delivery"** (that's FinanceKit, used for banking apps — has nothing to do with asset packs)
5. Name: e.g. `MyAppAssetPackDownloader`
6. Embed in: your main app
7. When prompted, choose **"Apple-hosted"** (vs. "self-hosted")
8. Finish

Xcode generates a Swift file with a `StoreDownloaderExtension`-conforming type. The minimal implementation:

```swift
import BackgroundAssets
import ExtensionFoundation
import StoreKit

@main
struct DownloaderExtension: StoreDownloaderExtension {
    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        return true
    }
}
```

In the extension target's **Signing & Capabilities** tab, add the same App Group as the main app.

The extension's `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` build values **must match the main app's**, or Xcode flags it as a binary mismatch. Easiest is to point them at the same `$(CURRENT_PROJECT_VERSION)` variable in their build settings.

---

## Step 6 — `AssetPackController.swift` (main app code)

A `@MainActor` wrapper over `AssetPackManager.shared` (which is a system actor, off-main). Mirrors a typical ODR API shape so call sites are mechanical to migrate.

```swift
import BackgroundAssets
import Combine
import Foundation
import SwiftUI

// One case per .aar bundle you ship. The rawValue MUST match the
// `assetPackID` field in that pack's Manifest.json.
enum AssetPackID: String, CaseIterable, Sendable {
    case recipes
    case kitchen
    case garden
    case farm
}

@MainActor
@available(iOS 26.4, macOS 26.4, *)
final class AssetPackController: ObservableObject {
    static let shared = AssetPackController()

    @Published private(set) var activeDownloads: Set<AssetPackID> = []
    @Published private(set) var progress: [AssetPackID: Double] = [:]
    @Published private(set) var availablePacks: Set<AssetPackID> = []
    @Published private(set) var errors: [AssetPackID: String] = [:]

    private var activeTasks: [AssetPackID: Task<Bool, Never>] = [:]

    private init() {
        Task { await self.bootstrap() }
    }

    private func bootstrap() async {
        for pack in AssetPackID.allCases {
            let isLocal = AssetPackManager.shared.assetPackIsAvailableLocally(withID: pack.rawValue)
            if isLocal {
                availablePacks.insert(pack)
                progress[pack] = 1.0
            }
        }
    }

    @discardableResult
    func ensureAvailable(_ pack: AssetPackID) async -> Bool {
        if availablePacks.contains(pack) { return true }
        if let existing = activeTasks[pack] { return await existing.value }

        let task = Task<Bool, Never> { [weak self] in
            guard let self else { return false }
            return await self.performDownload(pack: pack)
        }
        activeTasks[pack] = task
        let result = await task.value
        activeTasks[pack] = nil
        return result
    }

    func ensureAvailable(_ packs: [AssetPackID]) async {
        await withTaskGroup(of: Void.self) { group in
            for pack in packs {
                group.addTask { _ = await self.ensureAvailable(pack) }
            }
        }
    }

    func prefetch(_ pack: AssetPackID) {
        guard !availablePacks.contains(pack), activeTasks[pack] == nil else { return }
        Task { _ = await ensureAvailable(pack) }
    }

    func release(_ pack: AssetPackID) async {
        do {
            try await AssetPackManager.shared.remove(assetPackWithID: pack.rawValue)
            availablePacks.remove(pack)
            progress[pack] = nil
            errors[pack] = nil
        } catch {
            // log and swallow — release is best-effort
        }
    }

    func checkAvailability(_ pack: AssetPackID) -> Bool {
        let isLocal = AssetPackManager.shared.assetPackIsAvailableLocally(withID: pack.rawValue)
        if isLocal && !availablePacks.contains(pack) {
            availablePacks.insert(pack)
            progress[pack] = 1.0
        }
        return isLocal
    }

    private func performDownload(pack: AssetPackID) async -> Bool {
        activeDownloads.insert(pack)
        errors[pack] = nil
        progress[pack] = 0.0

        do {
            let assetPack = try await AssetPackManager.shared.assetPack(withID: pack.rawValue)
            try await AssetPackManager.shared.ensureLocalAvailability(of: assetPack, requireLatestVersion: false)
            availablePacks.insert(pack)
            activeDownloads.remove(pack)
            progress[pack] = 1.0
            return true
        } catch {
            activeDownloads.remove(pack)
            errors[pack] = error.localizedDescription
            progress[pack] = nil
            return false
        }
    }
}

// View modifier for "wait for pack before revealing"
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
                ProgressView("Loading…")
                    .transition(.opacity)
            }
        }
        .task {
            let allReady = packs.allSatisfy { controller.availablePacks.contains($0) }
            if allReady { ready = true; return }
            await controller.ensureAvailable(packs)
            withAnimation { ready = true }
        }
        .onDisappear {
            if releaseOnDisappear {
                Task { for pack in packs { await controller.release(pack) } }
            }
        }
    }
}

extension View {
    @available(iOS 26.4, macOS 26.4, *)
    func ensureAssetPacks(_ packs: AssetPackID..., releaseOnDisappear: Bool = false) -> some View {
        modifier(EnsureAssetPacksModifier(packs: packs, releaseOnDisappear: releaseOnDisappear))
    }
}
```

---

## Step 7 — `AssetPackImage.swift` (drop-in `Image` replacement)

`Image("name")` won't work for packed assets — they aren't in the compiled asset catalog. You have to load the file URL via `AssetPackManager`, decode `UIImage` off-main, then render.

```swift
import BackgroundAssets
import SwiftUI
import System
import UIKit

@available(iOS 26.4, macOS 26.4, *)
struct AssetPackImage: View {
    let name: String
    let pack: AssetPackID

    init(_ name: String, in pack: AssetPackID) {
        self.name = name
        self.pack = pack
    }

    @State private var uiImage: UIImage?
    @State private var loadFailed = false
    @ObservedObject private var controller = AssetPackController.shared

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                placeholder
            }
        }
        .task(id: name) { await loadImage() }
    }

    private var placeholder: some View {
        Color.gray.opacity(0.1)
            .overlay {
                if loadFailed {
                    Image(systemName: "photo")
                } else {
                    ProgressView()
                }
            }
    }

    private func loadImage() async {
        await MainActor.run {
            self.uiImage = nil
            self.loadFailed = false
        }

        let packReady = controller.availablePacks.contains(pack)
            ? true
            : await controller.ensureAvailable(pack)

        guard packReady else {
            await MainActor.run { self.loadFailed = true }
            return
        }

        let filename = "\(name).png"
        guard let url = await fileURL(filename: filename) else {
            await MainActor.run { self.loadFailed = true }
            return
        }

        // Decode off-main — file I/O + image decode together can take 1-50ms
        let loaded = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: url.path)
        }.value

        await MainActor.run {
            if let loaded { self.uiImage = loaded }
            else { self.loadFailed = true }
        }
    }

    private func fileURL(filename: String) async -> URL? {
        do {
            return try await AssetPackManager.shared.url(for: FilePath(filename))
        } catch {
            return nil
        }
    }
}
```

**Migrating call sites:**

```swift
// Before
Image("recipe_omelette")
    .resizable()
    .frame(width: 60, height: 60)

// After
AssetPackImage("recipe_omelette", in: .recipes)
    .scaledToFill()
    .frame(width: 60, height: 60)
```

For tab views that need a whole pack ready before rendering:

```swift
RecipeListView()
    .ensureAssetPacks(.recipes)
```

---

## Step 8 — Pack folder structure

At your project root, create an `AssetPacks/` directory. One subfolder per pack:

```
AssetPacks/
  recipes/
    Manifest.json
    recipe_omelette.png
    recipe_pasta.png
    ...
  garden/
    Manifest.json
    veggie_carrot.png
    ...
```

**`Manifest.json` for each pack:**

```json
{
    "assetPackID": "recipes",
    "downloadPolicy": {
        "essential": {
            "installationEventTypes": ["firstInstallation", "subsequentUpdate"]
        }
    },
    "fileSelectors": [
        { "file": "recipe_omelette.png" },
        { "file": "recipe_pasta.png" }
    ],
    "platforms": ["iOS"]
}
```

`assetPackID` MUST match the `rawValue` in your `AssetPackID` enum.

`downloadPolicy` options:
- `essential` — downloaded automatically at install / update time
- `prefetch` — downloaded automatically at install time but not blocking
- `onDemand` — downloaded only when your code calls `ensureAvailable`

For most apps, `essential` is right for assets the app needs to function. Use `onDemand` for level-specific or chapter-specific content.

---

## Step 9 — Build the `.aar`

```bash
xcrun ba-package package AssetPacks/recipes/Manifest.json --output-path AssetPacks/recipes.aar
```

The subcommand is `package` (NOT `create`). Output is a single `.aar` file (it's a tar archive).

Add `*.aar` to your `.gitignore` — these are build artifacts, not source.

---

## Step 10 — Upload to App Store Connect

Use **Transporter** from the Mac App Store. Easiest path:

1. Open Transporter
2. Sign in with your developer Apple ID
3. Drag the `.aar` file into the Transporter window
4. Click **Deliver**
5. Wait ~5-10 min for Apple processing

Alternatives:
- `xcrun altool --upload-asset-pack <path> --apple-id <id> -u <email> -p <app-specific-password>`
- App Store Connect REST API

You can upload asset packs **independently of app builds**. Once delivered and processed, the pack is available to any TestFlight or App Store build of your app that references the same `assetPackID`.

---

## Step 11 — Test on TestFlight

This is the **only realistic dev test path**. See Pitfall #6 for why.

1. Bump your app's `CURRENT_PROJECT_VERSION` (build number)
2. Switch Xcode destination to **Any iOS Device (arm64)**
3. Product → Archive
4. In the Organizer that opens: **Distribute App** → **App Store Connect** → **Upload** → defaults
5. Wait ~10-30 min for Apple to process
6. On your iPhone, open **TestFlight** → install / update your app
7. Launch — asset pack downloads from CDN with valid TLS, your `AssetPackImage` views populate

---

## Pitfalls — every wall we hit

### #1 — `INFOPLIST_KEY_BA*` build settings silently dropped

Xcode's `INFOPLIST_KEY_*` mechanism only works for keys on Apple's allow-list (`NS*`, `UI*`, `CF*`). The `BA*` keys are NOT on that list and will be silently ignored.

**Fix:** use an explicit `Info.plist` file with `GENERATE_INFOPLIST_FILE=NO` and `INFOPLIST_FILE=Info.plist`.

### #2 — `Info.plist` cannot live inside the auto-synced source folder

Modern Xcode projects use `PBXFileSystemSynchronizedRootGroup` to auto-include all files in your `MyApp/` source folder as build resources. If `Info.plist` is in that folder AND you point `INFOPLIST_FILE` at it, you get:

```
error: Multiple commands produce '.../Info.plist'
```

**Fix:** keep `Info.plist` at the project root, OUTSIDE the auto-synced source folder.

### #3 — With `GENERATE_INFOPLIST_FILE=NO`, you must hand-list every standard key

Disabling generation also disables the auto-merge of build-setting-derived keys (`CFBundleExecutable`, `CFBundleIdentifier`, etc.). Your app will crash at launch without these.

**Fix:** include all CFBundle*/UI*/NS* keys in your `Info.plist` using `$(VAR)` substitution so Xcode injects per-config values.

### #4 — Wrong extension template ("Background Delivery" is FinanceKit)

Xcode shows multiple "Background"-prefixed extension templates. **"Background Delivery Extension"** is for FinanceKit (banking apps), NOT Background Assets — picking it produces signing errors that look unrelated.

**Fix:** use **"Background Download"** template, then choose "Apple-hosted" when prompted. If you picked the wrong one, delete the target via the `–` button in target list, choose "Move to Trash", and start over.

### #5 — `xcrun ba-package` subcommand confusion

The subcommand is `package`, NOT `create`. Output flag is `--output-path`, NOT `-o` or `--output`.

```bash
# CORRECT
xcrun ba-package package <manifest.json> --output-path <out.aar>

# WRONG (will print help text)
xcrun ba-package create <manifest.json> -o <out.aar>
```

### #6 — Apple-Hosted asset packs only work via TestFlight or App Store

Per Apple framework engineers in the dev forums:

> "Apple-hosted packs currently only work for internal testers on TestFlight or from the App Store. Won't work from Xcode until later this year."

This means:

- **Running from Xcode on a device** — asset pack downloads fail (HTTP 400 from CDN)
- **Local `xcrun ba-serve` dev server** — `BackgroundAssets` framework rejects ba-serve's self-signed TLS cert (it's signed by your Apple Development cert, which iOS trusts for code signing only, not TLS). ATS overrides in iOS Developer Settings do NOT apply to BackgroundAssets — verified.
- **Simulator (iOS 26.4)** — known Apple bug: `"No team ID was specified for the app"`. Fixed in iOS 26.5 beta only.

**Fix:** plan to test via TestFlight from day one. Build, archive, upload, install via TestFlight, repeat. ~15-30 min round-trip per iteration. Frustrating but the only working path until Xcode 26.5 GA.

### #7 — Extension `CURRENT_PROJECT_VERSION` must match main app

If you bump the main app build version but forget the extension, you get:

```
warning: The CFBundleVersion of an app extension ('1') must match that of its containing parent app ('3').
```

**Fix:** keep extension and main app build numbers in sync. Easiest: edit both manually in Xcode's General tab, or have the extension reference `$(CURRENT_PROJECT_VERSION)` from the same configuration.

### #8 — `Image("name")` returns blank for packed assets

`SwiftUI.Image(_ name: String)` looks up assets in the compiled asset catalog (`.car`) inside the main bundle. Asset packs ship outside the catalog as raw files in the system's pack storage. The catalog has no entry, so the lookup silently fails.

**Fix:** use the `AssetPackImage` wrapper from Step 7. There's no shortcut — the file URL has to come from `AssetPackManager`.

### #9 — `BAAppleHosting` warnings about team ID

`AssetPackManager` reads your team ID from the embedded provisioning profile. On simulator / unsigned builds, there's no profile, hence "No team ID specified". This is the same bug as Pitfall #6.

**Fix:** test on TestFlight. The signed TestFlight build has a valid provisioning profile and team ID is found automatically.

---

## Iterative migration strategy

For an existing app with many bundled assets, don't migrate everything at once. Recommended order:

1. **Pick the smallest pack first.** Validates the full pipeline (manifest → .aar → Transporter → TestFlight) with minimal mechanical work.
2. **Get one pack working end-to-end.** Verify on TestFlight. Commit.
3. **Migrate progressively bigger packs** as confidence grows. Each migration is mostly:
   - Move source PNGs from `Assets.xcassets/<Name>/` to `AssetPacks/<name>/`
   - Add files to `Manifest.json`
   - Swap `Image("foo")` → `AssetPackImage("foo", in: .pack)` at call sites
   - Wrap views with `.ensureAssetPacks(.pack)` where loading state is acceptable
4. **Don't migrate during active asset churn.** Adding new images to a packed asset means rebuild .aar + Transporter upload + version bump on every iteration. Painful for active dev. Migrate when the asset list stabilizes (typically pre-launch).

---

## Versioning & updating packs

Every `.aar` upload to App Store Connect creates a new version of the pack. The system tracks pack versions independently per app.

When you update assets:
1. Replace files in `AssetPacks/<name>/`
2. Update `Manifest.json` if file list changed
3. Rebuild: `xcrun ba-package package <manifest> --output-path <aar>`
4. Upload via Transporter
5. ASC auto-increments the pack version

The `requireLatestVersion: false` flag in `ensureLocalAvailability` lets cached older versions remain usable. Set to `true` if you've shipped breaking changes that require the user to refetch.

---

## Reference

- [Apple Developer — Background Assets](https://developer.apple.com/documentation/backgroundassets)
- [Creating managed asset packs](https://developer.apple.com/documentation/backgroundassets/creating-managed-asset-packs)
- [Downloading Apple-hosted asset packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs)
- [App Store Connect — Asset Packs overview](https://developer.apple.com/help/app-store-connect/manage-asset-packs/overview-of-apple-hosted-asset-packs/)
- [WWDC25: Discover Apple-Hosted Background Assets](https://developer.apple.com/videos/play/wwdc2025/325/)
