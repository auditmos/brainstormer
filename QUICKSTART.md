# Brainstormer Quickstart

From a rough idea to a running software project, using six skills in order:
`/ask` → `/blueprint` → `/carve` → `/dispatch` → `/tdd` → `/ship`.

This page is written for two readers: you, and your Claude. The fastest route is to do
Step 1 yourself (two minutes of clicking), then hand the rest to Claude.

## Step 1 — Install the skills (you, once)

You need the Claude Desktop app with the **Code** tab, and `git` on your machine
(macOS: installed with the Xcode Command Line Tools; Windows: install
[Git for Windows](https://git-scm.com/download/win)). No GitHub account is needed yet.

1. Open the **Code** tab and pick any folder — an empty one named after your idea is fine.
2. Click **+** next to the prompt box → **Plugins** → **Add plugin**.
3. Add the marketplace `auditmos/brainstormer` (GitHub repo
   `https://github.com/auditmos/brainstormer`).
4. Install these six plugins: `ask`, `blueprint`, `carve`, `dispatch`, `tdd`, `ship`.
5. Start a **new session** so the skills load.

Using the terminal instead of the app:

```bash
claude plugin marketplace add auditmos/brainstormer
for p in ask blueprint carve dispatch tdd ship; do claude plugin install "$p@brainstormer"; done
```

## Step 2 — Hand over to Claude

Paste this into the new session:

> Read https://raw.githubusercontent.com/auditmos/brainstormer/main/QUICKSTART.md and
> follow the "Instructions for Claude" section. Start with /ask — I have an idea for a
> software project.

That is all you need to do by hand. Everything below is for Claude.

---

## Instructions for Claude

You are onboarding a first-time user of the Brainstormer skills. Speak the user's
language. Assume they have **no GitHub account and no `gh` CLI** — do not ask for either
until Stage B. Skills are invoked as `/ask:ask`, `/blueprint:blueprint`, and so on; typing
`/ask` in the prompt box finds them. If a skill is missing, send the user back to Step 1.

### Stage A — Discovery (no prerequisites)

1. Run the `ask` skill. Follow it exactly: one question at a time.
2. When the interview ends, save its closing summary (decisions, open questions, signed-off
   assumptions) to `discovery.md` in the current folder. The next stages run in a different
   folder and a fresh session, so this file is the handoff.

### Stage B — Pick a template and create the project

The project is software, so start it from one of the Auditmos templates rather than from
an empty folder. Recommend **one**, based on what discovery established, and let the user
confirm:

| Template | Choose it when the project is |
|---|---|
| [`astro-on-cf`](https://github.com/auditmos/astro-on-cf) | A content-first site — marketing pages, blog, docs — with an optional database |
| [`hono-on-cf`](https://github.com/auditmos/hono-on-cf) | An API or backend only, with no user interface of its own |
| [`tstack-on-cf`](https://github.com/auditmos/tstack-on-cf) | One full-stack web app: interface, API and database together |
| [`saas-on-cf`](https://github.com/auditmos/saas-on-cf) | A SaaS product with user accounts, built as a frontend plus a separate API service |

When two fit, prefer the smaller one. All four deploy to Cloudflare Workers.

GitHub becomes necessary here: the PRD and the work items are GitHub issues, and `/ship`
pushes to a GitHub repository. Set it up for the user, in this order:

1. Ask the user to create a free account at <https://github.com/signup> and tell you when
   it is done. This is the only part they must do themselves.
2. Install the GitHub CLI: `brew install gh` on macOS, `winget install --id GitHub.cli`
   on Windows.
3. Run `gh auth login --web --git-protocol https` and guide the user through the browser
   prompt. Confirm with `gh auth status`.
4. Create the project **from the template** — do not clone the template itself:

   ```bash
   gh repo create <project-name> --template auditmos/<template> --private --clone
   ```

5. Move `discovery.md` to `<project-name>/plans/discovery.md`.
6. Follow the "Using this Template" section of the new repository's `README.md`
   (Node and pnpm, `pnpm install`, and `pnpm run init-project` where the template has it).
   Install Node or pnpm if they are missing. Leave database and Cloudflare credentials for
   the moment the first issue needs them.
7. Tell the user to start a **new Code session in the `<project-name>` folder**. Every
   later stage runs there.

### Stage C — Plan and build (inside the project folder)

Run one skill at a time and stop for the user's approval between them.

| Order | Skill | Input | Output |
|---|---|---|---|
| 1 | `/blueprint` | `plans/discovery.md` | PRD, filed as a GitHub issue |
| 2 | `/carve` | The PRD issue | Phased plan in `./plans/` |
| 3 | `/dispatch` | The PRD issue | Dependency-ordered GitHub issues |
| 4 | `/tdd #<issue>` | One issue at a time, blockers first | Tested code |
| 5 | `/ship` | The finished change | Lint, type-check, commit, push |

Repeat rows 4 and 5 for each issue. Read the template's `AGENTS.md` or `CLAUDE.md` before
the first `/tdd` run — it defines the project's commands and conventions.
