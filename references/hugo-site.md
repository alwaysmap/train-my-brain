# Hugo in TMB curricula

Hugo is a tool that turns markdown files into a browsable website. In a TMB curriculum, the Hugo site under `site/` is the **single source of truth** for module concept prose. There is no README mirror, no sync script, no second authoring surface.

## Version and install

Hugo ≥ 0.120 (extended edition). The plugin ships a helper — `scripts/check-hugo.sh` (POSIX) or `scripts/check-hugo.ps1` (Windows) — that detects missing or outdated Hugo and offers a platform-appropriate install (`brew install hugo-extended`, `winget install Hugo.Hugo.Extended`, `snap install hugo --classic`, or `apt install hugo`). On decline, the helper prints the release URL — currently <https://github.com/gohugoio/hugo/releases/tag/v0.160.1> — and exits. Every orchestrator (`/tmb:tmb-create`, `/tmb:tmb-rebuild-site`, `/tmb:tmb-add-module`) calls this helper before anything else.

## Where the site lives

Each generated curriculum gets its own `site/` subdirectory:

```
<cwd>/<topic-slug>/
└── site/
    ├── archetypes/modules.md      # frontmatter template for new modules
    ├── assets/css/site.css        # hue-driven HSL theme
    ├── content/modules/NN-slug/index.md   # ← module content lives here
    ├── layouts/
    │   ├── baseof.html
    │   ├── _default/page.html
    │   ├── _default/section.html
    │   ├── index.html
    │   └── partials/nav.html
    ├── hugo.yaml
    └── public/                    # written by ./build.sh
```

All layouts, CSS, and the archetype are written by `scripts/scaffold-site.sh` (embedded heredocs). A user never edits them directly. If the plugin's scaffold templates evolve, `/tmb:tmb-rebuild-site --layouts-only` refreshes them without touching `content/`.

## Frontmatter contract

The archetype at `site/archetypes/modules.md` defines the frontmatter shape every module page carries. Beyond Hugo's built-in `title`, `weight`, `status`, `summary`, `topics`, `blog_post`, `date`, `draft`, TMB adds:

| Field | Source | Purpose |
|---|---|---|
| `driving_question` | brief | the question this module answers (per curriculum-design.md pattern) |
| `concepts` | brief | 3–5 named concepts the module covers |
| `contrast` | brief | the alternative this module compares against |
| `prior_ends_with` | brief | one-line handoff state the previous module leaves behind |
| `next_expects` | brief | one-line handoff state the next module begins from |

The module-builder agent copies these verbatim from `briefs/NN-slug.yaml` so the reviewer can check adjacency by reading frontmatter alone, without parsing prose.

## Theme

One HSL hue (from interview Step 7) drives every color via `site/hugo.yaml` `params.hue`. Primary, analogous, triadic, status-done, and status-in-progress all derive from it in `assets/css/site.css`. Changing one number retheme's the site.

## GitHub Pages (optional)

Each scaffold includes `.github/workflows/deploy.yml` wired to Hugo Pages. The workflow is unopinionated: the user enables Pages in Settings → Pages → Source → GitHub Actions if they want it. The plugin does not enable Pages automatically.

## How a user views the site

One command from the curriculum root: `./serve.sh`. It checks Hugo, starts `hugo server -D` from `site/`, writes the PID to `.hugo.pid`, and prints <http://localhost:1313>. `./stop.sh` reads the PID and kills the process. `./build.sh` runs `hugo --minify` and writes `site/public/` for static deployment.

Users on Windows use `serve.ps1`, `stop.ps1`, `build.ps1` — same interface.
