---
title: "About this site"
type: about
weight: 999
draft: false
---

This curriculum was built with **[Train My Brain](https://github.com/alwaysmap/train-my-brain)** (TMB), a Claude Code plugin that turns an 8-question interview about what you want to learn into a structured local Hugo site — with concept pages, validation prompts, exercises, and a shared glossary.

## How TMB works

You sit down with the plugin, answer eight short questions about your goal, what testing-yourself looks like, your starting point, and how you read. Behind the scenes:

1. A **researcher agent** does one pass of web research and writes `research.yaml` — a canonical glossary, sourced reading list, and concept map that every later step grounds in.
2. A **designer agent** turns that into a module spine and per-module briefs.
3. **Module-builder agents** run in parallel — one per module — each writing a concept page, a validation page, and at least one exercise plus a model answer. Because they all read the same `research.yaml`, the modules are consistent without coordination.
4. A **reviewer** runs deterministic checks (adjacency, frontmatter drift, URL reachability, AI-prose detection, glossary merge + auto-linking) and writes any substantive findings into `review.md` for your approval.

The full source for this curriculum lives next to the rendered site — every `_index.md` under `site/content/modules/` is editable markdown.

## Install Train My Brain

You need [Claude Code](https://claude.com/claude-code) installed first, then:

```
/plugin install train-my-brain@alwaysmap
```

That gives you the slash commands listed below. Run `/tmb:help` inside Claude Code for the up-to-date list.

## Working with this curriculum

| Task | How |
|---|---|
| Run the local site | `./serve.sh` from the curriculum folder, then open <http://localhost:1313> |
| Stop the local site | `Ctrl-C` if you started serve.sh in your own terminal; `./stop.sh` if it's running in the tmux session `/tmb:create` started |
| Rebuild static output | `./build.sh` |
| Edit a module | Open `site/content/modules/<NN-slug>/_index.md` and save — the dev server hot-reloads |
| Add a new module | `/tmb:add-module` (append, or insert at a specific position) |
| Re-run consistency checks | `/tmb:review` |
| Refresh layouts after a TMB upgrade | `/tmb:rebuild-site` (won't touch your content) |
| Publish to GitHub Pages | `/tmb:publish` (interactive — handles `gh` auth, repo create, Pages enablement, deploy watch) |

## Editing content directly

The orchestrator built the first draft, but the curriculum is yours. Edit any markdown file under `site/content/`, save, and the dev server picks it up. If you want changes to survive `/tmb:rebuild-site` and `/tmb:review`, edit the matching brief at `briefs/<NN-slug>.yaml` too — the reviewer flags drift between brief and frontmatter as a substantive issue.

The brief is the source of truth for **structural** fields (title, short_title, driving_question, weight, contrast, prior/next stitching). The body of each `_index.md` is yours to revise freely.

## Where the project source lives

| File | What it is |
|---|---|
| `briefs/<NN-slug>.yaml` | The brief each module was built from |
| `curriculum_spine.md` | Module sequence + glossary seed + running example |
| `research.yaml` | Canonical glossary, sources, contrasts (every module shares it) |
| `glossary.md` | Merged glossary — also rendered at [/glossary/](/glossary/) |
| `review.md` | Reviewer findings; flip `approved: true` on a flag and re-run `/tmb:review` to apply it |
| `site/content/modules/<NN-slug>/` | Hugo branch bundle — concept page, validation page, exercises folder |

## Acknowledgements

TMB is open source — issues, ideas, and contributions go to <https://github.com/alwaysmap/train-my-brain>.
