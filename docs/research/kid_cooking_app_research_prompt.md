# Research Prompt — Kid Cooking/Garden App Competitive Landscape

Use this prompt with either:
- **Claude.ai web → Research mode** (paste it into a chat inside the ChefAcademy Project), or
- The scheduled routine (`trig_research_kid_apps`) which runs an automated version and commits a report.

---

## Prompt

You are doing competitive + App Store landscape research for **Pip's Kitchen Garden**, a kid-friendly iOS app (ages 6+) where children grow virtual vegetables, cook recipes through mini-games, and feed a "Body Buddy" body figure. The developer is preparing a May 15 TestFlight submission and needs decision-grade research, not surface-level summaries.

### Apps in scope

Prioritize these as the comparison set:

**Cooking / food category:**
- Toca Kitchen (Toca Boca) — all versions
- Toca Life: World — food / restaurant sub-flows
- Sago Mini Forever, Sago Mini Trucks, Sago Mini School
- My PlayHome and PlayHome Stores
- Dr. Panda Restaurant series

**Garden / nurture category:**
- Sago Mini Forest
- Pok Pok Playroom (Apple Design Award winner — cooking + everyday-life mini-scenes)
- Tiny Farm / Hay Day Pop (mobile farm sims)
- Toca Nature

**Education / general kids-app benchmarks:**
- Khan Academy Kids
- Endless Reader / Endless Numbers
- Lola Panda / Lola's ABC Party
- PBS Kids Games
- Mussila Music
- ABCmouse

### Research questions — prioritized

1. **Cooking step UI patterns** — When kids "cook" in these apps, how is the step sequence presented? Single screen with all ingredients vs guided step-by-step? Mini-games per step (chop, stir, season) or batch interactions? What's the typical number of steps before a payoff? Drag-and-drop vs tap-to-advance? Voice narration vs text vs icons only?

2. **What do App Store reviews complain about** for these apps? Pull recurring negative-review patterns. Categorize: paywall frustration, content gating, complexity, bugs, ad concerns, age-mismatch, parental gate friction. For each app cite 2–3 representative review quotes if available.

3. **Subscription/paywall patterns in kid apps** — Free vs freemium vs one-time vs subscription. Where is the paywall placed in the flow (cold gate vs after value-delivery)? How do they handle "Designed for Children" requirements around purchase friction? What pricing tiers are most common ($2.99, $4.99, $9.99 monthly)? What conversion rates are publicly reported?

4. **Apple Design Award winners — kid category** — What patterns do Apple Design Award and App Store editorial-featured kid apps share? List winners from the last 3 years in the kid/family categories and extract their common UX principles. Pok Pok Playroom is a key reference.

5. **App Review rejection patterns for "Designed for Children"** — What are the documented and reported rejection reasons that hit kid apps specifically? Search for developer postmortems, Reddit r/iOSProgramming, indie devblogs, and Apple's own guideline updates. Focus on: parental gate requirements, third-party SDK restrictions, IAP placement, ad rules, data collection.

6. **Allergen and dietary preference handling** — Do any of these apps surface dietary considerations (halal, kosher, vegetarian, nut-free, gluten-free)? How? Is this a differentiator if Pip's Kitchen Garden does it well?

7. **Voice / audio approach** — Which apps have voice narration, which are text-only? Which charge for voice? How do they handle pre-readers vs early readers? Is there an industry pattern around free TTS as accessibility?

8. **Multiplayer / social patterns** — Pip's Kitchen Garden ships with local-pass, split-screen, and online (Game Center) multiplayer. What does this look like in competitor apps? Is multiplayer common in kid cooking/garden apps or unusual?

### Output format

Write to `RESEARCH_kid_apps_<YYYY-MM-DD>.md` at the repo root (use today's UTC date). Use this structure:

1. **TL;DR** — three bullets, the headline findings the developer most needs.
2. **App-by-app summary table** — one row per app: pricing model, cooking UX style, voice strategy, top review complaint, standout feature.
3. **Per-question deep dives** — one section per question above, ~150–300 words each, with citations (app name + Apple ID + source URL where possible).
4. **Patterns Pip's Kitchen Garden already does well** — what we should keep / lean into.
5. **Patterns Pip's Kitchen Garden should consider adopting** — ranked top 3 by impact + effort estimate.
6. **App Review risks specific to our codebase** — based on the patterns surfaced, flag the top 3 concerns for the May 15 submission.

### Style rules

- Cite real sources (App Store listings, dev blogs, Reddit threads, news articles). If you can't find a source for a claim, mark it as "inference" not fact.
- Quote actual review text when possible. Not paraphrased.
- Do not pad with generic kid-UX truisms. Marina has read the audit literature — bring something she hasn't seen.
- When apps differ, name the difference. Don't average across the category.
- Output length: target 2,500–4,000 words. Information density over verbosity.

---

## Commit instructions (routine mode only)

After writing the report file:

1. `git status` — only `RESEARCH_kid_apps_<date>.md` and (if you created a `docs/research/` subdirectory) supporting files should appear.
2. If anything else changed, abort: print `ABORT: unexpected file changes` + status, do NOT commit/push.
3. Otherwise: `git add RESEARCH_kid_apps_<date>.md docs/research/` then `git commit -m 'Kid-app competitive research — <date>' --no-gpg-sign` then `git push origin main`.
4. If push fails with HTTP 403: `git pull --rebase` once and retry. If still failing, print error and exit without force-push.
