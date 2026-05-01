---
name: rebuild-site
description: >
  Use this skill when the user asks to refresh the Hugo layouts of an existing
  curriculum or rebuild the static site after a plugin upgrade. Triggers on
  "/tmb:rebuild-site", "refresh the site layouts", "rebuild the Hugo scaffold",
  "upgrade the site templates". Touches only site/layouts/, site/assets/css/,
  site/archetypes/, and site/hugo.yaml — never site/content/ or modules/.
user_summary: >
  Refresh the Hugo layouts and rebuild the static site. Use after the plugin's
  scaffold templates have evolved. Your content is untouched.
version: 0.4.0
argument-hint: "<no arguments — operates on cwd>"
allowed-tools: [Read, Write, Bash]
---

# /tmb:rebuild-site

Refresh Hugo infrastructure in an existing curriculum without rewriting content, then rebuild.

## Files

| File | Loaded when |
|------|-------------|
| `SKILL.md` (this file) | Always |
| `references/hugo-site.md` | When the user asks why a layout changed or how the scaffold works |

## Phase 0: Preflight

```bash
bash scripts/check-deps.sh
bash scripts/detect-curriculum.sh "$(pwd)"
```

Branch on `state`:

- `v0.4-complete` or `v0.4-partial` — proceed.
- `v0.3-*` — refuse: *"v0.3 layouts diverge from v0.4. There's no automatic upgrade — see CHANGELOG.md."*
- `v0.2` — refuse with the v0.2 message.
- Anything else — refuse: *"This directory does not look like a TMB curriculum (state: <X>)."*

If `site/` is missing entirely, refuse: *"No site/ directory found. If you want to scaffold one, run /tmb:create."* Do not try to scaffold a site against existing content — the content wasn't written against this layout.

## Phase 1: Refresh layouts

```bash
bash scripts/scaffold-site.sh --target "$(pwd)" --layouts-only
```

This rewrites layouts, CSS, archetype, and the structural keys of `hugo.yaml` (preserving `title`, `description`, `author`, `hue`). It does NOT touch:

- `site/content/` (module pages — owned by the builders)
- `modules/` (exercises, VALIDATION)
- `briefs/`, `curriculum_spine.md`, `research.yaml`, `glossary.md`, `review.md`
- `serve.sh`, `build.sh`, `stop.sh` (these get their own upgrade path; not handled here to avoid clobbering user edits)

## Phase 2: Build

```bash
cd "$(pwd)" && ./build.sh
```

## Phase 3: Deliver

```
Layouts refreshed. Site rebuilt.

site/public/ is current against the v0.4 plugin templates.

If a server is running, restart it to pick up layout changes:
  ./stop.sh && ./serve.sh
```

If no server is running, offer to start one (same tmux-or-fallback flow as `/tmb:create`).

## Boundaries

- No interview, designer, builders, or reviewer.
- No web research.
- Only Hugo infrastructure + build. Content is untouched.
