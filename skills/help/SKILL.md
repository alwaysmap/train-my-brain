---
name: help
description: >
  Use this skill when the user types /tmb:help, asks "what can the tmb plugin
  do", "show TMB commands", or seems unsure which command to use. Pure-text
  output of every TMB slash command and what it does.
user_summary: >
  Show every TMB command and what it does — a one-screen summary.
version: 0.4.0
argument-hint: ""
allowed-tools: []
---

# /tmb:help

Print this verbatim:

```
Train My Brain (TMB) — commands

/tmb:create
    Full pipeline. Runs the 8-step interview, dispatches a one-shot topic
    researcher (writes research.yaml — canonical glossary, sourced reading
    list, concept map, contrasts, authorities), designs modules, scaffolds
    a local Hugo site, dispatches parallel module-builders (each reads
    research.yaml so all modules share definitions and URLs), runs the
    consistency reviewer (deterministic scripts + substantive flags), builds
    the static output, and starts the server. Scaffolds into <cwd>/<topic-slug>/.

/tmb:review
    Re-runs the consistency reviewer against an existing curriculum. The
    reviewer is a thin orchestrator over scripts/ — adjacency, frontmatter,
    URL reachability, glossary merge, AI-prose regex. Substantive flags
    land in review.md for your approval. Use after manual edits or after
    adding a module.

/tmb:add-module
    Adds one module to an existing curriculum. Supports append (after the
    last module) and insert-at-position-K (shifts later modules' weights).
    Re-uses the existing research.yaml. Dispatches the designer for the
    new brief, one module-builder, and a scoped reviewer over the new
    module plus adjacency neighbors. Rebuilds the site after success.

/tmb:rebuild-site
    Refreshes Hugo layouts, CSS, config, and archetype for an existing
    curriculum without touching content/ or modules/. Rebuilds the static
    output. Use when the plugin's scaffold templates have evolved.

/tmb:publish
    Publishes the current curriculum to GitHub Pages via the `gh` CLI.
    Interactive walkthrough — confirms the repo name, creates it, enables
    Pages, watches the first deploy, and prints the live URL. Requires
    `gh` installed and authenticated.

/tmb:help
    Shows this message.

Requirements
  Claude Code CLI (macOS / Linux / Windows-WSL).
  hugo (extended) >= 0.120, yq, jq, curl — used by the determinism scripts.

  Run the preflight any time:
      bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
  On macOS+brew it offers `brew install <missing>` interactively. On Linux
  it prints copy-paste install commands (no auto-sudo). Every TMB command
  runs this same preflight as Phase 0, so you can also just run /tmb:create
  and let it tell you what's missing.

Publishing online (GitHub Pages)
  cd into the curriculum folder, then:
      /tmb:publish
  Walks you through gh auth, repo creation, Pages enablement, and
  watching the first deploy. Requires `gh` installed and authenticated.
  Full reference (manual flow, custom domains, troubleshooting):
      references/github-pages.md

More
  CHANGELOG.md for v0.4 release notes
  README.md for the full per-platform install matrix
```

Do not run any tools. This skill is pure text.
