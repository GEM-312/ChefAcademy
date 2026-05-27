# CLAUDE.md - Pip's Kitchen Garden Project Instructions

## Project Overview

**App Name:** Pip's Kitchen Garden · **Platform:** iOS (iPhone/iPad) · **Language:** Swift / SwiftUI · **Target:** Ages 6+ (shifted from 8-12 based on UX audit) · **Developer:** Marina Pollak

A kid-friendly mobile GAME (not just an app) where players:
1. **GROW** vegetables in a garden (simulation + mini-games)
2. **COOK** recipes through fun mini-games (like Cooking Mama)
3. **FEED** their Body Buddy and watch food travel through a cartoon body

The core loop is: **GROW → COOK → FEED → REWARDS → repeat**

## Project Structure

Source is **flat** — all `.swift` files sit directly in `ChefAcademy/` (no Views/Models/ViewModels folders). Grouped below by purpose. Deep relationships → `graphify-out/GRAPH_REPORT.md` (`graphify query/explain`, rebuilt May 27).

```
ChefAcademy/
├── Entry & core state
│   ├── ChefAcademyApp.swift          # @main, AppRoute router (RootRouterView), MainTabView, HomeView
│   ├── ContentView.swift             # legacy root (mostly superseded by ChefAcademyApp)
│   ├── SessionManager.swift          # AppRoute state machine, profile CRUD, PIN, play-time
│   └── GameState.swift               # central state, SwiftData load/save, NutrientType enum
├── SwiftData models
│   ├── FamilyProfile.swift           # @Model, one per device (familyID)
│   ├── UserProfile.swift             # @Model parent|child, profilePoseImage
│   ├── PlayerData.swift              # @Model coins/seeds/plots/recipes/health (ownerID)
│   └── Allergen.swift                # FoodAllergen enum + filtering
├── Profiles / family / PIN / auth
│   ├── ProfilePickerView.swift       # "Who's playing today?"
│   ├── FamilySetupView.swift         # 8-step first-launch wizard
│   ├── AddChildFlowView.swift        # add child (3 steps + dup-name check)
│   ├── MigrationPINSetupView.swift   # legacy single-user upgrade
│   ├── ParentDashboardView.swift     # child stats, play time, allergen edit
│   ├── ParentPINEntryView.swift      # PIN pad host (shared PINPadGrid)
│   ├── PINKeychain.swift             # parent PIN in Keychain (iCloud-synced)
│   ├── AuthManager.swift             # Sign in with Apple
│   └── SignInView.swift              # Apple sign-in screen
├── Design system & shared UI
│   ├── AppTheme.swift                # color/font/spacing/animation tokens, button styles
│   ├── AdaptiveLayout.swift          # iPhone/iPad sizing, .trailingFade(), AdaptiveCardSize
│   ├── PipComponents.swift           # PipSpeechBubble/PipHeaderStack/PipSize/PINPadGrid
│   ├── MorphTransition.swift         # morph + card transitions
│   ├── BackgroundView.swift          # cottage background
│   └── PipDialogView.swift           # modal confirm prompts (BouncyButtonStyle)
├── Pip character & voice
│   ├── PipAnimations.swift           # PipPose enum, PipWavingAnimatedView, walking
│   ├── CharacterWalkingView.swift    # Timer-based walk engine (30fps)
│   ├── PipVoice.swift                # two-tier voice (silent free / ElevenLabs paid)
│   ├── PipGameAnimationView.swift    # game-screen Pip animations
│   └── PipStaticResponses.swift      # hand-written Pip starter replies (free tier)
├── Pip AI chat
│   ├── AskPipView.swift              # chat UI (starter Qs, typing indicator, streaming)
│   ├── PipAIService.swift            # Claude cloud chat — streaming, rate-limited, allergen-aware
│   └── PipFoundationModelService.swift  # on-device FoundationModels (iOS 26+)
├── Garden / shop / plants / weather
│   ├── GardenView.swift              # interactive plot map + draggable Pip
│   ├── PlotView.swift                # per-plot water / weed / bug UX
│   ├── PlantingSheet.swift           # plant-a-seed sheet
│   ├── FarmShopView.swift            # seeds + pantry shop (defines FarmTabView)
│   ├── SeedInfoView.swift            # veggie knowledge cards + PencilKit coloring
│   ├── PantryInfoView.swift          # pantry knowledge cards
│   ├── GardenWeatherService.swift    # WeatherKit (30-min cache)
│   ├── WeatherOverlayView.swift      # rain/snow/storm/seasonal overlays
│   ├── WaterPourCharacterView.swift  # kid pour animation + particles
│   └── GardenHubView.swift           # ORPHAN dead code — planned delete
├── Kitchen / cooking / recipes
│   ├── KitchenView.swift             # cooking scene map; book icon → RecipeListView
│   ├── CookingSessionView.swift      # multi-step mini-game sequencer (state machine)
│   ├── CookingMiniGames.swift        # 9 cooking mini-games
│   ├── ChopMiniGame.swift            # chop (tap-timing)
│   ├── CookingCompletionView.swift   # stars + organ-boost rewards
│   ├── RecipeCardExample.swift       # PantryItem / Recipe / GardenRecipes.all
│   └── RecipeDetailView.swift        # cookbook page, sticky "Let's Cook!" footer
├── Body Buddy & learn/play games
│   ├── BodyBuddyView.swift           # organ health rings
│   ├── PlayLearnView.swift           # mini-games hub
│   ├── HealthyChoiceGameView.swift   # Healthy Picks
│   ├── InsulinTetrisView.swift       # Sugar Sorter
│   └── GlucoseJourneyView.swift      # Pip's Glucose Journey
├── Multiplayer / versus
│   ├── LocalVersusView.swift         # local pass-and-play
│   ├── SplitScreenVersusView.swift   # split-screen versus
│   ├── NearbyVersusView.swift        # nearby (MultipeerConnectivity)
│   ├── MultiplayerHealthyPicksView.swift  # online Healthy Picks
│   ├── MultiplayerManager.swift      # Game Center match
│   ├── NearbyMultiplayerManager.swift  # MultipeerConnectivity
│   ├── GameCenterService.swift       # auth, leaderboards, achievements
│   ├── GameCenterMatchmakerView.swift  # GKMatchmaker bridge
│   └── SeededRandomGenerator.swift   # deterministic RNG for lockstep
├── Avatar / onboarding / profiles
│   ├── AvatarModel.swift             # Gender / Outfit / HeadCovering enums
│   ├── AvatarCreatorView.swift       # outfit + covering tabs
│   ├── OnboardingView.swift          # first-launch onboarding
│   ├── MeetPipAnimated.swift, MeetPipViews.swift  # Meet Pip intro
│   ├── ProfileView.swift             # profile screen
│   ├── SiblingProfileView.swift      # sibling profile
│   └── SiblingGardenView.swift       # visit a sibling's garden (read-only)
├── Subscription / networking / external APIs
│   ├── PaywallView.swift             # Pip Chat $3.99/mo paywall
│   ├── SubscriptionManager.swift     # StoreKit 2
│   ├── WorkerClient.swift            # Cloudflare Worker client
│   ├── AppAttestService.swift        # App Attest device auth
│   ├── APIKeys.swift                 # local dev key — gitignored, NEVER read (see §11)
│   ├── CloudKeyManager.swift         # legacy CloudKit key (Phase 4 delete)
│   ├── USDAFoodService.swift         # USDA FoodData Central nutrition
│   ├── ElevenLabsVoiceService.swift  # paid voice synthesis
│   ├── VoicePickerView.swift         # voice picker UI
│   └── VideoPlayerView.swift         # looping / one-shot video player
├── Asset packs / audio / dev tools
│   ├── AssetPackController.swift     # Apple-Hosted Asset Packs (replaces ODR)
│   ├── AssetPackImage.swift          # async asset-pack image view
│   ├── ODRManager.swift              # legacy ODR (kept during transition)
│   ├── AmbientAudioPlayer.swift      # ambient loop player
│   ├── SceneEditor.swift             # DEV-only map-item positioning
│   ├── PipTestView.swift             # DEV-only test view
│   └── HomeAnimated.swift            # animated Home variant
├── Assets.xcassets/                  # images, AppColors/ (Dark Mode), imagesets
├── Sounds/                           # audio files
└── Pips Animaions for the games/     # Pip game-animation frames
AssetPackDownloader/
└── BackgroundDownloadHandler.swift   # separate target — background asset-pack download
```

## Available Agent Skills (Auto-Activate)

Five user-level SwiftUI/Apple-platform skills are installed at `~/.claude/skills/` and auto-activate when relevant. Use them as the primary reference for generic Swift/SwiftUI/SwiftData/concurrency/security questions — this CLAUDE.md is for project-specific rules ONLY (decisions, file refs, past bugs, counter-defaults).

- **`swiftui-pro`** (Paul Hudson) — SwiftUI code review: modern API, views, data flow, navigation, accessibility, performance, hygiene
- **`swiftdata-pro`** (Paul Hudson) — SwiftData core rules, predicate safety, CloudKit constraints, indexing, class inheritance
- **`swift-concurrency`** (Antoine van der Lee) — `@MainActor` judgment, Task isolation, Sendable, Swift 6 strict concurrency, data races
- **`app-intents`** (Anton Novoselov) — `AppIntent` / `AppEntity` / Apple Intelligence (`AssistantEntity`/`AssistantIntent`), Spotlight, Snippets
- **`swift-security-expert`** (Ivan Magda) — Keychain, biometrics, CryptoKit, Secure Enclave, certificate pinning, OWASP MASTG

**Also available (user-invocable, not auto-activating):** `prompt-eval` (scaffolds a prompt-evaluation harness — auto-generated test set + Sonnet model-as-judge grading, 1–10 with mandatory pass/fail criteria, JSON + HTML report) and `prompt-engineering` (eval-driven prompt improvement). Use them to measure and improve `PipAIService` (Pip's kid-facing Claude chat). Trigger: "test the prompt" / "/prompt-eval".

When a skill's generic guidance conflicts with the project-specific Architecture Rules below, **Architecture Rules win** (project decisions, history, and file refs are non-negotiable).

## Architecture Rules

Canonical source for all hard rules. When statements elsewhere in this file (or in audit reports / chat) appear to relax or contradict these, the rules here win. Cite the rule's section name in code review or commit messages if you need to refer back.

### 1. SwiftData / CloudKit Compatibility

- **All `@Model` properties MUST have default values** at declaration. CloudKit requires it; missing defaults crash the schema migration.
- **NO `@Relationship` macros** — link models via `UUID` fields. `FamilyProfile` → members via `familyID` query; `UserProfile` → `PlayerData` via `ownerID`.
- **NO `[String: Int]` dictionaries on `@Model`** — use `[CodableStruct]` arrays. SwiftData doesn't reliably persist dictionary types.
- **`.modelContainer(modelContainer)` MUST be on the WindowGroup.** Required for `@Environment(\.modelContext)` to resolve in any descendant. Missing this caused an infinite loop bug.
- **Use `do { try save() } catch { print(error) }` for SwiftData saves** — never `try?`. Silent failures destroyed child profiles for a week (March bug). Always log errors so they're diagnosable.
- **Codable backwards compatibility:** every new field on a persisted struct needs `decodeIfPresent(...) ?? defaultValue`. Old saved data doesn't have the new keys → crash without it.

### 2. Concurrency & State Updates

- **ZERO inline `DispatchQueue.main.asyncAfter`** in `ChefAcademy/`. Every delayed UI mutation goes through:
  ```swift
  Task { @MainActor in
      try? await Task.sleep(for: .seconds(X))
      guard !Task.isCancelled else { return }
      // mutate @State here
  }
  ```
  Assign to a `@State var task: Task<Void, Never>?` and cancel in `.onDisappear` when cancellation matters (animation chains, repeat loops, transient cues).
- **Timer callbacks must wrap state mutations in `Task { @MainActor in }`.** `Timer.scheduledTimer` fires on the RunLoop; direct `@Published` / `@State` writes from there race with the renderer and produce data-race warnings under strict concurrency.
- **Game physics loops use `TimelineView(.animation)` with delta-time**, not `Timer.scheduledTimer` at 60fps. Pattern lives in `RainOverlay`, `StormOverlay`, `SnowOverlay`, `InsulinTetrisView`, `WaterPourCharacterView`. Timer-based physics ties speed to frame rate; ProMotion 120Hz devices and CPU throttling break it.
- **`@EnvironmentObject` propagation is selective.** `SiblingGardenView` swaps `gameState` (sibling's data) while inheriting `sessionManager` (visitor identity) — that's why visitor gender drives the right water-pour character without explicit wiring. Use this pattern when two flows share most but not all context.
- **`async/await` + `await MainActor.run { ... }` for any code touching `@Published` from a background context.** `PipAIService`, `USDAFoodService`, `ElevenLabsVoiceService` follow this.

### 3. Design System — No Hardcoded Values

Zero hardcoded colors / fonts / spacing / animation curves / stroke widths in any new SwiftUI code. Period.

| Category | Token namespace | Examples |
|---|---|---|
| **Colors** | `Color.AppTheme.*` | `cream`, `sage`, `goldenWheat`, `terracotta`, `sepia`, `darkBrown`, `weatherSunny`, `springGradientTop`. Shadows: `Color.AppTheme.sepia.opacity(N)` — never `Color.black.opacity(N)`. |
| **Fonts** | `Font.AppTheme.*` | `caption / subheadline / body / bodyBold / headline / title3 / title / largeTitle`. One-offs: `Font.AppTheme.rounded(size: N, weight: .X)`. Never `.font(.system(size:))`. |
| **Spacing** | `AppSpacing.*` | `xxs (4) / xs (8) / sm (12) / md (16) / lg (24) / xl (32) / xxl (48)`, `buttonHeight (52)`, corner radii `pill (8) / small (12) / card (16) / large (20)`, strokes `thin (1) / medium (2) / bold (3)`, `tabBarClearance (100)`, `pinButtonWidth (75)`, `pinButtonHeight (55)`, `infoCardImageSize (200)`. |
| **iPad sizing** | `AdaptiveCardSize.*(for: sizeClass)` | `pipMessage`, `pipReadyScreen`, `kitchenSpotRing`, etc. Never inline `isIPad ? 280 : 200`. |
| **Animations** | `AnimationConstants.*` | Springs: `springQuick / Medium / Slow / Bouncy / Snappy / Tight / Fly`. Easings: `fadeQuick / Fast / Medium / revealSlow / pipTransition / morphTransition / weatherTransition`. Loops: `floatLoopFast / floatLoop / floatLoopSlow / pinShake`. Frame rates: `walkingFPS / wavingFPS / gameFPS / walkSpeed`. Never inline `.spring(response:)` or `.easeInOut(duration:)`. |

**Pre-commit audit grep** — run on your own diff before declaring done:
```
Color.black            Color.white           .font(.system(
.spring(response:      easeInOut(duration:   easeOut(duration:    easeIn(duration:
RoundedRectangle(cornerRadius:    .shadow(color: Color.black    Color(hex: "
DispatchQueue.main.asyncAfter    Timer.scheduledTimer
```
Any hit in non-AppTheme files = not done. If a needed token doesn't exist, **add it to `AppTheme.swift` / `AppSpacing` / `AnimationConstants` / `AdaptiveLayout`** with a comment explaining what it's for. Never inline as a one-off.

### 4. UI Components — Reuse Mandatory

- **Buttons:** Primary CTAs → `.texturedButton(tint:)` (wood-grain capsule); secondary → `.buttonStyle(BouncyButtonStyle())`. Never `.buttonStyle(.plain)` with a custom-styled label; never hand-roll `.background() + .cornerRadius() + .shadow()` on a `Button`.
- **Cards:** `.softCard()` for the warm-cream surface (80% case). `.cardStyle()` for the parchment variant (rare).
- **Pip avatars:** Size via the `PipSize` enum (`.compact 40 / .medium 80 / .large 120 / .hero 160 / .custom(N)`). Never raw `Image("pip_...")` with hardcoded `.frame(width: N, height: N)`.
- **Pip dialogue:** `PipSpeechBubble` and `PipHeaderStack` **auto-speak** via `PipVoice.shared.speak(...)` on appear and on message change. Do NOT manually call `PipVoice.shared.speak(...)` next to these components — it double-speaks. Use `speakOnAppear: false` only for decorative usage.
- **PIN UI:** Use the shared `PINPadGrid<Leading, Trailing>` and `PINButton` from `PipComponents.swift`. Three views previously had local copies — never reintroduce.
- **Horizontal carousels:** Apply `.trailingFade()` (from `AdaptiveLayout.swift`) as the at-rest scroll cue. iOS's default scrollbar only appears mid-gesture; kids don't intuit swipe without this.
- **Primary CTAs that must always be reachable:** sticky footer pattern (see `RecipeDetailView` "Let's Cook!"). Don't bury below an un-cued `ScrollView(showsIndicators: false)`.
- **Profile pose image:** use `UserProfile.profilePoseImage` — never inline `gender == .boy ? "boy_card_clean_..." : "girl_card_clean_..."`. The helper routes parents to mom/dad frames.
- **Recipe display:** look up by ID, fall back to slug — `GardenRecipes.all.first { $0.id == star.recipeID }?.title ?? star.recipeID`. Never render raw recipe-ID slugs.

### 5. Storage Keys vs Display Labels

- **`rawValue` is an immutable storage key** when an enum is persisted (coin claim records, UserDefaults keys, SwiftData rows). Coin tracking uses keys like `"seed_\(veggie)_\(nutrient.rawValue)"`. Renaming a `rawValue` invalidates every existing user's saved progress and loses their coin claim history.
- **For UI display labels, add a separate computed property.** Example: `NutrientType.kidFriendlyName` returns `"Helper Shields"` for `.antioxidants` while `rawValue` stays `"Antioxidants"`. Default branch returns `rawValue` for cases that don't need renaming.
- **Applies to all enums on `@Model` properties:** `NutrientType`, `VegetableType`, `PantryItem`, `Gender`, `Outfit`, `HeadCovering`, `FoodAllergen`. Plus enums whose rawValues key into dictionaries or analytics.

### 6. SwiftUI Coding Conventions

- **SwiftUI for all views.** No new UIKit views except `UIViewControllerRepresentable` bridges to legacy frameworks (`GameCenterMatchmakerView`, `VeggieCanvasView` for PencilKit).
- **MVVM + ObservableObject + SwiftData `@Model`.** No new architectures.
- **`@EnvironmentObject`** for shared state: `GameState`, `SessionManager`, `AvatarModel`. Inject via `.environmentObject(...)` at the highest reasonable ancestor.
- **`@Environment(\.modelContext)`** for SwiftData queries from views. Requires `.modelContainer` set on the WindowGroup.
- **UUID-based model linking** between `@Model`s (no `@Relationship` — see SwiftData rules above).
- **`@Generable` / Apple FoundationModels** types live in `PipFoundationModelService.swift` only, gated by `#if canImport(FoundationModels)`. Don't proliferate.
- Code hygiene (`MARK: -`, `#Preview`, deprecated APIs, etc.) — handled by `swiftui-pro` skill, no need to repeat here.

### 7. Build & Verification

- **Build command:** `xcodebuild -scheme ChefAcademy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Trust `xcodebuild`, not SourceKit per-file diagnostics.** SourceKit doesn't see cross-file types — it will claim `Color.AppTheme`, `AppSpacing`, `GameState`, `PipFoundationModelService` are missing in any single file. Ignore these. `xcodebuild` is authoritative.
- **Build after every Edit batch** before declaring done. Don't push commits that haven't been built.
- **Reset simulator data:** `find ~/Library/Developer/CoreSimulator/Devices -name "default.store*" -path "*/Application Support/*" -exec rm -f {} \;`

### 8. Session Protocol

- **Read all relevant files before changes** when Marina says so. No context-budget arguments. Style/architecture files (`AppTheme.swift`, `AdaptiveLayout.swift`, `PipComponents.swift`) are mandatory pre-reads before any UI work. Memory files in `~/.claude/projects/.../memory/` count as "all files."
- **Plan-first for non-trivial changes.** Surface the diff intent, token usage, risk, and reversibility before editing. Don't sweep call sites without explicit sign-off (the "tokens-first, sweep-later" pattern).
- **One focused commit per audit item / feature.** Easy to revert, easy to bisect. Bundle only when items are genuinely the same change.
- **Audit findings are hypotheses, not instructions.** Before fixing: grep that the file is still referenced, the function still exists, the rationale still holds. Several audit items have been miscalibrated (PrimaryButtonStyle dead code, GardenHubView orphaned, Apple TTS already-rejected) — don't act on them blind.
- **Log teaching moments every session** — see Teaching System below.

### 9. Standing Decisions (Don't Re-Litigate)

- **Free voice = silent text on screen. Paid = ElevenLabs.** Apple TTS was rejected May 10 — "Enhanced" voices sounded awful, decision is documented and intentional. Don't re-propose. Audit items recommending Apple TTS are stale.
- **Sage / goldenWheat / terracotta are the botanical default for CTAs.** `brightGreen / brightBlue / sunflowerYellow` tokens exist for selective high-energy use; don't sweep all CTAs to brightGreen. The audit's "L-01 full sweep" path was declined.
- **Gender enum is binary (boy / girl).** Parent vs child role + gender combination drives mom/dad frame selection via `UserProfile.profilePoseImage`. Non-binary expansion is K-01 on the audit; deferred pending dedicated assets.
- **ColorChoice (Lycopene / Beta-carotene / Anthocyanins / Allicin) is intentional plant-pigment-science education.** In-file teaching comment in `SeedInfoView.swift:559-562` defends this. Don't replace with generic nutrient names. The kid-friendly rename only applies to `NutrientType.rawValue`, not `ColorChoice.nutrientName`.
- **`USDAFoodService.topNutrients()` is consumed only by `PipFoundationModelService.swift:505` (AI tools layer), not user UI.** Audit recommendations targeting "kid-unfriendly" tuple labels here are misdirected.
- **`GardenHubView.swift` is orphaned dead code** (zero references). Planned deletion. Don't add features to it; don't trust audit findings inside it.
- **`Tab.recipes` case is kept for compatibility** but hidden from the tab bar. Access via Kitchen book icon. The 6 visible tabs are Home / Garden / Shop / Kitchen / Body / Play. The March audit's "merge Garden + Farm" was deferred — Garden + Shop stay separate.
- **Routine pushes use the Claude GitHub App's install token** (separate from personal access). Failures → toggle repo access "All" → "Only select" → "All" on `github.com/settings/installations` to force token re-issue. Don't uninstall.
- **ODR is deprecated as of WWDC25.** Migrating to Apple-Hosted Asset Packs. `AssetPackController.swift` is the new path; `ODRManager.swift` stays during transition.

### 10. Honesty & Communication

**BE 100% HONEST about every status, estimate, and outcome.** No softening, no aspirational claims dressed as facts, no hidden mistakes.
- If a build failed, say it failed.
- If a commit's message claimed something the edit didn't include, surface it and fix it (don't paper over).
- If an estimate is wrong, correct it openly the moment you realize.
- End-of-task summaries describe what actually shipped, not what was attempted.
- Push back on weak approaches with reasoning rather than acquiescing to keep things smooth.

Trust depends on accurate signal; polite lies cost real hours of misallocation later.

### 11. Secrets & API Keys

**NEVER inline a secret value into a Bash command line.** No `PROXY_TOKEN="<hex>" node script.js`, no `curl -H "Authorization: Bearer <key>"` with the literal key, no `ANTHROPIC_API_KEY="sk-..." python run.py`. If a command needs a secret:
1. Ask Marina to `export VAR=...` in her own shell once (ephemeral, never seen by Claude Code), OR
2. Use `export VAR=$(cat ~/path/to/gitignored-file)` then run the bare command, OR
3. Source from `.env`: `set -a; source .env; set +a; node script.mjs`

The command that hits the shell must contain **no secret material** (the script reads the env var internally). **Why:** Claude Code's permission system stores "Always allow" approvals as the literal command string — a secret inlined into an approved command gets written into `.claude/settings.local.json` permanently. RAA incident (May 7 2026): an inlined `PROXY_TOKEN="4dbd…"` sat in `settings.local.json:33` for two weeks. ChefAcademy is clean — keep it.

**Never read raw-secret files** by Read/Edit/Write **or** Bash (`cat`/`grep`/`head`/`xxd`). `APIKeys.swift` is **already denied** in `.claude/settings.json` (Read/Edit/Write on both the absolute path and `**/APIKeys.swift`) — the harness enforces it. Add any new secret file's deny rules there the moment it exists. (`AppAttestService.swift` is fine — logic is public.)

## General Coding Behavior — Karpathy Guidelines

*Added 2026-05-27 from [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT), derived from Andrej Karpathy's notes on LLM coding pitfalls. Complements the Architecture Rules above — where it overlaps, the specific Architecture Rule wins. Bias toward caution over speed; for trivial edits, use judgment.*

### K1. Think Before Coding
Don't assume. Don't hide confusion. Surface tradeoffs.
- State your assumptions explicitly; if uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted (see also §10).
- If something is unclear, stop, name what's confusing, and ask.

### K2. Simplicity First
Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked. No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested. No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it. Test: *"Would a senior engineer say this is overcomplicated?"*

### K3. Surgical Changes
Touch only what you must. Clean up only your own mess.
- Don't "improve" adjacent code, comments, or formatting. Don't refactor what isn't broken.
- Match existing style, even if you'd do it differently.
- Notice unrelated dead code → mention it, don't delete it (e.g. `GardenHubView` stays until explicitly removed).
- Remove imports/variables/functions that YOUR change orphaned; leave pre-existing dead code alone.
- The test: every changed line traces directly to the request. (Reinforces §8 "don't sweep call sites without sign-off.")

### K4. Goal-Driven Execution
Define success criteria, then loop until verified.
- Turn tasks into verifiable goals: "fix the bug" → "reproduce it, then make the repro pass"; "refactor X" → "verify behavior before and after."
- For multi-step work, state a brief numbered plan with a `verify:` check per step.
- ChefAcademy has no XCTest suite, so "verify" = a green Xcode build (§7), a passing eval run (`/prompt-eval`), or a traced-through user flow — not an automated test.

## Teaching System (PROACTIVE)

Marina learns as we build — teach **while** coding, not after.
- **Trigger:** introducing a pattern, avoiding a pitfall, fixing a non-obvious bug, or writing non-trivial logic. Skip trivial wins (font bumps, one-line patches).
- **Print the title in green**, then explain: `echo -e "\n\033[1;32m━━━ TEACHING MOMENT: [Title] ━━━\033[0m\n"` → CONCEPT (1–2 sentences) → STEP BY STEP (numbered) → IN OUR CODE (specific file/symbol) → KEY TAKEAWAY (1 line). MIT-professor tone: clear, real-world analogies, no fluff. On demand: `/teach [topic]`.
- **Append every moment to `TEACHING.md`** in its existing 4-field format — `**Where it came up** / **What it is** / **In our code** / **Why it matters**` — 3–7 per session. Memory notes are not a substitute.

## Tech Stack

- **UI Framework:** SwiftUI · **Mini-games:** SwiftUI with gestures
- **Persistence:** SwiftData with iCloud CloudKit sync · **Minimum iOS:** 16.0
- **Architecture:** MVVM with ObservableObject + SwiftData `@Model`
- **Security:** Keychain for parent PIN (iCloud Keychain sync); Cloudflare Worker + App Attest for the Claude API key (never in the bundle)
- **External:** WeatherKit, USDA FoodData Central, ElevenLabs (paid voice), Game Center + MultipeerConnectivity (multiplayer)

## Multi-User Family System (COMPLETE)

Multiple players per device via a family profile system.

- **`FamilyProfile`** (@Model) — one per device; members found via `familyID` query.
- **`UserProfile`** (@Model) — parent or child; role, gender, avatar; `PlayerData` found via `ownerID` query.
- **`PlayerData`** (@Model) — per-user progress (coins, seeds, plots, pantry, recipes, health).
- **`SessionManager`** (ObservableObject) — central coordinator: routing state machine, profile CRUD, PIN verify, play-time.
- No `@Relationship` macros — all linking via UUID fields (see §1). File refs in **Key File Locations**.

**App Route Flow** — this is the **top-level router only** (`AppRoute` enum in `SessionManager`, rendered in `ChefAcademyApp.swift`). In-app navigation (6 tabs + their sheets/`fullScreenCover`s: cooking session, sibling-garden visit, Ask Pip, paywall, recipe book, seed/pantry info) is a separate, larger layer not shown here.
```
App Launch → SessionManager.bootstrap() sets an AppRoute (9 states):
  .loading           → loading screen (waving Pip) while bootstrap runs
  .signIn            → SignInView (Sign in with Apple) → on success find/create family
  .familySetup       → FamilySetupView (8-step: Welcome→Parent Name→Parent Avatar→
                       PIN→Child Name→Child Avatar→Meet Pip→Ready)
  .migrationPINSetup → MigrationPINSetupView (legacy single-user upgrade)
  .profilePicker     → ProfilePickerView ("Who's playing today?")
  .parentPINEntry(p) → ParentPINEntryView → success/cancel → .profilePicker
  .childOnboarding   → STUB (renders ProfilePickerView; "future per-child onboarding")
  .mainApp(id)       → MainTabView   ← the actual game (6 tabs)
  .parentDashboard   → ParentDashboardView

ProfilePickerView taps: child card → selectProfile() → .mainApp ·
  parent card → .parentPINEntry → dashboard/picker ·
  "Add Little Chef" → .parentPINEntry → AddChildFlowView (3 steps + dup-name check)
```

**Profile data flow:** `selectProfile()` → existing `PlayerData` found → `loadFromStore(for:)` → MainTabView; else → `createPlayerData()` → `resetToDefaults()` → `saveToStore()`. `resetToDefaults()` gives **0 coins** (learn-to-earn — kids tap nutrient cards / color seeds to earn), **8 starter seeds, 5 plots, 2 recipes**. `loadFromStore()` safety: re-grants starter seeds if empty.

**PIN:** stored in Keychain (not SwiftData), iCloud-synced — `PINKeychain.save/load/delete`. Required for parent profile, adding children, dashboard, changing PIN.

## Visual Style

**Aesthetic:** Vintage botanical watercolor ("paper style"). **Palette** is defined as `Color.AppTheme.*` in `AppTheme.swift` (backed by `Assets.xcassets/AppColors/` for Dark Mode) — never inline hex:
- `cream` #F5F0E1 (backgrounds), `warmCream` #FAF6EB, `parchment` #EDE6D3
- `sepia` #8B7355 (body text), `darkBrown` #5D4E37 (headlines), `lightSepia` #A89880
- `sage` #6B7B5E (primary CTAs / nature), `goldenWheat` #C9A227 (rewards / coins), `terracotta` #B87333 (warnings / heat), `softOlive` #8A9A7B (secondary), `warmKhaki` #C6BA8B
- **High-energy accents** (May 11): `brightGreen`, `brightBlue`, `sunflowerYellow` — saturated CTA pop for age-6+ visibility. Use sparingly; the botanical trio remains default.
- Weather: `weatherSunny/PartlyCloudy/Cloudy/Stormy/Snowy/Rainy`; seasons: `spring/summer/fall/winter` gradient + particle tokens (`springPetal`, `frostBlue`, `autumnBrown`, `rainBlue`, `sunYellow`).

Full token rules + pre-commit grep are in **§3 Design System**.

## Character: Pip the Hedgehog

- Round, fluffy hedgehog with chef hat — the kid's guide/mascot.
- 13 static poses (`PipPose` enum in `PipAnimations.swift`) + walking + waving animations.
- `PipWavingAnimatedView(size:)` — reusable animated Pip; size flows through `PipSize` (`compact 40 / medium 80 / large 120 / hero 160 / .custom(N)`).
- `PipSpeechBubble`, `PipHeaderStack` (`PipComponents.swift`) — canonical layouts; both auto-speak via `PipVoice.shared.speak(...)` on appear and message change.
- `PipDialogView` — modal confirm prompts ("Spend N coins and plant?") with `BouncyButtonStyle` choices.
- Walking frames: `pip_walking_frame_01..15` at 30fps Timer-based (`CharacterWalkingView`).

## Current Tab Structure (6 tabs)

| Tab | Icon | View | Purpose |
|-----|------|------|---------|
| Home | house.fill | `HomeView` | Main hub, sibling visits, switch player, parent dashboard |
| Garden | leaf.fill | `GardenView` | Plant & harvest veggies (interactive map) |
| Shop | cart.fill | `FarmTabView` → `FarmShopView` | Pip walks to barn, then seeds + pantry shop |
| Kitchen | fork.knife | `KitchenView` | Cook recipes with Pip; book icon opens `RecipeListView` |
| Body | person.fill | `BodyBuddyView` | "Your Body" — organ health rings + recipe impact |
| Play | gamecontroller.fill | `PlayLearnView` | Mini-games hub (Healthy Picks, Insulin Tetris, etc.) |

`Tab.recipes` still exists in the enum for references but is hidden from the tab bar (opened via the Kitchen book icon). `GardenHubView.swift` is orphaned dead code; planned deletion.

## Mini-Game System (COMPLETE)

9 mini-games in `CookingMiniGames.swift` — HeatPan (hold), AddToPan (drag), Stir (circular swipe), Season (tap), Peel (swipe down), CookTimer (green-zone), Wash (tap), CrackEgg (tap), Assemble (tap) — plus Chop (`ChopMiniGame.swift`, tap-timing). `CookingSessionView.swift` is the state machine: parses recipe steps → sequences mini-games → scores 0-100/game → averages to stars (85+ = 3, 60-84 = 2, <60 = 1).

## Roadmap (high-level — dated/active detail lives in `project_next_priorities.md` + `MEMORY.md` + the routine reports)

**Done:** multi-user family system; 9 cooking mini-games; WeatherKit + plant care; Pip AI chat (Claude Sonnet, streaming, XML prompt — eval 8.2/10); App Attest + Cloudflare Worker; Apple-Hosted Asset Packs migration; USDA + ElevenLabs + Game Center/multiplayer; learn-to-earn coins + seed/pantry knowledge cards.

**Remaining (pre-launch):**
- Paywall placement audit — guarantee one free cook-and-feed cycle before any paywall fires.
- Clear weekly-review debt: banned `DispatchQueue.main.async` sites, `try? save()` sites, `profilePoseImage` bypasses.
- UX P0s (05-25): ≥44pt bug-rescue taps, seed-carousel `.trailingFade()`, persistent Drag-Pip affordance.
- Privacy/COPPA copy review (chat sends game context to the cloud).
- TestFlight upload + App Review screenshot for the Pip Chat subscription.
- Remaining art: 19 veggie image assets, Body Buddy figure, non-binary gender (K-01), water-pour spout anchor.
- Cloudflare Phase 4 (delete `CloudKeyManager` + AppConfig record); Subscription Phase 2 (Pip Voice / Premium tiers).

**Durable constraints (not just TODOs):**
- 🚫 Never run repeated CLI `xcodebuild`, never `pkill actool` — it wedges the asset catalog and needs a Mac reboot. Verify in Xcode or read the xcactivitylog.
- Free voice = silent text; paid = ElevenLabs (don't re-propose Apple TTS).
- Gender enum is binary (non-binary deferred); zero hardcoded design values (§3).
- When CLAUDE.md contradicts a dated review file, the dated file wins.

## Contact & Attribution

**Developer:** Marina Pollak ·  Chicago · **Instructor:** Janell Baxter · **Nutrition Research:** Jessie Inchauspé ("Glucose Goddess")

---
*Last Updated: 2026-05-27 — architecture stable; high-level Roadmap above, dated detail in the review files + memory.*
