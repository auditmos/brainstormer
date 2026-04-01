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

Check with the user that these components match their expectations. Check with the user which components they want validation criteria for.

4. Once you have a complete understanding of the problem and solution, write the PRD using the template in [prd-template.md](./references/prd-template.md). The PRD should be submitted as a GitHub issue.

## Prerequisites

Before creating GitHub issues, verify:
1. `gh` CLI is installed and authenticated (`gh auth status`)
2. Current directory is a git repo with a GitHub remote
3. User has write access to the repository

If any check fails, inform the user and provide the fix command.
