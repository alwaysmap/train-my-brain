# Releasing

## Prerequisites

- Clean working tree (no uncommitted changes)
- HEAD is a fast-forward of `origin/main`
- Push access to `origin`

## Steps

```bash
npm run release -- X.Y.Z
```

This single command:

1. Updates version in `plugin.json`, `marketplace.json`, and `package.json`
2. Commits the version bump (`Release vX.Y.Z`) on the current branch
3. Creates git tag `vX.Y.Z`
4. Pushes `HEAD` to `origin/main` and pushes the tag

GitHub Actions detects the new `v*` tag and automatically:

5. Builds `train-my-brain.zip`
6. Creates a GitHub Release with the zip attached and auto-generated release notes

## Example

```bash
npm run release -- 0.2.0
```

## Troubleshooting

- **"Working tree is dirty"** — commit or stash your changes first
- **"Tag already exists"** — that version has already been released; pick a new one
- **Invalid version** — must be `X.Y.Z` format (e.g. `0.2.0`, `1.0.0`)
- **"Updates were rejected because a pushed branch tip is behind its remote"** — rebase onto `origin/main` before releasing
