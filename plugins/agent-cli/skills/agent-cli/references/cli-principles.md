# Seven Principles for Agent-Friendly CLIs — Full Reference

> Adapted with attribution from Trevin Chow, ["7 Principles for Agent-Friendly CLIs"](https://trevinsays.com/p/7-principles-for-agent-friendly-clis), published 2026-03-26. Reasoning, examples, and severity rubric paraphrased; this document exists so the skill can reference each principle in detail without reloading the source article.

## Why CLIs over MCP for agent consumption

CLIs are text in, text out, composable by design. Most agents are pre-trained on common CLI tools and standard flag conventions, so there is zero schema overhead. An MCP server can burn tens of thousands of tokens loading tool definitions before any work happens. MCP earns its complexity when per-user auth or structured governance is required; for everyday developer tools, a well-designed CLI is faster, cheaper, and more reliable.

CLIs nonetheless trip agents up in predictable ways. The seven principles below cover where those failures live.

## How to apply this rubric

This is not pass/fail. Each finding maps to a severity tier:

- **Blocker** — prevents reliable agent use. The command hangs, requires human input, or produces output the agent cannot recover from.
- **Friction** — agent can use it, but inefficiently. More retries, brittle parsing, wasted tokens, extra round-trips.
- **Optimization** — works fine but could be faster, cheaper, or more reliable.

Severity also depends on **command type**: idempotency matters for mutating commands, irrelevant for log tails. `--json` is critical for read/query commands, secondary for one-shot install wizards. Apply per command, not uniformly.

---

## 1. Non-interactive by default

Any command an agent might automate must run without prompts. Interactive mode can exist for humans as a convenience, but it cannot be the only path.

When a skill spawns a subagent that shells out to a CLI, there is no channel to surface an interactive prompt back to the user. The command hangs awaiting input that will never arrive. Even in interactive agent sessions, prompts create friction: extra round-trips, ambiguous menu navigation, wasted tokens. **If stdin is not a TTY, the command must not prompt.**

### What good looks like

```
# Human at a terminal (TTY detected) — prompts fill in missing inputs
$ blog-cli publish
? Status? (use arrow keys)
    draft
  > published
    scheduled
? Path to content: my-post.md
Published "My Post" to personal

# Agent or script (no TTY, or --no-input) — flags only, no prompts
$ blog-cli publish --content my-post.md --yes
Published "My Post" to personal (post_id: post_8k3m)
```

### Implementation requirements

- Support `--no-input` or `--non-interactive`.
- Detect TTY vs non-TTY and suppress prompts when stdin is not interactive.
- Accept `--yes` / `--force` for confirmation bypass.
- Take all required input via flags, files, or stdin.

### Verification recipe

```python
import subprocess, sys
cmd = ["blog-cli", "publish", "--content", "my-post.md"]
try:
    result = subprocess.run(cmd, stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, timeout=10)
    print("PASS — exited without hanging, code:", result.returncode)
except subprocess.TimeoutExpired:
    print("FAIL — command hung waiting for input")
    sys.exit(1)
```

### Severity mapping

- **Blocker** — command hangs waiting for input under non-TTY.
- **Friction** — some prompts can be bypassed, behavior inconsistent across subcommands.
- **Optimization target** — full flag coverage and a global non-interactive mode.

---

## 2. Structured, parseable output

Commands that return data must expose a stable machine-readable representation. A nicely aligned table with ANSI colors is great for humans and useless to an agent extracting a post ID. Without structure the agent must scrape its own tooling, which is brittle and expensive.

### What good looks like

```
$ blog-cli publish --content my-post.md
Published "My Post" to personal
URL: https://personal.blog.dev/my-post
Post ID: post_8k3m

$ blog-cli publish --content my-post.md --json
{"title":"My Post","url":"https://personal.blog.dev/my-post","post_id":"post_8k3m","status":"published"}
```

### Implementation requirements

- Support `--json` on every data-bearing command.
- Use exit code 0 for success, non-zero for failure.
- Write result data to stdout, diagnostics to stderr.
- Return useful fields: names, URLs, IDs, status.
- Suppress color, spinners, and decorative output when not attached to a TTY (many CLIs miss this for piped output).

### Severity mapping

- **Blocker** — no structured output at all on data commands.
- **Friction** — inconsistent coverage, mixed stdout/stderr, ANSI codes in pipe.
- **Optimization target** — full `--json` coverage with clean stream separation.

---

## 3. Fail fast with actionable errors

When a command fails, the error must teach the agent how to succeed on retry. Humans can infer; agents cannot. "Error: missing required arguments" tells an agent almost nothing. "Error: --content is required" tells it exactly what to fix.

### What good looks like

```
# Bad
$ blog-cli publish
Error: missing required arguments

# Good
$ blog-cli publish
Error: --content is required.
Usage: blog-cli publish --content <file> [--status <status>]
Available statuses: draft, published, scheduled
Example: blog-cli publish --content my-post.md
```

A good error names the specific problem, shows the correct invocation shape, suggests valid values, and includes an example. Agents that get this can self-correct in one retry.

### Implementation requirements

- Validate early, before any side effects.
- Include correct syntax in error output.
- Suggest valid values when a validation fails.
- Prefer actionable text over raw stack traces.

### Severity mapping

- **Blocker** — vague or silent failures (e.g., exit 1 with no stderr).
- **Friction** — errors name the problem but not the fix.
- **Optimization target** — errors with the full correction path inline.

---

## 4. Safe retries and explicit mutation boundaries

Agents retry, resume, and replay. Mutating commands should make repeats safe when possible, and dangerous operations should be explicit. A human re-running a command will notice the duplicate; an agent in a retry loop will not.

### What good looks like

```
$ blog-cli publish --content my-post.md
Published "My Post" to personal (post_id: post_8k3m)

$ blog-cli publish --content my-post.md
Already published "My Post" to personal, no changes (post_id: post_8k3m)

$ blog-cli posts delete --slug my-post --confirm
```

Strict idempotency is not always possible. For create/update/deploy commands, making duplicate application a no-op or clearly detectable is high-value. For append/send/trigger commands, return identifiers in the success output that let an agent determine whether it repeated work.

### Implementation requirements

- Provide `--dry-run` for consequential mutations.
- Use explicit destructive flags (`--confirm`, `--force-delete`) for dangerous operations.
- Return enough state in success output to verify what happened.
- Where possible, design idempotent semantics on retry.

### Severity mapping

- **Blocker** — retrying a mutating command silently duplicates or corrupts state.
- **Friction** — destructive commands are scriptable with little preview or state feedback.
- **Optimization target** — safe retries plus explicit danger flags plus audit-friendly identifiers.

---

## 5. Progressive help discovery

Agents do not read full documentation upfront. They probe top-level help, then subcommand help, then examples. Help must support that incremental workflow.

### What good looks like

```
$ blog-cli --help
Usage: blog-cli <command>

Commands:
  publish     Publish content
  posts       List and manage posts

$ blog-cli publish --help
Publish a markdown file to your blog.

Options:
  --content   Path to markdown file
  --status    Post status (draft, published, scheduled; default: published)
  --yes       Skip confirmation prompt
  --json      Output as JSON
  --dry-run   Preview without publishing

Examples:
  blog-cli publish --content my-post.md
  blog-cli publish --content my-post.md --status draft
  blog-cli publish --content my-post.md --dry-run
```

Each subcommand's help should include four things: one-line purpose, concrete invocation pattern, required arguments or flags, and the most important modifiers or safety flags. Examples matter more than they look — Anthropic's tool-design guidance shows agents use tools more reliably when given concrete examples.

### Severity mapping

- **Blocker** — subcommands undiscoverable, missing `--help`.
- **Friction** — help exists but omits invocation patterns or required arguments.
- **Optimization target** — layered, example-driven help with links to deeper docs.

---

## 6. Composable and predictable structure

Agents chain commands. They benefit from CLIs that accept stdin, produce clean stdout, and use predictable naming and subcommand patterns. Agents are less tolerant of inconsistency than humans because they pattern-match on structure.

### What good looks like

```
cat posts.json | blog-cli posts import --stdin
blog-cli posts list --json | blog-cli posts validate --stdin
blog-cli posts list --status draft --limit 5 --json | jq -r '.[].title'
```

### Implementation requirements

- Accept input via flags, files, or stdin where it helps automation.
- Support `-` as a stdin/stdout alias when file paths are involved.
- Keep command structure consistent across related resources.
- Prefer flags for ambiguous multi-field operations; reserve positional args for familiar conventions.

Consistency is the subtle one. If `posts list` supports `--json` but `posts stats` does not, the agent must learn the exception. If `posts list --limit` and `comments list --max-results` differ, the agent has to remember an arbitrary naming gap.

### Severity mapping

- **Blocker** — commands cannot participate in pipelines (no stdin, polluted stdout).
- **Friction** — inconsistent flag naming or subcommand structure.
- **Optimization target** — regular patterns, clean stdin/stdout, predictable conventions.

---

## 7. Bounded, high-signal responses

Every extra line of output costs the agent tokens and context window space. Large outputs are sometimes justified, but narrow, relevant responses must be the default.

### What good looks like

```
$ blog-cli posts list --limit 25
Showing 25 of 312 posts
To narrow results: blog-cli posts list --status published --since 7d --limit 10

$ blog-cli posts list --tag javascript --status published --since 30d --limit 10 --json
```

When the CLI truncates, it should teach the agent how to narrow further. "Showing 25 of 312" plus a suggested narrower command is far better than dumping all 312.

### Implementation requirements

- Support filtering, pagination, and limits on large result sets.
- Provide concise vs. detailed response modes.
- When truncating, explain how to narrow or page.
- Return summaries and identifiers before raw detail.

### Severity mapping

- **Blocker** — routine queries dump huge unbounded output.
- **Friction** — narrowing exists but defaults too broad.
- **Optimization target** — bounded defaults that teach the next better query.

---

## Closing note — humans benefit too

Every principle here makes a CLI better for humans. Structured output, actionable errors, bounded responses, non-interactive automation paths — these are not concessions to agents at the human's expense. They are good CLI design that humans have been forgiving enough to work around. Designing for the strict consumer first removes the tax that the forgiving consumer was silently paying.
