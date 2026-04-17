#!/usr/bin/env bash
# scaffold-site.sh — scaffold (or refresh layouts of) a Hugo site for a TMB curriculum.
#
# Modes:
#   Full scaffold (default):
#     scaffold-site.sh --target <dir> --title <str> --description <str> \
#                      --author <str> --hue <0..360>
#
#   Layouts-only (used by /tmb:rebuild-site):
#     scaffold-site.sh --target <dir> --layouts-only
#
# Full mode:
#   - Runs `hugo new site site/ --format yaml` inside <target>
#   - Writes archetypes/modules.md, hugo.yaml, layouts/, assets/css/
#   - Copies curriculum-templates/ (serve.sh, build.sh, stop.sh, .ps1 counterparts, .gitignore)
#   - Writes .github/workflows/deploy.yml
#
# Layouts-only mode:
#   - Rewrites only site/layouts/, site/assets/css/, site/archetypes/, site/hugo.yaml
#   - Leaves site/content/ untouched
#   - Preserves existing hugo.yaml params (title, description, author, hue) when possible
#
# Exits non-zero on any error. Safe to re-run layouts-only mode repeatedly.

set -euo pipefail

# ── Locate plugin root ────────────────────────────────────────
# Scripts ship inside the plugin; resolve plugin root from this script's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$PLUGIN_ROOT/curriculum-templates"

# ── Args ──────────────────────────────────────────────────────
TARGET=""
TITLE=""
DESCRIPTION=""
AUTHOR=""
HUE=""
LAYOUTS_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target)      TARGET="$2"; shift 2 ;;
    --title)       TITLE="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --author)      AUTHOR="$2"; shift 2 ;;
    --hue)         HUE="$2"; shift 2 ;;
    --layouts-only) LAYOUTS_ONLY=1; shift ;;
    *) echo "scaffold-site.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "scaffold-site.sh: --target is required" >&2
  exit 2
fi

# ── Hugo check ────────────────────────────────────────────────
if ! command -v hugo >/dev/null 2>&1; then
  echo "scaffold-site.sh: hugo is not installed. Run scripts/check-hugo.sh first." >&2
  exit 3
fi

HUGO_VERSION="$(hugo version 2>/dev/null | head -1 || true)"
echo "scaffold-site.sh: using $HUGO_VERSION"

# ── Full-mode validations ─────────────────────────────────────
if [ "$LAYOUTS_ONLY" -eq 0 ]; then
  if [ -z "$TITLE" ] || [ -z "$DESCRIPTION" ] || [ -z "$AUTHOR" ] || [ -z "$HUE" ]; then
    echo "scaffold-site.sh: full mode requires --title, --description, --author, --hue" >&2
    exit 2
  fi
  case "$HUE" in
    *[!0-9]*) echo "scaffold-site.sh: --hue must be an integer 0..360" >&2; exit 2 ;;
  esac
  if [ "$HUE" -lt 0 ] || [ "$HUE" -gt 360 ]; then
    echo "scaffold-site.sh: --hue must be between 0 and 360" >&2
    exit 2
  fi
  if [ -d "$TARGET/site" ]; then
    echo "scaffold-site.sh: $TARGET/site already exists." >&2
    echo "Use --layouts-only to refresh layouts, or remove site/ and re-run." >&2
    exit 4
  fi
fi

# ── Layouts-only validations ──────────────────────────────────
if [ "$LAYOUTS_ONLY" -eq 1 ] && [ ! -d "$TARGET/site" ]; then
  echo "scaffold-site.sh: --layouts-only requires an existing $TARGET/site/" >&2
  exit 4
fi

mkdir -p "$TARGET"

# ── Full scaffold ─────────────────────────────────────────────
if [ "$LAYOUTS_ONLY" -eq 0 ]; then
  echo "scaffold-site.sh: creating Hugo site at $TARGET/site"
  (cd "$TARGET" && hugo new site site --format yaml) >/dev/null
fi

# ── Write/rewrite hugo.yaml ───────────────────────────────────
# In layouts-only mode, preserve existing params from hugo.yaml if present.
if [ "$LAYOUTS_ONLY" -eq 1 ] && [ -f "$TARGET/site/hugo.yaml" ]; then
  # Extract preserved values using grep (avoids requiring yq).
  TITLE="$(grep -E '^title:' "$TARGET/site/hugo.yaml" | head -1 | sed 's/^title:[[:space:]]*"*//; s/"*$//' || echo "$TITLE")"
  DESCRIPTION="$(grep -E '^[[:space:]]*description:' "$TARGET/site/hugo.yaml" | head -1 | sed 's/^[[:space:]]*description:[[:space:]]*"*//; s/"*$//' || echo "$DESCRIPTION")"
  AUTHOR="$(grep -E '^[[:space:]]*author:' "$TARGET/site/hugo.yaml" | head -1 | sed 's/^[[:space:]]*author:[[:space:]]*"*//; s/"*$//' || echo "$AUTHOR")"
  HUE="$(grep -E '^[[:space:]]*hue:' "$TARGET/site/hugo.yaml" | head -1 | sed 's/^[[:space:]]*hue:[[:space:]]*//' || echo "$HUE")"
fi

cat > "$TARGET/site/hugo.yaml" <<EOF
baseURL: /
languageCode: en-us
title: "$TITLE"
paginate: 20

params:
  description: "$DESCRIPTION"
  author: "$AUTHOR"
  hue: $HUE

taxonomies:
  tag: tags
  topic: topics
EOF

# ── Archetypes ────────────────────────────────────────────────
mkdir -p "$TARGET/site/archetypes"
cat > "$TARGET/site/archetypes/modules.md" <<'EOF'
---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
weight: 0
status: planned
summary: ""
topics: []
blog_post: ""
driving_question: ""
concepts: []
contrast:
  alternative: ""
  when_alternative_wins: ""
prior_ends_with: ""
next_expects: ""
date: {{ .Date }}
draft: false
---
EOF

cat > "$TARGET/site/archetypes/glossary.md" <<'EOF'
---
title: "Glossary"
date: {{ .Date }}
draft: false
---
EOF

# ── Layouts ───────────────────────────────────────────────────
mkdir -p "$TARGET/site/layouts/_default" "$TARGET/site/layouts/partials"

cat > "$TARGET/site/layouts/baseof.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ .Title }} | {{ .Site.Title }}</title>
    <style>:root { --hue: {{ .Site.Params.hue | default 220 }}; }</style>
    {{ $siteCss := resources.Get "css/site.css" | fingerprint }}
    <link rel="stylesheet" href="{{ $siteCss.RelPermalink }}" />
  </head>
  <body>
    {{ partial "nav.html" . }}
    <main id="main" role="main">{{ block "main" . }}{{ end }}</main>
    <footer><p>{{ .Site.Params.description }}</p></footer>
  </body>
</html>
EOF

cat > "$TARGET/site/layouts/partials/nav.html" <<'EOF'
<nav>
  <a href="{{ "/" | relURL }}">{{ .Site.Title }}</a>
  <ul>
    <li><a href="{{ "/modules/" | relURL }}">Modules</a></li>
    <li><a href="{{ "/glossary/" | relURL }}">Glossary</a></li>
  </ul>
</nav>
EOF

cat > "$TARGET/site/layouts/index.html" <<'EOF'
{{ define "main" }}
<div class="home">
  <h1>{{ .Title }}</h1>
  <p class="tagline">{{ .Site.Params.description }}</p>
  {{ .Content }}
  <h2>Modules</h2>
  <ol class="module-list">
    {{ range (where .Site.RegularPages "Section" "modules").ByParam "weight" }}
    <li class="module-item {{ if .Params.status }}status-{{ .Params.status }}{{ end }}">
      <a href="{{ .RelPermalink }}">{{ .Title }}</a>
      <span class="status">{{ .Params.status | default "planned" }}</span>
      {{ if .Params.summary }}<p>{{ .Params.summary }}</p>{{ end }}
    </li>
    {{ end }}
  </ol>
</div>
{{ end }}
EOF

cat > "$TARGET/site/layouts/_default/page.html" <<'EOF'
{{ define "main" }}
<article class="module">
  <header class="module-header">
    <div class="module-meta">
      {{ if .Params.weight }}<span class="module-number">Module {{ .Params.weight }}</span>{{ end }}
      {{ with .Params.status }}<span class="status status-{{ . }}">{{ . }}</span>{{ end }}
    </div>
    <h1>{{ .Title }}</h1>
    {{ with .Params.summary }}<p class="summary">{{ . }}</p>{{ end }}
    {{ with .Params.driving_question }}<p class="driving-question"><strong>{{ . }}</strong></p>{{ end }}
    {{ with .Params.blog_post }}
    <p class="blog-link"><a href="{{ . }}" target="_blank" rel="noopener">Read the blog post &#8599;</a></p>
    {{ end }}
  </header>
  <div class="module-body">{{ .Content }}</div>
  <nav class="module-nav">
    {{ with .PrevInSection }}<a class="prev" href="{{ .RelPermalink }}">&larr; {{ .Title }}</a>{{ end }}
    {{ with .NextInSection }}<a class="next" href="{{ .RelPermalink }}">{{ .Title }} &rarr;</a>{{ end }}
  </nav>
</article>
{{ end }}
EOF

cat > "$TARGET/site/layouts/_default/section.html" <<'EOF'
{{ define "main" }}
<div class="section">
  <h1>{{ .Title }}</h1>
  {{ .Content }}
  <ol class="module-list">
    {{ range .Pages.ByParam "weight" }}
    <li class="module-item {{ if .Params.status }}status-{{ .Params.status }}{{ end }}">
      <div class="module-item-header">
        <a href="{{ .RelPermalink }}">{{ .Title }}</a>
        <span class="status">{{ .Params.status | default "planned" }}</span>
      </div>
      {{ with .Params.summary }}<p>{{ . }}</p>{{ end }}
    </li>
    {{ end }}
  </ol>
</div>
{{ end }}
EOF

# ── CSS ───────────────────────────────────────────────────────
mkdir -p "$TARGET/site/assets/css"
cat > "$TARGET/site/assets/css/site.css" <<'EOF'
:root {
  --color-primary:       hsla(var(--hue), 65%, 38%, 1);
  --color-primary-light: hsla(var(--hue), 65%, 96%, 1);
  --color-analogous:     hsla(calc(var(--hue) + 30), 70%, 46%, 1);
  --color-triadic:       hsla(calc(var(--hue) + 120), 55%, 42%, 1);
  --color-triadic-light: hsla(calc(var(--hue) + 120), 55%, 93%, 1);
  --color-planned:       hsla(0, 0%, 84%, 1);
  --color-in-progress:   hsla(calc(var(--hue) + 50), 75%, 68%, 1);
  --color-done:          hsla(calc(var(--hue) + 140), 55%, 50%, 1);
  --color-bg: #ffffff;
  --color-text: #1a1a1a;
  --color-muted: #666;
  --color-border: #e5e5e5;
  --font-body: Georgia, serif;
  --font-ui:   system-ui, sans-serif;
  --font-mono: Menlo, Consolas, monospace;
  --max-width: 720px;
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font-family: var(--font-body);
  color: var(--color-text);
  background: var(--color-bg);
  line-height: 1.6;
}
main { max-width: var(--max-width); margin: 0 auto; padding: 2rem 1.25rem; }
nav {
  font-family: var(--font-ui);
  border-bottom: 1px solid var(--color-border);
  padding: 1rem 1.25rem;
  display: flex; align-items: center; gap: 1.5rem;
  max-width: var(--max-width); margin: 0 auto;
}
nav a { color: var(--color-primary); text-decoration: none; font-weight: 600; }
nav ul { list-style: none; display: flex; gap: 1rem; margin: 0; padding: 0; }
nav ul a { font-weight: 400; color: var(--color-text); }
nav ul a:hover { color: var(--color-analogous); }
h1, h2, h3 { font-family: var(--font-ui); line-height: 1.25; }
h1 { color: var(--color-primary); }
a { color: var(--color-primary); }
code { font-family: var(--font-mono); background: var(--color-primary-light); padding: 0.1em 0.3em; border-radius: 3px; }
pre { font-family: var(--font-mono); background: var(--color-primary-light); padding: 1rem; border-radius: 6px; overflow-x: auto; }
pre code { background: transparent; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
th, td { border: 1px solid var(--color-border); padding: 0.5rem 0.75rem; text-align: left; }
th { background: var(--color-primary-light); font-family: var(--font-ui); }
.module-list { list-style: none; padding: 0; counter-reset: module; }
.module-item { counter-increment: module; padding: 1rem; border-bottom: 1px solid var(--color-border); }
.module-item::before { content: counter(module) "."; color: var(--color-muted); font-family: var(--font-ui); margin-right: 0.5rem; }
.status { font-family: var(--font-ui); font-size: 0.8em; padding: 0.1em 0.5em; border-radius: 3px; margin-left: 0.5rem; }
.status-planned { background: var(--color-planned); color: var(--color-text); }
.status-in-progress { background: var(--color-in-progress); color: var(--color-text); }
.status-done { background: var(--color-done); color: var(--color-bg); }
.module-header { border-bottom: 1px solid var(--color-border); padding-bottom: 1rem; margin-bottom: 1.5rem; }
.module-number { font-family: var(--font-ui); color: var(--color-muted); font-size: 0.9em; }
.driving-question { color: var(--color-triadic); font-size: 1.05em; padding: 0.75rem 1rem; background: var(--color-triadic-light); border-left: 4px solid var(--color-triadic); margin: 1rem 0; }
.module-nav { display: flex; justify-content: space-between; margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--color-border); }
.module-nav a { font-family: var(--font-ui); }
footer { max-width: var(--max-width); margin: 3rem auto 1.5rem; padding: 1.5rem 1.25rem 0; border-top: 1px solid var(--color-border); color: var(--color-muted); font-size: 0.9em; text-align: center; }
EOF

# ── Deploy workflow (full mode only) ──────────────────────────
if [ "$LAYOUTS_ONLY" -eq 0 ]; then
  mkdir -p "$TARGET/.github/workflows"
  cat > "$TARGET/.github/workflows/deploy.yml" <<'EOF'
name: Deploy site to GitHub Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: false
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: latest
          extended: true
      - uses: actions/configure-pages@v5
        id: pages
      - run: hugo --minify --baseURL "${{ steps.pages.outputs.base_url }}/" --source site/
      - uses: actions/upload-pages-artifact@v3
        with:
          path: ./site/public
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/deploy-pages@v4
        id: deployment
EOF

  # ── Curriculum-template scripts ──────────────────────────────
  if [ -d "$TEMPLATES_DIR" ]; then
    for f in serve.sh serve.ps1 build.sh build.ps1 stop.sh stop.ps1 .gitignore; do
      if [ -f "$TEMPLATES_DIR/$f" ]; then
        cp "$TEMPLATES_DIR/$f" "$TARGET/$f"
      fi
    done
    chmod +x "$TARGET/serve.sh" "$TARGET/build.sh" "$TARGET/stop.sh" 2>/dev/null || true
  else
    echo "scaffold-site.sh: warning — curriculum-templates/ not found at $TEMPLATES_DIR" >&2
    echo "  Serve/build/stop scripts were NOT copied. Users will need to create them manually." >&2
  fi
fi

if [ "$LAYOUTS_ONLY" -eq 1 ]; then
  echo "scaffold-site.sh: layouts-only refresh complete at $TARGET/site"
else
  echo "scaffold-site.sh: full scaffold complete at $TARGET/site"
fi
