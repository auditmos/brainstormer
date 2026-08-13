---
name: ask
version: 1.1.0
description: Discovery interview and requirements gathering session. Pressure-test an idea, architecture, or design decision through structured client interviews. Use when the user wants to be challenged on their thinking, explore trade-offs, or vet a plan before committing.
---

# Ask — Discovery Interview

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

**Ask the questions one at a time, waiting for feedback on each question before continuing.** Never batch or group questions, even when they feel tightly coupled — the client's answer to Q1 often reshapes Q2.

## Question Format

Number questions sequentially across the session (Q1, Q2, …). When proposing answer options, number them so the client can reply with just the number; free-form answers are always accepted.

```
**Q3.** What's the data sensitivity level?
  1. Public
  2. Internal only
  3. Contains PII
  4. Regulated (HIPAA, PCI, etc.)
```

## Interview Tracks

Load [interview-tracks.md](./references/interview-tracks.md) when starting the interview — three question tracks (problem/users, business model, scale/ops) plus domain-aware probes for HealthTech, Finance, and multi-tenant SaaS. Select tracks by judgment; full coverage is not required.

## Surface, Don't Assume

A discovery session is only as good as the assumptions it makes explicit. Three operational rules:

**1. Restate every decision back before moving on.** After the client answers a non-trivial question, paraphrase the decision in your own words and wait for confirmation. Do not advance on a maybe.

**2. Present alternatives when the answer is ambiguous.** When an answer admits 2-3 reasonable interpretations, do NOT pick silently — surface the options and let the client choose.

> Client: "We need multi-tenant."
> You: "Multi-tenant can mean (a) shared DB with tenant_id columns, (b) schema-per-tenant in one DB, or (c) DB-per-tenant. Which matches what you have in mind?"

**3. Push back when a feature smells premature.** If a request looks like premature optimization, scale, or flexibility, ask the simpler-version question BEFORE accepting the requirement. You are not arguing — you are testing the assumption.

## Session Flow

1. **Broad**: Understand the what and why. Let the client describe their vision without interruption, then probe.
2. **Narrow**: Drill into constraints, blockers, and non-obvious dependencies. Challenge assumptions.
3. **Synthesize**: Restate all decisions made, surface open questions, and confirm understanding.

End every session with a summary of decisions, the open questions that still need answers, the suggested next step (usually `/blueprint` if discovery is complete), and the explicit list of named assumptions the client has signed off on — not a list of inferences you made.

## Acceptance Checklist

- [ ] Core problem articulated; target users identified and characterized
- [ ] Key constraints, blockers, and compliance needs surfaced
- [ ] Every non-trivial decision restated and confirmed
- [ ] Signed-off list of named assumptions ready to hand to `/blueprint`
