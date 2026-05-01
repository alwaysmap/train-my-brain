# Changelog

## 0.4.13 — 2026-04-30

### Added

- **Every exercise gets a paired model-answer page.** Filename pattern: an exercise at `exercises/<name>.md` has a sibling at `exercises/<name>-answer.md`. The Hugo layout cross-links them automatically:
  - The exercise page renders a "Show model answer →" CTA at the bottom (dashed border, soft primary background, deliberate-click button — not a passive scroll target).
  - The answer page renders a "← Back to the exercise" link.
  - The exercises list page filters out `type: answer` so each pair shows as a single entry, not two.
  - URL pattern: `/modules/<slug>/exercises/<name>/` (exercise) and `/modules/<slug>/exercises/<name>-answer/` (answer).

  No links are written into the markdown body — `_default/single.html` does the lookup via `.Parent.GetPage` so cross-linking is structural, not content-coupled.

### Changed

- **Module-builder agent contract** now requires both files per exercise. The answer body must include: the worked solution (every `[TODO:]` filled in), a "Why these choices" tradeoff section, and a "Common pitfalls" wrong-then-right list. The reviewer flags any orphan exercise (no matching answer) as `build_failure`.
- **New archetype `archetypes/answer.md`** with `type: answer` so future Hugo `hugo new` invocations get the right frontmatter.

### Migration

Existing v0.4.x curricula don't have answer pages — only new modules built under v0.4.13 will. Layout change is safe: with no answer file, the CTA simply doesn't render. To retroactively add answers to existing modules, re-dispatch the module-builder for each module (a one-shot task; ask the agent to "add a model-answer file for each exercise").

### Fixed

- **CSS is no longer fingerprinted.** v0.4.0 piped `resources.Get "css/site.css" | fingerprint` so the URL was `/css/site.<sha>.css`. That meant every CSS edit forced a hard browser refresh and orphaned the previous fingerprinted file in `public/css/` until a clean rebuild. Now `baseof.html` skips `| fingerprint` so the URL is always `/css/site.css` — predictable, cacheable on a normal soft refresh.

  Stays in `assets/` (going through `resources.Get`) so future Hugo Pipes processing — minification, SCSS, PostCSS — can layer on without changing the URL contract. The "fingerprint for cache-busting in production" pattern can come back if the site is ever deployed to a setup with hot-reload-unfriendly CDN caching, but the local dev case shouldn't pay for that.

  Existing curricula pick up via `/tmb:rebuild-site`.

### Changed

- **Primary color now appears throughout the page, not just on h1.** v0.4.4–0.4.10 colored only `h1` and `<a>` with `--color-primary`; everything else inherited `--color-text` (near-black). For low-chroma hue choices like yellow-gold (55) or olive (80), this made the page read as monochrome below the fold. Now:
  - **h2** uses `--color-primary-strong` with a soft `--color-primary-soft` border-bottom — every section break carries a tint.
  - **h3** uses `--color-primary-strong`.
  - **`.module-number`** ("MODULE 5") uses `--color-primary` in uppercase letterspaced caps.
  - **Sidebar `<h3>` "ALL MODULES"** uses `--color-primary` (was muted).
  - **`.module-header`** border-bottom is now `2px var(--color-primary-soft)` (was 1px border-color).
- **Saturation pushed up across the palette** so any chosen hue actually reads. Light mode primary went from `s=65% l=38%` to `s=75% l=35%`; muted from `s=5%` to `s=10%`; border from `s=15%` to `s=25%`. Dark mode mirrored. New `--color-primary-strong` token (`s=80% l=28%` light / `s=80% l=80%` dark) for headings that need to read clearly against the body.
- **New token `--color-primary-strong`** for darker / more-saturated primary use cases (h2, h3).

  Existing curricula pick up via `/tmb:rebuild-site`.

### Fixed

- **Glossary page no longer shows duplicate "Glossary" heading or `(source: research.yaml)` attributions.** Both bugs were already fixed in v0.4.3's `merge-glossary.sh` rewrite, but two issues stuck around:
  - `merge-glossary.sh` only wrote `<root>/glossary.md` (the data file at curriculum root). Hugo serves from `<root>/site/content/glossary.md`, which was getting copy-mirrored by an older mechanical-fix step in the reviewer agent that ran v0.4.2-era code. Result: the served Hugo page kept showing the old format.
  - The Hugo layout renders `<h1>{{ .Title }}</h1>` from frontmatter, but the older `merge-glossary.sh` also wrote `# Glossary` as the first body line — a duplicate heading.

  Now `merge-glossary.sh` writes BOTH locations atomically (`<root>/glossary.md` AND `<root>/site/content/glossary.md`), bit-for-bit identical, with no body-level `# Glossary` heading and no source attributions. Existing curricula pick up via `/tmb:review` (which calls the reviewer, which calls merge-glossary.sh).

  Also swept the codebase: no other scripts/templates emit `(source:` or duplicate-heading patterns.

### Fixed

- **Module list now renders as proper cards.** v0.4.3 used `<li>::before { content: counter(module) "." }` to inject the module number, but the next sibling was a block `<div>` so the counter ended up on its own line above the title. Plus there was no card styling — just a thin bottom border on each item.

  v0.4.9 turns each `.module-item` into a 2-column CSS grid: column 1 is the counter (spans all rows), column 2 holds the title + summary + driving-question. Border + rounded corners + padding now make it look like an actual card. Hover states added: border tints primary, soft shadow, 1px translate, title colors. Dark-mode shadow tuned separately. Used on `/modules/` and `/modules/<slug>/exercises/` lists.

  Pick up via `/tmb:rebuild-site` on existing curricula.

### Fixed

- **Driving question rendered twice on module pages.** v0.4.3's `new-module.sh` defaulted `summary = driving_question`, and `module/section.html` rendered both fields independently — so the question appeared once as a `<p class="summary">` and again immediately below as a `<p class="driving-question">` callout. Two fixes:
  - `module/section.html` now skips `summary` when it equals `driving_question`. Defense in depth — even if a module's frontmatter has both set to the same string, only the callout renders.
  - `new-module.sh` no longer defaults `summary` to the driving question. It writes `summary: ""` and lets the module-builder fill it in only when there's a genuinely separate one-sentence framing to add.

  Existing curricula picked up via `/tmb:rebuild-site`. Authors can also edit `site/content/modules/<slug>/_index.md` to clear duplicate `summary` lines manually if they prefer.

## 0.4.7 — 2026-04-30

### Fixed

- **`scaffold-site.sh --layouts-only` now cleans up stale layouts.** v0.4.0–0.4.2 used `layouts/_default/page.html` and `layouts/_default/section.html`; v0.4.3+ replaced them with `layouts/_default/list.html` + `layouts/_default/single.html` + `layouts/module/section.html`. Refreshing layouts wrote the new files but left the old ones behind, and Hugo's lookup picked the older `section.html` for any generic section page (e.g., `/modules/<slug>/exercises/`), causing the `<span class="status">planned</span>` pill to keep rendering. Now `--layouts-only` deletes those two stale files before writing the current set.

  Existing curricula migrated from v0.4.2 should re-run `/tmb:rebuild-site` (or, equivalently, `bash scripts/scaffold-site.sh --target . --layouts-only && ./build.sh`) to pick up the cleanup. v0.4.4-onwards-fresh curricula are unaffected.

## 0.4.6 — 2026-04-30

### Changed

- **Slash command form: `/tmb:tmb-create` → `/tmb:create`.** v0.4.3 prefixed both the skill name AND the command-file name with `tmb-`, producing the doubly-namespaced `/tmb:tmb-<name>` slash form that nobody likes typing. Claude Code's plugin loader requires the `<plugin>:` colon prefix (it's not configurable), so the cleanest form is `/tmb:<command>`. Command files are now named `commands/<name>.md` (no `tmb-` prefix); skill names keep the `tmb-` prefix for picker disambiguation. Every doc/agent/skill/reference reference updated to the new form.

  - `/tmb:tmb-create`        → `/tmb:create`
  - `/tmb:tmb-review`        → `/tmb:review`
  - `/tmb:tmb-add-module`    → `/tmb:add-module`
  - `/tmb:tmb-rebuild-site`  → `/tmb:rebuild-site`
  - `/tmb:tmb-help`          → `/tmb:help`

  Skills (and the picker label form) stay `tmb-create`, `tmb-review`, `tmb-add-module`, `tmb-rebuild-site`, `tmb-help`. The shim `commands/<name>.md` invokes the `tmb-<name>` skill.

## 0.4.5 — 2026-04-30

### Changed

- **Step 8 (typography) now opens with rationale.** v0.4.4 asked "Are you more into public signage or printed books?" with a one-liner ("It picks the typography for your site.") — which read as whimsical and gave no reason to care. v0.4.5 leads with why typography matters for a curriculum the learner reads for hours, frames each option around its *reading pattern* (scan-and-dip vs sit-and-read) rather than its *appearance*, and explicitly notes that dark mode + high-contrast still work in either preset. The `ask_user_input` instruction is sharpened so the menu renders as the picker UI, not as free text.

## 0.4.4 — 2026-04-30

### Added

- **Step 8 of the interview: typography preset.** "Are you more into public signage or printed books?" The user picks once; the answer drives a `font_preset` (`signage` or `book`) persisted as `params.font_preset` in `hugo.yaml`.
  - **Signage** — humanist sans (Inter → system-ui). Tight UI feel like wayfinding and modern docs.
  - **Books** — classical serif (Source Serif 4 → Charter → Iowan Old Style → Georgia). Generous leading; reads like a long-form essay.
  - Both presets ship with Inter for UI chrome and JetBrains Mono for code, loaded from Google Fonts via `<link rel="preconnect">` + `display=swap`.
- **Dark mode** — `@media (prefers-color-scheme: dark)` block in `site.css` redefines every color token at adjusted lightness/saturation. Hue stays constant, so the palette identity carries from light to dark. The user's OS preference drives rendering automatically.
- **High-contrast a11y mode** — `@media (prefers-contrast: more)` pushes text↔bg lightness gaps further (>= AAA's 7:1 contrast ratio) for low-vision users. Works on top of light or dark.
- **Semantic color tokens** — palette is now organized as `--color-bg / --color-surface / --color-text / --color-muted / --color-border / --color-primary / --color-primary-soft / --color-primary-fade / --color-analogous / --color-triadic / --color-triadic-soft`. All HSLA, all derived from `--hue` via `calc()`. Light-mode contrast: text↔bg L gap of 84 → 16:1 (AAA). Dark: 80 → ~13:1 (AAA). Primary on either bg lands at AA (~5.4:1).

### Changed

- The 7-step interview is now an **8-step** interview. Every doc reference updated. The conversation-arc preamble at the top of `references/elicitation.md` says "8 short questions." `commands/tmb-create.md`, the `tmb-create` SKILL, the help skill, the designer/researcher agent contracts, and the spine schema all reflect the new count.
- `scaffold-site.sh` accepts a new required `--font-preset signage|book` argument. `--layouts-only` mode preserves an existing curriculum's `font_preset` from `hugo.yaml` so refreshes don't reset it.

## 0.4.3 — 2026-04-30

### Breaking

- **Each module is now a Hugo branch bundle, not a leaf page.** v0.4.2 wrote concept content to `site/content/modules/<slug>/index.md` and exercises + validation to `modules/<slug>/exercises/` and `modules/<slug>/VALIDATION.md` (outside Hugo, invisible on the site). v0.4.3 publishes everything as Hugo content:
  - `site/content/modules/<slug>/_index.md` — concept page
  - `site/content/modules/<slug>/validation.md` — `/modules/<slug>/validation/`
  - `site/content/modules/<slug>/exercises/_index.md` — `/modules/<slug>/exercises/`
  - `site/content/modules/<slug>/exercises/<name>.md` — `/modules/<slug>/exercises/<name>/`
  - `modules/<slug>/new_terms.yaml` — kept (data file, not user-facing)

  v0.4.2 curricula need to be re-generated (`/tmb:tmb-create` from a fresh directory). The existing exercise + validation files under `modules/<slug>/` are not auto-migrated.

### Added

- **Glossary auto-linker** (`scripts/link-glossary.sh`) — scans every module page, wraps the first occurrence of every known glossary term in a Hugo `{{< gloss "..." >}}` shortcode that links to the glossary anchor. Knows about `research.yaml.glossary` (with aliases), `curriculum_spine.glossary_seed`, and per-module `new_terms.yaml`. Idempotent. Runs in the reviewer phase as a mechanical fix. Solves "RAG is mentioned in a table heading but never linked to a definition."
- **`gloss` Hugo shortcode** — `{{< gloss "Term" "display text" >}}` renders a glossary link. Module-builders can use it directly; the auto-linker fills in any first-mention they missed.
- **Modules sidebar nav** — every page shows a sticky-positioned `<aside>` listing every module in weight order, with the current module highlighted and its sub-resources (validation, exercises) expanded. No more "next, next, next" — full curriculum navigation is always visible.
- **Practice section on each module page** — the concept page now ends with a "Practice" block linking to its validation and exercises with explicit calls to action ("try the scenario aloud, then answer in writing").
- **Multiple-choice confirmation gates** — every gate in `/tmb:tmb-create` (target dir, design approval, dep install, resume offer, research open-questions) presents numbered options like `1) Proceed / 2) Suggest changes / 3) Cancel` instead of "Is that ok?". One-keystroke confirmations, no more typing "yes" five times per setup.

### Fixed

- **Module pages no longer show "planned" status pill.** The status field was a v0.2 artifact that never went anywhere; layouts now ignore it. (Status field stays in frontmatter as `planned` — just hidden in templates.)
- **`(source: research.yaml)` removed from glossary entries.** `merge-glossary.sh` now writes clean `## Term` + definition entries with no provenance line.
- **Prev/next module navigation goes the right direction.** v0.4.2 used Hugo's `.PrevInSection` / `.NextInSection` which default to date-descending. v0.4.3 sorts by `weight` ascending so module N's "next" is module N+1.
- **Hugo deprecation warnings cleared.** Updated to `defaultContentLanguage` and removed `paginate` (now `pagination.pagerSize` in Hugo 0.158+; we drop the explicit setting since the default is fine).
- **Module-builder agent contract strengthened.** Hard rules now state every module produces at least one exercise file with at least two `[TODO:]` markers, plus a validation page with scenario + good-answer + try-it-aloud. The reviewer flags any module missing these as `build_failure`.

## 0.4.2 — 2026-04-30

### Fixed

- **Researcher agent was over-budget** — taking ~1 hour on real topics instead of the 3-5 minute budget. Three trims:
  - Dropped the per-anchor verification step (`Test the anchor — fetch the page and confirm the anchor exists`). For 4-10 sources × 1-3 sections each, that was 10-30 redundant `WebFetch` calls. The reviewer's `check-urls.sh` already catches dead URLs.
  - Dropped the two-source triangulation requirement on every glossary term. One authoritative source is enough; if a builder later defines a term differently, `merge-glossary.sh` flags the divergence.
  - Lowered glossary minimum from 8 to 5 entries (`validate-research.sh` and the schema doc both updated). Narrow topics were forcing extra search rounds to clear the gate.
  - Added an explicit time budget (3-5 min target) and hard-cap hints (~12 `WebSearch`, ~15 `WebFetch`).
- **Report scripts no longer exit non-zero on findings.** `check-urls.sh`, `check-adjacency.sh`, `check-frontmatter.sh`, and `check-ai-prose.sh` now always exit 0 when they ran successfully (regardless of how many issues they found). Their findings are `review.md` flags, not pipeline-aborting errors. Exit 2 still signals real setup errors (missing yq/jq/curl/dirs). Gates (`validate-briefs.sh`, `validate-research.sh`) keep their exit-1-on-gap behavior. This eliminates the alarming `Error: Exit code 1` surface in Claude Code when the reviewer is just reporting a 404 in a brief.

## 0.4.1 — 2026-04-30

### Fixed

- **Plugin manifest validation.** `plugin.json` no longer declares `skills`, `agents`, or `commands` path fields. The current Claude Code plugin loader rejects those (`agents: Invalid input`), and the conventional directories are auto-discovered without them. v0.4.0 was uninstallable — install v0.4.1 instead.

## 0.4.0 — 2026-04-30

Major refactor. Claude Code CLI only; lean on Hugo + shell scripts for everything that can be deterministic; share a single research substrate across parallel module-builders.

### Breaking

- **Claude Code CLI only.** The plugin shells out to `hugo`, `bash`, `curl`, `jq`, and `yq`. It cannot run inside Claude Work or claude.ai. The marketplace description and README drop all "optional Hugo" hedging. v0.3 curricula keep working under v0.3 but `/tmb:tmb-rebuild-site` refuses to upgrade them — research.yaml has no automatic backfill.
- **Slash commands and skill names are now consistently prefixed `tmb-`** — every command is `/tmb:tmb-<name>` (e.g., `/tmb:tmb-create`, `/tmb:tmb-review`, `/tmb:tmb-add-module`, `/tmb:tmb-rebuild-site`, `/tmb:tmb-help`). Skill `name:` fields, `commands/*.md` filenames, and every doc reference all use the same form. v0.3 used the bare `/tmb:create` form — your muscle memory will need to update.
- **Module frontmatter is now bootstrapped, not authored.** `scripts/new-module.sh` runs `hugo new modules/<slug>/index.md` against an enriched archetype, then patches every brief-sourced field with `yq`. The module-builder agent only writes body content; it must not modify frontmatter. Reviewer's `check-frontmatter.sh` will flag any drift.

### Added

- **`tmb-researcher` agent + `research.yaml`.** Runs once at the start of `/tmb:tmb-create`, between the interview and the designer. Produces a canonical glossary, sourced reading list with section anchors, concept map, common contrasts, and authority list. Every downstream agent reads it; nobody else writes it. Eliminates duplicated, divergent web research across parallel module-builders. Schema in `references/research-schema.md`.
- **Determinism scripts.** Every check that can be expressed as a shell script is one. The reviewer agent calls these instead of reimplementing the logic in prose:
  - `scripts/check-deps.sh` — unified preflight (hugo + yq + jq + curl).
  - `scripts/validate-research.sh` — gate on research.yaml completeness.
  - `scripts/validate-briefs.sh` — gate on briefs/*.yaml (replaces designer's in-prose check).
  - `scripts/check-urls.sh` — `curl -I` against every reading-list URL.
  - `scripts/check-adjacency.sh` — every `next_expects` ↔ `prior_ends_with` pair, brief and frontmatter.
  - `scripts/check-frontmatter.sh` — index.md frontmatter matches its brief.
  - `scripts/check-ai-prose.sh` — regex pass for opener clichés, fake enthusiasm, consulting-speak.
  - `scripts/merge-glossary.sh` — merges identical-definition terms; surfaces conflicts; folds in research.yaml glossary.
  - `scripts/detect-curriculum.sh` — JSON status (fresh / partial / non-tmb / v0.2) for resume detection.
  - `scripts/new-module.sh` — `hugo new` + frontmatter patch + `mkdir -p exercises/` + seeded VALIDATION.md and new_terms.yaml.
- **`commands/*.md` shims** wire each skill to a slash command. v0.3 had an empty `commands/` directory.
- **Progressive disclosure** in `tmb-create/SKILL.md` (jfm-style): `Files` table at the top, per-phase pointers, detail in `skills/tmb-create/references/delivery.md`.
- **Skill frontmatter standardized**: `version`, `user_summary`, multi-line `description: >` with comprehensive trigger phrases.

### Changed

- The 7-step interview is unchanged in content, but the create skill now reads `references/elicitation.md` rather than embedding it.
- Reviewer agent slimmed dramatically — it is now a thin orchestrator over the determinism scripts. Substantive triage and review.md authoring are the only LLM work.
- Designer reads `research.yaml` and never does web research itself. URLs and definitions come from the substrate.
- Module-builders are truly parallel — each only reads its brief, the spine, and `research.yaml`. No sibling-coordination or web research.
- Hugo `hugo.yaml` uses `defaultContentLanguage` instead of the deprecated `languageCode` (Hugo ≥ 0.158 deprecation).

### Migration from 0.3.x

There is no automatic migration. v0.3 curricula keep working under v0.3. To take a v0.3 curriculum to v0.4, re-run `/tmb:tmb-create` from a fresh directory; the research substrate cannot be reverse-engineered from existing module pages.

Slash command form changed: `/tmb:create` → `/tmb:tmb-create` (and the same for every other command). Update any docs, dashboards, or muscle memory accordingly.

## 0.3.0 — 2026-04 (in progress)

### Breaking

- The `/tmb` command is replaced by four namespaced commands: `/tmb:create`, `/tmb:review`, `/tmb:add-module`, `/tmb:rebuild-site` (plus `/tmb:help`).
- Per-module `README.md` files are gone. Concept prose lives in `site/content/modules/NN-slug/index.md` (Hugo single source of truth). `modules/NN-slug/` now holds only `exercises/` and `VALIDATION.md`.
- Top-level `README.md` becomes a short index (≤ ~15 lines). It does not duplicate concept prose.
- The claude.ai-chat delivery path (remote container + zip + `present_files`) is removed. v0.3 targets Claude Code on a local filesystem only. Users who need the claude.ai-chat flow should stay on v0.2.x.
- Save location is now `<cwd>/<topic-slug>/` (scaffolds into a subfolder of the current directory). The `/tmb:create` command no longer asks where to save. If the target subfolder already exists and is non-empty, the run aborts with a clear message.

### Added

- **Design phase** — a single `tmb-designer` agent turns the 7-step interview into `curriculum_spine.md` and one `briefs/NN-slug.yaml` per module. A brief-completeness gate aborts `/tmb:create` before dispatch if any field is missing.
- **Parallel module builders** — the pipeline dispatches one `tmb-module-builder` subagent per module. Each agent sees only its own brief and the spine. Glossary coordination is via per-builder `new_terms.yaml` side-files merged by the reviewer.
- **Reviewer agent** (`tmb-reviewer`) — runs automatically after builders. Auto-fixes mechanical issues (frontmatter, weight collisions, glossary merge). Flags substantive issues (missing contrast, adjacency mismatch, AI-prose violations, non-2xx reading-list URLs) in `review.md` with an `approved: null` field per flag. User edits approvals, re-runs, and the reviewer applies only approved fixes.
- **Shell scripts shipped inside curricula** — `serve.sh`, `build.sh`, `stop.sh` plus PowerShell counterparts. `./serve.sh` is the only command a user needs to view their site.
- **Hugo install helper** — `scripts/check-hugo.sh` / `.ps1` detects missing or outdated Hugo and offers a platform-appropriate one-line install (`brew`, `winget`, `snap`, `apt`) before falling back to printing the release URL.
- **Scaffold script** — `scripts/scaffold-site.sh` replaces inline heredocs in the old skill. Supports `--layouts-only` mode used by `/tmb:rebuild-site`.

### Changed

- The 7-step interview is retained verbatim from v0.2.
- Existing Hugo layouts, CSS, and archetype are carried forward; the archetype gains new frontmatter fields (`driving_question`, `concepts`, `contrast`, `prior_ends_with`, `next_expects`, `topics`, `blog_post`) so the reviewer can validate adjacency without parsing prose.
- Plugin manifest gains explicit `skills`, `agents`, `commands` path declarations.

### Migration from 0.2.x

There is no automatic migration. Curricula built with v0.2 keep working under v0.2; they are not upgraded in place. `/tmb:rebuild-site` refuses to run against a v0.2-shaped curriculum (detected by presence of `modules/NN/README.md`) and points at this changelog.

## 0.2.0

Previous release. See the `v0.2.0` git tag.
