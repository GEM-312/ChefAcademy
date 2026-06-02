# TEACHING.md — iOS/Swift Learning Log

Personal reference built from real code in Pip's Kitchen Garden. Newest lessons first.

---

### Anthropic Tool Use + Prompt Caching (Phase 1)
**Where it came up:** PipAIService.swift `askCloud` refactor — adding `get_garden_status` and `get_cookable_recipes` tools.
**What it is:** Instead of stuffing live game data into the system prompt every turn, you declare "tools" Claude can call. When Claude wants live data, the SSE stream emits `content_block_start` with `type:"tool_use"`, then `input_json_delta` chunks for the tool's input, then a final `stop_reason:"tool_use"`. You execute the tool, send `tool_result` back as a user message, and Claude continues with text. This is a multi-round-trip pattern: 1 turn becomes 2+ HTTP calls.
**In our code:** `askCloud` now loops `for hop in 1...maxHops` (capped at 2). Hop 1 sends `"tools": cloudTools` + `"tool_choice": ["type": "auto", "disable_parallel_tool_use": true]`. On `stop_reason == "tool_use"`, we append the assistant turn (with tool_use blocks) and a user turn (with tool_result blocks) to a *local* `modelMessages` buffer, then `continue`. Hop 2 omits the `tools` key — that forces a text response (no infinite recursion). The kid sees "Pip is looking at your garden..." via `streamingText` during the gap. The **bigger win** is that `gameContextString` no longer interpolates kid-specific data the tools cover → the system prompt with `cache_control:ephemeral` is now stable across a session → 60-80% input-token savings on turn 2+ (verify via `usage.cache_read_input_tokens` in the `message_start` SSE event, logged in DEBUG).
**Why it matters:** The naive way to "give the AI context" is to dump everything into the system prompt. That works for one-shot apps but ruins prompt caching the moment any per-user data goes in. Tools split the prompt into a cacheable static part and dynamic data fetched on demand. For multi-turn chat (like Pip), this is the single biggest cost optimization. Trade-off: each tool-using turn adds one HTTP round-trip (~1.5–2 s extra latency), so cap recursion and pick tools that pay for themselves (always-needed data, not edge cases).

---

## Session: May 24, 2026

### Trace the Code — Memory and the Knowledge Graph Are Both Stale-able
**Where it came up:** A `/graphify` build flagged `PipFoundationModelService` as a heavy "bridge" node in the AI subsystem, and project memory confidently said *"PipAIService is dual-mode (on-device + cloud), falls back to Claude."* Tracing the actual routing told a different story: `PipAIService.askPip()` (PipAIService.swift:482-485) is hard-wired to `await askCloud(question)` with the comment *"Cloud Claude only — on-device is too small for reliable multi-tool chat."* The on-device path still exists and is wired, but no longer answers chat — it only updates context.
**What it is:** Two derived artifacts — long-term memory notes and a generated dependency graph — both described an *intended* architecture that the code had since moved past (the cloud-only flip happened Apr 19; memory wasn't fully reconciled). A graph edge says "these symbols are connected," not "this connection is live in the current control flow." Memory says "this was true when written." Neither is the running code.
**In our code:** The graph's `path` query confirmed the structural wiring (`PipAIService → askCloud() → WorkerClient`; `PipAIService → PipFoundationModelService`), but only reading `askPip()` revealed which branch actually executes. The single source of truth was 4 lines of Swift, not the 6 memory files that referenced it.
**Why it matters:** Use the graph and memory to *locate* and *orient* — "where does AI routing live, what touches it" — then open the function and read it before asserting behavior. The more confident a derived source sounds, the more it's worth a 10-second code check. After verifying, fix the stale source (we corrected 6 memory claims) so the next reader isn't misled again.

### Dynamic Asset Names Defeat Naive Grep (Dead-Asset Detection)
**Where it came up:** Auditing 715 imagesets for unused ones. A first pass — "does the asset name appear as a literal string in any .swift file?" — flagged ~290 candidates, including whole families like `pip_throw_veggie_frame_01..30` and `boy_hat_colored_brown`. Tracing the call sites showed ~100 of those were actually live.
**What it is:** Code rarely hardcodes every frame name. It stores a *base* (`"pip_throw_veggie"`) and builds the full name at runtime: `Image(String(format: "%@_frame_%02d", base, i))` or `"\(base)_\(color)"`. The literal `pip_throw_veggie_frame_07` never appears in source, so a naive substring search reports it unused — a false positive. Conversely, `kitchen_sink_frame_001..125` looked the same but WAS dead: the code builds `kitchen_sink_%02d` (→ a *different*, 15-frame set `kitchen_sink_01..15`), so the 125-frame `_frame_NNN` originals were genuinely orphaned.
**In our code:** The reliable check was: strip the trailing variant suffix (`_NN`, `_color`) to get the base, search for the base, and when it matched, open the actual builder to confirm the format string maps to *these* assets and not a sibling set. `grep -rlF "pip_throw_veggie"` → `PipGameAnimationView.swift` (live); `grep -rlF "kitchen_sink_frame"` → nothing, while `kitchen_sink_%02d` pointed at the 2-digit set (dead originals confirmed).
**Why it matters:** Static "is this string referenced" analysis has a known blind spot for runtime-constructed identifiers — asset names, notification names, UserDefaults keys, segue IDs. Always verify a "dead" candidate by reading the construction site, and verify a "live" one isn't matching a same-prefix sibling. The audit caught 187 truly-dead imagesets only because the 100 false positives were filtered out by hand.

### Modern Xcode Catalogs: File-System-Synchronized Groups (no pbxproj edits)
**Where it came up:** Deleting 187 dead imagesets. The worry: "do I have to edit `project.pbxproj` to remove each imageset reference, or will the build break?"
**What it is:** `ChefAcademy.xcodeproj/project.pbxproj` has `objectVersion = 77` (Xcode 16+) and uses `fileSystemSynchronizedGroups`. Instead of listing every file as an individual `PBXFileReference`, Xcode syncs an entire directory tree from disk — it discovers files at build time. So deleting a `.imageset` folder from disk is automatically reflected; there's no per-file entry to clean up, and no dangling reference to break the build.
**In our code:** `rm -rf` on the dead imageset folders was the entire change — zero pbxproj edits, zero `Contents.json` group edits (the ODR tags lived in each imageset's own Contents.json, deleted along with the folder). Confirmed the catalog still compiled via `actool`.
**Why it matters:** On older `.pbxproj` formats, deleting a file outside Xcode left a stale reference that broke the build until you removed it in the project navigator. With synchronized groups, the filesystem IS the project — you can add/remove resources with plain shell commands. Know which era your project is in (`objectVersion` tells you) before deciding whether a file change needs a project-file edit.

### Metal Toolchain Is a Separate Component; `actool` and `metal` Are Independent Build Steps
**Where it came up:** After deleting the assets, `xcodebuild` ended in `** BUILD FAILED **`. The instinct is "my change broke the build" — but the only error was `cannot execute tool 'metal' due to missing Metal Toolchain`.
**What it is:** Xcode 16+/26 unbundles the Metal Toolchain — `.metal` shader files (we have `Ripple.metal`) won't compile until you run `xcodebuild -downloadComponent MetalToolchain`. Separately, the asset catalog is compiled by `actool`, a totally independent build task. A failure in one says nothing about the other. Reading the log showed `actool … Assets.xcassets` ran with zero errors/warnings; the single `error:` line was the Metal one.
**In our code:** Deleting PNGs cannot affect shader compilation, so the Metal failure was pre-existing and environmental. The actual verification target — does the catalog still compile after removing 187 imagesets — was answered "yes" by the clean `actool` step, even though the overall build couldn't finish.
**Why it matters:** "Build failed" is not "my change failed." Read the log for the *specific* failing command and ask whether your change could plausibly cause it. An asset deletion that breaks a Metal compile is a logical impossibility — which means the build was already broken for an unrelated reason (here, a missing toolchain component this machine never downloaded). Scope your verification to what your change actually touched.

---

## Session: May 12, 2026

### Verify Authority Docs Against Their Source of Truth Before Rewriting
**Where it came up:** Yesterday's CLAUDE.md cleanup confidently rewrote the color palette section with hex values like `cream: #FDF6E3`, `sage: #9CAF88`, `terracotta: #C4A484`. All eight values were wrong. The real values live in `Assets.xcassets/AppColors/*.colorset/Contents.json` as sRGB float components, and they read as `cream: #F5F0E1`, `sage: #6B7B5E`, `terracotta: #B87333`. STYLES.md had correct values the whole time. Marina caught it today during a follow-up audit when she asked to check the other style docs.
**What it is:** When rewriting an "authority" document (CLAUDE.md, README, style guide, schema reference), the data going into the doc should be sourced from the actual system of record (the asset catalog, the .swift file, the Info.plist, the schema migration), not from your context window. The risk of fabricating plausible-looking-but-wrong values is highest exactly when you're confidently rewriting "because you know the codebase." Confidence + plausibility + no verification = a quiet bug that propagates downstream as ground truth.
**In our code:** The fix was a one-shot Python script that read each `*.colorset/Contents.json`, converted the float-component triplet to hex, and printed a comparison table against both docs' claims. Once I saw STYLES.md was right and CLAUDE.md was wrong on every value, the fix took 30 seconds. The actual mistake had taken longer — I rewrote 8 hex values from memory in a doc that's now the authoritative consolidated rules file.
**Why it matters:** Authority docs are load-bearing. A future contributor reading CLAUDE.md would have used #9CAF88 for sage, gotten a visibly-different color from what's in the build, and either (a) overridden the asset catalog to match the doc (now the doc dictates color, not the catalog), or (b) wasted hours debugging "why does this look off." Before rewriting any reference doc, ask: where does this data actually live? Then read THAT file, not your memory. For numeric values, hex strings, file paths, line numbers, version numbers — always re-check, even when you're sure. Especially when you're sure.

### Audit Reports Don't Audit Themselves
**Where it came up:** ASSETS.md was last dated March 15 and claimed `~285 imagesets total / 43 AvatarCards`. Actual on-disk counts: 722 / 103. STYLES.md claimed "All clear! Last audit: March 23, 2026" — but five weeks of code had landed since, including yesterday's Pass C raw-color sweep that wouldn't have happened if STYLES.md had been right. Both docs read as authoritative statements about current state when they were actually frozen snapshots.
**What it is:** A reference doc that includes a self-assessment ("X items complete", "All clear", "Last audit: <date>") makes a claim about freshness. That claim decays the moment the next commit lands and isn't re-verified. Worse, the claim's specificity ("~285", "all clear") makes it feel authoritative — readers don't question it. The fix is either (a) bind the count to a programmatic source the doc points to ("see `WEEKLY_REVIEW_<date>.md`" or "run `find . -name '*.imageset' | wc -l`") or (b) date-stamp every claim and treat anything older than a sprint as suspect.
**In our code:** Updated ASSETS.md inventory to derive from `find ChefAcademy/Assets.xcassets -name "*.imageset" -type d | wc -l` (722) instead of a hand-maintained number. Replaced STYLES.md's "All clear" with a pointer to the latest dated weekly review. Both docs now footer-date their content and explicitly defer to the live source for tracked counts / violation status.
**Why it matters:** Self-assessed reference docs are a class of bug that doesn't surface until someone trusts them. The trust radius is wide — every new contributor reads the docs first. Treat reference numbers the same way you treat magic constants in code: either source them from the canonical store, or recompute them at every audit. Never copy-paste a number into a doc and walk away.

---

## Session: May 11, 2026

### SourceKit Per-File Diagnostics Are Noise (Trust the Build)
**Where it came up:** Every Edit during the F-03 font sweep — SourceKit yelled "Cannot find type 'GameState' / 'AppSpacing' / 'Color.AppTheme'" on files that compile perfectly.
**What it is:** SourceKit (the analyzer that powers Xcode autocomplete and the diagnostics surfaced after each Edit) only sees one file at a time when invoked outside a full project build. Cross-file types defined in other Swift files — `Color.AppTheme`, `AppSpacing`, `GameState`, `Recipe`, etc. — are not visible to it, so it claims they don't exist. None of these "errors" prevent the actual build from succeeding.
**In our code:** After every font edit, SourceKit listed 10+ "errors." Running `xcodebuild -scheme ChefAcademy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` returned `** BUILD SUCCEEDED **` every time. The xcodebuild result is authoritative; the per-file diagnostics are not.
**Why it matters:** If you stop and "fix" what SourceKit complains about in isolation, you'll waste hours chasing imaginary problems. The rule: run an actual build before believing any cross-file error. This applies to Xcode's own live diagnostics too — they sometimes regress after a clean, and you need a real build to clear them.

### Tokens-First Beats Sweeping CTAs Now
**Where it came up:** L-01 from the UX audit — "brighten the primary CTA color across the app."
**What it is:** When a UX audit recommends a visual palette shift, you have two paths: (1) add the new color tokens to your design system and stop, or (2) sweep all existing call sites to use the new tokens immediately. Tokens-first is almost always right: a named constant costs nothing to add (one line), documents the intent (the name `brightGreen` says "I want a high-energy CTA"), and lets you A/B in Xcode preview before committing to a palette change that touches a dozen views.
**In our code:** The audit said "update PrimaryButtonStyle to use brightGreen." A grep showed `.primaryButton()` was used exactly once in the entire codebase — inside its own preview. The actual production CTAs use `.texturedButton(tint: Color.AppTheme.sage)` and similar. Sweeping 6+ sage CTAs to brightGreen would have visibly shifted the app's botanical identity. Instead, we added `Color.AppTheme.brightGreen / brightBlue / sunflowerYellow` to the palette and stopped. Future buttons that need to pop can opt in; existing buttons keep their sage tint.
**Why it matters:** Design system maturity = the tokens are richer than the call sites. You want a palette that can express new ideas before you commit to them. Adding a token is a 1-line, reversible change; sweeping call sites is a multi-file diff that's harder to undo. Always do the cheap, reversible thing first when an audit suggests a visual shift.

### Audit Recommendations Are Hypotheses — Verify Before Acting
**Where it came up:** L-01 (PrimaryButtonStyle), D-01 (GardenHubView padding), F-01 (Apple TTS free tier).
**What it is:** Automated audit agents read the codebase fresh each run. They don't know your history, your prior design calls, or what's actually wired up to what. Three findings in today's audit were structurally miscalibrated: (a) L-01 recommended fixing `PrimaryButtonStyle` which was dead code (1 usage, in its own preview), (b) D-01 recommended padding a button inside `GardenHubView.swift` which has zero references in the rest of the codebase (orphaned dead file), (c) F-01 recommended adding Apple TTS as a free tier — a decision Marina had explicitly rejected on May 10 with strong reasoning. Acting on any of these without verifying would have wasted time, shipped dead code, or contradicted a deliberate product call.
**In our code:** Before each fix we ran `grep -rn "GardenHubView" ChefAcademy/ --include="*.swift" | grep -v "GardenHubView.swift:"` (zero hits → orphaned) and `grep -rn "\.primaryButton()" ChefAcademy/` (one hit, in a preview → dead). The fixes worth doing (F-03 fonts, G-01 recipe lookup) survived this verification step.
**Why it matters:** Treat every audit finding as a hypothesis, not an instruction. Grep before you fix. Read the call site before you commit. The audit prompts the question; the code answers it. This applies to code review feedback, Stack Overflow answers, and any external advice — the local context overrides the general recommendation.

### Optional Chaining + Nil-Coalescing for Safe Lookups
**Where it came up:** G-01 — `SiblingProfileView` was rendering `star.recipeID` (a slug like `"chicken-veggie-platter"`) as the visible recipe name.
**What it is:** Swift's `?.` (optional chaining) lets you reach through nilable values without crashing — if any link is nil, the whole expression evaluates to nil. The `??` (nil-coalescing) operator then provides a fallback for that nil. Combined, they handle "look this up, but if it's missing, use this default" in one line.
**In our code:** `Text(GardenRecipes.all.first { $0.id == star.recipeID }?.title ?? star.recipeID)` — `.first { ... }` returns `Recipe?`, `?.title` is `String?`, `??` falls back to the raw slug. If a recipe was renamed or removed, the slug still shows (better for debugging than a generic placeholder).
**Why it matters:** The pattern `collection.first { predicate }?.field ?? fallback` shows up constantly when bridging stored IDs to live data. It's safer than force-unwrapping (`!` would crash on missing recipes) and cleaner than `if let` blocks for one-shot display.

### Routine Push Failures: GitHub App Install Token Can Get Stale
**Where it came up:** Both the weekly review routine (May 10) and the UX review routine (May 11) ran successfully but failed silently at `git push origin main` with HTTP 403.
**What it is:** Anthropic's scheduled routines push commits via a git proxy that uses an *installation token* issued by the GitHub App you've installed (`github.com/settings/installations`). That token is separate from your personal access. It can become stale even when the GitHub App settings look fine — no yellow "Accept new permissions" banner, write permission still granted. The fix is to force GitHub to re-issue the install token, which propagates downstream.
**In our code:** Toggled the Claude GitHub App's repository access: "All repositories" → "Only select repositories" (pick ChefAcademy) → Save → switch back to "All repositories" → Save. This re-issues the install token. Then re-ran the routine via `RemoteTrigger` — push succeeded on the first try (commit `99ad74a` "Weekly UX review — 2026-05-11" landed on origin).
**Why it matters:** Any system that pushes git on your behalf (CI runners, scheduled jobs, automation bots) uses a delegated token. When automation pushes fail with 403 but your manual pushes work, the token is the suspect — not the code, not the GitHub App permissions screen. The "toggle access off/on" trick forces a fresh token without an uninstall/reinstall cycle.

### Design Tokens: Reuse Before You Add
**Where it came up:** L-02 — migrating ~24 hardcoded weather/season color literals to AppTheme tokens.
**What it is:** Before adding a new design token, grep `AppTheme.swift` for existing tokens that match the hex value or semantic role. Today the audit proposed `winterGradientTop = #E3F2FD` — but `frostBlue = #E3F2FD` already existed for winter sparkles. Two near-duplicate tokens with different names ("which one is canonical?") is *worse* than one token reused across contexts. Same situation with `sunYellow` (existing) vs proposed `weatherSunny`, and `rainBlue` (existing) vs proposed `weatherRainy` — the audit didn't notice them.
**In our code:** Skipped 3 of the audit's 13 proposed tokens by reusing `frostBlue`, `sunYellow`, `rainBlue`. Renamed the audit's proposed names to match the existing token vocabulary (`weatherPartlyCloudy` etc. for the genuinely new ones). Result: 10 new tokens, not 13. Cleaner palette, no overlap.
**Why it matters:** Design-system entropy is real — every duplicate token raises the question "which is correct?" and the answer drifts over time. Treat tokens like database normalization: one source of truth per concept. Audit recommendations are a starting point, not a final answer. Always cross-check against what you already have.

### Stable Storage Keys vs Display Labels (Don't Rename `rawValue`)
**Where it came up:** F-04 — replacing "Antioxidants" / "Probiotics" / "Omega-3" with kid-friendly labels in `NutrientType`.
**What it is:** Enum `rawValue`s often serve double duty as (a) stable storage keys for persistent state (database rows, UserDefaults dictionary keys, coin claim records keyed by `"seed_carrot_Antioxidants"`) AND (b) UI display labels. When you need to change the user-facing label, *don't* rename the rawValue — every existing user's saved progress would mismatch the new key, and they'd lose their coin claim records / look like they never tapped that nutrient before. Add a separate `var kidFriendlyName: String` property that returns the display text; keep `rawValue` immutable as the storage key.
**In our code:** Added `var kidFriendlyName: String` to `NutrientType` in `GameState.swift`. Default branch returns `rawValue` (unchanged for 17 cases); explicit cases rename only the 5 truly adult terms. Call sites in `SeedInfoView` and `PantryInfoView` now use `.kidFriendlyName` for display. Coin claim IDs like `"seed_\(veggie)_\(nutrient.rawValue)"` continue to use rawValue and remain stable — no migration needed for kids already mid-progression.
**Why it matters:** Whenever a string serves both as a stored identifier and a displayed label, separate the two concerns immediately. Storage keys must be immutable forever (or you write a migration); display labels can change freely. This is the same principle behind database primary keys never being human-readable text. The cost of conflating them is paid the first time you want to rename anything user-facing.

### Composite Animation: Static Frames + Procedural Overlay
**Where it came up:** Water pour animation — the source video frames showed the kid holding the watering can but the water stream itself wasn't drawn. Instead of redrawing all 15 frames with water added, we composed the stream in SwiftUI on top of the static frames.
**What it is:** Two ways to layer a missing visual onto pre-drawn assets: (a) redraw the assets to include it — high cost, locks the look at draw time, expensive to iterate; (b) leave the assets clean and overlay the missing element in code — cheap to tune, animates independently of the frame loop, can adapt per-device. For anything fluid (water, fire, sparks, dust, smoke) option (b) wins because particles benefit from frame-rate-independent physics that a hand-drawn animation can't match.
**In our code:** `WaterPourCharacterView` renders the 15-frame kid loop at ~10fps in a static `ZStack` layer, then overlays a `TimelineView(.animation)` Canvas drawing water drops with their own gravity + horizontal velocity at the device's native refresh rate (60–120Hz). The drops emit from a normalized spout anchor `(0.58, 0.78)` for girl / `(0.40, 0.70)` for boy — those numbers survive image resizing because they're a fraction of the bounding box, not absolute pixels. If Marina swaps in higher-resolution character art tomorrow, the spout stays correct without code changes.
**Why it matters:** When you have hand-drawn assets that need a dynamic element layered on top, decide which parts belong on the artist's plate vs the programmer's. Anything frame-rate-dependent, position-dependent, or count-tunable (3 drops vs 30 drops) belongs in code. Anything that requires artistic judgment (the character's posture, expression, clothing) belongs in the art. This split keeps both sides moving in parallel and avoids re-exporting frames every time you want to tune the particle count.

### Headless Image Pipelines Beat Computer Use For Repetitive Asset Work
**Where it came up:** Marina asked if Claude's Computer Use tool could drive her Photoshop trim-and-clean workflow. Honest answer: it could, but it would be slower, more expensive, and less reliable than just writing the pipeline in CLI tools.
**What it is:** Computer Use is Claude operating a virtual computer via screenshots + simulated keystrokes — designed for UI flows that have *no API*. Tasks that have first-class CLI/library equivalents (image processing, file manipulation, video encoding) should use those tools directly, not Computer Use. The mental model: Computer Use is the *last resort* for automation, not the first.
**In our code:** Built `extract-and-trim.sh` that chains `ffmpeg` (extract) → `rembg --model isnet-anime` (background removal, CLI Python tool with U^2-Net/IS-Net neural models) → Pillow `Image.getbbox()` with an alpha threshold (trim). Tested against Marina's hand-Photoshopped MomAvatar pass — produced 535×1070 vs her 533×1069 (within 2 pixels) at near-identical visual quality. The whole 15-frame pipeline runs in ~60 seconds with zero clicks. Critical detail: `getbbox()` counts ANY non-zero alpha pixel as "in-bounds." rembg leaves subtle alpha-fringe pixels (alpha 1–15) outside the visible silhouette, so the naive bbox crop was 1440×1440 (full canvas). Fix: threshold the alpha channel to a binary mask before calling getbbox, then crop the ORIGINAL image to that bbox — preserves real edge anti-aliasing in the output while tightly cropping past the fringe.
**Why it matters:** When you're tempted to automate a desktop UI flow with a screenshot-driven agent, first check whether the underlying operation has a programmatic API. For images: ImageMagick, Pillow, rembg, Sharp. For video: ffmpeg. For PDFs: pdfplumber, qpdf. For audio: sox, librosa. CLI tools are deterministic, debuggable, free to run, and 10–100× faster than Computer Use. Reserve Computer Use for genuine UI-only workflows (App Store Connect screens with no API, web admin panels, legacy Windows apps) — not for batch image processing that has been a solved problem since the 1990s.

### @EnvironmentObject Propagation: Why Sibling Visits "Just Work"
**Where it came up:** Wiring `playerGender` through `PlotView` — needed to know which kid is doing the watering. The player's gender lives on `sessionManager.activeProfile.gender`. Question: does this still resolve correctly when a visiting kid is helping in a sibling's garden?
**What it is:** SwiftUI's `@EnvironmentObject` propagates down the view hierarchy automatically — any descendant view that declares `@EnvironmentObject var sessionManager: SessionManager` reads the **same instance** that was injected at any ancestor. `SiblingGardenView` swaps in a fresh `GameState` for the sibling's plot data via `.environmentObject(siblingGameState)`, but it does NOT swap `sessionManager`. So `sessionManager.activeProfile` still resolves to the visitor — the kid who tapped the sibling card to come help, not the kid whose garden it is. The same gender lookup at `GardenView.swift:900` gives the right answer in both contexts without any conditional code.
**In our code:** `GardenView` passes `playerGender: sessionManager.activeProfile?.gender ?? .girl` to `PlotView`. When called from the normal home garden flow, `activeProfile` = the kid playing on this device. When called from `SiblingGardenView` (which wraps the same `GardenView`), `activeProfile` = still the visitor, because only `gameState` got swapped. Marina watering Tomas's plant shows the *girl* character (Marina's gender) — correct.
**Why it matters:** This is why SwiftUI's environment system feels magical when you set it up right and infuriating when you set it up wrong. Each environment object is a separate stream that descendants read independently — you can rebind one (`gameState`) while leaving others (`sessionManager`) intact. The mental model: an environment object is a *named pipe* from any ancestor to any descendant, not a single shared blob. Use this deliberately when two flows need most-but-not-all of the same context.

---

## Session: March 24, 2026

### Dual-Context Data Problem (In-Memory vs Persistent)
**Where it came up:** SiblingGardenView.swift — rewarding the visitor while visiting a sibling's garden
**What it is:** The app has two data layers: the in-memory `GameState` (what views read and render) and the persistent `PlayerData` (what SwiftData stores to disk). They must always agree. When you update PlayerData directly via `modelContext` but forget to also update the in-memory GameState, the autoSave timer (0.5s debounce) will overwrite your PlayerData changes with stale in-memory values.
**In our code:** When a visitor helps in a sibling's garden, we write `visitorData.coins += 5` to PlayerData AND `visitorGameState.coins += 5` to the in-memory GameState. If we only did the PlayerData write, the autoSave would fire 0.5s later and save the old coin count from memory, erasing the reward.
**Why it matters:** Any app with caching or in-memory state has this problem. The rule is: if you write to the database directly, also update the cache. Otherwise the cache overwrites your database change on the next sync. This is why we pass `visitorGameState` through the view hierarchy — so we can update both layers atomically.

### Avoiding Unintended Side Effects from Helper Methods
**Where it came up:** SiblingGardenView.swift — `addXP()` vs direct `xp += 3`
**What it is:** `GameState.addXP(3)` looks simple, but internally it calls `checkLevelUp()` and `saveToStore()`. When you're in the middle of updating multiple properties and plan to save once at the end, calling a method that saves internally creates a partial-save problem — some properties are updated, others aren't yet, and the save captures this inconsistent state.
**In our code:** We changed from `visitorGameState.addXP(3)` to `visitorGameState.xp += 3` because we didn't want the intermediate `saveToStore()`. We call `modelContext.save()` once at the very end after all updates are complete.
**Why it matters:** Always check what helper methods do internally before calling them in a batch-update context. A method named `addCoins()` might just add coins, or it might also save, log, trigger animations, and post notifications. Read the implementation, don't assume from the name.

### Claude Code Skills (Slash Commands)
**Where it came up:** Setting up `/extract-frames`, `/add-asset`, `/export-procreate`, `/add-pantry-item`
**What it is:** Claude Code lets you create custom slash commands by putting a `SKILL.md` file inside `.claude/skills/<skill-name>/SKILL.md`. The file has YAML frontmatter (`name`, `description`) and markdown instructions. Once created, typing `/skill-name` in Claude Code triggers the instructions automatically.
**In our code:** We created 4 skills for common workflows: extracting video frames, adding image assets to Xcode, exporting for Procreate, and scaffolding new PantryItem enum cases.
**Why it matters:** Skills turn multi-step repetitive tasks into one-line commands. The key gotcha: the file MUST be `SKILL.md` inside a folder (`.claude/skills/my-skill/SKILL.md`), not a flat `.md` file at the skills root. We debugged this exact issue today.

### Xcode Asset Catalog: Image Assets vs Emojis
**Where it came up:** ChopMiniGame.swift — replacing 🔪 emoji with `Image("knife")`
**What it is:** Emojis are convenient placeholders but look out of place next to hand-illustrated assets. Real image assets (`.imageset` in Assets.xcassets) let you control size, rotation, shadow, and style consistency. Each imageset needs a `Contents.json` that maps the filename to the `universal` idiom.
**In our code:** ChopMiniGame had a 🔪 emoji and a programmatic brown rectangle for the cutting board. We replaced both with real `Image("knife")` and `Image("cutting_board")` assets that match the botanical watercolor style. The gameplay (sweet spot timing, scoring) stayed identical — only the visuals changed.
**Why it matters:** Visual consistency matters for a polished app. When you have a defined art style (botanical watercolor), every visual element should match. Emojis are system-rendered and can't be styled — they'll always look like emojis, not like your art.

---

## Session: March 23, 2026

### Apple Developer Portal: Capabilities vs App Services
**Where it came up:** WeatherKit JWT auth failure that persisted for weeks
**What it is:** In the Apple Developer Portal, each App ID has TWO separate tabs: **Capabilities** and **App Services**. They look similar but do different things. **Capabilities** tells Xcode "this app is allowed to use this feature" (it controls the entitlements file). **App Services** tells Apple's servers "accept API requests from this bundle ID." You need BOTH checked for server-side services like WeatherKit.
**In our code:** WeatherKit was enabled under Capabilities (so the app compiled and made requests), but NOT under App Services (so Apple's servers rejected every JWT token). The fix was one checkbox on the App Services tab.
**Why it matters:** This is a 4-level activation system for Apple services: (1) Xcode entitlements file, (2) Capabilities tab in developer portal, (3) App Services tab in developer portal, (4) provisioning profile regeneration. Missing any ONE level causes cryptic failures. This specific gotcha (Capabilities vs App Services) is poorly documented and trips up even experienced developers.

---

## Session: March 16, 2026

### GameKit & Real-Time Multiplayer
**Where it came up:** MultiplayerManager.swift, MultiplayerHealthyPicksView.swift
**What it is:** GameKit is Apple's framework for Game Center. It has 3 layers: (1) Authentication — "who is this player?", (2) Matchmaking — "find someone to play with" (Apple handles this), (3) GKMatch — "now talk to each other" (peer-to-peer data). Unlike a chat app where messages go through a server, GameKit connects devices directly — lower latency, no server costs.
**In our code:** `MultiplayerManager` conforms to `GKMatchDelegate` to receive data from the opponent. `GKMatchRequest` with `minPlayers = 2, maxPlayers = 2` tells Game Center we need exactly one opponent.
**Why it matters:** Multiplayer games need networking. GameKit gives you matchmaking + data exchange for free, no backend server to build and pay for. Perfect for indie/student projects.

### Deterministic Simulation (Seeded RNG)
**Where it came up:** SeededRandomGenerator.swift
**What it is:** The biggest challenge in multiplayer: both devices must show the SAME food in the SAME order. Instead of sending every food item over the network (slow/laggy), both devices generate identical "random" sequences independently. If two `SeededRandomGenerator`s start with the same seed number, they produce the exact same sequence forever. The host picks a random seed, sends it once, and both devices are in sync.
**In our code:** `state ^= state << 13; state ^= state >> 7; state ^= state << 17` — this is the xorshift64 algorithm. Fast, deterministic, good distribution. Both devices call `allFoods.randomElement(using: &rng)` and get identical food.
**Why it matters:** This pattern is used by most real-time multiplayer games (Starcraft, Age of Empires, fighting games). It's called "lockstep simulation" — instead of syncing the entire game state, you sync just the inputs (or seed) and let each device compute identically.

### The Host Pattern (Deterministic Role Assignment)
**Where it came up:** MultiplayerManager.swift
**What it is:** Both devices need to agree on who's "in charge" (generates the seed, starts the countdown). We compare player IDs: `isHost = localPlayerID < opponentPlayerID`. String comparison is deterministic — both devices do the same comparison and get opposite results. No extra network message needed.
**In our code:** `isHost = GKLocalPlayer.local.gamePlayerID < opponent.gamePlayerID` — one line, no negotiation round-trip.
**Why it matters:** Distributed systems always need a way to elect a "leader." Comparing unique IDs is the simplest approach. Production systems use fancier algorithms (Raft, Paxos), but for 2-player games, this is perfect.

### Codable Enum as Message Protocol
**Where it came up:** MultiplayerManager.swift
**What it is:** A Swift enum where each case is a different type of network message. `Codable` conformance lets Swift automatically convert it to/from JSON data for sending over the network. The receiving device decodes it and uses `switch` to handle each message type.
**In our code:** `enum MultiplayerMessage: Codable { case playerInfo(...), case seedExchange(...), case scoreUpdate(...) }` — one enum replaces what would normally be a complex message parsing system.
**Why it matters:** This is how any networked app communicates — defining a "protocol" of message types. Swift's enum + Codable makes this incredibly clean compared to other languages where you'd manually parse message type codes.

### UIViewControllerRepresentable (UIKit ↔ SwiftUI Bridge)
**Where it came up:** GameCenterMatchmakerView.swift
**What it is:** GameKit's matchmaker UI (`GKMatchmakerViewController`) is written in UIKit (Apple's older framework). SwiftUI can't directly present it, so `UIViewControllerRepresentable` wraps a UIKit view controller for SwiftUI use. The `Coordinator` class handles delegate callbacks (like "match found!" or "user cancelled").
**In our code:** `makeUIViewController()` creates the UIKit VC, `Coordinator` implements `GKMatchmakerViewControllerDelegate` and forwards events to our `MultiplayerManager`.
**Why it matters:** Many Apple frameworks still use UIKit. As a SwiftUI developer, you'll regularly need this bridge pattern. It's one of the most important interop skills.

### State Machine Pattern
**Where it came up:** MultiplayerHealthyPicksView.swift, MatchPhase enum
**What it is:** The app can only be in ONE state at a time (idle, matchmaking, connected, countdown, playing, finished, error). A `switch` on the current state determines which UI to show. This prevents impossible states like "lobby and game showing simultaneously."
**In our code:** `enum MatchPhase { case idle, authenticating, matchmaking, connected, countdown(Int), playing, finished, error(String) }` — the associated values (`Int` for countdown, `String` for error) carry extra data with the state.
**Why it matters:** State machines prevent entire categories of bugs. Any time you have a multi-step flow (onboarding, checkout, game phases), model it as an enum. The compiler ensures you handle every state.

### Misleading UI Labels (Last Played Time Bug)
**Where it came up:** ProfilePickerView.swift — "17m" display
**What it is:** The profile card showed a clock icon + "17m" which LOOKED like "last played 17 minutes ago" but actually meant "17 minutes total play time." Users interpret UI based on context (clock icon = time reference), not what the developer intended.
**In our code:** Changed from `shortPlayTime` (total play time) to `lastPlayedRelative` (relative time since last played). Also fixed `recordPlayTime()` to update `lastPlayedDate` when the session ends, not just when it starts.
**Why it matters:** UX lesson — always consider how users will READ your UI, not just what data you're showing. A clock icon + time string naturally reads as "time ago" to most people.

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
