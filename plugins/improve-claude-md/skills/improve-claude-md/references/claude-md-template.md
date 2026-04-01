# CLAUDE.md Template

Reference structure for a well-optimized CLAUDE.md file. Sections are ordered by priority — foundational context first, conditional guidance second.

## Structure

### 1. Identity (bare — no wrapping)

One sentence describing what this project is. Always at the top, always bare.

```
# Project Name

Short description of the project's purpose and scope.
```

### 2. Directory Map (bare — no wrapping)

Top-level directories with one-line descriptions. Keep bare because it's relevant to every task.

```
## Project map

- `src/` — Application source code
- `tests/` — Test suites
- `docs/` — Documentation
- `scripts/` — Build and utility scripts
```

### 3. Commands (single wrapped block)

Build, test, lint, deploy commands in one `<important if>` block.

```xml
<important if="you need to run commands to build, test, lint, or deploy">

| Command | What it does |
|---------|-------------|
| `npm install` | Install dependencies |
| `npm run build` | Compile TypeScript |
| `npm test` | Run test suite |
| `npm run lint` | Lint codebase |

</important>
```

### 4. Rules (individually wrapped)

Each rule gets its own narrow `<important if>` trigger. Never group unrelated rules.

```xml
<important if="you are creating new files">
Follow the naming convention: kebab-case for files, PascalCase for components.
</important>

<important if="you are writing TypeScript">
Use strict mode. Prefer `unknown` over `any`. Use discriminated unions for state.
</important>

<important if="you are modifying API endpoints">
All endpoints must return standard response envelope: `{ data, error, meta }`.
</important>
```

### 5. Domain Sections (wrapped by domain)

Group related guidance under domain-specific conditions.

```xml
<important if="you are writing tests">
- Use Vitest, not Jest
- Co-locate test files next to source: `foo.ts` → `foo.test.ts`
- Integration tests hit real database, not mocks
</important>

<important if="you are working with the database">
- Migrations live in `src/db/migrations/`
- Use the query builder, not raw SQL
- All schema changes require a migration file
</important>
```

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Monolithic rules block | Split into individual `<important if>` blocks with specific conditions |
| Linter-enforceable rules ("use semicolons", "indent with 2 spaces") | Delete — the linter handles this |
| Inline code snippets | Replace with file path references: "See `src/utils/api.ts` for the pattern" |
| Vague instructions ("follow best practices", "keep code clean") | Delete — they add noise and carry no information |
| Unwrapped conditional content | Wrap in `<important if>` so the system knows when it's relevant |
| Broad conditions ("you are writing code") | Narrow to specific triggers ("you are writing API endpoints") |
