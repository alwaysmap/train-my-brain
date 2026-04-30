---
name: tmb-add-module
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
| `references/brief-schema.md` | Phase 3 — designer is producing a new brief |
| `references/curriculum-design.md` | Phase 1 — pushing back on vague answers |
| `references/research-schema.md` | Phase 1 — cross-checking concepts against research.yaml |

## Phase 0: Preflight

```bash
bash scripts/check-deps.sh
bash scripts/detect-curriculum.sh "$(pwd)"
```

Refuse unless the JSON `state` is `v0.4-complete`. (Partial means an unfinished `/tmb:create` — direct the user to resume that first.)

Also confirm `research.yaml` exists. If missing, refuse: *"This curriculum was created before v0.4 (no research.yaml). Add-module needs the research substrate. Re-run /tmb:create to migrate."*

## Phase 1: Collect the new module's spec

Ask the user one question at a time:

1. *"What's the driving question this module answers?"* (non-rhetorical, not "What is X?")
2. *"What are 3–5 concepts this module covers?"* (plain prose, not jargon)
3. *"What's the contrast target — the alternative a practitioner would actually consider instead?"*
4. *"What position? Append, or a weight N to insert at?"*

Push back once on vague answers. Don't proceed with placeholder fields.

Cross-check the user's concepts against `research.yaml.concept_map`. If a concept isn't in research.yaml, warn: *"<concept> isn't in research.yaml. The designer will flag this as a research gap rather than guessing. Re-run /tmb:create with broader research, or pick a different concept."*

## Phase 2: Position handling

Read `briefs/*.yaml` to determine current max weight and existing weights.

**Append (new_weight == max + 1):** designer writes only the new brief.

**Insert-at-K (new_weight ≤ current max):** the designer must shift every existing brief with `weight ≥ K` by +1, AND rewrite the adjacency strings on shifted briefs so the chain stays coherent. The reviewer's `check-adjacency.sh` will catch any drift.

Tell the user explicitly when inserting: *"Inserting at weight K shifts modules <K..max>. Their `prior_ends_with` / `next_expects` strings may need editing. The reviewer will flag any chain break."*

## Phase 3: Designer (add-module mode)

```
Agent(
  subagent_type: "tmb-designer",
  prompt: <JSON with mode="add-module", slug, curriculum_root=cwd, new_module_spec, existing_briefs>
)
```

The designer reads the existing spine and `research.yaml`, writes the new brief (and rewrites shifted briefs if inserting), then runs `bash scripts/validate-briefs.sh "$(pwd)"`.

If the gate fails, surface the error and stop. Do not bootstrap or dispatch the builder.

## Phase 4: Bootstrap module files

```bash
bash scripts/new-module.sh "$(pwd)" "<NN-slug>"
```

This runs `hugo new modules/<slug>/index.md` (using the archetype), patches the frontmatter from the new brief, creates `modules/<slug>/exercises/`, and seeds `VALIDATION.md` and `new_terms.yaml`. Pure shell — no LLM in this loop.

If it fails (e.g., module already exists), surface the error and stop.

## Phase 5: Dispatch a single module-builder

```
Agent(
  subagent_type: "tmb-module-builder",
  prompt: <JSON with brief_path, spine_path, research_path=research.yaml, curriculum_root=cwd, slug>
)
```

The builder fills in the body of `index.md`, the exercise files, the body of `VALIDATION.md`, and `new_terms.yaml` entries. It does NOT touch frontmatter (already deterministic).

If the builder fails, leave the brief in place and let the reviewer flag the build failure. The user can retry.

## Phase 6: Scoped reviewer

```
Agent(
  subagent_type: "tmb-reviewer",
  prompt: <JSON with curriculum_root=cwd, mode="scoped", scope_modules=[...]>
)
```

For append: `scope_modules = [N-1, N]`. For insert-at-K: every shifted module plus the new one.

## Phase 7: Rebuild

```bash
cd "$(pwd)" && ./build.sh
```

Don't auto-start the server — the user may already have one. If they want the change live: `./stop.sh && ./serve.sh`.

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
