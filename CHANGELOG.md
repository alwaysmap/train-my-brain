# Changelog

## 0.4.19 — 2026-05-01

### Changed — visuals strategy: prefer YouTube embeds, bundle downloaded images, cap budgets

Building the `traditional-wood-arrows` curriculum surfaced a UX problem: the module-builder defaulted to `visual-needed` callouts (search-hint placeholders) for ~26 visuals across 5 modules and hotlinked the few real images it did find. The result felt like a search-hint blog rather than a curriculum — every other section pointed the reader off-site to do their own searching.

Updated `agents/tmb-module-builder.md` with three shifts:

1. **Prefer `{{< youtube ID >}}` over `visual-needed` for motion/procedure topics.** A 60-second embedded demo teaches more than three paragraphs of prose plus a "search YouTube" callout. Cap embedded videos at ~10 across the whole curriculum so the curriculum doesn't become a YouTube playlist.
2. **Download images into the module's page bundle, do not hotlink.** Each module is a Hugo branch bundle; dropping `image.jpg` next to `_index.md` and referencing it by filename couples the image to the page that uses it, survives offline cache and upstream URL changes, and resolves correctly under path-prefixed deploys.
3. **Aim for ~1 image per module; ≤3 `visual-needed` per module.** Beyond that, the module feels empty. Step back and check whether a YouTube embed would do the job better.

The module-builder prompt now spells out the download-and-resize workflow (curl with a real User-Agent, `sips -Z 1024` for oversize files) and reorders the shortcode docs so `youtube` comes first, `figure` second, `visual-needed` last.

Existing curricula keep working — this only changes what new module-builders produce.

### Fixed — nav/gloss links broken when published under a path-prefixed baseURL

`/tmb:publish` deploys to `https://<user>.github.io/<repo>/`, where the
baseURL has a basepath (`/<repo>/`). The scaffold's nav and `gloss`
shortcode used `"/path/" | relURL`, which does not prepend the basepath
for absolute inputs — so the brand link rendered as `href="/"` and the
glossary shortcode rendered as `href="/glossary/#anchor"`, both 404'ing
under the deployed URL while working fine under `hugo server`.

Switched both to `RelPermalink` of looked-up pages
(`site.Home.RelPermalink`, `(site.GetPage "/modules").RelPermalink`,
etc.) — the idiomatic Hugo pattern that respects the baseURL basepath
and works under both `hugo server` and the deploy `--baseURL` flag.
The modules sidebar already used this pattern correctly.

Existing curricula can pick up the fix by running `/tmb:rebuild-site`,
which re-runs `scaffold-site.sh` against the existing content tree.

## 0.4.18 — 2026-05-01

### Fixed — five issues found building a real curriculum

Building a real `traditional-wood-arrows` curriculum surfaced five distinct issues across the build pipeline. None individually were release-blocking; together they degraded the rendered curriculum noticeably (partial bootstrap, raw template text, broken Mermaid diagrams, walls of text instead of visuals).

#### `new-module.sh` no longer fails on briefs containing literal `"`

The script previously interpolated brief values into `yq` via the shell:

```bash
yq -i ".next_expects = \"$NEXT\"" "$FM"
```

When a brief contained inch marks (`11/32"`, `28"`) or any other literal `"`, the expansion produced malformed `yq` input and modules were partially bootstrapped — the concept page was written but `validation.md` and `exercises/_index.md` were silently skipped. Switched all string assignments to `yq`'s `strenv()` form so the shell never interpolates value characters into the `yq` argument.

#### Reviewer scripts now look for `_index.md` (Hugo branch bundles)

`new-module.sh` produces Hugo branch bundles (`_index.md`), but `check-adjacency.sh`, `check-frontmatter.sh`, `check-ai-prose.sh`, and `detect-curriculum.sh` were still referencing the leaf-bundle convention. Result: every healthy curriculum reported `ok: false` on adjacency and frontmatter checks because the scripts couldn't locate the page they were trying to read.

#### Escaped Hugo shortcodes flagged

Module-builder agents sometimes emit Hugo's escaped shortcode form `{{</* gloss */>}}` in module body content. Hugo prints those as literal `{{< gloss "Term" >}}` text instead of clickable glossary links. Added `scripts/check-shortcodes.sh` (a pure-bash linter that ignores fenced code blocks) and corresponding documentation in `references/markdown-gotchas.md`. Wired into the reviewer's Phase A.

#### Mermaid v11 syntax linter

Module-builders frequently emit Mermaid blocks that older versions tolerated but v11 rejects with "Syntax error in text". Five distinct patterns reproduced and now flagged by `scripts/check-mermaid.sh`:

- ° / em-dashes / other Unicode inside unquoted node labels
- Literal `\n` for line breaks (Mermaid expects `<br/>`)
- Apostrophes inside unquoted labels (`Archer's paradox`)
- `subgraph Two Words` without bracket-or-quote form
- `flowchart LR` with 7+ arrows (parses but renders as illegible thumbnails)

Pure bash + grep + jq for portability across macOS BSD awk and Linux GNU awk. Documented in `references/markdown-gotchas.md`. Wired into the reviewer's Phase A.

#### Visual content is now mandatory, not optional

The largest change. Module-builders followed the path of least resistance and emitted `<!-- TODO: source image — search Wikimedia for "X" -->` instead of actually finding free-use imagery and embedding it. For a self-described visual learner the rendered curriculum was just prose.

- `agents/tmb-module-builder.md` mandates at least one real image OR YouTube embed per module, with a five-step sourcing process (search Wikimedia category, verify CC license, copy `upload.wikimedia` direct URL, WebFetch to confirm 200, embed via `figure` shortcode with attribution caption). Bare `<!-- TODO: source image -->` comments in shipped modules are now an explicit anti-pattern.
- `references/curriculum-design.md` adds rule 7 ("Visual content is required, not optional").
- `scripts/scaffold-site.sh` ships a new `visual-needed` shortcode in every scaffolded curriculum: a styled callout with one-click YouTube + Wikimedia search links, used as a fallback when free-use coverage is genuinely unavailable. Far better than an invisible HTML comment.

#### Module-list hover-state contrast fix

The previous `linear-gradient(135deg, var(--color-primary-fade), var(--color-bg) 70%)` hover was reading as a saturated tinted block on some hue values, fighting the title color and washing out the italic driving-question text. Replaced with a low-alpha primary tint (`hsla(var(--hue), 60%, 50%, 0.06)`) that lets the page background dominate, keeping text contrast high.

## 0.4.17 — 2026-05-01

### Added — design system rewrite + theme switch + content-quality gates

The default Hugo site has been redesigned as a coherent design system rather than a collection of ad-hoc styles. The whole front-end was previously incoherent: triadic colors auto-derived from the user's `--hue` produced clashing pairs (fuchsia 320° + olive 80° was the worst case), every page leaked monotone primary, and the mobile sidebar dumped an 8-card overlay onto small viewports. This release rewrites `scripts/scaffold-site.sh`'s template/CSS heredocs into a single coherent system, adds a system/light/dark theme switch, requires citation density and Mermaid diagrams from module-builders, and ships an About page in every scaffolded curriculum.

#### Color system

- **One chromatic accent + one mathematical complement.** `--color-primary` is the user's `--hue`; `--color-link` is `hsla(calc(var(--hue) + 180), 55%, 32%, 1)` — the complement, derived not picked. Headings/structure use primary; body links + small annotation roles (numerals, eyebrows, prev/next labels, heading anchors) use the complement. The pair is harmonious for every starting hue (fuchsia ↔ green, teal ↔ rust, orange ↔ teal, etc.) because the math is symmetric.
- **`--color-triadic` and `--color-analogous` are defined but no longer used in the default UI.** They remain available for opt-in customization but ship inert because auto-derived triadic clashes for most user hues.
- **Neutrals are warm and hue-INdependent**: `--color-bg` is `hsl(40, 30%, 98%)` (cream canvas), `--color-text` is `hsl(230, 18%, 14%)` (ink with subtle blue). Identical regardless of which primary the user picked.

#### Theme switch

- **System / Light / Dark toggle in the top nav.** Three-segment icon group; choice persists to `localStorage["tmb-theme"]`. An inline pre-paint `<script>` in `baseof.html` applies the saved theme before any styles render, so there is no flash of the wrong theme on page load. "System" removes the `data-theme` attribute, falling back to `prefers-color-scheme`.
- **Dark-mode tokens factored** into a single `html[data-theme="dark"]` block, with a `:not([data-theme])` guard that re-applies the same tokens via `@media (prefers-color-scheme: dark)` when the user has not picked an explicit override. No duplicated rules.

#### Composition

- **Whole module cards are clickable** — entire `<li>` is wrapped in a single `.module-item-link` anchor. Default state: hairline border. Hover: border tightens to primary, background swaps to a `linear-gradient(135deg, var(--color-primary-fade), var(--color-bg) 70%)`, lifts 1px. No more click-target-on-title-only.
- **Heading anchor links** via a Hugo render hook (`layouts/_default/_markup/render-heading.html`). Every Markdown-sourced `h2..h6` gets a `#` that fades in on hover; clicking pushes the hash to the URL bar so any section is shareable.
- **Editorial home hero** — the page title sits as full-bleed type with a small primary→complement gradient rule beneath, not as a card-on-canvas hero. The card-in-card-in-card pattern from prior releases is gone.
- **Driving question reads as a quoted pull-quote** (italic, muted, primary left-strip, no fill) instead of a heavy second callout that competed with the h1 above it.
- **Section rules removed.** Major heading separation comes from generous top margin alone; horizontal rules above/below `h2`, on `.module-header`, and on `.single > header` were removed because they signaled "section starts here" when the actual semantic was "section ends below".
- **Headings render in `font-variant-caps: all-small-caps`** with a slight letter-spacing — editorial calm, scans well at long titles ("Data: What Goes In Before Training Starts"), supported across both `signage` and `book` font presets.
- **Mobile sidebar is `display: none`.** The top nav has Modules / Glossary / About entry points; the sidebar that previously dumped 8 cards above the viewport on phones is gone. The brand title is also hidden on mobile (it's already in the browser tab + the page h1).

#### A11y

- **`:focus-visible` ring on every interactive element** (2px primary, 3px offset).
- **Skip-to-content link** in `baseof.html` — visible on focus, jumps to `#main`.
- **`prefers-reduced-motion`** blanket override forces 0.01ms transitions/animations.
- **Verified contrast**: body 14.8:1 (AAA), muted 6.4:1 (AAA), faint 4.7:1 (AA), primary text 5.6:1 (AA-normal/AAA-large) against the new warm cream canvas.

#### Content-quality gates (LLM output requirements)

- **`tmb-module-builder` now requires inline footnote citations.** Every concept page must carry at least 4 Markdown footnote definitions (`[^name]: As X explains: "..." — Source (year), URL`). Pure prose without sources reads as AI hallucination — and a learner trying to build credibility on a topic must be able to verify what they're learning AND cite their sources back to colleagues.
- **`tmb-module-builder` requires at least one Mermaid diagram in the mechanism section.** The scaffold wires up the render hook; concept-heavy modules without a visual reify the AI-slop concern.
- **`tmb-researcher` now captures `excerpt` per `sources[].sections[]`.** A 1–3 sentence verbatim quote that builders use as the body of an inline footnote. Without excerpts, builders can only cite bare URLs and citations don't let the reader verify a claim without leaving the page.
- **`scripts/check-citations.sh`** — new reviewer script. Counts footnote definitions per module concept page; flags any module under the threshold (4) as a `low_citation_density` substantive flag in `review.md`.
- **`scripts/validate-research.sh`** — soft-warns when more than half of the source sections lack `excerpt` fields.

#### About page + README

- **Every scaffolded curriculum now ships an About page** (`site/content/about.md`, served at `/about/`) explaining what TMB is, how to install the plugin, and how to edit/publish the curriculum. Generated from `curriculum-templates/about.md.tmpl` if missing — never clobbers an existing about page.
- **`curriculum-templates/about.md.tmpl`** documents the Ctrl-C vs `./stop.sh` behavior — Ctrl-C works for foreground `./serve.sh`; `./stop.sh` is for the tmux-detached session that `/tmb:create` launches.

## 0.4.16 — 2026-05-01

### Changed

- **Multiple-choice prompts now use the native `AskUserQuestion` picker.** Previously the interview and confirmation gates were rendered as numbered prose ("1) Job interview / 2) Customer conversation / ... — reply with the numbers"), which read as a form and didn't let the user unselect once they'd typed. The 8-step interview (steps 2, 4, 5, 8), the preamble, the post-Step-8 summary, the reflection confirmation after every step, and every confirmation gate in `/tmb:create` now call `AskUserQuestion` — Claude Code's TUI select widget with keyboard navigation (↑/↓, space to toggle in multi-select, Enter to submit, automatic "Other" option for free-text escape).

  Constraints of the tool drove two menu changes:

  - **Step 2 ("How will you be tested?")** consolidated from 6 options to 4 (`AskUserQuestion` caps at 4): "Job interview or certification exam", "Customer or stakeholder conversation", "Code review or pair programming", "Writing (blog post, docs, proposal)". The "no external test" path moves to "Other" — pickable via the auto-appended Other option, with a one-line note in the question text so users see it.
  - **Step 5 ("Validation preference")** dropped the redundant "All of the above" — multi-select makes it equivalent to picking all four.

  The reflection-confirmation pause after each interview step now uses a two-option picker ("Yes — that matches" / "Not quite — let me adjust") instead of the previous free-text "Does that sound right?" prompt. Same discipline (still a separate exchange from the next question), just one keystroke to confirm.

  Updated docs: `references/elicitation.md`, `skills/create/SKILL.md` (the "Confirmations are multiple-choice" standing rule is now "Confirmations use the AskUserQuestion picker"), `skills/create/references/curriculum-state.md` (v0.4-partial resume offer).

## 0.4.15 — 2026-05-01

### Fixed

- **Skill names dropped the redundant `tmb-` prefix.** Slash autocomplete previously surfaced two entries per command — e.g., both `/tmb:help` (the command shim) and `/tmb-help` (the underlying skill, named `tmb-help`). Two equally-valid forms is one too many, and the hyphenated form is the wrong one because the plugin namespace already provides `tmb:`. Skills are now named after the bare verb, so the picker shows only the `/tmb:<command>` form.

  Renames inside the plugin (no user-facing slash form changes — `/tmb:create` etc. still work):
  - `skills/tmb-create/`        → `skills/create/`        (`name: tmb-create` → `name: create`)
  - `skills/tmb-review/`        → `skills/review/`        (`name: tmb-review` → `name: review`)
  - `skills/tmb-add-module/`    → `skills/add-module/`    (`name: tmb-add-module` → `name: add-module`)
  - `skills/tmb-rebuild-site/`  → `skills/rebuild-site/`  (`name: tmb-rebuild-site` → `name: rebuild-site`)
  - `skills/tmb-help/`          → `skills/help/`          (`name: tmb-help` → `name: help`)

  Each `commands/<name>.md` now invokes the bare skill name. Internal `skills/create/references/...` path references in `skills/create/SKILL.md` were updated to the new directory. `agents/tmb-*.md` keep the `tmb-` prefix — agents are referenced via `subagent_type` and don't appear in slash autocomplete, so there's no collision to clean up.

  The v0.4.4 rationale for keeping `tmb-` on skill names ("picker disambiguation") no longer holds: the plugin namespace `tmb:` is the disambiguator, and doubling it just clutters the picker.

## 0.4.14 — 2026-05-01

### Fixed

- **Plugin `homepage` now points at the GitHub repo** (`https://github.com/alwaysmap/train-my-brain`) so "open home page" from the Claude Code CLI loads the source repo instead of an unrelated marketing URL.

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
