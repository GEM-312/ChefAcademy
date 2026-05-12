# ASSETS.md — Full Asset Inventory & Needs

## Current Inventory: ~722 imagesets total (May 12, 2026)

`find ChefAcademy/Assets.xcassets -name "*.imageset" -type d | wc -l` → 722.

| Category | Count | Status |
|----------|-------|--------|
| **AvatarCards** (all character frame sets) | **103** | Complete for shipped flows |
| ├─ `boy_card_frame_01..28` | 28 | Child avatar animation |
| ├─ `girl_card_frame_01..15` | 15 | Child avatar animation |
| ├─ `mom_avatar_frame_01..15` | 15 | Parent avatar (May 11) |
| ├─ `dad_avatar_frame_01..15` | 15 | Parent avatar (May 11) |
| ├─ `boy_pours_water_frame_01..15` | 15 | Plot watering animation (May 11) |
| └─ `girl_pours_water_frame_01..15` | 15 | Plot watering animation (May 11) |
| `boy_card_clean_*` / `girl_card_clean_*` | ~30 | "Profile pose" static frames (catalog root, separate folders) |
| Backgrounds (garden, farm, kitchen) | ~7 | Complete |
| FarmItems / Pantry (`farm_eggs`, `farm_salt`, etc.) | ~20 | Complete (19 used + 2 bonus: lamb, chili) |
| Vegetables (27 veggie images planned) | 8 drawn / 19 pending | See `MEMORY.md` Plants section for the 19-asset list still in Procreate queue |
| Recipes (17 recipe illustrations) | 17 | Complete |
| Pip poses + walking + waving + body + reaction frames | ~60+ | Complete |
| KitchenSink (cooking-flow frames) | ~140 | Complete |
| Cooking (`frying_pan`, `empty_plate`, `knife`, `cutting_board`, egg assets) | 6+ | `knife` and `cutting_board` added Mar 24 |
| AvatarCards colored outfit/hat frames | 20 | Outfits (10 colors × 2 genders) for color-reveal flow |

---

## Plant Care Assets — Status Update May 12

Original plan called for drawn `watering_can.png` / `weed_01.png` / `ladybug.png` / `aphid.png` / compost imagesets. Current ship state is **emoji-driven UI** at small plot-tile sizes (100×110pt — too small for botanical illustrations) **plus** a large kid-character pour animation that escapes the tile via overlay. This pattern is intentional, not a deferred plan.

### Watering — DONE differently
- ❌ Standalone `watering_can.png` drawn asset — not shipped
- ✅ `🚿` emoji visible on plot during watering hold (`PlotView.swift:232`)
- ✅ `WaterPourCharacterView` (May 11) — 15-frame kid character (boy or girl, gender-driven) slides in from the left/right of the plot with SwiftUI Canvas + TimelineView water particles. Spout anchor measured from frame 08; particle physics gravity + horizontal velocity toward plot.
- ✅ `boy_pours_water_frame_01..15` / `girl_pours_water_frame_01..15` imagesets (May 11)

### Weeding — emoji UI, illustrated assets deferred
- Plot weeds render as `🌿` at 3 sizes (`PlotView.swift:294`) — swipe up to remove with animated offset
- Drawn `weed_01/02/03.png` deferred unless plot-tile size grows or weeding gets its own dedicated screen

### Bug Rescue — emoji UI
- Plot bugs render as `🐛` / `🐞` — tap to rescue with ladybug-from-edge animation
- `ladybug.png` / `aphid.png` deferred (same rationale as weeding)

### Composting — feature not built
- No composting flow exists in the codebase. Drop from queue unless reintroduced.

### Sunshade — feature not built
- No sunshade mechanic shipped. Weather affects growth via `GardenPlot.weatherMultiplier`; per-veggie weather preferences via `weatherGroup`. No protective object UI.

### Kid Avatar Caring — DONE for watering (different spec from original plan)
- Original asked: 5 frames of `boy_watering_NN.png` + `girl_watering_NN.png`
- Shipped: 15 frames of `boy_pours_water_frame_01..15` + `girl_pours_water_frame_01..15` (different naming convention, 3× the frame count)
- Weeding / debugging avatar frames not drawn (emoji UI handles those)

---

## NEEDED: Cooking Assets

### Mini-Game Visuals
| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `cutting_board.png` | Wooden cutting board, top-down | Botanical watercolor | HIGH |
| `mixing_bowl.png` | Ceramic mixing bowl | Botanical watercolor | HIGH |
| `wooden_spoon.png` | Wooden cooking spoon | Botanical watercolor | MEDIUM |
| `salt_shaker.png` | Salt shaker for SeasonMiniGame | Botanical watercolor | MEDIUM |
| `peeler.png` | Vegetable peeler | Botanical watercolor | MEDIUM |

### Already Have (from this session)
- `frying_pan.png` — HeatPanMiniGame + AddToPanMiniGame
- `empty_plate.png` — AssembleMiniGame
- `cracked_egg_yolk.png` — CrackEggMiniGame (after crack)
- `cracked_egg_shell.png` — Available for shell animation

---

## NEEDED: Body Buddy Assets

| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `body_buddy_figure.png` | Cartoon kid body silhouette (front view, full body) | Cute, simple, botanical | HIGH |
| `organ_brain.png` | Cute cartoon brain | Kid-friendly, colorful | MEDIUM |
| `organ_heart.png` | Cute cartoon heart | Kid-friendly, colorful | MEDIUM |
| `organ_stomach.png` | Cute cartoon stomach (for digestion) | Kid-friendly, colorful | MEDIUM |
| `organ_bones.png` | Cute cartoon skeleton/bone | Kid-friendly, colorful | MEDIUM |
| `organ_muscle.png` | Cute cartoon flexing arm | Kid-friendly, colorful | MEDIUM |
| `organ_eye.png` | Cute cartoon eye | Kid-friendly, colorful | LOW |
| `organ_shield.png` | Cute shield (for immune system) | Kid-friendly, colorful | LOW |

---

## NEEDED: UI/UX Assets

| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `scroll_hint_arrow.png` | Bouncing down arrow for scroll cues | Simple, animated | HIGH (P0 UX) |
| `pip_big.png` | Larger Pip for interactive areas | Match existing Pip style | HIGH (P0 UX) |
| `speaker_icon.png` | Custom speaker button (or use SF Symbol) | Match theme | LOW (using SF Symbol) |

---

## Pip Voice — Architecture Update (May 12)

**Current ship state:** voice is **API-on-demand**, not pre-recorded clips.

- `ElevenLabsVoiceService.swift` calls a Cloudflare Worker proxy (App Attest-secured) for live TTS synthesis with the cached Pip voice ID
- `PipVoice.swift` is the singleton router: free tier = silent (kid reads on screen); paid tier = ElevenLabs synthesis with audio cache for repeated phrases (`audioCache` dict keyed by text)
- `PipSpeechBubble` and `PipHeaderStack` auto-speak on appear and on message change — no manual `.speak()` wiring needed at most call sites
- Apple TTS was rejected May 10 (voices sounded awful) — don't reintroduce

**Why no pre-recorded clip list anymore:** the texts speech is being produced for are now generated dynamically (recipe steps, garden weather tips, Pip's AI chat replies). A static clip list would only cover a fraction of what's spoken. The on-demand path + cache covers the variability without a manual recording pipeline.

If the cost model later forces a hybrid approach (pre-recorded for the top 50 most-said phrases, live for the rest), see `project_pip_ai_cost_optimizations.md` in memory for the planning notes.

---

## ASSET GENERATION TIPS

### For Procreate (Images)
- Export as **PNG with transparency**
- Canvas size: **1024×1024** (scales down well for all devices)
- Style: botanical watercolor, warm tones, hand-drawn feel
- No harsh outlines — soft, organic edges
- Match the warm cream/sepia/sage palette
- For airdropping app images to Procreate: use the `/export-procreate` skill (extracts all PNGs from `Assets.xcassets/` into a flat folder)

### For Multi-Frame Sprite Animations (NEW — May 11)
**Headless pipeline replaces the Photoshop trip.** From a video file:

```bash
bash extract-and-trim.sh <video.mp4> [num_frames]
```

Chains `ffmpeg` (extract) → `rembg` `isnet-anime` model (background removal) → Pillow `getbbox()` with alpha threshold (tight crop). Output ready for `Assets.xcassets` import. Tested against manual Photoshop pass on MomAvatar: bbox within 2 pixels at near-identical quality. ~60s per 15-frame video vs the prior 15-min manual pass.

Use the legacy `extract-frames.sh` only when rembg fumbles (hair wisps, transparent fabric) — it leaves `originals/` populated for a manual Photoshop touch-up.

### For ElevenLabs (Voice) — generation pipeline
- Voice ID + API key live in the Cloudflare Worker as secrets (`pipVoiceID`, `xi-api-key`)
- Clips synthesized on-demand at runtime via `ElevenLabsVoiceService.fetchSpeech(text:)`
- Per-phrase audio cached in memory via `audioCache: [String: Data]`
- Character voice: young, enthusiastic, slightly high-pitched; tone: encouraging, warm
- No file format on disk — audio data flows directly into `AVAudioPlayer`

---

## BONUS: Unused Assets in FarmItems
- `farm_lamb.imageset` — not in PantryItem enum (could add lamb recipes later)
- `farm_chili.imageset` — not in PantryItem enum (could add spicy recipes later)

---

*Last Updated: May 12, 2026 — counts re-measured from disk (722 total imagesets, 103 AvatarCards). Plant care section now reflects shipped emoji-UI reality + WaterPourCharacterView; Pip Voice section reflects API-on-demand architecture.*
