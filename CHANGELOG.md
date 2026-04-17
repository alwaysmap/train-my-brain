# Changelog

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
