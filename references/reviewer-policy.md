# Reviewer policy

The `tmb-reviewer` agent runs after builders finish (in `/tmb:tmb-create`), on demand (via `/tmb:tmb-review`), and on a targeted subset after `/tmb:tmb-add-module`. It auto-fixes mechanical issues and flags substantive issues for user approval. This file is its authoritative policy.

## Two classes of issue

A finding is **mechanical** when the correct fix is unambiguous and does not alter prose meaning. A finding is **substantive** when the fix changes prose meaning, requires authorial judgment, or has more than one reasonable resolution.

The test is not "how important?" but "is there more than one reasonable way to fix this?"

## Mechanical auto-fixes (no approval needed)

| Issue | Fix | Why mechanical |
|---|---|---|
| Frontmatter field missing that is present in the brief or spine | Copy the value from the authoritative source | One correct value exists |
| Frontmatter field has wrong type (e.g., `weight` is a string) | Cast to the archetype's declared type | Archetype schema is authoritative |
| Two modules collide on `weight` | Reorder: the module whose brief has the lower original weight keeps it; the other shifts to weight+1 and so on | Deterministic |
| Glossary term introduced in `new_terms.yaml` with identical definitions across multiple modules | Merge to one entry in `glossary.md` | Identical definitions are one entry |
| Relative link written as an absolute path (`/site/...`) | Rewrite as site-relative (`../NN-slug/`) | Hugo link format |
| Markdown link written as angle-bracket (`<URL>`) in prose | Rewrite as `[text](URL)` if context makes text obvious; else leave and flag | Style normalization |
| Module missing `status`, `date`, or `draft` in frontmatter | Fill with archetype defaults (`planned`, today's date, `false`) | Archetype defaults |

## Substantive flags (wait for user approval)

Substantive issues are written to `review.md` as numbered items with an `approved: null` field. The user edits the file to set `approved: true` on issues they want applied, leaves `approved: null` on ones they want to think about, or sets `approved: false` to dismiss. On a re-run, the reviewer applies approved fixes and updates `review.md` flag state.

| Issue | What the reviewer flags | Why substantive |
|---|---|---|
| Missing or weak contrast section | Module lacks a comparison table, or the table has no row where the alternative wins | Writing a contrast section requires pedagogical judgment |
| Missing, vague, or trivially answerable driving question | Frontmatter `driving_question` is empty, generic ("What is X?"), or answerable in one word | Rewriting requires understanding the module's scope |
| Adjacency handoff mismatch | Module N's `next_expects` does not match module N+1's `prior_ends_with` (string diff after whitespace normalization) | Resolving the mismatch requires choosing which side is right |
| Running-example absence | A module that should anchor on the spine's `running_example` does not reference it | Whether a module "should" anchor is judgment |
| Reading URL returns non-2xx on HEAD check | `curl -I -sSL --max-time 5 -o /dev/null -w "%{http_code}"` returned 404/410/5xx | Replacement URL requires research |
| `[TODO: find URL]` marker in the reading list | Designer emitted a placeholder the builder did not resolve | Needs a real URL |
| Glossary definition conflict (R32) | Two or more `new_terms.yaml` files define the same term with divergent text | Picking a canonical definition requires judgment; flag both, do not auto-merge |
| AI-prose violation | Throat-clearing opener ("In this module, we will explore..."), fake enthusiasm ("exciting", "powerful"), consulting-speak ("synergy", "holistic") — detected by regex heuristics | False positives are expected; user review protects content |
| Brief contradiction in prose | The Hugo content prose contradicts a specific brief constraint (e.g., `exercise_goal` says "simulate gas release" but the exercise is about stratigraphy) | Directional — brief is ground truth for adjacency fields; prose is ground truth for wording. Flag only when prose contradicts brief constraints, not when prose adds detail the brief didn't specify (R34) |
| Module failed to build (from R8a) | A builder agent errored or timed out; module is missing or partial | Requires a re-dispatch decision |

## Drift direction (R34)

When `/tmb:tmb-review` runs against a hand-edited curriculum:

- **Briefs are ground truth for frontmatter adjacency fields** (`driving_question`, `concepts`, `contrast`, `prior_ends_with`, `next_expects`, `weight`, `title`). If prose frontmatter differs from the brief, the reviewer flags "frontmatter drifted from brief" as substantive.
- **Prose is ground truth for content**. The reviewer does not rewrite prose to match the brief. It only flags prose that *contradicts* the brief's hard constraints.

## `review.md` format

```markdown
# Review: <curriculum slug>

Generated: <ISO timestamp>
Mechanical fixes applied: <N>
Substantive flags: <K> (waiting for user approval)

## Mechanical fixes

- mod-02 frontmatter: added missing `status: planned`
- mod-04 weight: collided with mod-03; shifted to 5
- glossary.md: merged "magma" (3 identical definitions)

## Substantive flags

### 1. mod-03 driving question is vague
approved: null
detail: |
  Current: "What is silica?"
  Why flagged: answerable in one word; not a driving question.
  Suggested fix: none — needs author rewrite.

### 2. mod-05 → mod-06 adjacency mismatch
approved: null
detail: |
  mod-05 next_expects: "learner can compute exsolution point"
  mod-06 prior_ends_with: "learner has grouped magmas by composition"
  Why flagged: strings differ substantively.
  Suggested fix: edit one to match the other.
```

## Reviewer crash containment (R37)

If the reviewer errors mid-pass, the orchestrator does not halt the broader pipeline. `/tmb:tmb-create` proceeds to `./build.sh` and delivery; `review.md` contains whatever the reviewer had written before it crashed, with a footer: `review failed — re-run /tmb:tmb-review manually to complete`. Builder outputs are never discarded because of reviewer failure.

## `/tmb:tmb-review` preconditions

- `curriculum_spine.md` must exist at the cwd.
- `briefs/` must exist with at least one `NN-slug.yaml`.

If either is missing, the reviewer errors with: *"This directory does not look like a TMB v0.3 curriculum. The spine and briefs files are required. If this is a v0.2 curriculum (with modules/NN-slug/README.md files), see CHANGELOG.md v0.3 notes — there is no automatic migration."*
