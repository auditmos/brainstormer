# Ten Principles for Agent-Native CLIs — Full Reference

> Adapted with attribution from Trevin Chow, ["10 Principles for Agent-Native CLIs"](https://trevinsays.com/p/10-principles-for-agent-native-clis), published 2026-05-01. Reasoning, examples, severity rubric, and tier organization paraphrased; this document exists so the skill can reference each principle in detail without reloading the source article.
>
> Supersedes the original ["7 Principles for Agent-Friendly CLIs"](https://trevinsays.com/p/7-principles-for-agent-friendly-clis) (2026-03-26), per the author's own "replacement, not a sequel" framing. Tier 1 condenses the original seven into five with three substantive upgrades; Tier 2 adds five new compounding principles. Cross-references in this skill that previously pointed at "Principle N (of 7)" map to the new numbering below.

## Why CLIs over MCP for agent consumption

CLIs are text in, text out, composable by design. Most agents are pre-trained on common CLI tools and standard flag conventions, so there is zero schema overhead at runtime. An MCP server can burn tens of thousands of tokens loading tool definitions before any work happens.

That said, the MCP and CLI surfaces are not equivalent — and the token cost of the MCP description surface is itself a target of Principle 5 below. Cloudflare's Code Mode MCP serves over 3,000 operations in under 1,000 tokens by treating tool descriptions as a budget; most MCP servers in the wild burn 1,000 tokens on a single tool description. The principle generalizes: whichever surface you pick, the description tax falls on every invocation.

For everyday developer tools, a well-designed CLI is faster, cheaper, and more reliable. MCP earns its complexity when per-user auth or structured governance is required.

## How to apply this rubric

This is not pass/fail. Each finding maps to a severity tier:

- **Blocker** — prevents reliable agent use. The command hangs, requires human input, silently corrupts state, or returns output the agent cannot recover from.
- **Friction** — agent can use it, but inefficiently. More retries, brittle parsing, wasted tokens, extra round-trips.
- **Optimization** — works fine but could be faster, cheaper, or more reliable.

Severity also depends on **command class**. Six classes are recognized:

- **read** — query, list, get, search, describe (no side effects)
- **mutate** — create, update, delete, deploy, publish, send (changes state synchronously)
- **stream** — tail, follow, watch (long-running, ongoing output)
- **bootstrap** — init, install, setup wizards (one-shot, often interactive by design)
- **async** — submit a job that completes off-band; returns a job ID; requires polling or `--wait` to collect (Principle 8 applies here specifically; Principle 4 idempotency extends across the submit-poll-collect arc)
- **config** — profile, auth, preferences, local state management (Principle 9 applies here specifically)

Decision tree for ambiguous classifications:

1. Does it block on a remote process that may take >5s? → **async** (even if the underlying API is HTTP).
2. Does it write to local CLI state (`~/.<cli>/`) without remote effect? → **config**.
3. Does it stream until the user kills it? → **stream**.
4. Does it change remote state synchronously? → **mutate**.
5. Does it return data without changing state? → **read**.
6. Is it a one-shot setup wizard? → **bootstrap**.

Apply principles per class — idempotency (Principle 4) matters for mutate and async; `--wait` (Principle 8) is async-only; profile precedence (Principle 9) is config-anchored but extends to any command that uses persisted credentials. The audit checklist captures the per-principle × per-class severity mapping.

---

# Tier 1 — Table Stakes

> **Don't break the agent.** Agents are good at figuring things out, but when these aren't met, the deck is stacked against them. Every gap costs more tokens, more retries, and more failure modes that don't surface until production.

---

## 1. Non-interactive by default

Any command an agent might automate must run without prompts. Interactive mode can exist for humans as a convenience, but it cannot be the only path.

When a skill spawns a subagent that shells out to a CLI, there is no channel to surface an interactive prompt back to the user. The command hangs awaiting input that will never arrive. Even in interactive agent sessions, prompts create friction: extra round-trips, ambiguous menu navigation, wasted tokens. **If stdin is not a TTY, the command must not prompt.**

### What good looks like

```
# Hangs forever waiting for a confirmation that will never come
$ mycli post delete post_8f2a < /dev/null
Are you sure you want to delete post_8f2a? [y/N]: ^C

# With --force: bypasses the prompt, agent gets through cleanly
$ mycli post delete post_8f2a --force
{"deleted":"post_8f2a"}
```

### Implementation requirements

- Support `--no-input` (or equivalent) on every command that might prompt.
- Detect TTY vs non-TTY and suppress prompts when stdin is not interactive.
- Standardize on **`--force`** for confirmation bypass on destructive ops, not `--skip-confirmations` or `--no-prompt`. Pick one convention and enforce it across the surface (Principle 6).
- Take all required input via flags, files, or stdin.

### Verification recipe

```python
import subprocess, sys
cmd = ["mycli", "post", "delete", "post_8f2a", "--force"]
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

- **Blocker** — silent hanging on a prompt under non-TTY.
- **Friction** — inconsistent prompt-bypass behavior across subcommands.
- **Optimization target** — comprehensive non-interactive mode the agent can rely on without per-command lookups.

---

## 2. Structured, parseable output

Commands that return data must expose a stable machine-readable representation. A nicely aligned table with ANSI colors is great for humans and useless to an agent extracting a post ID. Without structure, the agent must scrape its own tooling, which is brittle and expensive.

The newer wrinkle — and the one most often violated by mature CLIs — is **vocabulary uniformity at this layer**. Pick *one* flag and use it everywhere. Always `--json`, never `--format=json` for some commands and `--output json` for others. Inconsistency at the output layer is its own category of brokenness; it forces the agent to remember per-command exceptions or read `--help` before every call.

### What good looks like

```
# Data on stdout, parseable directly with jq
$ mycli post list --json | jq '.posts[0].id'
"post_8f2a"

# Errors go to stderr, exit codes signal failure class
$ mycli post get post_does_not_exist --json
$ echo $?
4
# stderr → "error: post not found: post_does_not_exist"
```

### Implementation requirements

- Support `--json` (singular, canonical) on every data-bearing command.
- Use exit code 0 for success, non-zero for failure. Maintain a stable exit-code taxonomy if you can: 1 = generic, 2 = usage, 3 = network, 4 = not-found, 5 = auth, etc.
- Write result data to stdout, diagnostics to stderr.
- Return useful fields: names, URLs, IDs, status.
- Suppress color, spinners, and decorative output when not attached to a TTY (many CLIs miss this for piped output).
- Never ship `--format=json`, `--output=json`, `-o json`, and `--json` as four ways to mean the same thing. Pick one.

### Severity mapping

- **Blocker** — no structured output at all on data commands.
- **Friction** — coverage gaps where some commands are JSON-capable and others aren't; mixed flag names for the same intent (`--format=json` vs `--json`); ANSI codes leaking into pipes.
- **Optimization target** — uniform `--json` across the CLI with clean stdout/stderr separation and a documented exit code taxonomy.

---

## 3. Errors that teach, and enumerate

When a command fails, the error must teach the agent how to succeed on retry. Humans can infer; agents cannot. "Error: missing required arguments" tells an agent almost nothing. "Error: --content is required" tells it exactly what to fix.

The newer refinement: when the failure is "you passed an invalid value for X," the error must include the **valid set inline**. The pattern generalizes — any time the CLI rejects user input against an enum, an enum-shaped resource list, or a schema, surface the enumeration in the error. Errors are the highest-signal context an agent gets, because they fire exactly when the agent doesn't know what to do next.

### What good looks like

```
# Unhelpful: agent has to read --help, parse, guess, retry
$ mycli post create --json --visibility=secret --content="hi"
error: invalid visibility

# Better: error names the valid set; agent self-corrects in one retry
$ mycli post create --json --visibility=secret --content="hi"
error: --visibility must be one of: public, private, unlisted (got: "secret")
```

A good error names the specific problem, shows the correct invocation shape, suggests valid values, and includes an example. Agents that get this can self-correct in one retry. Agents that don't read `--help`, parse it, and guess.

### Implementation requirements

- Validate early, before any side effects.
- Include correct syntax in error output.
- **Enumerate the valid set** when an enum is the cause; include the offending value (`got: "..."`) so the agent can locate the bad arg in its invocation.
- Provide a working-invocation example.
- Prefer actionable text over raw stack traces.

### Severity mapping

- **Blocker** — vague or silent failures (e.g., exit 1 with no stderr); enum failures with no hint at valid values.
- **Friction** — errors name the problem but not the solution; valid set listed but no example.
- **Optimization target** — errors that include the valid set, the offending value, and a working invocation example.

---

## 4. Safe retries and explicit mutation boundaries

Agents retry, resume, and replay. Mutating commands should make repeats safe when possible, and dangerous operations should be explicit. A human re-running a command will notice the duplicate; an agent in a retry loop will not.

### What good looks like

```
# Idempotent create — second call returns the existing resource, not a duplicate
$ mycli post create --json --content="hello world"
{"id":"post_8f2a","existing":false}
$ mycli post create --json --content="hello world"
{"id":"post_8f2a","existing":true}

# Destructive ops require an explicit flag; --dry-run shows what would happen
$ mycli post delete post_8f2a --dry-run
{"would_delete":"post_8f2a","status":"dry_run"}
```

### Idempotency across the submit-poll-collect arc

The newer wrinkle is async. Retries on a long-running operation aren't just about idempotency at submission; they're about idempotency across the whole submit→poll→collect arc. If the agent's first invocation submits a job and then loses connection mid-poll, the second invocation needs to find the in-flight job, not start a new one. A persistent job ledger solves this — see Principle 8 for the implementation pattern.

For sync mutations, idempotency tokens or natural keys make a retried `create` return the existing resource instead of a duplicate. For async, the ledger entry created at submit time is what the next invocation finds.

### Implementation requirements

- Idempotency tokens or natural keys for create operations, so a retried `create` returns the existing resource instead of a duplicate.
- `--dry-run` for any consequential mutation.
- Explicit, non-default flags for destructive operations (Cloudflare convention: `--force`, never `--skip-confirmations`).
- Identifiers returned in every mutation response so the agent has something to reference on the next call.
- For async commands: persist job state to a ledger at submit time so retries can recover (see Principle 8).

### Severity mapping

- **Blocker** — silent duplication or state corruption on retry; async submit-retry creates a duplicate job instead of recovering the existing one.
- **Friction** — destructive commands scriptable without preview; mutations that succeed but return no identifier the agent can reference.
- **Optimization target** — idempotent mutations, durable job state across the async arc, and explicit destructive flags.

---

## 5. Bounded responses, at every layer

Tokens cost money and context. Big outputs are sometimes justified, but the default should be narrow.

The original principle covered runtime output: `list` returning ten thousand rows, `logs` dumping forever. The newer layer this principle absorbs: **the tool description surface itself costs tokens**. Most MCP servers shipping today burn 1,000 tokens on a single tool's description. Cloudflare's Code Mode MCP serves 3,000 operations in under 1,000 tokens by treating descriptions as a budget audited at build time, not "however much explanation felt natural."

Both layers matter. A bloated MCP description never gets read by a human, but every agent that loads it pays the toll on every call. The same logic applies to `--help` text bloat in CLIs that get auto-loaded by skill systems.

### What good looks like

```
# Default page size is bounded; truncation tells the agent how to narrow
$ mycli post list --json
{"posts":[...20 items...],"truncated":true,"hint":"add --limit=N or --filter=author:..."}

# Cursor for explicit continuation
$ mycli post list --json --cursor=abc123
{"posts":[...],"next":null}
```

When the CLI truncates, it should teach the agent how to narrow further. "Showing 25 of 312" plus a suggested narrower command is far better than dumping all 312.

### Implementation requirements

- Filtering, pagination, and limits on every list-style command.
- Concise vs. detailed modes; default to concise.
- Truncation messages that include both the count and a concrete narrowing example or cursor.
- Summary-before-detail responses.
- For MCP wrappers (or any auto-loaded tool description surface): a budget per tool description, audited at build time. A reasonable target is "every tool description fits in a tweet."

### Severity mapping

- **Blocker** — routine commands dumping unbounded output; MCP wrapper that exposes the CLI without per-tool description budgets.
- **Friction** — broad defaults with available narrowing; truncation that shows count but no narrowing hint.
- **Optimization target** — bounded defaults that guide better queries, plus an MCP surface where each tool description fits in a tweet.

---

# Tier 2 — Compounding

> **Empower the agent.** Tier 1 keeps you in the game. Tier 2 makes the CLI better the more it gets used. These principles are about *compounding* instead of *not breaking* — the CLI becomes more useful as agents accumulate persistent identity, async workflows, output that has to land somewhere, and friction that maintainers should hear about.

---

## 6. Cross-CLI vocabulary consistency

This is the principle most under-stated in older CLI guides, and the one most worth enforcing mechanically.

Agents don't memorize one CLI at a time. They build a generalized model of what CLIs do, drawn from every CLI they've seen. When your tool uses `info` for what every other tool calls `get`, the agent doesn't fail; it succeeds slowly, with extra retries, after burning tokens on `--help`. Multiply that across thousands of agent invocations per week and the cost is real.

### What good looks like

```
# Conforming to the convention — agents recognize these immediately
$ wrangler kv namespace list --json
$ heygen videos list --json
$ mycli posts list --json

# Off-convention versions an agent has to relearn for each tool
$ mycli posts ls               # use list, not ls
$ mycli posts info abc         # use get, not info
$ mycli post delete abc \
    --skip-confirmations       # use --force, not --skip-*
$ mycli post list \
    --format=json              # use --json, not --format=json
```

### Canonical verbs and flags (Cloudflare schema rules, generalizable)

- Always `get`, never `info` or `describe`.
- Always `list`, never `ls` or `index`.
- Always `create`, never `add` or `new` (for the primary creation verb on a resource).
- Always `update`, never `edit` or `modify` (for a partial change).
- Always `delete`, never `remove`, `rm`, or `destroy`.
- Always `--force`, never `--skip-confirmations`, `--no-prompt`, `--yolo`.
- Always `--json`, never `--format=json`, `--output=json`, `-o json` (see Principle 2).
- Always `--limit`, never `--max-results`, `--page-size`, `--top`.
- Always `--profile`, never `--config-name` or `--context` (see Principle 9).

The principle generalizes beyond Cloudflare's specific list. Pick the convention the broader community already uses, and don't deviate without strong reason. Where you do have to invent vocabulary because the concept is genuinely new, name it consistently across your own commands and document it once, prominently.

### Implementation requirements

- A documented naming policy.
- A static check in CI that fails on banned verbs and flag aliases.
- Canonical names that match the dominant convention in your language community.
- Schema-enforced consistency where possible — manual review is Swiss cheese.

### Severity mapping

- **Blocker** — verbs and flags that contradict universal conventions (`info` instead of `get`, `--skip-confirmations` instead of `--force`).
- **Friction** — internal inconsistency between your own subcommands (`posts list --limit` and `comments list --max-results`).
- **Optimization target** — schema-enforced vocabulary that an agent trained on neighboring CLIs recognizes on first encounter.

---

## 7. Three-layer introspection

The original principle here was "progressive help discovery": top-level `--help` lists commands, subcommand `--help` shows usage. That's still true, but it's now the bottom layer of a three-layer stack. Each layer answers a different question.

### Layer 1 — `--help`: human-shaped text

```
$ mycli --help
mycli  Manage posts and accounts.

USAGE: mycli <command> [flags]

COMMANDS:
  post      Manage posts
  account   Manage accounts
  jobs      Inspect async jobs
  profile   Manage saved configurations
  feedback  Send feedback upstream
```

`--help` is necessary because some agents will hit it before anything else, and because a human dropping into the terminal needs it.

### Layer 2 — `agent-context`: structured, versioned shape

```
$ mycli agent-context | jq '.schema_version, (.commands | keys)'
"1"
["account","feedback","jobs","post","profile"]

$ mycli agent-context | jq '.commands.post.subcommands.create.flags'
{
  "--content":     {"type":"string","required":true},
  "--visibility":  {"type":"enum","values":["public","private","unlisted"]},
  "--json":        {"type":"bool","default":false},
  "--dry-run":     {"type":"bool","default":false}
}
```

`agent-context` is what an introspecting agent should actually consume: versioned, machine-readable JSON describing the full shape. The `schema_version` field lets the consuming agent detect breaking shape changes. Cloudflare's `/cdn-cgi/explorer/api` is the runtime version of this idea; the equivalent for a CLI is a top-level subcommand that emits a JSON document.

### Layer 3 — Skill manifest: long-form workflow prose

```
$ cat $(mycli skill-path)/SKILL.md
# Publishing a post end-to-end
1. Save a profile for your default audience.
2. Create the post with --wait so the artifact returns synchronously.
3. Use --deliver=webhook:... to ship it downstream.
```

Long-form prose teaching the agent how to *compose* operations into useful workflows. HeyGen ships a skills repo of SKILL.md files alongside their CLI; Cloudflare's MCP server is the equivalent. This layer describes the CLI from the perspective of the tasks an agent might use it for, not the commands it exposes.

### Implementation requirements

- All three layers present.
- Each versioned (`agent-context.schema_version`, skill manifest frontmatter version).
- Each kept in sync with the implementation by the same generation step (codegen or build-time validation).
- `agent-context` should expose: command tree, flag definitions with types and defaults, enum value lists (so Principle 3 errors can match), exit-code taxonomy, list of available profiles (Principle 9), available `--deliver` schemes (Principle 10), and feedback endpoint discoverability (Principle 10).

### Severity mapping

- **Blocker** — only `--help`, nothing structured (no `agent-context` or equivalent).
- **Friction** — `agent-context` exists but isn't versioned, or skill manifests have drifted from the actual command surface.
- **Optimization target** — three layers, schema-versioned, machine-validated against the real implementation.

---

## 8. Async-aware execution

Most CLIs treat async APIs the way the underlying HTTP endpoint does: submit returns a job ID, poll returns a status, that's the agent's problem. Two failure modes follow. Either the agent writes its own poll loop (wasting tokens and getting it subtly wrong), or it doesn't, and the workflow fails because the result wasn't ready when the next step ran.

The fix is `--wait`.

### What good looks like

```
# Without --wait: the agent has to write its own polling loop
$ mycli video render --script=story.txt
{"job_id":"job_8f2a","status":"queued"}
$ mycli video status job_8f2a
{"job_id":"job_8f2a","status":"running","progress":0.34}
$ mycli video status job_8f2a
{"job_id":"job_8f2a","status":"complete","url":"https://.../out.mp4"}

# With --wait: same workflow, one command, no polling logic
$ mycli video render --script=story.txt --wait
{"job_id":"job_8f2a","status":"complete","url":"https://.../out.mp4"}

# The job ledger survives across invocations
$ mycli jobs list
JOB_ID    STATUS    KIND          STARTED              DURATION
job_8f2a  complete  video.render  2026-04-30T18:22:11  37s
job_7c14  running   video.render  2026-04-30T18:24:02  12s
```

`--wait` blocks until completion. Behind it, the CLI runs a poll loop with backoff and writes job state to a local ledger. A `jobs` command exposes the ledger: `jobs list` shows in-flight and recent jobs, `jobs get <id>` retrieves status, `jobs prune` clears old entries.

This collapses several agent turns into one. Same workflow, fewer tokens, no polling logic the agent has to get right. **The job ledger is also what makes Principle 4 idempotency work across the async arc.** If the agent's `--wait` invocation gets killed mid-poll, the next invocation finds the existing job rather than submitting a new one.

### Implementation requirements

- `--wait` on every submitting command that wraps an async API.
- Polling implementation with exponential backoff (1s → 2s → 4s → 8s → 30s cap) and ±20% jitter.
- A persistent job ledger at `~/.<cli>/jobs.jsonl` (JSONL append-only is fine).
- A `jobs` parent command exposing `list / get / prune`.
- Idempotency-key submission so duplicate `--wait` calls collapse onto the same ledger entry.

### Verification recipe

```python
import subprocess, json
# Submit with --wait — must complete, not return queued
r = subprocess.run(["mycli", "video", "render", "--script=fixture.txt", "--wait", "--json"],
                   stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                   text=True, timeout=120)
payload = json.loads(r.stdout)
assert payload["status"] == "complete", f"Expected complete, got {payload['status']}"
```

### Severity mapping

- **Blocker** — async commands that return a job ID and stop, forcing the agent to write a polling loop.
- **Friction** — `--wait` exists but doesn't survive disconnect; no way to inspect or recover in-flight jobs from the ledger.
- **Optimization target** — `--wait` on every async submission with a durable, recoverable ledger and structured `jobs list/get/prune` access.

---

## 9. Persistent identity through profiles

Agents don't show up once. They show up tomorrow, and the day after, and a week from now, in a different shell, with the same underlying intent and a different specific input. Stateless leaf-shaped CLIs make every invocation re-specify the same eight flags.

The fix is a profile system.

### What good looks like

```
# Save a named bundle of configuration once
$ mycli profile save my-podcast \
    --avatar=lila \
    --voice=warm-en \
    --webhook=https://podcast.example.com/hook
profile saved: my-podcast

# Reuse it on every subsequent invocation
$ mycli video create --profile=my-podcast --script=ep_42.txt
{"job_id":"job_8f2a","using_profile":"my-podcast"}

# Explicit flags win over profile values
$ mycli video create --profile=my-podcast --voice=energetic --script=...
{"job_id":"job_a91","using_profile":"my-podcast","voice":"energetic"}

# Surfaced through introspection so agents discover available identities
$ mycli agent-context | jq '.available_profiles'
["my-podcast","client-demo","weekly-recap"]
```

### Precedence

Resolution order, highest to lowest priority:

1. Explicit flag (`--voice=energetic`)
2. Environment variable (`MYCLI_VOICE=energetic`)
3. Profile value (loaded via `--profile=my-podcast`)
4. Built-in default

Surfacing the available profile names in `agent-context` matters: it's how an introspecting agent discovers which identities exist without parsing a config file.

### Implementation requirements

- `profile save / use / list / show / delete` subcommands.
- `--profile <name>` as a persistent root flag.
- Stable storage location: `~/.<cli>/profiles.json` (or equivalent per-OS conventional path).
- Profile names exposed in `agent-context` (Principle 7).
- Clean precedence resolver enforced by a single code path (so flag/env/profile lookup is deterministic across all subcommands).

### Severity mapping

- **Blocker** — no way to persist configuration; every invocation requires the full flag set.
- **Friction** — profiles exist but aren't discoverable via introspection; precedence is documented but inconsistent across subcommands.
- **Optimization target** — named profiles with clean precedence, surfaced through `agent-context`, with profile values shown in dry-run output so agents can verify what's loaded.

---

## 10. Two-way I/O

Agents don't only consume CLIs through pipes, and the CLI doesn't only emit through stdout. Two mechanisms close the gap: a way for the CLI to emit artifacts where the agent actually needs them, and a way for the agent to report friction back.

### `--deliver` — outbound

```
$ mycli video create --script=story.txt --deliver=stdout
{"video_url":"https://.../out.mp4","duration_s":47}

$ mycli video create --script=story.txt --deliver=file:./out.mp4
{"delivered_to":"file:./out.mp4","bytes":4823091}

$ mycli video create --script=story.txt \
    --deliver=webhook:https://example.com/hook
{"delivered_to":"webhook:https://example.com/hook","status":201}

# Unknown schemes get a structured refusal naming what's supported
$ mycli video create --script=... --deliver=s3:bucket/key
error: --deliver scheme must be one of: stdout, file:<path>, webhook:<url>
```

`--deliver` routes the artifact directly: stdout, a file path, or a webhook URL. A video that lands as an MP4 at a known path, or POSTs to a webhook the agent already set up, is one fewer hop than "stdout to a temp file then move." File sinks must write atomically (temp + rename); webhook sinks POST and surface HTTP status; unknown schemes return a structured refusal that includes the supported set (Principle 3).

### `feedback` — inbound

```
$ mycli feedback "the --tier flag rejects 'enterprise' but the docs list it as valid"
feedback recorded locally (1 entry)

$ mycli feedback list
2026-04-30T18:31:02  the --tier flag rejects 'enterprise' but the docs list it as valid

# Optional upstream POST when configured
$ MYCLI_FEEDBACK_ENDPOINT=https://maintainers.example.com/cli-feedback \
    mycli feedback "race condition in --wait when job completes during the first poll"
feedback recorded locally and sent upstream (status: 200)
```

Agents hit friction constantly: flags rejected for the wrong reason, race conditions in async paths, error messages that don't enumerate. Most of it never gets reported because there's no channel: the agent retries, eventually succeeds, the maintainer never learns the call was painful. `<cli> feedback "..."` writes locally by default; with an endpoint configured (typically via `<CLI>_FEEDBACK_ENDPOINT` env var), the entry POSTs upstream too.

### Implementation requirements

- `--deliver` with at least three sinks: `stdout`, `file:<path>`, `webhook:<url>`.
- Atomic file writes (write to `.tmp`, fsync, rename).
- Webhook sinks POST and surface HTTP status code in the response body.
- Structured refusal on unknown schemes (Principle 3 enumeration applies).
- `feedback <text>` command appending to `~/.<cli>/feedback.jsonl`.
- Optional upstream POST configured via `<CLI>_FEEDBACK_ENDPOINT` env var.
- Both `--deliver` schemes and feedback upstream availability surfaced in `agent-context` (Principle 7).

### Severity mapping

- **Blocker** — output is stdout-only with no way to report friction back; agents have no closed loop to surface CLI bugs.
- **Friction** — output sinks exist but aren't atomic (partial writes visible during run); feedback exists but the upstream channel isn't discoverable.
- **Optimization target** — structured delivery and discoverable feedback, both versioned in introspection, with at minimum stdout/file/webhook sinks.

---

# Architectural backstop — schema or codegen

Most of Tier 2 is hard to apply by hand and easy to apply mechanically. Cross-CLI vocabulary, three-layer introspection, async detection, profile precedence, delivery routing — every one of them is the kind of thing you'd be inconsistent about across a dozen subcommands if you wrote them by hand, and trivially consistent about if a schema or codegen pipeline writes them.

Cloudflare's TypeScript schema is the load-bearing detail of their post: generating the CLI, the SDKs, the Terraform provider, and the MCP server from one source is what makes ten principles hold across thousands of operations without drift. The pattern works in any ecosystem — protobuf + a CLI generator, an OpenAPI spec + commander/click templates, a hand-rolled spec.

When auditing a CLI, schema/codegen is **not a finding** — it's an architectural recommendation that surfaces when:

- The CLI exposes more than ~20 commands, OR
- Cross-CLI vocabulary inconsistency (Principle 6) shows up in multiple places, OR
- The audit catches `agent-context` drift from `--help` (Principle 7).

In those cases, recommend codegen as the path to keep the consistency bar from rotting under future hand-edits. For small CLIs, hand-written conformance is fine — the principles still apply, just enforced by review and tests instead of generation.

---

## Closing note — humans benefit too

Every principle here makes a CLI better for humans. Structured output, actionable errors, bounded responses, non-interactive automation paths, durable async workflows, persistent profiles, sane delivery — none of these are concessions to agents at the human's expense. They are good CLI design that humans have been forgiving enough to work around.

The classic [Command Line Interface Guidelines](https://clig.dev) treat a human at a terminal as the primary user, with agents as a tolerated secondary audience. That's no longer the right default. Designing for agents first removes the tax that the forgiving consumer (humans) was silently paying. Bolt agent support onto a human-first CLI and you get the inconsistent, prompt-prone, stdout-only surfaces the first five principles exist to correct.
