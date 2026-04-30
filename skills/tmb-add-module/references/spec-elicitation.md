# Spec elicitation — `/tmb:add-module` Phase 1

Loaded at Phase 1 of `/tmb:add-module` to collect the new module's specification. Holds the question script, pushback rules, and the cross-check against `research.yaml`.

## Question script

Ask one at a time, wait for each answer:

1. *"What's the driving question this module answers?"*
2. *"What are 3–5 concepts this module covers?"* (plain prose, not jargon)
3. *"What's the contrast target — the alternative a practitioner would actually consider instead?"*
4. *"What position? Append (after the last module), or a weight N to insert at?"*

After the four answers, derive:

- `title` — propose a short, plain-language title; confirm with the user.
- `slug` — kebab-case from the title.
- `weight` — from the position (existing-max + 1 for append, the stated `N` for insert).

## Pushback rules

If the user answers vaguely on questions 1, 2, or 3, push back **once**. Examples:

- Vague: "user flow"
  Push: *"'user flow' is vague — what specifically? a login flow? a checkout flow?"*
- Vague: "the database stuff"
  Push: *"What about the database? Query planning? Transactions? Replication?"*
- Vague: "best practices"
  Push: *"Best practices for what specifically? Naming, error handling, deployment?"*

Don't proceed with placeholder fields. The designer will fail the brief gate downstream and the user will get a worse error than if you'd just clarified up front. If the user pushes back a second time without sharpening, abort: *"This needs a more specific scope before I can design a module. Try again with a single concrete question or concept in mind."*

## Drive-by question 4 ("What's a non-rhetorical question?")

If the driving question reads like *"What is X?"* (4 words or fewer, starts with "What is" + capitalized noun), reject and ask again:

> *"That's a definition prompt — fine for a glossary entry, but a module needs a question that has tradeoffs. Try: 'When does X make sense and when doesn't it?' or 'How does X actually work under load?'"*

## Cross-check against `research.yaml.concept_map`

After getting the concepts (question 2), look them up in `research.yaml`:

```bash
yq '.concept_map[] | select(.concept | test("^<concept-name>$"; "i")) | .concept' \
  "<curriculum_root>/research.yaml"
```

For any concept not found, warn:

> *"`<concept>` isn't in research.yaml. The designer will flag this as a research gap rather than guessing the definition. You can re-run `/tmb:create` with broader research, or pick a different concept that's already in the substrate."*

Do NOT silently let the user add a concept that's not in the substrate — every module-builder reads `research.yaml` for canonical definitions, and missing concepts mean the builder can't ground its prose.

## Output of Phase 1

By the end, the orchestrator has a structured `new_module_spec`:

```yaml
title: "..."
slug: "..."
weight: <N>
driving_question: "..."
concepts: [...]    # 3-5 entries, all confirmed against research.yaml
contrast_alternative: "..."
position_mode: "append" | "insert"
```

This is what gets passed to the designer in Phase 3.
