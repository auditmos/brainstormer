---
name: blueprint
version: 1.1.0
description: Create a Product Requirements Document through structured interview. Use when the user wants to write a PRD, define requirements, or plan a new feature.
---

# Blueprint — PRD

Work through the steps below; skip any you judge unnecessary.

1. Ask the user for a long, detailed description of the problem they want to solve and any potential ideas for solutions.

2. Interview the user relentlessly about every aspect of this plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

3. Sketch out the major functional components of the system. Actively look for opportunities to extract deep modules that can be verified independently.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

**Reasoning approach:** Deep modules aren't visible in a first pass. Sketch the obvious components, then ask of each: is its interface narrow relative to its body? Does it leak implementation details? Iterate silently before presenting — first-draft components tend to be shallow.

**When 2+ architectural interpretations are plausible:** do NOT pick silently. Present the top 2-3 options with their trade-offs (cost, complexity, lock-in, time to first user) and let the client choose. Writing a PRD on a silent architectural guess wastes the entire downstream pipeline.

Check with the user that these components match their expectations. Check with the user which components they want validation criteria for.

4. Once you have a complete understanding of the problem and solution, write the PRD using the template in [prd-template.md](./references/prd-template.md). The PRD should be submitted as a GitHub issue — run `gh auth status` first; if it fails, inform the user and provide the fix command.

Before submitting, verify the PRD satisfies the template's own gates: every user story has a **Validation Strategy** entry (test scenario / observable artifact / runnable command), **Assumptions** enumerates every claim the design rests on, and **Tradeoffs considered** lists rejected alternatives with a one-line reason each.
