# Usability Test Script — Pip's Kitchen Garden

**Facilitator:** Marina Pollak
**App:** Pip's Kitchen Garden (Little Chef Academy)
**Method:** Steve Krug "think-aloud" usability testing
**Session length:** ~40 min per tester (intro 3 + tasks 25 + debrief 10 + buffer 2)

---

## Before the session — facilitator prep

- Fully reset app data on the test device (simulator or physical). Command:
  `find ~/Library/Developer/CoreSimulator/Devices -name "default.store*" -path "*/Application Support/*" -exec rm -f {} \;`
- Set device volume low (Pip voice is on) but audible.
- Have this script + Observer Notes open.
- Optional: record screen (QuickTime → New Movie Recording → select device).

---

## Facilitator ground rules (read silently, apply always)

1. **You are not the designer today.** Don't defend the design. Don't explain. Don't hint.
2. **Silence is data.** If the tester hesitates, wait. Count to 10 before prompting.
3. **Only prompt: "What are you thinking?" or "What were you expecting to happen?"** Never "the button is in the corner."
4. **It's not the tester's fault.** If they struggle, that's a design problem.
5. **Don't lead.** "What would you do next?" — never "Try tapping X."

---

## Intro script (read aloud, ~2 min)

> Thanks for helping. This is a test of the app, not of you — there are no wrong answers. If something's confusing, that's exactly what I need to know.
>
> I'm going to ask you to try some tasks. As you go, please **think out loud** — say whatever comes to mind, even if it sounds obvious. "I'm looking for the garden," "I'm not sure what this button does," "this is confusing" — all of that is helpful.
>
> If you get stuck, that's fine — just tell me what you'd normally do. I can't help you during the tasks, so just do your best.
>
> The target audience is a 6-to-8-year-old child, so try to imagine you're helping a kid — or just react however feels natural.
>
> One more thing — is it OK if I record the screen during this session? Your voice won't be recorded, just taps and gestures. [Get verbal OK before recording.]

---

## Warm-up question (1 min)

Ask before handing them the device:

> When you hear "cooking game for kids," what do you picture? What would you expect it to do?

*(Capture their mental model — compare to actual app later.)*

---

## Tasks

**For each task:** read the scenario aloud, hand them the device, stay quiet. Start timer. Note completion and observations. If stuck for 2+ min, skip to next.

---

### Task 1 — First-launch setup (target: 5 min)

> You just downloaded this app for your family. Set it up — a parent profile for you, and one child profile for a pretend 7-year-old named "Alex."

**Watch for:**
- Do they understand the 8-step wizard?
- PIN setup — confusion about why they need it?
- Do they complete both parent + child, or stop at parent?
- Avatar choices — confused by gender/head covering/outfit?

**Success:** reached the main Home tab as Alex.

---

### Task 2 — Plant and grow (target: 3 min)

> You're now playing as Alex. Plant something in the garden. If the plant needs anything while it grows, give it what it needs.

**Watch for:**
- Do they find the Garden tab?
- Do they tap a plot to plant, or try to drag seeds?
- Do they notice water/weed/bug states?
- Do they harvest when ready?

**Success:** planted a seed, completed at least one care action.

---

### Task 3 — Earn coins and buy new seeds (target: 4 min)

> Alex wants to try growing something new but doesn't have enough coins. Figure out how to get more coins, then buy at least one new kind of seed.

**Watch for:**
- Do they discover the Shop tab?
- Do they find the seed bags?
- Do they tap a seed bag to open the knowledge card?
- Do they understand they earn coins by tapping nutrients / coloring?
- Time to first coin earned.

**Success:** earned coins through the knowledge card flow and completed a purchase.

---

### Task 4 — Cook a recipe (target: 5 min)

> Using something Alex has harvested, cook a recipe.

**Watch for:**
- Do they find the Kitchen tab?
- Do they find the recipe book (book icon)?
- Do they understand the mini-games?
- Which mini-game is most confusing? Most delightful?
- Star rating — do they understand how it's earned?

**Success:** completed a full cooking session, saw completion screen.

---

### Task 5 — Check the body + learn something (target: 3 min)

> Alex wants to see how what they just cooked affects their body, and learn something about the food they ate.

**Watch for:**
- Do they navigate to Body Buddy?
- Do they understand the organ rings?
- Do they try Play/Learn or Ask Pip?

**Success:** opened Body Buddy OR asked Pip a question OR opened a food knowledge card.

---

### Task 6 — Switch profiles (target: 2 min)

> Now switch back to the parent account and check on Alex's progress.

**Watch for:**
- Do they find the Switch Player option (on Home)?
- PIN re-entry — friction?
- Do they reach the Parent Dashboard?
- Do they understand what the dashboard shows?

**Success:** reached Parent Dashboard, identified Alex's stats.

---

## Debrief questions (5 min — open-ended, conversational)

1. What was the clearest part of the app to you?
2. What was the most confusing?
3. How old do you think this app is made for? Why?
4. Do you think a 7-year-old could use this on their own? What would stop them?
5. If you could change one thing right now, what would it be?
6. Was there any moment you smiled or laughed? Any moment you felt frustrated?
7. Did anything surprise you in a good way? In a bad way?

---

## Consent form (one-liner — use if recording)

> I agree to participate in a usability test of Pip's Kitchen Garden for the PROG-360A course. My screen actions may be recorded for the facilitator's review. My name will not appear in the final report.
>
> Name: __________________  Date: __________  Signature: __________________

---

## After each session — facilitator debrief (5 min alone)

Write down **immediately**, before memory fades:
- Top 3 things that went wrong
- One quote that stuck with you
- One thing that worked unexpectedly well
