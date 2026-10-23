# GitHub Actions Workflows

Two workflows wire the Claude Code GitHub App into this repo (both require the
`ANTHROPIC_API_KEY` repository secret); a third, `design-guard.yml`, needs no secrets.

## `claude.yml` — mention bot
Triggers when someone `@claude`-mentions on an issue or PR (comment, review, or
issue body/title). Claude can answer questions, implement changes, push branches,
and open PRs.

## `claude-review.yml` — automatic PR review
Runs on every opened/updated PR. Reviews the diff against the CLAUDE.md
Architecture Rules and posts inline comments. Read-only `gh` tooling — it reviews,
it does not push or merge.

## `design-guard.yml` — design ratchet
Runs on every push and PR. Runs the design-guard self-test, then
`design-guard.py --ratchet`: it fails if the whole-app count of hardcoded design
values and hand-made buttons rises above `.design-guard-baseline`. No secrets,
no AI tokens. The baseline only goes down: lower it in the same commit that fixes
a screen. This checks commits made from Xcode or a terminal too, which the Claude
Code hook never sees.

## Note on builds
Both run on a Linux runner, so they **cannot** build the Xcode project. Treat any
code the bot produces as a draft to build locally in Xcode before merging.
