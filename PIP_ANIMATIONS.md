# Pip Animation & Pose Guide

Complete list of every Pip pose and animation needed — what exists, what's missing, and where each is used.

---

## EXISTING ASSETS (Have These)

### Static Poses (6)

| Asset Name | Pose | Where Used |
|-----------|------|-----------|
| `pip_neutral` | Standing, relaxed, ready | Default state, Garden idle, Ask Pip, game lobbies, PIN entry |
| `pip_waving` | One arm up waving | Static fallback for waving animation |
| `pip_cooking` | Holding a spoon/utensil | Kitchen map, cooking steps, Glucose Journey fiber/quiz phases |
| `pip_thinking` | Hand on chin, looking up | Quiz questions, loading, PIN entry, Glucose Journey slow lane |
| `pip_excited` | Arms up, big smile | Positive feedback, recipe ready, Glucose Journey mitochondria |
| `pip_celebrating` | Both arms up, jumping | Badge earned, recipe complete, 3 stars, Glucose Journey peek |

### Frame Animations (2)

| Animation | Frames | FPS | Where Used |
|-----------|--------|-----|-----------|
| `pip_waving_frame_01–15` | 15 frames | 6fps + 3s pause | Home screen, Farm Shop, Kitchen message, everywhere via `PipWavingAnimatedView` |
| `pip_walking_frame_01–15` | 15 frames | 8fps (every 4 ticks at 30fps timer) | Garden walk between plots, Farm transition walk to barn |

---

## NEEDED POSES — Static (New Single Images)

### Core Poses (High Priority)

| Asset Name | Description | Where It Would Be Used | Priority |
|-----------|-------------|----------------------|----------|
| `pip_sleeping` | Curled up, eyes closed, Zzz | Night greeting on Home ("Good night!"), idle timeout, play time limit reached | HIGH |
| `pip_sad` | Slightly droopy, empathetic face | Wrong quiz answer (gentle), plant died/wilted, out of coins | HIGH |
| `pip_pointing_right` | One arm pointing right | "Tap here!", navigate to next screen, "Go to Kitchen!" | HIGH |
| `pip_pointing_up` | One arm pointing up | "Look at this!", speech bubble reference, scroll up hint, showing a message | HIGH |
| `pip_pointing_down` | One arm pointing down | Scroll down cue, "Check this out below!", garden plot prompt | MEDIUM |
| `pip_eating` | Holding food, mouth open/chewing | Post-cooking celebration, Body Buddy food journey, tasting step | HIGH |
| `pip_gardening` | Holding watering can or seed | Garden tab header, planting prompts, care instructions | HIGH |
| `pip_surprised` | Wide eyes, mouth open | Glucose spike comparison peek, finding bugs on plants, new discovery | HIGH |
| `pip_stirring` | Holding spoon in pot, focused | Kitchen scene, StirMiniGame, between cooking steps | HIGH |
| `pip_chopping` | Holding knife over cutting board | ChopMiniGame, prep step instructions | HIGH |
| `pip_grabbing` | Reaching forward with one arm | Pantry→counter ingredient flow, shop purchases, picking veggies | HIGH |
| `pip_presenting` | Holding a plate out proudly, big smile | Cooking completion, AssembleMiniGame finish, recipe card hero | HIGH |
| `pip_tasting` | Eyes closed, spoon to mouth, satisfied | After cooking, flavor approval moment, recipe review | MEDIUM |

### Emotion Poses (Medium Priority)

| Asset Name | Description | Where It Would Be Used | Priority |
|-----------|-------------|----------------------|----------|
| `pip_proud` | Chest puffed out, confident smile | Badge earned, "Glucose Expert" achievement, mastery moments | MEDIUM |
| `pip_confused` | Head tilted, question mark vibe | When kid is stuck, no ingredients available, empty states | MEDIUM |
| `pip_cheering` | Waving a small flag or pom-pom | Multiplayer encouragement, sibling garden visit, high score | MEDIUM |
| `pip_reading` | Holding a tiny book | Seed Info pages, recipe detail view, fun facts, Body Quiz | MEDIUM |
| `pip_love` | Heart eyes or holding a heart | Sibling likes, favorite recipe, "Pip loves your garden!" | MEDIUM |

### Activity Poses (For Future Features)

| Asset Name | Description | Where It Would Be Used | Priority |
|-----------|-------------|----------------------|----------|
| `pip_singing` | Mouth open, music notes implied | Sing-to-plant feature (5% growth boost), garden music moment | LOW |
| `pip_digging` | Holding a small shovel | Composting feature, planting animation | LOW |
| `pip_holding_basket` | Carrying a veggie basket | Harvest celebration, going to market/shop | LOW |
| `pip_sweating` | Wiping brow, effort face | Hard difficulty recipes, hot weather in garden | LOW |
| `pip_scientist` | Tiny lab coat, holding test tube | Glucose Journey science phases, Body Buddy deep dives | LOW |

---

## NEEDED ANIMATIONS — Frame Sequences (New)

### High Priority Animations

| Animation | Frames Needed | FPS | Description | Where Used |
|-----------|--------------|-----|-------------|-----------|
| `pip_walking_carry_frame_01–15` | 15 frames | 8fps | Walking while carrying a basket of veggies | After harvest in garden, walking to kitchen with ingredients |
| `pip_walking_plate_frame_01–15` | 15 frames | 8fps | Walking while carrying a finished plate | Stove→table after cooking, presenting finished dish |
| `pip_stirring_frame_01–10` | 10 frames | 6fps | Stirring a pot — circular arm motion | StirMiniGame background, kitchen cooking scene |
| `pip_chopping_frame_01–08` | 8 frames | 10fps | Arm goes up and down with knife | ChopMiniGame background, prep step |
| `pip_eating_frame_01–10` | 10 frames | 8fps | Takes a bite, chews, smiles | Glucose Journey food-enters-stomach phase, cooking completion |
| `pip_clapping_frame_01–08` | 8 frames | 10fps | Claps hands together | Smart Snack correct answer, recipe 3-star, badge earned |
| `pip_watering_frame_01–08` | 8 frames | 8fps | Tips a watering can, water pours | Plant care watering interaction, garden tutorial |
| `pip_grabbing_frame_01–06` | 6 frames | 10fps | Reaches out, grabs, pulls back | Kitchen pantry→counter ingredient grab, shop buy animation |

### Medium Priority Animations

| Animation | Frames Needed | FPS | Description | Where Used |
|-----------|--------------|-----|-------------|-----------|
| `pip_jumping_frame_01–06` | 6 frames | 12fps | Jumps up and lands | Level up, big reward moment, first harvest |
| `pip_dancing_frame_01–10` | 10 frames | 8fps | Does a little happy dance | Recipe completion, multiplayer win, streak milestone |
| `pip_peeking_frame_01–06` | 6 frames | 8fps | Peeks from behind something, shy | First app launch, returning after long absence, surprise reveal |
| `pip_presenting_frame_01–06` | 6 frames | 8fps | Lifts plate up proudly, holds it out | Cooking completion final pose, recipe card hero |

### Low Priority Animations

| Animation | Frames Needed | FPS | Description | Where Used |
|-----------|--------------|-----|-------------|-----------|
| `pip_sleeping_frame_01–06` | 6 frames | 3fps | Breathing while sleeping, Zzz float up | Night mode idle, play time limit |
| `pip_running_frame_01–10` | 10 frames | 15fps | Faster than walking, arms pumping | Timer-based mini-games, "hurry!" moments |
| `pip_tasting_frame_01–06` | 6 frames | 6fps | Spoon to mouth, chews, eyes close in bliss | After cooking, flavor approval moment |

---

## ANIMATION STYLE GUIDE

### General Rules
- **Canvas size**: 1024x1024 PNG with transparency
- **Style**: Botanical watercolor, soft edges, warm tones
- **Pip's proportions**: Round body, small legs, chef hat always on, big expressive eyes
- **Chef hat**: Always present in every pose (it's his identity)
- **Transparency**: PNG with NO background — Pip floats on any screen color
- **Hedgehog spines**: Visible from behind/side poses, soft and rounded (not sharp)

### Expression Guide
| Emotion | Eyes | Mouth | Body Language |
|---------|------|-------|---------------|
| Neutral | Normal, relaxed | Slight smile | Standing upright |
| Excited | Wide open, sparkly | Big grin | Leaning forward, arms up |
| Thinking | Looking up/sideways | Slight pout | Hand on chin |
| Cooking | Focused, determined | Slight smile | Holding utensil, leaning over |
| Celebrating | Closed (joy) or wide | Open-mouth grin | Both arms up, slight jump |
| Sad | Droopy, half-closed | Small frown | Shoulders down, head tilted |
| Surprised | Very wide, round | O-shape | Leaning back slightly |
| Sleeping | Closed, peaceful | Relaxed | Curled up, Zzz above |
| Proud | Confident, warm | Satisfied smile | Chest out, hands on hips |

### Frame Animation Tips
- First frame = starting pose, last frame = ending pose (for looping, last should flow back to first)
- Walking: arms and legs alternate, hat bounces slightly
- Waving: arm goes up → peak → down, body sways slightly
- Keep consistent line weight across all frames (~3px at 1024px canvas)
- Export at 1x scale — iOS handles @2x/@3x via asset catalog

---

## ASSET NAMING CONVENTION

| Type | Pattern | Example |
|------|---------|---------|
| Static pose | `pip_{emotion}` | `pip_sleeping` |
| Animation frame | `pip_{action}_frame_{##}` | `pip_eating_frame_01` |
| Number padding | Always 2 digits | `01`, `02`, ... `15` |

---

## TOTAL COUNT

| Category | Existing | Needed | Total |
|----------|---------|--------|-------|
| Static poses | 6 | 16 | 22 |
| Waving frames | 15 | 0 | 15 |
| Walking frames | 15 | 0 | 15 |
| New animation frames | 0 | 140 | 140 |
| **TOTAL** | **36** | **156** | **192** |

### Recommended Drawing Order

**Round 1 — Kitchen Actions (most visible, used in cooking flow):**
1. `pip_stirring` — static pose, core kitchen identity
2. `pip_chopping` — static pose, ChopMiniGame
3. `pip_grabbing` — static pose, ingredient flow
4. `pip_presenting` — static pose, finished dish moment
5. `pip_tasting` — static pose, after cooking

**Round 2 — Walking Variants (bring the game world to life):**
6. `pip_walking_carry_frame_01–15` — walking with veggie basket (harvest → kitchen)
7. `pip_walking_plate_frame_01–15` — walking with finished plate (stove → done)

**Round 3 — Emotions (make Pip feel alive):**
8. `pip_sleeping` — single pose, Home night greeting
9. `pip_sad` — single pose, gentle wrong answers
10. `pip_surprised` — single pose, glucose spike peek
11. `pip_pointing` — single pose, tutorials
12. `pip_proud` — single pose, badge earned

**Round 4 — Core Action Animations (the wow factor):**
13. `pip_stirring_frame_01–10` — animated stirring for mini-game
14. `pip_chopping_frame_01–08` — animated chopping for mini-game
15. `pip_eating_frame_01–10` — Glucose Journey food phase
16. `pip_clapping_frame_01–08` — quiz correct answer celebration
17. `pip_grabbing_frame_01–06` — kitchen ingredient grab
18. `pip_watering_frame_01–08` — plant care

**Round 5 — Garden & Polish:**
19. `pip_gardening` — static, garden tab
20. `pip_eating` — static, Body Buddy
21. `pip_jumping_frame_01–06` — level up moment
22. `pip_dancing_frame_01–10` — recipe completion dance

---

## AVATAR ANIMATIONS (Boy & Girl Characters)

The kid's avatar (boy chef / girl chef) currently only has outfit selection frames (`boy_card_frame_01–28`, `girl_card_frame_01–15`). For the game to feel alive, the avatar needs action animations too — especially for garden care and cooking.

### Naming Convention
- Boy: `boy_{action}_frame_{##}.png`
- Girl: `girl_{action}_frame_{##}.png`
- Both genders need every animation (same frame count, same timing)

### High Priority — Garden Care

| Animation | Frames | FPS | Description | Where Used |
|-----------|--------|-----|-------------|-----------|
| `boy/girl_watering_frame_01–08` | 8 per gender | 8fps | Kid holds watering can, tilts it, water pours onto plant | Plant care: `.needsWater` state → kid taps plot → watering animation plays |
| `boy/girl_weeding_frame_01–08` | 8 per gender | 8fps | Kid bends down, grabs weed, pulls it out with a tug | Plant care: `.needsWeeding` state → kid swipes plot → weeding animation |
| `boy/girl_bug_rescue_frame_01–08` | 8 per gender | 8fps | Kid spots bug, gently picks it up, places ladybug down | Plant care: `.hasBugs` state → kid taps bugs → rescue animation |
| `boy/girl_planting_frame_01–06` | 6 per gender | 8fps | Kid digs small hole, drops seed in, pats soil | Planting sheet → seed selected → planting animation on plot |
| `boy/girl_harvesting_frame_01–08` | 8 per gender | 8fps | Kid reaches down, pulls veggie out of ground, holds it up proudly | Plot ready → harvest tap → avatar pulls veggie + celebration |

### High Priority — Kitchen

| Animation | Frames | FPS | Description | Where Used |
|-----------|--------|-----|-------------|-----------|
| `boy/girl_stirring_frame_01–08` | 8 per gender | 6fps | Kid stirs a pot with a wooden spoon, circular motion | StirMiniGame background, kitchen cooking scene |
| `boy/girl_chopping_frame_01–06` | 6 per gender | 10fps | Kid chops on cutting board, careful knife motion | ChopMiniGame background |
| `boy/girl_tasting_frame_01–06` | 6 per gender | 6fps | Kid lifts spoon to mouth, tastes, big smile | After cooking completion, recipe preview |
| `boy/girl_presenting_frame_01–06` | 6 per gender | 8fps | Kid holds plate up proudly, showing finished dish | Cooking completion screen, recipe card hero |

### Medium Priority — Emotions & Reactions

| Animation | Frames | FPS | Description | Where Used |
|-----------|--------|-----|-------------|-----------|
| `boy/girl_celebrating_frame_01–08` | 8 per gender | 10fps | Kid jumps up, arms raised, confetti vibe | 3-star cooking, badge earned, level up |
| `boy/girl_thinking_frame_01–04` | 4 per gender | 4fps | Kid tilts head, hand on chin, looks up | Quiz questions, recipe selection, "what should I cook?" |
| `boy/girl_waving_frame_01–06` | 6 per gender | 6fps | Kid waves hello/goodbye | Home screen greeting, sibling visit, profile picker |
| `boy/girl_singing_frame_01–06` | 6 per gender | 6fps | Kid opens mouth, music notes implied, swaying | Sing-to-plant feature (5% growth boost) |

### Low Priority — Special Actions

| Animation | Frames | FPS | Description | Where Used |
|-----------|--------|-----|-------------|-----------|
| `boy/girl_sleeping_frame_01–04` | 4 per gender | 3fps | Kid curled up or head on table, Zzz | Night time greeting, play time limit reached |
| `boy/girl_eating_frame_01–08` | 8 per gender | 8fps | Kid takes bite, chews, happy expression | Glucose Journey food phase, post-cooking |
| `boy/girl_walking_frame_01–10` | 10 per gender | 8fps | Kid walks (side view) | Farm transition, moving between scenes |
| `boy/girl_dancing_frame_01–08` | 8 per gender | 8fps | Kid does happy dance | Multiplayer win, streak celebration |
| `boy/girl_composting_frame_01–06` | 6 per gender | 8fps | Kid dumps scraps into compost bin | Composting feature (future) |

### Head Covering Variants

For kids with hijab, kippah, or turban, the head covering must be visible and consistent in ALL avatar animations. This means:
- Each animation needs a base version (no covering)
- Head covering is either drawn as a separate overlay layer or baked into variant sets
- **Recommended approach**: Draw base animation → overlay head covering as a separate layer in Procreate → export both versions

| Covering | Variant Suffix | Example |
|----------|---------------|---------|
| None | (default) | `girl_watering_frame_01.png` |
| Hijab | `_hijab` | `girl_watering_hijab_frame_01.png` |
| Kippah | `_kippah` | `boy_watering_kippah_frame_01.png` |
| Turban | `_turban` | `boy_watering_turban_frame_01.png` |

**Simplification**: For the first pass, draw without head covering. Head coverings can be added as a second pass or as overlays. The app currently uses the last card frame (static image) for the avatar — head coverings aren't animated yet.

### Avatar Animation Summary

| Category | Animations | Frames per Gender | Total Frames (both genders) |
|----------|-----------|-------------------|----------------------------|
| Garden Care | 5 (water, weed, bug, plant, harvest) | 38 | 76 |
| Kitchen | 4 (stir, chop, taste, present) | 26 | 52 |
| Emotions | 4 (celebrate, think, wave, sing) | 24 | 48 |
| Special | 5 (sleep, eat, walk, dance, compost) | 36 | 72 |
| **TOTAL** | **18** | **124** | **248** |

### Drawing Tips for Avatar Animations
- Keep the same body proportions across all frames (trace the base pose)
- Chef hat always on (it's their uniform, like Pip's hat)
- Outfit color must match the selected outfit (apronRed, chefWhite, etc.) — draw in one neutral color, then recolor in code using `.colorMultiply()` or draw separate sets for each outfit
- **Simplest approach for now**: Draw one boy + one girl version in their default outfit. The app currently shows the last card frame everywhere anyway. Outfit variants can come later.
- Expression matters more than body detail at small sizes — focus on face/eyes/mouth

### Recommended Drawing Order for Avatars

**Start with garden care** — these are the most immediately needed (plant care system exists but has no avatar animations):

1. `boy/girl_watering_frame_01–08` — watering can interaction
2. `boy/girl_weeding_frame_01–08` — pulling weeds
3. `boy/girl_harvesting_frame_01–08` — pulling veggie from ground
4. `boy/girl_planting_frame_01–06` — dropping seed in soil
5. `boy/girl_bug_rescue_frame_01–08` — ladybug rescue

**Then kitchen**:

6. `boy/girl_stirring_frame_01–08` — pot stirring
7. `boy/girl_chopping_frame_01–06` — cutting board
8. `boy/girl_celebrating_frame_01–08` — the payoff moment

---

*For Pip's Kitchen Garden — March 2026*
*Style: Botanical watercolor, transparent PNG, 1024x1024*
