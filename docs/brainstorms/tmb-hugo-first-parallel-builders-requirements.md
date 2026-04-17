---
date: 2026-04-17
topic: tmb-hugo-first-parallel-builders
---

# TMB: Hugo-first authoring, parallel builders, and a reviewer agent

## Problem Frame

The TMB skill currently treats Hugo as a required **tool** but not a required **authoring surface**. Module content is written as rich `modules/NN-slug/README.md` files during the sequential Build phase; the Hugo site is scaffolded afterward and content is backfitted — often via a last-minute sync script. This produces three recurring problems:

1. **Duplication / drift.** The same concept prose lives in `modules/NN/README.md` and `site/content/modules/NN/index.md`. Whichever surface is edited by hand becomes the new truth and the other one rots.
2. **Slow builds.** Modules are generated one at a time. A 7-module curriculum takes as long as 7 modules plus interview plus packaging. Users wait.
3. **Silent drift across modules.** There is no consistency check after the build. Terms get redefined, contrast sections get skipped, `prior_ends_with` / `next_expects` handoffs mismatch.

The fix is to pivot the skill so Hugo archetypes are the baseline content type (not a destination), to parallelize per-module content generation behind atomic briefs, and to run a reviewer agent that catches drift automatically.

## Requirements

**Hugo-first content model**
- R1. Hugo content files at `site/content/modules/NN-slug/index.md` are the **single source of truth** for module concept prose.
- R2. Repo-level `modules/NN-slug/` contains only `exercises/` and `VALIDATION.md`. No per-module `README.md`.
- R3. Top-level `README.md` is a short index (≤ ~15 lines) pointing to the Hugo site and listing modules by status. It does not duplicate concept prose.
- R4. The Hugo site scaffold (layouts, CSS, archetypes, `hugo.yaml`, the GitHub Actions workflow) is created **before** any module content is authored. The scaffold is produced by an explicit `scripts/scaffold-site.sh` script invoked by the skill; the script runs `hugo new site site/ --format yaml`, copies archetypes and layouts from the skill's reference files, writes `hugo.yaml` with interview-derived params (title, description, author, hue), and copies `.github/workflows/deploy.yml`. Every step is a deterministic shell command — no prose-driven file creation.
- R5. Module content authoring uses Hugo archetypes (`hugo new content/modules/NN-slug/index.md`) when the Hugo CLI is available; otherwise the frontmatter is written directly from the same archetype template. The `archetypes/modules.md` file must include all frontmatter fields the brief populates (driving_question, concepts, contrast, topics, prior_ends_with, next_expects, blog_post, status, weight, summary, date, draft).

**Parallel module building**
- R6. The design phase produces a **detailed per-module brief** as a YAML file at `briefs/NN-slug.yaml` containing: `title`, `weight`, `driving_question`, `concepts` (3–5 named), `contrast` target, `reading` (real URLs for primary + secondary sources), `exercise_goal` (with **TODO hooks** — inline placeholder markers of the form `[TODO: <specific thing to implement>]` that mark the exact points where the learner fills in logic, not boilerplate), `validation_scenario`, `prior_ends_with`, `next_expects`. The module-builder agent copies the brief's `driving_question`, `concepts`, `contrast`, `prior_ends_with`, and `next_expects` verbatim into the Hugo page's frontmatter so the reviewer can validate adjacency without parsing prose.
- R6a. Before dispatching any builder, the design phase runs a **brief-completeness check**: every brief must have all required fields populated (no nulls, no `TBD`, no empty lists for `concepts`/`reading`). Incomplete briefs abort `/tmb:create` with a clear error listing the gaps. This makes the "zero missing contrast sections" success criterion satisfiable — the gate is pre-dispatch, not post-build.
- R7. A shared `curriculum_spine.md` file captures running-example state, goal, tested-via, depth-vs-breadth, audience starting point, hue, and glossary terms known at design time. Every module-builder reads it.
- R7a. **Glossary coordination under parallelism.** Builders do NOT write to `glossary.md` directly. Each builder emits a `new_terms.yaml` side-file in its module folder listing any terms it introduced that are not already in the spine (with inline definitions). The reviewer merges all `new_terms.yaml` files into `glossary.md` in one pass after builders finish. This avoids any concurrent-write race on a shared file.
- R8. Module builders are dispatched in **parallel** — one subagent per module. Each agent receives only its own brief and the spine; it does not read sibling modules' content.
- R8a. **Builder failure semantics.** If a builder fails, times out, or writes malformed frontmatter, the pipeline continues with the remaining modules and the reviewer lists the failed modules as a P0 substantive issue in `review.md`. The user decides whether to re-dispatch the failed builders (via a follow-up `/tmb:add-module`-style call targeted at the specific failed NN) or abort. The pipeline does not auto-retry.
- R9. Module builders may not invent scope. Because R6a gates on brief completeness, a dispatched builder always has every field populated. If the builder encounters a situation the brief does not cover (rare; implies a design-phase bug), it flags the specific gap and writes partial prose rather than guessing.

**Reviewer agent**
- R10. After all builders finish, a reviewer agent runs automatically and emits `review.md` at the repo root.
- R11. The reviewer **auto-fixes mechanical issues** without asking. Mechanical is defined as: does not alter prose meaning and the correct fix is unambiguous from the document or spine. The full mechanical list:
  - Missing or mistyped frontmatter fields where the value is already in the brief or spine
  - Merging `new_terms.yaml` side-files into `glossary.md` (per R7a)
  - Inline link format normalization (relative paths, trailing slashes, markdown vs angle-bracket)
  - Weight reordering when two modules collide on `weight`
  - Adding Hugo archetype defaults for any module missing `status`, `date`, or `draft` fields
- R12. The reviewer **flags substantive issues** for user approval before any fix is applied. Substantive is defined as: the fix changes prose meaning, requires authorial judgment, or has more than one reasonable resolution. The full substantive list:
  - Missing or weak contrast section
  - Missing, vague, or trivially answerable `driving_question`
  - `next_expects` on module N ≠ `prior_ends_with` on module N+1 (adjacency handoff mismatch)
  - AI-prose violations (Rules 1–4 in SKILL.md) — detected by a heuristic checker; false-positive rate is expected to be moderate, so every flag is presented for user review, never auto-rewritten
  - Running-example absence in a module that should anchor on it
  - `[TODO: find URL]` markers in the reading list
  - Reading-list URLs that return non-2xx on a reviewer HEAD-request (see R26)
  - Modules that failed to build (per R8a)
- R13. The reviewer is re-runnable on demand via `/tmb:review`.
- R26. The reviewer performs a **URL reachability check** on every reading-list URL in every module's frontmatter / prose. The check is an explicit command: `curl -I -sSL --max-time 5 -o /dev/null -w "%{http_code}" <URL>`. Non-2xx responses and `[TODO: find URL]` markers are flagged as substantive (R12). This is the only factual-accuracy check the reviewer performs; all other accuracy remains the builder's responsibility per `references/curriculum-design.md` Rule 1. Failures do not abort the pipeline.

**Slash command surface**
- R14. `/tmb:create` — full pipeline: interview → design → scaffold Hugo → parallel builders → reviewer → build → serve → deliver. Replaces the current `/tmb` as the primary entry point.
- R15. `/tmb:review` — runs the reviewer against an existing TMB curriculum in the current directory. Requires `curriculum_spine.md` and per-module briefs to exist.
- R16. `/tmb:add-module` — adds one module: asks for driving question + topic, generates a brief, dispatches a single builder, then runs the reviewer on just the new module and its adjacency neighbors. After success, re-runs `build.sh` so the site is up to date.
- R17. `/tmb:rebuild-site` — invokes `scripts/scaffold-site.sh --layouts-only` (which skips `hugo new site` and only refreshes `layouts/`, `assets/css/`, `archetypes/`, and `hugo.yaml`), then invokes `./build.sh`. Both steps are explicit shell commands, not prose-driven operations. Does not touch `content/` or `modules/`. Optionally offers to start the server via `./serve.sh`.

**Build and serve scripts**
- R20. Every curriculum scaffold includes a `serve.sh` (POSIX) and `serve.ps1` (Windows) at the repo root that run `hugo server -D` from `site/`. One command from the curriculum's root folder starts the local site. Non-technical users never type `cd site && hugo server -D` directly. Both scripts accept an optional `--port N` flag (default 1313) to support port-collision fallback (R25).
- R21. Every curriculum scaffold includes a `build.sh` / `build.ps1` that runs `hugo --minify` from `site/`, producing `site/public/` for static deployment. The script is idempotent and fails loudly if Hugo is missing.
- R22. `/tmb:create` calls `build.sh` at the end of the pipeline (after the reviewer), then starts the server via platform-appropriate backgrounding:
  - POSIX: `nohup ./serve.sh > /dev/null 2>&1 &` with the PID captured.
  - Windows: `Start-Process ./serve.ps1 -WindowStyle Hidden -PassThru` capturing the returned process object.
  - **Readiness probe**: poll `http://localhost:<port>/` with a 500ms interval until a 200 response or 15-second timeout. Use `curl -fsS` on POSIX, `Invoke-WebRequest -UseBasicParsing` on Windows. On timeout, treat as R25 (fallback path).
  - On port collision (probe gets connection refused immediately and a pre-check shows the port bound), retry on port+1 up to port 1315, then give up and follow R25.
- R23. `/tmb:rebuild-site` always calls `build.sh` after re-scaffolding. The user does not need a separate "now build" step.

**Delivery: URL and folder**
- R24. On successful `/tmb:create`, the skill prints a final delivery block containing:
  (a) The local URL for the running site (e.g., `http://localhost:1313`) — printed as a plain URL; terminals that linkify HTTP will render it clickable automatically.
  (b) BOTH a `file://` URL for the curriculum folder AND a shell command equivalent for the user's platform (`open <path>` on macOS, `xdg-open <path>` on Linux, `explorer <path>` on Windows). The shell command is the reliable fallback for terminals that do not linkify `file://`.
  (c) The command to re-start the server (`./serve.sh`) for later sessions.
  "Clickable" is a nice-to-have, not a success criterion; the requirement is that the user has both a URL and a platform-appropriate command they can use without further instructions.
- R25. If the background server cannot start (port collision, Hugo missing), delivery prints (a) the exact commands to diagnose (`lsof -i :1313` on POSIX, `Get-NetTCPConnection -LocalPort 1313` on Windows), (b) the command to start on a fallback port (`./serve.sh --port 1314`), and (c) still includes the folder path + `open`/`explorer` command from R24(b).

**Interview and placement**
- R18. The save location is **always `<cwd>/<topic-slug>/`** — the curriculum always gets its own subfolder inside the current working directory, never scaffolds directly into the cwd. The skill states this once ("I'll create the curriculum in `<cwd>/<topic-slug>/`. Say otherwise if you want a different parent path.") rather than re-asking. This avoids the footgun of scaffolding into a non-empty cwd and removes the path prompt without creating collision risk. If `<cwd>/<topic-slug>/` already exists and is non-empty, `/tmb:create` refuses with a clear message and a suggested rename.
- R19. The existing 7-step interview is retained. Interview answers feed directly into `curriculum_spine.md`.

## Flow

```
/tmb:create
    │
    ▼
┌──────────────────────────────┐
│ 7-step interview (unchanged) │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────────┐
│ Design phase (single agent)      │
│   writes:                        │
│     curriculum_spine.md          │
│     briefs/NN-slug.yaml  × N     │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Scaffold Hugo site           │
│   (layouts, CSS, archetypes, │
│    hugo.yaml, GH workflow)   │
└──────────────┬───────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ Parallel module builders (N subagents)      │
│   input per agent: spine + own brief        │
│   writes:                                   │
│     site/content/modules/NN/index.md        │
│     modules/NN/exercises/*.md               │
│     modules/NN/VALIDATION.md                │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ Reviewer agent                       │
│   auto-fixes mechanical issues       │
│   flags substantive → user approval  │
│   emits review.md                    │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ build.sh  (hugo --minify)            │
│ serve.sh  (hugo server -D, bg)       │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ Deliver                              │
│   🌐 http://localhost:1313          │
│   📁 file:///.../<curriculum>/      │
│   restart: ./serve.sh               │
└──────────────────────────────────────┘
```

## Success Criteria

- A 7-module curriculum completes in roughly the wall-clock time of building one module sequentially (plus design and review overhead). Parallelism produces a visible speedup the user can feel.
- After `/tmb:create` finishes, zero modules have: missing contrast sections, missing driving questions, frontmatter errors, or failed builds. (Adjacency mismatches and weak driving questions may still be *flagged* in `review.md` for user approval — these are surfaced, not silently absent.)
- `./serve.sh` starts the local site from the curriculum folder in one command.
- Running `/tmb:review` on a hand-edited curriculum surfaces drift (e.g., a term introduced inline but not merged into glossary) and either fixes it or lists it in `review.md`.
- A user who runs `/tmb:create` is not prompted for a path; the curriculum scaffolds into `<cwd>/<topic-slug>/`. If that subfolder already exists and is non-empty, the run aborts with a clear message.
- At the end of `/tmb:create`, the user sees a URL (`http://localhost:1313`), a `file://` path, and a platform-appropriate shell command (`open`, `xdg-open`, or `explorer`) that opens the curriculum folder. The user has everything needed without further instructions, regardless of whether their terminal linkifies either string.
- `/tmb:rebuild-site` finishes with a fresh `site/public/` on disk without the user running any extra commands.
- No deterministic operation in the pipeline is described only in prose — every scaffold, build, serve, and check is an explicit shell command in a script or inline command string.

## Scope Boundaries

- No GitHub Pages deploy automation beyond the existing workflow template. Wiring Pages is still a per-repo user task.
- No automatic migration from v0.2.x curricula (which have `modules/NN/README.md` as canonical). Existing curricula keep working; `/tmb:create` only governs new builds. `/tmb:rebuild-site` is layout-only and does not rewrite content.
- **v0.3 targets Claude Code (local filesystem) only.** The existing skill's claude.ai-chat environment path (remote container, zip delivery via `present_files`) is not supported in v0.3. Rationale: background server + clickable folder link + cwd scaffolding only work against a local filesystem. The claude.ai-chat path is preserved in the v0.2 skill for legacy use; users needing it stay on v0.2.
- Factual-accuracy checking is limited to reading-list URL reachability (R26). Text prose, concept claims, historical dates, and named mechanisms remain the builder's responsibility per `curriculum-design.md` Rule 1. v0.3 explicitly accepts that parallel builders enlarge the accuracy surface area compared to v0.2's single-author flow; the URL HEAD-check in R26 partially compensates but does not close the gap.
- No branching of the curriculum by user skill level or learning mode — one curriculum per interview.
- No per-module preview / approval gate **before** the reviewer runs. If a user wants to hand-edit mid-flow, they interrupt and re-run `/tmb:review` afterwards.

## Key Decisions

- **Hugo single source of truth** — zero duplication, zero sync tooling, zero "which file is canonical?" ambiguity. Users browsing the repo on GitHub see less prose, but the site is the intended consumption surface.
- **Detailed brief + shared spine drives parallelism** — the design phase does the "what goes in each module" thinking up front. Parallel builders only flesh out prose. This is the chosen trade between parallelism and narrative coherence.
- **Spine continuity is explicitly weaker under parallelism.** v0.2's sequential author saw every prior module's realized output; v0.3 builders see only declared intent (`prior_ends_with` / `next_expects` from the brief). The reviewer catches declared-vs-realized mismatches (R12) but cannot prevent them. Named trade: throughput and consistency over narrative tightness. Curricula that need strict running-example continuity should expect a reviewer-driven reconciliation pass at the end of `/tmb:create`.
- **Deterministic operations are explicit shell commands, not prose.** Wherever the skill performs a mechanical step (site scaffold, build, serve, URL check, archetype creation), the step is a named shell command in a script (`scaffold-site.sh`, `build.sh`, `serve.sh`) or an inline command string (`curl -I -sSL --max-time 5 ...`). The skill never says "then create the layout files" — it either runs a script or the exact `hugo` / `cp` / `mkdir` commands. Prose descriptions of deterministic operations are a code smell that hides non-reproducibility.
- **Self-healing reviewer with approval for substantive changes** — mechanical fixes (frontmatter, glossary merge, link normalization, weight reorder) are safe to auto-apply; prose-level fixes (adding a missing contrast section, rewriting a weak driving question) always go through user approval. The full classification is codified in R11 and R12.
- **Glossary is append-only per builder; merged by reviewer.** Avoids concurrent-write races on `glossary.md` while preserving the existing "every new term goes in glossary" rule.
- **Slash commands wrap the skill phases, not replace them** — the skill remains the workflow engine; commands are named entry points into specific phases.
- **Bare `/tmb` prints a pointer, does not redirect.** Existing users typing `/tmb` see a one-line message directing them to `/tmb:create`, `/tmb:review`, `/tmb:add-module`, or `/tmb:rebuild-site`. This preserves backward-compatibility for muscle memory without silently changing behavior.
- **Save location is always `<cwd>/<topic-slug>/`** — the curriculum gets its own subfolder, never scaffolds directly into the cwd. Refuses cleanly if the subfolder already exists.
- **Retain the 7-step interview unchanged** — it is not implicated in the reported problems; changing it is out of scope.
- **v0.3 is Claude Code local-filesystem only.** The claude.ai-chat dual-environment logic in v0.2's SKILL.md Phase 3 is explicitly dropped. Legacy users stay on v0.2. Named so the scope is deliberate.
- **Delivery prints both a URL and a platform-appropriate shell command.** Clickability is opportunistic — the contract is that the user has everything they need without further instructions. No dependency on terminal-specific linkification.

## Dependencies / Assumptions

- Hugo ≥ 0.120 is installed on the user's machine. Already enforced by the existing skill's Step 0 prerequisite check.
- Claude Code supports parallel subagent dispatch (the `Agent` tool). Verified for this plugin environment.
- `curl` is available on POSIX (standard) and PowerShell `Invoke-WebRequest` is available on Windows 10+ (standard). R26 and R22 readiness probes assume these.
- This is a refactor of `skills/tmb`, not a new skill. Bare `/tmb` becomes a pointer message per the Key Decision above.
- Plugin layout convention is NOT assumed — it is a Resolve-Before-Planning question (see Outstanding Questions).

## Outstanding Questions

### Resolve Before Planning

*(none — plugin-layout verification moved to Deferred with explicit "verify first" marker)*

### Deferred to Planning

- [Affects R14–R17, R8, R10][Verify FIRST before any implementation] The plugin-layout convention (`.claude-plugin/commands/<ns>/<name>.md` for slash commands, `.claude-plugin/agents/<name>.md` for custom agents) is assumed but not verified in this repo (`.claude-plugin/` currently only contains `plugin.json`). Every slash command and custom agent depends on this convention holding. **First task of planning: verify against Claude Code plugin docs and an existing reference plugin.** If the convention differs, update R14–R17 and the agent-type deferred question before any other planning work proceeds.
- [Affects R8, R10][Technical] Should the parallel builder and the reviewer be defined as custom agent types (`tmb-module-builder.md`, `tmb-reviewer.md`) or dispatched as generic `Agent` calls with inline system prompts? Decide during planning; affects plugin packaging and reusability. Dependent on the plugin-layout verification above.
- [Affects R15][Technical] When `/tmb:review` runs against a curriculum that lacks `curriculum_spine.md` or per-module briefs (either v0.2.x-era or hand-built), it should error cleanly with a pointer to `/tmb:create`. Exact error text to be written during planning.
- [Affects R12][Technical] The AI-prose violation detector is specified as a heuristic checker flagging for user review, never auto-rewriting. The specific heuristics (throat-clearing openers, fake enthusiasm, consulting-speak, Rules 1–4 from SKILL.md) are defined; the detector implementation — regex pack, LLM secondary pass, or both — is a planning choice. Expected false-positive rate is moderate; the user-approval gate absorbs that cost.
- [Affects R22][Technical] Backgrounding a child process from a Bash-tool call in Claude Code has known edge cases around process reparenting when the tool call returns. Planning should verify that `nohup ... &` on POSIX and `Start-Process` on Windows produce a detached process that survives the parent Bash call.
- [Affects R17, R23][Technical] `scripts/scaffold-site.sh --layouts-only` implies a second mode of the same scaffold script. Planning should decide whether it's one script with modes or two separate scripts (`scaffold-site.sh`, `refresh-layouts.sh`). Subjective; choose whichever is simpler at implementation time.

## Next Steps

-> `/ce:plan` for structured implementation planning
