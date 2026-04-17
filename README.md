# Train My Brain

A Claude Code plugin that builds structured, hands-on learning curricula. It interviews you about your goal, designs a curriculum, and creates a local folder containing real exercises, oral validation prompts, and a Hugo website you can view in your browser.

**Not theoretical.** Every module produces working exercises and tested understanding. Hugo content is the single source of truth — no duplicated READMEs, no sync scripts.

## Quick Start

1. Install the plugin in Claude Code (your plugin manager's usual flow).
2. In any directory where you want the curriculum to live, type `/tmb:help` to see the commands, or jump straight to `/tmb:create`.

## Commands

| Command | What it does |
|---|---|
| `/tmb:create` | Full pipeline: 7-step interview → design phase → Hugo scaffold → parallel module builders → consistency reviewer → build → serve. Scaffolds into `<cwd>/<slug>/`. |
| `/tmb:review` | Re-runs the consistency reviewer against an existing curriculum. Flags glossary drift, missing contrast sections, adjacency mismatches, and broken reading-list URLs. |
| `/tmb:add-module` | Adds one module to an existing curriculum. Supports append and insert-at-position-K (shifts later modules' weights mechanically). |
| `/tmb:rebuild-site` | Refreshes Hugo layouts / CSS / config without touching `content/` or `modules/`, then rebuilds `site/public/`. Useful when the plugin's scaffold templates evolve. |
| `/tmb:help` | Lists the commands and their purpose. |

## What `/tmb:create` produces

A folder at `<cwd>/<topic-slug>/` containing:

- `site/` — the Hugo site (layouts, CSS, hugo.yaml, content). Start it with `./serve.sh`.
- `modules/NN-slug/` — one directory per module, each holding `exercises/` and `VALIDATION.md`. Concept prose lives on the Hugo site, not here.
- `briefs/NN-slug.yaml` — the per-module brief the design phase produced. Ground truth for adjacency fields.
- `curriculum_spine.md` — running-example state, audience, goals, glossary seed.
- `glossary.md` — merged from each module's `new_terms.yaml` side-file.
- `review.md` — the reviewer's findings; substantive flags wait for your approval.
- `serve.sh` / `build.sh` / `stop.sh` (and PowerShell counterparts) — one command each, no arguments required.

## Requirements

- Claude Code (macOS, Linux, or Windows)
- Hugo ≥ 0.120 (Hugo Extended). If it isn't installed when you run `/tmb:create`, the plugin offers a platform-appropriate install command (`brew`, `winget`, `snap`).

## About

Built by [Dylan Thomas](https://bitsby.me) · Part of the [alwaysmap](https://github.com/alwaysmap) toolkit

See `CHANGELOG.md` for version notes; `RELEASING.md` for how the plugin itself is released.
