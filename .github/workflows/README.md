# GitHub Actions Workflows

Two workflows wire the Claude Code GitHub App into this repo. Both require the
`ANTHROPIC_API_KEY` repository secret.

## `claude.yml` — mention bot
Triggers when someone `@claude`-mentions on an issue or PR (comment, review, or
issue body/title). Claude can answer questions, implement changes, push branches,
and open PRs.

## `claude-review.yml` — automatic PR review
Runs on every opened/updated PR. Reviews the diff against the CLAUDE.md
Architecture Rules and posts inline comments. Read-only `gh` tooling — it reviews,
it does not push or merge.

## Note on builds
Both run on a Linux runner, so they **cannot** build the Xcode project. Treat any
code the bot produces as a draft to build locally in Xcode before merging.
