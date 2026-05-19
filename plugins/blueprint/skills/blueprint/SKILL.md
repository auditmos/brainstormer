---
name: blueprint
description: Create a Product Requirements Document through structured interview. Use when the user wants to write a PRD, define requirements, or plan a new feature.
---

# Blueprint — PRD

This skill will be invoked when the user wants to create a PRD. You should go through the steps below. You may skip steps if you don't consider them necessary.

1. Ask the user for a long, detailed description of the problem they want to solve and any potential ideas for solutions.

2. Interview the user relentlessly about every aspect of this plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

3. Sketch out the major functional components of the system. Actively look for opportunities to extract deep modules that can be verified independently.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

**Reasoning approach:** Deep modules aren't visible in a first pass. Sketch the obvious components, then ask of each: is its interface narrow relative to its body? Does it leak implementation details? Iterate silently before presenting — first-draft components tend to be shallow. **Recommended for this step:** opus-4.7 with extended thinking (medium-to-high effort).

**When 2+ architectural interpretations are plausible:** do NOT pick silently. Present the top 2-3 options with their trade-offs (cost, complexity, lock-in, time to first user) and let the client choose. Writing a PRD on a silent architectural guess wastes the entire downstream pipeline.

Check with the user that these components match their expectations. Check with the user which components they want validation criteria for.

4. Once you have a complete understanding of the problem and solution, write the PRD using the template in [prd-template.md](./references/prd-template.md). The PRD should be submitted as a GitHub issue.

**Before submitting, verify the PRD passes these gates:**
- [ ] Every user story has a corresponding entry in **Validation Strategy** describing how it will be verified (test scenario / observable artifact / runnable command). If a story has no verification mechanism, it isn't done — it's a wish.
- [ ] **Assumptions** section enumerates every claim the design rests on (scale, regulatory, user behavior, third-party availability). If a downstream phase fails because an assumption was wrong, the PRD must have made the assumption visible.
- [ ] **Tradeoffs considered** section lists the alternatives that were weighed and rejected, with a one-line reason. This is the audit trail for future "why didn't we just…" questions.

## Prerequisites

Before creating GitHub issues, verify:
1. `gh` CLI is installed and authenticated (`gh auth status`)
2. Current directory is a git repo with a GitHub remote
3. User has write access to the repository

If any check fails, inform the user and provide the fix command.
