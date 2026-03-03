# Testing Plan: Pip's Kitchen Garden

---

## Overview

**Project Title:** Pip's Kitchen Garden

**Build Version:** 1.0 Prototype (March 2026)

**Platform:** iOS 16.0+ (iPhone & iPad) — SwiftUI + SwiftData

**Facilitator(s):** Marina Pollak

**Tester(s):** [To be filled after sessions — target: 3-5 testers, ages 9-12]

**Date:** [To be filled per session]

**Project Context:** Pip's Kitchen Garden is an educational iOS cooking game for children ages 9-12. Players grow vegetables in a garden, buy pantry items at a farm shop, cook recipes through interactive mini-games, and learn about nutrition — all guided by Pip, a friendly hedgehog chef. The app is built entirely in Swift using SwiftUI, SwiftData for persistence, and custom gesture recognition for gameplay interactions.

**Technology Stack:** Swift 5.9, SwiftUI, SwiftData, PencilKit, Combine, MVVM architecture

**Current Prototype Status:** The core game loop (Grow, Cook, Rewards) is functional. The Body Buddy nutrition journey feature is not yet implemented. 9 of 27 vegetable image assets are complete; mini-games use placeholder emoji art.

---

## Tasks

The following tasks define what this testing plan aims to validate. Each task targets a specific aspect of the player experience and maps to a core SwiftUI development skill.

### Task 1: Complete the Onboarding Flow and Navigate the App

**What we are validating:** Can a first-time player create their avatar, meet Pip, and independently discover and navigate between the five main tabs (Home, Garden, Kitchen, Farm, Recipes)?

**Why this matters:** Navigation architecture is a foundational SwiftUI skill. This task validates that the TabView structure, .fullScreenCover presentations, and @AppStorage-based onboarding gating work correctly and intuitively for the target age group.

**Connection to professional goal:** iOS/SwiftUI developer roles require building intuitive navigation hierarchies. Apple's Human Interface Guidelines emphasize that users should always know where they are and how to get where they want to go. This task tests whether the app's navigation meets that standard.

### Task 2: Grow a Vegetable (Plant, Water, Harvest)

**What we are validating:** Can the player discover and execute the three core garden gestures — tap to plant, swipe to water, drag Pip to harvest — without instruction beyond what the UI provides?

**Why this matters:** This task validates custom gesture recognizer implementation (DragGesture, SwipeGesture, TapGesture), state machine transitions in PlotView, and the draggable character interaction (proximity detection, coordinate geometry). These are intermediate-to-advanced SwiftUI interaction patterns.

**Connection to professional goal:** SwiftUI developer job postings consistently list "custom gesture handling," "interactive animations," and "state management" as required skills. This task directly exercises all three.

### Task 3: Cook a Recipe Through the Full Mini-Game Sequence

**What we are validating:** Can the player select a recipe, understand the ingredient requirements, and complete a multi-step cooking session (9 possible mini-game types) to earn a star rating?

**Why this matters:** This is the most complex user flow in the app. It validates the CookingSessionView state machine, dynamic step generation from recipe data, 9 distinct mini-game gesture interactions (hold, drag, circular swipe, rapid tap, timed tap, swipe-down), the scoring system, and the transition between views. It also tests whether SwiftUI's @State and @Binding correctly propagate across deeply nested child views.

**Connection to professional goal:** Senior iOS developer roles require architects who can build complex, multi-screen flows with clean state management. This task tests the kind of view composition, data flow, and interactive animation work that distinguishes a strong SwiftUI portfolio piece.

---

## Observation Notes

*Copy this section for each tester. Fill in during and immediately after each session.*

### Session Info

**Tester ID:** [e.g., Tester 1, Tester 2 — no real names for minors]

**Age:**

**Date/Time:**

**Device Used:** [iPhone model / iPad / Simulator]

**Session Duration:**

---

### Task 1: Onboarding and Navigation

**Scenario:** The tester opens the app for the first time. They have never seen the app before. No instructions are given beyond "Try out this game and explore."

**Success Criteria:**
- Completes avatar creation (gender, outfit, head covering, name) without assistance
- Reads or engages with Pip's introduction dialogue
- Lands on the Home tab and identifies at least 3 of the 5 tabs by purpose
- Navigates to at least 2 other tabs independently within 2 minutes of reaching Home

**Completed successfully?** [ ] Yes [ ] Partially [ ] No

**Time to complete key objectives:**
- Avatar creation: ___ minutes
- First independent tab switch: ___ minutes
- Identified all tabs: ___ minutes

**Areas of user/player confidence:**


**Errors encountered:**


**Observed confusion points:**


**Points where user/player hesitated (uncertainty instead of confusion):**


**Verbal confusion moments or signs of frustration:**


**Unexpected behavior:**


**User/player comments:**


---

### Task 2: Grow a Vegetable

**Scenario:** The tester is told "Go to the garden and try to grow something." No further guidance is provided about gestures.

**Success Criteria:**
- Navigates to the Garden tab
- Taps an empty plot to open the PlantingSheet
- Selects a seed and plants it
- Discovers the swipe-to-water gesture (with or without prompting — note which)
- Discovers the drag-Pip-to-harvest interaction when the plot is ready
- Sees coins awarded after harvest

**Completed successfully?** [ ] Yes [ ] Partially [ ] No

**Time to complete key objectives:**
- Found Garden tab: ___ minutes
- First seed planted: ___ minutes
- Discovered watering (swipe): ___ minutes — Prompted? [ ] Yes [ ] No
- Completed harvest (drag Pip): ___ minutes — Prompted? [ ] Yes [ ] No

**Areas of user/player confidence:**


**Errors encountered:**


**Observed confusion points:**


**Points where user/player hesitated (uncertainty instead of confusion):**


**Verbal confusion moments or signs of frustration:**


**Unexpected behavior:**


**User/player comments:**


---

### Task 3: Cook a Recipe

**Scenario:** The tester is told "Try cooking something!" They must find the Kitchen or Recipes tab, select a recipe, and complete the cooking session mini-games.

**Success Criteria:**
- Finds and selects a recipe (via Kitchen tab or Recipes tab)
- Views the RecipeDetailView and taps "Let's Cook!"
- Completes at least 5 of the generated cooking steps (mini-games)
- Reaches the CookingCompletionView and sees their star rating
- Understands the scoring feedback (stars earned)

**Completed successfully?** [ ] Yes [ ] Partially [ ] No

**Time to complete key objectives:**
- Recipe selected: ___ minutes
- Started cooking session: ___ minutes
- Full cooking session completed: ___ minutes

**Mini-game performance (note difficulty for each encountered):**

| Mini-Game | Encountered? | Completed? | Struggled? | Notes |
|-----------|-------------|------------|------------|-------|
| Heat Pan (hold) | | | | |
| Add to Pan (drag) | | | | |
| Wash (rapid tap) | | | | |
| Peel (swipe down) | | | | |
| Chop (tap timing) | | | | |
| Stir (circular swipe) | | | | |
| Season (tap sprinkle) | | | | |
| Cook Timer (green zone) | | | | |
| Assemble (tap to plate) | | | | |

**Areas of user/player confidence:**


**Errors encountered:**


**Observed confusion points:**


**Points where user/player hesitated (uncertainty instead of confusion):**


**Verbal confusion moments or signs of frustration:**


**Unexpected behavior:**


**User/player comments:**


---

## UI / UX

**Was the interface easy to understand?**


**Any unclear menus or icons?**


**Readability issues?** (font sizes, color contrast, text length for age group)


**Touch target observations:** (Were buttons and interactive elements easy for kids to tap? Any missed taps?)


**Visual style reaction:** (Did the tester respond to the watercolor/botanical art style? Any comments?)


---

## Technical Issues

**Bugs encountered:**


**Performance issues (lag, crashes, long loads):**


**Platform-specific problems:** (iPhone vs. iPad differences, simulator vs. device)


**SwiftUI rendering issues:** (Layout glitches, animation stuttering, incorrect state updates)


**Data persistence issues:** (Did progress save correctly? Any loss of coins/inventory?)


---

## Game Design

**Mechanics:** How did the tester respond to the core mechanics (tapping, swiping, dragging)? Were any gestures unintuitive?


**Difficulty and balance:** Were the mini-games too easy, too hard, or well-balanced for the age group? Was the coin economy balanced (earning vs. spending)?


**Game feel:** Did interactions feel responsive and satisfying? Did animations provide adequate feedback?


**Level design / progression:** Did the tester understand the progression loop (grow vegetables to get ingredients, buy pantry items, cook recipes)? Did they feel a sense of advancement?


**Story/narrative/characters:** How did the tester respond to Pip? Did they read Pip's dialogue? Did Pip's tips feel helpful or ignored?


**Emotional reaction:** What emotions did you observe (joy, frustration, boredom, curiosity, pride)? At what moments?


**Comparison to other titles:** Did the tester compare the game to anything they've played before? What?


**Engagement and replay:** Did the tester want to keep playing after finishing the tasks? Did they ask to try more recipes or grow more vegetables?


---

## Additional Observations

**Educational content engagement:** Did the tester learn or mention anything about nutrition, vegetables, or cooking? Did they engage with Glucose Goddess tips? Did they use the SeedInfoView (educational veggie pages) or PencilKit coloring?


**Accessibility notes:** Any issues for the target age group related to reading level, motor skill requirements, or cultural content?


**Feature requests from tester:** What did the tester wish the game had?


---

## Summary

### Part 1: Connecting the Testing Plan to Professional Goals

This testing plan is designed to produce evidence of skills required for iOS Developer and SwiftUI Developer positions. Based on research of job postings for these roles, employers consistently require the following competencies — each of which this testing plan directly exercises and validates:

**1. SwiftUI Proficiency and Custom UI Development**

iOS developer job postings list SwiftUI as a primary requirement, with emphasis on building "custom, interactive user interfaces" and "fluid animations." This prototype demonstrates advanced SwiftUI capabilities: custom gesture recognizers (DragGesture, SwipeGesture, simultaneous gesture composition), spring-based animations, .fullScreenCover modal presentations, and complex view hierarchies. Testing with real users validates that these implementations work correctly in practice, not just in isolation.

Task 2 (Garden gestures) and Task 3 (mini-game interactions) directly test 6+ distinct gesture types — the kind of interactive UI work that differentiates a strong iOS portfolio from a basic one.

**2. State Management and Architecture (MVVM)**

Job postings for mid-to-senior SwiftUI roles require "clean architecture," "MVVM or similar patterns," and "experience with Combine or async/await." Pip's Kitchen Garden uses the MVVM pattern with ObservableObject (GameState), @EnvironmentObject injection, SwiftData persistence with auto-save via Combine debouncing, and Codable model serialization. Testing validates that state flows correctly across deeply nested views — a common failure point in real-world SwiftUI apps.

Task 1 (onboarding) tests @AppStorage gating and initial state setup. Task 3 (cooking) tests complex @State propagation through a multi-screen flow with 9 child views.

**3. User-Centered Design and Iterative Development**

Apple's own job postings for iOS roles emphasize "user empathy," "iterative refinement based on user feedback," and "collaboration with design teams." This testing plan implements a structured usability testing methodology: defined tasks, measurable success criteria, timed observations, and a feedback loop that feeds findings into the next development iteration.

The observation framework captures exactly the kind of data a professional development team would collect: gesture discoverability rates, task completion times, frustration points, and feature requests.

**4. Debugging and Quality Assurance**

Every iOS developer posting requires debugging skills. This testing plan's Technical Issues section systematically captures SwiftUI rendering problems, state management bugs, data persistence failures, and performance issues — the same categories that a QA process at a professional studio would track.

**5. Shipping a Complete Product**

The strongest signal in a developer portfolio is a shipped product. This testing plan moves the prototype from "works on my machine" toward "tested with real users" — the professional standard for App Store readiness. The ability to plan, execute, and analyze user testing is a skill gap that many junior developers have; demonstrating it provides concrete evidence of professional-level development practice.

**How this testing plan progresses toward the goal:** By executing these test sessions and documenting findings, this project produces two forms of career evidence: (1) a portfolio piece demonstrating advanced SwiftUI development — custom gestures, complex state management, SwiftData persistence, interactive animations, PencilKit integration; and (2) documented user testing methodology showing the ability to iterate based on real feedback, which is the development workflow used at professional iOS studios.

---

### Part 2: Findings and Next Iteration

*[To be completed after test sessions are conducted]*

**Test Session Summary:**

| Metric | Result |
|--------|--------|
| Number of testers | |
| Onboarding completion rate (unaided) | |
| Garden task success rate (unaided) | |
| Cooking task success rate (unaided) | |
| Average session duration | |
| "Would play again" rate | |
| Average engagement rating (1-5) | |

**Top 3 Successes (what worked well):**

1.
2.
3.

**Top 3 Issues (what needs improvement):**

1.
2.
3.

**Gesture Discoverability Results:**

| Gesture | Discovered Without Prompting (%) | Notes |
|---------|----------------------------------|-------|
| Tap to plant | | |
| Swipe to water | | |
| Drag Pip to harvest | | |
| Hold to heat pan | | |
| Circular swipe to stir | | |
| Swipe down to peel | | |

**Changes for Next Iteration:**

Based on test findings, the following changes will be prioritized for the next build:

1. **[Area]:** [Specific change based on observation]
2. **[Area]:** [Specific change based on observation]
3. **[Area]:** [Specific change based on observation]
4. **[Area]:** [Specific change based on observation]
5. **[Area]:** [Specific change based on observation]

**How findings inform SwiftUI development skills:**

[Reflect on what the testing revealed about your SwiftUI implementation — which patterns worked well, which need refactoring, and what new techniques you need to learn for the next version.]

---

*Prepared by Marina Pollak*
*PROG-360A Project Studio — Columbia College Chicago*
*March 2026*
