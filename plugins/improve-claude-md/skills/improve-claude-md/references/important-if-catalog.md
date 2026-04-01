# `<important if>` Condition Catalog

Curated conditions for wrapping CLAUDE.md sections. Use action-oriented phrasing — describe what the agent is *doing*, not what *exists*.

## Universal

These apply to nearly every project:

- `"you need to run commands to build, test, lint, or deploy"`
- `"you are creating new files"`
- `"you are modifying existing files"`
- `"you are writing commit messages"`
- `"you are creating pull requests"`
- `"you are creating or modifying documentation"`
- `"you are reviewing code"`

## Language-Specific

- `"you are writing TypeScript"` / `"you are writing Python"` / `"you are writing Rust"` / `"you are writing Go"`
- `"you are adding dependencies"`
- `"you are modifying package.json"` / `"you are modifying Cargo.toml"` / `"you are modifying pyproject.toml"`
- `"you are writing shell scripts"`

## Testing

- `"you are writing tests"`
- `"you are writing unit tests"`
- `"you are writing integration tests"`
- `"you are writing e2e tests"`
- `"you are mocking external services"`
- `"you are setting up test fixtures"`

## API & Data

- `"you are working with APIs"`
- `"you are writing API endpoints"`
- `"you are working with the database"`
- `"you are writing migrations"`
- `"you are handling authentication"`
- `"you are working with external services"`
- `"you are handling user input or form data"`

## Frontend

- `"you are writing React components"`
- `"you are writing CSS or styles"`
- `"you are working with state management"`
- `"you are handling forms"`
- `"you are working with routing"`
- `"you are writing accessible markup"`

## Infrastructure & DevOps

- `"you are modifying CI/CD configuration"`
- `"you are working with Docker"`
- `"you are modifying deployment configuration"`
- `"you are working with environment variables"`
- `"you are configuring monitoring or logging"`

## Architecture

- `"you are creating new modules or packages"`
- `"you are modifying public interfaces or exports"`
- `"you are handling errors"`
- `"you are working with logging"`
- `"you are refactoring existing code"`

## Domain-Specific

Use when the project scan reveals regulated or specialized domains:

- `"you are handling patient data or PHI"` (HealthTech)
- `"you are working with payment processing"` (FinTech)
- `"you are modifying tenant isolation logic"` (Multi-tenant SaaS)
- `"you are working with real-time data or WebSockets"` (Real-time systems)
- `"you are handling file uploads or media"` (Content platforms)

## Condition Writing Guidelines

1. **Action-oriented**: Use "you are writing tests", not "tests exist"
2. **Specific**: Use "you are writing API endpoints", not "you are writing code"
3. **Group related rules**: Combine related rules under one condition rather than repeating the same condition
4. **One concern per block**: Don't mix testing rules with API rules under one condition
5. **Match the agent's task**: Conditions should trigger based on what the agent is about to do, not project state
