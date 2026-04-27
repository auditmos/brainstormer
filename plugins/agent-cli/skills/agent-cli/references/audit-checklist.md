# Agent CLI Audit Checklist

Per-principle checks with severity mapping. Apply only the rows relevant to each command class.

**Command classes:**
- **read** — query, list, get, search, describe (no side effects)
- **mutate** — create, update, delete, deploy, publish, send (changes state)
- **stream** — tail, follow, watch (long-running, ongoing output)
- **bootstrap** — init, install, setup wizards (one-shot, often interactive by design)

---

## Principle 1 — Non-interactive by default

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Run with `stdin=DEVNULL` and 10s timeout — does it hang? | all except bootstrap | command hangs | exits but writes prompt to stderr | exits cleanly with TTY-aware behavior |
| Does `--no-input` / `--non-interactive` exist? | all | absent for mutating commands | exists on some commands only | global flag, documented |
| Does `--yes` / `--force` / `--confirm` bypass confirmation? | mutate | confirmation cannot be bypassed | exists but inconsistent across commands | uniform across all destructive commands |
| Does it detect TTY and behave accordingly? | all | spinners/prompts emitted to non-TTY | TTY detection partial | clean stream regardless of TTY |

## Principle 2 — Structured, parseable output

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| `--json` flag available? | read, mutate | absent on data commands | available on some commands only | uniform across all data-bearing commands |
| Result data on stdout, diagnostics on stderr? | all | mixed streams | mostly correct but logging leaks to stdout | strict separation |
| Useful fields returned (IDs, URLs, status)? | mutate | success says nothing identifying | returns minimal info | full audit-friendly state object |
| ANSI color/spinners suppressed when piped? | all | colors emitted on non-TTY | partial suppression | clean output when piped |
| Exit code 0 on success, non-zero on failure? | all | inverted or zero on failure | inconsistent across commands | strict POSIX convention |

## Principle 3 — Fail fast with actionable errors

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Errors name the specific problem (not "missing arguments")? | all | generic / silent | names problem only | names problem + fix + example |
| Validation runs before side effects? | mutate | mutation starts then fails midway | validation present but partial | full pre-flight validation |
| Valid values suggested on enum failures? | all | no hint | valid values listed | listed plus inline example |
| Stack traces avoided in user-facing output? | all | raw traceback on common errors | traceback for some errors | clean error messages always |

## Principle 4 — Safe retries & explicit mutation boundaries

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Replaying mutating command — duplicates state? | mutate | silent duplication / corruption | duplicates but warns | idempotent or clearly no-op on retry |
| `--dry-run` available for consequential mutations? | mutate | absent for high-blast-radius commands | partial coverage | universal on mutate |
| Destructive operations require explicit flag? | mutate (delete) | scriptable without confirmation | confirmation but not flag-based | distinct flag like `--confirm` or `--force-delete` |
| Identifiers returned to verify outcome? | mutate | no IDs/URLs in success | partial | full audit trail |
| Idempotency irrelevant — skip these checks | stream, read | — | — | — |

## Principle 5 — Progressive help discovery

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Top-level `--help` lists subcommands? | all | absent or undiscoverable | listed but no descriptions | listed with one-line summaries |
| Each subcommand `--help` shows invocation pattern? | all | missing | partial | full Usage: line |
| Required vs optional flags distinguished? | all | not marked | marked inconsistently | clear required marker |
| Examples included in help? | all | none | one example | multiple covering common paths |
| Default values shown for optional flags? | all | hidden | inconsistent | always shown |

## Principle 6 — Composable & predictable structure

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Accepts stdin where useful (`--stdin` or `-`)? | read, mutate (bulk) | piping impossible | partial support | uniform `--stdin` pattern |
| Flag naming consistent across resources? | all | wildly inconsistent (`--limit` vs `--max-results`) | minor variations | strict consistency |
| Subcommand structure consistent (`<resource> <verb>`)? | all | mix of styles | mostly consistent | uniform pattern |
| Positional args reserved for unambiguous cases? | all | overloaded positional args | moderate reliance | flags-first design |

## Principle 7 — Bounded, high-signal responses

| Check | Applies to | Blocker if | Friction if | Optimization if |
|-------|-----------|------------|-------------|-----------------|
| Pagination / limit on list commands? | read | unbounded by default | available but defaults too broad | sensible default (e.g., 25), max enforced |
| Truncation message teaches narrower query? | read | silent truncation or no truncation | shows count only | shows count + suggested narrowing command |
| Filter flags available (`--status`, `--since`, `--tag`)? | read | none | minimal | rich filter set |
| Concise vs detailed mode (`--summary` / `--verbose`)? | read | only one verbosity | partial | tunable, default narrow |
| Stream commands buffer reasonably? | stream | floods output without backpressure | partial | line-buffered with `--tail N` |

---

## Severity tie-breakers

When a check could plausibly be Blocker or Friction:

- **Mutating command + state corruption risk** → Blocker
- **Read command + agent must parse messy output** → Friction
- **Single missing piece on otherwise good design** → Optimization
- **Pattern absent across multiple commands** → escalate one tier
- **Pattern present on some but inconsistent** → Friction at minimum

When the user asks "what to fix first," recommend in this order:

1. All Blockers, in order: hangs > silent duplication > broken parsing > vague errors
2. All Friction items, grouped by principle (so a single fix lands consistently across commands)
3. Optimization items only after Blockers and Friction are clear
