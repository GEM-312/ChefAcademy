# Usability Test Report — Pip's Kitchen Garden

**Author:** Marina Pollak
**Course:** PROG-360A Project Studio, Columbia College Chicago
**Instructor:** Janell Baxter
**Date:** 2026-04-19
**Status:** Interim submission — methodology and scripts complete; testing sessions scheduled for 2026-04-20. Findings and actionable plan will be submitted as an addendum after sessions conclude.

---

## Overview

### Project
**Pip's Kitchen Garden** (working title: Little Chef Academy) — an iOS SwiftUI game for ages 6+ that teaches healthy eating through a core loop: **grow vegetables → cook recipes → feed a Body Buddy → earn rewards**. Built on the nutrition research of Jessie Inchauspé ("Glucose Goddess"), with a Pip hedgehog mascot guide.

### Purpose of testing
Validate whether classmates (as adult stand-ins for the target child user) can discover, understand, and complete the app's core loop without facilitator help. The app has been through an external UX audit (March 2026) and a component/theme refactor; this test targets fresh-eyes reactions to the current build.

### Qualitative aspects tested
- Discoverability of the 6 tabs and their purposes
- Understanding of the learn-to-earn coin system (knowledge cards)
- Clarity of the cooking mini-games (9 types)
- Emotional response to Pip the mascot
- Onboarding friction (8-step family setup)
- Navigation between parent and child profiles

### Quantitative aspects tested
- Task completion rate (% of tasks completed without facilitator help)
- Task completion time (relative to target times in the script)
- Severity of issues per task (1–5 scale from observer notes)
- Number of "stuck" moments per participant

### Success criteria
- ≥ 80% task completion rate across all participants without hints
- Mean completion time within 1.5× target per task
- Fewer than 2 severity-4-or-5 (showstopper) issues per participant
- Debrief shows participants can articulate the app's core loop in their own words

---

## Methodology

### Participant recruitment
- **Source:** PROG-360A classmates (peer review)
- **Count:** 3 testers (Steve Krug's recommended minimum — surfaces ~80% of issues)
- **Recruitment method:** in-class ask, voluntary
- **Demographics:** adults, ages ~18–30, mixed experience with iOS games and SwiftUI

### Selection criteria
- Have not previously seen or used Pip's Kitchen Garden
- Comfortable with iOS touch interactions
- Willing to think aloud during tasks

### Process standards
- **Protocol:** Steve Krug's think-aloud method (from *Rocket Surgery Made Easy*)
- **Facilitator rule:** observe, do not defend; prompt only with "What are you thinking?" and "What were you expecting?"
- **Silence counted as data.** Do not interrupt hesitations under 10 seconds.
- **Task framing:** scenarios ("set up a family"), not feature instructions ("tap the family button")

### Forms provided to participants
- Verbal intro (read aloud — see `USABILITY_TEST_SCRIPT.md`)
- One-line consent statement (if recording) — see script
- No written task list (tasks read aloud one at a time to prevent skim-ahead)

### Time frame
- **Per session:** ~40 min (3 intro + 25 tasks + 10 debrief + 2 buffer)
- **Total field time:** ~2 hrs across 3 participants
- **Analysis time:** ~2 hrs (same-day debrief + findings synthesis)

### Session structure
1. Reset app data on test device (clean install experience)
2. Facilitator reads intro script aloud
3. Warm-up question (mental-model capture)
4. 6 sequential tasks, facilitator silent during each
5. Debrief interview (7 open questions)
6. Facilitator solo debrief immediately after (capture fresh impressions)

### Testing environment
- **Device:** iPhone 17 Pro simulator (or physical device if available)
- **Location:** classroom / quiet space
- **Recording:** QuickTime screen recording (verbal consent required)
- **Data collection:** `USABILITY_OBSERVER_NOTES.md` template — one per participant

---

## Testing Script

Full script in `USABILITY_TEST_SCRIPT.md`. Task summary:

| # | Task | Target time | Metric |
|---|------|------------:|--------|
| 1 | First-launch setup (family + child profile) | 5 min | Completion, PIN confusion count |
| 2 | Plant a seed and care for it | 3 min | Completion, care-state discovery |
| 3 | Earn coins via knowledge cards and buy a new seed | 4 min | Completion, time to first coin |
| 4 | Cook a recipe using a harvested veggie | 5 min | Completion, mini-game friction points |
| 5 | Check Body Buddy / ask Pip / open knowledge card | 3 min | Path taken, completion |
| 6 | Switch to parent profile and view dashboard | 2 min | PIN friction, dashboard discoverability |

### Additional information
- **Data collection tools:** observer notes template, optional screen recording
- **Facilitator:** Marina Pollak
- **Note-taker:** Marina Pollak (same person; observer notes written live during each session)

---

## Testing session details

> **Status: Sessions scheduled for 2026-04-20.**
> Participant recruitment began 2026-04-19 via PROG-360A class outreach.
> Detailed session records and filled observer notes will be included in the post-session addendum.

### Session 1
- **Date / time:** _to be confirmed — target 2026-04-20 AM_
- **Participant:** (anonymized)
- **Consent (recording):** _TBD_
- **Notes:** see `USABILITY_OBSERVER_NOTES.md` — Participant 1 (pending)

### Session 2
- **Date / time:** _to be confirmed — target 2026-04-20 AM_
- **Participant:** (anonymized)
- **Consent:** _TBD_
- **Notes:** see `USABILITY_OBSERVER_NOTES.md` — Participant 2 (pending)

### Session 3
- **Date / time:** _to be confirmed — target 2026-04-20 AM_
- **Participant:** (anonymized)
- **Consent:** _TBD_
- **Notes:** see `USABILITY_OBSERVER_NOTES.md` — Participant 3 (pending)

---

## Analysis

> **Analysis pending sessions on 2026-04-20.** This section will contain:
> - A populated quantitative summary table (per-task completion status and time per participant)
> - A severity summary table (Krug 1–5 scale) totaling issues across participants
> - Qualitative patterns observed across ≥2 participants, individual outliers worth noting, and verbatim quotes that capture each participant's experience
>
> The analysis framework below remains as committed; only the data cells are deferred.

### Quantitative summary _(to be populated)_

| Task | P1 Complete | P1 Time | P2 Complete | P2 Time | P3 Complete | P3 Time | Avg time | Completion rate |
|------|:---:|---:|:---:|---:|:---:|---:|---:|---:|
| 1 — Setup | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| 2 — Plant | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| 3 — Shop | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| 4 — Cook | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| 5 — Body/Learn | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| 6 — Switch | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

### Severity summary _(to be populated)_

Number of issues by severity (from observer notes):

| Severity | P1 | P2 | P3 | Total |
|---:|:---:|:---:|:---:|:---:|
| 5 — showstopper | — | — | — | — |
| 4 — serious | — | — | — | — |
| 3 — moderate | — | — | — | — |
| 2 — minor | — | — | — | — |
| 1 — cosmetic | — | — | — | — |

### Qualitative patterns _(to be populated)_

**Repeated across participants (≥2 testers):** pending session data

**Individual but important observations:** pending session data

**Quotes that capture the experience:** pending session data

---

## Key findings

> **Key findings pending sessions on 2026-04-20.**
> Issues will be ranked by Krug's severity scale and categorized as critical (S4–S5 — fix before next version), important (S3 — fix this semester), or minor (S1–S2 — backlog), with positive observations captured separately.

### Critical issues (S4–S5 — fix before next version)
_Pending session data._

### Important issues (S3 — fix this semester)
_Pending session data._

### Minor issues (S1–S2 — backlog)
_Pending session data._

### What's working well
_Pending session data._

---

## Actionable plan

> **Actionable plan pending sessions on 2026-04-20.**
> Post-session, issues will be mapped to specific code changes with owner (Marina) and rough time-to-fix estimates, then scheduled against the May 15 course deadline.

### To incorporate into the next version (before semester end, May 15)

**Priority 1 — critical fixes (P0):** pending session data

**Priority 2 — important but not blocking (P1):** pending session data

### Deferred until after the semester

_Pending session data._

### Open questions to test in the next round
- Would kids aged 6–8 (the real target) have similar or different problems?
- Does voice / Pip audio reduce text friction as expected?
- Do parents understand the PIN system?

---

## Interim submission note (2026-04-19)

This report is submitted on the 2026-04-19 class deadline with the following sections complete:

- **Overview** — project, purpose, qualitative and quantitative aspects tested, success criteria
- **Methodology** — participant recruitment, selection criteria, Krug think-aloud protocol, environment, session structure
- **Testing Script** — full facilitator script, 6 tasks with target times, debrief questions, consent form (see `USABILITY_TEST_SCRIPT.md`)
- **Observer Notes Template** — per-participant blank template ready for live use (see `USABILITY_OBSERVER_NOTES.md`)

Sections pending data from sessions scheduled for **2026-04-20**:

- Testing session details (dates, participant data, notes)
- Analysis (quantitative and severity tables, qualitative patterns, quotes)
- Key findings (severity-ranked issues, what's working)
- Actionable plan (P0/P1 code changes mapped to May 15 deadline)

A **post-session addendum** containing all four pending sections will be submitted immediately after the final session concludes on 2026-04-20.

---

## Appendix

- `USABILITY_TEST_SCRIPT.md` — facilitator script, tasks, consent form
- `USABILITY_OBSERVER_NOTES.md` — blank template, one per participant
- `UX_AUDIT_REPORT.md` — prior external UX audit (March 2026)
- `UX_REDESIGN_PLAN.md` — P0/P1 redesign roadmap
