---
name: carve
description: Turn a PRD into a multi-phase implementation plan using tracer-bullet vertical slices, saved as a local Markdown file in ./plans/. Use when user wants to break down a PRD, create an implementation plan, plan phases from a PRD, or mentions "tracer bullets".
---

# Carve — PRD to Plan

Break a PRD into a phased implementation plan using vertical slices (tracer bullets). Output is a Markdown file in `./plans/`.

## Process

### 1. Confirm the PRD is in context

The PRD should already be in the conversation. If it isn't, ask the user to paste it or point you to the file.

### 2. Identify durable architectural decisions

Before slicing, identify high-level decisions that are unlikely to change throughout implementation:

- System architecture style
- Data model shape and key entities
- Authentication / authorization approach
- Third-party service boundaries
- Key constraints (compliance, performance, budget)

These go in the plan header so every phase can reference them.

### 3. Draft vertical slices

Break the PRD into **tracer bullet** phases. Each phase is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Follow the rules in [vertical-slice-rules.md](./references/vertical-slice-rules.md).

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each phase show:

- **Title**: short descriptive name
- **User stories covered**: which user stories from the PRD this addresses

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Should any phases be merged or split further?

Iterate until the user approves the breakdown.

### 5. Write the plan file

Create `./plans/` if it doesn't exist. Write the plan as a Markdown file named after the feature (e.g. `./plans/user-onboarding.md`). Use the template in [plan-template.md](./references/plan-template.md).
