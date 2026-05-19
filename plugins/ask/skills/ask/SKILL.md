---
name: ask
description: Discovery interview and requirements gathering session. Pressure-test an idea, architecture, or design decision through structured client interviews. Use when the user wants to be challenged on their thinking, explore trade-offs, or vet a plan before committing.
---

# Ask — Discovery Interview

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

**Ask the questions one at a time, waiting for feedback on each question before continuing.** Never batch or group questions, even when they feel tightly coupled — the client's answer to Q1 often reshapes Q2.

## Interview Tracks

Select and adapt tracks based on context. You do not need to cover every track — use judgment.

### Track 1: Problem & Users

- Who exactly has this problem? How many of them are there?
- How do they solve it today? What's painful about the current approach?
- What does success look like for the end user?
- How will you measure whether this is working?
- What happens if you don't build this?

### Track 2: Business Model & Constraints

- What's the revenue model? (Or: what justifies the investment?)
- What's the budget and timeline?
- How large is the team that will build and maintain this?
- Are there existing commitments, contracts, or deadlines that constrain the solution?
- Who are the stakeholders and what are their competing priorities?

### Track 3: Scale & Operations

- How many users do you expect at launch? In 12 months?
- What's the data sensitivity level? (Public, internal, PII, regulated)
- What are the uptime and availability requirements?
- Geographic distribution — single region or multi-region?
- Who handles support, and what does the support model look like?

## Domain-Aware Probing

If the conversation reveals domain-specific concerns, probe deeper:

**HealthTech / Medical / Patient Data**
- HIPAA compliance requirements and BAA needs
- Audit trail and access logging requirements
- Data retention and deletion policies
- PHI handling and de-identification needs

**Finance / Payments / Billing**
- PCI-DSS scope and compliance level
- SOC 2 requirements
- Financial regulation considerations (state/federal)
- Transaction audit and reconciliation needs

**Multi-Tenant SaaS**
- Data isolation strategy (logical vs. physical)
- Tenant boundary enforcement
- Per-tenant customization requirements
- Tenant onboarding and offboarding processes

## Question Format

See [question-format.md](./references/question-format.md) for numbering rules and answer option formatting.

## Surface, Don't Assume

A discovery session is only as good as the assumptions it makes explicit. Three operational rules:

**1. Restate every decision back before moving on.**
After the client answers a non-trivial question, paraphrase the decision in your own words and wait for confirmation. Do not advance to the next question on a maybe.

> Client: "We want it multi-tenant."
> You: "Reading back: multi-tenant means a single deployment serving multiple customer organizations with logical isolation between their data. Correct?"

**2. Present alternatives when the answer is ambiguous.**
When the client's answer admits 2-3 reasonable interpretations, do NOT pick silently. Surface the options and let them choose.

> Client: "We need multi-tenant."
> You: "Multi-tenant can mean (a) shared DB with tenant_id columns, (b) schema-per-tenant in one DB, or (c) DB-per-tenant. Which matches what you have in mind?"

**3. Push back when a feature smells premature.**
If the client requests a capability that looks like premature optimization, premature scale, or premature flexibility, ask the simpler-version question BEFORE accepting the requirement. You are not arguing — you are testing the assumption.

> Client: "We need real-time collaborative editing."
> You: "Could v1 ship with last-write-wins or optimistic locking, and add operational transforms after the first cohort of users? What breaks if collaboration isn't real-time on day one?"

The goal is to leave the session with an explicit list of named assumptions the client has signed off on — not a list of inferences you made.

## Session Flow

1. **Broad**: Understand the what and why. Let the client describe their vision without interruption, then probe.
2. **Narrow**: Drill into constraints, blockers, and non-obvious dependencies. Challenge assumptions.
3. **Synthesize**: Restate all decisions made, surface open questions, and confirm understanding.

End every session with:
- A summary of decisions made
- A list of open questions that still need answers
- Suggested next step (usually `/blueprint` if discovery is complete)

## Acceptance Checklist

- [ ] Core problem clearly articulated
- [ ] Target users identified and characterized
- [ ] Key constraints and blockers surfaced
- [ ] Compliance and regulatory needs addressed (if applicable)
- [ ] Session summary produced with decisions and open questions
- [ ] Explicit list of named assumptions (signed off by client) ready to hand off to `/blueprint`
