# ASSETS.md — Full Asset Inventory & Needs

## Current Inventory: ~285 imagesets (ALL code references covered)

| Category | Count | Status |
|----------|-------|--------|
| AvatarCards (boy/girl frames) | 43 | Complete |
| Backgrounds (garden, farm, kitchen) | 7 | Complete |
| FarmItems/Pantry (farm_eggs, farm_salt, etc.) | 20 | Complete (19 used + 2 bonus: lamb, chili) |
| Vegetables (27 veggie images) | 27 | Complete |
| Recipes (17 recipe illustrations) | 17 | Complete |
| Pip (poses + walking + waving frames) | 27 | Complete |
| KitchenSink (125 frames + 15 anim) | 140 | Complete |
| Cooking (frying_pan, empty_plate, egg assets) | 4 | Complete |

---

## NEEDED: Plant Care Assets

These are needed for the watering, weeding, composting, and bug rescue features (Tasks #5-12).

### Watering (Task #5)
| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `watering_can.png` | Cute watering can, side view | Botanical watercolor | HIGH |
| `water_droplet_01.png` | Small water drop for particle effect | Simple, transparent | MEDIUM |
| `water_droplet_02.png` | Medium water drop variant | Simple, transparent | MEDIUM |
| `water_splash.png` | Splash effect when water hits soil | Watercolor splash | MEDIUM |

### Weeding (Task #7)
| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `weed_01.png` | Small dandelion-style weed | Botanical watercolor | HIGH |
| `weed_02.png` | Tall grass weed variant | Botanical watercolor | HIGH |
| `weed_03.png` | Clover-style weed variant | Botanical watercolor | MEDIUM |

### Bug Rescue (Task #9)
| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `ladybug.png` | Cute ladybug, top-down view | Botanical watercolor | HIGH |
| `aphid.png` | Small green/black aphid (the pest) | Botanical watercolor | HIGH |

### Composting (Task #8)
| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `compost_bin.png` | Garden compost bin, front view | Botanical watercolor | MEDIUM |
| `food_scraps.png` | Pile of veggie scraps/peels | Botanical watercolor | MEDIUM |
| `compost_ready.png` | Rich dark compost/soil | Botanical watercolor | LOW |

### Sunshade (Task #11)
| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `garden_parasol.png` | Small garden umbrella/shade | Botanical watercolor | LOW |

### Kid Avatar Caring (Task #12)
| Asset Name | Description | Style | Priority |
|-----------|-------------|-------|----------|
| `boy_watering_01-05.png` | Boy avatar holding watering can (5 frames) | Match avatar style | LOW |
| `girl_watering_01-05.png` | Girl avatar holding watering can (5 frames) | Match avatar style | LOW |
| `boy_weeding_01-03.png` | Boy avatar pulling weeds (3 frames) | Match avatar style | LOW |
| `girl_weeding_01-03.png` | Girl avatar pulling weeds (3 frames) | Match avatar style | LOW |

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

## NEEDED: Pip Voice Assets (ElevenLabs Pre-Recording)

These are audio files, not images. Generate on ElevenLabs with a cute character voice.

### Cooking Phrases (~20 clips)
| Phrase | When Used |
|--------|-----------|
| "Let's get cooking!" | CookingSession start |
| "Chop chop!" | ChopMiniGame |
| "Into the pan!" | AddToPanMiniGame |
| "Stir it up!" | StirMiniGame |
| "A pinch of seasoning!" | SeasonMiniGame |
| "Crack that egg!" | CrackEggMiniGame |
| "Hold it steady..." | HeatPanMiniGame |
| "Smells amazing!" | CookTimerMiniGame |
| "Beautiful! Plate it up!" | AssembleMiniGame |
| "Perfect chef!" | 3 stars |
| "Great job!" | 2 stars |
| "Good try!" | 1 star |
| "Nice work!" | Between steps |
| "Keep going!" | Between steps |
| "You're a natural!" | Between steps |
| "Almost there!" | Between steps |
| "Yummy!" | Between steps |

### Garden Phrases (~15 clips)
| Phrase | When Used |
|--------|-----------|
| "Water time!" | needsWater state |
| "Pull those weeds!" | needsWeeding state |
| "Ladybugs to the rescue!" | hasBugs state |
| "Look, it's growing!" | 50% growth |
| "Ready to harvest!" | ready state |
| "Let's plant a seed!" | Empty plot tap |
| "Your garden looks amazing!" | Random gardening tip |
| "Sunshine helps plants grow!" | Sunny weather |
| "Rain is watering your garden!" | Rain event |

### General Phrases (~10 clips)
| Phrase | When Used |
|--------|-----------|
| "Hello there, little chef!" | App launch / profile select |
| "Welcome back!" | Returning player |
| "What should we do today?" | HomeView |
| "Time to cook!" | Kitchen tab |
| "Let's check your garden!" | Garden tab |
| "Tap to learn!" | Knowledge cards |

---

## ASSET GENERATION TIPS

### For Procreate (Images)
- Export as **PNG with transparency**
- Canvas size: **1024x1024** (scales down well for all devices)
- Style: botanical watercolor, warm tones, hand-drawn feel
- No harsh outlines — soft, organic edges
- Match the warm cream/sepia/sage palette

### For ElevenLabs (Voice)
- Character: young, enthusiastic, slightly high-pitched
- Tone: encouraging, warm, excited about food
- Length: 1-3 seconds per clip (short and punchy)
- Format: .m4a or .mp3 (iOS supports both)
- Free tier: ~10,000 characters/month (~100 short phrases)

---

## BONUS: Unused Assets in FarmItems
- `farm_lamb.imageset` — not in PantryItem enum (could add lamb recipes later)
- `farm_chili.imageset` — not in PantryItem enum (could add spicy recipes later)

---

*Last Updated: March 15, 2026*
