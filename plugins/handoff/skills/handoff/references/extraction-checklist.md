# Extraction Checklist

Walk the entire conversation start to current turn. Pull out every item below. Do not omit detail because it seems minor — a throwaway comment like "we found out port 465 needs `secure: true`" is exactly the kind of thing the next model needs.

| # | Category | What to capture |
|---|----------|-----------------|
| 1 | **Project identity** | Name, repo URL, local path, deployment target, stack, key dependencies, branch |
| 2 | **Session goal** | What the user came in wanting to accomplish (one paragraph) |
| 3 | **Decisions made** | Each one with the reasoning *and* alternatives that were considered and rejected |
| 4 | **Code blocks** | Every block, both final and discarded — labeled per [code-status-tags.md](./code-status-tags.md) |
| 5 | **Errors hit & fixes** | Error message verbatim, root cause, solution |
| 6 | **Environment quirks / gotchas** | Non-obvious setup notes, library versions, OS-specific behavior, config requirements |
| 7 | **Files touched** | Every file mentioned, created, or edited, with one-line purpose |
| 8 | **Commands run or planned** | Shell commands, git operations, deploy steps — verbatim |
| 9 | **User preferences** | Naming conventions, style rules, things to avoid |
| 10 | **Open questions** | Anything unresolved at the moment of handoff |
| 11 | **Next steps** | Ordered, imperative, actionable from item 1 |

## Verbatim discipline

These never get paraphrased:

- File paths
- Function / class / variable identifiers
- Error messages and stack traces
- Version numbers and SemVer ranges
- Command strings and flags
- Config keys and values
- Environment variable names and values

Prose surrounding these may be tightened freely.

## Throwaway details matter

The next model has zero context. Capture:

- Constraints expressed in passing ("oh and we're stuck on Node 18")
- Negative findings ("we tried X, didn't work because Y")
- Implicit assumptions made explicit ("the user wants X but never said so directly")
- Tooling quirks ("the linter complains about Z, ignore it")
