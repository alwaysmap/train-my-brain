---
name: add-module
description: >
  Use this skill when the user wants to add a single module to an existing
  curriculum. Triggers on "/tmb:add-module", "add a module", "insert a module
  at position N", "extend the curriculum". Supports append (default) and
  insert-at-position-K (shifts later modules' weights mechanically). Re-uses
  the existing research.yaml — no new web research. Dispatches the designer for
  the new brief, runs scripts/new-module.sh to bootstrap files, dispatches one
  module-builder, and runs a scoped reviewer.
user_summary: >
  Add a single module to an existing curriculum. Asks about the module's driving
  question and where it should sit, then runs the design + bootstrap + build
  pipeline for just that one module.
version: 0.4.0
argument-hint: "[optional topic or position hint]"
allowed-tools: [Read, Write, Bash, Agent]
---

# /tmb:add-module

Add one module to an existing TMB v0.4 curriculum.

## Files

| File | Loaded when |
|------|-------------|
| `SKILL.md` (this file) | Always |
| `references/spec-elicitation.md` | Phase 1 — the 4-question script + pushback rules + concept cross-check |
| `references/position-handling.md` | Phase 2 — append vs insert-at-K mechanics |
| `references/brief-schema.md` (repo-level) | Phase 3 — designer is producing a new brief |

## Workflow

### Phase 0: Preflight

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-curriculum.sh "$(pwd)"
```

Refuse unless `state` is `v0.4-complete`. (Partial means an unfinished `/tmb:create` — direct the user to resume that first.)

Also confirm `research.yaml` exists. If missing: *"This curriculum was created before v0.4 (no research.yaml). Add-module needs the research substrate. Re-run /tmb:create to migrate."*

### Phase 1: Collect the new module's spec

**Read `references/spec-elicitation.md`.** It has the 4-question script, the pushback rules for vague answers, and the cross-check against `research.yaml.concept_map`.

Output: a structured `new_module_spec` you'll pass to the designer in Phase 3.

### Phase 2: Position handling

**Read `references/position-handling.md`.** It has the append vs insert-at-K branch logic, the weight-shift mechanics, and the user-facing message templates.

Output: a position decision (`position_mode`, `new_weight`, `shift_set`).

### Phase 3: Designer (add-module mode)

```
Agent(
  subagent_type: "tmb-designer",
  prompt: <JSON with mode="add-module", slug, curriculum_root=cwd, new_module_spec, position_mode, shift_set, existing_briefs>
)
```

The designer reads the existing spine + `research.yaml`, writes the new brief (and rewrites shifted briefs if inserting), then runs `bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-briefs.sh "$(pwd)"`.

On gate failure: surface the error and stop. Do not bootstrap or dispatch the builder.

### Phase 4: Bootstrap module files

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/new-module.sh "$(pwd)" "<NN-slug>"
```

`hugo new` + frontmatter patch + mkdir exercises/ + seed VALIDATION.md and new_terms.yaml. Pure shell, no LLM. On failure (e.g., module already exists), surface the error and stop.

### Phase 5: Dispatch a single module-builder

```
Agent(
  subagent_type: "tmb-module-builder",
  prompt: <JSON with brief_path, spine_path, research_path=research.yaml, curriculum_root=cwd, slug>
)
```

The builder fills in the body of `index.md`, the exercise files, the body of `VALIDATION.md`, and `new_terms.yaml`. It does NOT touch frontmatter.

On builder failure, leave the brief in place. The reviewer will flag the build failure; the user can retry.

### Phase 6: Scoped reviewer

```
Agent(
  subagent_type: "tmb-reviewer",
  prompt: <JSON with curriculum_root=cwd, mode="scoped", scope_modules=[...]>
)
```

`scope_modules` for append: `[N-1, N]`. For insert-at-K: every shifted module plus the new one.

### Phase 7: Rebuild

```bash
cd "$(pwd)" && ./build.sh
```

Don't auto-start the server. If they want the change live: `./stop.sh && ./serve.sh`.

## Delivery

```
Added module <weight>: <title>

Review scope: <list>
  - Mechanical fixes: <N>
  - Substantive flags: <K>

Site rebuilt. Restart server to see: ./stop.sh && ./serve.sh
```

## Boundaries

- Exactly one module per invocation.
- Does not modify `research.yaml`, `running_example`, `goal`, or other spine fields.
- Does not drop existing modules.
