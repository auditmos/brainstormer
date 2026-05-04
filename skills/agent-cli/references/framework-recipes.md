# Framework Recipes — Idiomatic Agent-Friendly Patterns

Drop-in patterns per CLI framework. Use these snippets as the recommended fix when a finding maps to a specific framework. Cover the common five: Click, argparse, Cobra, clap, Commander/yargs, plus oclif.

---

## Python — Click

### Non-interactive default + TTY detection

```python
import sys, click

@click.command()
@click.option("--content", required=True, type=click.Path(exists=True))
@click.option("--status", type=click.Choice(["draft", "published", "scheduled"]),
              default="published", show_default=True)
@click.option("--yes", is_flag=True, help="Skip confirmation")
@click.option("--no-input", is_flag=True, help="Disable all interactive prompts")
@click.option("--json", "json_out", is_flag=True, help="Output as JSON")
def publish(content, status, yes, no_input, json_out):
    is_tty = sys.stdin.isatty() and not no_input
    if not yes and is_tty:
        click.confirm(f"Publish as {status}?", abort=True)
    elif not yes and not is_tty:
        # Non-interactive context — fail fast with actionable error
        raise click.UsageError("Confirmation required. Pass --yes in non-interactive contexts.")
    ...
```

### `--json` output with stream separation

```python
import json, sys, click

if json_out:
    click.echo(json.dumps(result, ensure_ascii=False))   # stdout
else:
    click.secho(f"Published \"{result['title']}\"", fg="green" if sys.stdout.isatty() else None)
    click.echo(f"URL: {result['url']}")
# Diagnostics always to stderr:
click.echo("info: cache refreshed", err=True)
```

Click suppresses `secho` colors automatically when stdout is not a TTY only if `color=None`; pass it explicitly to be safe.

**Vocabulary note (Principle 6):** standardize on `--json` across every command — never ship `--format=json`, `--output=json`, and `--json` as three ways to mean the same thing. Pick one, lint the rest as Principle 6 violations.

### Actionable errors

```python
class ContentRequired(click.UsageError):
    def format_message(self):
        return ("--content is required.\n"
                "Usage: blog-cli publish --content <file> [--status <status>]\n"
                "Available statuses: draft, published, scheduled\n"
                "Example: blog-cli publish --content my-post.md")
```

### Idempotency hint on retry

```python
existing = lookup_by_hash(content_hash)
if existing:
    click.echo(f"Already published \"{existing['title']}\", no changes (post_id: {existing['id']})")
    return
```

---

## Python — argparse

### Non-interactive + TTY-aware

```python
import argparse, sys, json

p = argparse.ArgumentParser(prog="blog-cli")
sub = p.add_subparsers(dest="cmd", required=True)

pub = sub.add_parser("publish", help="Publish content")
pub.add_argument("--content", required=True)
pub.add_argument("--status", choices=["draft", "published", "scheduled"], default="published")
pub.add_argument("--yes", action="store_true")
pub.add_argument("--no-input", action="store_true")
pub.add_argument("--json", dest="json_out", action="store_true")

args = p.parse_args()
is_tty = sys.stdin.isatty() and not args.no_input

if args.cmd == "publish" and not args.yes:
    if not is_tty:
        p.error("Confirmation required. Pass --yes in non-interactive contexts.")
    if input(f"Publish as {args.status}? [y/N] ").lower() != "y":
        sys.exit(1)
```

### Custom error formatting (override `error()`)

```python
class HelpfulParser(argparse.ArgumentParser):
    def error(self, message):
        sys.stderr.write(f"Error: {message}\n")
        sys.stderr.write(f"Usage: {self.format_usage()}\n")
        sys.stderr.write("Run with --help for examples.\n")
        sys.exit(2)
```

### `--json` output

```python
if args.json_out:
    print(json.dumps(result))
else:
    print(f"Published \"{result['title']}\" to personal")
    print(f"URL: {result['url']}")
```

---

## Go — Cobra

### Non-interactive + TTY-aware

```go
import (
    "github.com/mattn/go-isatty"
    "github.com/spf13/cobra"
    "os"
)

var publishCmd = &cobra.Command{
    Use:   "publish",
    Short: "Publish content",
    Example: `  blog-cli publish --content my-post.md
  blog-cli publish --content my-post.md --status draft
  blog-cli publish --content my-post.md --dry-run`,
    RunE: func(cmd *cobra.Command, args []string) error {
        isTTY := isatty.IsTerminal(os.Stdin.Fd()) && !noInput
        if !yes && !isTTY {
            return fmt.Errorf("--yes required in non-interactive contexts")
        }
        ...
    },
}

func init() {
    publishCmd.Flags().StringVar(&content, "content", "", "Path to markdown file (required)")
    publishCmd.Flags().StringVar(&status, "status", "published", "draft|published|scheduled")
    publishCmd.Flags().BoolVar(&yes, "yes", false, "Skip confirmation")
    publishCmd.Flags().BoolVar(&noInput, "no-input", false, "Disable interactive prompts")
    publishCmd.Flags().BoolVar(&jsonOut, "json", false, "Output as JSON")
    publishCmd.MarkFlagRequired("content")
}
```

### `--json` output with stream separation

```go
if jsonOut {
    json.NewEncoder(cmd.OutOrStdout()).Encode(result)
} else {
    fmt.Fprintf(cmd.OutOrStdout(), "Published %q\n", result.Title)
}
fmt.Fprintln(cmd.ErrOrStderr(), "info: cache refreshed")
```

Cobra's `cmd.OutOrStdout()` / `cmd.ErrOrStderr()` make testability trivial and enforce separation.

**Vocabulary note (Principle 6):** standardize on `--json` across every command — never `--format=json` mixed with `--output json` for different subcommands. Cobra has no built-in lint for this; enforce with a static check at build time (see Tier 2 recipes below).

### Actionable errors

```go
return fmt.Errorf(`--content is required.
Usage: blog-cli publish --content <file> [--status <status>]
Available statuses: draft, published, scheduled
Example: blog-cli publish --content my-post.md`)
```

---

## Rust — clap

### Non-interactive + TTY-aware

```rust
use clap::{Parser, ValueEnum};
use std::io::IsTerminal;

#[derive(Parser)]
#[command(name = "blog-cli")]
struct Cli {
    #[arg(long, required = true)]
    content: String,
    #[arg(long, value_enum, default_value_t = Status::Published)]
    status: Status,
    #[arg(long)]
    yes: bool,
    #[arg(long, alias = "no-input")]
    non_interactive: bool,
    #[arg(long)]
    json: bool,
}

#[derive(ValueEnum, Clone, Debug)]
enum Status { Draft, Published, Scheduled }

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let is_tty = std::io::stdin().is_terminal() && !cli.non_interactive;

    if !cli.yes && !is_tty {
        anyhow::bail!("--yes required in non-interactive contexts");
    }
    ...
}
```

### `--json` output

```rust
if cli.json {
    println!("{}", serde_json::to_string(&result)?);
} else {
    println!("Published \"{}\" to personal", result.title);
}
eprintln!("info: cache refreshed");
```

### Color suppression for piped output

```rust
use clap::ColorChoice;

#[command(color = ColorChoice::Auto)]   // disables colors when stdout is not TTY
```

---

## Node.js — Commander / yargs

### Commander — non-interactive + TTY

```js
import { Command } from "commander";

const program = new Command();
program
  .command("publish")
  .description("Publish content")
  .requiredOption("--content <file>", "Path to markdown file")
  .option("--status <status>", "draft|published|scheduled", "published")
  .option("--yes", "Skip confirmation")
  .option("--no-input", "Disable interactive prompts")
  .option("--json", "Output as JSON")
  .addHelpText("after", `
Examples:
  $ blog-cli publish --content my-post.md
  $ blog-cli publish --content my-post.md --status draft`)
  .action(async (opts) => {
    const isTTY = process.stdin.isTTY && opts.input;
    if (!opts.yes && !isTTY) {
      console.error("Error: --yes required in non-interactive contexts");
      process.exit(2);
    }
    ...
  });
```

### yargs — same idea

```js
import yargs from "yargs";

await yargs(process.argv.slice(2))
  .command("publish", "Publish content", (y) => y
    .option("content", { demandOption: true, type: "string" })
    .option("status", { choices: ["draft", "published", "scheduled"], default: "published" })
    .option("yes", { type: "boolean", default: false })
    .option("no-input", { type: "boolean", default: false })
    .option("json", { type: "boolean", default: false })
    .example("$0 publish --content my-post.md", "Publish a post")
    .strict()
    .fail((msg, err, y) => {
      console.error(`Error: ${msg}\n${y.help()}`);
      process.exit(2);
    }), async (argv) => { ... })
  .parse();
```

### `--json` + stream separation

```js
if (argv.json) {
  process.stdout.write(JSON.stringify(result) + "\n");
} else {
  process.stdout.write(`Published "${result.title}"\n`);
}
process.stderr.write("info: cache refreshed\n");
```

---

## Node.js — oclif

oclif handles `--help`, examples, and TTY detection idiomatically. Key patterns:

```ts
import { Command, Flags } from "@oclif/core";

export default class Publish extends Command {
  static description = "Publish a markdown file to your blog.";
  static examples = [
    "<%= config.bin %> publish --content my-post.md",
    "<%= config.bin %> publish --content my-post.md --status draft",
  ];
  static flags = {
    content: Flags.file({ required: true, exists: true }),
    status: Flags.string({ options: ["draft", "published", "scheduled"], default: "published" }),
    yes: Flags.boolean({ default: false, summary: "Skip confirmation" }),
    "no-input": Flags.boolean({ default: false, summary: "Disable interactive prompts" }),
    json: Flags.boolean({ default: false, summary: "Output as JSON" }),
  };

  async run(): Promise<void> {
    const { flags } = await this.parse(Publish);
    const isTTY = process.stdin.isTTY && !flags["no-input"];
    if (!flags.yes && !isTTY) this.error("--yes required in non-interactive contexts", { exit: 2 });

    const result = await publish(flags);
    if (flags.json) this.log(JSON.stringify(result));
    else this.log(`Published "${result.title}"`);
    this.warn("cache refreshed");   // → stderr
  }
}
```

oclif also generates `--help` in the right shape automatically and supports `--json` as a built-in flag pattern for commands that opt in.

---

## Cross-framework: bounded responses & pagination

Regardless of framework, list commands should follow this pattern:

```
$ tool list-things --limit 25
Showing 25 of 312 things
To narrow: tool list-things --status active --since 7d --limit 10
```

Implementation hint — always return `{ items, total, has_more, next_token }` in the JSON shape so agents can paginate without re-counting:

```json
{
  "items": [{"id": "thing_1"}, ...],
  "total": 312,
  "showing": 25,
  "has_more": true,
  "narrow_hint": "blog-cli posts list --status published --since 7d --limit 10"
}
```

The `narrow_hint` field is unusual but high-impact for agents — it converts truncation into an actionable next step rather than a parsing problem.

---

## Cross-framework: testing for non-interactive behavior

Use this snippet (or its language equivalent) in CI to catch regressions where a command starts hanging on missing input:

```bash
# Bash equivalent of the Python recipe
timeout 10 your-cli your-command </dev/null
[ $? -eq 124 ] && { echo "FAIL: command hung waiting for input"; exit 1; }
echo "PASS: command exited without hanging"
```

Plug it into the CI matrix once per mutating command. The cost is low; the regressions it catches are otherwise invisible until an agent hits production.

---

# Tier 2 — Compounding recipes

The recipes above (Tier 1) cover the original five principles condensed from the seven-principle source. The recipes below cover the five compounding principles introduced in the agent-native taxonomy: cross-CLI vocabulary consistency, three-layer introspection, async-aware execution, persistent profiles, and two-way I/O.

**Coverage:** full snippets for Click, Cobra, Commander, and oclif. For argparse / clap / yargs, the polling, ledger, profile, and delivery logic is framework-agnostic — the only differences are flag-declaration syntax. Each section ends with a one-line pointer.

---

## Principle 6 — Cross-CLI vocabulary consistency

The mechanical fix is a build-time lint against banned verbs and flag aliases. Frameworks differ in how they expose the command tree for inspection, but the lint logic is identical.

### Click — vocabulary lint via pytest

```python
# tests/test_vocabulary.py
import pytest
from blog_cli.cli import cli   # the click.Group root

BANNED_VERBS = {"info", "ls", "describe", "add", "rm", "destroy", "edit", "modify"}
BANNED_FLAGS = {"--skip-confirmations", "--no-prompt", "--yolo",
                "--format", "--output", "--max-results", "--page-size", "--top"}

def walk(group, path=()):
    for name, cmd in group.commands.items():
        yield (*path, name), cmd
        if hasattr(cmd, "commands"):
            yield from walk(cmd, (*path, name))

def test_no_banned_verbs():
    bad = [path for path, _ in walk(cli) if path[-1] in BANNED_VERBS]
    assert not bad, f"Banned verbs found: {bad}. Use canonical: get/list/create/update/delete."

def test_no_banned_flags():
    bad = []
    for path, cmd in walk(cli):
        for param in cmd.params:
            for opt in param.opts:
                if opt in BANNED_FLAGS:
                    bad.append((path, opt))
    assert not bad, f"Banned flags found: {bad}. Use --force/--json/--limit/--profile."
```

### Cobra — vocabulary lint via Go test

```go
// vocabulary_lint_test.go
package main

import (
    "strings"
    "testing"
    "github.com/spf13/cobra"
)

var bannedVerbs = map[string]bool{
    "info": true, "ls": true, "describe": true, "add": true, "rm": true, "destroy": true,
}
var bannedFlags = map[string]bool{
    "skip-confirmations": true, "no-prompt": true, "yolo": true,
    "format": true, "output": true, "max-results": true, "page-size": true, "top": true,
}

func walk(cmd *cobra.Command, fn func(*cobra.Command)) {
    fn(cmd)
    for _, c := range cmd.Commands() {
        walk(c, fn)
    }
}

func TestNoBannedVerbs(t *testing.T) {
    var bad []string
    walk(rootCmd, func(c *cobra.Command) {
        if bannedVerbs[c.Use] || bannedVerbs[strings.Split(c.Use, " ")[0]] {
            bad = append(bad, c.CommandPath())
        }
    })
    if len(bad) > 0 {
        t.Errorf("banned verbs: %v — use get/list/create/update/delete", bad)
    }
}

func TestNoBannedFlags(t *testing.T) {
    var bad []string
    walk(rootCmd, func(c *cobra.Command) {
        c.Flags().VisitAll(func(f *pflag.Flag) {
            if bannedFlags[f.Name] {
                bad = append(bad, c.CommandPath()+":--"+f.Name)
            }
        })
    })
    if len(bad) > 0 {
        t.Errorf("banned flags: %v — use --force/--json/--limit/--profile", bad)
    }
}
```

### Commander — vocabulary lint via vitest

```ts
// tests/vocabulary.test.ts
import { describe, it, expect } from "vitest";
import { program } from "../src/cli";   // the Commander root

const BANNED_VERBS = new Set(["info", "ls", "describe", "add", "rm", "destroy"]);
const BANNED_FLAGS = new Set([
  "--skip-confirmations", "--no-prompt", "--yolo",
  "--format", "--output", "--max-results", "--page-size", "--top",
]);

function walk(cmd, path = []) {
  const entries = [{ path: [...path, cmd.name()], cmd }];
  for (const sub of cmd.commands) entries.push(...walk(sub, [...path, cmd.name()]));
  return entries;
}

describe("Principle 6 — vocabulary consistency", () => {
  it("uses no banned verbs", () => {
    const bad = walk(program).filter((e) => BANNED_VERBS.has(e.path.at(-1)));
    expect(bad, `banned verbs: ${bad.map((e) => e.path.join(" "))}`).toHaveLength(0);
  });

  it("uses no banned flags", () => {
    const bad = [];
    for (const e of walk(program)) {
      for (const opt of e.cmd.options) {
        if (BANNED_FLAGS.has(opt.long) || BANNED_FLAGS.has(opt.short)) {
          bad.push(`${e.path.join(" ")} ${opt.long}`);
        }
      }
    }
    expect(bad).toHaveLength(0);
  });
});
```

### oclif — vocabulary lint via manifest introspection

```ts
// test/vocabulary.test.ts
import { describe, it, expect } from "vitest";
import { Manifest } from "@oclif/core/lib/interfaces";
import manifest from "../oclif.manifest.json";

const BANNED_VERBS = ["info", "ls", "describe", "add", "rm", "destroy"];

describe("Principle 6 — vocabulary consistency", () => {
  it("topic and command IDs use canonical verbs", () => {
    const ids = Object.keys((manifest as Manifest).commands);
    const bad = ids.filter((id) => BANNED_VERBS.some((v) => id.endsWith(`:${v}`)));
    expect(bad, `banned verbs: ${bad}`).toHaveLength(0);
  });
});
```

> **argparse / clap / yargs** — pattern is identical: walk the parser tree, assert that command names and flag long-names are not in the banned set. Reference the Click recipe (Python) or Commander recipe (Node) and adapt to the parser's introspection API. clap exposes the command tree via `Command::get_subcommands()`; yargs via `argv.help()` text grep or by reaching into the internal command store.

---

## Principle 7 — Three-layer introspection (`agent-context`)

Layer 1 (`--help`) is built-in to every framework. Layer 2 (`<cli> agent-context`) needs to be added as a top-level subcommand that walks the command tree and emits versioned JSON. Layer 3 (skill manifest) is a static file — surface it via a `<cli> skill-path` command.

### Click — `agent-context` subcommand

```python
import json
import click

SCHEMA_VERSION = "1"

def describe_command(cmd):
    return {
        "help": cmd.help or "",
        "flags": {
            opt: {
                "type": param.type.name if hasattr(param.type, "name") else str(param.type),
                "required": param.required,
                "default": param.default,
                "values": list(param.type.choices) if isinstance(param.type, click.Choice) else None,
            }
            for param in cmd.params for opt in param.opts
        },
        "subcommands": {n: describe_command(c) for n, c in cmd.commands.items()}
            if isinstance(cmd, click.Group) else {},
    }

@click.command("agent-context")
@click.pass_context
def agent_context(ctx):
    """Emit a versioned JSON description of the entire CLI surface."""
    root = ctx.find_root().command
    payload = {
        "schema_version": SCHEMA_VERSION,
        "cli": "blog-cli",
        "commands": {n: describe_command(c) for n, c in root.commands.items() if n != "agent-context"},
        "available_profiles": list_profiles(),                 # Principle 9
        "deliver_schemes": ["stdout", "file:<path>", "webhook:<url>"],  # Principle 10
        "feedback_endpoint_configured": bool(os.getenv("BLOG_CLI_FEEDBACK_ENDPOINT")),
    }
    click.echo(json.dumps(payload, indent=2))

cli.add_command(agent_context)
```

### Cobra — `agent-context` command

```go
import (
    "encoding/json"
    "github.com/spf13/cobra"
    "github.com/spf13/pflag"
)

const SchemaVersion = "1"

type FlagDef struct {
    Type     string      `json:"type"`
    Required bool        `json:"required,omitempty"`
    Default  interface{} `json:"default,omitempty"`
    Values   []string    `json:"values,omitempty"`
}

type CmdDef struct {
    Help        string             `json:"help"`
    Flags       map[string]FlagDef `json:"flags"`
    Subcommands map[string]CmdDef  `json:"subcommands,omitempty"`
}

func describeCmd(c *cobra.Command) CmdDef {
    out := CmdDef{Help: c.Short, Flags: map[string]FlagDef{}, Subcommands: map[string]CmdDef{}}
    c.Flags().VisitAll(func(f *pflag.Flag) {
        out.Flags["--"+f.Name] = FlagDef{Type: f.Value.Type(), Default: f.DefValue}
    })
    for _, sub := range c.Commands() {
        if sub.Name() == "agent-context" { continue }
        out.Subcommands[sub.Name()] = describeCmd(sub)
    }
    return out
}

var agentContextCmd = &cobra.Command{
    Use:   "agent-context",
    Short: "Emit versioned JSON description of the CLI surface",
    RunE: func(cmd *cobra.Command, args []string) error {
        payload := map[string]interface{}{
            "schema_version":                 SchemaVersion,
            "cli":                            rootCmd.Use,
            "commands":                       describeCmd(rootCmd).Subcommands,
            "available_profiles":             listProfiles(),
            "deliver_schemes":                []string{"stdout", "file:<path>", "webhook:<url>"},
            "feedback_endpoint_configured":   os.Getenv("BLOG_CLI_FEEDBACK_ENDPOINT") != "",
        }
        return json.NewEncoder(cmd.OutOrStdout()).Encode(payload)
    },
}

func init() { rootCmd.AddCommand(agentContextCmd) }
```

### Commander — `agent-context` command

```js
import { Command } from "commander";

const SCHEMA_VERSION = "1";

function describe(cmd) {
  const flags = {};
  for (const opt of cmd.options) {
    flags[opt.long] = {
      type: opt.argChoices ? "enum" : (opt.required ? "string" : "bool"),
      required: opt.mandatory ?? false,
      default: opt.defaultValue,
      values: opt.argChoices ?? null,
    };
  }
  const subcommands = {};
  for (const sub of cmd.commands) {
    if (sub.name() === "agent-context") continue;
    subcommands[sub.name()] = describe(sub);
  }
  return { help: cmd.description(), flags, subcommands };
}

program
  .command("agent-context")
  .description("Emit versioned JSON description of the CLI surface")
  .action(() => {
    const payload = {
      schema_version: SCHEMA_VERSION,
      cli: program.name(),
      commands: describe(program).subcommands,
      available_profiles: listProfiles(),
      deliver_schemes: ["stdout", "file:<path>", "webhook:<url>"],
      feedback_endpoint_configured: Boolean(process.env.BLOG_CLI_FEEDBACK_ENDPOINT),
    };
    process.stdout.write(JSON.stringify(payload, null, 2) + "\n");
  });
```

### oclif — `agent-context` from manifest

```ts
import { Command } from "@oclif/core";
import manifest from "../oclif.manifest.json";

const SCHEMA_VERSION = "1";

export default class AgentContext extends Command {
  static description = "Emit versioned JSON description of the CLI surface";

  async run(): Promise<void> {
    const payload = {
      schema_version: SCHEMA_VERSION,
      cli: this.config.name,
      commands: manifest.commands,                         // already structured
      available_profiles: await listProfiles(this.config),
      deliver_schemes: ["stdout", "file:<path>", "webhook:<url>"],
      feedback_endpoint_configured: Boolean(process.env.BLOG_CLI_FEEDBACK_ENDPOINT),
    };
    this.log(JSON.stringify(payload, null, 2));
  }
}
```

oclif is the most ergonomic for Layer 2 because the manifest already exists — `agent-context` is just a thin re-emit.

> **argparse / clap / yargs** — pattern is identical: walk the parser tree, serialize `{help, flags, subcommands}` to JSON, prepend `schema_version`. clap: walk `Command::get_subcommands()`. yargs: introspect `argv.getInternalMethods().getCommandInstance().getCommands()`. argparse: walk `parser._subparsers._actions[N].choices`.

---

## Principle 8 — `--wait` + persistent job ledger

The polling logic, ledger format, and recovery behavior are framework-agnostic. The only framework-specific differences are how `--wait` is declared as a flag and how the `jobs` parent command is registered.

### Shared logic — polling helper (Python reference)

```python
# blog_cli/jobs.py — language-agnostic shape, Python implementation
import json, os, random, time, uuid
from pathlib import Path

LEDGER_PATH = Path.home() / ".blog-cli" / "jobs.jsonl"
LEDGER_PATH.parent.mkdir(parents=True, exist_ok=True)

def submit_job(api, kind, payload, idempotency_key=None):
    """Submit, returning a ledger-tracked job_id. Reuses existing job on retry."""
    key = idempotency_key or _hash(kind, payload)
    existing = _find_in_ledger(idempotency_key=key)
    if existing and existing["status"] not in ("complete", "failed"):
        return existing["job_id"]
    job_id = api.submit(kind, payload, idempotency_key=key)
    _append_ledger({"job_id": job_id, "kind": kind, "idempotency_key": key,
                    "status": "queued", "submitted_at": time.time()})
    return job_id

def wait_for(api, job_id, timeout=600):
    """Block until complete; exponential backoff with jitter; survives reentry."""
    delay = 1.0
    deadline = time.time() + timeout
    while time.time() < deadline:
        status = api.status(job_id)
        _update_ledger(job_id, status)
        if status["status"] in ("complete", "failed"):
            return status
        time.sleep(delay + random.uniform(-0.2, 0.2) * delay)
        delay = min(delay * 2, 30.0)
    raise TimeoutError(f"job {job_id} did not complete within {timeout}s")
```

### Click — `--wait` flag + `jobs` group

```python
@click.command("render")
@click.option("--script", required=True, type=click.Path(exists=True))
@click.option("--wait", is_flag=True, help="Block until job completes")
@click.option("--json", "json_out", is_flag=True)
def render(script, wait, json_out):
    job_id = submit_job(api, "video.render", {"script": Path(script).read_text()})
    if wait:
        result = wait_for(api, job_id)
        click.echo(json.dumps(result) if json_out else f"complete: {result['url']}")
    else:
        click.echo(json.dumps({"job_id": job_id, "status": "queued"}))

@click.group("jobs")
def jobs_group():
    """Inspect async jobs."""

@jobs_group.command("list")
@click.option("--limit", default=25)
@click.option("--json", "json_out", is_flag=True)
def jobs_list(limit, json_out):
    entries = list(_iter_ledger())[-limit:]
    click.echo(json.dumps(entries) if json_out else _format_table(entries))

@jobs_group.command("get")
@click.argument("job_id")
def jobs_get(job_id):
    click.echo(json.dumps(_find_in_ledger(job_id=job_id)))

@jobs_group.command("prune")
@click.option("--older-than", default="7d")
def jobs_prune(older_than):
    n = _prune_ledger(older_than)
    click.echo(json.dumps({"pruned": n}))
```

### Cobra — `--wait` + `jobs` subcommand tree

```go
// cmd/render.go
var renderCmd = &cobra.Command{
    Use: "render",
    RunE: func(cmd *cobra.Command, args []string) error {
        jobID, err := SubmitJob(api, "video.render", payload, "")
        if err != nil { return err }
        if wait {
            result, err := WaitFor(api, jobID, 600*time.Second)
            if err != nil { return err }
            return jsonEncode(cmd.OutOrStdout(), result)
        }
        return jsonEncode(cmd.OutOrStdout(), map[string]string{"job_id": jobID, "status": "queued"})
    },
}

func init() { renderCmd.Flags().BoolVar(&wait, "wait", false, "Block until job completes") }

// cmd/jobs.go — parent group with list/get/prune
var jobsCmd = &cobra.Command{Use: "jobs", Short: "Inspect async jobs"}
var jobsListCmd = &cobra.Command{Use: "list", RunE: func(cmd *cobra.Command, args []string) error {
    return jsonEncode(cmd.OutOrStdout(), ListLedger(limit))
}}
// ... jobsGetCmd, jobsPruneCmd similarly
func init() { jobsCmd.AddCommand(jobsListCmd, jobsGetCmd, jobsPruneCmd); rootCmd.AddCommand(jobsCmd) }
```

### Commander — `--wait` + `jobs` group

```js
import fs from "node:fs";
import path from "node:path";

const LEDGER = path.join(process.env.HOME, ".blog-cli", "jobs.jsonl");

async function submitJob(api, kind, payload, idempotencyKey) {
  const key = idempotencyKey ?? hash(kind, payload);
  const existing = findInLedger({ idempotencyKey: key });
  if (existing && !["complete", "failed"].includes(existing.status)) return existing.job_id;
  const id = await api.submit(kind, payload, key);
  appendLedger({ job_id: id, kind, idempotency_key: key, status: "queued", submitted_at: Date.now() });
  return id;
}

async function waitFor(api, jobId, timeoutMs = 600_000) {
  let delay = 1000;
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const status = await api.status(jobId);
    updateLedger(jobId, status);
    if (["complete", "failed"].includes(status.status)) return status;
    await new Promise((r) => setTimeout(r, delay + (Math.random() - 0.5) * 0.4 * delay));
    delay = Math.min(delay * 2, 30_000);
  }
  throw new Error(`job ${jobId} timed out`);
}

program
  .command("render")
  .requiredOption("--script <file>")
  .option("--wait", "Block until job completes")
  .option("--json", "Output as JSON")
  .action(async ({ script, wait, json }) => {
    const id = await submitJob(api, "video.render", { script: fs.readFileSync(script, "utf8") });
    const out = wait ? await waitFor(api, id) : { job_id: id, status: "queued" };
    process.stdout.write(JSON.stringify(out) + "\n");
  });

const jobs = program.command("jobs").description("Inspect async jobs");
jobs.command("list").option("--limit <n>", "Max entries", "25").action(({ limit }) => {
  process.stdout.write(JSON.stringify(listLedger(Number(limit))) + "\n");
});
jobs.command("get <id>").action((id) => process.stdout.write(JSON.stringify(findInLedger({ job_id: id })) + "\n"));
jobs.command("prune").option("--older-than <duration>", "Threshold", "7d").action(({ olderThan }) => {
  process.stdout.write(JSON.stringify({ pruned: pruneLedger(olderThan) }) + "\n");
});
```

### oclif — `--wait` + `jobs` topic

```ts
// src/commands/render.ts
import { Command, Flags } from "@oclif/core";
import { submitJob, waitFor } from "../lib/jobs";

export default class Render extends Command {
  static flags = {
    script: Flags.file({ required: true, exists: true }),
    wait: Flags.boolean({ default: false, summary: "Block until job completes" }),
    json: Flags.boolean({ default: false }),
  };

  async run(): Promise<void> {
    const { flags } = await this.parse(Render);
    const jobId = await submitJob("video.render", { script: flags.script });
    const out = flags.wait ? await waitFor(jobId) : { job_id: jobId, status: "queued" };
    this.log(JSON.stringify(out));
  }
}

// src/commands/jobs/list.ts, jobs/get.ts, jobs/prune.ts — standard oclif topic pattern
```

> **argparse / clap / yargs** — the polling logic in `submitJob` / `waitFor` is framework-agnostic; lift the Python or Node helpers verbatim. The only framework piece is declaring `--wait` as a boolean flag and registering a `jobs` parent with three children. See Click recipe (Python) or Commander recipe (Node) for reference.

---

## Principle 9 — Profile system

Profiles persist to `~/.<cli>/profiles.json`. The precedence resolver — explicit flag > env var > profile > default — must live in a single code path that every command consumes.

### Click — profile group + resolver

```python
import json, os, click
from pathlib import Path

PROFILE_PATH = Path.home() / ".blog-cli" / "profiles.json"
PROFILE_PATH.parent.mkdir(parents=True, exist_ok=True)

def load_profiles() -> dict:
    return json.loads(PROFILE_PATH.read_text()) if PROFILE_PATH.exists() else {}

def save_profiles(data: dict) -> None:
    tmp = PROFILE_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2))
    os.replace(tmp, PROFILE_PATH)

def resolve(field: str, flag_value, env_name: str, profile_name: str | None, default=None):
    """Single source of truth for config resolution. Used by every command."""
    if flag_value is not None: return flag_value
    if (env := os.getenv(env_name)) is not None: return env
    if profile_name and (p := load_profiles().get(profile_name)):
        if field in p: return p[field]
    return default

@click.group("profile")
def profile_group():
    """Manage saved profiles."""

@profile_group.command("save")
@click.argument("name")
@click.option("--avatar"); @click.option("--voice"); @click.option("--webhook")
def profile_save(name, avatar, voice, webhook):
    profiles = load_profiles()
    profiles[name] = {k: v for k, v in {"avatar": avatar, "voice": voice, "webhook": webhook}.items() if v}
    save_profiles(profiles)
    click.echo(json.dumps({"profile": name, "saved": True}))

# list / show / delete / use — analogous

# Root flag — persistent, consumed by every command via resolve()
@click.option("--profile", "profile_name", help="Use a saved profile", expose_value=True)
@click.pass_context
def cli(ctx, profile_name):
    ctx.obj = {"profile_name": profile_name}
```

### Cobra — pre-run hook + persistent flag

```go
var profileName string

func init() {
    rootCmd.PersistentFlags().StringVar(&profileName, "profile", "", "Use a saved profile")
}

// pkg/config/resolve.go
func Resolve(field string, flagValue, envValue, profileValue, defaultValue string) string {
    if flagValue != "" { return flagValue }
    if envValue != "" { return envValue }
    if profileValue != "" { return profileValue }
    return defaultValue
}

// In each command:
voice := config.Resolve("voice", voiceFlag, os.Getenv("BLOG_CLI_VOICE"),
                        profileLookup(profileName, "voice"), "warm-en")

// cmd/profile.go — save/use/list/show/delete
var profileSaveCmd = &cobra.Command{
    Use: "save NAME",
    RunE: func(cmd *cobra.Command, args []string) error {
        return SaveProfile(args[0], map[string]string{
            "avatar": avatarFlag, "voice": voiceFlag, "webhook": webhookFlag,
        })
    },
}
```

### Commander — program-level hook

```js
import fs from "node:fs";
import path from "node:path";

const PROFILE_PATH = path.join(process.env.HOME, ".blog-cli", "profiles.json");

const loadProfiles = () => fs.existsSync(PROFILE_PATH) ? JSON.parse(fs.readFileSync(PROFILE_PATH, "utf8")) : {};
const saveProfiles = (data) => {
  const tmp = PROFILE_PATH + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
  fs.renameSync(tmp, PROFILE_PATH);
};

export function resolve(field, flagValue, envName, profileName, defaultValue) {
  if (flagValue !== undefined) return flagValue;
  if (process.env[envName] !== undefined) return process.env[envName];
  if (profileName) {
    const p = loadProfiles()[profileName];
    if (p && field in p) return p[field];
  }
  return defaultValue;
}

program.option("--profile <name>", "Use a saved profile");

const profile = program.command("profile").description("Manage saved profiles");
profile.command("save <name>")
  .option("--avatar <name>"); .option("--voice <name>"); .option("--webhook <url>")
  .action((name, { avatar, voice, webhook }) => {
    const profiles = loadProfiles();
    profiles[name] = Object.fromEntries(Object.entries({ avatar, voice, webhook }).filter(([_, v]) => v));
    saveProfiles(profiles);
    process.stdout.write(JSON.stringify({ profile: name, saved: true }) + "\n");
  });
// list / show / delete / use — analogous
```

### oclif — `Config` plugin + persistent flag

```ts
// src/lib/config.ts
import { Config } from "@oclif/core";
import * as fs from "node:fs";
import * as path from "node:path";

export class ProfileStore {
  private static path(config: Config) {
    return path.join(config.dataDir, "profiles.json");
  }
  static load(config: Config): Record<string, Record<string, string>> {
    const p = this.path(config);
    return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, "utf8")) : {};
  }
  static save(config: Config, data: Record<string, any>): void {
    const p = this.path(config);
    fs.writeFileSync(p + ".tmp", JSON.stringify(data, null, 2));
    fs.renameSync(p + ".tmp", p);
  }
  static resolve(config: Config, field: string, flagValue: any, envName: string, profileName?: string, def?: any) {
    if (flagValue !== undefined) return flagValue;
    if (process.env[envName] !== undefined) return process.env[envName];
    if (profileName) {
      const p = this.load(config)[profileName];
      if (p?.[field] !== undefined) return p[field];
    }
    return def;
  }
}

// Every command extends a base that adds the --profile flag:
import { Command, Flags } from "@oclif/core";
export abstract class BaseCommand extends Command {
  static baseFlags = { profile: Flags.string({ summary: "Use a saved profile" }) };
}

// src/commands/profile/save.ts, profile/use.ts, etc. — standard topic pattern
```

> **argparse / clap / yargs** — the storage and resolver logic above transfers verbatim. argparse: declare `--profile` on the top-level parser, resolve in each command. clap: persistent argument on root `Command`. yargs: `.option("profile", { type: "string" })` on the top-level builder. See Click recipe for reference.

---

## Principle 10 — `--deliver` + `feedback`

Two independent surfaces: `--deliver` for outbound artifacts (stdout / file / webhook) and `feedback` for inbound friction reports.

### Click — `--deliver` resolver + `feedback` group

```python
import json, os, urllib.request, click
from pathlib import Path

DELIVER_SCHEMES = ["stdout", "file:<path>", "webhook:<url>"]
FEEDBACK_PATH = Path.home() / ".blog-cli" / "feedback.jsonl"
FEEDBACK_PATH.parent.mkdir(parents=True, exist_ok=True)

def deliver(payload: dict, target: str) -> dict:
    if target == "stdout":
        click.echo(json.dumps(payload))
        return {"delivered_to": "stdout"}
    if target.startswith("file:"):
        path = Path(target[5:])
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_bytes(json.dumps(payload).encode())
        os.replace(tmp, path)
        return {"delivered_to": target, "bytes": path.stat().st_size}
    if target.startswith("webhook:"):
        url = target[8:]
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return {"delivered_to": target, "status": r.status}
    raise click.BadParameter(
        f"--deliver scheme must be one of: {', '.join(DELIVER_SCHEMES)} (got: {target!r})"
    )

# Apply to any command emitting an artifact:
@click.command("create")
@click.option("--script", required=True, type=click.Path(exists=True))
@click.option("--deliver", default="stdout", help=f"One of: {', '.join(DELIVER_SCHEMES)}")
def create(script, deliver):
    artifact = render_video(Path(script).read_text())
    result = deliver_fn(artifact, deliver)
    click.echo(json.dumps(result))

# Feedback group
@click.group("feedback", invoke_without_command=True)
@click.argument("text", required=False)
@click.pass_context
def feedback_group(ctx, text):
    """Record agent-to-maintainer feedback."""
    if ctx.invoked_subcommand: return
    if not text: raise click.UsageError("feedback text required, or use 'feedback list'")
    entry = {"ts": time.time(), "text": text}
    with FEEDBACK_PATH.open("a") as f:
        f.write(json.dumps(entry) + "\n")
    msg = "feedback recorded locally"
    endpoint = os.getenv("BLOG_CLI_FEEDBACK_ENDPOINT")
    if endpoint:
        try:
            urllib.request.urlopen(urllib.request.Request(
                endpoint, data=json.dumps(entry).encode(),
                headers={"Content-Type": "application/json"}), timeout=10)
            msg += " and sent upstream (status: 200)"
        except Exception as e:
            msg += f" (upstream POST failed: {e})"
    click.echo(msg)

@feedback_group.command("list")
def feedback_list():
    if not FEEDBACK_PATH.exists():
        click.echo("(no feedback recorded)"); return
    for line in FEEDBACK_PATH.read_text().splitlines():
        click.echo(line)
```

### Cobra — `--deliver` flag + `feedback` command

```go
var deliverSchemes = []string{"stdout", "file:<path>", "webhook:<url>"}

func deliverArtifact(payload []byte, target string) (map[string]interface{}, error) {
    switch {
    case target == "stdout":
        fmt.Println(string(payload))
        return map[string]interface{}{"delivered_to": "stdout"}, nil
    case strings.HasPrefix(target, "file:"):
        path := target[5:]
        tmp := path + ".tmp"
        if err := os.WriteFile(tmp, payload, 0o644); err != nil { return nil, err }
        if err := os.Rename(tmp, path); err != nil { return nil, err }
        info, _ := os.Stat(path)
        return map[string]interface{}{"delivered_to": target, "bytes": info.Size()}, nil
    case strings.HasPrefix(target, "webhook:"):
        resp, err := http.Post(target[8:], "application/json", bytes.NewReader(payload))
        if err != nil { return nil, err }
        defer resp.Body.Close()
        return map[string]interface{}{"delivered_to": target, "status": resp.StatusCode}, nil
    }
    return nil, fmt.Errorf("--deliver scheme must be one of: %s (got: %q)",
        strings.Join(deliverSchemes, ", "), target)
}

var feedbackCmd = &cobra.Command{
    Use:   "feedback [text]",
    Short: "Record agent-to-maintainer feedback",
    RunE: func(cmd *cobra.Command, args []string) error {
        if len(args) == 0 { return fmt.Errorf("feedback text required") }
        entry := map[string]interface{}{"ts": time.Now().Unix(), "text": args[0]}
        AppendFeedback(entry)
        if endpoint := os.Getenv("BLOG_CLI_FEEDBACK_ENDPOINT"); endpoint != "" {
            // POST entry to endpoint, surface status
        }
        return nil
    },
}
```

### Commander — `--deliver` resolver + `feedback`

```js
import fs from "node:fs";
import path from "node:path";

const DELIVER_SCHEMES = ["stdout", "file:<path>", "webhook:<url>"];

async function deliver(payload, target) {
  if (target === "stdout") {
    process.stdout.write(JSON.stringify(payload) + "\n");
    return { delivered_to: "stdout" };
  }
  if (target.startsWith("file:")) {
    const filePath = target.slice(5);
    const tmp = filePath + ".tmp";
    await fs.promises.writeFile(tmp, JSON.stringify(payload));
    await fs.promises.rename(tmp, filePath);
    const stat = await fs.promises.stat(filePath);
    return { delivered_to: target, bytes: stat.size };
  }
  if (target.startsWith("webhook:")) {
    const r = await fetch(target.slice(8), {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    return { delivered_to: target, status: r.status };
  }
  throw new Error(`--deliver scheme must be one of: ${DELIVER_SCHEMES.join(", ")} (got: "${target}")`);
}

program
  .command("create")
  .requiredOption("--script <file>")
  .option("--deliver <target>", `One of: ${DELIVER_SCHEMES.join(", ")}`, "stdout")
  .action(async ({ script, deliver: target }) => {
    const artifact = await render(fs.readFileSync(script, "utf8"));
    process.stdout.write(JSON.stringify(await deliver(artifact, target)) + "\n");
  });

const FEEDBACK = path.join(process.env.HOME, ".blog-cli", "feedback.jsonl");
fs.mkdirSync(path.dirname(FEEDBACK), { recursive: true });

program
  .command("feedback [text]")
  .description("Record agent-to-maintainer feedback")
  .action(async (text) => {
    if (!text) { console.error("feedback text required"); process.exit(2); }
    const entry = { ts: Date.now(), text };
    fs.appendFileSync(FEEDBACK, JSON.stringify(entry) + "\n");
    let msg = "feedback recorded locally";
    if (process.env.BLOG_CLI_FEEDBACK_ENDPOINT) {
      try {
        const r = await fetch(process.env.BLOG_CLI_FEEDBACK_ENDPOINT, {
          method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(entry),
        });
        msg += ` and sent upstream (status: ${r.status})`;
      } catch (e) { msg += ` (upstream POST failed: ${e.message})`; }
    }
    console.log(msg);
  });
```

### oclif — same patterns

```ts
// src/lib/deliver.ts and src/commands/feedback.ts
// — same shape as Commander; oclif gives you Flags.string({ options: [...] }) for native enum validation,
// which converts the "unknown scheme" check from manual into a built-in Principle 3 enumeration.

import { Flags } from "@oclif/core";
export const deliverFlag = Flags.string({
  default: "stdout",
  description: "stdout | file:<path> | webhook:<url>",
});
```

> **argparse / clap / yargs** — the `deliver()` function and `feedback` storage logic transfer verbatim. argparse: declare `--deliver` with `type=str`, validate manually. clap: `Arg::value_parser(["stdout", "file:.*", "webhook:.*"])`. yargs: `.option("deliver", { type: "string", default: "stdout" })`. See Commander recipe for reference.
