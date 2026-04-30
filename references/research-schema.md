# research.yaml — schema

Single source of truth for everything the designer and module-builders need to ground their work.

The `tmb-researcher` agent runs once per `/tmb:tmb-create` (and is *not* re-run on `/tmb:tmb-add-module`; the existing file is reused). Every other agent reads from it; nobody else writes to it.

## Why it exists

Without this file, every parallel `tmb-module-builder` would re-do the same web research independently, defining terms inconsistently and citing different URLs. With it, research happens once and the parallel work that follows is a faithful expansion of a shared substrate.

## File location

`<curriculum_root>/research.yaml`

## Schema

```yaml
# Top-level metadata.
topic: "PostgreSQL query planning"          # plain-language topic name
goal: "<from interview step 1, verbatim>"
created: "2026-04-30T13:51:00Z"
researcher_version: "0.4.0"                 # plugin version that produced it

# Canonical glossary. Every module-builder MUST use these definitions
# verbatim (or with trivial whitespace differences) when introducing terms.
glossary:
  - term: "Query plan"
    definition: "The ordered tree of operations the database will execute to satisfy a query."
    aliases: ["execution plan", "plan tree"]
  - term: "Selectivity"
    definition: "Estimated fraction of rows a predicate will return; the planner uses it to choose access paths."
  # ... 15 to 40 entries, depending on topic.

# Authoritative reading list with section anchors. The designer pulls
# from this list when assigning reading.primary / reading.secondary to
# briefs; module-builders cite from here.
sources:
  - title: "PostgreSQL docs — Using EXPLAIN"
    url: "https://www.postgresql.org/docs/current/using-explain.html"
    sections:
      - id: "explain-output"
        anchor: "#using-explain-basics"
        why: "Anatomy of EXPLAIN output line-by-line."
      - id: "buffers"
        anchor: "#using-explain-analyze"
        why: "How to read I/O cost numbers."
    authority: "official-docs"
    last_checked: "2026-04-30"
  - title: "Use The Index, Luke — execution plans"
    url: "https://use-the-index-luke.com/sql/explain-plan"
    sections:
      - id: "intro"
        why: "The most accessible third-party explainer; good for module 1 reading."
    authority: "well-known-third-party"
    last_checked: "2026-04-30"
  # ... 4 to 10 sources.

# Concept map: which concepts exist in this domain, what they depend on.
# The designer uses this to sequence modules — concepts can only depend
# on concepts in earlier modules.
concept_map:
  - concept: "Sequential scan"
    depends_on: []
    appears_in: ["access-paths"]      # module slug suggestion (designer can override)
  - concept: "Index scan"
    depends_on: ["Sequential scan", "B-tree"]
    appears_in: ["access-paths"]
  - concept: "Nested loop join"
    depends_on: ["Index scan"]
    appears_in: ["join-strategies"]

# Common contrasts a practitioner must understand. Designer wires these
# into the per-brief contrast.alternative + contrast.when_alternative_wins.
contrasts:
  - this: "Index scan"
    alternative: "Sequential scan"
    when_alt_wins: "Selectivity > ~10% — full scan is cheaper than index lookups + heap fetches."
    when_this_wins: "Selectivity < ~1% on a large table; the index keeps I/O small."
  - this: "Hash join"
    alternative: "Nested loop join"
    when_alt_wins: "Outer relation is small AND inner has a useful index."
    when_this_wins: "Both relations are large; hash table fits in work_mem."

# Authority list: who/what speaks credibly in this domain. Used by the
# reviewer when flagging reading-list URLs that point at low-credibility
# sources (e.g., random Medium posts when the official docs cover the topic).
authorities:
  - name: "PostgreSQL Documentation"
    url: "https://www.postgresql.org/docs/"
    why: "Primary source. Cite verbatim where possible."
  - name: "Markus Winand — Use The Index, Luke"
    url: "https://use-the-index-luke.com"
    why: "Best plain-language explainer for query planning fundamentals."
  - name: "Bruce Momjian"
    url: "https://momjian.us/main/presentations.html"
    why: "Long-running, deeply technical conference talks."

# Open questions the researcher could not resolve. The orchestrator
# surfaces these to the user before dispatching the designer.
open_questions:
  - "User's PostgreSQL version (different planner heuristics in 12 vs 16). Defaulting to current-stable."
  - "Are advisory-only features (e.g., custom statistics objects) in scope?"
```

## Required fields

The reviewer's preflight (`scripts/validate-research.sh`, called from `tmb-researcher` itself before exit) requires:

- `topic`, `goal`, `created`, `researcher_version` — all non-empty strings.
- `glossary` — at least 5 entries; every entry has `term` and `definition`.
- `sources` — at least 3 entries; every entry has `title`, `url` (http(s)://), and at least one `sections[]` item.
- `concept_map` — at least 5 entries; every entry has `concept` and `depends_on` (may be empty list).
- `contrasts` — at least 2 entries; every entry has all four fields.
- `authorities` — at least 2 entries.

If any check fails, the researcher does not write the file. It returns the gap list to the orchestrator, which surfaces it to the user.

## Lifecycle

| Phase | Reads | Writes |
|---|---|---|
| Interview | — | — |
| `tmb-researcher` | interview answers | `research.yaml` |
| `tmb-designer` | `research.yaml` | `curriculum_spine.md`, `briefs/*.yaml` |
| `tmb-module-builder` × N | `research.yaml`, own brief, spine | module page + exercises + VALIDATION + new_terms |
| `tmb-reviewer` | `research.yaml` (for canonical defs), all briefs, all pages | `glossary.md`, `review.md`, mechanical fm fixes |

After `/tmb:tmb-create` finishes, `research.yaml` is read-only ground truth. `/tmb:tmb-add-module` reads but does not modify it. If the researcher's findings need updating (a source moved, a term changed meaning), the user re-runs `/tmb:tmb-create` from a fresh directory — there is no "refresh research" subcommand in v0.4.

## Why the file matters for parallel module-builders

Each `tmb-module-builder` is dispatched in parallel and never reads sibling modules. Without `research.yaml`, two builders writing about "selectivity" would each define the term in their own words, and the reviewer would flag the divergence as a glossary conflict. With `research.yaml`, every builder uses the same definition by lookup, and conflicts only happen when a builder genuinely innovates on a term — which the reviewer can flag substantively rather than mechanically.
