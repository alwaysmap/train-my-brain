# Publishing your curriculum to GitHub Pages

Every TMB curriculum scaffolds with a ready-to-go `.github/workflows/deploy.yml`. Push the curriculum folder to a GitHub repository, enable Pages once, and every subsequent push to `main` rebuilds and deploys the site automatically. This file walks you through it.

You do not need to know GitHub Actions or Hugo to follow these steps — copy-paste each command in order.

## Prerequisites

- A GitHub account.
- The [`gh` CLI](https://cli.github.com/) installed and authenticated (`gh auth login`). If you'd rather not install `gh`, the manual `git remote add` path works too — both are below.
- Your TMB curriculum directory built locally (you've already run `/tmb:create` and `./build.sh` succeeded — you can see the site at http://localhost:1313).

## Step 1: Initialize the curriculum as a git repository

From inside your curriculum folder:

```sh
cd <curriculum-slug>     # e.g., cd postgresql-query-planning
git init
git add .
git commit -m "Initial curriculum"
```

The `.gitignore` shipped with TMB already excludes `site/public/`, `.hugo.pid`, and other build artifacts.

## Step 2: Create the GitHub repository

### Option A: with `gh` (recommended — one command)

```sh
gh repo create <your-username>/<curriculum-slug> --public --source=. --push
```

That creates a new public repo, sets it as `origin`, and pushes `main` in one go. Use `--private` instead if you don't want the source visible (Pages still works on private repos for paid plans; on free plans Pages requires public).

### Option B: with the GitHub web UI

1. Open https://github.com/new
2. Repository name: `<curriculum-slug>` (matches your local folder)
3. Public (or Private with a paid plan)
4. Do **not** initialize with README, license, or `.gitignore` — your local repo already has those.
5. Click **Create repository**.
6. Copy the `git remote add origin ...` line GitHub shows you and run it locally:
   ```sh
   git remote add origin https://github.com/<your-username>/<curriculum-slug>.git
   git branch -M main
   git push -u origin main
   ```

## Step 3: Enable GitHub Pages

The `deploy.yml` workflow needs Pages enabled before it can publish.

1. In the GitHub web UI, go to your repo → **Settings** → **Pages** (left sidebar, under "Code and automation").
2. Under **Build and deployment**, set **Source** to **GitHub Actions**.
3. Save (the button might be auto-applied — there's no explicit save on this page).

You don't need to pick a branch or folder — `deploy.yml` handles all of that.

## Step 4: Wait for the first deploy

The push from Step 2 already triggered the workflow. To watch:

```sh
gh run watch              # follows the latest run live
```

Or in the web UI: repo → **Actions** tab → click the running workflow.

The first run takes 1–2 minutes. When it finishes, the **Pages** settings page shows your site URL — typically `https://<your-username>.github.io/<curriculum-slug>/`.

## Step 5: Visit your site

Open the URL the Pages settings page shows. It can take an extra 30–60 seconds after the workflow succeeds for DNS to propagate.

If you see a 404, wait another minute and refresh. If it persists, jump to [Troubleshooting](#troubleshooting).

## Updating the site

Every push to `main` rebuilds and redeploys automatically — there's no manual step. After running `/tmb:add-module` or `/tmb:review`:

```sh
git add .
git commit -m "Add module on <topic>"
git push
```

The Action runs in 1–2 minutes; the live site picks up the change.

## Custom domain (optional)

If you want `learning.example.com` instead of the `*.github.io` URL:

1. In Pages settings, scroll to **Custom domain**, enter your domain, **Save**.
2. At your DNS provider, add a CNAME record from your subdomain to `<your-username>.github.io`.
3. Wait for DNS to propagate; GitHub will issue a Let's Encrypt cert automatically (can take ~15 minutes).
4. Tick **Enforce HTTPS** once it's available.

The TMB curriculum's `hugo.yaml` uses `baseURL: /` which works for both Pages defaults and custom domains. Don't change it.

## Troubleshooting

**404 on the deployed URL.**
Wait 60 seconds and refresh. If it persists, check Settings → Pages: the **Source** must be **GitHub Actions**, not **Deploy from a branch**. Re-saving fixes a surprising number of cases.

**Workflow failed: "Build failed: ... not extended Hugo".**
The `peaceiris/actions-hugo@v3` step in `deploy.yml` requests `extended: true`. If the build still fails, open `.github/workflows/deploy.yml` and confirm the `extended: true` line is present. Re-run the failed workflow from the Actions tab.

**Workflow failed: "no jekyll".**
Ignore — Pages auto-warns about missing Jekyll, but `deploy.yml` overrides it. Look at the actual job logs.

**Links broken when deployed (`/css/site.abc.css` 404 on the public URL).**
This means `baseURL` in `hugo.yaml` got changed. Restore it to `baseURL: /`. The deploy workflow already passes `--baseURL "${{ steps.pages.outputs.base_url }}/"` at build time, which overrides the file value with the correct Pages URL.

**Workflow is stuck in a queue forever.**
GitHub Actions has free-tier minute limits. If you've burned them this month, the workflow waits. Either upgrade or wait until the new month rolls over. Public repos on free plans get unlimited Action minutes — if you started private and want to switch, Settings → General → Change visibility.

**My site updates but the changes don't show.**
Hard-refresh the browser (Cmd+Shift+R / Ctrl+Shift+R). Pages aggressively caches; the underlying file is current.

## What ships in `deploy.yml`

For reference (you don't need to edit this file — TMB ships a working version):

- Triggers on push to `main` or manual dispatch.
- Uses `peaceiris/actions-hugo@v3` with extended Hugo.
- Sets `--baseURL` from the Pages-provided URL at build time.
- Uploads `site/public` as the Pages artifact.
- Deploys via `actions/deploy-pages@v4`.

If you genuinely need to customize the workflow (e.g., deploy only a subdirectory), edit `.github/workflows/deploy.yml` directly. The TMB plugin won't overwrite it on `/tmb:rebuild-site` — that command only refreshes Hugo layouts inside `site/`.
