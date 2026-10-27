---
name: card
description: Implement a YouTrack card end-to-end via explorer and implementer subagents
argument-hint: <card-id, e.g. DG-796>
---

Start work on $ARGUMENTS.

1. Read the card from YouTrack.
2. Explore the relevant code (use the explorer subagent), then write a concrete spec: Files, Behavior, Constraints (from the card and this conversation), Done when, Verify (exact command).
3. Hand the spec to the `implementer` subagent. Review its report and `git diff` against the spec; iterate with follow-up specs if needed.
4. Create a PR titled "$ARGUMENTS: …" linking the card.
5. Comment on the card with the PR link and summary, and move it to Code Review.
