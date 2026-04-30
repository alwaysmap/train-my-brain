# Per-module brief schema

Each module in a TMB curriculum has a brief at `briefs/NN-slug.yaml`. The designer agent writes it; the module-builder agent reads it; the reviewer agent validates it. Briefs are load-bearing — they are the coordination mechanism that makes parallel module building safe.

## Schema

```yaml
# briefs/03-silica-viscosity.yaml
weight: 3
title: "Silica and viscosity"
driving_question: "Why does more silica make an eruption explosive rather than just slower?"
concepts:
  - silica polymerization
  - viscosity as molecular drag
  - gas retention under pressure
contrast:
  alternative: "basalt shield volcanoes"
  when_alternative_wins: "long-duration effusive flows (Hawaii) dissipate gas continuously and rarely go explosive"
reading:
  primary:
    url: "https://volcanoes.usgs.gov/vhp/magma.html"
    section: "Composition and viscosity"
  secondary:
    url: "https://www.nature.com/articles/s41598-019-50458-9"
    section: "Abstract and Figure 2"
exercise_goal: |
  Learner simulates dissolved-gas release from a rising magma column. Given a
  starting pressure and temperature, compute the point at which exsolution
  begins and the gas volume fraction at venting. TODO markers at:
    - [TODO: implement the solubility curve for H2O in silicate melt]
    - [TODO: implement the pressure-decay function along the ascent path]
    - [TODO: compute gas-volume fraction at P_vent]
validation_scenario: |
  A geologist describes a pumice deposit as "clast-supported, poorly sorted,
  angular fragments in a fine matrix."
  Good answer covers:
    - Plinian-style column + collapse explains the sorting
    - Pumice signals high silica magma (trapped vesicles)
    - "Angular" rules out long-distance reworking
    - Honest mention: without context, could be a pyroclastic surge deposit
prior_ends_with: "The learner has grouped magmas by composition (felsic vs mafic) and knows silica percentages by name."
next_expects: "The learner understands why viscosity drives explosive vs effusive eruptions, and is ready to see how dissolved gas pressure shapes the column."
```

## Field definitions

| Field | Type | Required | Notes |
|---|---|---|---|
| `weight` | integer | yes | 1..N position in the curriculum. Unique per curriculum. |
| `title` | string | yes | Human-readable module title. Copied verbatim into Hugo frontmatter. |
| `driving_question` | string | yes | Non-rhetorical question the module answers. No vague "explore" phrasing. |
| `concepts` | list[string] | yes (3–5 items) | Named concepts in plain prose, not jargon. |
| `contrast.alternative` | string | yes | The comparison target — an alternative approach, competing model, or adjacent concept. |
| `contrast.when_alternative_wins` | string | yes | One-sentence honest statement of when the alternative is better. Curriculum-design Rule: every contrast table has at least one row where the alternative wins. |
| `reading.primary.url` | string | yes | Official documentation, original paper, or specification. |
| `reading.primary.section` | string | yes | What to read (not "the docs" — a specific section). |
| `reading.secondary.url` | string | yes | Tutorial, case study, blog post. |
| `reading.secondary.section` | string | yes | What to read. |
| `exercise_goal` | string | yes | Block text. Must include at least two `[TODO: <specific thing>]` markers — the learner's fill-in points. Boilerplate is fine; thinking points are TODO. |
| `validation_scenario` | string | yes | Block text. A scenario prompt plus a "Good answer covers:" list. Never "name the three types of X" recall questions — always a mechanism-explanation prompt. |
| `prior_ends_with` | string | yes | One sentence. The state the previous module leaves the learner in. For module 1 this is the learner's starting-point state from the interview. |
| `next_expects` | string | yes | One sentence. The state this module is expected to leave the learner in so module N+1 can start cleanly. For module N this is the curriculum's end-state goal. |

## Completeness gate (R6a)

Before dispatching any module builder, the designer agent validates every brief:

- No null fields.
- No `TBD`, `???`, or empty string values.
- `concepts` has between 3 and 5 items.
- `reading.primary` and `reading.secondary` URLs are HTTP(S) URLs (no `[TODO: find URL]` markers — those are caught by the reviewer at write time, but the designer must not emit them).
- `exercise_goal` contains at least two `[TODO:` markers.

If any brief fails, `/tmb:tmb-create` aborts with a clear error listing every gap in every brief. The designer does not dispatch builders with incomplete context.

## Why briefs, not prose

A module builder receiving a brief can write its content without reading any sibling module. That is the only reason parallel dispatch is safe. The cost is that briefs pre-bake narrative continuity as declared intent — module N's `prior_ends_with` must match module N-1's `next_expects`, both written at design time. The reviewer validates this match after builders finish (R12 adjacency flag).

The brief is the smallest artifact that, when complete, guarantees a coherent module. Its fields map 1:1 to the pedagogical rules in `curriculum-design.md`: driving question = question-first README; concepts = tiered knowledge model; contrast = honest comparison table; reading = mandatory references with section pointers; exercise_goal = active exercise with TODO hooks; validation_scenario = understanding-not-recall; prior/next = spine continuity.
