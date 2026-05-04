# CLI Agent-Readiness Test Recipes — pytest & vitest

Drop-in test snippets that turn the ten principles into CI-enforceable assertions. Pick the row matching the principle, paste into the relevant suite, swap in your CLI invocation. All recipes shell out to the built binary — they treat the CLI as a black box, the way an agent does.

**Convention used below:** `BIN = ["blog-cli"]` (string list, ready for `subprocess`/`execa`). For local testing replace with `["uv", "run", "python", "-m", "blog_cli"]`, `["node", "dist/cli.js"]`, `["./target/debug/blog-cli"]`, etc.

**Numbering:** matches [cli-principles.md](./cli-principles.md). Tier 1 (table stakes) is principles 1-5; Tier 2 (compounding) is principles 6-10.

---

## pytest (Python)

```python
# tests/conftest.py
import json
import os
import subprocess
import pytest

BIN = ["blog-cli"]              # adjust to your invocation
DEFAULT_TIMEOUT = 10            # seconds — short enough to fail loud on hang


def run(*args, stdin=subprocess.DEVNULL, timeout=DEFAULT_TIMEOUT, env=None):
    """Run the CLI and return CompletedProcess. Defaults: stdin disconnected, timeout aggressive."""
    return subprocess.run(
        [*BIN, *args],
        stdin=stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
        env={**os.environ, "NO_COLOR": "1", **(env or {})},
    )


@pytest.fixture
def tmp_post(tmp_path):
    p = tmp_path / "post.md"
    p.write_text("# Hello\n")
    return p
```

### Principle 1 — Non-interactive default

```python
def test_publish_does_not_hang_without_stdin(tmp_post):
    """Blocker check — command must exit, not wait for input."""
    result = run("publish", "--content", str(tmp_post), "--force")
    assert result.returncode == 0, result.stderr


def test_publish_fails_actionably_when_force_omitted_in_non_tty(tmp_post):
    """Non-TTY context must refuse instead of prompting."""
    result = run("publish", "--content", str(tmp_post))
    assert result.returncode != 0
    assert "--force" in result.stderr or "non-interactive" in result.stderr.lower()


def test_no_input_flag_is_global(tmp_post):
    result = run("publish", "--content", str(tmp_post), "--force", "--no-input")
    assert result.returncode == 0
```

### Principle 2 — Structured output (single canonical `--json`)

```python
def test_publish_json_is_valid_and_carries_id(tmp_post):
    result = run("publish", "--content", str(tmp_post), "--force", "--json")
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert "post_id" in payload
    assert "url" in payload
    assert payload["status"] == "published"


def test_diagnostics_go_to_stderr_not_stdout(tmp_post):
    result = run("publish", "--content", str(tmp_post), "--force", "--json")
    json.loads(result.stdout)            # stdout must be parseable JSON only
    assert result.stderr == "" or "info:" in result.stderr


def test_no_ansi_in_piped_stdout(tmp_post):
    result = run("posts", "list", "--limit", "5")
    assert "\x1b[" not in result.stdout


def test_only_one_canonical_json_flag():
    """Principle 2 + 6 — no --format=json, --output=json, -o json variants."""
    result = run("--help")
    help_text = result.stdout + result.stderr
    forbidden = ["--format=json", "--format json", "--output=json", "--output json", "-o json"]
    found = [f for f in forbidden if f in help_text]
    assert not found, f"Found forbidden output flags: {found}. Use only --json."
```

### Principle 3 — Errors that teach, and enumerate

```python
def test_missing_required_flag_explains_fix():
    result = run("publish")
    assert result.returncode != 0
    msg = result.stderr.lower()
    assert "--content" in msg                            # names the flag
    assert "usage:" in msg or "example" in msg           # shows shape


def test_enum_failure_enumerates_valid_set(tmp_post):
    """Invalid enum value must list valid options inline."""
    result = run("publish", "--content", str(tmp_post), "--force", "--visibility=secret")
    assert result.returncode != 0
    msg = result.stderr.lower()
    assert "secret" in msg or "got" in msg               # names offending value
    # must enumerate at least two valid alternatives
    valid_values = ["public", "private", "unlisted"]
    matches = [v for v in valid_values if v in msg]
    assert len(matches) >= 2, f"Error must enumerate valid set; only matched {matches} in: {result.stderr}"
```

### Principle 4 — Safe retries

```python
def test_publishing_same_content_twice_is_idempotent(tmp_post):
    first = run("publish", "--content", str(tmp_post), "--force", "--json")
    second = run("publish", "--content", str(tmp_post), "--force", "--json")
    assert first.returncode == 0 and second.returncode == 0
    assert json.loads(first.stdout)["post_id"] == json.loads(second.stdout)["post_id"]
    second_payload = json.loads(second.stdout)
    assert second_payload.get("existing") is True or "already" in second.stdout.lower()


def test_dry_run_does_not_mutate(tmp_post):
    before = run("posts", "list", "--json")
    run("publish", "--content", str(tmp_post), "--force", "--dry-run")
    after = run("posts", "list", "--json")
    assert before.stdout == after.stdout
```

### Principle 5 — Bounded responses

```python
def test_list_respects_limit_and_teaches_narrowing():
    result = run("posts", "list", "--limit", "5", "--json")
    payload = json.loads(result.stdout)
    assert len(payload["items"]) <= 5
    if payload.get("has_more") or payload.get("truncated"):
        # Either an inline hint field OR a stderr/stdout message must exist
        assert ("narrow_hint" in payload or "hint" in payload
                or "narrow" in result.stderr.lower())
```

---

## pytest — Tier 2 (compounding) tests

### Principle 6 — Vocabulary consistency lint

This is a runtime test that walks the CLI's discoverable surface (via `--help` introspection or `agent-context`) and asserts no banned verbs or flag aliases are reachable.

```python
BANNED_VERBS = {"info", "ls", "describe", "add", "rm", "destroy", "edit", "modify"}
BANNED_FLAGS = {
    "--skip-confirmations", "--no-prompt", "--yolo",
    "--format", "--output", "--max-results", "--page-size", "--top",
    "--config-name", "--context",   # see Principle 9 — use --profile
}


def test_no_banned_verbs_in_command_tree():
    """Walks agent-context (or falls back to --help). Fails on any banned verb."""
    result = run("agent-context")
    if result.returncode != 0:
        pytest.skip("agent-context not implemented (Principle 7); cannot lint vocabulary remotely")
    payload = json.loads(result.stdout)
    found = []
    def walk(commands, path=()):
        for name, defn in commands.items():
            if name in BANNED_VERBS:
                found.append("/".join((*path, name)))
            walk(defn.get("subcommands", {}), (*path, name))
    walk(payload["commands"])
    assert not found, f"Banned verbs in CLI surface: {found}. Use canonical: get/list/create/update/delete."


def test_no_banned_flags_in_command_tree():
    result = run("agent-context")
    if result.returncode != 0:
        pytest.skip("agent-context not implemented (Principle 7)")
    payload = json.loads(result.stdout)
    found = []
    def walk(commands, path=()):
        for name, defn in commands.items():
            for flag_name in defn.get("flags", {}):
                # flag_name may be "--format" or "--format=json"; normalize
                base = flag_name.split("=")[0]
                if base in BANNED_FLAGS:
                    found.append(f"{'/'.join((*path, name))}:{flag_name}")
            walk(defn.get("subcommands", {}), (*path, name))
    walk(payload["commands"])
    assert not found, f"Banned flags in CLI surface: {found}. Use --force/--json/--limit/--profile."
```

### Principle 7 — `agent-context` schema validation

```python
def test_agent_context_emits_versioned_json():
    result = run("agent-context")
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert "schema_version" in payload, "agent-context must include schema_version"
    assert isinstance(payload["schema_version"], str), "schema_version must be a string"
    assert "commands" in payload and isinstance(payload["commands"], dict)


def test_agent_context_matches_help_surface():
    """Every command listed in --help must appear in agent-context (no drift)."""
    help_result = run("--help")
    ctx_result = run("agent-context")
    payload = json.loads(ctx_result.stdout)
    ctx_commands = set(payload["commands"].keys())
    # Heuristic: top-level subcommands appear in --help under "Commands:" section
    help_lines = help_result.stdout.splitlines()
    in_commands = False
    help_commands = set()
    for line in help_lines:
        if line.strip().lower().startswith("commands"):
            in_commands = True; continue
        if in_commands and line.strip() and not line.startswith(" "):
            break
        if in_commands and line.strip():
            help_commands.add(line.split()[0])
    drift = help_commands - ctx_commands
    assert not drift, f"Commands in --help missing from agent-context: {drift}"


def test_agent_context_exposes_profile_and_deliver_metadata():
    """Tier 2 cross-references — agent-context surfaces P9 profiles + P10 schemes."""
    payload = json.loads(run("agent-context").stdout)
    assert "available_profiles" in payload, "Principle 9 — profiles must be discoverable"
    assert "deliver_schemes" in payload, "Principle 10 — deliver schemes must be discoverable"
    assert "feedback_endpoint_configured" in payload, "Principle 10 — feedback discoverability"
```

### Principle 8 — `--wait` synchronicity + ledger recovery

```python
def test_wait_returns_completed_status_not_queued(tmp_post):
    """--wait must block until the job finishes."""
    result = run("video", "render", "--script", str(tmp_post), "--wait", "--json", timeout=120)
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["status"] == "complete", f"Expected complete, got {payload}"
    assert "url" in payload or "result" in payload


def test_jobs_list_finds_recent_submissions(tmp_post):
    """Submitting a job (with or without --wait) must persist to the ledger."""
    submit = run("video", "render", "--script", str(tmp_post), "--json")
    job_id = json.loads(submit.stdout)["job_id"]
    listing = run("jobs", "list", "--json")
    entries = json.loads(listing.stdout)
    items = entries if isinstance(entries, list) else entries.get("items", [])
    assert any(e["job_id"] == job_id for e in items), \
        f"Job {job_id} not in ledger; ledger entries: {items}"


def test_wait_retry_recovers_existing_job(tmp_post, monkeypatch):
    """Submit-poll-collect arc — second invocation with same idempotency key
    must find the in-flight job, not duplicate it."""
    # First call submits and starts polling; second call (same content) must reuse
    first = run("video", "render", "--script", str(tmp_post), "--wait", "--json", timeout=120)
    second = run("video", "render", "--script", str(tmp_post), "--wait", "--json", timeout=120)
    assert first.returncode == 0 and second.returncode == 0
    p1, p2 = json.loads(first.stdout), json.loads(second.stdout)
    assert p1["job_id"] == p2["job_id"], "Retry must recover the existing job, not start a new one"
```

### Principle 9 — Profile precedence

```python
def test_profile_value_loaded_when_no_override(tmp_path, monkeypatch):
    """Profile value wins when no flag and no env var present."""
    run("profile", "save", "test", "--voice", "warm-en", "--json")
    result = run("video", "create", "--script", "fixture.txt", "--profile", "test", "--dry-run", "--json")
    payload = json.loads(result.stdout)
    assert payload.get("voice") == "warm-en"


def test_env_var_overrides_profile(monkeypatch):
    """ENV > profile in precedence."""
    run("profile", "save", "test", "--voice", "warm-en", "--json")
    result = run("video", "create", "--script", "fixture.txt", "--profile", "test", "--dry-run", "--json",
                 env={"BLOG_CLI_VOICE": "energetic"})
    assert json.loads(result.stdout).get("voice") == "energetic"


def test_explicit_flag_overrides_env_and_profile(monkeypatch):
    """Explicit flag > ENV > profile > default."""
    run("profile", "save", "test", "--voice", "warm-en", "--json")
    result = run("video", "create", "--script", "fixture.txt", "--profile", "test",
                 "--voice", "calm", "--dry-run", "--json",
                 env={"BLOG_CLI_VOICE": "energetic"})
    assert json.loads(result.stdout).get("voice") == "calm"


def test_profiles_visible_in_agent_context():
    run("profile", "save", "discoverable-profile", "--voice", "warm-en", "--json")
    payload = json.loads(run("agent-context").stdout)
    assert "discoverable-profile" in payload.get("available_profiles", []), \
        "Profile must be discoverable via agent-context (cross-reference Principle 7)"
```

### Principle 10 — `--deliver` routing + `feedback`

```python
def test_deliver_to_file_writes_atomically(tmp_path, tmp_post):
    """File sink must produce a complete file or no file — never partial."""
    out = tmp_path / "result.json"
    result = run("video", "create", "--script", str(tmp_post),
                 "--deliver", f"file:{out}", "--json")
    assert result.returncode == 0, result.stderr
    assert out.exists()
    # Atomic write means the .tmp file should NOT be left behind
    assert not (tmp_path / "result.json.tmp").exists(), "Atomic write leaked a .tmp file"
    payload = json.loads(out.read_text())
    assert payload  # non-empty JSON


def test_deliver_unknown_scheme_returns_structured_refusal(tmp_post):
    """Unknown --deliver scheme must enumerate supported set (Principle 3 cross-ref)."""
    result = run("video", "create", "--script", str(tmp_post),
                 "--deliver", "s3:bucket/key", "--json")
    assert result.returncode != 0
    msg = result.stderr.lower()
    assert "stdout" in msg and "file:" in msg and "webhook:" in msg, \
        f"Refusal must enumerate supported schemes; got: {result.stderr}"


def test_feedback_appends_to_local_jsonl(tmp_path, monkeypatch):
    """feedback <text> must persist to ~/.<cli>/feedback.jsonl."""
    monkeypatch.setenv("HOME", str(tmp_path))
    result = run("feedback", "the --tier flag rejects valid values")
    assert result.returncode == 0
    feedback_path = tmp_path / ".blog-cli" / "feedback.jsonl"
    assert feedback_path.exists()
    last_line = feedback_path.read_text().splitlines()[-1]
    entry = json.loads(last_line)
    assert "the --tier flag rejects valid values" in entry["text"]


def test_feedback_endpoint_discoverable_via_agent_context(monkeypatch):
    """Principle 7 cross-ref — feedback upstream availability is introspectable."""
    monkeypatch.setenv("BLOG_CLI_FEEDBACK_ENDPOINT", "https://maintainers.example.com/cli-feedback")
    payload = json.loads(run("agent-context").stdout)
    assert payload.get("feedback_endpoint_configured") is True
```

---

## vitest (Node / TypeScript)

```ts
// tests/cli.helper.ts
import { execa } from "execa";

const BIN = "blog-cli";              // adjust to your invocation
const DEFAULT_TIMEOUT = 10_000;      // ms

export async function run(
  args: string[],
  opts: { stdin?: "ignore" | string; timeout?: number; env?: NodeJS.ProcessEnv } = {},
) {
  return execa(BIN, args, {
    input: typeof opts.stdin === "string" ? opts.stdin : undefined,
    stdin: typeof opts.stdin === "string" ? "pipe" : (opts.stdin ?? "ignore"),
    timeout: opts.timeout ?? DEFAULT_TIMEOUT,
    reject: false,
    env: { NO_COLOR: "1", FORCE_COLOR: "0", ...opts.env },
  });
}
```

### Principle 1 — Non-interactive default

```ts
import { describe, it, expect } from "vitest";
import { run } from "./cli.helper";
import { writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const post = join(tmpdir(), "post.md");
await writeFile(post, "# Hello\n");

describe("Principle 1 — Non-interactive", () => {
  it("does not hang without stdin", async () => {
    const r = await run(["publish", "--content", post, "--force"]);
    expect(r.exitCode).toBe(0);
  });

  it("refuses with actionable error when --force omitted in non-TTY", async () => {
    const r = await run(["publish", "--content", post]);
    expect(r.exitCode).not.toBe(0);
    expect(r.stderr.toLowerCase()).toMatch(/--force|non-interactive/);
  });
});
```

### Principle 2 — Structured output

```ts
describe("Principle 2 — Structured output", () => {
  it("returns valid JSON with id, url, status", async () => {
    const r = await run(["publish", "--content", post, "--force", "--json"]);
    expect(r.exitCode).toBe(0);
    const payload = JSON.parse(r.stdout);
    expect(payload.post_id).toBeTruthy();
    expect(payload.url).toMatch(/^https?:\/\//);
    expect(payload.status).toBe("published");
  });

  it("keeps diagnostics out of stdout", async () => {
    const r = await run(["publish", "--content", post, "--force", "--json"]);
    expect(() => JSON.parse(r.stdout)).not.toThrow();
  });

  it("emits no ANSI escapes in piped output", async () => {
    const r = await run(["posts", "list", "--limit", "5"]);
    expect(r.stdout).not.toMatch(/\x1b\[/);
  });

  it("uses --json as the only canonical output flag (no --format=json variants)", async () => {
    const r = await run(["--help"]);
    const help = r.stdout + r.stderr;
    const forbidden = ["--format=json", "--format json", "--output=json", "--output json", "-o json"];
    const found = forbidden.filter((f) => help.includes(f));
    expect(found, `Forbidden output flags found: ${found.join(", ")}`).toHaveLength(0);
  });
});
```

### Principle 3 — Errors that teach, and enumerate

```ts
describe("Principle 3 — Errors that teach, and enumerate", () => {
  it("names the missing flag and shows usage", async () => {
    const r = await run(["publish"]);
    expect(r.exitCode).not.toBe(0);
    const msg = r.stderr.toLowerCase();
    expect(msg).toContain("--content");
    expect(msg).toMatch(/usage:|example/);
  });

  it("enumerates the valid set on enum failure", async () => {
    const r = await run(["publish", "--content", post, "--force", "--visibility=secret"]);
    expect(r.exitCode).not.toBe(0);
    const msg = r.stderr.toLowerCase();
    expect(msg, `must include offending value: ${r.stderr}`).toMatch(/secret|got/);
    const valid = ["public", "private", "unlisted"];
    const matched = valid.filter((v) => msg.includes(v));
    expect(matched.length, `must enumerate ≥2 valid values; got ${matched}`).toBeGreaterThanOrEqual(2);
  });
});
```

### Principle 4 — Safe retries

```ts
describe("Principle 4 — Safe retries", () => {
  it("publishing the same content twice is idempotent", async () => {
    const first = await run(["publish", "--content", post, "--force", "--json"]);
    const second = await run(["publish", "--content", post, "--force", "--json"]);
    expect(first.exitCode).toBe(0);
    expect(second.exitCode).toBe(0);
    expect(JSON.parse(first.stdout).post_id).toBe(JSON.parse(second.stdout).post_id);
    const sp = JSON.parse(second.stdout);
    expect(sp.existing === true || /already|no changes/i.test(second.stdout)).toBe(true);
  });

  it("--dry-run does not mutate", async () => {
    const before = await run(["posts", "list", "--json"]);
    await run(["publish", "--content", post, "--force", "--dry-run"]);
    const after = await run(["posts", "list", "--json"]);
    expect(before.stdout).toBe(after.stdout);
  });
});
```

### Principle 5 — Bounded responses

```ts
describe("Principle 5 — Bounded responses", () => {
  it("respects --limit and teaches narrowing on truncation", async () => {
    const r = await run(["posts", "list", "--limit", "5", "--json"]);
    const payload = JSON.parse(r.stdout);
    expect(payload.items.length).toBeLessThanOrEqual(5);
    if (payload.has_more || payload.truncated) {
      expect(
        payload.narrow_hint || payload.hint || r.stderr.toLowerCase().includes("narrow"),
      ).toBeTruthy();
    }
  });
});
```

---

## vitest — Tier 2 (compounding) tests

### Principle 6 — Vocabulary consistency lint

```ts
import { describe, it, expect } from "vitest";
import { run } from "./cli.helper";

const BANNED_VERBS = new Set(["info", "ls", "describe", "add", "rm", "destroy", "edit", "modify"]);
const BANNED_FLAGS = new Set([
  "--skip-confirmations", "--no-prompt", "--yolo",
  "--format", "--output", "--max-results", "--page-size", "--top",
  "--config-name", "--context",
]);

describe("Principle 6 — Vocabulary consistency", () => {
  it("uses no banned verbs in the command tree", async () => {
    const ctx = await run(["agent-context"]);
    if (ctx.exitCode !== 0) return;   // skip — Principle 7 not implemented
    const payload = JSON.parse(ctx.stdout);
    const found: string[] = [];
    const walk = (commands: any, path: string[] = []) => {
      for (const [name, defn] of Object.entries<any>(commands)) {
        if (BANNED_VERBS.has(name)) found.push([...path, name].join("/"));
        if (defn.subcommands) walk(defn.subcommands, [...path, name]);
      }
    };
    walk(payload.commands);
    expect(found, `Banned verbs: ${found.join(", ")}. Use get/list/create/update/delete.`).toHaveLength(0);
  });

  it("uses no banned flags in the command tree", async () => {
    const ctx = await run(["agent-context"]);
    if (ctx.exitCode !== 0) return;
    const payload = JSON.parse(ctx.stdout);
    const found: string[] = [];
    const walk = (commands: any, path: string[] = []) => {
      for (const [name, defn] of Object.entries<any>(commands)) {
        for (const flag of Object.keys(defn.flags ?? {})) {
          const base = flag.split("=")[0];
          if (BANNED_FLAGS.has(base)) found.push(`${[...path, name].join("/")}:${flag}`);
        }
        if (defn.subcommands) walk(defn.subcommands, [...path, name]);
      }
    };
    walk(payload.commands);
    expect(found, `Banned flags: ${found.join(", ")}.`).toHaveLength(0);
  });
});
```

### Principle 7 — `agent-context` schema validation

```ts
describe("Principle 7 — agent-context schema validation", () => {
  it("emits versioned JSON with required top-level fields", async () => {
    const r = await run(["agent-context"]);
    expect(r.exitCode).toBe(0);
    const payload = JSON.parse(r.stdout);
    expect(typeof payload.schema_version).toBe("string");
    expect(payload.commands).toBeTypeOf("object");
  });

  it("agent-context surface matches --help surface (no drift)", async () => {
    const help = (await run(["--help"])).stdout;
    const ctx = JSON.parse((await run(["agent-context"])).stdout);
    const ctxCommands = new Set(Object.keys(ctx.commands));
    // crude help parse — adapt to your framework's --help format
    const helpCommands = new Set(
      help.split("\n")
        .filter((l) => l.startsWith("  ") && !l.includes("--"))
        .map((l) => l.trim().split(/\s+/)[0])
        .filter(Boolean)
    );
    const drift = [...helpCommands].filter((c) => !ctxCommands.has(c));
    expect(drift, `Drift between --help and agent-context: ${drift.join(", ")}`).toHaveLength(0);
  });

  it("exposes Tier 2 cross-references (profiles, deliver schemes, feedback)", async () => {
    const payload = JSON.parse((await run(["agent-context"])).stdout);
    expect(payload.available_profiles).toBeDefined();
    expect(payload.deliver_schemes).toBeDefined();
    expect(payload.feedback_endpoint_configured).toBeDefined();
  });
});
```

### Principle 8 — `--wait` synchronicity + ledger recovery

```ts
describe("Principle 8 — Async-aware execution", () => {
  it("--wait returns complete status, not queued", async () => {
    const r = await run(["video", "render", "--script", post, "--wait", "--json"], { timeout: 120_000 });
    expect(r.exitCode).toBe(0);
    const payload = JSON.parse(r.stdout);
    expect(payload.status).toBe("complete");
  });

  it("submitting a job persists it to the jobs ledger", async () => {
    const submit = await run(["video", "render", "--script", post, "--json"]);
    const jobId = JSON.parse(submit.stdout).job_id;
    const list = await run(["jobs", "list", "--json"]);
    const entries = JSON.parse(list.stdout);
    const items = Array.isArray(entries) ? entries : entries.items;
    expect(items.some((e: any) => e.job_id === jobId)).toBe(true);
  });

  it("retry with same content recovers existing job (no duplicate)", async () => {
    const first = await run(["video", "render", "--script", post, "--wait", "--json"], { timeout: 120_000 });
    const second = await run(["video", "render", "--script", post, "--wait", "--json"], { timeout: 120_000 });
    expect(JSON.parse(first.stdout).job_id).toBe(JSON.parse(second.stdout).job_id);
  });
});
```

### Principle 9 — Profile precedence

```ts
describe("Principle 9 — Profile precedence", () => {
  it("profile value loads when no flag and no env var", async () => {
    await run(["profile", "save", "test", "--voice", "warm-en", "--json"]);
    const r = await run(["video", "create", "--script", "fixture.txt",
                         "--profile", "test", "--dry-run", "--json"]);
    expect(JSON.parse(r.stdout).voice).toBe("warm-en");
  });

  it("env var overrides profile", async () => {
    await run(["profile", "save", "test", "--voice", "warm-en", "--json"]);
    const r = await run(["video", "create", "--script", "fixture.txt",
                         "--profile", "test", "--dry-run", "--json"],
                        { env: { BLOG_CLI_VOICE: "energetic" } });
    expect(JSON.parse(r.stdout).voice).toBe("energetic");
  });

  it("explicit flag overrides env and profile", async () => {
    await run(["profile", "save", "test", "--voice", "warm-en", "--json"]);
    const r = await run(["video", "create", "--script", "fixture.txt",
                         "--profile", "test", "--voice", "calm", "--dry-run", "--json"],
                        { env: { BLOG_CLI_VOICE: "energetic" } });
    expect(JSON.parse(r.stdout).voice).toBe("calm");
  });

  it("saved profile appears in agent-context.available_profiles", async () => {
    await run(["profile", "save", "discoverable-profile", "--voice", "warm-en", "--json"]);
    const ctx = JSON.parse((await run(["agent-context"])).stdout);
    expect(ctx.available_profiles).toContain("discoverable-profile");
  });
});
```

### Principle 10 — `--deliver` routing + `feedback`

```ts
import { existsSync, readFileSync, mkdtempSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

describe("Principle 10 — Two-way I/O", () => {
  it("--deliver=file:<path> writes atomically (no .tmp leak)", async () => {
    const dir = mkdtempSync(join(tmpdir(), "deliver-"));
    const out = join(dir, "result.json");
    const r = await run(["video", "create", "--script", post,
                         "--deliver", `file:${out}`, "--json"]);
    expect(r.exitCode).toBe(0);
    expect(existsSync(out)).toBe(true);
    expect(existsSync(out + ".tmp")).toBe(false);
    expect(() => JSON.parse(readFileSync(out, "utf8"))).not.toThrow();
  });

  it("unknown --deliver scheme returns structured refusal with valid set", async () => {
    const r = await run(["video", "create", "--script", post, "--deliver", "s3:bucket/key", "--json"]);
    expect(r.exitCode).not.toBe(0);
    const msg = r.stderr.toLowerCase();
    expect(msg).toMatch(/stdout/);
    expect(msg).toMatch(/file:/);
    expect(msg).toMatch(/webhook:/);
  });

  it("feedback <text> appends to local JSONL", async () => {
    const home = mkdtempSync(join(tmpdir(), "home-"));
    const r = await run(["feedback", "test entry from CI"], { env: { HOME: home } });
    expect(r.exitCode).toBe(0);
    const fbPath = join(home, ".blog-cli", "feedback.jsonl");
    expect(existsSync(fbPath)).toBe(true);
    const lines = readFileSync(fbPath, "utf8").trim().split("\n");
    const last = JSON.parse(lines[lines.length - 1]);
    expect(last.text).toContain("test entry from CI");
  });

  it("feedback endpoint configuration surfaces in agent-context", async () => {
    const r = await run(["agent-context"], {
      env: { BLOG_CLI_FEEDBACK_ENDPOINT: "https://maintainers.example.com/cli-feedback" },
    });
    expect(JSON.parse(r.stdout).feedback_endpoint_configured).toBe(true);
  });
});
```

---

## CI integration tips

- **Run in matrix mode** if you have multiple binaries (e.g., dev build + release build). The agent-readiness contract should hold for both.
- **Tag with markers** (`pytest -m agent_cli` or vitest `test.concurrent`) so the suite can run in isolation as a contract gate, separate from unit tests.
- **Keep timeouts tight** for Tier 1 (10s default); allow longer (60–120s) for Principle 8 `--wait` tests where remote completion is involved.
- **Strip TTY emulation** (`NO_COLOR=1`, `FORCE_COLOR=0`, `CI=true`) in env so the test mirrors the non-TTY context an agent or CI runner sees.
- **Run after every release build** — a CLI that passed agent-readiness in v1.2 and hangs in v1.3 is a contract break agents will hit before humans do.
- **Vocabulary lint (Principle 6)** is the cheapest test in the suite and catches the highest-leverage drift. Run it on every PR, not just nightly.
- **Tier 2 tests cross-reference each other**: agent-context (P7) is a precondition for the cleanest P6, P9, P10 assertions. If `agent-context` isn't implemented, those tests `skip` (pytest) or early-return (vitest); they don't fail. Implement P7 first to unlock the rest.
