---
name: help
description: Lists the TMB slash commands and what they do.
when_to_use: >
  The user types /tmb:help, or asks what the tmb plugin can do, or seems lost about which
  command to use.
argument-hint: <none>
allowed-tools: []
---

# /tmb:help

Print this:

```
Train My Brain (TMB) — commands

/tmb:create
    Full pipeline. Runs the 7-step interview, designs modules, scaffolds a
    local Hugo site, dispatches parallel module-builders, runs the consistency
    reviewer, builds the static output, and starts the server. Scaffolds into
    <cwd>/<topic-slug>/.

/tmb:review
    Re-runs the consistency reviewer against an existing curriculum. Flags
    glossary drift, missing contrast sections, adjacency mismatches, and
    broken reading-list URLs. Use after manual edits or after adding a module.
    Requires curriculum_spine.md and briefs/ at the cwd.

/tmb:add-module
    Adds one module to an existing curriculum. Supports append (after the
    last module) and insert-at-position-K (shifts later modules' weights).
    Dispatches the designer for the new brief, one module-builder, and a
    scoped reviewer over the new module plus adjacency neighbors. Rebuilds
    the site after success.

/tmb:rebuild-site
    Refreshes Hugo layouts, CSS, config, and archetype for an existing
    curriculum without touching content/ or modules/. Rebuilds the static
    output. Use when the plugin's scaffold templates have evolved.

/tmb:help
    Shows this message.

Requirements
  Hugo >= 0.120 (extended). If not installed, /tmb:create offers a platform
  install (brew / winget / snap / apt) before it runs.

More
  CHANGELOG.md for v0.3 release notes
  README.md for quick-start
```

Do not run any tools. This skill is pure text.
