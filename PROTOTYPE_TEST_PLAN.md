# Pip's Kitchen Garden — Prototype Test Plan

**Version:** 1.0 (March 2026)
**Developer:** Marina Pollak
**Course:** PROG-360A Project Studio, Columbia College Chicago
**Target Audience:** Children ages 9–12

---

## 1. Prototype Overview

**Pip's Kitchen Garden** is an iOS educational cooking game where kids grow vegetables, cook recipes through interactive mini-games, and learn about nutrition — all guided by Pip, a friendly hedgehog chef.

### Core Game Loop

```
🌱 GROW (Garden)  →  🍳 COOK (Kitchen)  →  🫀 FEED (Body Buddy*)  →  🏆 REWARDS
    Plant seeds         Select recipe         See food impact           Coins, XP,
    Water crops         Play mini-games       on your body              Stars, Badges
    Harvest veggies     Earn star rating      (coming soon)
```

*Body Buddy is not yet implemented in this prototype.

### What IS Testable

| Feature | Status | Tab |
|---------|--------|-----|
| Onboarding & Avatar Creation | Complete | First launch |
| Meet Pip Introduction | Complete | First launch |
| Home Dashboard | Complete | Home |
| Garden — Plant, Water, Harvest | Complete | Garden |
| Kitchen — Recipe Selection & Cooking | Complete | Kitchen |
| Farm Shop — Browse & Buy Pantry Items | Complete | Farm |
| Recipe Browser — View All 17 Recipes | Complete | Recipes |
| Recipe Detail — Full Cookbook Page | Complete | Recipes |
| Cooking Mini-Games (9 types) | Complete | Kitchen |
| Seed Info — Educational Veggie Pages | Complete | Garden |
| PencilKit Coloring on Vegetables | Complete | Garden |
| Coin Economy (earn & spend) | Complete | All |

### What is NOT Testable Yet

| Feature | Status |
|---------|--------|
| Body Buddy (post-cooking nutrition journey) | Not started |
| Quest System UI | Not started |
| Badges / Achievements Gallery | Not started |
| Profile / "Me" Tab | Placeholder only |
| 19 of 27 vegetable images | Missing assets (placeholders may appear) |

---

## 2. Test Environment Setup

### Requirements
- **Device:** iPhone or iPad running iOS 16.0+
- **Recommended Simulator:** iPhone 17 Pro (Xcode)
- **Build:** Run via Xcode — `ChefAcademy.xcodeproj`

### Build & Run
```bash
# Via command line
xcodebuild -scheme ChefAcademy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Or open in Xcode and press Cmd+R
open ChefAcademy.xcodeproj
```

### Fresh Start (Reset All Data)
To give each tester a clean experience, delete the app from the simulator/device before each session. This clears SwiftData persistence and UserDefaults (onboarding state, avatar).

---

## 3. Test Scenarios

Each scenario describes a task for the tester. The **facilitator** reads the task aloud; the **observer** watches and takes notes.

---

### Scenario 1: First Launch & Onboarding
**Goal:** Can the child set up their character and understand the game?

**Task:** "You're opening Pip's Kitchen Garden for the first time. Create your character and meet Pip."

| Step | Expected Behavior | Observe |
|------|-------------------|---------|
| App launches | Onboarding screen appears | Does the child understand what to do? |
| Gender selection | Boy/girl card animation plays | Is the selection intuitive? |
| Avatar customization | Outfit + Head Covering tabs | Does the child explore both tabs? |
| Name entry | Keyboard appears | Any confusion? |
| Meet Pip | Pip introduces himself with dialogue | Does the child read Pip's messages? |
| Complete | Lands on Home tab | Does the child feel welcomed? |

**Key Questions:**
- Did they understand each onboarding step without help?
- Did they enjoy the avatar customization?
- Did they read or skip Pip's introduction?

---

### Scenario 2: Explore the Home Screen
**Goal:** Can the child understand the dashboard and navigate to other tabs?

**Task:** "Look around your home screen. What can you see? Where would you go first?"

| Element | What to Observe |
|---------|-----------------|
| Greeting + Avatar | Do they recognize their character? |
| Coins / XP / Level chips | Do they understand what these are? |
| Streak card | Do they notice it? |
| Pip's message | Do they read it? |
| Quick action cards | Do they tap one? Which one? |
| Today's Recipe | Do they tap it? |
| Tab bar (bottom) | Do they discover other tabs naturally? |

**Key Questions:**
- What drew their attention first?
- Did they feel overwhelmed or curious?
- Could they find the Garden / Kitchen on their own?

---

### Scenario 3: Plant & Grow a Vegetable
**Goal:** Can the child successfully plant, water, and harvest?

**Task:** "Go to the Garden and grow a vegetable!"

| Step | Action | Expected | Observe |
|------|--------|----------|---------|
| 1 | Navigate to Garden tab | Garden map appears with empty plots | Can they find the tab? |
| 2 | Tap an empty plot | Planting sheet slides up with seed options | Is the tap target easy to find? |
| 3 | Select a seed | Seed planted, plot shows growth | Do they understand seed selection? |
| 4 | Swipe on the plot | Watering animation | Do they discover the swipe gesture? |
| 5 | Wait / check back | Plot reaches "Ready" state (golden glow) | Do they understand the wait? |
| 6 | Drag Pip over the plot | Harvest animation, coins earned | Can they figure out the drag mechanic? |
| 7 | Check harvest basket | Veggie appears in basket | Do they notice the basket? |

**Key Questions:**
- Did they discover watering (swipe) without prompting?
- Was dragging Pip to harvest intuitive or confusing?
- Did they understand the growth timing?

---

### Scenario 4: Learn About a Vegetable (Seed Info)
**Goal:** Can the child access and engage with educational content?

**Task:** "Tap on a seed bag to learn about a vegetable. Try coloring!"

| Step | Action | Expected | Observe |
|------|--------|----------|---------|
| 1 | Find seed bags in Garden | Seed badge row visible | Can they find seed bags? |
| 2 | Tap a seed bag | SeedInfoView opens (full-screen) | Is the tap target clear? |
| 3 | Read info | Veggie image, name, fun facts, nutrients | Do they read or skim? |
| 4 | Find coloring tool | Paintbrush button visible | Can they find it? |
| 5 | Draw on veggie | PencilKit canvas active | Do they enjoy drawing? |
| 6 | Change colors | PKToolPicker appears | Do they explore colors? |
| 7 | Pip reacts | Pip gives nutrition tip per color | Do they notice Pip's tips? |

**Key Questions:**
- Which facts interested them most?
- Did they engage with the coloring feature?
- Did they connect colors to nutrients (Pip's tips)?

---

### Scenario 5: Buy Pantry Items at the Farm Shop
**Goal:** Can the child navigate the shop and make purchases?

**Task:** "Go to the Farm and buy some ingredients you'll need for cooking."

| Step | Action | Expected | Observe |
|------|--------|----------|---------|
| 1 | Navigate to Farm tab | Pip walks toward barn (transition) | Do they watch or tap to skip? |
| 2 | Arrive at shop | FarmShopView with item grid | Is the layout clear? |
| 3 | Browse categories | Filter pills at top | Do they use category filters? |
| 4 | Check prices | Coin costs shown per item | Do they check if they can afford items? |
| 5 | Tap to buy | Purchase confirmation | Do they understand the purchase? |
| 6 | Check "My Pantry" | Purchased items appear in inventory | Do they scroll down to see pantry? |

**Key Questions:**
- Did they understand the coin economy?
- Did they make strategic purchases or random ones?
- Was the shop layout easy to navigate?

---

### Scenario 6: Browse & Select a Recipe
**Goal:** Can the child find a recipe and understand its requirements?

**Task:** "Look at the recipe book and find something you'd like to cook."

| Step | Action | Expected | Observe |
|------|--------|----------|---------|
| 1 | Navigate to Recipes tab | Recipe list with category tabs | Can they find the tab? |
| 2 | Browse categories | All / Breakfast / Lunch / Dinner / Snacks | Do they filter by category? |
| 3 | Tap a recipe card | RecipeDetailView opens (full-screen cookbook) | Is the transition smooth? |
| 4 | Read recipe details | Image, tip, ingredients, steps, nutrition | What do they focus on? |
| 5 | Check ingredient availability | Garden + Pantry ingredient status | Do they understand what they need? |
| 6 | Tap "Let's Cook!" | Navigates to Kitchen | Is the button prominent? |

**Key Questions:**
- How did they choose a recipe (difficulty, picture, name)?
- Did they read Pip's glucose tip?
- Did they check if they had ingredients?

---

### Scenario 7: Cook a Full Recipe (Mini-Games)
**Goal:** Can the child complete a cooking session through all mini-game steps?

**Task:** "Time to cook! Follow each step to make your recipe."

| Mini-Game | Gesture | Observe |
|-----------|---------|---------|
| Heat Pan | Hold finger on pan | Is the hold mechanic clear? |
| Add to Pan | Drag ingredient into pan | Is drag intuitive? |
| Wash | Tap rapidly | Do they understand rapid tapping? |
| Peel | Swipe down | Is the swipe direction clear? |
| Chop | Tap timing | Can they time the chops? |
| Stir | Circular swipe | Do they discover the circular motion? |
| Season | Tap to sprinkle | Is it satisfying? |
| Cook Timer | Hit green zone | Do they understand the timing? |
| Assemble | Tap to plate | Clear finishing step? |

| After Cooking | Expected | Observe |
|---------------|----------|---------|
| Completion screen | Star rating (1-3 stars) | Reaction to their score? |
| Rewards | Coins + XP earned | Do they feel rewarded? |
| Pip celebrates | Encouraging message | Does it motivate replay? |

**Key Questions:**
- Which mini-games were most fun? Most confusing?
- Did Pip's encouragement between steps help?
- Did they want to cook again for a higher score?

---

### Scenario 8: Full Game Loop (Combined)
**Goal:** Can the child complete the GROW → COOK cycle independently?

**Task:** "Your goal is to grow a vegetable, buy ingredients from the shop, then cook a recipe. You can do it in any order!"

**Observe:**
- What order do they choose (Garden → Shop → Kitchen? Or something else?)
- Do they get stuck at any point?
- How long does the full loop take?
- Do they feel a sense of accomplishment at the end?

---

## 4. Observation Checklist

Use this during each test session. Mark Y/N/Partial and add notes.

### Navigation & Understanding

| # | Observation | Y/N | Notes |
|---|-------------|-----|-------|
| 1 | Found all tabs without help | | |
| 2 | Understood what each tab does | | |
| 3 | Used the back/close buttons correctly | | |
| 4 | Read Pip's messages and tips | | |
| 5 | Understood the coin system | | |

### Engagement

| # | Observation | Y/N | Notes |
|---|-------------|-----|-------|
| 6 | Smiled or laughed during play | | |
| 7 | Wanted to keep playing after task | | |
| 8 | Asked to try more recipes | | |
| 9 | Expressed interest in growing veggies | | |
| 10 | Engaged with educational content | | |

### Gestures & Interactions

| # | Observation | Y/N | Notes |
|---|-------------|-----|-------|
| 11 | Tap targets easy to hit | | |
| 12 | Swipe gestures discovered naturally | | |
| 13 | Drag-and-drop worked smoothly | | |
| 14 | Mini-game instructions clear | | |
| 15 | No accidental navigation or actions | | |

### Frustration Points

| # | Observation | Y/N | Notes |
|---|-------------|-----|-------|
| 16 | Got stuck on a screen | | |
| 17 | Didn't understand what to do next | | |
| 18 | Repeated the same wrong action | | |
| 19 | Asked for help (what? when?) | | |
| 20 | Expressed frustration or confusion | | |

---

## 5. Post-Test Interview Questions

Ask these after the child finishes playing. Keep it conversational.

### For the Child (ages 9–12)

1. **Fun:** What was the most fun part? What was the least fun?
2. **Favorite:** Which mini-game did you like the most? Why?
3. **Confusing:** Was anything confusing or hard to figure out?
4. **Pip:** What do you think about Pip? Did Pip's tips help you?
5. **Learning:** Did you learn anything new about vegetables or cooking?
6. **Again:** Would you want to play this again? What would you do next?
7. **Wish:** If you could add one thing to this game, what would it be?
8. **Hard:** Was anything too easy or too hard?
9. **Cooking IRL:** Does this game make you want to cook real food?

### For the Parent/Guardian (if present)

1. Does the content feel age-appropriate for your child?
2. Do you see educational value in the game?
3. Would you feel comfortable with your child playing this independently?
4. Any concerns about the nutrition information presented?
5. Would dietary/cultural options (halal, kosher) be useful for your family?

---

## 6. Known Issues & Limitations

Inform testers about these before or during the session:

| Issue | Impact | Workaround |
|-------|--------|------------|
| 19 missing vegetable images | Some veggies show placeholder or no image | Focus testing on original 8 veggies (lettuce, carrot, tomato, cucumber, broccoli, zucchini, onion, pumpkin) |
| Mini-games use emoji art | Visual polish incomplete — emoji instead of watercolor illustrations | Explain these are placeholder graphics |
| Body Buddy not built | Game loop ends after cooking completion | Tell tester: "In the full version, you'd see how the food helps your body!" |
| Profile/Me tab is placeholder | Tapping shows "coming soon" | Skip this tab during testing |
| Growth timing | Veggies may grow instantly or too fast in test builds | Acceptable for testing — note if it confuses testers |
| Some recipe images missing | Not all 17 recipes have hero images | Focus on recipes that have images |

---

## 7. Test Session Template

### Before the Session
- [ ] Delete app from device (fresh install)
- [ ] Prepare observation checklist (print or digital)
- [ ] Confirm device is charged
- [ ] Get parental consent if testing with minors
- [ ] Set up screen recording (optional, with consent)

### Session Structure (30–40 minutes)

| Time | Activity |
|------|----------|
| 0–3 min | Welcome, explain: "We're testing the game, not you. There are no wrong answers." |
| 3–5 min | **Scenario 1:** Onboarding & Avatar |
| 5–8 min | **Scenario 2:** Explore Home |
| 8–15 min | **Scenario 3:** Plant & Grow |
| 15–18 min | **Scenario 5:** Farm Shop |
| 18–22 min | **Scenario 6:** Browse Recipes |
| 22–30 min | **Scenario 7:** Cook a Recipe |
| 30–35 min | Free play — let them explore on their own |
| 35–40 min | Post-test interview questions |

### After the Session
- [ ] Complete observation checklist while fresh
- [ ] Note top 3 successes (what worked well)
- [ ] Note top 3 issues (what confused or frustrated)
- [ ] Rate overall engagement (1–5)
- [ ] Save screen recording (if captured)

---

## 8. Metrics to Track Across Sessions

After testing with multiple users, compile these:

| Metric | How to Measure |
|--------|----------------|
| **Onboarding completion rate** | % who finish onboarding without help |
| **Task success rate per scenario** | % who complete each scenario unaided |
| **Time to first harvest** | Minutes from Garden entry to first harvest |
| **Time to first cook** | Minutes from Kitchen entry to recipe completion |
| **Mini-game difficulty ranking** | Rank 9 games by observed confusion/failure |
| **Gesture discoverability** | Which gestures needed prompting (swipe, drag, hold, circular) |
| **Top frustration points** | Most common confusion across testers |
| **Engagement score** | 1–5 average from facilitator observation |
| **"Play again" rate** | % of testers who asked to keep playing |
| **Feature requests** | Common "I wish it had..." responses |

---

## 9. Quick Reference: App Navigation Map

```
FIRST LAUNCH
    │
    ▼
Onboarding (5 screens)
    │
    ▼
Meet Pip (dialogue sequence)
    │
    ▼
╔══════════════════════════════════════════════════════════╗
║  MAIN TAB BAR                                            ║
╠══════════╦═══════════╦═══════════╦══════════╦════════════╣
║  🏠 Home  ║ 🌱 Garden  ║ 🍳 Kitchen ║ 🛒 Farm   ║ 📖 Recipes ║
╠══════════╬═══════════╬═══════════╬══════════╬════════════╣
║ Greeting ║ Map +     ║ Map +     ║ Walk     ║ List by    ║
║ Stats    ║ 5 Plots   ║ Pantry    ║ Anim →   ║ category   ║
║ Streak   ║ Seed Bags ║ Counter   ║ Shop     ║            ║
║ Pip msg  ║ Basket    ║ Stove     ║ Grid     ║ Tap card → ║
║ Actions  ║ Pip drag  ║           ║ My Items ║ Detail     ║
║ Recipe   ║           ║           ║          ║ page       ║
╚══════════╩═══════════╩═══════════╩══════════╩════════════╝
                │               │
     Tap plot → │    Select recipe →
     PlantingSheet    CookingSessionView
                │               │
     Tap seed bag →     9 Mini-Games
     SeedInfoView          │
     (+ PencilKit)   CookingCompletionView
                     (Stars + Rewards)
```

---

## 10. Facilitator Tips

- **Don't lead.** Let the child explore. Only intervene if they're stuck for 30+ seconds.
- **Think-aloud.** Ask "What are you thinking?" or "What do you expect to happen?" when they pause.
- **Note exact words.** Write down what they say, not your interpretation.
- **Watch fingers, not screen.** Observe where they tap — missed taps reveal UI issues.
- **Celebrate effort.** Say "Great job exploring!" not "You did it right."
- **Time pressure.** Never rush. If a scenario takes too long, skip to the next.
- **Emoji vs. art.** If they ask about the emoji graphics in mini-games, explain: "The artist is still drawing those — what would you like to see there?"

---

*Document prepared for PROG-360A Project Studio, Columbia College Chicago*
*Pip's Kitchen Garden v1.0 Prototype — March 2026*
