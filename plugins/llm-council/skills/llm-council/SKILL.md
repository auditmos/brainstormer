---
name: llm-council
description: "Run a question through 5 AI advisors who analyze independently, peer-review anonymously, then synthesize a verdict. Invoke for strategic decisions with genuine uncertainty where multiple perspectives add value."
---

# LLM Council

Multi-perspective analysis based on Andrej Karpathy's LLM Council methodology. Five independent advisors, anonymous peer review, one synthesized verdict.

## When to Invoke

- Strategic decisions where being wrong is expensive
- Trade-offs where reasonable people genuinely disagree
- High-stakes choices where blind spots could be costly

Not for: factual lookups, creation tasks, or questions with one right answer.

## The Advisors

| Advisor | Orientation |
|---------|-------------|
| Contrarian | Finds fatal flaws and hidden risks |
| First Principles | Strips to fundamentals, questions assumptions |
| Expansionist | Finds upside everyone else is missing |
| Outsider | Zero domain context — fresh eyes |
| Executor | What do you actually do Monday morning? |

Full persona descriptions and prompt templates: [Council Playbook](./references/council-playbook.md)

## Process

### Step 1 — Frame the Question

Take the user's raw question and reframe it as a clear, neutral prompt:

1. State the core decision or question
2. Add key context and constraints from the user
3. Identify what's at stake — why this decision matters

If the question is too vague to council, ask **one** clarifying question. Then proceed.

### Step 2 — Independent Analysis (5 parallel sub-agents)

Spawn all 5 advisors simultaneously using the Agent tool. **Recommended model for advisors:** sonnet-4.5 (cost/quality balance — each persona is narrow and short-form; Opus×5 in parallel is ~5× cost for marginal gain). Each advisor receives:

- Their persona from the [Council Playbook](./references/council-playbook.md)
- The framed question
- Instruction: respond in 150-300 words, don't hedge, lean fully into your assigned angle

All 5 must run in parallel. Sequential spawning lets earlier responses bleed into later ones.

### Step 3 — Peer Review (5 parallel sub-agents)

Collect all 5 responses. Anonymize them as Response A through E — **randomize the mapping** so there's no positional bias.

Spawn 5 new sub-agents in parallel. **Recommended model for reviewers:** sonnet-4.5 (structural comparison across 5 short texts — well within Sonnet's range). Each reviewer sees all 5 anonymized responses and answers:

1. Which response is the strongest and why? (pick one)
2. Which response has the biggest blind spot?
3. What did ALL responses miss?

Each review: under 200 words.

### Step 4 — Chairman Synthesis + Output

Spawn one Chairman sub-agent. **Recommended model:** opus-4.7 with extended thinking (high effort) — 11-input synthesis is the cognitive bottleneck of this skill. The Chairman receives everything de-anonymized: original question, all 5 advisor responses, all 5 peer reviews.

**Reasoning approach:** Before writing the verdict, reason silently through:

1. Which points appear in ≥3 advisor responses (convergence signal)?
2. Where do reviewers disagree about the strongest response (genuine clash)?
3. Which blind spots emerged ONLY in peer review, not in original advisors?

Identify at least 2 non-obvious findings before structuring output. Do not stream a first draft — produce a single considered verdict.

Produces the verdict in this structure:

- **Where the Council Agrees** — convergence points (high-confidence signals)
- **Where the Council Clashes** — genuine disagreements with both sides
- **Blind Spots the Council Caught** — emerged only through peer review
- **The Recommendation** — a clear answer, not "it depends"
- **The One Thing to Do First** — one concrete next step

The chairman can disagree with the majority if the dissenter's reasoning is strongest.

Display the full verdict directly to the user.

## Output

- **Verdict**: displayed in conversation immediately after synthesis
- **Transcript**: saved to `./plans/council-{topic}-{YYYY-MM-DD}.md` with: original question, framed question, all 5 advisor responses, all 5 peer reviews (with anonymization mapping revealed), and the chairman's full synthesis

## Acceptance Checklist

- [ ] Question framed and confirmed with user
- [ ] All 5 advisors produced independent analyses (parallel)
- [ ] Peer review completed with anonymization (parallel)
- [ ] Chairman synthesis delivered with clear verdict
- [ ] Full transcript saved to `./plans/`
