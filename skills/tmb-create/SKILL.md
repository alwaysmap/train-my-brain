---
name: tmb-create
description: >
  Use this skill when the user wants to build a learning curriculum, study plan,
  or "train their brain" on a topic. Triggers on "/tmb:create", "create a
  curriculum", "build a learning plan for X", "help me learn X for a job",
  "I want to get credible in Y", "I need to learn X". Runs the 7-step interview,
  dispatches a one-shot topic researcher, designs modules, scaffolds a Hugo site,
  bootstraps each module's filesystem with `hugo new`, dispatches parallel
  module-builders that share the research substrate, runs the deterministic
  reviewer, builds, and serves. Scaffolds into `<cwd>/<topic-slug>/`.
user_summary: >
  Build a hands-on learning curriculum for any topic. Asks 7 short questions,
  researches the topic once, then produces a structured local Hugo site with
  exercises and validation prompts.
version: 0.4.0
argument-hint: "[optional topic hint — the interview will clarify]"
allowed-tools: [Read, Write, Bash, Agent, Glob, Grep]
---

# /tmb:create

Orchestrate a TMB v0.4 curriculum build. You do not write module content yourself — the agents and scripts do. Your job is to run phases in order, wire agents together, surface failures honestly, and deliver the result.

## Files

| File | Loaded when |
|------|-------------|
| `SKILL.md` (this file) | Always — the workflow scaffold |
| `references/elicitation.md` | Phase 1 — 7-step interview discipline |
| `references/research-schema.md` | Phase 3 — what `research.yaml` must contain |
| `references/spine-schema.md` | Phase 4 — what the designer produces |
| `references/brief-schema.md` | Phase 4 — per-module brief contract |
| `references/curriculum-design.md` | Phase 4 + Phase 7 — pedagogy rules |
| `references/reviewer-policy.md` | Phase 8 — what the reviewer enforces |
| `skills/tmb-create/references/delivery.md` | Phase 10 + 11 — tmux serve flow + delivery block |

## Workflow

### Phase 0: Preflight

```bash
bash scripts/check-deps.sh
```

On non-zero exit, propagate verbatim and stop. Do not attempt to install dependencies yourself.

### Phase 1: Interview

**Read `references/elicitation.md`** before starting. Run the 7 steps with the two-exchange discipline (ask → wait → reflect → STOP → wait for confirmation → ask next). Do not skip the reflection pauses.

After Step 7, summarize back ("Here's what I'm building: ..."). Wait for confirmation before Phase 2.

### Phase 2: Target directory

Derive a kebab-case slug from the Step 1 goal + topic. Compute `target = <cwd>/<slug>/`. Tell the user the path. Wait for confirmation or a different parent.

```bash
bash scripts/detect-curriculum.sh "<target>"
```

Branch on `state`:

- `fresh` — `mkdir -p "<target>"` and continue.
- `v0.4-partial` — offer resume; on yes, skip to Phase 6 and only dispatch new-module + builders for `missing_pages`.
- `v0.3-*` — refuse; v0.4 introduces research.yaml with no auto-upgrade.
- `v0.2` — refuse with the v0.2 message.
- `non-tmb` — refuse with "directory exists and is not empty."

### Phase 3: Topic research

Dispatch the `tmb-researcher` agent with `slug`, `curriculum_root=target`, and `interview_answers`. The agent writes `research.yaml` and runs `validate-research.sh` itself. If the gate fails, propagate verbatim and abort. **Do not dispatch the designer against an invalid `research.yaml`.**

Summarize: "Researched <topic>: <N> glossary entries, <M> sources, <K> contrasts." If `open_questions` exist, surface them and wait for input before Phase 4.

### Phase 4: Design

**Read `references/spine-schema.md` and `references/brief-schema.md`** to understand what the designer will produce.

Dispatch `tmb-designer` with `mode="new"`. The designer reads `research.yaml`, writes `curriculum_spine.md` and `briefs/*.yaml`, then runs `validate-briefs.sh`. On gate failure, propagate the JSON gaps verbatim and abort.

Tell the user: "Designed <count> modules: <titles>. Running example: <name>. Continue? [Y/n]". Wait.

### Phase 5: Scaffold the Hugo site

```bash
bash scripts/scaffold-site.sh \
  --target "<target>" \
  --title "<from interview>" \
  --description "<one-sentence>" \
  --author "<git config user.name or asked>" \
  --hue <interview_answers.step_7_hue>
```

Stop on failure. Don't dispatch builders against a broken scaffold.

### Phase 6: Bootstrap module filesystems (deterministic)

```bash
for brief in "<target>/briefs"/*.yaml; do
  slug=$(basename "$brief" .yaml)
  bash scripts/new-module.sh "<target>" "$slug"
done
```

`new-module.sh` runs `hugo new` (using the archetype) and patches frontmatter from the brief. After this, every module's filesystem is ready and frontmatter is correct — builders only deal with bodies. In resume mode, the script refuses to clobber existing modules; skip those.

### Phase 7: Parallel module builders

Dispatch one `tmb-module-builder` per bootstrapped slug, in parallel (cap 10 per batch).

**Failure semantics.** If a builder fails, note the slug and continue. The reviewer's `check-frontmatter.sh` will flag the missing body as `build_failure`. Do not auto-retry.

### Phase 8: Reviewer

Dispatch `tmb-reviewer` with `mode="full"`. The reviewer runs every determinism script (adjacency, frontmatter, URL reachability, AI-prose, glossary merge), applies mechanical fixes, and writes `review.md`. If it crashes mid-pass it leaves a partial `review.md` with a footer — fine, continue.

### Phase 9: Build

```bash
cd "<target>" && ./build.sh
```

Surface errors verbatim.

### Phase 10: Serve

**Read `skills/tmb-create/references/delivery.md`** — it has the tmux logic, readiness probe, and fallbacks.

### Phase 11: Deliver

`references/delivery.md` has the delivery block template. Substitute runtime values; match the actual server state (don't print the success block if the fallback fired).

## Standing rules

- Announce each phase in one short line so users see progress.
- Never skip a phase even if the user says "just do it" — the interview discipline and research substrate are what make the output good.
- Propagate agent and script errors verbatim. Do not paraphrase them into optimism.
- Do not invent content. Module content comes from agents; scaffold from `scaffold-site.sh`; URLs and definitions from `research.yaml`.

## Quality gates

- [ ] `check-deps.sh` passed (Phase 0)
- [ ] All 7 interview steps confirmed
- [ ] Target was `fresh` or `v0.4-partial`
- [ ] `research.yaml` written, `validate-research.sh` passed
- [ ] Spine + briefs written, `validate-briefs.sh` passed
- [ ] Hugo site scaffolded
- [ ] `new-module.sh` succeeded for every brief
- [ ] Every builder returned (success or flagged failure)
- [ ] `review.md` written
- [ ] `./build.sh` succeeded
- [ ] Server running OR user has the exact command
- [ ] Delivery block printed with accurate state
