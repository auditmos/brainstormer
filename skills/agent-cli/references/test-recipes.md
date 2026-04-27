# CLI Agent-Readiness Test Recipes — pytest & vitest

Drop-in test snippets that turn the seven principles into CI-enforceable assertions. Pick the row matching the principle, paste into the relevant suite, swap in your CLI invocation. All recipes shell out to the built binary — they treat the CLI as a black box, the way an agent does.

**Convention used below:** `BIN = ["blog-cli"]` (string list, ready for `subprocess`/`execa`). For local testing replace with `["uv", "run", "python", "-m", "blog_cli"]`, `["node", "dist/cli.js"]`, `["./target/debug/blog-cli"]`, etc.

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
    """Run the CLI and return (returncode, stdout, stderr).

    Defaults: stdin disconnected, timeout aggressive. Raises on hang so the
    test fails loud instead of silently waiting.
    """
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
    result = run("publish", "--content", str(tmp_post), "--yes")
    assert result.returncode == 0, result.stderr


def test_publish_fails_actionably_when_yes_omitted_in_non_tty(tmp_post):
    """Non-TTY context must refuse instead of prompting."""
    result = run("publish", "--content", str(tmp_post))
    assert result.returncode != 0
    assert "--yes" in result.stderr or "non-interactive" in result.stderr.lower()


def test_no_input_flag_is_global(tmp_post):
    result = run("publish", "--content", str(tmp_post), "--yes", "--no-input")
    assert result.returncode == 0
```

### Principle 2 — Structured output

```python
def test_publish_json_is_valid_and_carries_id(tmp_post):
    result = run("publish", "--content", str(tmp_post), "--yes", "--json")
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert "post_id" in payload
    assert "url" in payload
    assert payload["status"] == "published"


def test_diagnostics_go_to_stderr_not_stdout(tmp_post):
    result = run("publish", "--content", str(tmp_post), "--yes", "--json")
    json.loads(result.stdout)            # stdout must be parseable JSON only
    assert result.stderr == "" or "info:" in result.stderr   # diagnostics, not data


def test_no_ansi_in_piped_stdout(tmp_post):
    """Subprocess pipes stdout — there must be no escape sequences."""
    result = run("posts", "list", "--limit", "5")
    assert "\x1b[" not in result.stdout
```

### Principle 3 — Actionable errors

```python
def test_missing_required_flag_explains_fix():
    result = run("publish")
    assert result.returncode != 0
    msg = result.stderr.lower()
    assert "--content" in msg              # names the flag
    assert "usage:" in msg or "example" in msg   # shows shape
```

### Principle 4 — Safe retries

```python
def test_publishing_same_content_twice_is_idempotent(tmp_post):
    first = run("publish", "--content", str(tmp_post), "--yes", "--json")
    second = run("publish", "--content", str(tmp_post), "--yes", "--json")
    assert first.returncode == 0 and second.returncode == 0
    assert json.loads(first.stdout)["post_id"] == json.loads(second.stdout)["post_id"]
    assert "no changes" in second.stdout.lower() or "already" in second.stdout.lower()


def test_dry_run_does_not_mutate(tmp_post):
    before = run("posts", "list", "--json")
    run("publish", "--content", str(tmp_post), "--yes", "--dry-run")
    after = run("posts", "list", "--json")
    assert before.stdout == after.stdout
```

### Principle 5 — Help discovery

```python
@pytest.mark.parametrize("path", [(), ("publish",), ("posts", "list")])
def test_help_lists_examples(path):
    result = run(*path, "--help")
    assert result.returncode == 0
    assert "Usage:" in result.stdout or "usage:" in result.stdout
    assert "Example" in result.stdout or "example" in result.stdout
```

### Principle 7 — Bounded responses

```python
def test_list_respects_limit_and_teaches_narrowing():
    result = run("posts", "list", "--limit", "5", "--json")
    payload = json.loads(result.stdout)
    assert len(payload["items"]) <= 5
    if payload.get("has_more"):
        # Either an inline hint field OR a stderr/stdout message must exist
        assert "narrow_hint" in payload or "narrow" in result.stderr.lower()
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
    reject: false,                    // never throw; tests inspect exitCode
    env: { NO_COLOR: "1", FORCE_COLOR: "0", ...opts.env },
  });
}
```

`execa` with `stdin: "ignore"` replicates `subprocess.DEVNULL`. The `reject: false` flag prevents non-zero exits from throwing — assertions inspect `exitCode` directly the way an agent would.

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
    const r = await run(["publish", "--content", post, "--yes"]);
    expect(r.exitCode).toBe(0);
  });

  it("refuses with actionable error when --yes omitted in non-TTY", async () => {
    const r = await run(["publish", "--content", post]);
    expect(r.exitCode).not.toBe(0);
    expect(r.stderr.toLowerCase()).toMatch(/--yes|non-interactive/);
  });
});
```

### Principle 2 — Structured output

```ts
describe("Principle 2 — Structured output", () => {
  it("returns valid JSON with id, url, status", async () => {
    const r = await run(["publish", "--content", post, "--yes", "--json"]);
    expect(r.exitCode).toBe(0);
    const payload = JSON.parse(r.stdout);
    expect(payload.post_id).toBeTruthy();
    expect(payload.url).toMatch(/^https?:\/\//);
    expect(payload.status).toBe("published");
  });

  it("keeps diagnostics out of stdout", async () => {
    const r = await run(["publish", "--content", post, "--yes", "--json"]);
    expect(() => JSON.parse(r.stdout)).not.toThrow();
  });

  it("emits no ANSI escapes in piped output", async () => {
    const r = await run(["posts", "list", "--limit", "5"]);
    expect(r.stdout).not.toMatch(/\x1b\[/);
  });
});
```

### Principle 3 — Actionable errors

```ts
describe("Principle 3 — Actionable errors", () => {
  it("names the missing flag and shows usage", async () => {
    const r = await run(["publish"]);
    expect(r.exitCode).not.toBe(0);
    const msg = r.stderr.toLowerCase();
    expect(msg).toContain("--content");
    expect(msg).toMatch(/usage:|example/);
  });
});
```

### Principle 4 — Safe retries

```ts
describe("Principle 4 — Safe retries", () => {
  it("publishing the same content twice is idempotent", async () => {
    const first = await run(["publish", "--content", post, "--yes", "--json"]);
    const second = await run(["publish", "--content", post, "--yes", "--json"]);
    expect(first.exitCode).toBe(0);
    expect(second.exitCode).toBe(0);
    expect(JSON.parse(first.stdout).post_id).toBe(JSON.parse(second.stdout).post_id);
    expect(second.stdout.toLowerCase()).toMatch(/already|no changes/);
  });

  it("--dry-run does not mutate", async () => {
    const before = await run(["posts", "list", "--json"]);
    await run(["publish", "--content", post, "--yes", "--dry-run"]);
    const after = await run(["posts", "list", "--json"]);
    expect(before.stdout).toBe(after.stdout);
  });
});
```

### Principle 5 — Help discovery

```ts
describe.each([[], ["publish"], ["posts", "list"]])(
  "Principle 5 — Help discovery for %j",
  (...path) => {
    it("includes usage and at least one example", async () => {
      const r = await run([...path, "--help"]);
      expect(r.exitCode).toBe(0);
      expect(r.stdout.toLowerCase()).toMatch(/usage:/);
      expect(r.stdout.toLowerCase()).toMatch(/example/);
    });
  },
);
```

### Principle 7 — Bounded responses

```ts
describe("Principle 7 — Bounded responses", () => {
  it("respects --limit and teaches narrowing on truncation", async () => {
    const r = await run(["posts", "list", "--limit", "5", "--json"]);
    const payload = JSON.parse(r.stdout);
    expect(payload.items.length).toBeLessThanOrEqual(5);
    if (payload.has_more) {
      expect(
        payload.narrow_hint || r.stderr.toLowerCase().includes("narrow"),
      ).toBeTruthy();
    }
  });
});
```

---

## CI integration tips

- **Run in matrix mode** if you have multiple binaries (e.g., dev build + release build). The agent-readiness contract should hold for both.
- **Tag with markers** (`pytest -m agent_cli` or vitest `test.concurrent`) so the suite can run in isolation as a contract gate, separate from unit tests.
- **Keep timeouts tight** (10s default). A regression that turns a clean exit into a hang must fail in seconds, not minutes — the whole point of these tests is to catch hangs that humans would never notice locally.
- **Strip TTY emulation** (`NO_COLOR=1`, `FORCE_COLOR=0`, `CI=true`) in env so the test mirrors the non-TTY context an agent or CI runner sees.
- **Run after every release build** — a CLI that passed agent-readiness in v1.2 and hangs in v1.3 is a contract break agents will hit before humans do.
