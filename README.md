# Train My Brain

A Claude Code plugin that builds structured, hands-on learning curricula. It interviews you about your goal, researches the topic once up-front, designs a module sequence, dispatches parallel module-builders that share a canonical glossary and reading list, and ships a local Hugo site with exercises, oral validation prompts, and a deterministic consistency reviewer.

**Claude Code CLI only.** TMB shells out to Hugo, `bash`, `curl`, and `yq`; it cannot run inside Claude Work or claude.ai. Every check the reviewer applies is a small script under `scripts/` so the LLM does not silently skip a step.

## Quick Start

1. Install the plugin from the alwaysmap marketplace (`/plugin install tmb@alwaysmap`).
2. From any directory where you want the curriculum to live, type `/tmb:help` to see the commands, or jump straight to `/tmb:create`.

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

- Claude Code CLI (macOS, Linux, or Windows with WSL).
- Hugo ≥ 0.120 (Hugo Extended). If it isn't installed when you run `/tmb:create`, the plugin offers a platform-appropriate install command (`brew`, `winget`, `snap`).
- `yq` and `curl` on PATH (the determinism scripts call them).

## About

Built by [Dylan Thomas](https://bitsby.me) · Part of the [alwaysmap](https://github.com/alwaysmap) toolkit

See `CHANGELOG.md` for version notes; `RELEASING.md` for how the plugin itself is released.
