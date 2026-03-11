---
name: write-a-prd
description: Create a Product Requirements Document through structured interview. Use when the user wants to write a PRD, define requirements, or plan a new feature.
---

This skill will be invoked when the user wants to create a PRD. You should go through the steps below. You may skip steps if you don't consider them necessary.

1. Ask the user for a long, detailed description of the problem they want to solve and any potential ideas for solutions.

2. Interview the user relentlessly about every aspect of this plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

3. Sketch out the major functional components of the system. Actively look for opportunities to extract deep modules that can be verified independently.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these components match their expectations. Check with the user which components they want validation criteria for.

4. Once you have a complete understanding of the problem and solution, use the template below to write the PRD. The PRD should be submitted as a GitHub issue.

<prd-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

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

## Validation Strategy

How to verify the system works as intended:

- How each user story will be verified
- What constitutes "done" for each major component
- Quality criteria and acceptance thresholds

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.

</prd-template>
