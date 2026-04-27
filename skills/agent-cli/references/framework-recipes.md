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
