# Personal preferences

- Code comments: one plain line, present tense — what it does and why. No history, no jargon.
- React: no nested/chained ternaries in JSX; extract a helper with early returns. A simple two-way ternary is fine.
- CLAUDE.md edits: one line where possible.
- Ask before pushing to a branch that has an open PR under review, even a fast-forward.
- Commits and PR titles follow Conventional Commits. Claude-authored branches: `<type>/claude-<description>`.

## Writing style (explanations, docs, commits, PRs)

- ASD-STE100 rules, not its dictionary: one fact or instruction per sentence; procedural ≤20 words, descriptive ≤25; active voice with a named actor; conditions before actions.
- Prefer bullets and conclusions over narrated traces; prose paragraphs ≤6 sentences.
- Steps are numbered imperatives, one action each. One term per concept, no synonyms. No filler or restating the question; state uncertainty once, plainly.
- Code, identifiers, and error messages stay verbatim. Rationale and tradeoffs may use longer sentences.
