#!/usr/bin/env bash
# new-module.sh — Bootstrap a single module's filesystem layout from its brief.
#
# v0.4.3 content model: each module is a Hugo branch bundle so its concept,
# validation, and exercises all get real URLs.
#
#   site/content/modules/<slug>/_index.md           # concept page
#   site/content/modules/<slug>/validation.md       # validation page
#   site/content/modules/<slug>/exercises/_index.md # exercises section
#   modules/<slug>/new_terms.yaml                   # data file (not Hugo content)
#
# What this script does (deterministically — no LLM in this loop):
#   1. cd into <curriculum_root>/site and run `hugo new modules/<slug>/_index.md`
#      using archetypes/modules.md to seed frontmatter.
#   2. Patch every brief-sourced frontmatter field with values from briefs/<slug>.yaml.
#   3. `hugo new` for validation.md and exercises/_index.md, also frontmatter-patched.
#   4. Seed validation.md body with brief.validation_scenario and contrast prompt.
#   5. Seed modules/<slug>/new_terms.yaml as `[]` (data file the reviewer reads).
#
# After this returns, the module-builder agent only writes BODY content into
# the existing files (and creates individual exercise pages in exercises/).
# It must NOT modify frontmatter — the reviewer's check-frontmatter.sh enforces.
#
# Usage: bash scripts/new-module.sh <curriculum_root> <slug>
#
# Output: JSON with the paths the agent should fill in:
#   { ok: bool,
#     concept_md:    "<root>/site/content/modules/<slug>/_index.md",
#     validation_md: "<root>/site/content/modules/<slug>/validation.md",
#     exercises_dir: "<root>/site/content/modules/<slug>/exercises/",
#     new_terms_yaml:"<root>/modules/<slug>/new_terms.yaml" }
#
# Exit 0 on success; 1 if any file already exists; 2 on usage / setup error.

set -euo pipefail

ROOT="${1:-}"
SLUG="${2:-}"
[ -z "$ROOT" ] || [ -z "$SLUG" ] && { echo '{"ok":false,"error":"usage: new-module.sh <root> <slug>"}' >&2; exit 2; }

command -v hugo >/dev/null || { echo '{"ok":false,"error":"hugo not found"}' >&2; exit 2; }
command -v yq   >/dev/null || { echo '{"ok":false,"error":"yq not found"}'   >&2; exit 2; }
command -v jq   >/dev/null || { echo '{"ok":false,"error":"jq not found"}'   >&2; exit 2; }

BRIEF="$ROOT/briefs/$SLUG.yaml"
SITE="$ROOT/site"
MOD_BUNDLE="$SITE/content/modules/$SLUG"
CONCEPT="$MOD_BUNDLE/_index.md"
VALIDATION="$MOD_BUNDLE/validation.md"
EX_INDEX="$MOD_BUNDLE/exercises/_index.md"
EX_DIR="$MOD_BUNDLE/exercises"
NT_DIR="$ROOT/modules/$SLUG"
NT="$NT_DIR/new_terms.yaml"

[ -f "$BRIEF" ] || { echo "{\"ok\":false,\"error\":\"$BRIEF missing\"}" >&2; exit 2; }
[ -d "$SITE" ]  || { echo "{\"ok\":false,\"error\":\"$SITE missing — run scaffold-site.sh first\"}" >&2; exit 2; }

# Refuse to clobber.
for f in "$CONCEPT" "$VALIDATION" "$EX_INDEX" "$NT"; do
  if [ -e "$f" ]; then
    jq -nc --arg p "$f" '{ok: false, error: ("file already exists: " + $p)}'
    exit 1
  fi
done

# Helper: split a Hugo-generated file into its frontmatter and body parts.
# Writes frontmatter to $1, body to $2, reads from $3.
split_fm_body() {
  awk -v fm="$1" -v body="$2" '
    /^---$/ { c++; if (c==1) {next}; if (c==2) {next} }
    c==1 { print > fm; next }
    { print > body }
  ' "$3"
}

# Helper: reassemble a fronmatter file + body file into a single markdown file.
write_with_fm() {
  local fm="$1" body="$2" out="$3"
  {
    printf -- '---\n'
    cat "$fm"
    printf -- '---\n'
    cat "$body"
  } > "$out"
}

# ── 1. Concept page (_index.md) ──────────────────────────────
(cd "$SITE" && hugo new --kind modules "modules/$SLUG/_index.md" >/dev/null)

FM=$(mktemp); BODY=$(mktemp)
trap 'rm -f "$FM" "$BODY"' EXIT
split_fm_body "$FM" "$BODY" "$CONCEPT"

TITLE=$(yq '.title' "$BRIEF")
WEIGHT=$(yq '.weight' "$BRIEF")
DQ=$(yq '.driving_question' "$BRIEF")
CONTRAST_ALT=$(yq '.contrast.alternative' "$BRIEF")
CONTRAST_WHEN=$(yq '.contrast.when_alternative_wins' "$BRIEF")
PRIOR=$(yq '.prior_ends_with' "$BRIEF")
NEXT=$(yq '.next_expects' "$BRIEF")
CONCEPTS_YAML=$(yq -o=json '.concepts' "$BRIEF" | jq -c '.')

yq -i ".title = \"$TITLE\"" "$FM"
yq -i ".weight = $WEIGHT" "$FM"
yq -i ".driving_question = \"$DQ\"" "$FM"
yq -i ".contrast.alternative = \"$CONTRAST_ALT\"" "$FM"
yq -i ".contrast.when_alternative_wins = \"$CONTRAST_WHEN\"" "$FM"
yq -i ".prior_ends_with = \"$PRIOR\"" "$FM"
yq -i ".next_expects = \"$NEXT\"" "$FM"
# Leave summary empty — it's an OPTIONAL one-sentence framing that adds info
# beyond the driving question. Module-builders can fill it in when they have
# something useful to say; otherwise the layout skips the field. Pre-v0.4.8
# defaulted summary = driving_question, which produced a duplicate render.
yq -i '.summary = ""' "$FM"
yq -i ".concepts = $CONCEPTS_YAML" "$FM"

write_with_fm "$FM" "$BODY" "$CONCEPT"

# ── 2. Validation page ────────────────────────────────────────
(cd "$SITE" && hugo new --kind validation "modules/$SLUG/validation.md" >/dev/null)

# Replace the placeholder body with a seeded structure.
SCENARIO=$(yq '.validation_scenario' "$BRIEF")
VAL_FM=$(mktemp); VAL_BODY=$(mktemp)
split_fm_body "$VAL_FM" "$VAL_BODY" "$VALIDATION"
yq -i ".title = \"Validation: $TITLE\"" "$VAL_FM"
yq -i ".weight = 100" "$VAL_FM"   # validation always sorts last among section pages

cat > "$VAL_BODY" <<EOF

## Scenario

$SCENARIO

## Good answer covers

<!-- builder: fill from brief.validation_scenario "Good answer covers" list -->

## If asked "why not $CONTRAST_ALT?"

<!-- builder: short answer grounded in the contrast section -->

## Try it aloud

Set a timer for 90 seconds. Cover the notes. Answer the scenario out loud. If
you stumble on a specific concept, re-read that concept's paragraph in the
module page and try again.
EOF

write_with_fm "$VAL_FM" "$VAL_BODY" "$VALIDATION"
rm -f "$VAL_FM" "$VAL_BODY"

# ── 3. Exercises section index ────────────────────────────────
mkdir -p "$EX_DIR"
cat > "$EX_INDEX" <<EOF
---
title: "Exercises: $TITLE"
weight: 90
draft: false
---

Hands-on tasks for this module. Each exercise has a starter scaffold with
\`[TODO:]\` markers — fill them in and run the verification step.
EOF

# ── 4. new_terms.yaml (data file, not Hugo content) ───────────
mkdir -p "$NT_DIR"
echo '[]' > "$NT"

# ── Output ────────────────────────────────────────────────────
jq -nc \
  --arg c "$CONCEPT" \
  --arg v "$VALIDATION" \
  --arg ex "$EX_DIR" \
  --arg nt "$NT" \
  '{ok: true, concept_md: $c, validation_md: $v, exercises_dir: $ex, new_terms_yaml: $nt}'
