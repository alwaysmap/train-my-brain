---
title: "refactor: TMB v0.3 — Hugo-first authoring, parallel builders, reviewer agent"
type: refactor
status: active
date: 2026-04-17
origin: docs/brainstorms/tmb-hugo-first-parallel-builders-requirements.md
---

# refactor: TMB v0.3 — Hugo-first authoring, parallel builders, reviewer agent

## Overview

Refactor the `tmb` Claude Code plugin from v0.2 (one skill, sequential build, Hugo as afterthought) to v0.3 (four namespaced command-skills, a design phase that emits structured briefs, parallel module-builder subagents, a self-healing reviewer, and Hugo content as the single source of truth). Ships cross-platform build/serve scripts inside generated curricula and gains a Hugo-install helper so prerequisites are resolved instead of documented.

## Problem Frame

The v0.2 skill builds rich per-module `README.md` files sequentially and then backfits them into Hugo at the end. This causes duplication/drift, slow wall-clock builds, and silent cross-module drift (undefined terms, missing contrast sections, mismatched handoffs). See origin for the full frame.

## Requirements Trace

All requirements carry forward from the origin document. Stable IDs are preserved. A handful of requirements were added or adjusted during planning to reflect research findings — marked **(planning)**.

**Hugo-first content model**
- R1 — Hugo is single source of truth (`site/content/modules/NN-slug/index.md`).
- R2 — `modules/NN-slug/` holds only `exercises/` + `VALIDATION.md`. No per-module `README.md`.
- R3 — Top-level `README.md` is ≤ ~15 lines, pointing to the site.
- R4 — Hugo scaffold via explicit `scripts/scaffold-site.sh`.
- R5 — Authoring via `hugo new content/modules/NN-slug/index.md`; `archetypes/modules.md` extended with new fields.

**Parallel module building**
- R6 — Per-module brief at `briefs/NN-slug.yaml` with fixed schema including TODO-hook format.
- R6a — Brief completeness gate pre-dispatch.
- R7 — Shared `curriculum_spine.md`.
- R7a — Glossary append-only via per-builder `new_terms.yaml`; reviewer merges.
- R8 — Parallel subagent dispatch.
- R8a — Builder failure semantics (continue + flag).
- R9 — Builders may not invent scope.

**Reviewer agent**
- R10 — Reviewer auto-runs after builders; emits `review.md`.
- R11 — Mechanical auto-fix list (codified).
- R12 — Substantive flag list (codified), requires user approval.
- R13 — Reviewer re-runnable via `/tmb:review`.
- R26 — URL reachability HEAD-check.

**Slash command surface (corrected during planning)**
- R14 — `/tmb:create` as `skills/create/SKILL.md`.
- R15 — `/tmb:review` as `skills/review/SKILL.md`.
- R16 — `/tmb:add-module` as `skills/add-module/SKILL.md`.
- R17 — `/tmb:rebuild-site` as `skills/rebuild-site/SKILL.md`.
- R27 **(planning)** — `/tmb:help` as `skills/help/SKILL.md` replaces the origin's "bare `/tmb` pointer" (Claude Code does not invoke bare plugin names — commands need a skill name after the colon).

**Build and serve scripts**
- R20 — `serve.sh` / `serve.ps1` at curriculum root.
- R21 — `build.sh` / `build.ps1` at curriculum root.
- R22 **(revised during planning)** — `/tmb:create` calls `build.sh`, then attempts to start the server via tmux if available; otherwise prints the exact `./serve.sh` command for the user to run in another terminal and skips the readiness probe. Origin's `nohup &` / `Start-Process` detachment model does not work under Claude Code's `Bash` tool (`--die-with-parent`).
- R23 — `/tmb:rebuild-site` always calls `build.sh`.

**Delivery**
- R24 — Prints URL + `file://` + platform-appropriate `open`/`xdg-open`/`explorer` command.
- R25 — Port-collision fallback to 1314/1315; prints diagnostic commands.

**Interview and placement**
- R18 — Scaffolds into `<cwd>/<topic-slug>/`; refuses if that subfolder exists non-empty.
- R19 — 7-step interview retained unchanged.

**New requirements from research**
- R28 **(planning, from user message)** — Hugo-install helper. If `hugo version` is missing or below 0.120, detect platform + package manager, offer one-line install (`brew install hugo-extended` / `winget install Hugo.Hugo.Extended` / `snap install hugo --classic`). On user decline or no package manager, print the release URL (https://github.com/gohugoio/hugo/releases/tag/v0.160.1) and abort.
- R29 **(planning)** — Interview → spine field mapping is explicit. Step 1 goal → `goal`; Step 2 tested-via → `tested_via`; Step 3 → `audience_starting_point`; Step 4 → `depth_vs_breadth`; Step 5 → `validation_preferences`; Step 6 → `timeline`, `tools_present`; Step 7 → `hue`. Module count `N` is decided by the designer from timeline × depth_vs_breadth (5–9 typical, default 7).
- R30 **(planning)** — Running-example sourcing. Designer synthesizes a concrete running example from Step 1 (goal) + Step 3 (starting point). If the user mentioned a specific project or domain, use that; otherwise the designer proposes one and records it in the spine.
- R31 **(planning)** — Reviewer approval UX. `review.md` lists substantive issues as numbered items with an `approved: <null|true|false>` field per item. User approves inline by editing the field or via a follow-up prompt; the reviewer's fix pass only touches issues whose `approved: true`. Unapproved issues persist in `review.md` across re-runs.
- R32 **(planning)** — Glossary merge conflict rule. Duplicate term with identical definition: keep one. Duplicate term with divergent definitions: flag as substantive (R12 — "glossary definition conflict"), do not auto-merge.
- R33 **(planning)** — `/tmb:create` resume path. If scaffold exists and some builders succeeded (detected by frontmatter presence in `site/content/modules/NN-slug/index.md`), the command offers `--resume` to skip completed modules; otherwise refuses per R18. No force-overwrite; users delete manually.
- R34 **(planning)** — `/tmb:review` drift direction. Briefs are ground truth for brief-frontmatter adjacency fields (`driving_question`, `concepts`, `contrast`, `prior_ends_with`, `next_expects`). Hugo content prose is ground truth for everything else. The reviewer flags frontmatter drift against the brief as substantive; flags prose-vs-brief content disagreement as substantive only when the prose contradicts the brief's constraints (e.g., exercise_goal).
- R35 **(planning)** — `/tmb:add-module` insert-at-position-K. Insertion shifts weights of K..N by +1 (mechanical, R11), rewrites `prior_ends_with` on K and `next_expects` on K-1 to match the new neighbor, and runs the reviewer on modules K-1, K, K+1. Users are warned that shifted-weight modules may need handoff edits.
- R36 **(planning)** — Server stop/restart. `serve.sh` writes its PID to `.hugo.pid` at curriculum root on start; a new `stop.sh` / `stop.ps1` reads the PID and kills the process. Both added to delivery output in R24(c).
- R37 **(planning)** — Reviewer crash containment. If the reviewer agent errors out during `/tmb:create`, the orchestrator still calls `build.sh` and delivery proceeds with a note "review failed — re-run `/tmb:review` manually". Builder outputs are never discarded because of reviewer failure.

## Scope Boundaries

- No GitHub Pages deploy automation beyond the existing workflow template.
- No automatic migration from v0.2.x curricula. `/tmb:rebuild-site` on a v0.2.x curriculum errors with a pointer to manual migration.
- Reviewer does not check factual accuracy of prose claims (only URL reachability per R26).
- No curriculum branching by skill level.
- No per-module approval gate before the reviewer runs.
- **v0.3 targets Claude Code local-filesystem only.** The v0.2 claude.ai-chat path (remote container + zip delivery) is dropped. Legacy users stay on v0.2.

### Deferred to Separate Tasks

- **Inline approval UI for reviewer flags** — R31 uses file-based approval (edit `review.md` → re-run). A richer inline-prompt flow (AskUserQuestion for each flag) is a future iteration.
- **`skills/help/SKILL.md` enrichment** — initial implementation is a static text skill. A dynamic version that reads the plugin's own commands and lists them is a later improvement.
- **Hugo-extended version enforcement** — the helper installs `hugo-extended` where possible, but does not verify the binary reports as `extended` post-install. Add a stricter check later.

## Context & Research

### Relevant Code and Patterns

- `skills/tmb/SKILL.md` — current workflow phases (interview, location, design, sequential build, deliver). Full rewrite required; repurpose elicitation logic into the `/tmb:create` orchestrator.
- `skills/tmb/references/elicitation.md` — 7-step interview kept verbatim. Move to a shared reference location (`references/elicitation.md` or `skills/create/references/elicitation.md`).
- `skills/tmb/references/hugo-site.md` lines 169–332 — Hugo `hugo.yaml`, archetype, layouts, CSS. Source material for embedded templates in `scripts/scaffold-site.sh`.
- `skills/tmb/references/curriculum-design.md` — pedagogy rules feed brief schema fields (contrast, driving question, tiered knowledge model).
- `skills/tmb/references/markdown-gotchas.md` — consumed by module-builder and reviewer agents.
- `.claude-plugin/plugin.json` — minimal manifest; will bump to v0.3.0.
- `scripts/build.js` lines 61–66 — `includes` list must add `commands/` (for legacy-flat-form commands if used) and `agents/`.
- `.github/workflows/release.yml` — mirrors the includes list; must update in lockstep with `scripts/build.js`.
- `scripts/release.js` — unchanged; reads version from argv and updates both JSONs.

### Institutional Learnings

- `docs/solutions/` does not exist in this repo. No prior-solution constraints apply. `/ce:compound` after v0.3 lands to capture the plugin-layout verification, tmux-workaround, and parallel-dispatch-cap findings for future plugin work.

### External References

- https://code.claude.com/docs/en/plugins — component-path overrides, directory conventions
- https://code.claude.com/docs/en/skills — skill frontmatter, namespacing (`/<plugin>:<skill>`)
- https://code.claude.com/docs/en/sub-agents — agent frontmatter, tool lists, allowed-tools, isolation
- https://github.com/anthropics/claude-code/issues/11716 — known `run_in_background` token-exhaustion bug
- https://github.com/gohugoio/hugo/releases/tag/v0.160.1 — target Hugo version for install helper
- Claude Code `Bash` tool uses `--die-with-parent`; `nohup` / `&` / `disown` / `setsid` all fail. tmux is the documented workaround (community + docs).

## Key Technical Decisions

- **Slash commands are implemented as skills at plugin root** (`skills/<name>/SKILL.md`), not `commands/<name>.md` legacy form. This matches Claude Code's Q1 2026 merged skills-and-commands model and avoids duplicating surface trees.

  *Corrects:* origin doc's assumption of `.claude-plugin/commands/<ns>/<name>.md`.

- **Three custom agents at `agents/` plugin root:** `tmb-designer` (interview → spine + briefs), `tmb-module-builder` (parallel-dispatched per module), `tmb-reviewer` (post-build consistency pass). All three are declared at plugin root per Claude Code convention.

  *Origin had:* two agents (builder + reviewer). Planning splits out the designer explicitly because the flow analysis surfaced it as an unnamed agent doing load-bearing work.

- **Background `hugo server` uses tmux-if-available, else user-run.** `Bash run_in_background` cannot produce a detached process that survives the parent Bash call. Pragmatic fallback matches R22's revised wording: if `command -v tmux` succeeds, the orchestrator runs `tmux new-session -d -s tmb-<slug> ./serve.sh`; otherwise it prints the command and skips the readiness probe. The clickable URL + folder link still work either way.

- **Existing `skills/tmb/` directory is deleted.** Its content is split across the new skills (create/review/add-module/rebuild-site/help) and agent definitions. `skills/tmb/SKILL.md` would be invoked as `/tmb:tmb` under the plugin-name prefix, which is awkward; the `help` skill replaces it.

- **References are shared from a plugin-root `references/` directory.** `elicitation.md`, `curriculum-design.md`, `markdown-gotchas.md`, `hugo-site.md` move to `references/` so all skills and agents can cite them by relative path. Avoids per-skill duplication.

- **Hugo templates move from a reference file into an embedded script.** `scripts/scaffold-site.sh` embeds the layouts / CSS / archetype / `hugo.yaml` template via heredocs, parameterized by `--title`, `--hue`, `--description`, `--author`. This makes R4 "every step is a deterministic shell command" literally true.

- **Agents get a narrow tool allowlist.** `tmb-module-builder` gets `Write`, `Read`, and nothing else — no `Bash` (no arbitrary shell), no `Agent` (no further dispatch). `tmb-reviewer` gets `Read`, `Write`, `Edit`, `Bash` (for `curl`/`tmux`/`hugo`), and `Grep`/`Glob`. `tmb-designer` gets `Read`, `Write`. This minimizes blast radius under parallel dispatch.

- **Plugin manifest adds explicit component-path declarations.** `plugin.json` gets `"commands": "./commands"`, `"agents": "./agents"`, `"skills": "./skills"` to make discovery explicit and build-pipeline reviewable. Not strictly required (convention-based discovery works) but it documents the plugin's surface in one place.

## Open Questions

### Resolved During Planning

- **Plugin layout convention** — commands/agents at plugin root, not under `.claude-plugin/`. (Research verified against Claude Code plugin docs.)
- **Custom-agent-type vs inline Agent prompts** — custom types. `agents/tmb-*.md` at plugin root. Cleaner reuse and narrower tool scope than inline prompts.
- **`/tmb:review` on pre-brief curricula** — errors cleanly with a pointer. Implementation in Unit 7.
- **Mechanical vs substantive classification** — codified in R11/R12 of the origin; Unit 5 implements the rules table in the reviewer agent prompt.
- **Parallel dispatch cap** — 10 concurrent (community-reported). Acceptable for 5–9 module curricula. Unit 6 batches if N > 10.
- **Module count N** — designer-decided per R29.
- **Running example** — designer-synthesized per R30.
- **Reviewer approval UX** — file-based approval via `review.md` editing per R31.
- **Glossary conflict rule** — flag as substantive per R32.
- **`/tmb:create` resume** — detect partial progress; offer `--resume` per R33.
- **Drift direction for `/tmb:review`** — brief is ground truth for frontmatter; prose for content per R34.
- **`/tmb:add-module` insert-at-K** — mechanical weight shift + re-review neighbors per R35.
- **Server stop** — PID file + `stop.sh` per R36.
- **Reviewer crash containment** — build and deliver anyway per R37.

### Deferred to Implementation

- Exact `tmux` session lifecycle (detach-on-exit behavior, cleanup when the user manually kills the session) — decide while writing `serve.sh`.
- Exact `curl -f` vs `curl -I -sSL` wording in the URL-check helper — may differ on Windows PowerShell vs POSIX; decide during Unit 5.
- Final mechanical-fix ordering in the reviewer pass (frontmatter fixes before glossary merge, or parallel?) — shake out during Unit 5 implementation.
- Whether `scripts/scaffold-site.sh` should support a dry-run flag for testing — add if useful during Unit 11.
- Specific AI-prose heuristic regex pack — tune during Unit 5 against real outputs.

## Output Structure

```
<plugin-root>/
├── .claude-plugin/
│   └── plugin.json                    # bumped to 0.3.0; adds commands/agents/skills paths
├── agents/                            # NEW
│   ├── tmb-designer.md
│   ├── tmb-module-builder.md
│   └── tmb-reviewer.md
├── skills/                            # RESTRUCTURED — skills/tmb/ deleted
│   ├── create/
│   │   └── SKILL.md                   # /tmb:create orchestrator
│   ├── review/
│   │   └── SKILL.md                   # /tmb:review
│   ├── add-module/
│   │   └── SKILL.md                   # /tmb:add-module
│   ├── rebuild-site/
│   │   └── SKILL.md                   # /tmb:rebuild-site
│   └── help/
│       └── SKILL.md                   # /tmb:help (list of commands)
├── references/                        # NEW — shared by all skills & agents
│   ├── elicitation.md                 # moved from skills/tmb/references/
│   ├── curriculum-design.md           # moved
│   ├── markdown-gotchas.md            # moved
│   ├── hugo-site.md                   # rewritten (prose only; templates now in scripts/)
│   ├── brief-schema.md                # NEW — briefs/NN-slug.yaml schema + example
│   ├── spine-schema.md                # NEW — curriculum_spine.md schema
│   └── reviewer-policy.md             # NEW — mechanical vs substantive table
├── scripts/                           # plugin-level build tooling; UNCHANGED in purpose
│   ├── build.js                       # updated includes list
│   ├── release.js                     # unchanged
│   └── scaffold-site.sh               # NEW — shipped INTO curricula via the skill
├── curriculum-templates/              # NEW — files copied verbatim into each curriculum
│   ├── serve.sh
│   ├── serve.ps1
│   ├── build.sh
│   ├── build.ps1
│   ├── stop.sh
│   ├── stop.ps1
│   └── .gitignore
├── .github/workflows/release.yml      # includes list updated
├── README.md                          # updated to list /tmb:create, /tmb:review, etc.
├── RELEASING.md                       # unchanged
├── package.json                       # bumped to 0.3.0
├── LICENSE                            # unchanged
└── CHANGELOG.md                       # NEW (or appended) — v0.3 notes
```

Each generated curriculum looks like:

```
<cwd>/<topic-slug>/
├── README.md                          # ≤ 15 lines, points to site
├── curriculum_spine.md
├── briefs/
│   └── NN-slug.yaml                   # one per module
├── glossary.md                        # written by reviewer
├── modules/
│   └── NN-slug/
│       ├── exercises/*.md
│       ├── VALIDATION.md
│       └── new_terms.yaml             # written by builder; consumed by reviewer
├── review.md                          # written by reviewer
├── serve.sh / serve.ps1
├── build.sh / build.ps1
├── stop.sh / stop.ps1
├── .hugo.pid                          # written at serve time
├── .gitignore
└── site/                              # Hugo scaffold
    ├── archetypes/modules.md
    ├── assets/css/site.css
    ├── content/modules/NN-slug/index.md
    ├── layouts/{baseof,index,page,section}.html
    ├── layouts/partials/nav.html
    ├── hugo.yaml
    └── public/                        # after build.sh runs
```

## High-Level Technical Design

> *This illustrates the intended pipeline and directional agent contracts for review. It is not implementation specification; the implementing agent should treat it as context, not code to reproduce.*

**Pipeline flow for `/tmb:create`:**

```
skills/create/SKILL.md (orchestrator)
   │
   1. scripts/check-hugo.sh → install-if-missing helper (R28)
   │
   2. Read references/elicitation.md → run 7-step interview (R19)
   │      produces: structured answers hash
   │
   3. Refuse if <cwd>/<slug>/ exists non-empty (R18, R33 detects resume case)
   │
   4. Agent(tmb-designer, { interview_answers, slug }) → writes
   │      curriculum_spine.md
   │      briefs/NN-slug.yaml × N
   │      runs brief-completeness gate (R6a)
   │
   5. scripts/scaffold-site.sh --title X --hue Y --desc Z → writes
   │      site/{archetypes,assets,content,layouts,hugo.yaml}
   │      .github/workflows/deploy.yml
   │      .gitignore
   │      curriculum-templates/*  → root-level serve/build/stop scripts
   │
   6. Parallel Agent dispatch (batched at 10):
   │      for each brief:
   │         Agent(tmb-module-builder, { brief_path, spine_path })
   │         writes: site/content/modules/NN/index.md
   │                 modules/NN/exercises/*.md
   │                 modules/NN/VALIDATION.md
   │                 modules/NN/new_terms.yaml
   │      R8a: failed builders listed but do not abort
   │
   7. Agent(tmb-reviewer) → mechanical pass + substantive pass → writes
   │      glossary.md (merged from new_terms.yaml files, R7a)
   │      review.md (flags, R12)
   │      R37: failure still proceeds to step 8
   │
   8. ./build.sh → hugo --minify → site/public/
   │
   9. tmux-or-user serve start → http://localhost:1313
   │
   10. Delivery block:
         🌐 http://localhost:1313
         📁 file://<cwd>/<slug>/    and    open <cwd>/<slug>/
         ↻ ./serve.sh               ✖ ./stop.sh
```

**Agent contract sketches (directional):**

```
agents/tmb-designer.md
  INPUT:  interview_answers (7 fields), slug
  READS:  references/elicitation.md, curriculum-design.md, spine-schema.md, brief-schema.md
  WRITES: curriculum_spine.md, briefs/NN-slug.yaml × N
  GATE:   every brief passes the completeness check or the agent errors with a list
```

```
agents/tmb-module-builder.md
  INPUT:  brief_path, spine_path
  READS:  the brief, the spine, references/curriculum-design.md, markdown-gotchas.md
  WRITES: site/content/modules/<slug>/index.md
          modules/<slug>/exercises/*.md
          modules/<slug>/VALIDATION.md
          modules/<slug>/new_terms.yaml
  TOOLS:  Read, Write  (no Bash, no Agent — narrow blast radius)
```

```
agents/tmb-reviewer.md
  INPUT:  curriculum root path
  READS:  all briefs, all new_terms.yaml, all site/content/modules/*/index.md,
          all modules/*/VALIDATION.md, references/reviewer-policy.md
  WRITES: glossary.md (merged), review.md (flag list with approved: null),
          edits to frontmatter / link format / weight ordering (mechanical only)
  TOOLS:  Read, Write, Edit, Bash (curl for R26 URL check), Grep, Glob
```

## Implementation Units

- [ ] **Unit 1: Plugin surface layout correction and v0.3.0 bump**

**Goal:** Correct the plugin-layout conventions flagged in the origin doc (commands/agents at plugin root, not inside `.claude-plugin/`); bump version; extend the build pipeline to package new directories.

**Requirements:** R14–R17 (corrected), R27 (planning).

**Dependencies:** None.

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `package.json`
- Modify: `scripts/build.js`
- Modify: `.github/workflows/release.yml`
- Modify: `README.md`
- Create: `CHANGELOG.md`
- Create: `agents/.gitkeep`, `commands/.gitkeep` (reserve directories; `commands/` reserved for potential future legacy-form commands)

**Approach:**
- Bump `version` in both JSON files to `0.3.0`.
- Add explicit `commands: "./commands"`, `agents: "./agents"`, `skills: "./skills"` to `plugin.json`.
- Extend `scripts/build.js` `includes` array to add `agents/`, `references/`, `curriculum-templates/`, `commands/` (even if empty at first).
- Mirror the same change in `.github/workflows/release.yml`.
- Rewrite `README.md` to list the four new slash commands and delete the obsolete `/tmb` command row.
- `CHANGELOG.md` captures the v0.3 breaking changes for users.

**Patterns to follow:**
- `scripts/release.js` already handles version bumps; Unit 1 only touches the plugin-surface config.

**Test scenarios:**
- Happy path: `npm run build` produces `train-my-brain.zip` containing `agents/`, `skills/`, `references/`, `curriculum-templates/` and `plugin.json` with `version: "0.3.0"`.
- Happy path: `.github/workflows/release.yml` inline zip includes match `scripts/build.js` includes exactly (lint check: diff the arrays).
- Edge case: `plugin.json` validates against Claude Code plugin schema (manual review against plugin docs).

**Verification:**
- `unzip -l train-my-brain.zip` shows all expected directories at root.
- `cat .claude-plugin/plugin.json | jq .version` returns `"0.3.0"`.

---

- [ ] **Unit 2: Shared references and data schemas**

**Goal:** Move existing references to a plugin-root `references/` directory and add new schema documents for briefs, spine, and the reviewer policy. Extend the Hugo archetype frontmatter.

**Requirements:** R5 (archetype extension), R6, R7, R7a, R11, R12, R26, R29, R31, R32, R34.

**Dependencies:** Unit 1.

**Files:**
- Move: `skills/tmb/references/elicitation.md` → `references/elicitation.md`
- Move: `skills/tmb/references/curriculum-design.md` → `references/curriculum-design.md`
- Move: `skills/tmb/references/markdown-gotchas.md` → `references/markdown-gotchas.md`
- Rewrite: `skills/tmb/references/hugo-site.md` → `references/hugo-site.md` (prose-only; template bodies move into `scripts/scaffold-site.sh` in Unit 11)
- Create: `references/brief-schema.md`
- Create: `references/spine-schema.md`
- Create: `references/reviewer-policy.md`
- Modify: The archetype definition (to be embedded in `scripts/scaffold-site.sh`, Unit 11) — add frontmatter fields `driving_question`, `concepts`, `contrast`, `prior_ends_with`, `next_expects`, `topics`, `blog_post`, and carry existing `title`, `weight`, `status`, `summary`, `date`, `draft`.

**Approach:**
- `brief-schema.md` documents the YAML schema in R6 with an example; used by the designer and module-builder.
- `spine-schema.md` documents the spine file schema (R7 fields) + the R29 interview mapping table.
- `reviewer-policy.md` is the rules table from R11/R12 expanded with edge cases (R31 approval UX, R32 glossary conflict, R34 drift direction).
- `hugo-site.md` keeps installation + HOW-TO-VIEW-SITE.md template + "how Hugo works in this project" prose but removes the inline HTML/CSS/archetype blocks (now owned by Unit 11's scaffold script).

**Patterns to follow:**
- Existing reference file voice and structure (short sentences, plain language, cite specific line numbers where relevant).

**Test scenarios:**
- Happy path: `references/brief-schema.md` contains a YAML example that the module-builder agent can read and interpret.
- Edge case: `references/spine-schema.md` covers all 7 interview answers → spine fields with no orphans.
- Integration: moved reference files are reachable by relative path from every skill and agent that cites them (manual lint).

**Verification:**
- `ls references/` shows all seven reference files.
- `skills/tmb/references/` no longer exists after the move.

---

- [ ] **Unit 3: `agents/tmb-designer.md`**

**Goal:** Define the designer agent that consumes the 7 interview answers, writes `curriculum_spine.md`, synthesizes `briefs/NN-slug.yaml` × N, and runs the completeness gate before returning.

**Requirements:** R6, R6a, R7, R9, R29, R30.

**Dependencies:** Unit 2.

**Files:**
- Create: `agents/tmb-designer.md`

**Approach:**
- Frontmatter: `name: tmb-designer`, `description:`, `tools: [Read, Write]`, narrow scope.
- System prompt authors the spine using R29's mapping table and decides N per R29 (5–9, default 7).
- System prompt synthesizes running example per R30.
- Generates one brief per module with R6's full schema.
- Runs completeness gate (R6a): if any brief field is null/empty/TBD, return an error listing gaps rather than writing files.
- System prompt pulls from `references/curriculum-design.md` for concept/contrast/reading-list expectations.

**Patterns to follow:**
- `compound-engineering` agent frontmatter style (see `.claude/plugins/cache/every-marketplace/compound-engineering/.../agents/*.md`).

**Test scenarios:**
- Happy path: given plausible interview answers, returns spine + 7 briefs, each with all R6 fields populated.
- Edge case: interview answer Step 6 says "a few weeks" + Step 4 = "deep dives" → N=5; Step 6 "a few months" + "wide map" → N=9.
- Error path: if the agent cannot synthesize a running example (Step 1 too vague), it writes a placeholder spine and errors with a request for clarification.
- Integration: designer output is consumed unmodified by a module-builder dispatch in a subsequent unit; no translation layer needed.

**Verification:**
- Manual: run designer against a canned interview transcript and inspect the spine + briefs for R6/R7 conformance.

---

- [ ] **Unit 4: `agents/tmb-module-builder.md`**

**Goal:** Define the per-module builder agent that reads spine + brief and writes the three module files plus `new_terms.yaml`.

**Requirements:** R6, R8, R8a, R9, R7a (write side).

**Dependencies:** Unit 2, Unit 3.

**Files:**
- Create: `agents/tmb-module-builder.md`

**Approach:**
- Frontmatter: `name: tmb-module-builder`, `tools: [Read, Write]`.
- System prompt: read brief at `$BRIEF_PATH`, read `curriculum_spine.md`, read `references/curriculum-design.md` and `references/markdown-gotchas.md`.
- Write `site/content/modules/<slug>/index.md` with frontmatter copied verbatim from the brief (R6 last sentence) plus authored prose.
- Write `modules/<slug>/exercises/*.md` with TODO hooks per the brief's `exercise_goal`.
- Write `modules/<slug>/VALIDATION.md` per the brief's `validation_scenario` + curriculum-design.md's "good answer covers" template.
- Write `modules/<slug>/new_terms.yaml` with any new terms introduced + inline definitions (per R7a — NEVER write `glossary.md`).
- On any scope-inventing situation (R9), flag in prose and halt without guessing.

**Patterns to follow:**
- v0.2 `skills/tmb/SKILL.md` Phase 3 Tier 3 describes what a good module looks like; inline that voice into the builder system prompt.

**Test scenarios:**
- Happy path: builder receives a well-formed brief, produces one `index.md` with full frontmatter, one exercise with at least two `[TODO:]` markers, one VALIDATION.md with a scenario + "good answer covers" block, and a `new_terms.yaml` listing any new terms.
- Edge case: brief lists 3 concepts, builder does not introduce any new ones → `new_terms.yaml` is empty/omitted.
- Error path: brief is malformed (schema fail) → builder returns an error without touching the filesystem.
- Integration: parallel dispatch of 7 builders against one spine produces 7 non-colliding module trees (no shared file writes except each builder's own outputs).

**Verification:**
- Manual: dispatch the builder solo against a known brief + spine pair; diff the output against expected file list.
- Manual: dispatch 3 builders in parallel and verify no file collisions.

---

- [ ] **Unit 5: `agents/tmb-reviewer.md`**

**Goal:** Define the reviewer agent that runs after builders, performs mechanical auto-fixes, flags substantive issues for user approval, merges glossary terms, runs URL HEAD checks, and emits `review.md`.

**Requirements:** R10, R11, R12, R13, R26, R31, R32, R34, R37.

**Dependencies:** Unit 2.

**Files:**
- Create: `agents/tmb-reviewer.md`

**Approach:**
- Frontmatter: `name: tmb-reviewer`, `tools: [Read, Write, Edit, Bash, Grep, Glob]`.
- System prompt reads `references/reviewer-policy.md` as its authoritative rules table.
- Mechanical pass (R11): frontmatter fix, weight reorder, link normalization, glossary merge from `new_terms.yaml` files (R7a). Glossary conflicts (R32) are NOT auto-merged — they become substantive flags.
- URL check (R26): `curl -I -sSL --max-time 5 -o /dev/null -w "%{http_code}" <URL>` per reading-list URL; non-2xx → substantive flag.
- Substantive pass (R12): emits `review.md` with numbered flags + `approved: null` per item. Does NOT apply substantive fixes — that happens on a re-run after the user edits approvals (R31).
- On re-run: reads `review.md`, applies approved fixes, updates flag state, rewrites `review.md`.
- Drift direction per R34: brief = truth for adjacency frontmatter; prose = truth for content unless it contradicts brief constraints.

**Patterns to follow:**
- `compound-engineering:review:*` persona agent structure (narrow scope, structured output).

**Test scenarios:**
- Happy path: 7-module curriculum with no issues → `review.md` contains "All mechanical fixes: 0. All substantive flags: 0."
- Mechanical: two modules collide on `weight: 3` → reviewer auto-reorders, logs fix in `review.md`.
- Mechanical: `new_terms.yaml` from 3 modules all define "API" with identical text → merged into glossary once.
- Substantive: module 3's `next_expects` doesn't match module 4's `prior_ends_with` → flag with `approved: null`.
- Substantive: reading URL returns 404 → flag.
- Substantive-conflict: two modules define "tephra" differently → flag, glossary stays un-merged for that term.
- Re-run: user sets `approved: true` on an adjacency-mismatch flag → reviewer rewrites both module files' frontmatter to align.
- Error path (R37): reviewer crashes mid-run → orchestrator still calls `build.sh`; `review.md` says "partial review, re-run /tmb:review".
- Integration: URL check survives one unreachable URL (timeout) without halting the full pass.

**Verification:**
- Manual: feed the reviewer a curriculum with known issues (hand-planted) and verify every class of issue is either auto-fixed or flagged with the right classification.

---

- [ ] **Unit 6: `skills/create/SKILL.md` — `/tmb:create` orchestrator**

**Goal:** Implement the full pipeline orchestrator skill: Hugo prereq, interview, location check, designer dispatch, scaffold, parallel builder dispatch, reviewer, build, serve, deliver.

**Requirements:** R14, R18, R19, R22 (revised), R24, R25, R28, R33, R37.

**Dependencies:** Units 2, 3, 4, 5, 10, 11 (scaffold script), 13 (templates).

**Files:**
- Create: `skills/create/SKILL.md`
- Create: `skills/create/references/` (optional — may just cite plugin-root `references/`)

**Approach:**
- Frontmatter: `name: create`, `description:`, `when_to_use:`, `allowed-tools: [Read, Write, Bash, Agent]`.
- Flow: check Hugo (invoke Unit 12 helper) → run interview from `references/elicitation.md` → compute `<cwd>/<slug>/` → refuse or resume per R18/R33 → dispatch `tmb-designer` → run `scripts/scaffold-site.sh` → parallel-dispatch `tmb-module-builder` per brief (batched at 10) → dispatch `tmb-reviewer` → run `./build.sh` → tmux-or-user server start (R22) → print delivery block (R24/R25).
- `disable-model-invocation: false` so the user can invoke directly.
- Structure the body as phases with clear announce/STOP patterns lifted from v0.2's Phase 1 discipline.

**Patterns to follow:**
- v0.2 `skills/tmb/SKILL.md` phase/quality-gate structure (adapted for parallel dispatch).

**Test scenarios:**
- Happy path: fresh cwd → full 7-module curriculum in the subfolder, site running.
- Edge case: Hugo missing → Unit 12 helper runs install flow → pipeline resumes.
- Edge case: `<cwd>/<slug>/` exists and empty → proceed.
- Edge case: `<cwd>/<slug>/` exists with partial modules → offer `--resume`; only dispatch builders for missing modules.
- Error path: designer fails completeness gate → skill aborts with the gate's error list, no scaffold written.
- Error path: reviewer crashes → build + deliver continue with "review failed" note (R37).
- Integration: tmux available → server starts in detached session; tmux missing → delivery prints the command and skips readiness probe.

**Verification:**
- Manual end-to-end: run `/tmb:create` against a simple topic ("Learn basic SQL"), confirm full deliverable.

**Execution note:** Incremental — implement the orchestrator skeleton first, wire in each sub-agent as its unit lands. Blocks on Units 3/4/5/10/11/12/13.

---

- [ ] **Unit 7: `skills/review/SKILL.md` — `/tmb:review`**

**Goal:** Standalone reviewer invocation for hand-edited curricula.

**Requirements:** R13, R15, R31, R34.

**Dependencies:** Unit 5.

**Files:**
- Create: `skills/review/SKILL.md`

**Approach:**
- Frontmatter: `name: review`, `allowed-tools: [Bash, Agent]`.
- Precondition: `curriculum_spine.md` and `briefs/` must exist at cwd. If missing → error with "this is not a TMB curriculum, or it was built with v0.2 — run `/tmb:create` or follow migration notes."
- Dispatch `tmb-reviewer` against cwd.
- Report written findings from `review.md`.

**Test scenarios:**
- Happy path: clean curriculum → "no issues" message.
- Edge case: spine + briefs present but stale → reviewer flags drift per R34.
- Error path: cwd has no spine → clean error per R15.

**Verification:** Run against a curriculum produced by Unit 6 then hand-edit one module's prose to contradict the brief; confirm reviewer flags it.

---

- [ ] **Unit 8: `skills/add-module/SKILL.md` — `/tmb:add-module`**

**Goal:** Add a module to an existing curriculum; support append (default) and insert-at-K.

**Requirements:** R16, R35.

**Dependencies:** Units 3, 4, 5, 11.

**Files:**
- Create: `skills/add-module/SKILL.md`

**Approach:**
- Prompt user for `weight` (default = N+1, append), `title`, `driving_question`, `contrast` target.
- If weight ≤ existing max: insert-at-K flow (R35) — designer regenerates briefs K..N with shifted weights; orchestrator writes the new brief first.
- Dispatch single `tmb-module-builder` for the new module.
- Run `tmb-reviewer` scoped to K-1, K, K+1 for append case, or the full shifted range for insert-at-K.
- Re-run `./build.sh` after success.

**Test scenarios:**
- Happy path (append): existing 7-module curriculum → `/tmb:add-module` at weight 8 → new brief written, one builder, reviewer on 7+8, build succeeds.
- Insert-at-K: existing 7-module curriculum → `/tmb:add-module` at weight 3 → modules 3–7 shift to 4–8, new brief at 3, builder runs, reviewer on 2/3/4/5/6/7/8.
- Error path: insert-at-K with brief gaps (e.g., missing prior_ends_with rewrite) → pipeline halts with designer error.

**Verification:** Run append against a small curriculum; then run insert-at-K and confirm weights shift cleanly.

---

- [ ] **Unit 9: `skills/rebuild-site/SKILL.md` — `/tmb:rebuild-site`**

**Goal:** Refresh Hugo scaffold (layouts/CSS/config) without touching content, then rebuild static output.

**Requirements:** R17, R23.

**Dependencies:** Unit 11.

**Files:**
- Create: `skills/rebuild-site/SKILL.md`

**Approach:**
- Precondition: `site/` exists. If not, error.
- Refuse with pointer message if `modules/*/README.md` detected (v0.2.x curriculum).
- Invoke `scripts/scaffold-site.sh --layouts-only` (writes `site/layouts/`, `site/assets/css/`, `site/archetypes/`, `site/hugo.yaml` only; leaves `site/content/` untouched).
- Run `./build.sh`.
- Optionally (ask user) start `./serve.sh`.

**Test scenarios:**
- Happy path: v0.3 curriculum with outdated layouts → `/tmb:rebuild-site` → new layouts + fresh `public/`.
- Edge case: `site/content/` is missing → builds empty site; that's user-visible and correct.
- Error path: v0.2.x curriculum (has `modules/NN/README.md`) → refuses with migration pointer.
- Error path: `site/` missing entirely → clean error.

**Verification:** After any change to the skill's layout files, `/tmb:rebuild-site` on an older curriculum brings it current.

---

- [ ] **Unit 10: `skills/help/SKILL.md` — `/tmb:help`**

**Goal:** Replace the origin doc's bare-`/tmb` pointer (which can't be implemented under Claude Code's namespacing) with a `/tmb:help` skill listing all commands.

**Requirements:** R27.

**Dependencies:** None.

**Files:**
- Create: `skills/help/SKILL.md`

**Approach:**
- Static content listing the four operational commands plus `/tmb:help` itself, each with a one-line description and example invocation.
- No agent dispatch, no tool calls beyond trivial reads.

**Test scenarios:**
- Happy path: `/tmb:help` prints the command menu.
- Test expectation: none — pure text skill, no behavioral surface beyond rendering.

**Verification:** Invoke in a fresh session and confirm output.

---

- [ ] **Unit 11: `scripts/scaffold-site.sh`**

**Goal:** Deterministic, parameterized Hugo site scaffolder. Supports a default mode (full scaffold + templates) and `--layouts-only` mode.

**Requirements:** R4, R5, R17, R23.

**Dependencies:** Unit 2 (for archetype contract), Unit 13 (templates to copy into curricula).

**Files:**
- Create: `scripts/scaffold-site.sh`

**Approach:**
- Bash script, POSIX-compatible.
- Arguments: `--title`, `--hue`, `--description`, `--author`, `--target <dir>`, `--layouts-only`.
- Full mode:
  - `hugo new site "$TARGET/site" --format yaml`
  - Embed via heredocs: `site/archetypes/modules.md` (with expanded frontmatter per R5), `site/assets/css/site.css`, `site/layouts/baseof.html`, `site/layouts/index.html`, `site/layouts/_default/page.html`, `site/layouts/_default/section.html`, `site/layouts/partials/nav.html`, `site/hugo.yaml`.
  - Copy `curriculum-templates/{serve,build,stop}.{sh,ps1}` and `.gitignore` into `$TARGET`.
  - Write `.github/workflows/deploy.yml` from embedded heredoc.
- `--layouts-only` mode:
  - Rewrite only `site/layouts/`, `site/assets/css/`, `site/archetypes/`, `site/hugo.yaml`.
  - Leave `site/content/` untouched.
- Fails loudly if Hugo is missing (delegates to Unit 12 helper).

**Patterns to follow:**
- Current `skills/tmb/references/hugo-site.md` lines 225–366 provides the authoritative layout and CSS bodies; port verbatim into heredocs.

**Test scenarios:**
- Happy path: `scripts/scaffold-site.sh --title "SQL for Analysts" --hue 220 --description "..." --author "D. Thomas" --target /tmp/test-curriculum` → full scaffold produced; `hugo server -D` from the scaffolded `site/` starts cleanly.
- Happy path (layouts-only): point at an existing curriculum → `site/content/` is unchanged; `site/layouts/` matches the latest.
- Edge case: `--target` doesn't exist → creates it.
- Edge case: `--target/site/` exists and full mode called → errors; suggest `--layouts-only`.
- Error path: `--hue` out of [0,360] → errors.
- Error path: Hugo missing → exits non-zero with pointer to Unit 12 helper.

**Verification:** `hugo server -D -s /tmp/test-curriculum/site` serves a working site with the theme hue applied.

---

- [ ] **Unit 12: Hugo prerequisite + install helper**

**Goal:** Detect Hugo availability; if missing or outdated, offer a platform-appropriate one-line install; on decline or no package manager, print the release URL and abort.

**Requirements:** R28.

**Dependencies:** None.

**Files:**
- Create: `scripts/check-hugo.sh`
- Create: `scripts/check-hugo.ps1`
- Modify: `references/hugo-site.md` (document the helper)

**Approach:**
- `check-hugo.sh`: run `hugo version`; parse output; compare against `0.120.0` minimum.
- If missing: detect `brew` / `apt` / `snap` / `dnf`; prompt `Install hugo-extended via <mgr>? [y/N]`. If yes, run the install command with sudo-elevation only where mandatory (apt/dnf); if no, print the release URL (https://github.com/gohugoio/hugo/releases/tag/v0.160.1) and exit with a helpful message.
- If outdated: same flow but worded as upgrade.
- `check-hugo.ps1`: equivalent using `winget` / `choco` / `scoop`.
- Orchestrators (Unit 6, Unit 9, Unit 11) call this helper before anything else.

**Test scenarios:**
- Happy path: Hugo installed at 0.160 → helper exits 0 with "hugo 0.160 detected".
- Edge case: Hugo installed at 0.115 → helper offers upgrade.
- Edge case: Hugo missing, brew installed, user accepts → `brew install hugo-extended` runs; helper re-checks and exits 0.
- Edge case: Hugo missing, no package manager detected → prints release URL + exits 1.
- Error path: `brew install` fails → helper prints the error and exits 1.
- Integration: `/tmb:create` short-circuits if helper exits 1.

**Verification:** Test on a machine without Hugo; run `/tmb:create`; confirm the install offer flow.

---

- [ ] **Unit 13: Curriculum-root script templates**

**Goal:** Ship `serve.sh` / `serve.ps1` / `build.sh` / `build.ps1` / `stop.sh` / `stop.ps1` templates that go into every generated curriculum.

**Requirements:** R20, R21, R22, R24, R25, R36.

**Dependencies:** Unit 12 (Hugo check).

**Files:**
- Create: `curriculum-templates/serve.sh`
- Create: `curriculum-templates/serve.ps1`
- Create: `curriculum-templates/build.sh`
- Create: `curriculum-templates/build.ps1`
- Create: `curriculum-templates/stop.sh`
- Create: `curriculum-templates/stop.ps1`
- Create: `curriculum-templates/.gitignore`

**Approach:**
- `serve.sh` / `serve.ps1`: accept `--port N` flag (default 1313). Run Hugo check helper (Unit 12). Call `hugo server -D --port "$PORT"` from `site/` and write `$$` (or `$PID`) to `.hugo.pid`. Trap EXIT to remove the pidfile.
- `build.sh` / `build.ps1`: Hugo check; `hugo --minify` from `site/`. Idempotent.
- `stop.sh` / `stop.ps1`: read `.hugo.pid` and `kill` (POSIX) or `Stop-Process` (Windows). Remove pidfile.
- `.gitignore`: `site/public/`, `site/resources/`, `.hugo.pid`.

**Test scenarios:**
- Happy path: `./serve.sh` → site up at 1313, pidfile exists.
- Happy path: `./stop.sh` → process killed, pidfile removed.
- Edge case: port 1313 in use → serve.sh suggests `--port 1314`.
- Edge case: `./stop.sh` with no pidfile → prints "no running server" and exits 0.
- Integration: `./serve.sh --port 1314 &` then `./stop.sh` → clean teardown.
- Cross-platform: `serve.ps1` equivalent to `serve.sh` on Windows.

**Verification:** Run the full lifecycle (serve → visit localhost → stop) on macOS. PowerShell counterpart tested on a Windows VM (if available; otherwise document as "needs Windows user validation").

---

- [ ] **Unit 14: End-to-end acceptance run**

**Goal:** Validate all success criteria against a real 3-module curriculum.

**Requirements:** All.

**Dependencies:** Units 1–13.

**Files:**
- Create (temporary): `/tmp/tmb-acceptance/` (throwaway target)
- Create: `docs/solutions/2026-MM-DD-tmb-v0.3-launch-notes.md` (post-run learnings, to feed `/ce:compound`)

**Approach:**
- Install the v0.3 plugin locally (`npm run build` + manual install).
- Run `/tmb:create` with a compact test topic ("SQL joins for analysts", 3 modules via depth-vs-breadth=deep + timeline=weeks).
- Walk every success criterion in the origin doc against the result.
- Hand-edit one module's prose to contradict its brief; run `/tmb:review`; verify drift flagged.
- Run `/tmb:add-module` at position 2; verify weights shift, reviewer runs on neighbors.
- Run `/tmb:rebuild-site`; verify layouts refresh, content untouched.
- Capture any issues as `docs/solutions/` entries and file follow-up.

**Test scenarios:**
- Happy path: all success criteria pass.
- Error path (deliberate): sabotage one brief to be incomplete → `/tmb:create` aborts at R6a gate with a clear error.
- Error path (deliberate): simulate Hugo missing → `/tmb:create` offers install.

**Verification:**
- `hugo server -D` via `./serve.sh` shows a live site at the delivered URL.
- `review.md` lists only expected flags (deliberate drift, if any).
- A second run of `/tmb:create` in the same cwd is refused per R18.

## System-Wide Impact

- **Interaction graph:** The plugin gains four named skill entry points + three custom agents. `skills/create/SKILL.md` coordinates all three agents + two shell scripts. `skills/review/` and `skills/add-module/` each dispatch `tmb-reviewer` (and `tmb-module-builder` for add-module). `skills/rebuild-site/` invokes only `scripts/scaffold-site.sh`. Cross-talk between skills is via filesystem state (spine, briefs, review.md), not direct skill-to-skill calls.
- **Error propagation:** The orchestrator is responsible for surfacing errors to the user as either a cleanly-formatted abort (R6a gate, R18 collision, R28 Hugo missing) or a degraded-but-continue path (R8a builder failure, R37 reviewer crash, R22 server unable to start). No silent swallowing.
- **State lifecycle risks:**
  - `.hugo.pid` orphaning if the shell dies without trap fire → `stop.sh` handles "no pidfile" gracefully.
  - Partial builds: R33 resume flow detects completed modules by frontmatter; no half-written files left if a builder fails mid-write (builder agents are all-or-nothing per Unit 4).
  - Glossary race was load-bearing in the origin doc; R7a's side-file merge model eliminates it structurally.
- **API surface parity:** Four skills share the Hugo install helper (Unit 12). Any change to the install flow must be made once and inherited by all four.
- **Integration coverage:** Unit 14's end-to-end acceptance run is the only place parallel dispatch + reviewer + build + serve are exercised together. Manual run required because the pipeline crosses filesystem, Agent tool, and Bash tool boundaries.
- **Unchanged invariants:** The 7-step interview in `references/elicitation.md` is unchanged. Hugo theme CSS / layouts preserve their HSL-hue architecture. The plugin's release workflow (`npm run release -- X.Y.Z` → tag → GitHub Actions → marketplace dispatch) is unchanged apart from the version number.

## Risks & Dependencies

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Claude Code plugin convention diverges from researched expectation (commands/agents paths) | Low | High (all 4 skills + 3 agents fail discovery) | Unit 1 is the first committed change; run locally and verify `/tmb:help` loads before any other unit is built. |
| tmux unavailable on user's platform → server backgrounding degraded | Medium | Medium (UX regression from origin's vision) | R22 fallback (print command, skip probe) is specified. User still gets a working site; just manual start. |
| `Agent` tool dispatch cap of 10 hit in practice (curricula with 10+ modules) | Low | Low (rare case) | Unit 6 batches at 10; extra modules queue. Documented as a deferred optimization. |
| Hugo install flow surprises user (sudo prompt, package manager conflict) | Medium | Low-Medium | R28's explicit prompt pattern surfaces the command before running. Decline path always available. |
| Reviewer false-positives on AI-prose flood `review.md` with noise | Medium | Medium | R12 explicit "user review, never auto-rewritten" protects content. Acceptance run (Unit 14) tunes the heuristic. |
| Cross-platform script parity drift (POSIX vs PowerShell behavior diverges) | Medium | Low (Windows user base unconfirmed) | POSIX is the canonical reference; PowerShell counterparts mirror with best-effort. Flagged as "needs Windows user validation" in Unit 13. |
| v0.2.x curricula break on update | N/A (intentional) | N/A | Scope boundary: no auto-migration. Documented in CHANGELOG and `/tmb:rebuild-site` error. |
| `.github/workflows/release.yml` and `scripts/build.js` drift | High without discipline | High (released zip differs from local) | Unit 1 updates both; add a lint-check comparing their include lists (deferred to implementation, see Open Questions). |

## Documentation / Operational Notes

- `CHANGELOG.md` must call out breaking changes: no more per-module README.md, no more claude.ai-chat support, new slash command surface.
- `README.md` rewrite: replace "The `/tmb` command" section with a table of the four operational commands + `/tmb:help`.
- Rollout: minor version bump to `0.3.0` per semver (breaking changes in a pre-1.0 plugin are acceptable at the minor level). `RELEASING.md` flow unchanged.
- Monitoring: none (client-side plugin). Post-release, watch GitHub Issues for plugin-layout surprises on user machines.
- Future compounding: Unit 14's acceptance run should produce at least one `docs/solutions/` entry documenting the tmux workaround and the `--die-with-parent` gotcha so subsequent plugin work inherits the learning.

## Sources & References

- **Origin document:** `docs/brainstorms/tmb-hugo-first-parallel-builders-requirements.md`
- **Existing skill:** `skills/tmb/SKILL.md`
- **Hugo reference material:** `skills/tmb/references/hugo-site.md` (moves to `references/hugo-site.md` in Unit 2)
- **Curriculum design principles:** `skills/tmb/references/curriculum-design.md` (moves in Unit 2)
- **Interview script:** `skills/tmb/references/elicitation.md` (moves in Unit 2)
- **Plugin manifest:** `.claude-plugin/plugin.json`
- **Build pipeline:** `scripts/build.js`, `.github/workflows/release.yml`
- **Claude Code plugin docs:** https://code.claude.com/docs/en/plugins, https://code.claude.com/docs/en/skills, https://code.claude.com/docs/en/sub-agents
- **Hugo releases:** https://github.com/gohugoio/hugo/releases/tag/v0.160.1
- **Related issue:** https://github.com/anthropics/claude-code/issues/11716 (`run_in_background` caveat)
