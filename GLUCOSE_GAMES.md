# Glucose Science Mini-Games — Design Document

Based on Marina's iBooks annotations from *Glucose Revolution* by Jessie Inchauspe.
These games teach kids how food affects their body through interactive play.

**Target Age:** 6+
**Style:** Botanical watercolor aesthetic, Pip as guide
**Integration:** Play & Learn tab + Body Buddy post-cooking flow

---

## Game 1: Pip's Glucose Journey (Post-Cooking Animation + Smart Snack Quiz)

**Source annotation:** "Use it for animation of metabolism of glucose"

### Concept
After cooking a recipe, kids watch their healthy meal travel through the body — celebrating each ingredient's role. Then Pip quizzes them on what they'd eat next, using real USDA sugar data for the "bad" options.

### Part A: Interactive Body Journey (3 Phases — All Interactive)

All recipes in the app are healthy (Glucose Goddess approved). Each phase has the kid DOING something — no passive watching.

#### Phase 1 — "Your Tummy" (Interactive Drag)

**The science:** Food goes to the stomach → breaks into glucose → glucose absorbs through the gut wall into blood. Fiber, protein, and fat slow down how fast glucose passes through the tummy wall. This is where the magic happens — not in the blood, but in the gut.

**What the kid sees:** A cute cartoon tummy (stomach/intestine shape, like a friendly pouch). On one side: the tummy. On the other side: a blood stream (red river). Between them: the **tummy wall** (a dotted barrier with tiny gates). Glucose balls want to pass through the gates into the blood.

**What the kid does:**
1. Pip: "Your food just arrived in your tummy! Let's see what happens. Drag your ingredients in!"
2. Kid drags each recipe ingredient into the tummy one by one
3. **Veggies (fiber):** When dragged in, they THICKEN the tummy wall — gates get smaller, glucose squeezes through slowly. Green glow on the wall.
   - Pip: "Fiber makes the tummy wall thicker! Glucose has to wait in line!"
4. **Protein (eggs, chicken):** When dragged in, they create a QUEUE — glucose balls line up in a neat row instead of rushing all at once.
   - Pip: "Protein tells glucose to wait its turn!"
5. **Fat (olive oil, butter, cheese):** When dragged in, they COAT the glucose balls — coated balls move slower through the gates (they're slippery/heavy now).
   - Pip: "Fat wraps around the glucose so it moves nice and slow!"

**Visual result:** After all ingredients placed, glucose passes through the tummy wall one-by-one into the blood stream. Smooth, calm, steady.

**Compare button:** "What if you ate just candy?" — tap and all the fiber/protein/fat disappear. Tummy wall becomes thin, gates wide open, glucose FLOODS through into the blood all at once. Blood stream turns from calm blue-red to chaotic rushing. Quick shock, then snap back.
- Pip: "Whoa! No fiber, no protein, no fat — glucose rushes straight through! That's a spike!"

#### Phase 2 — "Inside Your Cell" (Zoom + Tap Interaction)

**What the kid sees:** A zoom sequence:
1. First: cartoon body outline (the kid's Body Buddy figure)
2. Pip: "Let's zoom in! Your body is made of tiny cells..."
3. Body zooms in → shows thousands of tiny circles (cells)
4. Pip: "Each cell has a power plant inside called a mitochondria!"
5. Zoom into ONE big cell — fills the screen. Inside: nucleus, membrane, and a MITOCHONDRIA (cute power plant with a chimney)

**What the kid does:**
1. Golden glucose balls float into the cell from the blood vessel (from Phase 1)
2. Kid TAPS the mitochondria to feed it glucose
3. Each tap: mitochondria GLOWS, produces ENERGY SPARKLE (lightning bolt)
4. Sparkle flies out of the cell → back to the body view
5. Body parts light up as sparkles arrive: brain glows, muscles glow, heart glows (based on recipe nutrients)
6. After 5-6 taps: cell DIVIDES (splits into two with a satisfying animation)
7. Pip: "Steady glucose = happy cells = strong body!"

**Steady vs Spike comparison:**
- A toggle or button: "What if glucose came too fast?"
- Tap it: glucose balls FLOOD the cell. Kid taps mitochondria frantically but can't keep up
- Mitochondria turns red, overwhelmed, sparks fly (free radicals preview)
- Pip: "Too much at once! The mitochondria can't keep up!"
- Toggle back to steady: everything calms down

#### Phase 3 — "Free Radical Sandbox" (Interactive Experiment)

**What the kid sees:** A large cell view with mitochondria in the center. A sugar cube tray on the side. Free radical counter at top.

**What the kid does — THE EXPERIMENT:**
1. Pip: "Let's see what happens when you add sugar! Drag sugar cubes into the cell."
2. Kid drags sugar cubes (from a tray) INTO the cell
3. Each sugar cube added:
   - Glucose floods in (golden balls increase)
   - Mitochondria works harder (glows brighter, shakes)
   - **FREE RADICALS SPAWN** — spiky purple dots appear, bouncing around
   - Free radical counter goes UP
4. Kid can also DRAG sugar cubes OUT (remove them):
   - Glucose decreases
   - Free radicals SLOW DOWN and get absorbed by the cell (green flash = neutralized)
   - Free radical counter goes DOWN
   - Mitochondria calms down, stops shaking
5. The cell has a HEALTH BAR:
   - Green when few radicals (healthy)
   - Yellow when moderate (warning)
   - Red when overwhelmed (oxidative stress!)

**The question:**
After the kid experiments, Pip asks: "How do you think YOUR meal was?"
- Three choices: "Lots of sugar" / "A little sugar" / "Healthy & balanced"
- Correct answer (Healthy & balanced): Pip celebrates, +10 coins
- Wrong answer: Pip gently explains, "Remember, we used veggies and protein — that keeps glucose steady!"

**Teaching moment:** Kid FELT the difference by adding/removing sugar cubes themselves. They saw radicals appear and disappear. Way more powerful than reading about it.

### Part B: "Pip's Smart Snack" (Post-Journey Quiz)

Immediately after the animation, Pip asks: **"Great cooking! Now what would you eat for a snack?"**

#### How It Works
- Show 3 food options as illustrated cards (2 bad, 1 good)
- Bad options pulled from USDA API with REAL sugar data
- Good option is always a veggie/fruit/healthy snack from the app's existing items

#### Example Rounds

| Good Choice | Bad Choice 1 | Bad Choice 2 |
|-------------|-------------|-------------|
| Apple slices with nuts | Frosted Cornflakes (12g sugar/serving) | Chocolate bar (24g sugar) |
| Carrot sticks with hummus | Fruit juice box (22g sugar) | Gummy bears (18g sugar) |
| Greek yogurt with berries | Soda can (39g sugar!) | White bread with jam (15g sugar) |
| Cucumber + cheese | Pop-Tart (16g sugar) | Sugary cereal (13g sugar) |
| Handful of nuts | Candy bar (30g sugar) | Sports drink (21g sugar) |

#### If Kid Chooses HEALTHY Option
- Pip jumps and celebrates: "Smart choice, chef! That snack has fiber AND protein!"
- **+10 coins reward**
- Brief animation: smooth glucose ride (reuses Phase 1-3 assets)
- Sugar comparison appears: "Your snack: 4g natural sugar. The cornflakes? 12g added sugar!"

#### If Kid Chooses UNHEALTHY Option
- Pip doesn't scold — he explains with curiosity:
- Pip: "Hmm, let's look at that one together..."
- USDA sugar data appears on screen: "This has 24g of sugar — that's 6 teaspoons!"
- Visual: 6 animated sugar cubes stack up next to the food
- Brief "spike peek" animation (fast glucose flood, overwhelmed mitochondria)
- Pip: "That would make a BIG glucose spike! Want to pick something better?"
- Kid gets to choose again — **still earns 5 coins** for learning (no punishment, just education)
- Pip: "Now you know! Next time you'll be a glucose pro!"

#### USDA Integration
Uses existing `USDAFoodService.swift` — add FDC IDs for common unhealthy items:

| Bad Food | FDC ID | Sugar per Serving | Visual Sugar Cubes |
|----------|--------|-------------------|-------------------|
| Frosted Cornflakes | 1104032 | 12g | 3 cubes |
| Coca-Cola (12oz) | 174826 | 39g | ~10 cubes |
| Chocolate bar (Snickers) | 1100294 | 24g | 6 cubes |
| Gummy bears | 1104215 | 18g | 4.5 cubes |
| Apple juice box | 1104524 | 22g | 5.5 cubes |
| White bread + jam | 1105488 | 15g | ~4 cubes |
| Pop-Tart (frosted) | 1101162 | 16g | 4 cubes |
| Sports drink (Gatorade) | 1104345 | 21g | ~5 cubes |

Compare against healthy picks:
| Good Food | Sugar | Visual |
|-----------|-------|--------|
| Apple (whole) | 10g (with fiber!) | 2.5 cubes BUT wrapped in green fiber |
| Carrot sticks | 3g | Less than 1 cube |
| Greek yogurt (plain) | 4g | 1 cube |
| Handful of almonds | 1g | Barely visible |

#### Sugar Cube Visualization
- 1 sugar cube = 4g sugar
- Cubes stack up next to the food card in real-time
- Healthy foods show cubes wrapped in a green fiber glow (fiber slows the sugar)
- Unhealthy foods show bare cubes stacking up with a red glow
- Pip: "Each cube is one teaspoon of sugar. Count them with me!"

#### Quiz Rotation
- 1 question per cooking session (don't overwhelm)
- Pool of 20+ question sets, randomized
- New questions unlock as kid cooks more recipes
- Track correct answers in `claimedKnowledgeIDs` for one-time bonus coins
- After 10 correct answers: unlock "Glucose Expert" badge

### Scoring Summary

| Action | Reward |
|--------|--------|
| Watch full Glucose Journey animation | +5 coins |
| Choose healthy snack on first try | +10 coins |
| Choose unhealthy, then learn + pick again | +5 coins (learning reward) |
| 10 correct snack choices total | "Glucose Expert" badge |

### Teaching Points
- Every ingredient in their recipe has a job (fiber = net, protein = speed bump, fat = slow lane)
- Their cooking choices directly help their body (positive reinforcement)
- Real sugar data makes "bad" foods concrete (6 teaspoons = visual shock)
- No shaming — wrong choices become learning moments with Pip's gentle explanation
- Fiber changes everything (whole apple vs apple juice — same fruit, different spike)

### Connection to Existing Systems
- Triggers after CookingCompletionView (replaces or extends current flow)
- Recipe's `glucoseTip` provides the Phase 4 comparison context
- Recipe's `gardenIngredients` and `pantryIngredients` drive Phases 1-3 visuals
- Feeds into Body Buddy organ health updates
- USDA API (already integrated) provides real sugar data for bad food options
- `claimedKnowledgeIDs` tracks quiz progress for one-time bonuses
- New badge: "Glucose Expert" after 10 correct snack picks

---

## Game 2: Insulin Tetris

**Source annotation:** "Ideas for Tetris insulin game" + "Add a game to the Pip games"

### Concept
Glucose blocks fall from the top (like Tetris). Insulin (a little key character) must sort them into 3 storage bins before they overflow.

### Storage Bins

| Storage | Capacity | Visual | Science |
|---------|----------|--------|---------|
| Liver (jar) | 100g (small) | Fills up fast, turns amber | Liver holds ~100g glucose = 2 large McDonald's fries |
| Muscles (flexing arms) | 400g (medium) | Takes more, arms grow stronger | Muscles hold ~400g for a 150lb adult |
| Fat cells (balloons) | Unlimited | Inflates with each block | Last resort storage, causes weight gain |

### Gameplay
- Drag falling glucose blocks into the right bin
- Liver fills first -> muscles -> fat (last resort)
- **Fructose blocks** (red/purple) can ONLY go to fat — they won't fit in liver or muscles!
- **Fiber blocks** (green, from veggies the kid grew!) slow down the falling speed — easier to sort
- Speed increases over time (simulating a glucose spike)

### Scoring
- Keep fat balloons as small as possible
- Fiber blocks = speed reduction bonus = higher score
- Filling liver + muscles efficiently = combo bonus
- Fat balloon size at end determines star rating (small = 3 stars)

### Pip Says
- "See? When we eat veggies first, the glucose comes slowly — easier to store!"
- "Fructose can only become fat — that's why fruit is best eaten with fiber!"
- "Your muscles are hungry for glucose — exercise helps them hold more!"

### Teaching Points
- Fiber slows glucose absorption (easier gameplay = visual proof)
- Fructose can ONLY be stored as fat (red blocks won't fit anywhere else)
- Liver and muscles have limited capacity
- Fat storage is unlimited but undesirable

### Source Facts
- "The liver can hold about 100 grams of glucose in glycogen form (the amount of glucose in two large McDonald's fries)"
- "The muscles of a typical 150-pound adult can hold about 400 grams of glucose as glycogen"
- "Fructose cannot be turned into glycogen and stored in the liver and the muscles. The only thing that fructose can be stored as is fat."
- "Fat cells deflate like balloons" (visualization for winning)

---

## Game 3: Free Radical Defense (Tower Defense)

**Source annotation:** "Oxidative stress try to make a game with free radicals attacking the body" + "Free radicals cell damaging animation"

### Concept
Spiky purple free radical monsters spawn from glucose spikes and bounce around a cell. The kid must protect the cell's DNA (a glowing double helix in the center).

### Gameplay
- Free radicals (spiky purple balls) spawn at screen edges and bounce toward center
- **Tap free radicals** to neutralize them (pop into sparkles)
- **Antioxidant shields** appear based on veggies the kid has eaten/grown:
  - Red veggies (lycopene) = red shield (blocks radicals from one direction)
  - Purple veggies (anthocyanins) = purple shield
  - Orange veggies (beta-carotene) = orange shield
  - Green veggies (chlorophyll) = green shield
  - Yellow veggies (vitamin C) = yellow shield
- Shields auto-deploy around the DNA — more veggie colors eaten = more shield coverage

### Difficulty Levels
- **Easy** (balanced meal): Few radicals, slow movement
- **Medium** (some sugar): More radicals, moderate speed
- **Hard** (glucose spike!): Swarm of radicals, fast — oxidative stress warning flashes

### DNA Health
- DNA health meter at top (starts at 100%)
- Each radical that reaches DNA reduces health
- If DNA flickers red, Pip warns: "Too many free radicals! We need antioxidants!"
- Game ends when DNA health hits 0% or timer runs out

### Connection to Color-Nutrient System
Directly ties into existing SeedInfoView ColorChoice system:
- red = lycopene (heart)
- orange = beta-carotene (skin/eyes)
- yellow = vitamin C (immune)
- green = chlorophyll (energy)
- purple = anthocyanins (brain)

### Teaching Points
- Free radicals damage DNA and cells
- Antioxidants from colorful veggies neutralize free radicals
- Glucose spikes = more free radicals (oxidative stress)
- Eating a rainbow of veggies = better protection

### Source Facts
- "Free radicals randomly snap and modify our genetic code (our DNA), creating mutations"
- "They poke holes in the membranes of our cells"
- "When there are too many free radicals to be neutralized, our body is said to be in a state of oxidative stress"

---

## Game 4: The Toaster (Glycation Reaction Game)

**Source annotation:** "Glaciated molecules damages game" + "Make animation or a game where molecules bumps into another type of molecule"

### Concept
Based on the Maillard reaction — "you can't untoast a piece of toast." Glucose molecules bounce around and permanently damage healthy molecules on contact.

### Gameplay
- Grid of healthy molecule cards: proteins (blue), fats (yellow), DNA strands (purple) — cute, bouncy, colorful faces
- Glucose molecules (golden balls) bounce around the screen like bumper cars
- When glucose hits a healthy molecule, it turns brown and "toasted" (glycated) — PERMANENTLY damaged
- **Kid's job**: Tap to place fiber shields (green barriers) around healthy molecules before glucose hits them
- Limited fiber shields per round (earn more by growing veggies in garden)

### Rounds
1. **Round 1 — Steady Glucose**: Slow glucose, few molecules — easy to protect
2. **Round 2 — Glucose Spike**: Many fast glucose balls — harder to shield everything
3. **Round 3 — Fructose Attack**: Fructose balls move **10x faster** than glucose! Nearly impossible to protect all molecules

### Key Visual: Can't Un-Toast
- Once a molecule turns brown, it stays that way for the rest of the game
- At the end, kid sees how many molecules they saved vs. how many got "toasted"
- Pip: "See those brown ones? They're damaged forever — just like you can't un-toast toast!"

### Scoring
- Molecules saved = points
- All molecules saved in a round = perfect bonus
- Fructose round survival = bonus coins (it's meant to be hard — teaches the 10x lesson)

### Teaching Points
- Glycation = permanent cell damage (Maillard reaction)
- Fructose glycates 10x faster than glucose
- Fiber creates a protective barrier (slows glucose down)
- Visual: browned/toasted = damaged = can't undo

### Source Facts
- "Once a molecule is glycated, it's damaged forever — which is why you can't untoast a piece of toast"
- "Fructose molecules glycate things 10 times as fast as glucose"
- "Browning happens when a glucose molecule bumps into another type of molecule"

---

## Game 5: Pip's Body Quiz (Interactive Q&A)

**Source annotation:** "Question for the kids"

### Concept
Pip asks fun body science questions between other games. Quick-tap quiz format with visual answers.

### Question Bank

| Question | Answer | Visual |
|----------|--------|--------|
| "Which body part can grow just by sitting on the couch?" | Fat cells! | Balloon inflates on couch |
| "How many McDonald's fries of glucose can your liver hold?" | 2 large fries | Liver jar fills with fries |
| "What's the ONLY thing fructose can become?" | Fat! | Fructose ball rolls into balloon |
| "What gives your cells energy?" | Mitochondria! | Power plant lights up |
| "What color veggie boosts your brain?" | Purple! (anthocyanins) | Brain sparkles purple |
| "What color veggie helps your heart?" | Red! (lycopene) | Heart glows red |
| "What slows down a glucose spike?" | Fiber! | Green wave smooths out spike graph |
| "Can you un-glycate a molecule?" | No! Like un-toasting toast! | Toast pops up, can't go back |
| "What happens when too many free radicals attack?" | Oxidative stress! | Cell flashes red warning |
| "Where does glucose go FIRST for storage?" | The liver! | Liver jar lights up |
| "Where does glucose go when the liver is full?" | Muscles! | Flexing arms appear |
| "What makes fructose more dangerous than glucose?" | It glycates 10x faster! | Speed comparison animation |
| "What does dopamine do when you taste something sweet?" | Makes you want MORE! | Brain with sparkle loop |
| "Why were Stone Age bananas healthier?" | More fiber, less sugar! | Old vs new banana side by side |

### Gameplay
- 5 random questions per round
- Multiple choice (3 options) with visual answers
- Correct answer = Pip celebrates + 5 coins
- Perfect round (5/5) = bonus 10 coins
- Questions refresh daily (different 5 each day)
- New questions unlock as kid cooks more recipes / plays more games

### Pip Reactions
- Correct: "You're a nutrition scientist!" / "Your brain cells are happy!"
- Wrong: "Almost! Let me show you..." (brief animation explains the right answer)
- Perfect round: "AMAZING! You know more about glucose than most grown-ups!"

### Teaching Points
- Reinforces concepts from the other 4 games
- Spaced repetition (daily refresh) builds long-term memory
- Wrong answers become teaching moments, not failures

---

## Integration Map

### Where Each Game Lives

| Game | Location | Unlock Condition |
|------|----------|-----------------|
| Glucose Journey | Body Buddy tab (post-cooking) | Automatic after first recipe cooked |
| Insulin Tetris | Play & Learn tab | Unlock after cooking 3 recipes |
| Free Radical Defense | Play & Learn tab | Unlock after learning 5 veggie nutrients |
| The Toaster | Play & Learn tab | Unlock after cooking 5 recipes |
| Pip's Body Quiz | Play & Learn tab | Always available, grows with progress |

### Connection to Existing Game Loop

```
GROW (Garden)
  |
  v
COOK (Kitchen) --> Glucose Journey animation (Body Buddy)
  |                      |
  v                      v
FEED (Body Buddy)   Organ health updates
  |
  v
PLAY (Play & Learn) --> Insulin Tetris, Free Radical Defense, The Toaster, Quiz
  |
  v
EARN coins --> buy more seeds --> GROW more --> unlock harder game levels
```

### Data Connections

| Game | Reads From | Writes To |
|------|-----------|-----------|
| Glucose Journey | Last cooked recipe, glucoseTip | Body Buddy organ health |
| Insulin Tetris | Garden fiber veggies grown (= fiber blocks) | Coins, XP |
| Free Radical Defense | Veggie colors eaten (= shield types) | Coins, XP |
| The Toaster | Garden veggies grown (= fiber shields) | Coins, XP |
| Body Quiz | All game progress | Coins, claimedKnowledgeIDs |

---

## Implementation Priority

| Priority | Game | Effort | Impact |
|----------|------|--------|--------|
| 1 | Pip's Body Quiz | Low (text + tap) | High (daily engagement, reinforces all concepts) |
| 2 | Insulin Tetris | Medium (falling blocks, drag) | High (core glucose concept, very visual) |
| 3 | Free Radical Defense | Medium (tap targets, shields) | High (connects to veggie color system) |
| 4 | Glucose Journey | Medium (animation sequence) | Medium (post-cooking wow factor) |
| 5 | The Toaster | Medium (bouncing physics, shields) | Medium (glycation is advanced concept) |

---

## Visual Style Notes

All games maintain the botanical watercolor aesthetic:
- Glucose molecules: golden/amber watercolor balls with cute dot eyes
- Fructose molecules: deeper amber/red, slightly spiky
- Fiber: green leafy shields with soft edges
- Free radicals: purple spiky balls (scary but cute, like sea urchins)
- Mitochondria: tiny warm-toned power plants with brick chimneys
- DNA: soft glowing double helix in cream/gold
- Fat cells: round, soft, balloon-like in warm peach tones
- Storage bins: liver (amber jar), muscles (sage flexing arms), fat (peach balloons)

Pip appears in every game as the guide/commentator, using existing pip_cooking and pip_excited poses.

---

*Based on Glucose Revolution by Jessie Inchauspe*
*Game design for Pip's Kitchen Garden — March 2026*
*Marina Pollak, PROG-360A Project Studio*
