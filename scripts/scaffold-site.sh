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
defaultContentLanguage: en
title: "$TITLE"

pagination:
  pagerSize: 20

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

# Module concept page — the _index.md inside each module's branch bundle.
cat > "$TARGET/site/archetypes/modules.md" <<'EOF'
---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
type: module
weight: 0
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

<!-- Concept body (the agent fills this in below the frontmatter). -->
EOF

# Validation page — one per module.
cat > "$TARGET/site/archetypes/validation.md" <<'EOF'
---
title: "Validation"
type: validation
date: {{ .Date }}
draft: false
---

<!-- Validation body (scenario, good-answer bullets, contrast prompt, try-it-aloud). -->
EOF

# Exercise page — one per exercise inside a module's exercises/ section.
cat > "$TARGET/site/archetypes/exercises.md" <<'EOF'
---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
type: exercise
date: {{ .Date }}
draft: false
---

<!-- Exercise body (what you'll do, setup, scaffold with [TODO:] markers, verification). -->
EOF

cat > "$TARGET/site/archetypes/glossary.md" <<'EOF'
---
title: "Glossary"
date: {{ .Date }}
draft: false
---
EOF

# ── Layouts ───────────────────────────────────────────────────
mkdir -p "$TARGET/site/layouts/_default" \
         "$TARGET/site/layouts/partials" \
         "$TARGET/site/layouts/module" \
         "$TARGET/site/layouts/shortcodes"

# Base template — every page shares this shell.
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
    <div class="layout">
      {{ partial "modules-sidebar.html" . }}
      <main id="main" role="main">{{ block "main" . }}{{ end }}</main>
    </div>
    <footer><p>{{ .Site.Params.description }}</p></footer>
  </body>
</html>
EOF

cat > "$TARGET/site/layouts/partials/nav.html" <<'EOF'
<nav class="topnav">
  <a href="{{ "/" | relURL }}" class="brand">{{ .Site.Title }}</a>
  <ul>
    <li><a href="{{ "/modules/" | relURL }}">Modules</a></li>
    <li><a href="{{ "/glossary/" | relURL }}">Glossary</a></li>
  </ul>
</nav>
EOF

# Sidebar that lists every module (and, when on a module page, its
# validation + exercises). Always-visible TOC for the whole curriculum.
cat > "$TARGET/site/layouts/partials/modules-sidebar.html" <<'EOF'
{{ $modulesSection := .Site.GetPage "/modules" }}
{{ if $modulesSection }}
<aside class="sidebar">
  <h3><a href="{{ $modulesSection.RelPermalink }}">All modules</a></h3>
  <ol class="sidebar-modules">
    {{ range $modulesSection.Sections.ByWeight }}
      {{ $isCurrent := or (eq .RelPermalink $.RelPermalink) (in $.RelPermalink .RelPermalink) }}
      <li class="{{ if $isCurrent }}current{{ end }}">
        <a href="{{ .RelPermalink }}">{{ .Title }}</a>
        {{ if $isCurrent }}
          <ul class="sidebar-children">
            {{ with .GetPage "validation" }}<li><a href="{{ .RelPermalink }}">Validation</a></li>{{ end }}
            {{ with .GetPage "exercises" }}<li><a href="{{ .RelPermalink }}">Exercises ({{ len .Pages }})</a></li>{{ end }}
          </ul>
        {{ end }}
      </li>
    {{ end }}
  </ol>
</aside>
{{ end }}
EOF

# Glossary shortcode: {{< gloss "Term" >}} renders a link to /glossary/#term.
# {{< gloss "Term" "display text" >}} lets the link text differ from the
# anchor target — useful for "RAG" → glossary anchor "retrieval-augmented-generation".
cat > "$TARGET/site/layouts/shortcodes/gloss.html" <<'EOF'
{{- $term := .Get 0 -}}
{{- $display := .Get 1 | default $term -}}
{{- $anchor := $term | urlize -}}
<a class="gloss" href="{{ "/glossary/" | relURL }}#{{ $anchor }}">{{ $display }}</a>
EOF

# Home page — short blurb + module list ordered by weight.
cat > "$TARGET/site/layouts/index.html" <<'EOF'
{{ define "main" }}
<div class="home">
  <h1>{{ .Site.Title }}</h1>
  <p class="tagline">{{ .Site.Params.description }}</p>
  {{ .Content }}
  <h2>Modules</h2>
  {{ $modulesSection := .Site.GetPage "/modules" }}
  {{ if $modulesSection }}
  <ol class="module-list">
    {{ range $modulesSection.Sections.ByWeight }}
    <li class="module-item">
      <div class="module-item-header">
        <a href="{{ .RelPermalink }}">{{ .Title }}</a>
      </div>
      {{ with .Params.summary }}<p>{{ . }}</p>{{ end }}
      {{ with .Params.driving_question }}<p class="driving-question-inline">{{ . }}</p>{{ end }}
    </li>
    {{ end }}
  </ol>
  {{ end }}
</div>
{{ end }}
EOF

# Generic single-page layout — used for validation, exercises, glossary.
cat > "$TARGET/site/layouts/_default/single.html" <<'EOF'
{{ define "main" }}
<article class="single">
  <header>
    <h1>{{ .Title }}</h1>
  </header>
  <div class="single-body">{{ .Content }}</div>
  {{ if .Parent }}
  <p class="back-link"><a href="{{ .Parent.RelPermalink }}">&larr; Back to {{ .Parent.Title }}</a></p>
  {{ end }}
</article>
{{ end }}
EOF

# Generic section layout — used for /modules/ list, /modules/<slug>/exercises/ list,
# and any other section that isn't an individual module's concept page.
cat > "$TARGET/site/layouts/_default/list.html" <<'EOF'
{{ define "main" }}
<div class="section">
  <h1>{{ .Title }}</h1>
  {{ .Content }}
  {{ $children := .Sections.ByWeight }}
  {{ if eq (len $children) 0 }}{{ $children = .Pages.ByWeight }}{{ end }}
  {{ if $children }}
  <ol class="module-list">
    {{ range $children }}
    <li class="module-item">
      <div class="module-item-header">
        <a href="{{ .RelPermalink }}">{{ .Title }}</a>
      </div>
      {{ with .Params.summary }}<p>{{ . }}</p>{{ end }}
      {{ with .Params.driving_question }}<p class="driving-question-inline">{{ . }}</p>{{ end }}
    </li>
    {{ end }}
  </ol>
  {{ end }}
  {{ if .Parent }}
  <p class="back-link"><a href="{{ .Parent.RelPermalink }}">&larr; Back to {{ .Parent.Title }}</a></p>
  {{ end }}
</div>
{{ end }}
EOF

# Module concept page — _index.md inside each /modules/<slug>/ branch bundle.
# Hugo finds this layout via type: module set in archetypes/modules.md.
# Renders concept .Content + Practice section linking validation + exercises +
# weight-ordered prev/next navigation.
cat > "$TARGET/site/layouts/module/section.html" <<'EOF'
{{ define "main" }}
<article class="module">
  <header class="module-header">
    {{ if .Params.weight }}<span class="module-number">Module {{ .Params.weight }}</span>{{ end }}
    <h1>{{ .Title }}</h1>
    {{ with .Params.summary }}<p class="summary">{{ . }}</p>{{ end }}
    {{ with .Params.driving_question }}<p class="driving-question"><strong>{{ . }}</strong></p>{{ end }}
    {{ with .Params.blog_post }}
    <p class="blog-link"><a href="{{ . }}" target="_blank" rel="noopener">Read the blog post &#8599;</a></p>
    {{ end }}
  </header>

  <div class="module-body">{{ .Content }}</div>

  <section class="practice">
    <h2>Practice</h2>
    <p>Reading the concept is not the goal. Test it.</p>
    <ul>
      {{ with .GetPage "validation" }}
        <li><strong><a href="{{ .RelPermalink }}">Validation</a></strong> — try the scenario aloud, then answer in writing.</li>
      {{ end }}
      {{ with .GetPage "exercises" }}
        {{ if gt (len .Pages) 0 }}
        <li><strong><a href="{{ .RelPermalink }}">Exercises ({{ len .Pages }})</a></strong> — hands-on tasks with [TODO:] markers to fill in.</li>
        {{ end }}
      {{ end }}
    </ul>
  </section>

  {{/* Weight-ordered prev/next within /modules/. */}}
  {{ $allModules := .Parent.Sections.ByWeight }}
  {{ $here := .RelPermalink }}
  {{ $prev := false }}{{ $next := false }}{{ $hit := false }}
  {{ range $allModules }}
    {{ if $hit }}{{ if not $next }}{{ $next = . }}{{ end }}{{ end }}
    {{ if eq .RelPermalink $here }}{{ $hit = true }}{{ end }}
    {{ if not $hit }}{{ $prev = . }}{{ end }}
  {{ end }}
  <nav class="module-nav">
    <span class="module-nav-slot module-nav-prev">
      {{ with $prev }}<a href="{{ .RelPermalink }}">&larr; <span class="label">Previous module</span><br>{{ .Title }}</a>{{ end }}
    </span>
    <span class="module-nav-slot module-nav-next">
      {{ with $next }}<a href="{{ .RelPermalink }}"><span class="label">Next module</span> &rarr;<br>{{ .Title }}</a>{{ end }}
    </span>
  </nav>
</article>
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
  --color-bg: #ffffff;
  --color-text: #1a1a1a;
  --color-muted: #666;
  --color-border: #e5e5e5;
  --color-sidebar-bg: hsla(var(--hue), 30%, 98%, 1);
  --font-body: Georgia, serif;
  --font-ui:   system-ui, sans-serif;
  --font-mono: Menlo, Consolas, monospace;
  --max-width: 720px;
  --sidebar-width: 240px;
  --layout-max: calc(var(--max-width) + var(--sidebar-width) + 4rem);
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font-family: var(--font-body);
  color: var(--color-text);
  background: var(--color-bg);
  line-height: 1.6;
}

/* Top nav */
nav.topnav {
  font-family: var(--font-ui);
  border-bottom: 1px solid var(--color-border);
  padding: 1rem 1.25rem;
  display: flex; align-items: center; gap: 1.5rem;
  max-width: var(--layout-max); margin: 0 auto;
}
nav.topnav .brand { color: var(--color-primary); text-decoration: none; font-weight: 600; }
nav.topnav ul { list-style: none; display: flex; gap: 1rem; margin: 0; padding: 0; }
nav.topnav ul a { font-weight: 400; color: var(--color-text); text-decoration: none; }
nav.topnav ul a:hover { color: var(--color-analogous); }

/* Two-column layout: sidebar + main */
.layout {
  max-width: var(--layout-max);
  margin: 0 auto;
  display: grid;
  grid-template-columns: var(--sidebar-width) 1fr;
  gap: 2rem;
  padding: 2rem 1.25rem;
  align-items: start;
}
@media (max-width: 800px) {
  .layout { display: block; }
  .sidebar { margin-bottom: 2rem; }
}
main { max-width: var(--max-width); }

/* Sidebar */
.sidebar {
  font-family: var(--font-ui);
  background: var(--color-sidebar-bg);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 1rem 1.25rem;
  position: sticky;
  top: 1rem;
  font-size: 0.92em;
}
.sidebar h3 { margin: 0 0 0.5rem; font-size: 0.85em; text-transform: uppercase; letter-spacing: 0.04em; color: var(--color-muted); }
.sidebar h3 a { color: inherit; text-decoration: none; }
.sidebar h3 a:hover { color: var(--color-primary); }
.sidebar ol.sidebar-modules { list-style: decimal inside; padding: 0; margin: 0; }
.sidebar ol.sidebar-modules > li { margin: 0.35rem 0; }
.sidebar ol.sidebar-modules > li.current > a { color: var(--color-primary); font-weight: 600; }
.sidebar ol.sidebar-modules > li > a { color: var(--color-text); text-decoration: none; }
.sidebar ol.sidebar-modules > li > a:hover { color: var(--color-primary); }
.sidebar ul.sidebar-children { list-style: none; padding-left: 1.25rem; margin: 0.25rem 0 0.5rem; font-size: 0.9em; }
.sidebar ul.sidebar-children li { margin: 0.15rem 0; }
.sidebar ul.sidebar-children a { color: var(--color-muted); text-decoration: none; }
.sidebar ul.sidebar-children a:hover { color: var(--color-primary); }

/* Typography */
h1, h2, h3 { font-family: var(--font-ui); line-height: 1.25; }
h1 { color: var(--color-primary); }
a { color: var(--color-primary); }
a.gloss { border-bottom: 1px dotted var(--color-primary); text-decoration: none; }
a.gloss:hover { border-bottom-style: solid; }
code { font-family: var(--font-mono); background: var(--color-primary-light); padding: 0.1em 0.3em; border-radius: 3px; }
pre { font-family: var(--font-mono); background: var(--color-primary-light); padding: 1rem; border-radius: 6px; overflow-x: auto; }
pre code { background: transparent; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
th, td { border: 1px solid var(--color-border); padding: 0.5rem 0.75rem; text-align: left; }
th { background: var(--color-primary-light); font-family: var(--font-ui); }

/* Module list cards */
.module-list { list-style: none; padding: 0; counter-reset: module; }
.module-item { counter-increment: module; padding: 1rem 0; border-bottom: 1px solid var(--color-border); }
.module-item::before { content: counter(module) "."; color: var(--color-muted); font-family: var(--font-ui); margin-right: 0.5rem; font-weight: 600; }
.module-item-header a { font-family: var(--font-ui); font-weight: 600; text-decoration: none; }
.driving-question-inline { color: var(--color-muted); font-style: italic; margin: 0.25rem 0 0; font-size: 0.95em; }

/* Module concept page */
.module-header { border-bottom: 1px solid var(--color-border); padding-bottom: 1rem; margin-bottom: 1.5rem; }
.module-number { font-family: var(--font-ui); color: var(--color-muted); font-size: 0.9em; }
.driving-question { color: var(--color-triadic); font-size: 1.05em; padding: 0.75rem 1rem; background: var(--color-triadic-light); border-left: 4px solid var(--color-triadic); margin: 1rem 0; }
.module-body { /* prose styles inherit */ }

/* Practice section */
.practice {
  margin: 2.5rem 0 1rem;
  padding: 1.5rem;
  background: var(--color-primary-light);
  border-radius: 8px;
  border-left: 4px solid var(--color-primary);
}
.practice h2 { margin-top: 0; color: var(--color-primary); }
.practice ul { padding-left: 1.25rem; }
.practice li { margin: 0.5rem 0; }

/* Module prev/next nav */
.module-nav { display: flex; justify-content: space-between; gap: 1rem; margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--color-border); }
.module-nav-slot { flex: 1; font-family: var(--font-ui); font-size: 0.95em; }
.module-nav-prev { text-align: left; }
.module-nav-next { text-align: right; }
.module-nav a { text-decoration: none; }
.module-nav a:hover { color: var(--color-analogous); }
.module-nav .label { color: var(--color-muted); font-size: 0.85em; }

/* Single page (validation, exercise, glossary) */
.single { /* prose styles inherit */ }
.back-link { margin-top: 2rem; font-family: var(--font-ui); font-size: 0.9em; }

footer { max-width: var(--layout-max); margin: 3rem auto 1.5rem; padding: 1.5rem 1.25rem 0; border-top: 1px solid var(--color-border); color: var(--color-muted); font-size: 0.9em; text-align: center; }
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
