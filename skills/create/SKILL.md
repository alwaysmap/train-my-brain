---
name: create
description: Builds a structured, hands-on learning curriculum with a local Hugo site. Runs the 7-step TMB interview, designs modules, scaffolds the site, dispatches parallel module-builders, runs the consistency reviewer, builds the static output, and starts the server. Scaffolds into <cwd>/<topic-slug>/.
when_to_use: >
  The user asks to build a learning curriculum, study plan, or "train my brain" on a topic.
  Trigger phrases: "/tmb:create", "create a curriculum", "build a learning plan for X",
  "help me learn X for a job", "I want to get credible in X", "I need to learn X to achieve Y".
  Also use this skill even if the domain seems simple — the interview and structure are what
  make the output good. Do NOT skip the interview phase.
argument-hint: <optional topic hint — the interview will clarify>
allowed-tools: [Read, Write, Bash, Agent, Glob, Grep]
---

# /tmb:create

You are orchestrating a TMB v0.3 curriculum build. You do not write module content yourself — the agents do that. Your job is to run the phases in order, wire the agents together, and deliver the result.

## Phase 0: Hugo prerequisite

Before touching anything else, invoke the Hugo check:

```bash
bash scripts/check-hugo.sh
```

On non-zero exit, stop. The helper will have printed install guidance. Propagate its output to the user verbatim and do not proceed.

## Phase 1: Interview

Read `references/elicitation.md`. Run the 7 steps exactly as specified, including the two-exchange discipline (ask → wait → reflect → STOP → wait for confirmation → ask next). Do not skip the reflection pauses.

At the end of Step 7, you have the full `interview_answers` structure described in the designer agent's contract:

```yaml
step_1_goal: "..."
step_2_tested_via: [...]
step_3_audience_starting_point: "..."
step_4_depth_vs_breadth: "wide" | "deep" | "middle"
step_5_validation_preferences: [...]
step_6_timeline: "a few weeks" | "a few months"
step_6_tools_present: [...]
step_7_color: "..."
step_7_hue: <0..360>
```

Summarize back to the user per the elicitation flow ("Here's what I'm building: ..."). Wait for confirmation before Phase 2.

## Phase 2: Target directory

Derive the kebab-case slug from the Step 1 goal + topic (e.g., "Learn PostgreSQL query planning" → `postgresql-query-planning`). Compute `target = <cwd>/<slug>/`.

Tell the user: *"I'll create the curriculum in `<target>`. Say otherwise if you want a different parent path."* Wait for confirmation or a new path. Do not ask "where do you want to save this?" — the default is stated.

Once confirmed:

```bash
if [ -d "<target>" ] && [ "$(ls -A <target>)" ]; then
  # Non-empty — refuse unless resume case
  # Detect partial-progress: does <target>/curriculum_spine.md exist?
  if [ -f "<target>/curriculum_spine.md" ] && [ -d "<target>/briefs" ]; then
    # Partial — offer --resume
    ...
  else
    # Hard refuse
    ...
  fi
fi
mkdir -p "<target>"
```

- Fresh: create the directory and continue.
- Partial (spine + briefs exist, some modules missing): ask the user `"Found an in-progress curriculum at <target>. Resume by re-running only the missing modules? [y/N]"`. On yes, skip to Phase 5 and only dispatch builders for modules whose `site/content/modules/<slug>/index.md` does not exist. On no, abort.
- Non-empty and not a TMB curriculum: refuse with `"<target> already exists and is not empty. Rename or pick another parent directory."`

## Phase 3: Design

Dispatch the `tmb-designer` agent with:

```
Agent(
  subagent_type: "tmb-designer",
  prompt: <JSON containing slug, curriculum_root, interview_answers>
)
```

The designer writes `curriculum_spine.md` and `briefs/NN-slug.yaml` per module, and runs the completeness gate. If the agent returns a gap error, surface it verbatim and abort — do not scaffold a site on a broken design.

Tell the user what the designer produced: module count, titles, the chosen running example. Give them a chance to cancel (one yes/no prompt) before the scaffold runs.

## Phase 4: Scaffold the Hugo site

```bash
bash scripts/scaffold-site.sh \
  --target "<target>" \
  --title "<from interview>" \
  --description "<one-sentence curriculum description>" \
  --author "<from git config user.name or ask>" \
  --hue <from interview_answers.step_7_hue>
```

The scaffold writes `site/` layouts / CSS / archetype / `hugo.yaml`, copies the curriculum-templates (`serve.sh`, `build.sh`, `stop.sh`, POSIX + PowerShell counterparts, `.gitignore`), and writes the `.github/workflows/deploy.yml`. It does not write module content — that's the builders' job.

If the scaffold script fails, stop. Do not dispatch builders on a broken scaffold.

## Phase 5: Parallel module builders

For each brief in `<target>/briefs/*.yaml`, dispatch a `tmb-module-builder`:

```
Agent(
  subagent_type: "tmb-module-builder",
  prompt: <JSON with brief_path, spine_path, curriculum_root, slug>
)
```

**Batching**: Claude Code's Agent tool caps parallel dispatch at ~10 concurrent. If there are > 10 briefs, issue them in batches of 10 and wait for each batch to complete before starting the next. For 5–9 modules (the normal range), dispatch all at once in a single assistant turn.

**Do not** run the reviewer between batches. Wait until every builder has returned.

**Failure semantics (R8a)**: if a builder errors or times out, note the module slug and continue with the rest. The reviewer will flag the missing module as a P0 substantive issue. Do not auto-retry.

**Resume mode**: in Phase 2 resume case, only dispatch builders for modules whose `site/content/modules/<slug>/index.md` does not already exist.

## Phase 6: Reviewer

Once all builders have returned (success or failure), dispatch the reviewer:

```
Agent(
  subagent_type: "tmb-reviewer",
  prompt: <JSON with curriculum_root, mode: "full">
)
```

The reviewer merges `new_terms.yaml` files into `glossary.md`, runs mechanical fixes, checks URLs, and writes `review.md` with substantive flags.

**Crash containment (R37)**: if the reviewer fails mid-pass, it writes a partial `review.md` with a footer. Continue to Phase 7 anyway — do not discard builder outputs.

## Phase 7: Build

```bash
cd "<target>" && ./build.sh
```

This runs `hugo --minify` from `site/` and writes `site/public/`. Surface errors verbatim.

## Phase 8: Serve

Attempt to start the server in the background:

```bash
if command -v tmux >/dev/null 2>&1; then
  tmux new-session -d -s "tmb-<slug>" "cd '<target>' && ./serve.sh"
  # Readiness probe
  for i in {1..30}; do
    if curl -fsS -o /dev/null "http://localhost:1313/"; then
      server_ready=true
      break
    fi
    sleep 0.5
  done
else
  server_ready=false
fi
```

- If tmux is available and the readiness probe succeeded: the site is live.
- If tmux is missing or the probe timed out (port in use, Hugo failed to start, etc.): fall back to telling the user to run `./serve.sh` in another terminal. Include the `lsof -i :1313` diagnostic command.

Do not hang indefinitely. 15 seconds max on the probe.

## Phase 9: Deliver

Print the delivery block:

```
Your curriculum is ready.

🌐 Site:   http://localhost:1313
📁 Folder: file://<target>/
   Open:  open <target>       (macOS)
          xdg-open <target>   (Linux)
          explorer <target>   (Windows)

↻ Restart server: cd <target> && ./serve.sh
✖ Stop server:    cd <target> && ./stop.sh
🔧 Rebuild site:  cd <target> && ./build.sh

Review: <target>/review.md
  - Mechanical fixes applied: <N>
  - Substantive flags waiting: <K>
  <If K>0: ask the user to open review.md and set approved: true on flags they want applied, then re-run /tmb:review.>

If the server didn't start automatically:
  cd <target> && ./serve.sh
  (then open http://localhost:1313)
```

Match the actual state — don't print the tmux-succeeded version if the fallback path fired.

## Standing rules (apply at every phase)

- Announce what you're doing before each phase in one short line. Users should see progress.
- Never skip a phase even if the user says "just do it" — the interview discipline is what makes the output good.
- Propagate agent errors verbatim. Do not paraphrase them into optimism.
- Do not invent content. All module content comes from agents; all scaffold content comes from the scaffold script.

## References

- `references/elicitation.md` — the 7-step interview
- `references/spine-schema.md` — what the designer produces
- `references/brief-schema.md` — per-module brief contract
- `references/reviewer-policy.md` — what the reviewer enforces
- `references/curriculum-design.md` — underlying pedagogy rules
- `agents/tmb-designer.md`, `agents/tmb-module-builder.md`, `agents/tmb-reviewer.md` — agent contracts

## Quality gates (before declaring delivery complete)

- [ ] Hugo confirmed installed (Phase 0 passed)
- [ ] All 7 interview steps confirmed
- [ ] Target directory is `<cwd>/<slug>/` and was created fresh or resumed cleanly
- [ ] `curriculum_spine.md` and every `briefs/NN-slug.yaml` written and passed the completeness gate
- [ ] Hugo site scaffolded (`site/layouts/`, `site/assets/css/`, `site/archetypes/`, `site/hugo.yaml`)
- [ ] Curriculum-template scripts in place (`serve.sh`, `build.sh`, `stop.sh` + .ps1 counterparts)
- [ ] Every module builder has returned (success or flagged failure)
- [ ] `review.md` written
- [ ] `./build.sh` ran successfully and `site/public/` exists
- [ ] Server is running OR user has the exact command to run it
- [ ] Delivery block printed with accurate state
