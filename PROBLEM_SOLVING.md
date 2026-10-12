# Problem Solving Log — Pip's Kitchen Garden

Real problems we hit, what caused them, how we fixed them, and how the fix works.
Newest first. Each entry: **Symptom → Cause → Solution → How it works → Where**.

---

## 2026-10-11

### 1. The Garden looked hugely zoomed in on iPad, but Home looked fine

**Symptom.** On the iPad Pro 13" the Garden screen showed only the top-left corner of the oak tree. The Home map fit the window perfectly. The new background had just been swapped in, so the art looked like the cause.

**Cause.** It wasn't the art. The new and old garden images have the same size and framing. The real culprit was four lines in `GardenView.swift` that measured **`UIScreen.main.bounds.width`**:
- the harvest basket
- the empty-basket height
- the falling veggie
- the seed bags

`UIScreen` is the width of the whole iPad screen. The app was running in a **Stage Manager window** about 390pt wide, but the basket asked for 85% of the full screen, about 1,170pt.

In SwiftUI a stack is as wide as its widest child, so that one basket stretched the whole Garden page to about 1,170pt. The map fills the page width, so it grew 3× and only its corner was visible.

Home was fine because it never asks `UIScreen`. It measures its own space with a `GeometryReader`.

In full screen the window and the screen are the same width, which is why the bug stayed hidden until the app ran in a window.

**Wrong first fix (lesson).** The first attempt changed how the garden map is sized, so it would always fit the screen height. Nobody had asked for a layout change, and on the windowed iPad it shrank the map and pushed it sideways. It was reverted with `git checkout`. Rule: when a visual problem shows up after art work, find what actually changed before touching any layout code.

**Solution.** Pass the real window width down from the `GeometryReader` GardenView already had:
- `bottomPanel(width:)`, `seedInventorySection(width:)` and `harvestedSection(width:)`
- `SeedBadge(availableWidth:)`

**How it works.** `GeometryReader` reports the size SwiftUI actually gives the view, which is the app's window or split. `UIScreen.main.bounds` always reports the physical screen, whatever the window size. Apple deprecated `UIScreen.main` for exactly this reason. Anything that sizes itself as a percentage should be a percentage of the space it actually has.

**Where.** `88526f5` fix(garden), in `GardenView.swift`. The garden map's `.opacity(0.8)` was also removed (`6ec62d5`) so it shows at full strength like Home.

---

### 2. The Home background came out pinkish when matched to the stations

**Symptom.** The Home map's lines had 9–21% less sepia than the station buildings. Boosting the sepia made the flowers and path look **pink/reddish**, not sepia.

**Cause.** The Home map is a **cut-out**: its paper was removed, and the lines have soft, partly transparent edges that blend into the app's cream background. What you see on screen is a mix of the line color and the cream.

The first attempt boosted the color in that on-screen mix, then worked backwards to the PNG's own color. For many pixels that meant a color channel would have to go *below zero*. The number got clipped at 0, the green channel lost the most, and green missing from sepia reads as pink. The hue moved from 83° (sepia) to 70° (pinkish).

Marina's spec for the fix: *"desaturate and apply the amount of sepia the station has, not saturation."*

**Solution.** Two steps, done in the on-screen color space:
1. **Desaturate, then tint.** For each pixel, keep only its lightness, which is the same as making it gray. Then give it the stations' sepia, the exact hue and strength the stations have *at that same lightness*. Dark lines get the stations' dark-line sepia, and light shading gets their light-shading sepia.
2. **Re-derive the transparency** with a color-to-alpha step against the cream. For each target color, find the smallest opacity that, mixed with cream, gives exactly that color. Then nothing has to be clipped, and the result on screen is exact.

**How it works.** Matching "amount of color" only makes sense at **equal lightness**. The stations' darkest lines and their pale shading carry different amounts of sepia. So the stations are measured in lightness bands (L20–30, L30–40, …). Each band gets its own median sepia hue and strength, and each pixel of the new art is tinted from the band it falls in. Lightness isn't changed, so contrast stays the same and no saturation is added.

Always check the **hue spread**, not just the average saturation. An average hid the pink shift; the hue numbers showed it right away.

**Where.** `acd2036` art(home).

---

### 3. Removing the scattered meadow flowers without cutting flowers in half

**Symptom.** The Home map had flowers scattered all over the meadow. Marina wanted only the stepping-stone path and the flower rings around the six stations.

**Cause / difficulty.** Erasing with a shape, like "keep these ellipses", slices any flower that crosses the edge in half.

**Solution.** Treat each flower or grass tuft as one object:
1. Find every drawn pixel. The map is a cut-out, so drawn means not transparent.
2. Grow the drawn pixels by 4px so each flower's petals, stem and leaves join into a single **blob**. This is connected-component labelling.
3. Define a "keep zone": each station oval, widened to include its flower ring, plus a band along the stepping stones.
4. Keep a blob only if **more than half of it** lies in the keep zone. A blob is kept or removed whole, so nothing gets sliced.
5. A few loose tufts sat just inside the zone; those were erased by hand.

**How it works.** Connected-component labelling (`scipy.ndimage.label`) gives every separate drawn shape its own number. The decision is then made per object, not per pixel.

The first try grew the blobs too much (12px). The faint grass then chained every flower in the meadow into one giant blob, which "touched" a station, so nothing was removed. The amount of growth has to be big enough to join one flower's parts but small enough not to join neighbours.

**Where.** `acd2036` art(home). Size and placement unchanged, so the station positions in `HomeImageMap` still line up.

---

### 4. New OpenArt art never matches the house style. Automate the match and prove it

**Symptom.** Every new image from OpenArt comes in a different color and contrast: green paintings, yellow vegetables, washed-out backgrounds. Matching each one by hand is slow and inconsistent.

**Solution: the Art Match tool.** A Python script plus a macOS folder watcher.

**The flow:**
1. Drop an image in `~/Dropbox/Mac/Desktop/Art Inbox/`.
2. **launchd**, the macOS system that starts background programs, watches the folder. The settings file `com.chefacademy.artmatch.plist` (`WatchPaths`) tells it to run `tools/art_match.py --inbox` whenever the folder changes. It starts at login, and Claude doesn't need to be open.
3. The script waits until the file stops growing, so a half-downloaded image is never processed.
4. **Reference:** it measures the 6 `home_loc_*` stations fresh every run, as they look on cream. If the stations change, the target follows automatically.
5. **Contrast match:** finds the new image's darkest lines (2nd percentile of ink) and its mid-tones (25th/50th/75th percentiles). A tone curve moves them onto the stations' values (darkest L16, mid-tones L62). Paper lighter than L88 is left alone, so the background doesn't change.
6. **Sepia match:** desaturate and tint per lightness band, as in problem 2.
7. **Transparency:** cut-out art gets color-to-alpha against cream. Sprites keep their transparency untouched.
8. **Evaluation gate:** 6 pass/fail checks against the stations:

   | Check | Pass if |
   |---|---|
   | Darkest lines | within ±2 lightness |
   | Mid-tones | within ±2 lightness |
   | Sepia per shade (every band) | within ±5% |
   | Sepia hue | within ±3° |
   | Reddish cast | no more reddish pixels than the stations have, +1% |
   | Transparency | sprites unchanged; cut-outs lose ≤10% of visible pixels |

9. PASS goes to `matched/`; FAIL goes to `matched/failed/`, with the failing checks in red on the before/after sheet. The original moves to `originals/`, a line is written to `match_log.txt`, and a notification pops up.
10. **Install stays human:** `/add-asset` lists only the passed files, shows each one's sheet, and asks for its name and folder. It never installs a failed file.

**Proving the checks work (negative tests).** A check that never fails proves nothing, so we fed it known-bad images on purpose:
- raw unmatched OpenArt: **FAIL**
- a matched image pushed slightly pink: **FAIL**, caught only by the hue check (79° vs 83°)
- a faded image: **FAIL**
- the correctly matched image: **PASS**

**A check that was wrong.** The transparency check first failed a good image with "visible pixels +20%". Matching the contrast had made faint lines darker, so more of them became visible. That's correct behavior, so the check was changed to fail only when content is *lost*, never when it's gained. Lesson: when a check fails, first ask whether the check is measuring the right thing.

**Where.** `7398736` feat(tools):
- `tools/art_match.py`
- `tools/com.chefacademy.artmatch.plist`, with an installed copy in `~/Library/LaunchAgents/`
- `.claude/skills/add-asset/SKILL.md`

To check any image without changing it: `python3 tools/art_match.py --report image.png`.

---

### 5. "The backgrounds look more colorful than the stations" (morning)

**Symptom.** After desaturating, the Home background still looked more colorful than the station buildings.

**Cause.** The first measurement compared the background's paper with the stations' building shading, which is the wrong pair, and averaged the whole image. Compared at **matched lightness**, the sepia was already almost the same. The extra color Marina saw was the **pink and salmon poppies**: small, saturated accents that a whole-image average hides.

**Solution.** Measure color per lightness band and look at the image, not only at the averages. The 27 vegetables measured too yellow the same way and were recolored to the stations' sepia (`1e8751f`). The Home map's paper was cut out so it sits directly on the app's cream (`0d3df4d`). The Garden map was recolored and its paper filled with the stations' ground color #F9F2DF (`cb4ace9`).

---

### Open: Pixelmator has no history log

Photoshop's History Log proves *what* was edited and *when*, and the hours record depends on it. Pixelmator Pro has no history or undo access in its scripting dictionary. Idea, postponed: a background script that every 60 seconds records which document is in front, whether it has unsaved changes, its current layer, and keyboard/mouse idle time. That gives a timestamped "actively working on file X" log. It proves *when* and *which file*, not individual edits.
