# PRD Template

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

Example:
> 1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The major functional components of the system
- System boundaries and integration points
- Key data flows
- Third-party service decisions
- Technical clarifications from the stakeholder
- Architectural decisions

Include technology-specific constraints only if the client has explicitly stated them.

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

## Assumptions

An explicit list of claims this PRD rests on but cannot guarantee. Every downstream phase will read these to decide whether their work still makes sense. Examples:

- Scale: "100 < concurrent users < 10k in first year"
- Regulatory: "data stays in EU; no US-resident PII"
- Behavioral: "users will tolerate a 2-step onboarding"
- Dependencies: "Stripe Connect remains available in target markets"

If an assumption later turns out to be wrong, this is the section that flags the PRD as needing revision.

## Tradeoffs Considered

Alternatives that were weighed and rejected, with a one-line reason. This is the audit trail for future "why didn't we just…" questions and prevents the same options being re-litigated mid-implementation.

Format:
- **<Option>** — rejected because <reason>.

Example:
- **DB-per-tenant** — rejected because operational cost scales linearly with tenants and we expect 1000+ tenants by year 2.
- **Real-time collaborative editing (OT/CRDT)** — rejected for v1 because last-write-wins suffices for the initial use case and OT adds 6+ weeks of engineering.

## Validation Strategy

How to verify the system works as intended. **Every user story above must have at least one entry here**, with a concrete verification mechanism — not just a claim that it works.

For each user story / major component, specify:
- **Test scenario** (e.g., "automated integration test exercises happy path + 2 error modes"), OR
- **Observable artifact** (e.g., "row appears in audit_log table within 5 s of event"), OR
- **Runnable command** (e.g., "`make smoke-test` exits 0 against a fresh deploy")

Also include:
- What constitutes "done" for each major component
- Quality criteria and acceptance thresholds (numeric where possible)

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.
