# Problem Solving Log — Pip's Kitchen Garden

Real problems we hit, what caused them, how we fixed them, and how the fix works.
Newest first. Each entry: **Symptom → Cause → Solution → How it works → Where**.

---

## 2026-10-23

### 1. Pip stuttered and stopped mid-sentence in chat

**Symptom.** In Ask Pip, Pip restarted the same sentence over and over ("shattering") and often stopped before the end. The console showed many `fetched + saved: Carrots are orange because they are pack…`, `Too many concurrent requests… maximum of 6`, `401`, and `Could not sign request… devicecheck error 0`.

**Cause.** The chat shows Pip's reply while it streams in. That live bubble is a `PipSpeechBubble`, which speaks every time its text changes, so every few words a new ElevenLabs request went out with a partial sentence. Each clip that came back replaced the one playing; the last to finish was often partial. More than 6 at once hit ElevenLabs' limit, and the burst of App Attest signatures failed (401).

**Solution.** The streaming bubble is quiet (`pipBubble(_, speaks: false)`); the finished reply's own bubble speaks once. The voice service also keeps the line in flight in `speakTask`, and a new line cancels it ("newest wins").

**How it works.** A view that re-renders many times a second must not trigger a side effect (a paid network call) on every render. And a `Task` you never store can never be cancelled: keeping one handle makes "cancel the old one" a single `cancel()`.

**Where.** `AskPipView.swift`, `ElevenLabsVoiceService.swift`, commit `03cf714`.

### 2. Garden Pip said half of one tip, then another

**Symptom.** Tapping Pip in the garden: he started one sentence, got cut off, then said a different one.

**Cause.** The tap asked the AI for a new tip (about 1 s) and opened the bubble at the same moment, still showing the previous tip, so Pip started reading the old one; when the new tip arrived, the bubble changed and spoke again, cutting the first.

**Solution.** The bubble opens only when the new tip is ready; extra taps while it's coming are ignored (plus a haptic, so the kid feels the tap). Every tip is one short sentence.

**How it works.** Show state only once it's the state you mean. Ignoring taps while loading also fixed a second bug: kids tap again when nothing happens, which cancelled the first request (`-999 cancelled` in the log).

**Where.** `GardenView.swift`, commits `4119003`, `a6dd0f6`.

### 3. Pip said "plant broccoli" while broccoli was ready to harvest

**Symptom.** The garden tip AI suggested planting a veggie that was already grown and ready.

**Cause.** The tip came from Apple's small on-device model with the garden state pasted into the prompt. The data was there; the small model ignored it. (Giving it tools had been tried before and was worse.)

**Solution.** `VeggieJourney`: one source of truth for each veggie (seeds → spots → wheelbarrow → pantry → cooked), with the next step decided in code. Pip Plus players get Claude Haiku, which only words that step (facts in the message, no tool: the tip always needs the whole garden). Free players and visitors get the built-in lines. A safety review then caught that Pip could suggest a recipe with the child's allergen; `VeggieJourney` now skips those. The child's name is added in code, never sent.

**How it works.** Code decides, the model words it. A model handed a decided action can phrase it freely but can't choose the wrong one. A tool earns its place only when the model decides what to look up.

**Where.** `VeggieJourney.swift`, `GardenTipAI.swift`, `GardenView.swift`, commits `fb7d3a3`, `a6dd0f6`.

### 4. Silent mode muted Pip, depending on which screen opened first

**Symptom.** With the phone in silent mode, Pip sometimes didn't speak.

**Cause.** Pip's voice service set the shared audio session to `.playback` (ignores silent mode) and the ambient-sound player set it to `.ambient` (obeys it). Whichever started last won.

**Solution.** One owner, `AppAudioSession.configure()` at launch: `.playback` + mix with others (Marina: Pip talks through silent mode, like a media app). Later "Pip is silent in a kid profile" turned out to be the Home 🔊 chip switched off (one switch for the whole device), not silent mode.

**How it works.** A shared resource needs exactly one owner. To tell the cases apart, read the log: no `[ElevenLabs]` line at all means `speak()` returned at its first guard.

**Where.** `AppAudioSession.swift`, commit `fa29a66`.

**Open.** The "AVAudioSession Hang Risk" warning still fires once per player start: `AVAudioPlayer.play()` checks the session on the main thread. Moving `play()` off the main thread is on board #10 (voice tier card); `fa29a66`'s message overstates this fix.

### 5. The design guard missed most hardcoded values

**Symptom.** A scan found ~985 hardcoded sizes, spacing, strokes and hand-made buttons that the commit hook never blocked.

**Cause.** `design-guard.py` only checked 8 patterns, and only on Claude's own commits.

**Solution.** It now blocks every category (zero allowed; `// design-guard: allow — <reason>` for real exceptions), and a GitHub Action runs `--ratchet` on every push: it fails if the whole-app count rises above `.design-guard-baseline`.

**How it works.** A ratchet doesn't demand zero today; it only forbids going backwards, and the baseline drops as each screen is fixed.

**Where.** `.claude/hooks/design-guard.py`, `.github/workflows/design-guard.yml`, commits `6111747`, `980f6d7`.

### 6. "Create their chef!" asked for the hat color before Boy/Girl, then again

**Symptom.** Marina's iPhone test (Add Little Chef): the hat colors showed before a gender was picked, with white already circled. After tapping Girl they vanished, then came back after the outfit color ("pick hat color again"). The outfit label just said "Pick a color!" without saying of what, and Next worked with nothing picked.

**Cause.** Both flows started every child already dressed: `.apronRed` and `.chefHatWhite` (`AddChildFlowView`, `FamilySetupManager`). The hat picker shows when `outfit.isChosen`, which was true before the kid chose anything. Picking a gender resets the outfit to `.none`, which hid the picker until an apron color turned it back on.

**Solution.** Outfit and hat start at `.none`, which is what `AvatarModel.defaultOutfit()` already promised. The hat picker needs `genderChosen && outfit.isChosen`. The label says "Apron color!" or "Coat color!". Next is faded until a gender and an outfit color are picked; the hat stays optional (✕ = no hat). `restorePickedLook()` shows the dressed chef again after Back.

**How it works.** A default value is a choice made for the player: every "has she picked?" check downstream trusts it, so use the explicit "none" case and require the pick. And `@State` starts fresh each time the step's `switch` case re-creates the view, while the `@Binding` values in the parent survive, so after Back the view has to rebuild its look from the bindings.

**Where.** `FamilySetupView.swift` (`FamilySetupManager`, `FamilyAvatarStep`, `OutfitColorPicker`), `AddChildFlowView.swift`.

**Open.** Parents dress up a *kid* card in setup, then appear as the separate mom/dad art, which looks like grandparents next to the kids. That needs new art: board #10 card "Art: parent avatars (mom/dad) redrawn in the kids' style + dress-up frames".

---

## 2026-10-18

### 1. Switching players could overwrite a sibling's whole game

**Symptom.** None seen yet, but it was found while reviewing the save code: after "Switch player", one kid's coins, garden and pantry could end up in a sibling's record.

**Cause.** Autosave waits 0.5 s after a change, then saves. Switch Player and Sign Out clear the selected kid (`activeProfileID = nil`) right away. If an autosave was still waiting, `saveToStore()` ran with no kid and fell back to an old "legacy mode": it saved into *the first PlayerData in the store*, which can be any kid. "Delete all data" hit the same fallback and created an ownerless record, which the next launch mistook for an old single-player save to migrate.

**Solution.** With no kid selected, `saveToStore()` now logs `SKIPPED` and returns. Nothing in the app needed the fallback: new kids, family setup and the legacy migration all set the kid first or write directly.

**How it works.** A save can only go to the record of the kid who is playing. A late save that has no kid is dropped, and that's safe because Switch Player and Sign Out already saved just before clearing the kid. Verified on device: the save log showed every save under the right kid's ID, and one `SKIPPED` exactly at the switch.

**Where.** `GameState.swift` (`saveToStore`), commit `0b5fa6a`.

### 2. An older app version would delete items a newer one added

**Symptom.** None seen yet; found by the persistence review of the new grains & legumes items. A device with an older build would wipe a kid's oats after syncing.

**Cause.** Loading skips saved items whose name the app doesn't know (fine), but saving rebuilt the pantry from memory, so the skipped items were left out and the deletion synced back through iCloud. Seeds and harvest worked the same way.

**Solution.** Unknown entries are kept aside on load (`unknownSeedsData`, `unknownHarvestedData`, `unknownPantryData`) and written back unchanged on save.

**How it works.** Forward compatibility: if you don't understand it, carry it, don't delete it. It only protects from the version that has it onward, so it had to go in before the first App Store release. Still open: a garden plot growing an unknown vegetable loses it (board card).

**Where.** `GameState.swift` (`loadFromStore`, `saveToStore`), commit `0b5fa6a`.

### 3. Likes on a sibling's garden disappeared

**Symptom.** After visiting a sibling's garden, help showed up for them but likes didn't.

**Cause.** A visit loads the sibling's game into a temporary in-memory copy. "Cool garden!" added the like straight to the saved record, but the copy kept the old count. A help action then saved the copy, writing the old like count back over the new one. Help messages survived because they're added straight to the record and aren't part of the copy.

**Solution.** The like also updates the copy (`siblingGameState.gardenLikes = data.gardenLikes`).

**How it works.** When two places hold the same data, every change has to update both, or the last one to save wins. Likes lost before the fix can't be recovered.

**Where.** `SiblingGardenView.swift` (`onLikeGarden`), commit `0b5fa6a`.

### 4. Cooking kept re-teaching steps the player already knew

**Symptom.** After making instructions show only the first time, the cooking steps were still read out for a player who had cooked before.

**Cause.** First wrong guess: the app on the phone was built before the change. True (the newest build log was older than the edit), but after rebuilding it still happened. Reading the app's saved settings off the iPhone (`xcrun devicectl … --domain-type appDataContainer`) showed the real cause: skills are recorded when a mini-game is finished, and recording started with that day's build. One profile had cooked only before it, so it had no skills saved.

**Solution.** When a cook starts, every recipe the player has already finished (it has stars) counts: all of its mini-game skills are marked learned. The Kitchen's first-cook instructions use the same check.

**How it works.** Skills are tracked per mini-game (chop / slice / dice share one skill), not per dish, so a new dish still teaches a skill the player has never used.

**Where.** `CookingSessionView.swift` (`markSkillsFromFinishedRecipes`, `CookingStepType.skill`), `PipComponents.swift` (`PipTutorial`), `KitchenView.swift`.

### 5. Pip stood on the Counter button and started up on the shelves

**Symptom.** In the Kitchen, Pip walked onto the Counter spot, so it couldn't be tapped. When the Kitchen opened he appeared up on the shelves and walked down.

**Cause.** For each cooking step Pip walked to the station's exact centre. His home spot was calculated once, on the first layout pass, when the picture was still measured smaller than its final size, and a `pipDidInit` flag stopped it from being recalculated.

**Solution.** Pip stays on the floor line and stops a little left of each station, under it, showing the "points up" pose. His home spot is recalculated whenever the picture's size changes while he's idle (`.onChange(of: size, initial: true)`).

**Where.** `KitchenView.swift` (`walkPipForPhase`, `floorSpot`), `AdaptiveLayout.swift` (`kitchenPipStationGap`).

### 6. Tomato sauce showed a tiny old can

**Symptom.** Found while thinning the item outlines: the tomato sauce item still used an old picture, a tiny red can in a lot of empty space.

**Cause.** On Oct 17 the new picture was copied in as `farm_tomatoSauce.png`, but the set's `Contents.json` still named the old file (`farm_soySauce.png`). Honey had the same problem.

**Solution.** Both sets now point at their new files, and the old files were removed. A check confirmed that every item set names its own picture.

**Where.** `Assets.xcassets/FarmItems/farm_tomatoSauce.imageset`, `farm_honey.imageset`.

### 7. The shop looked darker and yellower than the kitchen

**Symptom.** The shop background read darker and warmer than the kitchen, and the item pictures had heavy outlines.

**Cause.** The shop art had darker shading and a warmer (more yellow and orange) sepia. The kitchen is also drawn at 85% over the cream page in the code, but the shop was drawn at full strength.

**Solution.** It took several tries:
1. Matching brightness only left the warmth difference.
2. Adding the kitchen's 85% fade on top doubled the lightening.
3. Matching colour by *stretching* it as well as shifting it pushed already-tinted items (turmeric) to bright yellow.

The final version shifts the shop's brightness and colour (Lab L curve + a\*/b\* shift, no stretch) onto the kitchen's, starting from the original art, at a light 93% fade. The heavy shop texture went hazy at 85%. The 30 item pictures got the same shift, and their cut-out edge was shrunk 2 px, which removes the outer half of the drawn outline without regenerating.

**How it works.** The darkest lines are left where they are and only mid-tones and paper move, so the drawing stays crisp. Backups: `ShopArt/front_repaint/`, `ShopArt/items/before_outline_oct18/`, `ShopArt/items/cut/`.

**Where.** `Assets.xcassets/Backgrounds/bg_shop.imageset`, `Assets.xcassets/FarmItems/`, `FarmShopView.swift` (`shopMapSection`, opacity 0.93).

### 8. The new garden looked washed out, whatever the art

**Symptom.** The new orchard garden looked faded next to the kitchen and shop, even after its colors were matched to the kitchen.

**Cause.** The art was never the problem, though it took three art passes to see that:
1. matched to the kitchen as shown, then faded again at 93% (lightened twice)
2. matched to the kitchen's art
3. matched to the shop's darker lines

Marina said to check the code, and that's where it was: `SeasonalOverlayView` lays a **pale color gradient over the whole garden map**, which in fall is peach and gray at 30% / 20% / 10%. A veil over the whole picture washes out every line, so no amount of re-coloring the art could fix it.

**Solution.** The full-map tint was removed, and the seasonal particles (leaves, petals, sparkles) still show the season. The 93% fade came off the garden, and the art is the version matched to the kitchen as shown.

**How it works.** The order of layers matters as much as the colors in them: anything drawn *over* a picture changes how it looks, whatever the picture's own pixels are. Lesson: when a whole screen looks washed out, look for overlays and opacity in the code before re-grading the art.

**Where.** `WeatherOverlayView.swift` (`SeasonalOverlayView`), `GardenWeatherService.swift` (`gradientColors` removed), `GardenView.swift` (`gardenMapSection`), commit `01a95fb`.

---

## 2026-10-17

### 1. The harvest basket looked tiny next to the veggies

**Symptom.** Under "Harvested Veggies" a small basket sat in a big empty area, with huge veggies stacked around it instead of in it.

**Cause.** The basket picture was 2912×1632 px, but the basket covered only about a third of its width. The rest was empty canvas. The view sized the *canvas* to the section, so the basket came out small, while the veggies were sized from the same number and looked enormous.

**Solution.** A new empty wheelbarrow drawing, cut out and trimmed tight so the object *is* the image, in three layers:
1. the whole wheelbarrow
2. the veggies, at fixed spots matched to the tub's rim
3. only the front wall (`harvest_wheelbarrow_front`), drawn again on top

**How it works.** Drawing the front wall last covers the bottom of each veggie, so they look like they're inside the tub. The same trick puts Pip behind the shop counter: a second copy of the shop picture, masked to everything below the counter edge, is drawn over him.

**Where.** `FarmShopView.swift` (`BasketWithVeggiesView`, `shopMapSection`), `Assets.xcassets/Backgrounds/harvest_wheelbarrow*`.

### 2. Cut-outs from the shop picture were too small to use

**Symptom.** The shop items were meant to be cut straight out of the stall background, but a jar on the shelf was only about 70 px wide. The shop card needs about 300 px and the info card about 600 px.

**Cause.** The whole stall is one 1296 px picture, so each item is only a tiny part of it.

**Solution.** Crop each item, enlarge the crop 4×, and have the image model *redraw exactly that object*, isolated and crisp. Then remove the background and trim. The items stay the same objects as in the scene, just sharp. The old per-item zoom settings (`shopScale`, `shopOffset`, the 2.2× on pantry badges) were deleted, because they only existed to make up for tiny items in huge canvases.

**Where.** `~/Dropbox/Mac/Desktop/ShopArt/items/` (crops, redraws, cutouts), `Assets.xcassets/FarmItems/`.

### 3. Pip's speech bubble covered the shop items

**Symptom.** In the new tappable shop, Pip's bubble sat beside him at shelf height and hid the items on the right.

**Cause.** `PipFloatingBubble` always places itself beside its anchor, which was Pip's position, and Pip stands in the middle of the shelves. The bubble also caught taps meant for the items under it.

**Solution.** Anchor the bubble to the open grass below the counter instead of to Pip, and give it `.allowsHitTesting(false)` so taps reach the items underneath.

**Where.** `FarmShopView.swift`, `shopMapSection` (`bubbleY`).

### 4. Recipe pictures looked too realistic next to the game's vegetables

**Symptom.** The recipe pictures were drawn like fine engravings, so the food looked far more realistic than the soft, round pencil vegetables in the garden.

**Cause.** The reference images were the Game Center icons and the older recipe drawings, which use dense engraving lines. Each new image copied that detail.

**Solution.** Use only the game's own vegetable drawings (a sheet of 8 from `Assets.xcassets/Vegetables`) as the style reference, and describe the dish in words. Passing the old drawing pulled the engraving back in. Smaller side vegetables were done as *edits* of the approved drawings ("keep everything, make only the vegetables half size"), so the dishes didn't change.

**Where.** `~/Dropbox/Mac/Desktop/RecipeArt/veggie_style/` (reference sheet, prompts in `jobs.txt`).

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
