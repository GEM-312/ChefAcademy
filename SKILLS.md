# SKILLS.md — Pip's Kitchen Garden

Technical skills, frameworks, and domain knowledge required for this project.

---

## Teacher-Tutor Mode

Every session should include teaching moments. The developer is learning iOS/Swift while building this app — explain WHY, not just WHAT.

### How to Teach During Sessions

| When | What to Teach |
|------|--------------|
| **Writing new code** | Explain the pattern: "This is a singleton because..." / "We use async/await here because..." |
| **Fixing a bug** | Explain the root cause: "This crashed because SwiftData requires..." / "The view didn't refresh because SwiftUI only redraws when @Published changes" |
| **Choosing an approach** | Explain trade-offs: "We could use @Query or manual fetch — @Query auto-refreshes but manual gives more control" |
| **New framework** | Give a 2-3 sentence overview before diving in: "AVSpeechSynthesizer is Apple's built-in text-to-speech. It works offline, no API needed. You give it text, it speaks." |
| **Architecture decisions** | Explain WHY: "We put this in a singleton because multiple views need the same instance" / "UUID linking instead of @Relationship because CloudKit can't handle relationships" |
| **Common mistakes** | Call them out: "Never use `try?` for database saves — it hides errors. Always `do/catch` so you know when something fails" |

### Topics to Cover Over Time

**Fundamentals (explain as they come up):**
- SwiftUI view lifecycle (onAppear, onChange, onDisappear)
- @State vs @StateObject vs @ObservedObject vs @EnvironmentObject — when to use which
- Value types (struct) vs reference types (class) — why GardenPlot is a struct but GameState is a class
- Optionals — why Swift forces you to handle nil and how (guard let, if let, ??)
- Closures — what `{ item in ... }` means and why SwiftUI uses them everywhere
- async/await — why network calls need it, what happens without it

**Intermediate (teach when relevant):**
- MVVM pattern — Model (data), View (UI), ViewModel (logic) and how our app uses it
- SwiftData — how @Model works, why CloudKit has restrictions, schema migration
- Combine — publishers, @Published, how views react to state changes
- Generics — what `<T>` means when you see it in error messages
- Protocol-oriented programming — what Codable, Identifiable, Equatable do
- Memory management — weak self in closures, why [weak self] prevents leaks

**Advanced (introduce gradually):**
- App architecture — why SessionManager is a state machine, how routes work
- Concurrency — Task, TaskGroup, MainActor, why UI updates must be on main thread
- Testing — how to write unit tests, what to test, XCTest basics
- Performance — lazy loading, caching strategies, avoiding unnecessary redraws
- App Store — provisioning, entitlements, capabilities, TestFlight, review process

### Teaching Style

- **Short explanations** — 2-3 sentences max per concept, not paragraphs
- **Real examples** — use code we just wrote, not abstract examples
- **Build on prior knowledge** — reference things already in the project
- **No jargon without explanation** — if using a technical term, briefly define it
- **Encourage questions** — "This pattern is called X — want me to explain more?"
- **Celebrate progress** — "You now have a full API integration — that's a real production skill"

### Teaching Log (TEACHING.md)

Every session MUST update `TEACHING.md` at the project root. This is a living document that accumulates all teaching moments across sessions — like a personal iOS textbook built from your own project.

**Format for each entry:**

```markdown
## Session: [Date]

### [Concept Name]
**Where it came up:** [file or task]
**What it is:** [2-3 sentence explanation]
**In our code:** [specific example from the project]
**Why it matters:** [practical reason]
```

**Rules:**
- Add new entries at the TOP (newest first)
- Never delete old entries — they form a study reference
- Group related concepts under the same session header
- Link to actual files/lines when possible
- Keep each entry short — this is a reference, not a lecture

---

## Swift / iOS Development

| Skill | Where Used | Level |
|-------|-----------|-------|
| **SwiftUI** | All views, layouts, animations, navigation | Core |
| **SwiftData** | FamilyProfile, UserProfile, PlayerData persistence | Core |
| **CloudKit** | iCloud sync across devices, API key storage | Core |
| **MVVM Architecture** | GameState, SessionManager, AvatarModel (ObservableObject) | Core |
| **Combine** | Publishers, NotificationCenter, state propagation | Intermediate |
| **Concurrency (async/await)** | API calls (WeatherKit, USDA, Claude), background tasks | Intermediate |

---

## Apple Frameworks

| Framework | Purpose | Status |
|-----------|---------|--------|
| **WeatherKit** | Real weather → garden growth multipliers, rain auto-watering | Integrated (pending Apple activation) |
| **AVSpeechSynthesizer** | Pip reads instructions aloud for age 6+ audience | Not started |
| **CoreLocation** | Device location for WeatherKit weather data | Integrated |
| **PencilKit** | Kids color veggies in SeedInfoView (drawing canvas) | Integrated |
| **Sign in with Apple (AuthenticationServices)** | Parent authentication, family account linking | Integrated |
| **Keychain Services** | Secure parent PIN storage (iCloud Keychain sync) | Integrated |
| **UIKit (interop)** | PKCanvasView, PKToolPicker via UIViewRepresentable | Integrated |

---

## APIs & Networking

| API | Purpose | Auth | Status |
|-----|---------|------|--------|
| **USDA FoodData Central** | Real nutrient data per veggie/pantry item (free) | None (public) | Not started |
| **Claude Haiku API** | Pip AI chat — kid-friendly Q&A about food/cooking | API key (CloudKit) | Integrated |
| **WeatherKit (Apple)** | Real-time weather conditions + temperature | Entitlement (JWT) | Integrated (auth pending) |

**Networking skills needed:**
- URLSession / async data fetching
- JSON decoding (Codable)
- Response caching (UserDefaults / local store)
- Error handling with graceful fallbacks
- Rate limiting (Claude: 20 questions/day)
- API key security (CloudKit public DB, never in source)

---

## Game Design & Mechanics

| Skill | Where Used |
|-------|-----------|
| **State machines** | CookingSessionView (step flow), PlotState (empty→growing→ready), AppRoute (navigation) |
| **Gesture recognition** | Drag (planting, watering can), swipe (peeling, weeding), tap (chopping, cracking), hold (heating pan), circular swipe (stirring) |
| **Scoring systems** | Mini-game scores (0-100), star tiers (1-3), XP/level progression |
| **Economy design** | Coin earning (knowledge cards), spending (seeds/pantry), learn-to-earn loop |
| **Reward psychology** | One-time knowledge rewards, streak tracking, care XP bonuses |
| **Timer-based gameplay** | Growth timers, cook timers, green-zone timing games |
| **Random events** | Weeding at 25% growth, bugs at 75% growth, weather events |

---

## Animation & Visual Effects

| Skill | Where Used |
|-------|-----------|
| **Frame animation (Timer-based)** | Walking Pip (15 frames @ 30fps), waving Pip, avatar card selection |
| **SwiftUI transitions** | Crossfade (farm barn doors), slide, scale, opacity |
| **Spring animations** | Plot tap feedback, plant bounce after watering |
| **Particle effects** | Rain drops, snowflakes, water droplets, floating XP text, musical notes |
| **Gesture-driven animation** | Drag-to-plant, drag watering can, circular stir motion |
| **Overlay effects** | Weather overlay (sun glow, rain, snow, lightning), sparkle/glow |

---

## Art & Design

| Skill | Tool | Where Used |
|-------|------|-----------|
| **Botanical watercolor illustration** | Procreate (iPad) | All veggie images, Pip character, backgrounds |
| **Character design** | Procreate | Pip poses, boy/girl avatars, avatar outfits |
| **Asset production** | Procreate → PNG export | Transparent PNGs for all game elements |
| **UI/UX design (age 6+)** | Figma / SwiftUI | Large touch targets, minimal text, vibrant CTAs |
| **Color theory** | AppTheme.swift | Warm botanical palette + vibrant accents for kids |
| **Icon design** | SF Symbols + custom | Tab bar, action buttons, nutrient icons |

**Assets still needed:**
- 19 veggie/fruit/berry images (botanical watercolor)
- Watering can, water droplets
- Weeds (2-3 varieties)
- Compost bin, food scraps
- Ladybug, aphids
- Parasol/garden umbrella
- Boy/girl avatar caring animations (watering, weeding)
- Wilting plant overlay

---

## Data & Nutrition Science

| Skill | Where Used |
|-------|-----------|
| **USDA nutrition database** | Mapping foods to FDC IDs, parsing nutrient data per serving |
| **Nutrient → organ mapping** | 21 NutrientTypes → 6 Body Buddy organs (brain, heart, immune, muscles, bones, energy) |
| **Age-appropriate health education** | Fun facts, Pip tips, color-to-nutrition mapping |
| **Glucose/blood sugar science** | Recipe glucoseTips (Jessie Inchauste / Glucose Goddess research) |

---

## Multi-User & Security

| Skill | Where Used |
|-------|-----------|
| **Family profile system** | FamilyProfile → UserProfile → PlayerData (UUID linking) |
| **Parental controls** | PIN-gated parent access (Keychain), play time tracking |
| **CloudKit data sync** | Cross-device family data, API key distribution |
| **Sign in with Apple** | Parent authentication, opaque user ID storage |
| **Data isolation** | Per-child game state, sibling garden visits (read-only) |

---

## Accessibility & UX (Age 6+)

| Skill | Where Used |
|-------|-----------|
| **Text-to-speech** | AVSpeechSynthesizer for all instructions (P0 UX requirement) |
| **Reduced text density** | Max 8 words per Pip bubble, 4-step max processes |
| **Large touch targets** | Plot buttons, seed bags, tab bar icons |
| **Visual affordances** | Scroll cues, pulsing buttons, bouncing Pip |
| **Inclusive design** | Gender options, head coverings (hijab/kippah/turban), dietary preferences |
| **Responsive layout** | iPhone SE → iPad Pro, portrait + landscape |

---

## Adaptive Layout & Device Orientation

| Skill | What It Means |
|-------|--------------|
| **GeometryReader** | Read available width/height to scale content dynamically — avoid hardcoded frame sizes |
| **Size classes (horizontalSizeClass / verticalSizeClass)** | Detect compact (iPhone portrait) vs regular (iPad, iPhone landscape) and swap layouts |
| **Portrait layout** | Primary layout: vertical stacks, bottom tab bar, full-width cards, single-column scrolling |
| **Landscape layout** | Side-by-side panels: garden map + seed inventory, recipe list + detail, Pip chat + game area |
| **iPhone SE (375pt wide)** | Smallest target — seed bags must not overlap, tab labels must fit, plot grid must scroll if needed |
| **iPhone 17 Pro (393pt wide)** | Standard target — primary development device |
| **iPhone Pro Max (430pt wide)** | Wider — use extra space for padding, don't stretch elements |
| **iPad (768-1024pt wide)** | Multi-column layouts, larger touch targets, bigger Pip, side-by-side navigation |
| **Safe area handling** | `.ignoresSafeArea()` only on backgrounds, content respects notch/Dynamic Island/home indicator |
| **Tab bar in landscape** | Compact height — reduce tab bar padding, smaller icons, hide labels if needed |
| **Garden map rotation** | Plots reflow: portrait = 2 columns, landscape = 3-4 columns. Map scrolls horizontally in landscape |
| **Cooking mini-games rotation** | Must work in both orientations — gesture areas scale with screen, instructions reposition |
| **Kitchen/Garden scene maps** | SceneEditor items use relative positions (% of screen), not absolute points |
| **Keyboard avoidance** | Text fields (child name, Ask Pip chat) push content up when keyboard appears |
| **Dynamic Type support** | Respect user font size preferences — use `.font(.AppTheme.*)` which scales, test with Large Accessibility sizes |
| **Screen-relative sizing** | Use `UIScreen.main.bounds` or GeometryReader ratios (e.g., `width * 3/8`) instead of fixed pixel values |

### Device Reference Table

| Device | Width (pt) | Height (pt) | Size Class (Portrait) | Size Class (Landscape) |
|--------|-----------|-------------|----------------------|----------------------|
| iPhone SE 3rd | 375 | 667 | compact / regular | compact / compact |
| iPhone 16 | 390 | 844 | compact / regular | compact / compact |
| iPhone 17 Pro | 393 | 852 | compact / regular | compact / compact |
| iPhone 17 Pro Max | 430 | 932 | compact / regular | regular / compact |
| iPad mini | 744 | 1133 | regular / regular | regular / regular |
| iPad Air/Pro 11" | 820 | 1180 | regular / regular | regular / regular |
| iPad Pro 13" | 1024 | 1366 | regular / regular | regular / regular |

### Layout Strategy Per Screen

| Screen | Portrait | Landscape |
|--------|----------|-----------|
| **Home** | Single column scroll | Two columns: greeting+stats left, quick actions right |
| **Garden** | Map top, seed bags bottom scroll | Map left (60%), seed panel right (40%) |
| **Kitchen** | Scene map full width, recipe list below | Scene map left, recipe panel right |
| **Farm Shop** | 2-column grid | 3-4 column grid |
| **Cooking mini-games** | Centered gesture area | Wider gesture area, Pip on side |
| **Body Buddy** | Vertical organ rings | Body figure left, rings/stats right |
| **Seed Info** | Vertical scroll: image → color → nutrients | Image left, info panel right |
| **Profile Picker** | Horizontal scroll cards | Grid of cards |

---

## DevOps & Build

| Skill | Where Used |
|-------|-----------|
| **Xcode project configuration** | Entitlements, capabilities, signing, provisioning |
| **Apple Developer Portal** | WeatherKit, CloudKit, Push Notifications setup |
| **Simulator + device testing** | iPhone 17 Pro sim, real device for WeatherKit/CloudKit |
| **SwiftData schema migration** | ModelContainer auto-recovery, backwards compatibility |
| **Git version control** | Feature branches, commit hygiene |

---

## Clean Code

| Skill | What It Means |
|-------|--------------|
| **Single Responsibility** | Each file/struct/class does ONE thing — `PipVoice` only handles speech, `GardenWeatherService` only handles weather. Never mix UI + networking + persistence in one file |
| **Small functions** | Every function fits on one screen (~20 lines max). If it's longer, break it into named sub-functions that read like steps |
| **Descriptive naming** | `harvestPlot(index:)` not `doAction()`. `isOwned` not `flag`. Names should explain what it does without needing a comment |
| **No magic numbers** | Use `AppSpacing.md` not `16`. Use `badgeWidth * 0.43` not `47`. Define constants with meaningful names |
| **DRY (Don't Repeat Yourself)** | If 3+ views share the same pattern, extract it (e.g., `PrimaryButtonStyle`, `ProfileCard`). But don't abstract too early — 2 is fine |
| **MARK sections** | Every file uses `// MARK: -` to organize: Properties, Body, Helpers, Actions, Preview. Makes long files scannable |
| **Dead code removal** | No commented-out code blocks, no unused imports, no leftover `print()` statements in production. If it's not used, delete it |
| **Error handling** | Never use `try?` for critical saves (SwiftData). Always `do/catch` with meaningful log messages. Fail gracefully for kids — never show raw errors |
| **Minimal imports** | Only import what you need — `import SwiftUI` not `import UIKit` when SwiftUI suffices |
| **File organization** | One primary type per file. File name matches the main struct/class. Related helpers can live in the same file below the main type |
| **Preview hygiene** | Every view has a `#Preview` that works standalone. Use `.preview` helpers on state objects for realistic preview data |
| **Avoid force unwraps** | Never use `!` except for `#Preview` and guaranteed-safe cases like `UIImage(named:)`. Use `guard let` or `if let` everywhere else |
| **Consistent formatting** | Same brace style, same spacing, same parameter alignment. Code should look like one person wrote it |
| **Extract reusable views** | Common patterns become components: `PrimaryButtonStyle`, `QuickActionCard`, `ProfileCard`, `PipMessageCard`, `SpeakerButton` |
| **Meaningful commits** | Each commit does one thing. Message explains WHY not WHAT. "Add watering can drag interaction for plant care" not "update garden" |

---

## Consistency & Quality Standards

| Skill | What It Means |
|-------|--------------|
| **Design system adherence** | All colors from AppTheme.swift, all fonts from AppTheme, all spacing from AppSpacing — no hardcoded values |
| **Art style consistency** | Every asset matches botanical watercolor aesthetic — same line weight, same color warmth, same paper texture feel |
| **Voice & tone consistency** | Pip always speaks in short, encouraging, kid-friendly language — max 8 words per bubble, no scary/negative content |
| **Code architecture consistency** | MVVM everywhere, @EnvironmentObject for shared state, UUID-based model linking, MARK sections, #Preview for every view |
| **Naming conventions** | Files: PascalCase.swift, Assets: snake_case_name, Enums: camelCase cases, Views: PascalCaseView |
| **Animation consistency** | All spring animations use same response/damping, all frame animations at 30fps, all transitions use easeInOut(0.3) |
| **Reward balance** | Knowledge cards: 5 coins per nutrient tap. Care actions: 1-3 XP. Seeds: 5-15 coins. Pantry: 3-10 coins. Keep economy balanced |
| **Interaction patterns** | Tap = select/confirm, Drag = move/place, Swipe = remove/peel, Hold = charge/heat, Circular = stir. Same gesture = same meaning everywhere |
| **Error handling** | Never show errors to kids. Always fallback gracefully (sunny weather default, offline nutrition fallback, starter seeds if empty) |
| **Persistence safety** | Always use do/catch with logging on context.save(). Never use try? for SwiftData saves. Test across app restarts |
| **Accessibility baseline** | Touch targets min 44pt, text readable at default size, VoiceOver labels on interactive elements, speech available for all instructions |
| **Platform testing** | Test on iPhone SE (small), iPhone 17 Pro (standard), iPad (large). Portrait + landscape |

---

## Summary by Priority

### Must Have (ship blockers)
- SwiftUI + SwiftData + CloudKit (core stack)
- AVSpeechSynthesizer (P0 UX — kids can't read long text)
- Gesture-based mini-games (core gameplay)
- Botanical watercolor art (visual identity)

### Should Have (quality & depth)
- USDA API (real nutrition data)
- Plant care mechanics (watering, weeding, bugs)
- WeatherKit (real weather → garden)
- Body Buddy health connection

### Nice to Have (polish)
- Kid avatar caring animations
- Composting mechanic
- Singing to plants
- Sunshade mechanic

---

*Last Updated: March 15, 2026*
