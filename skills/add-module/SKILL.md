---
name: add-module
description: Adds one module to an existing TMB curriculum. Supports append (default) and insert-at-position-K (shifts later modules' weights mechanically). Dispatches the designer for the new brief, one module-builder, and a scoped reviewer over the new module plus its adjacency neighbors. Rebuilds the site after success.
when_to_use: >
  The user asks to add a module to an existing curriculum. Trigger phrases: "/tmb:add-module",
  "add a module", "insert a module at position N", "extend the curriculum".
argument-hint: <optional topic or position hint — an interactive prompt collects details>
allowed-tools: [Read, Write, Bash, Agent]
---

# /tmb:add-module

Add one module to an existing TMB v0.3 curriculum. Supports append and insert-at-K.

## Preconditions

Same as `/tmb:review`:

```bash
[ -f curriculum_spine.md ] && [ -d briefs ] && [ -d site/content/modules ]
```

If missing, print the same v0.2-or-not-a-curriculum error and stop.

## Phase 1: Collect the new module's spec

Ask the user (one question at a time, wait for each answer):

1. *"What's the driving question this module answers?"* (non-rhetorical, not "What is X?")
2. *"What are 3–5 concepts this module covers?"* (plain prose, not jargon)
3. *"What's the contrast target — the alternative a practitioner would actually consider instead?"*
4. *"What position in the curriculum should this be? (Append = after the last module, or a weight N to insert at)"*

Derive:
- `title` (short, descriptive — can be proposed by you, confirmed by user)
- `slug` (kebab-case from title)
- `weight` (from position; existing max + 1 for append, the stated N for insert)

If the user answers vaguely on any of 1–3, push back once ("'user flow' is vague — what specifically? a login flow? a checkout flow?"). Do not proceed with placeholder fields.

## Phase 2: Position handling

Read `briefs/*.yaml` to determine current max weight and existing weights.

### Append (new_weight == max + 1)

- Designer dispatch writes only the new brief.
- Existing briefs unchanged.
- Set the new brief's `prior_ends_with` = existing max weight module's `next_expects`.
- Set the new brief's `next_expects` = something sensible for the curriculum end state (or ask user if unclear).

### Insert-at-K (new_weight <= current max)

- Shift every existing brief with `weight >= K` by +1 (mechanical).
- Dispatch the designer with the updated briefs state (pass the current briefs as context so it can re-derive adjacency for the shifted modules).
- After designer returns, the new brief is at weight K; old module K is now K+1, etc.
- Verify adjacency chain:
  - module K-1's `next_expects` must equal new module K's `prior_ends_with`.
  - New module K's `next_expects` must equal what was old module K's `prior_ends_with` (now at K+1).
  - The reviewer will flag any mismatch.
- If Hugo files already exist for shifted modules, update their frontmatter `weight` (mechanical fix — can be done by the reviewer in Phase 5, or update here directly).
- Tell the user explicitly: *"Inserting at weight K means modules <K..max> shifted. Their `prior_ends_with` / `next_expects` hand-off strings may need editing. The reviewer will flag any that drifted."*

## Phase 3: Dispatch the designer (brief only)

```
Agent(
  subagent_type: "tmb-designer",
  prompt: <JSON with mode: "add-module", slug, curriculum_root, new_module_spec, existing_briefs>
)
```

The designer reads the existing spine (not modified) and existing briefs, then writes the new `briefs/NN-slug.yaml`. If insert-at-K, it also rewrites adjacency fields on shifted briefs. Completeness gate runs on the new brief + any modified briefs.

On gate failure, surface the error and stop. Do not dispatch the builder or touch Hugo content.

## Phase 4: Dispatch a single module-builder

```
Agent(
  subagent_type: "tmb-module-builder",
  prompt: <JSON with brief_path=briefs/NN-slug.yaml, spine_path, curriculum_root, slug>
)
```

If the builder fails, leave the brief in place (it's valid) and flag a build_failure for the reviewer to pick up. The user can retry with another `/tmb:add-module` call.

## Phase 5: Scoped reviewer

Dispatch the reviewer with `mode: "scoped"` and `scope_modules` set to the new module + its adjacency neighbors. For append: `[N-1, N]`. For insert-at-K: `[K-1, K, K+1, K+2, ..., max]` (every module with a weight that changed).

```
Agent(
  subagent_type: "tmb-reviewer",
  prompt: <JSON with curriculum_root, mode: "scoped", scope_modules: [...]>
)
```

The reviewer checks adjacency handoffs, frontmatter correctness (shifted weights), glossary merge for the new module's `new_terms.yaml`, and URL reachability for the new brief.

## Phase 6: Rebuild

```bash
cd "<curriculum_root>" && ./build.sh
```

Don't auto-start the server — the user may already have one running. If they want to see the change: `./stop.sh && ./serve.sh` restarts with the new module.

## Delivery

Short message:

```
Added module <weight>: <title>

Review scope: <list>
  - Mechanical fixes: <N>
  - Substantive flags: <K>

Site rebuilt. Restart server to see: ./stop.sh && ./serve.sh
```

## Boundaries

- Exactly one module added per invocation. If the user wants two, they run the skill twice.
- Does not modify the running example, curriculum goal, or other spine fields.
- Does not drop existing modules. If the user wants to replace a module, they remove and re-add manually (out of scope for v0.3).
