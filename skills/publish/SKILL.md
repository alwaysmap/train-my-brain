---
name: publish
description: >
  Use this skill when the user wants to publish their TMB curriculum to GitHub
  Pages. Triggers on "/tmb:publish", "publish my curriculum", "deploy to github
  pages", "put this online", "share my curriculum". Walks the user through
  `gh` authentication, repo creation, Pages enablement, and the first deploy
  watch — executing each step interactively rather than dumping commands.
user_summary: >
  Publish your curriculum to GitHub Pages. Creates the repo, enables Pages,
  watches the first deploy, and prints the live URL. You stay in control —
  every state-changing step is confirmed before it runs.
version: 0.1.0
argument-hint: "<no arguments — operates on cwd>"
allowed-tools: [Read, Write, Bash, AskUserQuestion]
---

# /tmb:publish

Walk the user from "curriculum exists locally" to "live on GitHub Pages." Your job is to execute each step interactively — confirming destructive or visible actions before they happen — not to dump a script. Every command you run, you announce in one line first.

You operate on `$(pwd)`. If the user is in the wrong directory, abort early and tell them.

## Phase 0: Preflight

Run, in order, stopping on the first failure:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-curriculum.sh "$(pwd)"
```

- If `state` is not `v0.4-complete` or `v0.4-partial`, refuse: *"This directory does not look like a TMB v0.4 curriculum (state: <X>). Run /tmb:publish from inside a curriculum folder."*
- If `site/` is missing, refuse: *"No site/ directory found — nothing to publish."*

```bash
command -v gh >/dev/null 2>&1
```

- If gh is not installed: print *"GitHub CLI (`gh`) is required. Install it: https://cli.github.com/ — on macOS: `brew install gh`. Re-run /tmb:publish after installing."* and stop.

```bash
gh auth status
```

- If not authenticated: print *"You're not logged in to GitHub via `gh`. Run `gh auth login` (in your terminal — it's interactive), then re-run /tmb:publish."* and stop. Do NOT try to run `gh auth login` from inside the skill — it requires a TTY you don't have.

```bash
gh api user --jq .login
```

Capture as `GH_USER`. You'll suggest it as the repo owner default.

```bash
ls .github/workflows/deploy.yml >/dev/null 2>&1
```

- If missing: refuse — *"This curriculum is missing `.github/workflows/deploy.yml`. Run `/tmb:rebuild-site` to refresh the scaffold, then re-run /tmb:publish."*

## Phase 1: Confirm repo identity

Compute defaults:

- `OWNER` = `GH_USER` (the authenticated GitHub user).
- `REPO` = the curriculum folder name (`basename "$(pwd)"`).

Print one line stating both, then `AskUserQuestion`:

> Quick confirmation: I'll create `<OWNER>/<REPO>` on GitHub.

```
question: "Create this repository?"
header:   "Repo identity"
multiSelect: false
options:
  - label: "Public — proceed"
    description: "Create <OWNER>/<REPO> as a public repo. Public repos get unlimited Pages bandwidth on free plans."
  - label: "Private — proceed"
    description: "Create <OWNER>/<REPO> as a private repo. Pages on private repos requires a paid GitHub plan."
  - label: "Use a different name"
    description: "I'll ask for a different repo name (owner stays as your GitHub user)."
```

If the user picks "different name", ask for it as plain prose, then re-call this picker with the new name.

If `gh repo view "<OWNER>/<REPO>"` returns success, the repo already exists. Pivot:

> The repo `<OWNER>/<REPO>` already exists.

```
question: "What do you want to do?"
header:   "Repo exists"
multiSelect: false
options:
  - label: "Use the existing repo"
    description: "Add it as `origin` (if not already wired) and push the current curriculum."
  - label: "Use a different name"
    description: "Pick a different name and create a fresh repo."
  - label: "Cancel"
    description: "Stop without changing anything."
```

## Phase 2: Initialize git (if needed)

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

- If `false` (not a git repo): announce, then run `git init -b main`, `git add .`, `git commit -m "Initial curriculum"`. If `git init` defaults to `master`, rename: `git branch -m master main`.
- If `true`: check `git status --porcelain`. If dirty, surface a one-line summary (e.g. *"3 modified files, 2 untracked. I'll stage and commit them as 'Pre-publish snapshot'."*) and confirm via `AskUserQuestion` before staging+committing. If clean, skip.

Never run `git config` to set user.name/email — if the commit fails because git config is unset, surface the verbatim error and stop. The user fixes that in their global config.

## Phase 3: Create the repo and push

```bash
gh repo create "<OWNER>/<REPO>" --<public|private> --source=. --push
```

Surface the output. On failure, propagate verbatim and stop.

## Phase 4: Enable Pages

GitHub Pages requires a one-time enablement. Do it via the API — no need to send the user to the web UI:

```bash
gh api -X POST "/repos/<OWNER>/<REPO>/pages" -f build_type=workflow
```

Two known non-fatal outcomes:

- HTTP 409 / "Pages site already exists" — fine, continue.
- HTTP 422 with "build_type" — older `gh` versions; fall back:
  ```
  gh api -X POST "/repos/<OWNER>/<REPO>/pages" -f source='{"branch":"main","path":"/"}'
  gh api -X PUT  "/repos/<OWNER>/<REPO>/pages" -f build_type=workflow
  ```

If the API returns 403, the user's `gh` token doesn't have the `workflow` scope. Print: *"Your gh token is missing the `workflow` scope needed to enable Pages. Run `gh auth refresh -s workflow` and re-run /tmb:publish."* — and stop.

## Phase 5: Watch the first deploy

The push from Phase 3 already triggered the workflow. Find its run id:

```bash
sleep 3   # let the workflow register
RUN_ID=$(gh run list --workflow=deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

If `RUN_ID` is empty after a few seconds, retry once more after another 3-second pause. If still empty, surface: *"Workflow hasn't registered yet. Check `gh run list --workflow=deploy.yml` in a minute."* and skip to Phase 6 with no live URL.

Otherwise:

```bash
gh run watch "$RUN_ID" --exit-status
```

This blocks until the run finishes and exits non-zero on failure. On failure, fetch the failed step logs:

```bash
gh run view "$RUN_ID" --log-failed
```

Surface the last 30 lines. Stop without printing a "live" block.

## Phase 6: Resolve the URL and deliver

```bash
PAGE_URL=$(gh api "/repos/<OWNER>/<REPO>/pages" --jq .html_url 2>/dev/null)
```

Print:

```
🎉 Published.

Live URL:    <PAGE_URL>
Repo:        https://github.com/<OWNER>/<REPO>
Local site:  http://localhost:1313  (still running, if you started it)

To update later:
  git add . && git commit -m "<message>" && git push
  (the workflow rebuilds and redeploys in ~1–2 minutes)

If the URL 404s for a minute, that's DNS propagation — refresh.
```

If `PAGE_URL` was empty (Phase 5 fallback), substitute the predictable URL `https://<OWNER>.github.io/<REPO>/` and add a one-line note: *"Pages may still be provisioning — check repo Settings → Pages in 60 seconds."*

## Standing rules

- Never run `gh auth login` — it needs a TTY. Always punt to the user.
- Never run `git push --force`. Never `git config --global` anything.
- Every command you execute, announce on the line above it: `[<short verb-led description>]` then the command. Match the phase counter pattern from `/tmb:create`: `[2 of 6] Initializing the git repository...` etc.
- If `gh` returns a credential prompt or 2FA challenge, propagate verbatim and stop — don't try to handle it.
- The full reference (manual flow, custom domains, troubleshooting) is `references/github-pages.md`. Point users there if they ask "how does this work" or hit an edge case this skill doesn't cover.
