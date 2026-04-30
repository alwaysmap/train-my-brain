#!/usr/bin/env bash
# new-module.sh — Bootstrap a single module's filesystem layout from its brief.
#
# What it does (deterministically — no LLM in this loop):
#   1. cd into <curriculum_root>/site and run `hugo new modules/<slug>/index.md`,
#      which uses archetypes/modules.md to seed the frontmatter.
#   2. Patch every brief-sourced frontmatter field with values from briefs/<slug>.yaml.
#   3. Create modules/<slug>/exercises/ (empty — agent fills in exercise files).
#   4. Seed modules/<slug>/VALIDATION.md from a template, with brief.validation_scenario
#      already inlined.
#   5. Seed modules/<slug>/new_terms.yaml as `[]` so the agent can append.
#
# After this script returns, the module-builder agent only writes BODIES, never
# frontmatter. That eliminates an entire class of frontmatter-drift bugs.
#
# Usage: bash scripts/new-module.sh <curriculum_root> <slug>
#
# Output: JSON to stdout with the four paths the agent should fill in:
#   { ok: bool,
#     index_md: "...",
#     exercises_dir: "...",
#     validation_md: "...",
#     new_terms_yaml: "..." }
#
# Exit 0 on success; 1 if any file already exists (idempotent caller can detect);
# 2 on usage / setup error.

set -euo pipefail

ROOT="${1:-}"
SLUG="${2:-}"
[ -z "$ROOT" ] || [ -z "$SLUG" ] && { echo '{"ok":false,"error":"usage: new-module.sh <root> <slug>"}' >&2; exit 2; }

command -v hugo >/dev/null || { echo '{"ok":false,"error":"hugo not found"}' >&2; exit 2; }
command -v yq   >/dev/null || { echo '{"ok":false,"error":"yq not found"}'   >&2; exit 2; }
command -v jq   >/dev/null || { echo '{"ok":false,"error":"jq not found"}'   >&2; exit 2; }

BRIEF="$ROOT/briefs/$SLUG.yaml"
SITE="$ROOT/site"
PAGE="$SITE/content/modules/$SLUG/index.md"
MOD_DIR="$ROOT/modules/$SLUG"
EX_DIR="$MOD_DIR/exercises"
VAL="$MOD_DIR/VALIDATION.md"
NT="$MOD_DIR/new_terms.yaml"

[ -f "$BRIEF" ] || { echo "{\"ok\":false,\"error\":\"$BRIEF missing\"}" >&2; exit 2; }
[ -d "$SITE" ]  || { echo "{\"ok\":false,\"error\":\"$SITE missing — run scaffold-site.sh first\"}" >&2; exit 2; }

# Refuse to clobber an existing module — the orchestrator's resume logic
# decides what to skip; this script just creates fresh.
for f in "$PAGE" "$VAL" "$NT"; do
  if [ -e "$f" ]; then
    jq -nc --arg p "$f" '{ok: false, error: ("file already exists: " + $p)}'
    exit 1
  fi
done

# 1. hugo new — uses archetypes/modules.md.
(cd "$SITE" && hugo new "modules/$SLUG/index.md" >/dev/null)

# 2. Patch frontmatter from brief.
# Read the frontmatter block, splice in brief values via yq, write back.
FM_FILE="$(mktemp)"
BODY_FILE="$(mktemp)"
trap 'rm -f "$FM_FILE" "$BODY_FILE"' EXIT

awk -v fm="$FM_FILE" -v body="$BODY_FILE" '
  /^---$/ { c++; if (c==1) {next}; if (c==2) {next} }
  c==1 { print > fm; next }
  { print > body }
' "$PAGE"

# Extract from the brief.
TITLE=$(yq '.title' "$BRIEF")
WEIGHT=$(yq '.weight' "$BRIEF")
DQ=$(yq '.driving_question' "$BRIEF")
CONTRAST_ALT=$(yq '.contrast.alternative' "$BRIEF")
CONTRAST_WHEN=$(yq '.contrast.when_alternative_wins' "$BRIEF")
PRIOR=$(yq '.prior_ends_with' "$BRIEF")
NEXT=$(yq '.next_expects' "$BRIEF")
SUMMARY=$(yq '.driving_question' "$BRIEF")  # default; agent can refine in body if it wants.

# Read concepts as a YAML list (string array).
CONCEPTS_YAML=$(yq -o=json '.concepts' "$BRIEF" | jq -c '.')

# Patch fields. yq operates in-place when invoked with -i.
yq -i ".title = \"$TITLE\"" "$FM_FILE"
yq -i ".weight = $WEIGHT" "$FM_FILE"
yq -i ".driving_question = \"$DQ\"" "$FM_FILE"
yq -i ".contrast.alternative = \"$CONTRAST_ALT\"" "$FM_FILE"
yq -i ".contrast.when_alternative_wins = \"$CONTRAST_WHEN\"" "$FM_FILE"
yq -i ".prior_ends_with = \"$PRIOR\"" "$FM_FILE"
yq -i ".next_expects = \"$NEXT\"" "$FM_FILE"
yq -i ".summary = \"$SUMMARY\"" "$FM_FILE"
yq -i ".concepts = $CONCEPTS_YAML" "$FM_FILE"

# Reassemble.
{
  printf -- '---\n'
  cat "$FM_FILE"
  printf -- '---\n'
  cat "$BODY_FILE"
} > "$PAGE"

# 3. modules/<slug>/exercises/ — empty dir; agent populates.
mkdir -p "$EX_DIR"

# 4. VALIDATION.md from template, scenario inlined.
SCENARIO=$(yq '.validation_scenario' "$BRIEF")
cat > "$VAL" <<EOF
# Validation: $TITLE

## Scenario

$SCENARIO

## Good answer covers

<!-- builder: fill from brief.validation_scenario "Good answer covers" list -->

## If asked "why not $CONTRAST_ALT?"

<!-- builder: short answer grounded in the contrast section -->

## Try it aloud

Set a timer for 90 seconds. Cover the notes. Answer the scenario out loud. If
you stumble on a specific concept, re-read that concept's paragraph in
\`index.md\` and try again.
EOF

# 5. new_terms.yaml — empty list to append to.
echo '[]' > "$NT"

# Output paths.
jq -nc --arg i "$PAGE" --arg ex "$EX_DIR" --arg v "$VAL" --arg nt "$NT" \
  '{ok: true, index_md: $i, exercises_dir: $ex, validation_md: $v, new_terms_yaml: $nt}'
