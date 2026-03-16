# Pip's Kitchen Garden — Midterm Presentation
### PROG-360A Project Studio | Columbia College Chicago
### Marina Pollak | March 2026

---

## Summary

**Pip's Kitchen Garden** is an educational iOS game for children ages 6+ that teaches healthy eating through interactive gameplay. Players grow vegetables in a virtual garden, cook real recipes through gesture-based mini-games, and watch how food nourishes their body through an animated Body Buddy system.

**Genre:** Educational Simulation / Cooking Game

**High Concept:** "Cooking Mama meets Animal Crossing — but everything you cook is healthy, and you see exactly how it helps your body."

**Unique Selling Points:**
- **Real nutrition science** — USDA FoodData Central API provides real nutrient data, presented as kid-friendly "superpowers" (e.g., "Germ-fighting superpower!" instead of "89mg Vitamin C")
- **Grow-to-Cook loop** — Kids plant seeds, care for plants (water, weed, rescue from bugs), harvest, then cook with what they grew
- **Multi-user family system** — Up to 4 children per device with separate profiles, parent PIN protection, and sibling garden visits
- **AI-powered mascot** — Pip the hedgehog answers food questions via Claude AI, reads instructions aloud via text-to-speech
- **Real weather integration** — Apple WeatherKit makes garden growth reflect actual local weather conditions

---

## Visuals and Key Points

### 1. The Game Loop: GROW → COOK → FEED

The core experience follows a satisfying loop that keeps kids engaged:

**[Screenshot: Garden View with growing plants]**
Kids plant seeds, water thirsty plants, pull weeds, and rescue plants from bugs. Each care action earns XP, and well-cared-for plants yield bonus vegetables at harvest.

**[Screenshot: Cooking Session — frying pan mini-game]**
10 gesture-based mini-games make cooking interactive: drag ingredients into a frying pan, stir with circular swipes, crack eggs with taps, time the cooking perfectly, and plate the finished dish.

**[Screenshot: Body Buddy with animated health bars]**
After cooking, the Body Buddy screen shows which organs were powered up. Each ingredient's real nutrients (from USDA data) map to body systems — carrots boost Eyes, broccoli boosts Immune System, eggs build Muscles.

### 2. Multi-User Family System

**[Screenshot: "Who's playing today?" profile picker]**
The app supports multiple children per device. Each child has their own garden, recipes, coins, and progress. Parents access a PIN-protected dashboard to monitor play time and stats.

**[Screenshot: Family Setup wizard]**
First-launch onboarding walks parents through creating the family: parent account (Sign in with Apple), set PIN, add first child with avatar customization.

### 3. Learning Through Play

**[Screenshot: Seed Info card with nutrients and fun facts]**
Every seed and pantry item has a knowledge card. Kids tap nutrients to learn what they do ("Vitamin C — Germ-fighting superpower!") and earn coins. The USDA API provides real data behind the scenes, translated into age-appropriate language.

**[Screenshot: PencilKit coloring on veggie image]**
Kids color vegetable images directly on screen using PencilKit. The ink color they choose triggers nutrition education — red ink teaches about lycopene (heart health), green teaches about chlorophyll (energy).

### 4. Social Features

**[Screenshot: Sibling garden visit]**
Kids can visit each other's gardens, see what's growing, and leave likes. Pip greets visitors with personalized messages. Coming soon: leave gifts, trade veggies, and compete in real-time mini-games via Game Center.

### 5. Plant Care System

**[Screenshot: Plot showing "Water me!" / "Pull weeds!" / "Help! Bugs!"]**
Plants don't just grow automatically — they need care. At 25% growth, weeds may appear (swipe to remove). At 50%, plants get thirsty (tap to water). At 75%, bugs may attack (tap ladybugs to rescue). Good care = better harvest yields.

---

## Key Contributions

As the **sole developer and designer**, I built every aspect of this project:

### iOS Development (Career Goal: iOS Developer)
- **SwiftUI Architecture** — Built 40+ views using MVVM pattern with @EnvironmentObject, @Published, and SwiftData @Model for reactive UI updates
- **SwiftData + CloudKit** — Designed a multi-user persistence layer using UUID-based model linking (no @Relationship — CloudKit compatible). Custom Codable decoders for backwards compatibility when adding new fields
- **API Integration** — Built 3 API clients:
  - USDA FoodData Central (nutrition data with caching)
  - Claude Haiku AI (kid-safe chatbot with rate limiting)
  - Apple WeatherKit (real weather → garden effects)
- **AVSpeechSynthesizer** — Text-to-speech system (PipVoice) with automatic best-voice selection, speaker buttons, and parent mute toggle
- **Gesture-Based Mini-Games** — 10 interactive games using DragGesture, TapGesture, LongPressGesture, and custom circular swipe detection
- **Animation Systems** — Frame-based character animation (30fps Timer), spring physics for UI feedback, particle effects for weather, staggered animation sequences for rewards

### UX Design
- **External UX audit** — Commissioned and implemented findings (shifted target age from 8-12 to 6+)
- **Accessibility** — Voice narration for pre-readers, 44pt minimum touch targets, inclusive avatar options (hijab, kippah, turban)
- **Visual consistency** — Created STYLES.md design system with banned color list, enforced AppTheme across all 40+ views

### Art Direction
- **Botanical watercolor aesthetic** — Curated and organized 285 image assets across 9 categories
- **Procreate workflow** — Planned batch extraction pipeline for hand-coloring all game assets on iPad

---

## Key Value Points

### For Children (Ages 6+)
1. **Builds healthy eating habits** through play, not lectures
2. **Teaches real nutrition science** using government data (USDA), not made-up facts
3. **Develops fine motor skills** through gesture-based cooking interactions
4. **Encourages responsibility** through plant care (watering, weeding)
5. **Fosters sibling bonding** through garden visits and future multiplayer

### For Parents
1. **Safe, ad-free environment** with no in-app purchases or external links
2. **Real nutrition education** backed by USDA data and Glucose Goddess research
3. **Parental controls** — PIN-protected dashboard, play time tracking
4. **Multiple children** — one device, separate profiles, equal experience
5. **Privacy-first** — Sign in with Apple, no third-party data sharing

### For the Market
1. **$5.99 one-time purchase** — sustainable via efficient API usage (~$0.60/child/month for AI)
2. **No subscription fatigue** — parents pay once, kids play forever
3. **Unique positioning** — no competing app combines growing + cooking + body education with real data

---

## Process

### Design Methodology

**Phase 1: Research & Planning (January 2026)**
- Researched career requirements for iOS Developer roles (Swift, SwiftUI, API integration, multi-user systems)
- Studied nutritional science: Jessie Inchauste's "Glucose Goddess" methodology for blood sugar-friendly recipes
- Analyzed competitor apps: Cooking Mama, Toca Kitchen, Khan Academy Kids
- Defined core game loop: GROW → COOK → FEED → REWARDS

**Phase 2: Core Build (February 2026)**
- Built garden system with 8 initial plants → expanded to 27
- Created 10 cooking mini-games with gesture recognition
- Implemented multi-user family system with SwiftData
- Designed avatar creator with inclusive options

**Phase 3: Integration & Polish (March 2026)**
- Integrated 3 external APIs (USDA, Claude AI, WeatherKit)
- Added plant care system (watering, weeding, bugs)
- Redesigned Body Buddy with animated health visualization
- Conducted and implemented external UX audit recommendations
- Built PipVoice text-to-speech for age 6+ accessibility
- Enforced visual consistency across all views (STYLES.md)

**Phase 4: Social & Multiplayer (Planned: March-April 2026)**
- Async social features (gifts, trading, message boards)
- Game Center real-time multiplayer mini-games
- Family leaderboards and cooperative recipes

### Iterative Refinement
- **UX Audit feedback** shifted target age from 8-12 to 6+, driving voice integration and text reduction
- **Testing on real device** revealed WeatherKit JWT propagation delays, PlotData Codable crashes, and profile persistence bugs — all resolved with logging and backwards-compatible decoders
- **Player testing** (creating child profiles, cooking recipes) revealed Body Buddy wasn't updating after cooking — built the nutrient→organ mapping system

### Tools Used
| Tool | Purpose |
|------|---------|
| Xcode 16 | IDE, building, simulator testing |
| iPhone (real device) | WeatherKit, CloudKit, location testing |
| Claude Code (CLI) | AI pair programming, code generation, debugging |
| Procreate (iPad) | Asset creation and hand-coloring |
| Git + GitHub | Version control |
| Figma | UI reference and planning |

---

## Technical Details

### Architecture
```
┌─────────────────────────────────────────────┐
│                 SwiftUI Views                │
│  (HomeView, GardenView, KitchenView, etc.)  │
├─────────────────────────────────────────────┤
│              ViewModels / State               │
│  GameState    SessionManager    AvatarModel   │
├─────────────────────────────────────────────┤
│              Services Layer                   │
│  PipVoice  USDAFoodService  GardenWeather    │
│  PipAIService  CloudKeyManager               │
├─────────────────────────────────────────────┤
│           SwiftData + CloudKit                │
│  FamilyProfile  UserProfile  PlayerData      │
├─────────────────────────────────────────────┤
│           Apple Frameworks                    │
│  WeatherKit  PencilKit  AVFoundation         │
│  AuthenticationServices  GameKit (planned)    │
└─────────────────────────────────────────────┘
```

### Tech Stack
| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9 |
| UI | SwiftUI with MVVM |
| Persistence | SwiftData + iCloud CloudKit |
| Auth | Sign in with Apple + Keychain |
| APIs | USDA FoodData Central, Claude Haiku, WeatherKit |
| Voice | AVSpeechSynthesizer |
| Drawing | PencilKit |
| Multiplayer | Game Center (planned) |
| Platform | iOS 16.0+ (iPhone & iPad) |

### By the Numbers
| Metric | Count |
|--------|-------|
| Swift source files | 40+ |
| Lines of code | ~15,000+ |
| Image assets | 285 |
| Vegetables/fruits | 27 |
| Pantry items | 19 |
| Recipes | 17 |
| Mini-game types | 10 |
| API integrations | 3 |
| Body organ systems | 9 |
| Pip character poses | 6 + walking + waving animations |

### Key Technical Challenges Solved
1. **SwiftData + CloudKit compatibility** — No @Relationship macros, UUID-based linking, all properties with defaults
2. **Codable backwards compatibility** — Custom `init(from:)` decoders so old saved data doesn't crash when new fields are added
3. **API response format mismatch** — USDA single-food endpoint returns nested JSON vs search endpoint's flat JSON; unified with computed accessors
4. **Silent data loss** — Replaced all `try? context.save()` with `do/catch` logging to catch persistence failures
5. **WeatherKit JWT auth** — Entitlements, provisioning profile regeneration, and Apple server propagation timing

---

## Career Goal Connection

My career goal is to become an **iOS Developer** specializing in educational and family-focused apps. This project directly demonstrates the skills employers look for:

| Employer Requirement | How This Project Demonstrates It |
|---------------------|----------------------------------|
| SwiftUI proficiency | 40+ views with complex state management, animations, gestures |
| API integration | 3 production APIs (USDA, Claude AI, WeatherKit) with caching and error handling |
| Data persistence | SwiftData + CloudKit with multi-user architecture and schema migration |
| Security awareness | Keychain PIN storage, API key protection, Sign in with Apple |
| UX/Accessibility | Voice narration, inclusive design, UX audit implementation |
| Code quality | Design system (STYLES.md), consistent architecture (MVVM), comprehensive documentation |
| Ship-ready mindset | Real device testing, backwards compatibility, graceful error handling |

---

## Reflection

### Strengths
- **Full-stack iOS skills** — I built every layer: UI, state management, persistence, networking, animation
- **Real API integration** — Not just mock data; the app fetches real nutrition from the US government's database
- **User-centered design** — The UX audit drove real changes (voice for younger kids, simplified text, inclusive avatars)

### Challenges
- **SwiftData + CloudKit constraints** — No @Relationship macros forced creative UUID-based solutions
- **WeatherKit activation delays** — Apple's server propagation took longer than documented
- **Balancing education and fun** — Raw nutrient data is boring; translating to "superpowers" required creative design thinking

### Growth Areas
- **Testing** — Need to add XCTest unit tests for GameState and API services
- **Performance** — Profile large garden views on older devices
- **Multiplayer** — Game Center integration is the next major skill to learn

---

*Pip's Kitchen Garden is an ongoing project. Final submission: May 15, 2026.*

<p align="center"><strong>Thank you!</strong></p>
