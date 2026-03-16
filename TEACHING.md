# TEACHING.md — iOS/Swift Learning Log

Personal reference built from real code in Pip's Kitchen Garden. Newest lessons first.

---

## Session: March 15, 2026 (continued)

### Codable Backwards Compatibility
**Where it came up:** PlotData crash when adding new fields (hasWatered, hasWeeded)
**What it is:** When you add new fields to a Codable struct, Swift's auto-generated decoder expects ALL keys in the saved JSON. Old data doesn't have the new keys → crash. Fix: write a custom `init(from decoder:)` using `decodeIfPresent` with `?? defaultValue` for new fields.
**In our code:** `hasWatered = try c.decodeIfPresent(Bool.self, forKey: .hasWatered) ?? false` — old PlotData without care tracking loads fine, defaults to false.
**Why it matters:** Every time you add a field to a saved struct, you MUST handle backwards compatibility. Real apps have millions of users with old data — you can't crash them.

### API Response Structure Mismatch
**Where it came up:** USDA FoodData API — golden badges weren't showing
**What it is:** APIs can return different JSON structures from different endpoints. The USDA `/foods/search` endpoint returns flat fields (`nutrientNumber`, `value`) but `/food/{id}` returns nested ones (`nutrient.number`, `amount`). Our decoder only handled one format.
**In our code:** Added `USDANutrientDetail` struct and unified accessors: `var number: String? { nutrientNumber ?? nutrient?.number }` — works with both formats.
**Why it matters:** Always test your API decoder with the ACTUAL response. Don't trust documentation alone — `curl` the endpoint and look at the real JSON.

### Xcode Asset Catalog (.imageset)
**Where it came up:** frying_pan.png, empty_plate.png, cracked eggs — all loose PNGs
**What it is:** Xcode requires images inside `.imageset` folders with a `Contents.json` manifest. The manifest maps filenames to screen scales (1x, 2x, 3x). `Image("name")` in SwiftUI looks for a matching imageset, not a loose file.
**In our code:** Created `frying_pan.imageset/Contents.json` pointing to `frying_pan.png` at 1x scale. Without this, `Image("frying_pan")` returns nothing — no error, just invisible.
**Why it matters:** This is a common gotcha. You drag an image into Assets.xcassets in Xcode's GUI and it creates the imageset automatically. From the filesystem (like we do), you must create it manually.

---

## Session: March 15, 2026

### Singleton Pattern
**Where it came up:** PipVoice.swift, USDAFoodService.swift, GardenWeatherService.swift
**What it is:** A singleton means there's only ONE instance of a class in the whole app. You create it with `static let shared = MyClass()` and access it everywhere with `MyClass.shared`.
**In our code:** `PipVoice.shared.speak("Hello!")` — every screen uses the same voice instance, so if one screen starts speaking and another stops it, they're controlling the same synthesizer.
**Why it matters:** Without a singleton, each screen would create its own speaker — they'd talk over each other, and muting in one place wouldn't mute the others.

### async/await (Asynchronous Code)
**Where it came up:** USDAFoodService.swift, GardenWeatherService.swift
**What it is:** Network calls take time (0.1-2 seconds). If you wait synchronously, the whole app freezes. `async` marks a function as "this takes time", and `await` means "pause here until the result comes back, but let the app keep running."
**In our code:** `nutrientProfile = await usdaService.nutrientProfile(for: veggie.rawValue)` — fetches nutrition from USDA's server without freezing the UI. The `Task { }` wrapper lets you call async code from a synchronous context like `.onAppear`.
**Why it matters:** Without async/await, tapping a seed bag would freeze the entire app for 1-2 seconds while waiting for the API response. Kids would think the app is broken.

### Pattern Matching (switch on enums)
**Where it came up:** SeedInfoView.swift `usdaAmount()`, PlotView.swift, GardenWeatherService.swift
**What it is:** Swift's `switch` is more powerful than most languages. It can match enum cases, bind values, check conditions, and the compiler forces you to handle EVERY case (no bugs from missing one).
**In our code:** `switch nutrient { case .vitaminA: value = profile.vitaminA ... }` maps our game's NutrientType enum to real USDA data fields. Swift won't compile if you forget a nutrient type.
**Why it matters:** This "exhaustive matching" catches bugs at compile time. When you add a new NutrientType case later, the compiler will show errors everywhere you need to handle it.

### ObservableObject + @Published
**Where it came up:** PipVoice.swift (`@Published var isSpeaking`), USDAFoodService.swift (`@Published var cache`)
**What it is:** `ObservableObject` is a protocol that lets SwiftUI watch a class for changes. `@Published` marks which properties trigger a view redraw when they change. Together they connect your data to your UI.
**In our code:** `SpeakerButton` uses `@ObservedObject private var voice = PipVoice.shared`. When `voice.isSpeaking` changes to true, the button icon automatically switches from `speaker.wave.2` to `speaker.wave.3.fill` — no manual refresh needed.
**Why it matters:** This is the core of SwiftUI's "reactive" design. You change data, views update automatically. No need to manually tell the UI "hey, redraw yourself."

### Struct vs Class (Value vs Reference Types)
**Where it came up:** GardenPlot (struct) vs GameState (class)
**What it is:** Structs are copied when assigned (`var b = a` makes an independent copy). Classes are shared (`var b = a` means both point to the same object). SwiftUI views are structs. State managers are classes.
**In our code:** `GardenPlot` is a struct — each plot in the array is independent. When you do `gameState.gardenPlots[index].water()`, you're modifying that specific plot's copy. `GameState` is a class (ObservableObject) because all views need to share the same game data.
**Why it matters:** If GardenPlot were a class, changing one plot could accidentally affect another if they shared a reference. Structs are safer for data models. Classes are needed when multiple views must share state.

### AVSpeechSynthesizer (Text-to-Speech)
**Where it came up:** PipVoice.swift
**What it is:** Apple's built-in text-to-speech engine. Works completely offline, no API needed. You create an `AVSpeechUtterance` with text, set voice properties (rate, pitch, volume), and hand it to the synthesizer.
**In our code:** `utterance.rate = 0.45` (slightly slower for kids), `utterance.pitchMultiplier = 1.2` (slightly higher for cute hedgehog voice). The delegate methods track speaking state for the UI.
**Why it matters:** For a 6-year-old audience, reading text is hard. Voice makes the app accessible to pre-readers and kids with dyslexia — it's not just a nice feature, it's a P0 accessibility requirement.

### API Response Caching
**Where it came up:** USDAFoodService.swift, GardenWeatherService.swift
**What it is:** Saving API responses locally so you don't re-fetch the same data every time. USDA nutrition for a carrot never changes, so we fetch once and cache forever. Weather changes, so we cache for 30 minutes.
**In our code:** `cache` dictionary stored in UserDefaults via JSONEncoder. On app launch, `loadCache()` restores it. On fetch, `saveCache()` persists it. Next time the user opens carrot info — instant, no network needed.
**Why it matters:** Saves battery, works offline, respects API rate limits (1000 requests/hour), and makes the app feel instant. Real production apps always cache API data.

### Entitlements & Capabilities (WeatherKit)
**Where it came up:** ChefAcademy.entitlements, Apple Developer Portal
**What it is:** Some Apple features (WeatherKit, CloudKit, Push Notifications) require permission at THREE levels: (1) entitlements file in Xcode, (2) capability enabled on your App ID in the developer portal, (3) provisioning profile that includes the capability.
**In our code:** WeatherKit was enabled in both places but kept failing with a JWT error. The fix: toggle "Automatically manage signing" off/on to regenerate the provisioning profile. Apple's servers also need up to 48 hours to activate.
**Why it matters:** This is the #1 thing that trips up new iOS developers. The code can be perfect, but if the signing/capabilities aren't aligned, Apple's servers reject your requests.

### try? vs do/catch (Error Handling)
**Where it came up:** SessionManager.swift `context.save()`, GardenWeatherService.swift
**What it is:** `try?` silently swallows errors — if it fails, you get nil and no clue why. `do { try ... } catch { print(error) }` lets you see what went wrong.
**In our code:** Child profiles weren't persisting because `try? context.save()` was hiding SwiftData errors. We switched to `do/catch` with logging so we can see `[Session] FAILED to save child profile` in the console.
**Why it matters:** Never use `try?` for important operations (saving data, API calls). Silent failures are the hardest bugs to find. Always log errors so you can diagnose problems.

---

*This file grows every session. Use it as a study reference for iOS development concepts.*
