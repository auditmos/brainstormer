# `/react-audit` Phase 1 — verification log

Manual walk through the four-module path on both fixtures, recording the
exact output each module would produce. The verification is **simulated**:
the skill is not actually invoked because it would file real GitHub issues
against `auditmos/brainstormer`. Instead, every step is performed by hand
exactly as the SKILL.md contract specifies, and the results are frozen here
as evidence for AC #4, #5, #6.

Run date: 2026-05-08
Run by: tkowalczyk

---

## Step 1 — Rule Card Library

Source file:
`skills/react-shared/references/cards/effects/computing-derived-state.md`.

`loadCard("effects/computing-derived-state")` returns:

```
{
  id: "effects/computing-derived-state",
  category: "effects",
  detect: "llm-judge",
  source: "https://react.dev/learn/you-might-not-need-an-effect#updating-state-based-on-props-or-state",
  body: "<full markdown body — 65 lines, beginning with '# Computing derived state in `useEffect`' and ending with the citation footer>"
}
```

`scripts/validate-rule-cards.sh` confirms the schema offline:

```
$ scripts/validate-rule-cards.sh
All 1 rule cards valid.
```

✅ AC #2 verified (file exists, frontmatter valid).
✅ AC #3 verified (load interface returns parsed Card; missing-id error
  contract is documented in SKILL.md and enforced by validator).

---

## Step 2 — Code Scanner

Detection criteria from the card body's "Detection" section:

1. The effect's body is dominated by a single `setX(...)` call.
2. The argument to the setter is a pure expression over the effect's
   dependency array.
3. The effect has no cleanup function and no asynchronous work.

### `scan(["seeded/UserCard.tsx"], [card])`

File contents (line-numbered):

```
 1  import { useEffect, useState } from 'react';
 2
 3  interface UserCardProps {
 4    initialFirstName: string;
 5    initialLastName: string;
 6  }
 7
 8  export function UserCard({ initialFirstName, initialLastName }: UserCardProps) {
 9    const [firstName, setFirstName] = useState(initialFirstName);
10    const [lastName, setLastName] = useState(initialLastName);
11    const [fullName, setFullName] = useState('');
12
13    useEffect(() => {
14      setFullName(firstName + ' ' + lastName);
15    }, [firstName, lastName]);
16
17    return (
...
```

Applying detection:

- Line 13 opens a `useEffect` whose body (line 14) is exactly one
  `setFullName(...)` call. **Trigger 1 ✓**.
- The setter argument `firstName + ' ' + lastName` is a pure expression
  over `[firstName, lastName]` (the effect's dep array on line 15).
  **Trigger 2 ✓**.
- The effect has no return value (no cleanup) and the body is synchronous.
  **Trigger 3 ✓**.

All three triggers fire → one occurrence.

Severity assignment: card default is **Friction**. The fixture path
`skills/react-audit/references/fixtures/seeded/UserCard.tsx` does not match
any hot-path heuristic (no `src/auth/`, `src/payment/`, `src/router/`; the
filename `UserCard.tsx` is not `*Provider.tsx`/`*Layout.tsx`/`App.tsx`/
`_app.tsx`/`route.tsx`). Severity stays at Friction.

Resulting Finding:

```
{
  rule_id: "effects/computing-derived-state",
  file: "skills/react-audit/references/fixtures/seeded/UserCard.tsx",
  line: 13,
  severity: "Friction",
  snippet: "useEffect(() => {",
  context: <lines 11–15>
}
```

Context block (5 lines):

```tsx
  const [fullName, setFullName] = useState('');

  useEffect(() => {
    setFullName(firstName + ' ' + lastName);
  }, [firstName, lastName]);
```

✅ AC #4 verified (Finding produced with all six required fields, including
the ~5-line context).

### `scan(["clean/UserCard.tsx"], [card])`

File contents (line-numbered):

```
 1  import { useState } from 'react';
 2
 3  interface UserCardProps {
 4    initialFirstName: string;
 5    initialLastName: string;
 6  }
 7
 8  export function UserCard({ initialFirstName, initialLastName }: UserCardProps) {
 9    const [firstName, setFirstName] = useState(initialFirstName);
10    const [lastName, setLastName] = useState(initialLastName);
11    const fullName = firstName + ' ' + lastName;
12
13    return (
...
```

No `useEffect` is present (the import is also dropped on line 1). No
detection trigger fires. **Zero Findings**.

✅ AC #6 verified (clean fixture produces zero issues).

---

## Step 3 — Issue Manager

For the single seeded Finding, the Issue Manager would invoke:

```bash
gh issue create \
  --title "[react-audit] effects/computing-derived-state at UserCard.tsx:13" \
  --label "react-audit:effects/computing-derived-state" \
  --body-file /tmp/react-audit-effects-computing-derived-state-001.md
```

Body file content (rendered locally; not filed):

````markdown
<!-- begin: card body -->
# Computing derived state in `useEffect`

Storing data in state and then keeping it in sync with props or other state via
`useEffect` is unnecessary indirection. The derived value is recomputed during
render anyway — pushing it through state forces an extra render, makes the
component harder to reason about, and risks the synced value falling out of
date when the effect's dependency list is wrong.

If a value can be calculated from existing props or state, calculate it during
render. Reach for `useMemo` only when the calculation is measurably expensive
on the render path.

(...full card body verbatim — Detection, Bad, Good, Severity guidance,
Citation sections — preserved without truncation per SKILL.md rules...)
<!-- end: card body -->

## Occurrence

- **File**: `skills/react-audit/references/fixtures/seeded/UserCard.tsx:13`
- **Severity**: Friction

```tsx
  const [fullName, setFullName] = useState('');

  useEffect(() => {
    setFullName(firstName + ' ' + lastName);
  }, [firstName, lastName]);
```
````

For the clean fixture, **no `gh issue create` invocation is made**. The
skill exits with `0 findings`.

✅ AC #5 verified (label `react-audit:effects/computing-derived-state`
applied; rule id present in title; full card content embedded in body).
✅ AC #7 verified (only `gh` is invoked; no `curl`, `WebFetch`, `@octokit`,
or `api.github.com` reference appears in the issue-creation path).

---

## Caveat per lesson #4

These verifications walk the contract by hand against fixed inputs. They
prove the contracts described in `SKILL.md` produce the documented outputs
on the documented fixtures. They do **not** prove that an agent reading
`SKILL.md` will execute those contracts identically when invoked through
Claude Code. That confirmation requires installing the plugin from the
marketplace, opening a separate test repo, and running `/react-audit`
end-to-end against a real `gh`-authenticated GitHub remote. That step is
out of scope for the brainstormer planning workspace and is what would be
exercised when a downstream consumer (e.g., `tstack-on-cf`) installs the
plugin.
