# Curriculum state branches — `/tmb:create` Phase 2

Loaded at Phase 2 of `/tmb:create` after `scripts/detect-curriculum.sh` returns. Holds the per-state branch logic so the SKILL workflow stays a one-liner.

## The detector output

```json
{
  "state": "fresh" | "v0.4-complete" | "v0.4-partial" | "v0.3-complete" | "v0.3-partial" | "v0.2" | "non-tmb",
  "module_count": <N>,
  "missing_pages": [<slug>, ...]
}
```

`missing_pages` is populated only on `*-partial` states.

## Branches

### `fresh`

```bash
mkdir -p "<target>"
```

Continue to Phase 3 (research).

### `v0.4-partial`

A previous `/tmb:create` was interrupted between scaffold and reviewer. Offer resume — print a one-line preface, then call `AskUserQuestion`:

> *"Quick confirmation: Found an in-progress v0.4 curriculum at `<target>` with `<missing_pages.length>` modules missing (`<missing_pages joined>`)."*

```
question: "Resume the existing build, or stop here?"
header:   "Resume"
multiSelect: false
options:
  - label: "Resume"
    description: "Re-run only the missing module-builders against the existing scaffold."
  - label: "Stop here"
    description: "Don't touch the folder — I'll move or rename it and re-run /tmb:create."
```

- Resume → carry `missing_pages` forward; skip Phase 3 (research already done) and Phase 4 (design already done) and Phase 5 (scaffold already done). Jump to Phase 6, calling `new-module.sh` only for the missing slugs (the script refuses to clobber, so it's safe to call against existing modules — they'll be no-ops).
- Stop here → abort: *"OK — move or delete `<target>` and re-run /tmb:create when ready."*

### `v0.4-complete`

```
"<target>" already has a complete v0.4 curriculum. /tmb:create is for fresh
builds. To modify it, use:
  /tmb:add-module    add a new module
  /tmb:review        re-run the consistency reviewer
  /tmb:rebuild-site  refresh layouts and rebuild
```

Abort.

### `v0.3-complete` or `v0.3-partial`

```
"<target>" is a v0.3 curriculum. v0.4 introduces research.yaml as a hard
prerequisite for the design and module-builder phases — there is no automatic
upgrade because the canonical glossary, sourced reading list, and concept map
cannot be reverse-engineered from existing module pages.

Options:
  1. Move <target> aside and run /tmb:create fresh in a new directory.
  2. Stay on v0.3 (the v0.3 plugin tag still works).

See CHANGELOG.md v0.4 notes for migration discussion.
```

Abort.

### `v0.2`

```
"<target>" is a v0.2 curriculum (modules/NN-slug/README.md is the canonical
content). Neither v0.3 nor v0.4 has automatic migration from v0.2 — per-module
READMEs were replaced by Hugo content pages.

Options:
  1. Move <target> aside and run /tmb:create fresh.
  2. Stay on v0.2 (the v0.2 plugin tag still works).
```

Abort.

### `non-tmb`

```
"<target>" already exists and isn't a TMB curriculum. Rename it or pick
another parent directory.
```

Abort.

## Why this is a separate file

The branch table is reference material — only relevant *after* the detector runs and *only* if the user is pointing at a non-fresh directory. The common case (`fresh`) is one line, and the SKILL workflow shouldn't carry six other branches inline for every curriculum build.
