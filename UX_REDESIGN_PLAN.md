# UX Redesign Plan: Pip's Kitchen Garden
## Based on UX Audit Report — March 2026

**Developer:** Marina Pollak
**Course:** PROG-360A Project Studio, Columbia College Chicago
**Deadline:** May 15, 2026
**Target Audience Shift:** Ages 8–12 → Ages 6+

---

## Executive Summary

The UX audit identified critical barriers preventing the app from reaching its younger (6+) target audience. The core issues fall into five categories: **literacy/text overload**, **color palette too muted**, **navigation redundancy**, **missing scroll/interaction cues**, and **lack of audio guidance**. This plan translates each audit finding into a specific, prioritized development task.

---

## Priority Tiers

| Tier | Label | Deadline | Description |
|------|-------|----------|-------------|
| **P0** | Critical | April 15 | Blocks usability for 6+ audience. Must ship. |
| **P1** | Important | May 1 | Significantly improves experience. Should ship. |
| **P2** | Nice-to-have | May 15 | Polish and differentiation. Ship if time allows. |
| **P3** | Post-launch | v1.1+ | Social features, companion app, advanced systems. |

---

## P0 — Critical (Ship by April 15)

### 1. Reduce Text Density — Voice + Icons

**Audit Finding:** "Even a 9-year-old would leave the whole thing if confronted with a full sentence."

**Changes:**
- [ ] Add `AVSpeechSynthesizer` text-to-speech for ALL instructions (Pip reads aloud)
- [ ] Add a speaker icon button on every text-heavy screen so kids can tap to hear
- [ ] Replace paragraph instructions with **icon + 1-3 words** wherever possible
- [ ] Enforce **4-step maximum** for any process (cooking, planting, shopping)
- [ ] Pip's dialogue: shorten to max 8 words per bubble
- [ ] Onboarding: reduce Meet Pip from 7 dialogue screens to 4

**Files to modify:**
- `MeetPipViews.swift` — shorten dialogues
- `FamilySetupView.swift` — simplify step text
- `CookingSessionView.swift` — add voice narration per step
- `RecipeDetailView.swift` — reduce text, add icons
- NEW: `PipVoice.swift` — AVSpeechSynthesizer wrapper

### 2. Brighten the Color Palette

**Audit Finding:** "Gray, adult, and sad." Buttons don't pop. Kids need vibrant CTAs.

**Changes:**
- [ ] Add **4 new vibrant accent colors** to AppTheme:
  - `brightGreen` (#4CAF50) — primary CTA (Cook, Plant, Buy)
  - `brightBlue` (#2196F3) — secondary CTA (Next, Continue)
  - `sunflowerYellow` (#FFD600) — rewards, stars, coins
  - `coralPink` (#FF6B6B) — alerts, important actions
- [ ] Update `PrimaryButtonStyle` — use `brightGreen` with white text, rounded, drop shadow
- [ ] Update `SecondaryButtonStyle` — use `brightBlue` with white text
- [ ] Keep paper/cream backgrounds (brand identity) but increase contrast of interactive elements
- [ ] Add **bold 2px borders** on all cards and interactive elements
- [ ] Star ratings: use `sunflowerYellow` instead of current muted gold

**Files to modify:**
- `AppTheme.swift` — add new colors, update button styles
- `PrimaryButtonStyle` / `SecondaryButtonStyle` — vibrant colors
- All views using `.foregroundColor(Color.AppTheme.sage)` on buttons → switch to bright accents

### 3. Scroll-Down Cues Everywhere

**Audit Finding:** "Character screen lacked visible scroll-down cues. Users unable to see options at the bottom."

**Changes:**
- [ ] Add a bouncing chevron (↓) at the bottom of any scrollable area
- [ ] Show "peek" of next item below the fold (half-visible card implies more content)
- [ ] FamilyAvatarStep: ensure outfit grid shows partial 3rd row to hint at scroll
- [ ] FarmShopView: show top edge of items below the fold
- [ ] RecipeListView: similar scroll hint

**Files to modify:**
- NEW: `ScrollHintView.swift` — reusable bouncing chevron component
- `FamilySetupView.swift` — avatar step scroll hints
- `FarmShopView.swift` — grid scroll hints
- `RecipeListView` — scroll hints

### 4. Make Pip Bigger and Interactive

**Audit Finding:** "If an item is important, it must be big and bold. Pip should be scaled up and made interactive."

**Changes:**
- [ ] Home screen: Pip size 120 → 180, with tap-to-bounce interaction
- [ ] All screens: Pip minimum size = 140pt
- [ ] Add "drag Pip" tutorial on first garden visit (animated hand shows drag gesture)
- [ ] Pip responds to tap anywhere: random encouraging phrase + bounce animation
- [ ] Pip's message bubbles: larger text (title3 → title2), higher contrast background

**Files to modify:**
- `PipWavingAnimatedView` — increase default size
- `ChefAcademyApp.swift` (HomeView) — bigger Pip
- `GardenView.swift` — first-visit drag tutorial overlay
- `PipMessageCard` — larger bubbles

### 5. Fix Typography Consistency

**Audit Finding:** "Lettuce font discrepancy. All screens must use unified, bold, child-friendly typeface."

**Changes:**
- [ ] Audit all `.font()` calls — ensure AppTheme fonts used everywhere
- [ ] Increase minimum body text size from 16pt to 18pt for 6+ readability
- [ ] All headings: bold weight, minimum 22pt
- [ ] All button text: bold, minimum 18pt
- [ ] Consider switching serif Georgia to a rounded sans-serif (SF Rounded) for younger audience

**Files to modify:**
- `AppTheme.swift` — update font scale, consider SF Rounded
- Global audit of all views

### 6. Fix Asset Masking — Remove Character Backgrounds

**Audit Finding:** "Characters have backgrounds that clash with scenes. Remove to allow natural integration."

**Changes:**
- [ ] Audit all Pip images — ensure transparent backgrounds (pip_neutral, pip_waving, etc.)
- [ ] Avatar card frames — ensure transparent bg on boy_card_frame_*, girl_card_frame_*
- [ ] Use `.renderingMode(.original)` where needed
- [ ] Profile cards: character should float on the card, not sit in a white box

**Files to modify:**
- Assets.xcassets — re-export character PNGs with transparent backgrounds
- `ProfilePickerView.swift` — update ProfileCard layout
- `AvatarPreviewView` — ensure clean compositing

---

## P1 — Important (Ship by May 1)

### 7. Condense Garden + Farm into Single Ecosystem

**Audit Finding:** "Structural redundancy between Garden and Farm/Farm Shop. Sending user everywhere dilutes core loop."

**Changes:**
- [ ] Merge Farm Shop INTO the Garden tab as a sub-section
- [ ] Garden tab layout: Garden Map (top) → Seed Bags → "Pip's Shop" section (bottom)
- [ ] Remove the standalone Farm tab from the tab bar
- [ ] Keep the farm walk animation as an optional "Visit the Farm" exploration from Garden
- [ ] Tab bar: Home | Garden | Kitchen | Recipes | Me (5 tabs instead of 6)

**Files to modify:**
- `ChefAcademyApp.swift` — remove Farm tab, update Tab enum
- `GardenView.swift` — add shop section at bottom
- `FarmShopView.swift` — refactor as embeddable component
- `FarmTabView.swift` / `FarmTransitionView.swift` — make optional/accessible from Garden

### 8. Kid-Friendly Recipe Names (Verb-Object Alignment)

**Audit Finding:** "Terms like 'Chicken Stir Fry' are abstract. Use verb-object alignment: 'The Mixing Bowl' or 'Sizzling Chicken'."

**Changes:**
- [ ] Rename all 17 recipes with kid-friendly names:
  - "Chicken Veggie Stir Fry" → "Sizzling Veggie Pan"
  - "Garden Salad" → "Rainbow Veggie Bowl"
  - "Veggie Wrap" → "The Rolling Wrap"
  - "Sunny Pancakes" → "Flippy Pancakes"
  - etc.
- [ ] Add `kidFriendlyName` field to Recipe struct (keep original as `title` for parents)
- [ ] All child-facing UI uses `kidFriendlyName`

**Files to modify:**
- `RecipeCardExample.swift` — add kidFriendlyName, rename all recipes
- `RecipeCardView`, `RecipeDetailView`, `RecipeListView` — use kidFriendlyName

### 9. Add Non-Binary Gender Option

**Audit Finding:** "Expand character builder to include non-binary option."

**Changes:**
- [ ] Add `Gender.nonBinary` case with dedicated avatar frames
- [ ] Generate/source non-binary character art (neutral presentation)
- [ ] Update avatar selection UI to show 3 options instead of 2
- [ ] All gender-specific text → gender-neutral alternatives

**Files to modify:**
- `AvatarModel.swift` — add .nonBinary case
- `FamilySetupView.swift` — 3-option gender selector
- `OnboardingView.swift` / `AvatarCreatorView.swift` — update selection UI
- Assets.xcassets — add nonbinary_card_frame_* assets

### 10. Pantry "Grab All" and Reduced Tapping

**Audit Finding:** "Tapping the same spot five times is repetitive friction. Allow 'grab all'."

**Changes:**
- [ ] Add quantity stepper (+/-) on FarmShopView items instead of single-tap-to-buy
- [ ] Add "Buy 5" bulk button on frequently purchased items
- [ ] Kitchen pantry: "Add All Available" button for recipe ingredients
- [ ] Show ingredient count badges on shop items

**Files to modify:**
- `FarmShopView.swift` — quantity stepper UI
- `KitchenView.swift` — "Add All" for recipe ingredients

### 11. Skippable Animations After First Viewing

**Audit Finding:** "Unskippable animations during frequent task-switching are a primary source of annoyance."

**Changes:**
- [ ] Track `hasSeenAnimation_<key>` in UserDefaults per animation
- [ ] Farm walk: already has tap-to-skip; ensure it auto-skips after 3rd viewing
- [ ] Meet Pip intro: mark as seen, skip on subsequent logins
- [ ] Cooking step transitions: reduce from 0.8s to 0.3s after first cook
- [ ] All explanation overlays: add "Got it!" dismiss button

**Files to modify:**
- `FarmTransitionView.swift` — auto-skip logic
- `CookingSessionView.swift` — faster transitions after first cook
- `MeetPipViews.swift` — skip for returning players

---

## P2 — Nice-to-Have (Ship by May 15)

### 12. Body/Organ Visualizer (Body Buddy)

**Audit Finding:** "Strongest value proposition. Centralize food-to-health mapping into an interactive body visualizer."

**Changes:**
- [ ] Build `BodyBuddyView` — cartoon body with tappable organs
- [ ] After cooking: animated food journey (mouth → stomach → organs light up)
- [ ] Each organ shows health meter + what foods help it
- [ ] Color-coded: green foods → brain, orange → eyes/skin, purple → brain memory, red → heart

**Files to create:**
- `BodyBuddyView.swift` — main interactive body view
- `FoodJourneyView.swift` — post-cooking animation
- `OrganDetailView.swift` — tap organ for info

### 13. Food Encyclopedia

**Audit Finding:** "A visual log of all discovered foods."

**Changes:**
- [ ] Track discovered vegetables and recipes in PlayerData
- [ ] New "Encyclopedia" section in Me/Profile tab
- [ ] Grid of veggie cards — greyed out until discovered, full color when found
- [ ] Tap for fun facts, nutrients, Pip's tips

**Files to modify:**
- `PlayerData.swift` — add discoveredVegetables array
- `ProfileView.swift` — add Encyclopedia section
- NEW: `EncyclopediaView.swift`

### 14. Recipe Gating by Garden Progress

**Audit Finding:** "Recipes should be gated by garden progress for sense of achievement."

**Changes:**
- [ ] Lock advanced recipes until player has harvested X vegetables
- [ ] Show locked recipes as silhouettes with "Grow 3 more carrots to unlock!"
- [ ] Tier 1 (unlocked): 5 simple recipes. Tier 2: harvest 10 veggies. Tier 3: harvest 25.

**Files to modify:**
- `RecipeCardExample.swift` — add unlock requirements
- `RecipeListView.swift` — show locked state
- `GameState.swift` — track total harvests

### 15. Bolder UI Borders and Card Styling

**Audit Finding:** "UI elements require bolder borders to stand out against paper texture."

**Changes:**
- [ ] Add 2pt stroke to all cards (warm brown, 0.4 opacity)
- [ ] Increase shadow depth on interactive cards
- [ ] Tab bar items: add subtle underline indicator for active tab
- [ ] Buttons: add 1.5pt border matching button color

**Files to modify:**
- `AppTheme.swift` — add card border style constants
- All card views — apply consistent border

---

## P3 — Post-Launch (v1.1+)

### 16. Social Features — Visit Friends' Farms
- Requires multiplayer networking (GameKit or Photon)
- View-only visits to friends' gardens
- Gift seeds to friends

### 17. Parent Companion Portal Improvements
- Push notification: "Your child learned about Protein today!"
- Weekly progress report view
- Screen time recommendations
- In-app purchase management

### 18. Expanded Character Builder
- More outfit options, hair styles, accessories
- Seasonal outfits (holiday aprons, summer hats)
- Earned cosmetics from achievements

---

## Implementation Order (Sprint Plan)

### Sprint 1: April 1–7 (Foundation)
| # | Task | Priority | Est. Hours |
|---|------|----------|------------|
| 1 | Add vibrant colors to AppTheme + update button styles | P0 | 3 |
| 2 | Create PipVoice.swift (AVSpeechSynthesizer) | P0 | 4 |
| 3 | Create ScrollHintView component | P0 | 2 |
| 4 | Fix asset masking (transparent PNGs) | P0 | 3 |
| 5 | Update font scale for 6+ readability | P0 | 2 |

### Sprint 2: April 8–14 (Core UX)
| # | Task | Priority | Est. Hours |
|---|------|----------|------------|
| 6 | Shorten all text / add voice to key screens | P0 | 6 |
| 7 | Make Pip bigger + interactive (tap to bounce) | P0 | 3 |
| 8 | Add scroll cues to avatar, shop, recipe views | P0 | 3 |
| 9 | Condense Garden + Farm tabs | P1 | 6 |
| 10 | Rename recipes (kid-friendly names) | P1 | 2 |

### Sprint 3: April 15–21 (Polish)
| # | Task | Priority | Est. Hours |
|---|------|----------|------------|
| 11 | Non-binary gender option | P1 | 4 |
| 12 | Pantry "grab all" + quantity stepper | P1 | 4 |
| 13 | Skippable animations | P1 | 3 |
| 14 | Bold borders + card styling | P2 | 2 |
| 15 | First-visit gesture tutorials | P1 | 4 |

### Sprint 4: April 22–May 1 (Features)
| # | Task | Priority | Est. Hours |
|---|------|----------|------------|
| 16 | Body Buddy / Organ Visualizer | P2 | 8 |
| 17 | Food Encyclopedia | P2 | 4 |
| 18 | Recipe gating by progress | P2 | 3 |

### Sprint 5: May 2–15 (Testing + Ship)
| # | Task | Priority | Est. Hours |
|---|------|----------|------------|
| 19 | User testing round 2 with 6-year-olds | — | 6 |
| 20 | Bug fixes from testing | — | 8 |
| 21 | App Store submission prep | — | 4 |
| 22 | Privacy policy + screenshots | — | 3 |

---

## Metrics to Validate Redesign

After implementing changes, re-test with 3-5 children (ages 6-9) and measure:

| Metric | Current Baseline | Target |
|--------|-----------------|--------|
| Onboarding completion (unaided) | Unknown | > 90% |
| First harvest (unaided) | Unknown | > 80% |
| First recipe cooked (unaided) | Unknown | > 70% |
| "Would play again" | Unknown | > 85% |
| Text complaints | "Too much text" | Zero |
| Navigation confusion | "Where do I go?" | Zero |

---

## Key Design Principles (Post-Audit)

1. **If they can't read it, they can't use it.** → Voice + icons first, text second.
2. **If they can't see it, it doesn't exist.** → Scroll cues, big buttons, bright colors.
3. **If it takes more than 4 steps, it's too long.** → Simplify every flow.
4. **If Pip isn't helping, he's in the way.** → Make Pip the interactive guide, not decoration.
5. **If the parent can't see the value, the app gets deleted.** → Parent dashboard with learning reports.

---

*Based on UX Audit Report for Little Chef Educational Cooking Application*
*Prepared for PROG-360A Project Studio, Columbia College Chicago*
*Marina Pollak — March 2026*
