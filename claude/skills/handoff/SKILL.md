---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

# Handoff

Write a handoff doc for a fresh agent with no memory of this conversation. Terse — agent reader, not human.

## Current State
- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Default branch: !`git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main`
- Commits ahead of default branch: !`git log "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"..HEAD --oneline`

## Focus

`$ARGUMENTS` = what next session focuses on — weight "Next Steps" toward it. Empty → infer from conversation.

## Save path

OS temp dir (not automatically visible to a fresh session; you must copy/attach the file when starting the next session):

```
/tmp/handoff-<repo>-<branch-slug>-<YYYYMMDD-HHMM>.md
```

Repo from `basename "$(git rev-parse --show-toplevel)"`, branch from command above (`/`→`-`), timestamp from `date +%Y%m%d-%H%M`. Print the full path in your final reply.

## Sections

1. **Goal** — 1–2 sentences: ask + why.
2. **State** — branch, committed/pushed?, packages/dirs touched (full repo-relative paths).
3. **Decisions** — non-obvious choices + reasoning, esp. deviations from `CLAUDE.md`. Skip what the diff already shows.
4. **Open questions / blockers**.
5. **Next steps** — concrete, ordered, weighted toward `$ARGUMENTS`.
6. **References** — link, don't restate: PRs, issues, SHAs, plans, YouTrack tickets.
7. **Suggested skills** — pick 1–3 from this repo's current skill menu the next agent should run, with why (e.g. `code-review` before PR, `run` for a live check, `simplify` for cleanup). Not the whole menu.

## Omit

- Anything already in a PRD/plan/ADR/issue/commit/diff — reference it, don't copy it.
- Long code excerpts — use `file:line`.
- `CLAUDE.md` restatement (layout, checklist, PR conventions) — assume it's read directly.

## Redact

Before saving: replace API keys, tokens, passwords, connection strings, PII with `[REDACTED]`. Never write real secrets to `/tmp`.

## Reply

File path + one-sentence summary only. Don't repeat the doc's contents.
