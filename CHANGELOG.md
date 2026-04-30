# Changelog

## 0.4.0 — 2026-04-30

Major refactor. Claude Code CLI only; lean on Hugo + shell scripts for everything that can be deterministic; share a single research substrate across parallel module-builders.

### Breaking

- **Claude Code CLI only.** The plugin shells out to `hugo`, `bash`, `curl`, `jq`, and `yq`. It cannot run inside Claude Work or claude.ai. The marketplace description and README drop all "optional Hugo" hedging. v0.3 curricula keep working under v0.3 but `/tmb:rebuild-site` refuses to upgrade them — research.yaml has no automatic backfill.
- **Skill names are prefixed `tmb-`** for picker disambiguation (`tmb-create`, `tmb-review`, `tmb-add-module`, `tmb-rebuild-site`, `tmb-help`). Slash commands stay short (`/tmb:create`, etc.) — the `commands/<name>.md` shim invokes the prefixed skill.
- **Module frontmatter is now bootstrapped, not authored.** `scripts/new-module.sh` runs `hugo new modules/<slug>/index.md` against an enriched archetype, then patches every brief-sourced field with `yq`. The module-builder agent only writes body content; it must not modify frontmatter. Reviewer's `check-frontmatter.sh` will flag any drift.

### Added

- **`tmb-researcher` agent + `research.yaml`.** Runs once at the start of `/tmb:create`, between the interview and the designer. Produces a canonical glossary, sourced reading list with section anchors, concept map, common contrasts, and authority list. Every downstream agent reads it; nobody else writes it. Eliminates duplicated, divergent web research across parallel module-builders. Schema in `references/research-schema.md`.
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

There is no automatic migration. v0.3 curricula keep working under v0.3. To take a v0.3 curriculum to v0.4, re-run `/tmb:create` from a fresh directory; the research substrate cannot be reverse-engineered from existing module pages.

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
