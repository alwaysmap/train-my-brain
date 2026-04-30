# Train My Brain

A Claude Code plugin that builds structured, hands-on learning curricula. It interviews you about your goal, researches the topic once up-front, designs a module sequence, dispatches parallel module-builders that share a canonical glossary and reading list, and ships a local Hugo site with exercises, oral validation prompts, and a deterministic consistency reviewer.

**Claude Code CLI only.** TMB shells out to Hugo, `bash`, `curl`, and `yq`; it cannot run inside Claude Work or claude.ai. Every check the reviewer applies is a small script under `scripts/` so the LLM does not silently skip a step.

## Quick Start

### 1. Install the plugin

TMB ships through the `alwaysmap` marketplace. From your terminal:

```sh
claude plugin marketplace add alwaysmap/alwaysmap-marketplace
claude plugin marketplace update
claude plugin install tmb@alwaysmap
```

Verify it landed:

```sh
claude plugin list
```

You should see `tmb` listed. The plugin is now available to every Claude Code session — start a new session (or run `/plugin reload` in an existing one) and the `/tmb:*` commands will be live.

**Already have the marketplace added** (e.g., from installing `jfm`)? Skip to `claude plugin install tmb@alwaysmap`.

**Updating later**: `claude plugin marketplace update && claude plugin install tmb@alwaysmap` pulls the latest tagged release. The marketplace.json in `alwaysmap/alwaysmap-marketplace` is auto-bumped by the release workflow whenever this repo tags a `v*`.

### 2. Install runtime dependencies

TMB shells out to four CLIs at runtime: `hugo` (extended), `yq`, `jq`, and `curl`. Run the preflight any time to check what's already installed and get an interactive install offer for what's missing:

```sh
# Inside the installed plugin directory, or from a curriculum folder:
bash $(claude plugin path tmb@alwaysmap)/scripts/check-deps.sh
```

Or just run `/tmb:create` — it calls `check-deps.sh` as Phase 0 and offers install before the interview starts.

On macOS with Homebrew this offers `brew install <missing>` interactively. On Linux it prints copy-paste commands (snap / apt / direct download — we don't auto-elevate `sudo`). See [Requirements](#requirements) below for the full per-platform install matrix.

### 3. Build your first curriculum

From any directory where you want a curriculum to live:

```
/tmb:help       # see every command
/tmb:create     # build a curriculum
```

`/tmb:create` walks you through a 7-question interview, then runs autonomously for ~6–10 minutes (research → design → scaffold → parallel module-builders → reviewer → build → serve). At the end you get a working Hugo site at `http://localhost:1313`.

Want to publish it online? See [Publishing online (GitHub Pages)](#publishing-online-github-pages).

## Commands

| Command | What it does |
|---|---|
| `/tmb:create` | Full pipeline: 7-step interview → topic research (`research.yaml`) → design phase → Hugo scaffold → parallel module builders → consistency reviewer → build → serve. Scaffolds into `<cwd>/<slug>/`. |
| `/tmb:review` | Re-runs the consistency reviewer against an existing curriculum. Calls deterministic scripts for adjacency, frontmatter, URL reachability, AI-prose regex, and glossary merge. |
| `/tmb:add-module` | Adds one module to an existing curriculum. Supports append and insert-at-position-K (shifts later modules' weights mechanically). |
| `/tmb:rebuild-site` | Refreshes Hugo layouts / CSS / config without touching `content/` or `modules/`, then rebuilds `site/public/`. |
| `/tmb:help` | Lists the commands and their purpose. |

## What `/tmb:create` produces

A folder at `<cwd>/<topic-slug>/` containing:

- `research.yaml` — canonical glossary, sourced reading list, concept map, common contrasts, authority list. Read by every module-builder so they all use the same definitions and URLs.
- `site/` — the Hugo site (layouts, CSS, hugo.yaml, content). Start it with `./serve.sh`.
- `modules/NN-slug/` — one directory per module, each holding `exercises/` and `VALIDATION.md`. Concept prose lives on the Hugo site, not here.
- `briefs/NN-slug.yaml` — the per-module brief the design phase produced. Ground truth for adjacency fields.
- `curriculum_spine.md` — running-example state, audience, goals, glossary seed.
- `glossary.md` — merged from `research.yaml` plus each module's `new_terms.yaml` side-file (deterministic merge via `scripts/merge-glossary.sh`).
- `review.md` — the reviewer's findings; substantive flags wait for your approval.
- `serve.sh` / `build.sh` / `stop.sh` (and PowerShell counterparts) — one command each, no arguments required.

## Determinism

Every check that can be expressed as a script is a script. The reviewer agent is a thin orchestrator that calls:

- `scripts/validate-briefs.sh` — gate on briefs/*.yaml (no nulls, concept count, URL format, adjacency, TODO markers).
- `scripts/check-urls.sh` — `curl -I` against every reading-list URL.
- `scripts/check-adjacency.sh` — every `next_expects` ↔ `prior_ends_with` pair.
- `scripts/check-frontmatter.sh` — index.md frontmatter matches its brief.
- `scripts/check-ai-prose.sh` — regex pass for opener clichés, fake enthusiasm, consulting-speak.
- `scripts/merge-glossary.sh` — merges identical-definition terms; surfaces conflicts.
- `scripts/detect-curriculum.sh` — JSON status (fresh / partial / non-tmb / v0.2) for resume detection.

If you don't trust an LLM to never skip a step, run any of these directly against a curriculum directory.

## Requirements

| Tool | Why TMB needs it | macOS (Homebrew) | Linux (snap) | Linux (apt) |
|---|---|---|---|---|
| **Claude Code CLI** | The plugin host. | `brew install --cask claude` | n/a — download from claude.ai | n/a |
| **Hugo (extended) ≥ 0.120** | Site generation, archetypes, layouts. | `brew install hugo` | `sudo snap install hugo --classic` | apt's package is often stale — prefer the [upstream `.deb`](https://github.com/gohugoio/hugo/releases) |
| **yq** (Mike Farah, Go-based) | Reads/patches nested YAML in briefs, frontmatter, and `research.yaml`. | `brew install yq` | `sudo snap install yq` | Download single binary from [`mikefarah/yq`](https://github.com/mikefarah/yq#install) |
| **jq** | JSON munging in the determinism scripts. | `brew install jq` | `sudo apt-get install -y jq` | `sudo apt-get install -y jq` |
| **curl** | URL reachability checks. | preinstalled | preinstalled | preinstalled |

### One-shot install

```sh
# macOS
brew install hugo yq jq

# Debian/Ubuntu (snap available)
sudo snap install hugo --classic && sudo snap install yq && sudo apt-get install -y jq

# Anywhere — let TMB tell you what's missing and how to install it
bash scripts/check-deps.sh
```

`check-deps.sh` is also Phase 0 of `/tmb:create`, `/tmb:review`, `/tmb:add-module`, and `/tmb:rebuild-site` — every entry point validates the runtime before doing anything else. On macOS it offers an interactive `brew install` for whatever is missing. On Linux it prints copy-paste commands (we do not auto-elevate `sudo`).

### Platform support

- **macOS** — first-class. Homebrew is the assumed package manager.
- **Linux** — first-class. snap or apt+upstream binaries.
- **Windows** — supported via WSL (use the Linux instructions inside your WSL distro). Native Windows is untested; PowerShell counterparts ship for `serve.ps1` / `build.ps1` / `stop.ps1` but the determinism scripts assume bash.

## Publishing online (GitHub Pages)

Every TMB curriculum scaffolds with a working `.github/workflows/deploy.yml`. Push the curriculum folder to a GitHub repo, enable Pages once, and every subsequent push to `main` rebuilds and redeploys automatically.

Quick version (with the `gh` CLI installed):

```sh
cd <curriculum-slug>
git init && git add . && git commit -m "Initial curriculum"
gh repo create <your-username>/<curriculum-slug> --public --source=. --push
# then in repo Settings → Pages → Source = "GitHub Actions"
```

Full step-by-step including the manual non-`gh` path, custom domains, and troubleshooting: see [`references/github-pages.md`](references/github-pages.md).

## About

Built by [Dylan Thomas](https://bitsby.me) · Part of the [alwaysmap](https://github.com/alwaysmap) toolkit

See `CHANGELOG.md` for version notes; `RELEASING.md` for how the plugin itself is released.
