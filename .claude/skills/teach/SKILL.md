---
name: teach
description: Deliver a teaching moment (MIT-professor tone) and log the problem behind it to PROBLEM_SOLVING.md (TEACHING.md is retired). Use PROACTIVELY when introducing a pattern, avoiding a pitfall, fixing a non-obvious bug, or writing non-trivial logic — and on demand when Marina says "/teach [topic]", "teach me X", "explain this", or "what did I just learn". Skip trivial wins (font bumps, one-line patches).
allowed-tools: Read, Edit, Bash
---

# Teaching Moment

Marina learns as we build — teach **while** coding, not after. A teaching moment has two outputs: a spoken explanation in chat, and, when it came from a real problem, an entry in `PROBLEM_SOLVING.md`.

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

## 2. Log the problem to PROBLEM_SOLVING.md (not TEACHING.md)

`TEACHING.md` is retired (Marina, Oct 11 + Oct 23 2026) — never append to it. When the moment came from a real problem (a bug, a wrong first attempt, a non-obvious fix), add an entry to today's dated section of `PROBLEM_SOLVING.md` at the repo root (newest first; add `## YYYY-MM-DD` if missing). It is committed and pushed to GitHub. A pure concept with no problem behind it stays in chat only.

```markdown
### N. <What went wrong, in the player's words>

**Symptom.** <what was seen, and where>

**Cause.** <the real root cause>

**Solution.** <what changed>

**How it works.** <the transferable lesson>

**Where.** <files, commit SHAs>

**Open.** <only if something is left unsolved>
```

Read the newest section of `PROBLEM_SOLVING.md` first to match its voice and numbering.

## Notes

- The proactive trigger also lives as a one-line rule in CLAUDE.md so it fires without `/teach`; this skill holds the full format so it stays out of every-session context.
- This is a ChefAcademy project skill (it appends to this repo's `PROBLEM_SOLVING.md`). Promote to user-level if you want the same behavior in other projects.
