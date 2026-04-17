---
name: review
description: Re-runs the TMB consistency reviewer against an existing curriculum. Auto-fixes mechanical issues and flags substantive ones in review.md. Use after manual edits, after adding a module, or whenever you want a consistency pass. Requires curriculum_spine.md and briefs/ to exist at the cwd.
when_to_use: >
  The user asks to re-check an existing TMB curriculum, review it for drift, validate adjacency,
  check reading-list URLs, or apply previously-approved substantive fixes.
  Trigger phrases: "/tmb:review", "re-review this curriculum", "check for drift", "validate the
  curriculum", "apply the approved review fixes".
argument-hint: <no arguments — operates on cwd>
allowed-tools: [Read, Write, Bash, Agent]
---

# /tmb:review

Run the TMB consistency reviewer against the current directory. Delegate to the `tmb-reviewer` agent.

## Preconditions

Before dispatching, verify the cwd looks like a v0.3 TMB curriculum:

```bash
[ -f curriculum_spine.md ] && [ -d briefs ] && [ -d site/content/modules ]
```

If any path is missing, stop and print:

```
/tmb:review: this directory does not look like a TMB v0.3 curriculum.

Missing:
  <list missing paths>

If this is a v0.2 curriculum (modules/NN-slug/README.md as canonical content),
there is no automatic migration — see CHANGELOG.md v0.3 notes. If you want to
create a fresh curriculum here, run /tmb:create.
```

Do NOT dispatch the reviewer against a non-curriculum directory.

## Mode selection

If `review.md` already exists and contains any flag with `approved: true` that has not been `applied: true`, ask the user:

*"Found existing review.md with N approved flags waiting to be applied. Apply them now, or run a fresh full review? [apply/fresh]"*

- On `apply`: dispatch with `mode: "apply-approved"`.
- On `fresh`: dispatch with `mode: "full"`.
- Default if no review.md exists: `mode: "full"`.

## Dispatch

```
Agent(
  subagent_type: "tmb-reviewer",
  prompt: <JSON with curriculum_root (= cwd), mode>
)
```

## After the agent returns

Read `review.md` and summarize to the user:

- Mechanical fixes applied (count + one-line list).
- Substantive flags open (count + categories).
- If there are substantive flags: tell the user how to approve them: open `review.md`, set `approved: true` on the flags they want applied, then re-run `/tmb:review`.
- If mode was `apply-approved`: tell the user which approved flags could be auto-applied and which require manual editing (e.g., prose rewrites).

Do not print the entire `review.md` back — just the summary. The file is the artifact; the message is the signal.

## Boundaries

- No interview.
- No scaffold.
- No build.
- No serve.
- Only dispatches the reviewer and reports the result.

If the user wants a post-review build refresh, direct them to `/tmb:rebuild-site` (or `./build.sh` from the curriculum root).
