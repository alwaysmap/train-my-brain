---
name: create
description: >
  Use this skill when the user wants to build a learning curriculum, study plan,
  or "train their brain" on a topic. Triggers on "/tmb:create", "create a
  curriculum", "build a learning plan for X", "help me learn X for a job",
  "I want to get credible in Y", "I need to learn X". Runs the 8-step interview,
  dispatches a one-shot topic researcher, designs modules, scaffolds a Hugo site,
  bootstraps each module's filesystem with `hugo new`, dispatches parallel
  module-builders that share the research substrate, runs the deterministic
  reviewer, builds, and serves. Scaffolds into `<cwd>/<topic-slug>/`.
user_summary: >
  Build a hands-on learning curriculum for any topic. Asks 8 short questions,
  researches the topic once, then produces a structured local Hugo site with
  exercises, validation prompts, dark-mode-aware theming, and your choice of
  signage-style or book-style typography.
version: 0.4.4
argument-hint: "[optional topic hint — the interview will clarify]"
allowed-tools: [Read, Write, Bash, Agent, Glob, Grep]
---

# /tmb:create

Orchestrate a TMB v0.4 curriculum build. You do not write module content yourself — the agents and scripts do. Your job is to run phases in order, wire agents together, surface failures honestly, and deliver the result.

## Files

| File | Loaded when |
|------|-------------|
| `SKILL.md` (this file) | Always — the workflow scaffold |
| `references/elicitation.md` | Phase 1 — 8-step interview discipline |
| `skills/create/references/curriculum-state.md` | Phase 2 — only when `detect-curriculum.sh` returns non-fresh |
| `references/research-schema.md` | Phase 3 — what `research.yaml` must contain |
| `references/spine-schema.md` | Phase 4 — what the designer produces |
| `references/brief-schema.md` | Phase 4 — per-module brief contract |
| `references/curriculum-design.md` | Phase 4 + Phase 7 — pedagogy rules |
| `references/reviewer-policy.md` | Phase 8 — what the reviewer enforces |
| `skills/create/references/delivery.md` | Phase 10 + 11 — tmux serve flow + delivery block |
| `skills/create/references/quality-gates.md` | Before declaring delivery complete — 12-item green-check list |
| `references/github-pages.md` | Phase 11 — only when the user asks how to publish online |

## Workflow

### Phase 0: Preflight

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
```

The script tells the user what's missing and offers (macOS+brew) or prints (Linux) install commands. If it exits non-zero, propagate its output verbatim and stop. Do not freelance dep installs.

### Phase 1: Interview

**Read `references/elicitation.md`** before starting. Run the 8 steps with the two-exchange discipline (ask → wait → reflect → STOP → wait for confirmation → ask next). Do not skip the reflection pauses.

After Step 8, summarize back ("Here's what I'm building: ..."). Wait for confirmation before Phase 2.

### Phase 2: Target directory

Derive a kebab-case slug from the Step 1 goal + topic. Compute `target = <cwd>/<slug>/`. Tell the user the path. Wait for confirmation or a different parent.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-curriculum.sh "<target>"
```

**If `state == "fresh"`:** `mkdir -p "<target>"` and continue.

**Otherwise**, read `skills/create/references/curriculum-state.md` for the per-state branch logic (`v0.4-partial` resume offer, `v0.3`/`v0.2` refusal messages, `non-tmb` refusal). The reference has the user-facing text verbatim.

### Phase 3: Topic research

Dispatch the `tmb-researcher` agent with `slug`, `curriculum_root=target`, and `interview_answers`. The agent writes `research.yaml` and runs `validate-research.sh` itself. If the gate fails, propagate verbatim and abort. **Do not dispatch the designer against an invalid `research.yaml`.**

Summarize: "Researched <topic>: <N> glossary entries, <M> sources, <K> contrasts." If `open_questions` exist, surface them and wait for input before Phase 4.

### Phase 4: Design

**Read `references/spine-schema.md` and `references/brief-schema.md`** to understand what the designer will produce.

Dispatch `tmb-designer` with `mode="new"`. The designer reads `research.yaml`, writes `curriculum_spine.md` and `briefs/*.yaml`, then runs `validate-briefs.sh`. On gate failure, propagate the JSON gaps verbatim and abort.

Tell the user: "Quick confirmation: Designed <count> modules — <titles>. Running example: <name>." then call `AskUserQuestion` with the design-approval picker described in the standing rules below. Wait.

### Phase 5: Scaffold the Hugo site

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold-site.sh \
  --target "<target>" \
  --title "<from interview>" \
  --description "<one-sentence>" \
  --author "<git config user.name or asked>" \
  --hue <interview_answers.step_7_hue> \
  --font-preset <interview_answers.step_8_font_preset>
```

`--font-preset` is `signage` or `book` from Step 8 of the interview. The scaffold writes both as `params.hue` and `params.font_preset` in `hugo.yaml`; the Hugo templates load the matching Google Fonts and apply the right CSS variables. Dark mode + WCAG-AA contrast handling are automatic via `prefers-color-scheme` and `prefers-contrast` media queries (the user's OS setting drives rendering).

Stop on failure. Don't dispatch builders against a broken scaffold.

### Phase 6: Bootstrap module filesystems (deterministic)

```bash
for brief in "<target>/briefs"/*.yaml; do
  slug=$(basename "$brief" .yaml)
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/new-module.sh "<target>" "$slug"
done
```

`new-module.sh` creates each module as a Hugo branch bundle:

- `site/content/modules/<slug>/_index.md` (concept page, frontmatter populated from brief)
- `site/content/modules/<slug>/validation.md` (with scenario inlined)
- `site/content/modules/<slug>/exercises/_index.md` (exercises section)
- `modules/<slug>/new_terms.yaml` (data file, not Hugo content)

Builders only fill in body content. The script refuses to clobber existing modules in resume mode.

### Phase 7: Parallel module builders

Dispatch one `tmb-module-builder` per bootstrapped slug, in parallel (cap 10 per batch).

**Failure semantics.** If a builder fails, note the slug and continue. The reviewer's `check-frontmatter.sh` will flag the missing body as `build_failure`. Do not auto-retry.

### Phase 8: Reviewer

Dispatch `tmb-reviewer` with `mode="full"`. The reviewer runs every determinism script (adjacency, frontmatter, URL reachability, AI-prose, glossary merge, **glossary auto-link**), applies mechanical fixes, and writes `review.md`. The auto-linker injects `{{< gloss "..." >}}` shortcodes so first mentions of glossary terms become clickable. If the reviewer crashes mid-pass it leaves a partial `review.md` with a footer — fine, continue.

### Phase 9: Build

```bash
cd "<target>" && ./build.sh
```

Surface errors verbatim.

### Phase 10: Serve

**Read `skills/create/references/delivery.md`** — it has the tmux logic, readiness probe, and fallbacks.

### Phase 11: Deliver

`references/delivery.md` has the delivery block template. Substitute runtime values; match the actual server state (don't print the success block if the fallback fired).

## Standing rules

### Progress announcements

Every phase boundary the user can't otherwise see — every script call, every agent dispatch — gets a one-line announcement in this format:

```
[<N> of 11] <short verb-led description>...
```

Examples:

- `[3 of 11] Researching the topic — this takes 1–2 minutes.`
- `[6 of 11] Bootstrapping module filesystems with hugo new...`
- `[7 of 11] Dispatching 6 module-builders in parallel — this takes 3–5 minutes.`
- `[8 of 11] Running the consistency reviewer...`
- `[9 of 11] Building the static site...`
- `[10 of 11] Starting the dev server.`

Phases 0–2 don't need numbered announcements — the user is actively in conversation. The phase counter is for the autonomous block (Phase 3 onward) so the user has a clear "we're at step X of 11" mental model and can leave the laptop without losing the thread.

For agent dispatch (Phases 3, 4, 7, 8): also include an estimated duration if you have one.

### Confirmations use the AskUserQuestion picker, not numbered prose

Every confirmation gate outside the 8-step interview (target-directory confirmation, design approval, resume offer, dep install offer, open-question resolution from the researcher) is presented via the `AskUserQuestion` tool — a TUI select widget the user navigates with the keyboard — **not** as a numbered list in prose, and **not** as "Is that ok?" with free-text yes/no. The picker is the entire gate.

Standard pattern:

1. Print a one-line state-of-the-world preface as a normal message, prefixed with `Quick confirmation:` so the user recognizes the gate.
2. Immediately call `AskUserQuestion` with 2–4 options describing the available paths. The "Other" option is appended automatically — never include one yourself.

Examples:

**Target directory:**

> Quick confirmation: I'll create the curriculum at `<target>`.

```
question: "Use this folder for the curriculum?"
header:   "Target folder"
multiSelect: false
options:
  - label: "Proceed"
    description: "Create the curriculum at <target>."
  - label: "Use a different parent directory"
    description: "Tell me where to put it instead."
  - label: "Cancel"
    description: "Stop without creating anything."
```

**Design approval:**

> Quick confirmation: Designed 6 modules — Lifecycle, Data, Post-training, Evals, Safety, Productization. Running example: Claude Legal Advisor.

```
question: "Continue to scaffold with this module list?"
header:   "Approve design"
multiSelect: false
options:
  - label: "Proceed to scaffold"
    description: "Build the Hugo site and dispatch module-builders."
  - label: "Suggest changes"
    description: "Tell me which module to revise, drop, or add."
  - label: "Cancel"
    description: "Stop without scaffolding."
```

**Resume offer:**

> Quick confirmation: Found an in-progress v0.4 curriculum at `<target>` with 3 modules missing.

```
question: "Resume or start fresh?"
header:   "Resume"
multiSelect: false
options:
  - label: "Resume"
    description: "Re-run only the missing builders against the existing scaffold."
  - label: "Start fresh"
    description: "Abort and rename the existing folder so we begin clean."
```

Rules:

- Always lead with a `Quick confirmation:` preface as a normal message so the user knows it's a gate, not a substantive question.
- 2–4 options per `AskUserQuestion` call. Two is fine when the choice is binary (proceed vs cancel). Three when there's a "modify" path.
- "Suggest changes" / "Use a different parent directory" / similar modify paths mean *the user's next message is plain prose describing the change* — treat it as an open turn, apply the change, then re-call the same `AskUserQuestion` widget.
- Never substitute a numbered list in prose for the picker, even for two-option gates. The picker keeps confirmation a one-keystroke act.
- The 8-step interview itself also uses `AskUserQuestion` per `references/elicitation.md` — but with its own reflection-pause discipline. The standing rule here covers gates *between* phases.

### Other rules

- Never skip a phase even if the user says "just do it" — the interview discipline and research substrate are what make the output good.
- Propagate agent and script errors verbatim. Do not paraphrase them into optimism.
- Do not invent content. Module content comes from agents; scaffold from `scaffold-site.sh`; URLs and definitions from `research.yaml`.

## Quality gates

Before declaring delivery complete, work through `skills/create/references/quality-gates.md` — a 12-item checklist covering preflight, interview, research, design, scaffold, bootstrap, builders, reviewer, build, and serve.
