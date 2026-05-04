# Agent CLI Audit Checklist

Per-principle checks with severity mapping. Apply only the rows relevant to each command class. Numbering matches [cli-principles.md](./cli-principles.md): five Tier 1 principles (Table Stakes), five Tier 2 principles (Compounding).

## Command classes

- **read** — query, list, get, search, describe (no side effects)
- **mutate** — create, update, delete, deploy, publish, send (changes state synchronously)
- **stream** — tail, follow, watch (long-running, ongoing output)
- **bootstrap** — init, install, setup wizards (one-shot, often interactive by design)
- **async** — submit a job that completes off-band; returns a job ID; requires polling or `--wait` (Principles 4 + 8 apply)
- **config** — profile, auth, preferences, local state management (Principle 9 applies)

### Classification decision tree

When a command sits between two classes, walk this tree top-to-bottom and stop at the first match:

1. Does it block on a remote process that may take >5s? → **async**
2. Does it write to local CLI state (`~/.<cli>/`) without remote effect? → **config**
3. Does it stream until the user kills it? → **stream**
4. Does it change remote state synchronously? → **mutate**
5. Does it return data without changing state? → **read**
6. Is it a one-shot setup wizard? → **bootstrap**

A command can satisfy two classes (e.g., a mutate that also writes to local state). In that case, apply checks from both classes — the principles are additive.

---

# Tier 1 — Table Stakes

## Principle 1 — Non-interactive by default

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Run with `stdin=DEVNULL` and 10s timeout — does it hang? | all except bootstrap | command hangs | exits but writes prompt to stderr | exits cleanly with TTY-aware behavior |
| Does `--no-input` / `--non-interactive` exist? | all | absent for mutating/async commands | exists on some commands only | global flag, documented |
| Does `--force` bypass confirmation on destructive ops? | mutate, async | confirmation cannot be bypassed | uses non-canonical name (`--skip-confirmations`, `--no-prompt`, `--yolo`) | uniform `--force` across all destructive commands |
| Does it detect TTY and behave accordingly? | all | spinners/prompts emitted to non-TTY | TTY detection partial | clean stream regardless of TTY |

## Principle 2 — Structured, parseable output

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| `--json` flag available? | read, mutate, async, config | absent on data commands | available on some commands only | uniform across all data-bearing commands |
| Single canonical output flag (`--json`, not `--format=json` mixed with `--output=json`)? | all | multiple competing flags for the same intent | one canonical exists but legacy aliases linger | exactly one flag, schema-enforced |
| Result data on stdout, diagnostics on stderr? | all | mixed streams | mostly correct but logging leaks to stdout | strict separation |
| Useful fields returned (IDs, URLs, status)? | mutate, async | success says nothing identifying | returns minimal info | full audit-friendly state object |
| ANSI color/spinners suppressed when piped? | all | colors emitted on non-TTY | partial suppression | clean output when piped |
| Exit code 0 on success, non-zero on failure? | all | inverted or zero on failure | inconsistent across commands | strict POSIX convention with stable taxonomy (1=generic, 2=usage, 3=network, 4=not-found, 5=auth, …) |

## Principle 3 — Errors that teach, and enumerate

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Errors name the specific problem (not "missing arguments")? | all | generic / silent | names problem only | names problem + fix + example |
| Validation runs before side effects? | mutate, async | mutation starts then fails midway | validation present but partial | full pre-flight validation |
| Enum failures enumerate the valid set inline? | all | no hint at valid values on enum mismatch | valid set listed but no example | listed plus offending value (`got: "..."`) plus working invocation |
| Structured refusal on unknown `--deliver` schemes (Principle 10)? | mutate, async | generic "invalid value" | names the offending scheme but not supported set | enumerates supported set inline |
| Stack traces avoided in user-facing output? | all | raw traceback on common errors | traceback for some errors | clean error messages always |

## Principle 4 — Safe retries & explicit mutation boundaries

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Replaying mutating command — duplicates state? | mutate | silent duplication / corruption | duplicates but warns | idempotent or clearly no-op on retry |
| Submit-poll-collect arc — second invocation finds in-flight job in ledger, not duplicates? | async | duplicate job submitted on `--wait` retry | recovery exists but undocumented | idempotency-key submission with ledger-backed recovery |
| `--dry-run` available for consequential mutations? | mutate, async | absent for high-blast-radius commands | partial coverage | universal on mutate and async |
| Destructive operations require explicit flag (`--force`)? | mutate (delete) | scriptable without confirmation | confirmation but not flag-based or non-canonical name | distinct canonical `--force` flag |
| Identifiers returned to verify outcome? | mutate, async | no IDs/URLs in success | partial | full audit trail (ID, URL, status, `existing` boolean for idempotent creates) |
| Idempotency irrelevant — skip these checks | stream, read, bootstrap | — | — | — |

## Principle 5 — Bounded responses, at every layer

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Pagination / limit on list commands? | read | unbounded by default | available but defaults too broad | sensible default (e.g., 25), max enforced |
| Truncation message teaches narrower query? | read | silent truncation or no truncation | shows count only | shows count + concrete narrowing example or cursor |
| Filter flags available (`--status`, `--since`, `--tag`)? | read | none | minimal | rich filter set |
| Concise vs detailed mode (`--summary` / `--verbose`)? | read | only one verbosity | partial | tunable, default narrow |
| Stream commands buffer reasonably? | stream | floods output without backpressure | partial | line-buffered with `--tail N` |
| MCP wrapper (if any) keeps per-tool description budget < ~1k tokens? | all (when wrapped) | a single tool description >2k tokens | descriptions trimmed but inconsistent across tools | every tool description fits in a tweet, audited at build time |

---

# Tier 2 — Compounding

## Principle 6 — Cross-CLI vocabulary consistency

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Verb naming uses canonical set (`get`/`list`/`create`/`update`/`delete`)? | all | uses banned verbs (`info`, `ls`, `describe`, `add`, `rm`, `destroy`) | minor variations across resources | single canonical verb per intent, schema-enforced |
| Confirmation-bypass flag is `--force` (not `--skip-confirmations`, `--no-prompt`, `--yolo`)? | mutate, async | uses banned alias | mixed — some commands use `--force`, others use alias | uniform `--force`, lint-enforced |
| Output flag is `--json` (not `--format=json`, `--output=json`, `-o json`)? | all | multiple competing flags | canonical `--json` exists but legacy aliases linger | exactly one canonical, all aliases removed |
| Pagination flag is `--limit` (not `--max-results`, `--page-size`, `--top`)? | read | banned alias | inconsistent across resources | uniform `--limit` |
| Profile/identity flag is `--profile` (not `--config-name`, `--context`)? | config, mutate (when using credentials) | banned alias | inconsistent | uniform `--profile` (Principle 9) |
| Banned-verb / banned-flag CI lint exists? | all | no enforcement, drift across resources | manual review only | static check in CI, fails the build on banned verbs/flags |

## Principle 7 — Three-layer introspection

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Top-level `--help` lists subcommands with one-line descriptions? | all | absent or undiscoverable | listed but no descriptions | listed with one-line summaries |
| Each subcommand `--help` shows invocation pattern + examples? | all | missing | partial | full Usage line + ≥1 example |
| `<cli> agent-context` (or equivalent) emits structured JSON description of the full surface? | all | absent | exists but undocumented or untested | top-level subcommand, documented, schema-validated |
| `agent-context.schema_version` field present and incremented on breaking changes? | all (when agent-context exists) | unversioned | versioned but unincremented | versioned with documented breaking-change policy |
| `agent-context` content matches `--help` content (no drift)? | all | drift between layers | manual sync | generated from same source; CI test asserts parity |
| Skill manifest / SKILL.md describing common workflows discoverable via the CLI (e.g., `<cli> skill-path`)? | all | absent | exists but in repo only, not surfaced by CLI | discoverable from the binary, versioned with CLI |

## Principle 8 — Async-aware execution

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| `--wait` flag on every submitting command? | async | absent — agent must write polling loop | exists but not on all submitters | universal on every async submission |
| Polling implementation uses exponential backoff with jitter? | async | tight loop or fixed-interval poll | backoff present but no jitter | exponential 1→2→4→8→30s cap with ±20% jitter |
| Persistent job ledger written at submit time (`~/.<cli>/jobs.jsonl` or equivalent)? | async | no ledger; recovery impossible | ledger exists but only in-memory | durable JSONL append-only, recoverable across processes |
| `jobs list / get / prune` parent command exposes ledger? | async | no inspection surface | partial (only `list`) | full triplet |
| `--wait` survives disconnect — second invocation finds in-flight job, not duplicates? | async | duplicate submit on retry | recovery exists but only via separate `jobs resume` | idempotency-key based; `--wait` retry transparently picks up |
| `jobs` outputs include `--json` and Principle 5 bounded defaults? | async | unbounded job list dump | bounded but no `--json` | uniform |

## Principle 9 — Persistent identity through profiles

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| `profile save / use / list / show / delete` subcommands present? | config (and mutate using credentials) | no profile system at all | partial set (e.g., only save/use, no show) | full quintuplet |
| `--profile <name>` available as persistent root flag? | config, mutate | no per-invocation override | exists but not honored uniformly | persistent on every command that consumes config |
| Precedence is explicit flag > env var > profile > default, enforced by single resolver? | config, mutate | precedence inverted or per-command-different | precedence documented but not deterministic | single code path resolves config; `--dry-run` shows resolved values |
| Profile names surfaced in `agent-context` (Principle 7)? | config | not introspectable | listed but unversioned | listed under `available_profiles` in versioned `agent-context` |
| Stable storage location (`~/.<cli>/profiles.json` or per-OS conventional path)? | config | location undocumented or inconsistent | documented but volatile | conventional, documented, migration-safe |

### Severity scaling for Principle 9

- CLI with ≤2 commands or no credential state → absence is **Optimization** at most.
- CLI with 3-5 commands using credentials → absence is **Friction**.
- CLI with >5 commands using credentials, or any CLI where users repeat the same flag set → absence is **Blocker** for daily use.

## Principle 10 — Two-way I/O

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| `--deliver` flag with `stdout`, `file:<path>`, `webhook:<url>` schemes? | mutate, async (when emitting artifacts) | output is stdout-only, no routing | only stdout + file (no webhook), or stdout + webhook (no file) | full triplet |
| File sinks write atomically (temp + fsync + rename)? | mutate, async | partial files visible during run | atomic-ish (rename without fsync) | full atomic with explicit fsync |
| Webhook sinks POST and surface HTTP status in response body? | mutate, async | no status surfaced; agent can't tell if delivery succeeded | partial — exit code reflects status but body doesn't | structured response with `delivered_to` + `status` |
| Unknown schemes return structured refusal (Principle 3 enumeration)? | mutate, async | generic "invalid value" | names value but not supported set | enumerates supported schemes inline |
| `<cli> feedback "<text>"` command appends to local JSONL? | all | no feedback channel at all | command exists but writes to stderr only | persistent JSONL, queryable via `feedback list` |
| Optional upstream POST configurable via `<CLI>_FEEDBACK_ENDPOINT`? | all | no upstream channel | exists but not surfaced | configured + reported in `agent-context` so agent can detect availability |
| Both `--deliver` schemes and feedback endpoint surfaced in `agent-context`? | all | not introspectable | partial (one or the other) | both versioned and machine-validated |

---

## Severity tie-breakers

When a check could plausibly be Blocker or Friction:

- **Mutating or async command + state corruption risk** → Blocker
- **Read command + agent must parse messy output** → Friction
- **Single missing piece on otherwise good design** → Optimization
- **Pattern absent across multiple commands** → escalate one tier
- **Pattern present on some but inconsistent** → Friction at minimum

### Tier 2-specific tie-breakers

- **Vocabulary inconsistency (Principle 6)** → escalate one tier for each additional command using a banned verb. A single `posts info` is Friction; the same CLI also shipping `accounts describe` and `--skip-confirmations` is Blocker territory.
- **Async without `--wait` (Principle 8)** in a CLI where >50% of commands submit jobs → Blocker (forces every workflow to write polling). In a CLI with one async command → Friction.
- **Profiles absent (Principle 9)** → see scaling table under Principle 9 (≤2 commands = Optimization, 3-5 = Friction, >5 = Blocker).
- **`agent-context` absent (Principle 7)** in CLIs with <5 commands → Optimization. CLIs with 5-20 commands → Friction. CLIs with >20 commands → Blocker, and additionally recommend codegen as architectural backstop.
- **`--deliver` absent (Principle 10)** when the CLI produces no artifacts (only emits status JSON) → not a finding. When it produces artifacts but is stdout-only → Friction (forces tempfile dance). When it produces artifacts that don't fit in a terminal buffer (videos, large blobs) → Blocker.

### Recommendation order — what to fix first

1. **All Blockers**, in order: hangs > silent duplication > broken parsing > vague errors > async without `--wait` > vocabulary in canonical verbs.
2. **All Friction items**, grouped by principle (so a single fix lands consistently across commands).
3. **Optimization items** only after Blockers and Friction are clear.
4. **Architectural backstop** (codegen / schema) — surface as a separate recommendation at the end of the report when:
   - CLI exposes >20 commands, OR
   - Vocabulary inconsistency findings appear in 3+ places, OR
   - `agent-context` and `--help` show drift.
