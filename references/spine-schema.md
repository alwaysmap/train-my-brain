# Curriculum spine schema

The `curriculum_spine.md` file at the curriculum root captures the shared context every module-builder needs. It is written once during the design phase and read (never written) by every downstream agent.

## Schema

```yaml
---
topic: "Volcanic eruption mechanics"
slug: "volcanic-eruptions"
goal: "Be able to hold a technical conversation with a volcanologist about what drives explosive vs effusive eruptions and why."
tested_via:
  - interview
  - customer_conversation
audience_starting_point: "Knows adjacent Earth-science vocabulary (stratigraphy, plate tectonics) but has not studied igneous petrology."
depth_vs_breadth: "deep"    # wide | deep | middle
validation_preferences:
  - questions_out_loud
  - hands_on_exercise
  - blog_post
timeline: "a few months"
tools_present:
  - python_3
  - jupyter
hue: 25                      # 0..360, feeds site/hugo.yaml params.hue
running_example:
  name: "Mount Vesuvius 79 AD"
  description: "A well-documented stratovolcano eruption the learner anchors every concept against."
  introduced_in_module: 1
module_count: 7
glossary_seed:
  - term: "Magma"
    definition: "Molten rock beneath the Earth's surface; includes dissolved gases and may contain suspended crystals."
  - term: "Lava"
    definition: "Magma that has reached the surface and lost most of its dissolved gases."
---

# Spine narrative

<optional free-prose section where the designer can record assumptions,
tradeoffs considered, or notes for the reviewer — NOT module content>
```

## Interview → spine mapping (R29)

The 7-step interview's answers map into the spine:

| Step | Question | Spine field |
|---|---|---|
| 1 | The real goal | `goal` |
| 2 | How they'll be tested | `tested_via` (multi-select) |
| 3 | Starting point | `audience_starting_point` |
| 4 | Depth vs breadth | `depth_vs_breadth` |
| 5 | Validation preference | `validation_preferences` (multi-select) |
| 6 | Time + tools | `timeline`, `tools_present` |
| 7 | Favorite color | `hue` (via color→HSL table) |

The designer synthesizes `running_example` from Step 1 + Step 3 per R30. If the user named a specific project or domain in the interview, use that; otherwise propose a concrete small running example that survives every module.

Module count `N` is chosen by the designer from `timeline` × `depth_vs_breadth`:

| timeline | wide | middle | deep |
|---|---|---|---|
| few weeks | 5 | 6 | 5 |
| a few months | 9 | 7 | 7 |

These are defaults — the designer may deviate with a note in the narrative section. Ranges outside 5..10 require explicit justification.

## Glossary seed

`glossary_seed` lists terms the interview surfaced or that are load-bearing from the first module. Module-builders read the seed and do NOT redefine those terms inline — they use them freely. New terms introduced during building go in per-module `new_terms.yaml` side-files (see `reviewer-policy.md` for how the reviewer merges them).

## Why a separate spine file

Briefs are per-module and self-contained. The spine holds everything that's shared: running example, glossary state, audience, theme. Putting it in briefs would either duplicate (every brief repeats the spine) or fragment (each brief gets a slice and builders can't cross-reference).

The spine is read-only after the design phase. If a builder encounters a spine gap (e.g., a term not in the glossary_seed that it needs to reference), it records the term in its own `new_terms.yaml` — it does not modify the spine.
