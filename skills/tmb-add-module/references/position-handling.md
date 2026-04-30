# Position handling — `/tmb:tmb-add-module` Phase 2

Loaded at Phase 2 of `/tmb:tmb-add-module` to figure out what `weight` the new module gets and what side-effects that has on existing modules. Two modes: append and insert-at-K.

## Read current state

```bash
ls "<curriculum_root>/briefs"/*.yaml | wc -l    # current module count
yq -r '.weight' "<curriculum_root>/briefs"/*.yaml | sort -n  # current weights
```

The new module's weight comes from the user's Phase 1 answer (`position_mode`).

## Mode: append (`new_weight == max + 1`)

Simplest case. Designer writes only the new brief; no shifts.

The new brief's `prior_ends_with` should be the existing max-weight brief's `next_expects` (so the chain stays intact). The new brief's `next_expects` is "the curriculum's end state" — usually a slight extension of what the previous tail expected.

When dispatching the designer, pass `mode: "add-module"`, `position_mode: "append"`, and the existing max-weight brief's path so the designer can read its `next_expects` for chain continuity.

## Mode: insert-at-K (`new_weight ≤ current_max`)

Every existing brief with `weight ≥ K` shifts by +1. This is mechanical — the designer does it by reading the existing briefs, updating their `weight` field, and rewriting their `prior_ends_with` / `next_expects` fields where adjacency changed.

Specifically:

- New module at K: `prior_ends_with` = (old K-1).next_expects.
- New module at K: `next_expects` = (old K).prior_ends_with → which is now at K+1.
- Old K (now at K+1): `prior_ends_with` updates to new K's `next_expects`.

The reviewer's `check-adjacency.sh` will verify the chain end-to-end after the designer + builder runs.

If Hugo content already exists for shifted modules (it always does in `v0.4-complete` mode), their frontmatter `weight` field needs updating too. The reviewer's `check-frontmatter.sh` flags any drift; the mechanical-fix pass corrects it.

## Tell the user explicitly

For insert-at-K, before dispatching the designer:

> *"Inserting at weight K shifts modules \<K..max\> by +1. Their `prior_ends_with` / `next_expects` strings may need editing — the designer will rewrite them, but if a shifted module's narrative already mentioned 'the previous module' by content (rather than abstractly), the reviewer's adjacency check will flag it for you to clean up manually."*

For append:

> *"Appending at weight \<N\>. No existing modules change."*

## Output of Phase 2

A position decision the orchestrator passes to the designer:

```yaml
position_mode: "append" | "insert"
new_weight: <N>
shift_set: [<slug>, <slug>, ...]    # only populated for insert mode
```

Phase 3 (designer dispatch) takes it from here.
