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
FONT_PRESET="signage"   # default
LAYOUTS_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target)       TARGET="$2"; shift 2 ;;
    --title)        TITLE="$2"; shift 2 ;;
    --description)  DESCRIPTION="$2"; shift 2 ;;
    --author)       AUTHOR="$2"; shift 2 ;;
    --hue)          HUE="$2"; shift 2 ;;
    --font-preset)  FONT_PRESET="$2"; shift 2 ;;
    --layouts-only) LAYOUTS_ONLY=1; shift ;;
    *) echo "scaffold-site.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$FONT_PRESET" in
  signage|book) ;;
  *) echo "scaffold-site.sh: --font-preset must be 'signage' or 'book'" >&2; exit 2 ;;
esac

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
  EXISTING_FONT="$(grep -E '^[[:space:]]*font_preset:' "$TARGET/site/hugo.yaml" | head -1 | sed 's/^[[:space:]]*font_preset:[[:space:]]*"*//; s/"*$//' || echo "")"
  [ -n "$EXISTING_FONT" ] && FONT_PRESET="$EXISTING_FONT"
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
  font_preset: "$FONT_PRESET"

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
short_title: ""
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
# Every exercise has a sibling `<name>-answer.md` model-answer page; the
# layout cross-links them automatically.
cat > "$TARGET/site/archetypes/exercises.md" <<'EOF'
---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
type: exercise
date: {{ .Date }}
draft: false
---

<!-- Exercise body (what you'll do, setup, scaffold with [TODO:] markers, verification). -->
EOF

# Model-answer page — a sibling to each exercise. Filename pattern:
# `<exercise-slug>-answer.md`. The layout looks it up and renders a
# "Show model answer →" CTA at the bottom of the exercise page.
cat > "$TARGET/site/archetypes/answer.md" <<'EOF'
---
title: "Model answer"
type: answer
date: {{ .Date }}
draft: false
---

<!-- Worked solution + commentary on tradeoffs the learner had to make. -->
EOF

cat > "$TARGET/site/archetypes/glossary.md" <<'EOF'
---
title: "Glossary"
date: {{ .Date }}
draft: false
---
EOF

# ── Layouts ───────────────────────────────────────────────────
# Clean up any stale layouts from older plugin versions before writing the
# current set. v0.4.0–0.4.2 used _default/page.html + _default/section.html
# (no module/ dir, no shortcodes); v0.4.3+ uses _default/list.html +
# _default/single.html + module/section.html + shortcodes/gloss.html. Stale
# files would win Hugo's lookup over the new ones, so they have to go.
rm -f "$TARGET/site/layouts/_default/page.html"
rm -f "$TARGET/site/layouts/_default/section.html"

mkdir -p "$TARGET/site/layouts/_default" \
         "$TARGET/site/layouts/partials" \
         "$TARGET/site/layouts/module" \
         "$TARGET/site/layouts/shortcodes"

# Base template — every page shares this shell.
cat > "$TARGET/site/layouts/baseof.html" <<'EOF'
<!doctype html>
<html lang="en" data-font-preset="{{ .Site.Params.font_preset | default "signage" }}">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ .Title }} | {{ .Site.Title }}</title>
    <style>:root { --hue: {{ .Site.Params.hue | default 220 }}; }</style>
    {{/* Apply saved theme before paint to avoid a flash of the wrong theme.
         Stored values: "light" or "dark"; absent = follow system. */}}
    <script>
      (function () {
        try {
          var saved = localStorage.getItem("tmb-theme");
          if (saved === "light" || saved === "dark") {
            document.documentElement.setAttribute("data-theme", saved);
          }
        } catch (e) { /* localStorage may be blocked; fall back to system */ }
      })();
    </script>
    {{ $preset := .Site.Params.font_preset | default "signage" }}
    {{ if eq $preset "signage" }}
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono&display=swap">
    {{ else if eq $preset "book" }}
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,400;8..60,600&family=Inter:wght@400;600&family=JetBrains+Mono&display=swap">
    {{ end }}
    {{/* No fingerprint — keep the URL stable as /css/site.css. Going through
         resources.Get (vs static/) leaves room for future Hugo Pipes processing
         (minification, SCSS) without changing the URL contract. */}}
    {{ $siteCss := resources.Get "css/site.css" }}
    <link rel="stylesheet" href="{{ $siteCss.RelPermalink }}" />
  </head>
  <body>
    <a class="skip-link" href="#main">Skip to content</a>
    {{ partial "nav.html" . }}
    <div class="layout">
      {{ partial "modules-sidebar.html" . }}
      <main id="main" role="main">{{ block "main" . }}{{ end }}</main>
    </div>
    <footer><p>{{ .Site.Params.description }}</p></footer>
    {{/* Theme switch click handler. "system" = remove the attribute so the
         CSS @media (prefers-color-scheme: dark) rule takes over. */}}
    <script>
      (function () {
        var root = document.documentElement;
        var buttons = document.querySelectorAll(".theme-switch [data-theme-set]");
        if (!buttons.length) return;
        function current() {
          var saved;
          try { saved = localStorage.getItem("tmb-theme"); } catch (e) {}
          return (saved === "light" || saved === "dark") ? saved : "system";
        }
        function paint() {
          var c = current();
          buttons.forEach(function (b) {
            b.setAttribute("aria-pressed", b.getAttribute("data-theme-set") === c ? "true" : "false");
          });
        }
        buttons.forEach(function (b) {
          b.addEventListener("click", function () {
            var next = b.getAttribute("data-theme-set");
            try {
              if (next === "system") {
                localStorage.removeItem("tmb-theme");
                root.removeAttribute("data-theme");
              } else {
                localStorage.setItem("tmb-theme", next);
                root.setAttribute("data-theme", next);
              }
            } catch (e) {
              if (next === "system") root.removeAttribute("data-theme");
              else root.setAttribute("data-theme", next);
            }
            paint();
          });
        });
        paint();
      })();
    </script>
    {{ if .Store.Get "hasMermaid" }}
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
      const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
      mermaid.initialize({ startOnLoad: true, theme: dark ? "dark" : "default", securityLevel: "strict" });
    </script>
    {{ end }}
  </body>
</html>
EOF

mkdir -p "$TARGET/site/layouts/_default/_markup"
cat > "$TARGET/site/layouts/_default/_markup/render-codeblock-mermaid.html" <<'EOF'
<pre class="mermaid">{{ .Inner | safeHTML }}</pre>
{{ .Page.Store.Set "hasMermaid" true }}
EOF

# Heading render hook — wraps every Markdown-sourced h2..h6 with a "#" anchor
# revealed on hover. Clicking copies the hash to the URL bar so the section is
# shareable. The page <h1> is emitted by layout (not Markdown), so it's never
# touched here.
cat > "$TARGET/site/layouts/_default/_markup/render-heading.html" <<'EOF'
{{- $level := .Level -}}
{{- $anchor := .Anchor -}}
{{- $text := .Text -}}
<h{{ $level }} id="{{ $anchor }}" class="md-heading">
  {{ $text | safeHTML }}
  <a class="heading-anchor" href="#{{ $anchor }}" aria-label="Link to this section">#</a>
</h{{ $level }}>
EOF

cat > "$TARGET/site/layouts/partials/nav.html" <<'EOF'
<nav class="topnav">
  <div class="topnav-inner">
    <a href="{{ site.Home.RelPermalink }}" class="brand">{{ .Site.Title }}</a>
    <ul>
      {{ with site.GetPage "/modules" }}<li><a href="{{ .RelPermalink }}">Modules</a></li>{{ end }}
      {{ with site.GetPage "/glossary" }}<li><a href="{{ .RelPermalink }}">Glossary</a></li>{{ end }}
      {{ with site.GetPage "/about" }}<li><a href="{{ .RelPermalink }}">About</a></li>{{ end }}
    </ul>
    <div class="theme-switch" role="group" aria-label="Color theme">
      <button type="button" data-theme-set="light" aria-label="Light theme" title="Light theme">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
      </button>
      <button type="button" data-theme-set="system" aria-label="System theme" title="Follow system">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/></svg>
      </button>
      <button type="button" data-theme-set="dark" aria-label="Dark theme" title="Dark theme">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
      </button>
    </div>
  </div>
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
        <a href="{{ .RelPermalink }}" title="{{ .Title }}">{{ .Params.short_title | default .Title }}</a>
        {{ if $isCurrent }}
          <ul class="sidebar-children">
            {{ with .GetPage "validation" }}<li><a href="{{ .RelPermalink }}">Validation</a></li>{{ end }}
            {{ with .GetPage "exercises" }}{{ $exCount := len (where .Pages "Params.type" "exercise") }}<li><a href="{{ .RelPermalink }}">Exercises ({{ $exCount }})</a></li>{{ end }}
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
{{- $glossary := site.GetPage "/glossary" -}}
<a class="gloss" href="{{ with $glossary }}{{ .RelPermalink }}{{ end }}#{{ $anchor }}">{{ $display }}</a>
EOF

# Visual-needed shortcode: a styled callout that renders where a real
# image or video should go but doesn't yet. Use it ONLY when free-use
# imagery is genuinely unavailable — it gives the reader an actionable
# YouTube + Wikimedia search instead of an invisible HTML comment.
#
# Usage:
#   {{< visual-needed what="What the visual should show"
#                     youtube="search query"
#                     wikimedia="search query" >}}
#   Optional body prose explaining what the reader is looking for.
#   {{< /visual-needed >}}
cat > "$TARGET/site/layouts/shortcodes/visual-needed.html" <<'EOF'
{{- $what := .Get "what" -}}
{{- $youtube := .Get "youtube" -}}
{{- $wikimedia := .Get "wikimedia" -}}
{{- $description := .Inner -}}
<aside class="visual-needed" role="note" aria-label="Visual reference needed">
  <div class="visual-needed-label">Visual reference: {{ $what }}</div>
  {{ if $description }}<div class="visual-needed-body">{{ $description | markdownify }}</div>{{ end }}
  <div class="visual-needed-links">
    {{ if $youtube -}}
      <a href="https://www.youtube.com/results?search_query={{ $youtube | urlquery }}" target="_blank" rel="noopener noreferrer">▶︎ Watch on YouTube</a>
    {{- end }}
    {{ if $wikimedia -}}
      <a href="https://commons.wikimedia.org/w/index.php?search={{ $wikimedia | urlquery }}&amp;ns0=1" target="_blank" rel="noopener noreferrer">🔍 Search Wikimedia Commons</a>
    {{- end }}
  </div>
</aside>
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
      <a class="module-item-link" href="{{ .RelPermalink }}">
        <span class="module-item-header">{{ .Title }}</span>
        {{ with .Params.summary }}<span class="module-item-summary">{{ . }}</span>{{ end }}
        {{ with .Params.driving_question }}<span class="driving-question-inline">{{ . }}</span>{{ end }}
      </a>
    </li>
    {{ end }}
  </ol>
  {{ end }}
</div>
{{ end }}
EOF

# Generic single-page layout — used for validation, exercises, answers, glossary.
# When the page is an exercise, looks for a sibling `<slug>-answer.md` and
# renders a "Show model answer" CTA. When the page is an answer, links back
# to its parent exercise.
cat > "$TARGET/site/layouts/_default/single.html" <<'EOF'
{{ define "main" }}
<article class="single">
  <header>
    <h1>{{ .Title }}</h1>
  </header>
  <div class="single-body">{{ .Content }}</div>

  {{/* Exercise → "Show model answer" CTA */}}
  {{ if eq .Type "exercise" }}
    {{ $base := path.BaseName .File.LogicalName }}
    {{ $answerName := printf "%s-answer" $base }}
    {{ with .Parent.GetPage $answerName }}
    <aside class="model-answer-cta">
      <p><strong>Tried it?</strong> Compare your work against the worked solution.</p>
      <a class="model-answer-button" href="{{ .RelPermalink }}">Show model answer &rarr;</a>
    </aside>
    {{ end }}
  {{ end }}

  {{/* Answer → "Back to exercise" link */}}
  {{ if eq .Type "answer" }}
    {{ $base := path.BaseName .File.LogicalName }}
    {{ $exName := strings.TrimSuffix "-answer" $base }}
    {{ with .Parent.GetPage $exName }}
    <p class="back-link"><a href="{{ .RelPermalink }}">&larr; Back to the exercise</a></p>
    {{ end }}
  {{ end }}

  {{/* Default back-link for everything else */}}
  {{ if and .Parent (ne .Type "answer") }}
  <p class="back-link"><a href="{{ .Parent.RelPermalink }}">&larr; Back to {{ .Parent.Title }}</a></p>
  {{ end }}
</article>
{{ end }}
EOF

# Generic section layout — used for /modules/ list, /modules/<slug>/exercises/ list,
# and any other section that isn't an individual module's concept page.
# Filters out type:answer pages so exercise-list pages don't show every model
# answer as a separate item alongside the exercise.
cat > "$TARGET/site/layouts/_default/list.html" <<'EOF'
{{ define "main" }}
<div class="section">
  <h1>{{ .Title }}</h1>
  {{ .Content }}
  {{ $children := .Sections.ByWeight }}
  {{ if eq (len $children) 0 }}
    {{ $children = where .Pages.ByWeight ".Type" "ne" "answer" }}
  {{ end }}
  {{ if $children }}
  <ol class="module-list">
    {{ range $children }}
    <li class="module-item">
      <a class="module-item-link" href="{{ .RelPermalink }}">
        <span class="module-item-header">{{ .Title }}</span>
        {{ with .Params.summary }}<span class="module-item-summary">{{ . }}</span>{{ end }}
        {{ with .Params.driving_question }}<span class="driving-question-inline">{{ . }}</span>{{ end }}
      </a>
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
    {{/* Show summary only when it adds info beyond the driving question. */}}
    {{ $summary := .Params.summary }}
    {{ $dq := .Params.driving_question }}
    {{ if and $summary (ne $summary $dq) }}<p class="summary">{{ $summary }}</p>{{ end }}
    {{ with $dq }}<p class="driving-question"><strong>{{ . }}</strong></p>{{ end }}
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
        {{ if gt (len (where .Pages "Params.type" "exercise")) 0 }}
        <li><strong><a href="{{ .RelPermalink }}">Exercises</a></strong> — hands-on tasks with [TODO:] markers to fill in.</li>
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
/* =============================================================
 * TMB curriculum site — design system
 *
 * Discipline:
 *   • One chromatic accent: --color-primary (the user's --hue).
 *   • Neutrals are warm & hue-INdependent: warm cream canvas + ink-with-blue
 *     text. This stays harmonious regardless of which hue the user picks.
 *   • Triadic/analogous tokens are defined for opt-in but NEVER used in the
 *     default UI — auto-derived triadic clashes with most user hues
 *     (fuchsia 320 → olive 80 is the worst case but most pairings are bad).
 *   • Two-tier color hierarchy:
 *       Chrome (nav/sidebar/footer/code/blockquote strip)  → neutrals.
 *       Content (page h1, body links, callouts, CTA, gloss) → primary.
 *   • One callout pattern (.callout) — applied to driving-question and practice.
 *   • Modular type scale (ratio 1.25), 8-step spacing scale (4px base).
 *
 * Contrast targets (WCAG AA, light mode hue=320):
 *   text  hsl(230,18%,14%) ↔ bg hsl(40,30%,98%)  → 14.8:1  (AAA)
 *   muted hsl(230,8%,40%)  ↔ bg                  →  6.4:1  (AAA)
 *   primary hsla(320,75%,35%) ↔ bg               →  6.1:1  (AA normal, AAA large)
 * Dark mode and high-contrast pass the same gates (verified by lightness gap).
 * ============================================================= */

:root {
  /* ---- Hue is set by baseof.html inline <style>, default 220 ----
   * Do NOT redeclare --hue here: var(--hue, 220) self-references
   * and CSS treats that as a cycle (IACVT). */
  --hue-analogous: calc(var(--hue) + 30);
  --hue-triadic:   calc(var(--hue) + 120);

  /* ---- Neutrals (hue-independent, warm canvas) ---- */
  --color-bg:       hsl(40, 30%, 98%);   /* warm cream canvas */
  --color-surface:  hsl(40, 22%, 94%);   /* slightly warmer for code/table headers */
  --color-text:     hsl(230, 18%, 14%);  /* near-black with subtle blue ink */
  --color-muted:    hsl(230, 8%, 38%);   /* secondary text — 6.4:1 on bg (AAA) */
  --color-faint:    hsl(230, 10%, 45%);  /* tertiary text — 4.7:1 on bg (AA) */
  --color-border:   hsl(40, 14%, 86%);   /* hairlines */
  --color-rule:     hsl(40, 14%, 92%);   /* very soft section dividers */

  /* ---- Chromatic accent (the user's --hue) ----
   * primary       = body links, page h1, CTA fill, gloss underline, current state
   * primary-strong= h2/h3 headings, hover state
   * primary-soft  = callout left-strip, focus ring at low opacity
   * primary-fade  = callout background, hero wash
   */
  --color-primary:        hsla(var(--hue), 75%, 38%, 1);
  --color-primary-strong: hsla(var(--hue), 80%, 28%, 1);
  --color-primary-soft:   hsla(var(--hue), 65%, 88%, 1);
  --color-primary-fade:   hsla(var(--hue), 55%, 96%, 1);

  /* Defined for opt-in user customization; the default UI does not use them. */
  --color-analogous:    hsla(var(--hue-analogous), 75%, 40%, 1);
  --color-triadic:      hsla(var(--hue-triadic),   60%, 36%, 1);
  --color-triadic-soft: hsla(var(--hue-triadic),   60%, 92%, 1);

  /* ---- Secondary accent (derived from --hue) ----
   * Same hue as primary, low saturation. For annotation roles only.
   * Fuchsia → dusty mauve; blue → slate; green → sage. */
  --color-accent:      hsla(var(--hue), 28%, 42%, 1);
  --color-accent-soft: hsla(var(--hue), 30%, 90%, 1);

  /* ---- Link / annotation color (complement of --hue, +180°) ----
   * Classic editorial move: structural elements (h1, hero) use the primary;
   * actionable links + small annotation roles (eyebrows, numerals, prev/next
   * labels, heading anchors) use the complement so they're visibly distinct.
   * Mathematical complement, no temperature claim — for fuchsia primary the
   * complement lands in green; for teal it lands in rust; for orange it
   * lands in teal. Saturation kept moderate so the complement reads as
   * "linkable" rather than as a competing brand color.
   */
  --color-link:        hsla(calc(var(--hue) + 180), 55%, 32%, 1);
  --color-link-hover:  hsla(calc(var(--hue) + 180), 65%, 22%, 1);
  --color-link-soft:   hsla(calc(var(--hue) + 180), 50%, 88%, 1);

  /* ---- Type scale (1.25 modular ratio) ---- */
  --type-xs:  0.875rem;   /* 14px — labels, captions */
  --type-sm:  1rem;       /* 16px — body */
  --type-md:  1.125rem;   /* 18px — lead paragraph */
  --type-lg:  1.25rem;    /* 20px — h4 */
  --type-xl:  1.5625rem;  /* 25px — h3 */
  --type-2xl: 1.953rem;   /* 31px — h2 */
  --type-3xl: 2.441rem;   /* 39px — h1 */
  --type-4xl: 3.052rem;   /* 49px — hero h1 (home only) */

  /* ---- Spacing scale (4px base) ---- */
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  --space-3: 0.75rem;
  --space-4: 1rem;
  --space-6: 1.5rem;
  --space-8: 2rem;
  --space-12: 3rem;
  --space-16: 4rem;

  /* ---- Layout ---- */
  --measure: 65ch;                        /* prose line-length cap */
  --max-width: 700px;                     /* main column width */
  --sidebar-width: 220px;
  --layout-max: calc(var(--max-width) + var(--sidebar-width) + 4rem);
  --radius: 6px;
  --radius-lg: 10px;

  /* ---- Type families (default = signage; book preset overrides) ---- */
  --font-body: "Inter", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  --font-ui:   "Inter", system-ui, -apple-system, sans-serif;
  --font-mono: "JetBrains Mono", "SF Mono", Menlo, Consolas, monospace;
  --line-body:    1.6;
  --line-heading: 1.2;
}

html[data-font-preset="book"] {
  --font-body: "Source Serif 4", "Charter", "Iowan Old Style", Georgia, serif;
  --font-ui:   "Inter", system-ui, -apple-system, sans-serif;
  --line-body: 1.7;
}

/* ---- Dark mode tokens (shared) ---- */
/* Applied either via system preference (when no manual override is set)
 * or via html[data-theme="dark"] (when the user picks dark explicitly).
 * Light mode is always the :root default. */
html[data-theme="dark"] {
  --color-bg:       hsl(230, 16%, 9%);
  --color-surface:  hsl(230, 12%, 15%);
  --color-text:     hsl(40, 15%, 94%);
  --color-muted:    hsl(230, 10%, 68%);
  --color-faint:    hsl(230, 10%, 50%);
  --color-border:   hsl(230, 12%, 24%);
  --color-rule:     hsl(230, 12%, 18%);

  --color-primary:        hsla(var(--hue), 75%, 72%, 1);
  --color-primary-strong: hsla(var(--hue), 78%, 82%, 1);
  --color-primary-soft:   hsla(var(--hue), 50%, 28%, 1);
  --color-primary-fade:   hsla(var(--hue), 45%, 16%, 1);

  --color-accent:      hsla(var(--hue), 30%, 70%, 1);
  --color-accent-soft: hsla(var(--hue), 25%, 25%, 1);

  --color-link:        hsla(calc(var(--hue) + 180), 60%, 70%, 1);
  --color-link-hover:  hsla(calc(var(--hue) + 180), 70%, 80%, 1);
  --color-link-soft:   hsla(calc(var(--hue) + 180), 35%, 25%, 1);
}
@media (prefers-color-scheme: dark) {
  /* Apply dark tokens when system pref is dark AND no manual override.
   * The :not() guard means data-theme="light" wins over system pref. */
  html:not([data-theme]) {
    --color-bg:       hsl(230, 16%, 9%);
    --color-surface:  hsl(230, 12%, 15%);
    --color-text:     hsl(40, 15%, 94%);
    --color-muted:    hsl(230, 10%, 68%);
    --color-faint:    hsl(230, 10%, 50%);
    --color-border:   hsl(230, 12%, 24%);
    --color-rule:     hsl(230, 12%, 18%);

    --color-primary:        hsla(var(--hue), 75%, 72%, 1);
    --color-primary-strong: hsla(var(--hue), 78%, 82%, 1);
    --color-primary-soft:   hsla(var(--hue), 50%, 28%, 1);
    --color-primary-fade:   hsla(var(--hue), 45%, 16%, 1);

    --color-accent:      hsla(var(--hue), 30%, 70%, 1);
    --color-accent-soft: hsla(var(--hue), 25%, 25%, 1);

    --color-link:        hsla(calc(var(--hue) + 180), 60%, 70%, 1);
    --color-link-hover:  hsla(calc(var(--hue) + 180), 70%, 80%, 1);
    --color-link-soft:   hsla(calc(var(--hue) + 180), 35%, 25%, 1);
  }
}

/* ---- High-contrast mode ---- */
@media (prefers-contrast: more) {
  :root {
    --color-text:    hsl(230, 30%, 5%);
    --color-muted:   hsl(230, 25%, 22%);
    --color-border:  hsl(230, 20%, 60%);
    --color-primary: hsla(var(--hue), 90%, 28%, 1);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --color-text:    hsl(40, 20%, 98%);
      --color-muted:   hsl(230, 8%, 82%);
      --color-border:  hsl(230, 12%, 38%);
      --color-primary: hsla(var(--hue), 85%, 82%, 1);
    }
  }
}

/* ---- Reduced motion ---- */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

/* ============================================================= */
/* Reset & base                                                   */
/* ============================================================= */

*, *::before, *::after { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
html { scroll-behavior: smooth; }

body {
  font-family: var(--font-body);
  color: var(--color-text);
  background: var(--color-bg);
  line-height: var(--line-body);
  font-size: var(--type-sm);
  font-feature-settings: "kern", "liga", "onum";
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* ---- Skip link (a11y) — visible on focus only ---- */
.skip-link {
  position: absolute;
  top: -100px;
  left: var(--space-4);
  background: var(--color-primary);
  color: var(--color-bg);
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius);
  text-decoration: none;
  z-index: 100;
  font-family: var(--font-ui);
  font-weight: 600;
  font-size: var(--type-xs);
}
.skip-link:focus { top: var(--space-2); }

/* ---- Universal focus ring ---- */
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 3px;
  border-radius: 2px;
}
/* Buttons/cards already have padding & radius — keep their existing shape */
.module-item:focus-within,
.model-answer-button:focus-visible {
  outline-offset: 3px;
}

/* ============================================================= */
/* Top nav — chrome. Neutral, hairline, sticky.                   */
/* ============================================================= */

nav.topnav {
  position: sticky;
  top: 0;
  z-index: 50;
  background: var(--color-bg);
  border-bottom: 1px solid var(--color-border);
  font-family: var(--font-ui);
}
nav.topnav .topnav-inner {
  max-width: var(--layout-max);
  margin: 0 auto;
  padding: var(--space-3) var(--space-6);
  display: flex;
  align-items: baseline;
  gap: var(--space-6);
  flex-wrap: nowrap;
}
nav.topnav .brand {
  color: var(--color-text);
  text-decoration: none;
  font-weight: 600;
  font-size: var(--type-sm);
  letter-spacing: -0.01em;
  /* Truncate on narrow viewports — keeps nav one line */
  flex: 1 1 auto;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
nav.topnav .brand:hover { color: var(--color-primary); }
nav.topnav ul {
  list-style: none;
  display: flex;
  gap: var(--space-6);
  margin: 0;
  padding: 0;
  flex: 0 0 auto;
}
nav.topnav ul a {
  font-weight: 500;
  font-size: var(--type-xs);
  color: var(--color-muted);
  text-decoration: none;
  padding: var(--space-1) 0;
  border-bottom: 2px solid transparent;
  transition: color 0.12s ease, border-color 0.12s ease;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
nav.topnav ul a:hover {
  color: var(--color-primary);
  border-bottom-color: var(--color-primary);
}

/* Theme switch — three-segment radio (light / system / dark) */
.theme-switch {
  display: inline-flex;
  gap: 0;
  margin-left: var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  padding: 2px;
  background: var(--color-bg);
}
.theme-switch button {
  font: inherit;
  font-size: var(--type-xs);
  background: transparent;
  border: 0;
  color: var(--color-muted);
  padding: 0.2rem 0.5rem;
  cursor: pointer;
  border-radius: 4px;
  line-height: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 1.8rem;
  transition: background-color 0.12s ease, color 0.12s ease;
}
.theme-switch button:hover { color: var(--color-text); }
.theme-switch button[aria-pressed="true"] {
  background: var(--color-primary);
  color: var(--color-bg);
}
.theme-switch svg {
  width: 14px;
  height: 14px;
  display: block;
}
@media (max-width: 800px) {
  .theme-switch { margin-left: 0; }
}

/* ============================================================= */
/* Layout                                                         */
/* ============================================================= */

.layout {
  max-width: var(--layout-max);
  margin: 0 auto;
  display: grid;
  grid-template-columns: var(--sidebar-width) 1fr;
  gap: var(--space-12);
  padding: var(--space-8) var(--space-6);
  align-items: start;
}
main { max-width: var(--max-width); min-width: 0; }
main > * { max-width: var(--measure); }
main > .home,
main > .module,
main > .module > .module-body,
main > .module > .module-header,
main > .module > .practice,
main > .module > .module-nav,
main > .single,
main > .section { max-width: none; }

@media (max-width: 800px) {
  /* Drop sidebar on mobile — top nav has the entry points */
  .layout {
    display: block;
    padding: var(--space-4);
  }
  .sidebar { display: none; }
  main { max-width: 100%; }
  main > * { max-width: 100%; }

  /* Mobile nav — drop the brand label entirely. The site title is already in
   * the page <h1> and in the browser tab. Persistent nav real estate is too
   * scarce on phones to spend on a 4-line title. */
  nav.topnav .brand { display: none; }
  nav.topnav .topnav-inner {
    padding: var(--space-3) var(--space-4);
    justify-content: center;
    gap: var(--space-4);
  }
  nav.topnav ul {
    margin: 0;
    gap: var(--space-4);
    width: 100%;
    justify-content: space-around;
  }
  nav.topnav ul a { font-size: var(--type-xs); letter-spacing: 0.06em; }
}

/* ============================================================= */
/* Sidebar — quiet chrome, no card                                */
/* ============================================================= */

.sidebar {
  font-family: var(--font-ui);
  position: sticky;
  top: var(--space-6);
  font-size: var(--type-xs);
  border-right: 1px solid var(--color-rule);
  padding-right: var(--space-4);
}
.sidebar h3 {
  margin: 0 0 var(--space-3);
  font-size: var(--type-xs);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 600;
  color: var(--color-faint);
}
.sidebar h3 a { color: inherit; text-decoration: none; }
.sidebar h3 a:hover { color: var(--color-text); }
.sidebar ol.sidebar-modules {
  list-style: decimal inside;
  padding: 0;
  margin: 0;
  color: var(--color-link);   /* complement — sidebar numerals pop on every page */
}
.sidebar ol.sidebar-modules > li {
  margin: var(--space-2) 0;
  padding-left: var(--space-1);
  /* Hang the marker — number sits flush, title indents */
  text-indent: -1.2em;
  padding-left: 1.2em;
}
.sidebar ol.sidebar-modules > li > a {
  color: var(--color-text);
  text-decoration: none;
}
.sidebar ol.sidebar-modules > li > a:hover {
  color: var(--color-primary);
}
.sidebar ol.sidebar-modules > li.current > a {
  color: var(--color-primary);
  font-weight: 600;
}
.sidebar ul.sidebar-children {
  list-style: none;
  padding-left: 1rem;
  margin: var(--space-1) 0 var(--space-3);
  font-size: var(--type-xs);
  text-indent: 0;
}
.sidebar ul.sidebar-children li { margin: var(--space-1) 0; padding-left: 0; text-indent: 0; }
.sidebar ul.sidebar-children a {
  color: var(--color-muted);
  text-decoration: none;
}
.sidebar ul.sidebar-children a:hover { color: var(--color-primary); }

/* ============================================================= */
/* Typography — modular scale, vertical rhythm                    */
/* ============================================================= */

h1, h2, h3, h4, h5, h6 {
  font-family: var(--font-ui);
  line-height: var(--line-heading);
  font-weight: 700;
  /* Small caps treatment: every letter renders as a small-cap glyph.
   * Proper nouns lose distinction but headings gain editorial calm —
   * fits the "this is a chapter marker" reading rhythm. Letter-spacing
   * adds a touch of openness so the small-caps don't crowd. */
  font-variant-caps: all-small-caps;
  letter-spacing: 0.04em;
}

/* Page h1 — the article's voice. Carries primary color. */
h1 {
  color: var(--color-primary);
  font-size: var(--type-3xl);
  margin: 0 0 var(--space-4);
  line-height: 1.15;
  letter-spacing: 0.02em;
}

/* Section h2 — major break inside an article. Separation comes from
 * generous top margin alone; no rule. The whitespace IS the break. */
h2 {
  color: var(--color-text);
  font-size: var(--type-2xl);
  margin: var(--space-12) 0 var(--space-3);
}

/* Inside .practice (and other callouts), no top rule — the box itself separates */
.callout h2,
.practice h2,
.model-answer-cta h2 {
  border-top: 0;
  padding-top: 0;
  margin-top: 0;
}

h3 {
  color: var(--color-text);
  font-size: var(--type-xl);
  margin: var(--space-8) 0 var(--space-2);
}

/* Heading anchor — appears on hover, copies hash on click.
 * Renders only on Markdown-sourced headings (via render-heading.html hook).
 * Reads as a quiet annotation mark, not a competing brand element. */
.md-heading {
  position: relative;
  scroll-margin-top: var(--space-12);
}
.heading-anchor {
  display: inline-block;
  margin-left: var(--space-2);
  color: var(--color-link);
  text-decoration: none;
  font-weight: 400;
  opacity: 0;
  transition: opacity 0.12s ease, color 0.12s ease;
  font-size: 0.85em;
}
.md-heading:hover .heading-anchor,
.heading-anchor:focus-visible {
  opacity: 1;
}
.heading-anchor:hover {
  color: var(--color-link-hover);
  opacity: 1;
}
h4 {
  color: var(--color-text);
  font-size: var(--type-lg);
  margin: var(--space-6) 0 var(--space-2);
}

p, ul, ol, dl, blockquote, pre, table, figure {
  margin: var(--space-4) 0;
}

/* Links — complementary color (hue+180), classic editorial pairing.
 * Headings/structure use the primary; links use the complement so they
 * stand out from prose by hue, not just by underline. The underline is
 * thick and at full link color (not desaturated) so the link is obvious
 * even at a glance. On hover, a soft highlight wash signals interactivity. */
a {
  color: var(--color-link);
  text-decoration-line: underline;
  text-decoration-thickness: 2px;
  text-underline-offset: 0.18em;
  text-decoration-color: var(--color-link);
  text-decoration-skip-ink: auto;
  font-weight: 500;
  border-radius: 2px;
  transition: background-color 0.12s ease, color 0.12s ease, text-decoration-color 0.12s ease;
  padding: 0 0.05em;
}
a:hover {
  color: var(--color-link-hover);
  background-color: var(--color-link-soft);
  text-decoration-color: var(--color-link-hover);
}

/* Glossary tooltip links — same complement color so they're clearly clickable,
 * but a DOTTED underline differentiates them from regular hyperlinks (signals
 * "definition available" vs "external/internal link"). */
a.gloss {
  color: var(--color-link);
  text-decoration: none;
  font-weight: 500;
  border-bottom: 2px dotted var(--color-link);
  padding: 0 0.05em;
  border-radius: 2px;
  transition: background-color 0.12s ease, color 0.12s ease, border-bottom-color 0.12s ease;
}
a.gloss:hover {
  color: var(--color-link-hover);
  background-color: var(--color-link-soft);
  border-bottom-color: var(--color-link-hover);
  border-bottom-style: solid;
}

/* Inline code — neutral surface, ink text. Stays out of the way. */
code {
  font-family: var(--font-mono);
  background: var(--color-surface);
  color: var(--color-text);
  padding: 0.1em 0.35em;
  border-radius: 3px;
  font-size: 0.9em;
  border: 1px solid var(--color-border);
}

/* Block code — same surface, larger pad, no inline border */
pre {
  font-family: var(--font-mono);
  background: var(--color-surface);
  padding: var(--space-4);
  border-radius: var(--radius);
  overflow-x: auto;
  border: 1px solid var(--color-border);
  font-size: var(--type-xs);
  line-height: 1.55;
}
pre code {
  background: transparent;
  padding: 0;
  border: 0;
  color: inherit;
  font-size: 1em;
}
pre.mermaid {
  background: var(--color-bg);
  text-align: center;
  padding: var(--space-6);
}
pre.mermaid svg { max-width: 100%; height: auto; }

/* Tables — quiet. Only header gets a subtle fill. */
table {
  border-collapse: collapse;
  width: 100%;
  font-size: var(--type-xs);
}
th, td {
  border-bottom: 1px solid var(--color-border);
  padding: var(--space-2) var(--space-3);
  text-align: left;
  vertical-align: top;
}
th {
  background: var(--color-surface);
  font-family: var(--font-ui);
  color: var(--color-text);
  font-weight: 600;
  border-bottom-width: 2px;
}

/* Lists — restrained */
ul, ol { padding-left: 1.4em; }
li { margin: var(--space-1) 0; }
li > ul, li > ol { margin: var(--space-1) 0; }

/* Blockquote — left strip in primary, neutral bg */
blockquote {
  margin: var(--space-6) 0;
  padding: var(--space-3) var(--space-4);
  border-left: 3px solid var(--color-primary);
  background: var(--color-primary-fade);
  color: var(--color-text);
  font-style: normal;
  border-radius: 0 var(--radius) var(--radius) 0;
}
blockquote > :first-child { margin-top: 0; }
blockquote > :last-child  { margin-bottom: 0; }

hr {
  border: 0;
  border-top: 1px solid var(--color-rule);
  margin: var(--space-8) 0;
}

/* ============================================================= */
/* Home — editorial, not card-in-card                             */
/* ============================================================= */

.home > h1:first-child {
  font-size: var(--type-4xl);
  letter-spacing: 0.01em;
  line-height: 1.1;
  color: var(--color-text);
  margin: var(--space-4) 0 var(--space-3);
  position: relative;
}
.home > h1:first-child::after {
  /* Two-tone rule: primary into its complement. The single most visible
   * spot on the home page where both colors meet. */
  content: "";
  display: block;
  width: 4rem;
  height: 4px;
  background: linear-gradient(to right, var(--color-primary), var(--color-link));
  margin-top: var(--space-3);
}
.home .tagline {
  font-size: var(--type-md);
  color: var(--color-muted);
  margin: 0 0 var(--space-12);
  max-width: 60ch;
  line-height: 1.5;
}
/* "MODULES" eyebrow — small complement-color label */
.home > h2 {
  border-top: 0;
  padding-top: 0;
  margin: var(--space-8) 0 var(--space-3);
  font-size: var(--type-xs);
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--color-link);
  font-weight: 700;
}

@media (max-width: 800px) {
  .home > h1:first-child { font-size: var(--type-3xl); }
  h1 { font-size: var(--type-2xl); }
}

/* ============================================================= */
/* Module list — clickable items. Cards because they ARE the      */
/* interaction. Hairline border, subtle hover lift.               */
/* ============================================================= */

.module-list {
  list-style: none;
  padding: 0;
  margin: var(--space-4) 0 var(--space-8);
  counter-reset: module;
  display: grid;
  gap: var(--space-3);
}
/* Whole card is a single anchor — clicking anywhere navigates.
 * Border is a uniform hairline; hover applies a low-alpha primary tint
 * over the page background so contrast with text stays high. */
.module-item {
  counter-increment: module;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  background: var(--color-bg);
  transition: border-color 0.18s ease, background 0.25s ease, transform 0.18s ease;
  position: relative;
}
.module-item:hover,
.module-item:focus-within {
  border-color: var(--color-primary);
  background: hsla(var(--hue), 60%, 50%, 0.06);
  transform: translateY(-1px);
}
.module-item-link {
  display: grid;
  grid-template-columns: 2.25rem 1fr;
  column-gap: var(--space-2);
  padding: var(--space-4) var(--space-6);
  text-decoration: none;
  color: inherit;
  border-radius: inherit;
}
.module-item-link:hover { text-decoration: none; color: inherit; }
.module-item::before {
  content: counter(module);
  color: var(--color-link);   /* complement — visible spot against the primary-themed canvas */
  font-family: var(--font-ui);
  font-weight: 700;
  font-size: var(--type-lg);
  line-height: 1.2;
  position: absolute;
  left: var(--space-6);
  top: var(--space-4);
  font-variant-numeric: tabular-nums;
  pointer-events: none;
}
.module-item-link > * {
  display: block;
  grid-column: 2;
}
.module-item-link > * + * { margin-top: var(--space-2); }
.module-item-header {
  font-family: var(--font-ui);
  font-weight: 600;
  font-size: var(--type-md);
  color: var(--color-text);
  line-height: 1.3;
}
.module-item:hover .module-item-header,
.module-item:focus-within .module-item-header { color: var(--color-primary); }
.module-item-summary { color: var(--color-muted); font-size: var(--type-sm); }
.driving-question-inline {
  color: var(--color-faint);
  font-style: italic;
  font-size: var(--type-xs);
}

/* ============================================================= */
/* Visual-needed callout — placeholder for slots where free-use   */
/* imagery is unavailable. Soft tinted block with action links to */
/* YouTube and Wikimedia searches. Use sparingly — a wall of      */
/* these is a sign the module is missing real visual content.    */
/* ============================================================= */
.visual-needed {
  margin: var(--space-6) 0;
  padding: var(--space-4) var(--space-5);
  border-left: 3px solid var(--color-primary);
  background: hsla(var(--hue), 60%, 50%, 0.05);
  border-radius: var(--radius);
  font-size: var(--type-sm);
}
.visual-needed-label {
  font-family: var(--font-ui);
  font-weight: 600;
  color: var(--color-primary-strong);
  margin-bottom: var(--space-2);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  font-size: var(--type-xs);
}
.visual-needed-body { margin-bottom: var(--space-3); color: var(--color-text); }
.visual-needed-body p { margin: 0 0 var(--space-2); }
.visual-needed-body p:last-child { margin-bottom: 0; }
.visual-needed-links { display: flex; flex-wrap: wrap; gap: var(--space-3); }
.visual-needed-links a {
  font-family: var(--font-ui);
  font-size: var(--type-xs);
  text-decoration: none;
  color: var(--color-primary);
  border: 1px solid var(--color-primary);
  padding: 0.25rem 0.6rem;
  border-radius: 999px;
  transition: background 0.15s ease;
}
.visual-needed-links a:hover {
  background: hsla(var(--hue), 60%, 50%, 0.12);
}

/* ============================================================= */
/* Module concept page                                            */
/* ============================================================= */

.module-header {
  margin-bottom: var(--space-8);
}
.module-header h1 {
  border: 0;
  padding: 0;
  margin: var(--space-2) 0 var(--space-3);
  font-size: var(--type-3xl);
}
.module-header .summary {
  font-size: var(--type-md);
  color: var(--color-muted);
  margin: 0 0 var(--space-4);
  line-height: 1.5;
  max-width: var(--measure);
}
/* "MODULE N" eyebrow — small complement-color label. Tiny dot of color
 * but visible on every module page; pairs visibly with the primary h1. */
.module-number {
  font-family: var(--font-ui);
  color: var(--color-link);
  font-size: var(--type-xs);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  display: block;
  margin-bottom: var(--space-2);
}

/* Driving question = the article's thesis statement. Quoted-pull-quote feel:
 * subtle left strip, no background fill, italic to read as "the question".
 * Keeps the h1 above as the unambiguous focal point. */
.driving-question {
  font-family: var(--font-body);
  font-size: var(--type-md);
  font-weight: 400;
  font-style: italic;
  padding: 0 0 0 var(--space-4);
  border-left: 3px solid var(--color-primary);
  margin: var(--space-6) 0 0;
  color: var(--color-muted);
  line-height: 1.5;
  max-width: 60ch;
}
.driving-question strong {
  font-weight: 400;
  color: var(--color-text);
}

.module-body { /* prose styles inherit */ }
.module-body > :first-child { margin-top: 0; }

.blog-link {
  font-family: var(--font-ui);
  font-size: var(--type-sm);
  margin: var(--space-3) 0 0;
}

/* ============================================================= */
/* Practice section — same callout pattern, slightly stronger     */
/* ============================================================= */

.practice {
  margin: var(--space-12) 0 var(--space-6);
  padding: var(--space-6);
  background: var(--color-primary-fade);
  border-left: 4px solid var(--color-primary);
  border-radius: 0 var(--radius) var(--radius) 0;
}
.practice h2 {
  color: var(--color-primary-strong);
  font-size: var(--type-xl);
}
.practice ul { padding-left: 1.25rem; margin-bottom: 0; }
.practice li { margin: var(--space-2) 0; }
.practice a { color: var(--color-primary-strong); }

/* ============================================================= */
/* Module prev/next nav                                           */
/* ============================================================= */

.module-nav {
  display: flex;
  justify-content: space-between;
  gap: var(--space-6);
  margin-top: var(--space-12);
  padding-top: var(--space-6);
  border-top: 1px solid var(--color-rule);
}
.module-nav-slot {
  flex: 1 1 50%;
  font-family: var(--font-ui);
  font-size: var(--type-sm);
  min-width: 0;
}
.module-nav-prev { text-align: left; }
.module-nav-next { text-align: right; }
.module-nav a {
  text-decoration: none;
  color: var(--color-text);
  display: inline-block;
  font-weight: 500;
}
.module-nav a:hover { color: var(--color-primary); }
.module-nav .label {
  display: block;
  color: var(--color-link);
  font-size: var(--type-xs);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin-bottom: var(--space-1);
  font-weight: 700;
}

/* ============================================================= */
/* Single page (validation, exercise, answer, glossary)           */
/* ============================================================= */

.single > header { margin-bottom: var(--space-6); }
.single > header h1 { margin: 0; }
.single-body > :first-child { margin-top: 0; }

.back-link {
  margin-top: var(--space-12);
  font-family: var(--font-ui);
  font-size: var(--type-sm);
}
.back-link a { color: var(--color-muted); text-decoration: none; }
.back-link a:hover { color: var(--color-primary); }

/* ============================================================= */
/* Exercise → model-answer CTA                                    */
/* ============================================================= */

.model-answer-cta {
  margin: var(--space-12) 0 var(--space-4);
  padding: var(--space-6);
  border: 1px dashed var(--color-primary);
  border-radius: var(--radius);
  background: var(--color-primary-fade);
}
.model-answer-cta p { margin: 0 0 var(--space-3); color: var(--color-text); }
.model-answer-cta p strong { color: var(--color-primary-strong); }

.model-answer-button {
  display: inline-block;
  padding: var(--space-2) var(--space-4);
  font-family: var(--font-ui);
  font-weight: 600;
  font-size: var(--type-sm);
  text-decoration: none;
  color: var(--color-bg);
  background: var(--color-primary);
  border-radius: var(--radius);
  border: 1px solid var(--color-primary-strong);
  transition: background-color 0.12s ease, transform 0.12s ease;
}
.model-answer-button:hover {
  background: var(--color-primary-strong);
  transform: translateY(-1px);
}

/* ============================================================= */
/* Glossary — definition list feel, not section feel              */
/* ============================================================= */

/* The glossary page is a long alphabetical list. Each <h2> is a TERM,
 * not a section break. Override the page-h2 styling to look more like
 * an entry header in a dictionary. */
.single-body h2 {
  font-family: var(--font-ui);
  font-size: var(--type-lg);
  color: var(--color-primary-strong);
  border-top: 0;
  padding-top: 0;
  margin: var(--space-8) 0 var(--space-2);
  font-weight: 700;
}
.single-body h2 + p {
  margin-top: 0;
  color: var(--color-text);
  max-width: var(--measure);
}

/* ============================================================= */
/* Section index pages (validation, exercises lists)              */
/* ============================================================= */

.section h1 { font-size: var(--type-3xl); }
.section > p:first-of-type { font-size: var(--type-md); color: var(--color-muted); max-width: 60ch; }

/* ============================================================= */
/* Footer                                                         */
/* ============================================================= */

footer {
  max-width: var(--layout-max);
  margin: var(--space-16) auto var(--space-6);
  padding: var(--space-6) var(--space-6) 0;
  border-top: 1px solid var(--color-rule);
  color: var(--color-faint);
  font-size: var(--type-xs);
  text-align: center;
}
footer p { margin: 0; max-width: 60ch; margin-inline: auto; }
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
    # README.md — only write if missing, so we don't clobber user edits on re-scaffold
    if [ ! -f "$TARGET/README.md" ] && [ -f "$TEMPLATES_DIR/README.md.tmpl" ]; then
      # Use awk so multi-line description with special chars is safe (sed s/// chokes on /, &, etc.)
      awk -v title="$TITLE" -v desc="$DESCRIPTION" '
        { gsub(/\{\{TITLE\}\}/, title); gsub(/\{\{DESCRIPTION\}\}/, desc); print }
      ' "$TEMPLATES_DIR/README.md.tmpl" > "$TARGET/README.md"
    fi
    # .claude/settings.local.json — Claude Code permission allowlist for /tmb:publish.
    # Only write if missing; users may have customized their own.
    if [ ! -f "$TARGET/.claude/settings.local.json" ] && [ -f "$TEMPLATES_DIR/.claude/settings.local.json" ]; then
      mkdir -p "$TARGET/.claude"
      cp "$TEMPLATES_DIR/.claude/settings.local.json" "$TARGET/.claude/settings.local.json"
    fi
    # site/content/about.md — about page from template, only if missing.
    # Renders at /about/ and is linked from the top nav.
    if [ ! -f "$TARGET/site/content/about.md" ] && [ -f "$TEMPLATES_DIR/about.md.tmpl" ]; then
      cp "$TEMPLATES_DIR/about.md.tmpl" "$TARGET/site/content/about.md"
    fi
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
