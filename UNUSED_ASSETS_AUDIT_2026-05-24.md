# Unused Asset Audit — 2026-05-24

**Method:** Enumerated all 715 `.imageset` names across the asset catalogs, then checked
each against the full Swift source (`ChefAcademy/`, `AssetPackDownloader/`) for both literal
references (`Image("name")`) and dynamic base-name + frame-builder patterns
(`String(format: "base_%02d", i)`). Every candidate was manually verified — the first
automated pass produced ~100 false positives (assets loaded via a base name with the frame
suffix appended at runtime), which were excluded after tracing the actual call sites.

> ⚠️ This is a static analysis. Confirm against the running app before deleting — an asset
> could be referenced from a `.strings` file, a plist, or a code path not yet read.
> Deleting imagesets also touches `Contents.json` + the asset pack / ODR tags.

---

## ✅ Confirmed unused (187 imagesets — high confidence)

| Family | Count | Why it's dead |
|---|---:|---|
| `kitchen_sink_frame_001`–`125` | 125 | `WashMiniGame` loads `kitchen_sink_%02d` (→ `kitchen_sink_01`–`15`, which exist and ARE used). These 125 `_frame_NNN` originals are the un-downsampled set; no code references them. `CookingMiniGames.swift:831`. |
| `boy_card_frame_01`–`28` | 28 | App uses `boy_card_clean_frame_*` (`AvatarCreatorView.swift:114`). Raw `card_frame` originals appear only in `GardenHubView.swift`, which is orphaned dead code (CLAUDE.md §9). |
| `girl_card_frame_01`–`15` | 15 | Same as above — `girl_card_clean_frame_*` is the live set. |
| `stove_flame_01`–`15` | 15 | The stove flame is rendered with an SF Symbol (`flame.fill`) + scale animation (`flameScale`), not these frame assets. No code loads `stove_flame_NN`. |
| `recipe_pancakes_sunny`, `…_sunny1` | 2 | No `recipe_pancakes` reference anywhere. Likely old recipe hero images. |
| `cracked_egg_shell` | 1 | `CrackEggMiniGame` uses `cracked_egg_yolk` (`CookingMiniGames.swift:1053`), not `_shell`. |
| `Pip_points_up_left` (capital P, in `Pip_Poses_clean/`) | 1 | Duplicate of the live lowercase `pip_points_up_left` (in `Pip/`). Code + `PipPose` enum reference the lowercase one (`PipAnimations.swift:233`). |

**The big win:** `kitchen_sink_frame_*` (125) + the `card_frame` originals (43) + `stove_flame_*` (15) = **183 assets**, all superseded by other live sets. The kitchen-sink frames are tagged into the kitchen asset pack (~147 MB per `ODRManager.swift:11`), so removing them meaningfully shrinks that pack.

---

## 🟡 Verify intent before deleting (3 — possibly future features)

| Asset | Note |
|---|---|
| `farm_chili` | No `PantryItem` case references it. Either dead or a planned pantry item. |
| `farm_honey` | Same. |
| `farm_lamb` | Same. |

`PantryItem.imageName` uses `farm_*` assets, so these were likely drawn for pantry items not
yet added to the enum. Keep if on the roadmap; delete if abandoned.

---

## ❌ False positives my first pass flagged — these ARE used (do NOT delete)

These were caught by the automated check but confirmed live after tracing call sites:

- `pip_throw_veggie_frame_01`–`30`, `pip_hand_up_left_frame_01`–`30`, `pip_hand_up_right_frame_01`–`30` (90 frames) → `PipGameAnimationView.swift` (base name + frame builder)
- `boy_hat_colored_*`, `girl_hat_colored_*` (10) → `AvatarModel.swift`

---

## Suggested next step

If you want these removed, I can delete the imageset folders and their entries, then rebuild
to confirm nothing breaks — **one family at a time**, starting with the 125 `kitchen_sink_frame_*`
(biggest, cleanest case). Your call — this is destructive so I won't touch anything without a go-ahead.
