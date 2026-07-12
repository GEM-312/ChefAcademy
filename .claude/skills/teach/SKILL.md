---
name: teach
description: Deliver a teaching moment (MIT-professor tone) and log it to TEACHING.md in the project's 4-field format. Use PROACTIVELY when introducing a pattern, avoiding a pitfall, fixing a non-obvious bug, or writing non-trivial logic — and on demand when Marina says "/teach [topic]", "teach me X", "explain this", or "what did I just learn". Skip trivial wins (font bumps, one-line patches).
allowed-tools: Read, Edit, Bash
---

# Teaching Moment

Marina learns as we build — teach **while** coding, not after. A teaching moment has two outputs: a spoken explanation in chat, and a permanent entry appended to `TEACHING.md`. Do both.

## When to fire

- **Proactively**, without being asked, when: introducing a pattern, avoiding a pitfall, fixing a non-obvious bug, or writing non-trivial logic.
- **On demand** when Marina invokes `/teach [topic]` or asks to be taught/explained something.
- **Skip** trivial wins — font bumps, one-line patches, obvious renames. Aim for 3–7 real moments per session, not noise.

## 1. Explain in chat

Print the title in green, then the four parts:

```bash
echo -e "\n\033[1;32m━━━ TEACHING MOMENT: [Title] ━━━\033[0m\n"
```

Then, in this order:
- **CONCEPT** — 1–2 sentences, the idea in the abstract.
- **STEP BY STEP** — numbered, how it actually works.
- **IN OUR CODE** — the specific file/symbol where it lives (e.g. `PipAIService.swift askCloud`).
- **KEY TAKEAWAY** — one line the reader keeps.

Tone: MIT professor — clear, real-world analogies, no fluff, no filler.

## 2. Log to TEACHING.md

Append every moment to `TEACHING.md` in its existing **4-field format**, newest first (under the current session header if one exists, else add a `## Session: <date>` header). Memory notes are NOT a substitute — this file is the durable log.

```markdown
### <Short Descriptive Title>
**Where it came up:** <the real task/file that triggered it>
**What it is:** <the concept, plainly>
**In our code:** <specific file:symbol and what the code does>
**Why it matters:** <the transferable lesson + any trade-off>
```

Match the depth of existing entries — each field is a full, concrete sentence or two grounded in the actual code, not a stub. Read the top of `TEACHING.md` first to match voice and placement.

## Notes

- The proactive trigger also lives as a one-line rule in CLAUDE.md so it fires without `/teach`; this skill holds the full format so it stays out of every-session context.
- This is a ChefAcademy project skill (it appends to this repo's `TEACHING.md`). Promote to user-level if you want the same behavior in other projects.
