# Releasing

The repo has no Node runtime — release tooling is plain bash + jq + git.

```sh
bash scripts/release.sh 0.4.0
```

That script:

1. Verifies the working tree is clean and the tag doesn't already exist.
2. Bumps `version` in `.claude-plugin/plugin.json`.
3. Commits the bump.
4. Creates the `v0.4.0` git tag.
5. Pushes `HEAD` and the tag.

Pushing the tag triggers `.github/workflows/release.yml`, which builds `train-my-brain.zip`, creates a GitHub Release, and dispatches `plugin-released` to `alwaysmap/alwaysmap-marketplace` — its workflow then updates `marketplace.json` automatically.

Local-only build (no tag, no push):

```sh
bash scripts/build.sh
```

## Prerequisites

`MARKETPLACE_DISPATCH_TOKEN` must be set in this repo's Actions secrets — a fine-grained PAT scoped to `alwaysmap/alwaysmap-marketplace` with Contents write permission.
