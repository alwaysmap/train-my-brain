---
name: tmb-review
description: >
  Use this skill when the user asks to re-check, re-review, or validate an
  existing TMB curriculum, or to apply previously-approved review flags.
  Triggers on "/tmb:tmb-review", "re-review this curriculum", "check for drift",
  "validate the curriculum", "apply the approved review fixes". Operates on the
  current working directory; requires curriculum_spine.md and briefs/ to exist.
user_summary: >
  Re-check a curriculum for drift — adjacency, frontmatter, URL reachability,
  glossary conflicts, AI-prose patterns. Substantive flags wait in review.md
  for your approval before being applied.
version: 0.4.0
argument-hint: "<no arguments — operates on cwd>"
allowed-tools: [Read, Write, Bash, Agent]
---

# /tmb:tmb-review

Run the TMB consistency reviewer against the current directory. Delegate to the `tmb-reviewer` agent.

## Files

| File | Loaded when |
|------|-------------|
| `SKILL.md` (this file) | Always |
| `references/reviewer-policy.md` | When triaging flags or explaining categories to the user |

## Phase 0: Preflight

```bash
bash scripts/check-deps.sh
```

Stop on non-zero. Then:

```bash
bash scripts/detect-curriculum.sh "$(pwd)"
```

Branch on the JSON `state`:

- `v0.4-complete` or `v0.4-partial` — proceed.
- `v0.3-*` — refuse: *"This is a v0.3 curriculum. v0.4 introduces research.yaml and new determinism scripts. There is no automatic upgrade — see CHANGELOG.md."*
- `v0.2` — refuse with the same v0.2-not-supported message v0.3 used.
- `non-tmb` or `fresh` — refuse: *"This directory does not look like a TMB curriculum (state: <X>). Run /tmb:tmb-create to start one."*

## Phase 1: Mode selection

If `review.md` already exists and contains any flag with `approved: true` that has not been `applied: true`, ask:

*"Found existing review.md with N approved flags waiting to be applied. Apply them now, or run a fresh full review? [apply/fresh]"*

- `apply` → dispatch with `mode: "apply-approved"`.
- `fresh` → dispatch with `mode: "full"`.
- Default if no review.md exists: `mode: "full"`.

## Phase 2: Dispatch

```
Agent(
  subagent_type: "tmb-reviewer",
  prompt: <JSON with curriculum_root=cwd, mode>
)
```

The agent runs the determinism scripts, applies mechanical fixes, merges the glossary, and writes `review.md`. You do not duplicate any of that logic.

## Phase 3: Summarize

Read `review.md` and summarize:

- Mechanical fixes applied (count + one-line list).
- Substantive flags open (count + categories).
- If flags exist: tell the user how to approve them — open `review.md`, set `approved: true` on flags they want applied, then re-run `/tmb:tmb-review`.
- If `mode == apply-approved`: report which flags auto-applied and which require manual editing.

Do not print the entire `review.md`. The file is the artifact; the message is the signal.

## Boundaries

- No interview.
- No scaffold.
- No build.
- No serve.
- No web research.
- Only dispatches the reviewer and reports the result.

If the user wants a post-review build refresh, point them at `/tmb:tmb-rebuild-site` (or `./build.sh` from the curriculum root).
