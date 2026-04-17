---
name: rebuild-site
description: Refreshes Hugo layouts, CSS, config, and archetype for an existing TMB curriculum without touching content/ or modules/, then rebuilds the static site. Use when the plugin's scaffold templates have evolved and you want an existing curriculum to pick them up.
when_to_use: >
  The user asks to refresh the Hugo scaffold of an existing curriculum, apply updated plugin
  layouts, or rebuild the site after plugin upgrade. Trigger phrases: "/tmb:rebuild-site",
  "refresh the site layouts", "rebuild the Hugo scaffold", "upgrade the site templates".
argument-hint: <no arguments — operates on cwd>
allowed-tools: [Read, Write, Bash]
---

# /tmb:rebuild-site

Refresh Hugo infrastructure in an existing curriculum without rewriting content, then rebuild.

## Phase 0: Hugo check

```bash
bash scripts/check-hugo.sh
```

Stop on non-zero.

## Phase 1: Preconditions

Verify cwd is a v0.3 curriculum:

```bash
[ -d site ] && [ -f curriculum_spine.md ]
```

**v0.2 refusal.** If the cwd has `modules/*/README.md` files, this is a v0.2 curriculum. Refuse:

```bash
if ls modules/*/README.md >/dev/null 2>&1; then
  # v0.2 shape detected
  ...
fi
```

Print:

```
/tmb:rebuild-site: this looks like a v0.2 curriculum (modules/NN-slug/README.md exists).

v0.3 has no automatic migration — per-module READMEs are replaced by Hugo content at
site/content/modules/NN-slug/index.md, and the top-level README becomes a short index.
See CHANGELOG.md v0.3 notes for manual migration steps, or stay on v0.2 for this
curriculum.
```

If `site/` is missing entirely, print: `"No site/ directory found. If you want to scaffold one, run /tmb:create (fresh curriculum) or restore from git."` Do not try to scaffold a site against existing content — the content wasn't written against this layout.

## Phase 2: Refresh layouts

```bash
bash scripts/scaffold-site.sh --target "<cwd>" --layouts-only
```

This rewrites:

- `site/archetypes/modules.md`
- `site/assets/css/site.css`
- `site/layouts/baseof.html`
- `site/layouts/_default/page.html`
- `site/layouts/_default/section.html`
- `site/layouts/index.html`
- `site/layouts/partials/nav.html`
- `site/hugo.yaml` (preserves existing `title`, `params.description`, `params.author`, `params.hue` — only rewrites the structural fields)

It does NOT touch:

- `site/content/` (module pages)
- `modules/` (exercises, VALIDATION)
- `briefs/`, `curriculum_spine.md`, `glossary.md`, `review.md`
- the curriculum-root shell scripts (`serve.sh` etc. — these get their own upgrade path, not handled here to avoid overwriting user edits)

## Phase 3: Build

```bash
cd "<cwd>" && ./build.sh
```

## Phase 4: Deliver

```
Layouts refreshed. Site rebuilt.

site/public/ is current against the v0.3 plugin templates.

If a server is running, restart it to pick up layout changes:
  ./stop.sh && ./serve.sh
```

Offer to start the server if one is not running:

```bash
if [ ! -f .hugo.pid ] || ! kill -0 "$(cat .hugo.pid 2>/dev/null)" 2>/dev/null; then
  # No server running
  # Ask: "Start the server now? [y/N]"
fi
```

On yes, same tmux-or-fallback flow as `/tmb:create` Phase 8.

## Boundaries

- No interview.
- No designer.
- No module-builders.
- No reviewer.
- Only Hugo infrastructure + build. Content is untouched.
