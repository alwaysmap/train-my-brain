#!/usr/bin/env bash
# link-glossary.sh — Auto-link first mention of glossary terms on every page.
#
# Reads the union of:
#   - <root>/research.yaml         glossary[].term + glossary[].aliases[]
#   - <root>/curriculum_spine.md   glossary_seed[].term
#   - <root>/modules/*/new_terms.yaml  [].term
#
# For each module page (_index.md, validation.md, exercises/*.md), scans the
# body and wraps the FIRST occurrence of each known term in a Hugo
# {{< gloss "..." >}} shortcode, which the layout renders as a glossary link.
#
# Skips terms inside fenced code blocks, code spans, or existing shortcodes.
# Only first occurrence per page per term. Idempotent.
#
# Output: JSON
#   { ok: bool,
#     pages_scanned: N,
#     terms_known:   M,
#     links_added: [ { page, term } ... ] }
#
# Always exits 0 unless setup error (then exit 2).

set -euo pipefail

ROOT="${1:-}"
[ -z "$ROOT" ] && { echo '{"ok":false,"error":"usage: link-glossary.sh <root>"}' >&2; exit 2; }
command -v yq >/dev/null || { echo '{"ok":false,"error":"yq not found"}' >&2; exit 2; }
command -v jq >/dev/null || { echo '{"ok":false,"error":"jq not found"}' >&2; exit 2; }
command -v python3 >/dev/null || { echo '{"ok":false,"error":"python3 not found"}' >&2; exit 2; }

SITE="$ROOT/site"
[ -d "$SITE/content/modules" ] || { echo '{"ok":false,"error":"no module pages"}' >&2; exit 2; }

# ── Collect terms into a temp file (one per line) ────────────
TERMS_FILE=$(mktemp)
LINKS_FILE=$(mktemp)
trap 'rm -f "$TERMS_FILE" "$LINKS_FILE"' EXIT

# TERMS_FILE format: each line is "<surface>\t<canonical>". Surface is what we
# look for in prose; canonical is the glossary entry name (used for the
# shortcode's first arg, which Hugo's `urlize` turns into the anchor).
# A canonical term has surface == canonical. An alias has surface == alias,
# canonical == the canonical term it points to.

if [ -f "$ROOT/research.yaml" ]; then
  # Canonical terms.
  yq -r '.glossary[] | .term + "\t" + .term' "$ROOT/research.yaml" 2>/dev/null \
    | grep -v $'^null\tnull$' >> "$TERMS_FILE" || true
  # Aliases mapped to their canonical term.
  yq -r '.glossary[] | .term as $c | (.aliases // []) | .[] | . + "\t" + $c' \
    "$ROOT/research.yaml" 2>/dev/null \
    | grep -vE '^[[:space:]]*\t' | grep -v $'^null\t' >> "$TERMS_FILE" || true
fi

if [ -f "$ROOT/curriculum_spine.md" ]; then
  awk '/^---/{c++; next} c==1' "$ROOT/curriculum_spine.md" \
    | yq -r '.glossary_seed[] | .term + "\t" + .term' - 2>/dev/null \
    | grep -v $'^null\tnull$' >> "$TERMS_FILE" || true
fi

shopt -s nullglob
for nt in "$ROOT/modules"/*/new_terms.yaml; do
  yq -r '.[] | .term + "\t" + .term' "$nt" 2>/dev/null \
    | grep -v $'^null\tnull$' >> "$TERMS_FILE" || true
done

# Dedupe + sort by length of surface, descending (longer terms link first to
# avoid double-linking when both "RAG" and "Retrieval-Augmented Generation (RAG)"
# could match a passage).
awk -F'\t' 'NF==2 && $1 != "" && $2 != ""' "$TERMS_FILE" \
  | sort -u \
  | awk -F'\t' '{ print length($1), $0 }' \
  | sort -rn \
  | cut -d' ' -f2- > "$TERMS_FILE.sorted"
mv "$TERMS_FILE.sorted" "$TERMS_FILE"

terms_known=$(wc -l < "$TERMS_FILE" | tr -d ' ')

# ── Process each page via the Python helper ──────────────────
pages_scanned=0

# Find every module page (_index.md, validation.md, exercises/*.md inside /modules/).
mapfile -t PAGES < <(find "$SITE/content/modules" -type f -name '*.md' | sort)

for page in "${PAGES[@]}"; do
  pages_scanned=$((pages_scanned + 1))
  python3 - "$page" "$TERMS_FILE" "$LINKS_FILE" "$ROOT" <<'PYEOF'
import re, sys
from pathlib import Path

page_path = Path(sys.argv[1])
terms_file = Path(sys.argv[2])
links_file = Path(sys.argv[3])
root = Path(sys.argv[4])

# Each line is "<surface>\t<canonical>".
term_pairs = []
for line in terms_file.read_text(encoding="utf-8").splitlines():
    if "\t" not in line:
        continue
    surface, canonical = line.split("\t", 1)
    if surface and canonical:
        term_pairs.append((surface, canonical))

text = page_path.read_text(encoding="utf-8")

# Split frontmatter from body.
m = re.match(r'^(---\n.*?\n---\n)(.*)$', text, re.DOTALL)
if m:
    head, body = m.group(1), m.group(2)
else:
    head, body = "", text

original_body = body

for surface, canonical in term_pairs:
    # Already linked to this canonical anywhere on page? Skip.
    if f'{{< gloss "{canonical}"' in body:
        continue
    pattern = re.compile(r'(?<![\w/-])(' + re.escape(surface) + r')(?![\w/-])', re.IGNORECASE)
    lines = body.split("\n")
    in_fence = False
    linked = [False]
    new_lines = []
    for line in lines:
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            new_lines.append(line)
            continue
        if in_fence or linked[0]:
            new_lines.append(line)
            continue
        def make_repl(current_line, canonical):
            def repl(mm):
                if linked[0]:
                    return mm.group(0)
                start = mm.start()
                before = current_line[:start]
                if before.count("`") % 2 == 1:
                    return mm.group(0)
                if before.count("{{<") > before.count(">}}"):
                    return mm.group(0)
                linked[0] = True
                # Use the canonical for the shortcode's first arg so the
                # link targets the correct glossary anchor; preserve the
                # original surface text for display.
                return f'{{{{< gloss "{canonical}" "{mm.group(1)}" >}}}}'
            return repl
        new_line = pattern.sub(make_repl(line, canonical), line, count=1)
        new_lines.append(new_line)
    if linked[0]:
        body = "\n".join(new_lines)
        with links_file.open("a", encoding="utf-8") as f:
            rel = page_path.relative_to(root)
            f.write(f"{rel}\t{surface}\t{canonical}\n")

if body != original_body:
    page_path.write_text(head + body, encoding="utf-8")
PYEOF
done

# Build the links_added JSON from the LINKS_FILE.
# Each row: page\tsurface\tcanonical
links_json="[]"
if [ -s "$LINKS_FILE" ]; then
  links_json=$(jq -Rsc '
    split("\n") | map(select(length > 0)) | map(split("\t")) |
    map({page: .[0], surface: .[1], canonical: .[2]})
  ' < "$LINKS_FILE")
fi

jq -nc \
  --argjson l "$links_json" \
  --argjson p "$pages_scanned" \
  --argjson t "$terms_known" \
  '{ok: true, pages_scanned: $p, terms_known: $t, links_added: $l}'
