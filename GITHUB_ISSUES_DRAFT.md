# GitHub Issues Draft — ChefAcademy backlog

Paste each issue below into github.com/GEM-312/ChefAcademy/issues/new. Copy the title into the title field, the body into the body field. Add the suggested label(s) before saving.

After you create them, drag them onto the Roadmap Project with the rough date estimates noted at the bottom of each issue.

Delete this file once all issues are created (or commit it as a snapshot of your launch backlog — your call).

---

## 🔴 P0 — Pre-May 15 (this week, your action)

### Issue 1 — TestFlight upload pending since May 2

**Labels:** `P0`, `release`, `blocked-by-marina`

**Body:**
The current TestFlight build (build 4) was uploaded May 4 with the Phase 2 P1 fixes. Phase 3 (commit `50fc377`, May 10) and the May 10 evening sweep (`5ebbb91` through `15d1372`, 13 commits) have not been shipped to testers yet.

Tomorrow's reviewers should test on the latest design-system-clean code, not the May 4 build.

**Acceptance:**
- [ ] `xcrun agvtool next-version -all` to bump build number
- [ ] `./toggle_odr.sh on` (per `feedback_odr_toggle.md`)
- [ ] Xcode → Any iOS Device (arm64) destination
- [ ] Product → Archive
- [ ] Organizer → Distribute App → App Store Connect → Upload
- [ ] Wait for ASC processing email (~15-60 min)
- [ ] Add new build to existing TestFlight tester group
- [ ] Notify testers there's a new build

**Estimate:** ~30 min active, +60 min waiting for ASC processing.

---

### Issue 2 — Replace placeholder App Review screenshot for Pip Chat subscription

**Labels:** `P0`, `release`, `app-store-connect`

**Body:**
The Pip Chat subscription product in App Store Connect currently has a placeholder PNG (text-only "Pip Chat" image) uploaded via API. App Review may flag this.

**Acceptance:**
- [ ] Take a real screenshot of the paywall from the running app (640×920+ resolution)
- [ ] Upload via App Store Connect → Subscriptions → Pip Chat → Review Information → Screenshot

**Reference:** [reference_asc_api_key.md] — API endpoint is `/v1/subscriptionAppStoreReviewScreenshots`.

**Estimate:** ~15 min.

---

### Issue 3 — Voice review of PipStaticResponses.swift

**Labels:** `P0`, `content`, `pip-voice`

**Body:**
~20 hand-written Pip starter responses + ~30 fun-fact wildcards live in `PipStaticResponses.swift`. Claude wrote them from a system prompt; Marina knows Pip's voice better and should tweak any that feel off.

Pip's voice traits:
- Curious 6-year-old's friend, not a teacher
- Excited about veggies but never preachy
- Short sentences with energy
- No medical/clinical vocab ("glucose", "insulin" → already banned)
- Encourages, never shames

**Acceptance:**
- [ ] Open `ChefAcademy/PipStaticResponses.swift`
- [ ] Read each starter response aloud — does it sound like Pip?
- [ ] Read each fun-fact wildcard — same test
- [ ] Tweak any that don't pass the read-aloud test
- [ ] Commit with `Closes #3` in message

**Estimate:** ~45 min.

---

## 🟠 P1 — Post-launch (June)

### Issue 4 — Parent avatars need visual distinction from children

**Labels:** `P1`, `ux`, `onboarding`, `needs-design-decision`

**Body:**
In `FamilySetupView FamilyAvatarStep` and `AddChildFlowView`, parents and children pick from the same boy/girl card frame avatars. Result: in `ProfilePickerView`, parent and child cards look near-identical except for a small crown + lock icon. Hard to tell who is the parent at a glance.

**Open design questions:**
1. Separate adult illustration set (different from kid cards), OR badge overlay (chef hat, glasses) on top of any avatar, OR distinct frame color?
2. If new assets: same botanical watercolor style, or signal "adult" with different style?
3. Migration: existing families that already chose a child-style avatar for the parent — migrate, or leave alone?

**Files affected:** `AvatarModel.swift`, `AvatarCreatorView.swift`, `FamilySetupView.swift`, `ProfilePickerView.swift`, `Assets.xcassets/AvatarCards/`.

**Reference:** [project_parent_avatar_distinction.md] in memory.

**Acceptance:**
- [ ] Decision made on approach
- [ ] If new assets needed: list created
- [ ] Implementation
- [ ] Build clean

**Estimate:** 1-3 hours depending on approach (badge overlay = 1hr; separate asset set = 3hr + asset creation time).

---

### Issue 5 — Animate static Pip images across components

**Labels:** `P1`, `ux`, `pip-animation`

**Body:**
`PipSpeechBubble`, `PipHeaderStack`, and `PipJourneyMessage` all render Pip as a static `Image(pose.rawValue)`. Pip looks alive in some places (animated waving via `PipWavingAnimatedView`) but frozen in others (chat bubbles, header stacks, GlucoseJourney). Inconsistent.

**Open question:** Should ALL Pip instances animate, or only the "speaking" ones? Some places (small inline avatars) might look noisy with constant animation.

**Suggested approach:**
- Add `animated: Bool = true` parameter to `PipSpeechBubble` / `PipHeaderStack`
- When true, use `PipWavingAnimatedView` instead of `Image`
- When false (decorative usage), keep static
- Default to true for all current call sites

**Files affected:** `PipComponents.swift`, `PipAnimations.swift`, all call sites of the above components.

**Acceptance:**
- [ ] Decision made on which sites animate
- [ ] `PipSpeechBubble` updated with optional animated render
- [ ] `PipHeaderStack` updated similarly
- [ ] `PipJourneyMessage` updated (or replaced with `PipSpeechBubble` if Marina's "raw image" preference relaxes)
- [ ] Visual check across the app

**Estimate:** 1-2 hours.

---

### Issue 6 — Subscription Phase 2: Pip Chat + Voice tier ($9.99/mo)

**Labels:** `P1`, `monetization`, `subscriptions`

**Body:**
Phase 1 (Pip Chat $3.99) is live. Phase 2 adds the higher tier with ElevenLabs voice everywhere (cooking, dialogs, NPC greetings).

**Full spec:** [project_subscription_phase2.md] in memory.

**Critical for cost control:** Build-time audio pre-generation pipeline (cache static dialog as bundled `.mp3`s) — without caching, ElevenLabs eats ~$67/mo per heavy user, which would lose money on $9.99/mo tier.

**Acceptance:**
- [ ] ASC subscription product `pipchatvoice.monthly` at $9.99
- [ ] `SubscriptionManager` refactored to 2-tier enum (`PipTier { none, chat, chatVoice }`)
- [ ] Build-time audio pre-gen script (`Scripts/generate_static_audio.py`)
- [ ] Per-device `.mp3` cache with LRU eviction (max 100MB)
- [ ] Per-tier daily voice cap (15 min trial / 60 min paid)
- [ ] `PipVoicePlayer` coordinator routes between AVSpeech / cached / live ElevenLabs
- [ ] Sandbox-tested
- [ ] Live in ASC

**Estimate:** ~3.5 hours total per the plan.

**Dependencies:** Phase 1 must be stable in TestFlight first.

---

### Issue 7 — ElevenLabs license: upgrade to Starter + redownload SFX

**Labels:** `P1`, `licensing`, `pre-app-store-submission`

**Body:**
Current ElevenLabs account is on Free/PAYG tier. Commercial license records require a paid tier (Starter is $6/mo cheapest).

Without paid tier records, App Store may flag the 5 ambient SFX files (used by `AmbientAudioPlayer.swift`) as having no commercial license attached.

**Acceptance:**
- [ ] Upgrade elevenlabs.io account Free/PAYG → Starter ($6/mo)
- [ ] Redownload all 5 ambient SFX files (so each download is recorded under the paid plan)
- [ ] Replace files in `Assets.xcassets` if needed
- [ ] Keep download receipts / invoices in case of App Review query

**Estimate:** ~30 min including transactions.

---

## 🟡 P2 — Post-launch polish (July+)

### Issue 8 — Adaptive layout: iPhone landscape + iPad landscape support

**Labels:** `P2`, `ux`, `adaptive-layout`

**Body:**
All major views are tuned for iPhone portrait and iPad portrait. Landscape on either device shows broken layouts (overflows, fixed-height elements, spacing meant for narrow screens).

**Affected views (priority order):**
- HomeView — primary entry
- GardenView — most-used
- KitchenView
- BodyBuddyView
- PlayLearnView
- ProfilePickerView

**Acceptance:**
- [ ] Add `@Environment(\.verticalSizeClass)` checks where needed
- [ ] Use `AdaptiveCardSize` tokens (already defined for portrait; extend for landscape variants)
- [ ] Test on iPhone 17 Pro landscape + iPad landscape
- [ ] No overflow at any orientation

**Estimate:** ~4-6 hours across views.

---

### Issue 9 — Allergen setup in onboarding flow

**Labels:** `P2`, `safety`, `onboarding`

**Body:**
Allergens are currently only editable via Parent Dashboard (after a child is set up). Should be part of initial family setup so the first recipe gen is allergen-aware.

**Acceptance:**
- [ ] Add `AllergenPickerStep` into `FamilySetupView` flow (after child name/avatar, before "Meet Pip")
- [ ] Save allergens to child's `UserProfile.foodAllergens`
- [ ] First recipe gen respects allergens

**Estimate:** ~1 hour.

---

### Issue 10 — Missing veggie image assets (19 of 27)

**Labels:** `P2`, `assets`, `marina-action`

**Body:**
27 plants in `VegetableType` enum, only 8 have botanical watercolor images. The other 19 fall back to placeholder.

**Missing assets** (botanical watercolor style, transparent background):
spinach, bellpepper_red, bellpepper_yellow, sweetpotato, corn, beet, eggplant, radish, kale, basil, mint, greenbeans, strawberry, watermelon, avocado, lemon, blueberry, raspberry, blackberry

**Acceptance:**
- [ ] Each asset added to `Assets.xcassets/Vegetables/`
- [ ] Imageset name matches `VegetableType.imageName` for each case
- [ ] Visually consistent with existing 8 (lettuce, carrot, tomato, cucumber, broccoli, zucchini, onion, pumpkin)

**Estimate:** ~1-2 hours per asset (Marina draws), so ~30-40 hours total. Can be done incrementally.

---

### Issue 11 — SpriteKit physics rebuild for Healthy Picks games

**Labels:** `P2`, `performance`, `games`

**Body:**
Healthy Picks variants currently use SwiftUI `TimelineView` for physics. Acceptable but limited — no real collision, no particles at scale, frame-rate ceiling.

SpriteKit rebuild would give:
- Real physics (food bounces off walls, gravity, collisions)
- GPU-accelerated particles (juice splashes, confetti via `SKEmitterNode`)
- Better performance under load
- Easier to add power-ups, obstacles

**Affected:** `HealthyChoiceGameView`, `LocalVersusView`, `MultiplayerHealthyPicksView`, `NearbyVersusView`, `SplitScreenVersusView`. InsulinTetris already has SpriteKit-style physics in pure SwiftUI.

**Acceptance:**
- [ ] Single shared `FoodPhysicsScene: SKScene` extracted
- [ ] One game view migrated as proof of concept (probably HealthyChoiceGameView)
- [ ] Other 4 games migrated using the same scene
- [ ] Multiplayer sync still works
- [ ] Visual parity or improvement

**Estimate:** ~6-10 hours.

---

### Issue 12 — Body Buddy figure asset from Procreate

**Labels:** `P2`, `assets`, `body-buddy`, `marina-action`

**Body:**
`BodyBuddyView` shows organ rings without a body figure outline. Procreate-drawn figure (`body_buddy_figure.png` or similar) would visually anchor the organs.

**Acceptance:**
- [ ] Procreate illustration of a kid-friendly body outline (transparent background)
- [ ] Add to `Assets.xcassets/BodyBuddy/`
- [ ] Wire into `BodyBuddyView` behind/around the organ rings

**Estimate:** Asset creation 1-2 hours, integration ~30 min.

---

### Issue 13 — Cloudflare Phase 4: delete CloudKeyManager + AppConfig record

**Labels:** `P2`, `tech-debt`, `cleanup`

**Body:**
Pre-Phase-2c, API keys lived in CloudKit public DB and were fetched at runtime via `CloudKeyManager.swift`. Phase 2c+2d migration (May 2, commit `f6a9ac8`) replaced this with Cloudflare Worker + App Attest. CloudKit fetch path is dead.

**Acceptance:**
- [ ] Delete `ChefAcademy/CloudKeyManager.swift`
- [ ] Remove all references / imports
- [ ] Delete the AppConfig record from CloudKit Dashboard (container `iCloud.GraphicElegance.ChefAcademy` → Public DB → AppConfig record `pipAPIKey`)
- [ ] Build clean

**Estimate:** ~20 min.

---

## 🔵 Tech debt / housekeeping

### Issue 14 — Investigate May 10 routine abort recurrence

**Labels:** `P3`, `routines`, `monitoring`

**Body:**
On May 10 morning the weekly review routine fired but pushed nothing — root cause was GitHub App permission re-grant required (HTTP 403 on push). Marina re-accepted permissions and the routine then worked (`164538d` landed at 15:36).

**Question:** does it stay working? Tue May 12 06:04 CDT will be the next scheduled run. If it pushes a `WEEKLY_REVIEW_2026-05-12.md` automatically, we're good. If not, dig deeper.

**Reference:** [project_session_may10_evening_summary.md] — "Routine GitHub auth (resolved)" section.

**Acceptance:**
- [ ] Tue May 12: check git for new commit from routine
- [ ] If commit landed: close this issue
- [ ] If not: open the routine logs at https://claude.ai/code/routines/trig_01JSoZmJW7QwYR7Vz3a7CNqn and diagnose

**Estimate:** ~5 min on Tuesday.

---

## 🗓️ Roadmap suggested timeline

When you set up the Project's Roadmap view, drag these onto the timeline with rough estimates:

| Issue | Suggested target | Notes |
|---|---|---|
| 1 — TestFlight upload | This week (May 11-12) | Blocking May 15 |
| 2 — App Review screenshot | This week (May 11-12) | Blocking May 15 |
| 3 — PipStaticResponses voice review | This week (May 11-13) | Blocking May 15 |
| 14 — Routine recurrence check | May 12 | One-shot Tuesday check |
| 4 — Parent avatar distinction | Late May / early June | Post-launch polish |
| 5 — Animate static Pips | Early June | Post-launch polish |
| 7 — ElevenLabs license stamp | Early June | Pre-Phase-2 dependency |
| 6 — Subscription Phase 2 | June (3.5 hrs over 1-2 wks) | Major feature |
| 8 — Adaptive landscape layout | July | Polish |
| 9 — Allergen onboarding step | July | Safety polish |
| 11 — SpriteKit physics rebuild | July-August | Heavier feature |
| 13 — Cloudflare Phase 4 cleanup | August (low priority) | 20 min, anytime |
| 10 — 19 missing veggie assets | Ongoing through Q3 | Marina draws incrementally |
| 12 — Body Buddy figure asset | Ongoing | Marina draws when inspired |
