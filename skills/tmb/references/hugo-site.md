# Hugo Site: Setup Guide

Hugo is a free tool that turns markdown files into a website you can view in your
browser. The curriculum folder always contains a Hugo site — it's how you browse
the modules, check the glossary, and track your progress.

Before writing any markdown content for Hugo, read `references/markdown-gotchas.md`.

---

## Installing Hugo

Hugo must be installed before `init.sh` can run. Check for it first:

```sh
hugo version
```

If that prints a version number (e.g. `hugo v0.128.0`), Hugo is already installed.
If it prints "command not found" or similar, install it:

### macOS

```sh
brew install hugo
```

If you don't have Homebrew, install it first from https://brew.sh — it's a free
package manager for macOS. Takes about 5 minutes the first time.

### Windows

Open PowerShell and run:

```powershell
winget install Hugo.Hugo.Extended
```

Or with Chocolatey if you have it:

```powershell
choco install hugo-extended
```

If neither is available, download the installer directly from
https://github.com/gohugoio/hugo/releases — look for the file ending in
`windows-amd64.zip`, unzip it, and add it to your PATH.

### Linux (Ubuntu/Debian)

```sh
sudo snap install hugo
```

Or download directly from https://github.com/gohugoio/hugo/releases — look for
the file matching your architecture (usually `linux-amd64.tar.gz`).

### Verify it worked

```sh
hugo version
# Should print something like: hugo v0.128.0 linux/amd64 ...
```

Any version from 0.120.0 onwards works. If you see an older version, upgrade it
using the same method you used to install.

---

## The HOW-TO-VIEW-SITE.md template

Write this file to the curriculum folder alongside `init.sh`. It gives non-technical
users everything they need to view and maintain the site without asking for help.

```markdown
# How to view your learning site

Your curriculum has a small website you can browse in your browser. Here's everything
you need to use it.

## First time: what you'll need

One tool: **Hugo**. It's free and takes about 2 minutes to install.

Open your terminal (on Mac: press ⌘+Space and type "Terminal") and run:

    hugo version

If you see a version number, you're ready. If not, run:

    brew install hugo       ← macOS
    winget install Hugo.Hugo.Extended   ← Windows

For other platforms: https://gohugo.io/installation/

## Viewing the site

Every time you want to browse your curriculum:

1. Open your terminal
2. Run these two commands (replace the path with your actual folder location):

       cd [CURRICULUM_PATH]/site
       hugo server -D

3. Open your browser and go to: **http://localhost:1313**

The site will show your modules, their status, and links to blog posts as you
complete them.

## Stopping the site

Press **Ctrl+C** in the terminal. The site stops; your files are untouched.

## Updating the site

The site reflects whatever is in the `modules/` folder. After you edit a module's
README or update a status, just restart Hugo:

    cd [CURRICULUM_PATH]/site
    hugo server -D

## Updating a module's status

When you finish a module, open `site/content/modules/NN-module-name/index.md`
and change:

    status: planned

to:

    status: done

Add your blog post URL if you wrote one:

    blog_post: https://yourblog.com/your-post

Refresh your browser and the site updates automatically.

## Publishing to the web (optional)

If you want to share the site publicly, see the GitHub Pages section in
`references/hugo-site.md` in the skill files. It's optional — the local
version is all you need for personal use.

## Troubleshooting

**"hugo: command not found"** — Hugo isn't installed yet. See the installation
steps above.

**"port 1313 already in use"** — Another Hugo server is already running. Either
stop it (find the terminal and press Ctrl+C) or run on a different port:
`hugo server -D -p 1314`

**The site looks broken / CSS not loading** — Make sure you're running Hugo
from inside the `site/` folder, not the parent folder.

**Changes aren't showing** — Make sure you saved the file. Hugo watches for
changes automatically — no need to restart.
```

---

## Site configuration: hugo.yaml

The main config goes in `site/hugo.yaml`. The key parameter for theming is `hue`,
which controls the color scheme. See the CSS section below.

```yaml
baseURL: /
languageCode: en-us
title: "<Curriculum Title>"
paginate: 20

params:
  description: "<One sentence describing this curriculum and who it's for>"
  author: "<Your name>"
  hue: <H>    # from interview Step 7 — e.g. 55 for yellow/gold, 220 for blue

taxonomies:
  tag: tags
  topic: topics
```

---

## Hugo archetypes

Archetypes are templates that Hugo uses when you run `hugo new content/...`.
They ensure every module page has the right frontmatter structure automatically.

### `site/archetypes/modules.md`

```markdown
---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
weight: 0
status: planned
summary: ""
topics: []
blog_post: ""
date: {{ .Date }}
draft: false
---
```

### `site/archetypes/glossary.md`

```markdown
---
title: "Glossary"
date: {{ .Date }}
draft: false
---
```

---

## Hugo layout files

These five files form the complete layout system. They are written by `init.sh`
as heredocs — identical for every curriculum, parameterized only by `--hue`.

### baseof.html

The outer shell for every page. Injects `--hue` from `hugo.yaml` as an inline
CSS variable so every color in the stylesheet derives from it.

```html
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
```

### partials/nav.html

```html
<nav>
  <a href="{{ "/" | relURL }}">{{ .Site.Title }}</a>
  <ul>
    <li><a href="{{ "/modules/" | relURL }}">Modules</a></li>
    <li><a href="{{ "/glossary/" | relURL }}">Glossary</a></li>
    <li><a href="https://github.com/<username>/<repo>" target="_blank" rel="noopener">GitHub ↗</a></li>
    <li><a href="https://<blog-url>" target="_blank" rel="noopener">Blog ↗</a></li>
  </ul>
</nav>
```

### index.html (home page)

```html
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
```

### page.html (single module or glossary page)

```html
{{ define "main" }}
<article class="module">
  <header class="module-header">
    <div class="module-meta">
      {{ if .Params.weight }}<span class="module-number">Module {{ .Params.weight }}</span>{{ end }}
      {{ with .Params.status }}<span class="status status-{{ . }}">{{ . }}</span>{{ end }}
    </div>
    <h1>{{ .Title }}</h1>
    {{ with .Params.summary }}<p class="summary">{{ . }}</p>{{ end }}
    {{ with .Params.blog_post }}
    <p class="blog-link">📝 <a href="{{ . }}" target="_blank" rel="noopener">Read the blog post ↗</a></p>
    {{ end }}
  </header>
  <div class="module-body">{{ .Content }}</div>
  <nav class="module-nav">
    {{ with .PrevInSection }}<a class="prev" href="{{ .RelPermalink }}">← {{ .Title }}</a>{{ end }}
    {{ with .NextInSection }}<a class="next" href="{{ .RelPermalink }}">{{ .Title }} →</a>{{ end }}
  </nav>
</article>
{{ end }}
```

### section.html (module listing)

```html
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
      {{ with .Params.blog_post }}
      <p class="blog-link">📝 <a href="{{ . }}" target="_blank" rel="noopener">Blog post ↗</a></p>
      {{ end }}
    </li>
    {{ end }}
  </ol>
</div>
{{ end }}
```

---

## CSS: the HSLA color system

All colors are derived from a single `--hue` value (0–360, the color wheel).
Changing `params.hue` in `hugo.yaml` re-themes the entire site.

Key relationships used:
- **Primary:** `hsla(var(--hue), 65%, 38%, 1)` — the main color
- **Analogous:** `hue + 30` — warm neighbor, used for hover states
- **Triadic:** `hue + 120` — used for tags and topic badges
- **In-progress:** `hue + 50` — warm yellow-shifted variant
- **Done:** `hue + 140` — cool green-shifted variant

```css
:root {
  --color-primary:       hsla(var(--hue), 65%, 38%, 1);
  --color-primary-light: hsla(var(--hue), 65%, 96%, 1);
  --color-analogous:     hsla(calc(var(--hue) + 30), 70%, 46%, 1);
  --color-triadic:       hsla(calc(var(--hue) + 120), 55%, 42%, 1);
  --color-triadic-light: hsla(calc(var(--hue) + 120), 55%, 93%, 1);
  --color-planned:       hsla(0, 0%, 84%, 1);
  --color-in-progress:   hsla(calc(var(--hue) + 50), 75%, 68%, 1);
  --color-done:          hsla(calc(var(--hue) + 140), 55%, 50%, 1);
  /* Neutrals — don't shift with hue */
  --color-bg: #ffffff; --color-text: #1a1a1a;
  --color-muted: #666; --color-border: #e5e5e5;
  --font-body: 'Georgia', serif;
  --font-ui:   system-ui, sans-serif;
  --font-mono: 'Menlo', 'Consolas', monospace;
  --max-width: 720px;
}
```

The full CSS block (with all selectors) is embedded in `init.sh` as a heredoc
and written to `site/assets/css/site.css` when `init.sh` runs.

---

## Running the site locally

```sh
cd site/
hugo server -D
```

Open http://localhost:1313. The `-D` flag shows draft content. Press Ctrl+C to stop.

To verify the color theme: open browser DevTools → Elements → `:root` computed
styles → check `--hue`. Change `params.hue` in `hugo.yaml` and Hugo hot-reloads.

---

## Publishing to GitHub Pages (optional)

Create `.github/workflows/deploy.yml` in the repo root:

```yaml
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
```

In GitHub: Settings → Pages → Source → GitHub Actions.

---

## Updating a module's status

When you complete a module, update two places:

**`site/content/modules/NN-name/index.md`:**
```yaml
status: done
blog_post: https://yourblog.com/post-slug
```

**Root `README.md` status table:**
```
| 2 | [Module Title](modules/02-slug/) | done | [link](https://...) |
```

The site rebuilds on next `hugo server` start (or auto-reloads if already running).
