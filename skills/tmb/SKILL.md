---
name: tmb
description: >
  "Train My Brain" — builds a structured, hands-on learning curriculum with a GitHub
  repo and optional Hugo site. Use this skill whenever a user says /tmb, "train my brain",
  "build a learning plan for", "create a curriculum for", "build a study plan for",
  "help me learn X for a job", "I want to get credible in", or "I need to learn X to
  achieve Y". Always use this skill even if the domain seems simple — the elicitation
  and structure are what make the output good. Do NOT skip the interview phase.
---

# TMB: Train My Brain

Builds a structured, practical learning curriculum as a folder on the user's computer,
with real exercises, mandatory references, oral validation, and a Hugo website.
The goal is always **demonstrable knowledge** — not academic familiarity.

## Workflow overview

1. **Prerequisites check** — confirm Hugo is installed before anything else
2. **Elicit** — 7-step interview (see `references/elicitation.md`)
3. **Location** — ask where to save the folder
4. **Design** — apply curriculum principles (see `references/curriculum-design.md`)
5. **Build** — use the three-tier approach below, reporting progress at every step
6. **Deliver** — zip the folder, present for download, give launch instructions

Read each reference file before the phase it covers. Do not skip elicitation.

---

## Step 0: Prerequisites check (before the interview)

Hugo is required. Check before asking any questions:

> "Before we start, there's one tool you'll need: Hugo. It's free and takes about
> 2 minutes to install. Type `hugo version` in your terminal — if you see a version
> number, we're ready. If not, I'll walk you through installing it."

If they don't have Hugo, give them the install instructions from `references/hugo-site.md`.
Do not proceed until Hugo is confirmed.

---

## Four standing rules (apply at every phase)

### Rule 1: No unexplained terms
Every specialized term must be explained in plain language before it's used.
The explanation comes before the term, not after. Apply to all prose.

**Wrong:** "Stratovolcanoes produce pyroclastic flows during a Plinian eruption."

**Right:** "A stratovolcano — the tall, cone-shaped kind like Mount Fuji — behaves
very differently from a flat shield volcano. During a Plinian eruption (named after
Pliny the Younger, who described Vesuvius in 79 AD), the column can reach the
stratosphere. If it collapses, it sends a pyroclastic flow — a fast-moving avalanche
of superheated gas and debris — down the mountainside."

### Rule 2: No AI-sounding prose
Check every substantial passage against this list and rewrite any match:
- Throat-clearing openers: "In this module, we will explore...", "Let's dive into..."
- Fake enthusiasm: "exciting", "powerful", "game-changing", "seamlessly"
- Vague value claims: "This will help you better understand...", "This is crucial for..."
- Consulting-speak: "paradigm shift", "best-in-class", "synergy", "holistic approach"

Test: would someone who actually works in this field roll their eyes? If yes, rewrite.

### Rule 3: No jargon as insider signaling
If a simpler word is equally accurate, use it. Technical terms are for precision,
not credibility. Always explain them the first time (Rule 1).

### Rule 4: Maintain the glossary
Every new term goes in `glossary.md` at the repo root — in addition to the
inline explanation, not instead of it. Add entries as you build; never batch them
at the end.

---

## Phase 1: Elicitation

Read `references/elicitation.md` now. Run the 7-step interview.

**Critical:** After the user answers each question, reflect back and STOP.
End the message there. Wait for genuine confirmation before asking the next question.
"Does that sound right?" at the end of a message that immediately asks the next
question is not a genuine confirmation — it's performative.

Pattern per step:
1. Ask the question (use `ask_user_input` tool for multiple choice)
2. User answers
3. Reflect back what their answer *means* for the curriculum — STOP
4. Wait for "yes" or a correction
5. Only then ask the next question

Do not proceed to Phase 2 until all 7 steps are confirmed.

---

## Phase 1.5: Location

After the interview summary is confirmed, ask:

> "One last thing — where on your computer would you like to save this?
> I'll create a folder there."

- Say "folder" not "repository", "repo", or "directory"
- Don't mention git unless they bring it up
- Default if unspecified: `~/Documents/learning/<topic-slug>/`
- Confirm back with the exact path before building

---

## Phase 2: Curriculum design

Read `references/curriculum-design.md` now.

Non-negotiables: real-world anchoring, specific reference URLs, contrast in every
module, TODO markers in exercises, AGENTS.md, VALIDATION.md per module, glossary.md.

### Folder structure

```
<topic>/
├── AGENTS.md
├── README.md
├── glossary.md
├── HOW-TO-VIEW-SITE.md
├── .gitignore
└── modules/
    └── NN-<topic-slug>/
        ├── README.md
        ├── VALIDATION.md
        └── exercises/
            └── <exercise>.md
```

Plus `site/` created by Hugo (layouts, content, CSS — see Phase 3).

---

## Phase 3: Build — three tiers, environment-aware

### Tier 1: Scaffolding (deterministic)

**Detect environment first:**

**Claude Code / Claude Work** — `bash_tool` runs on the user's machine:
- Test: `bash_tool ls ~/projects` succeeds (user's home directory is visible)
- Action: Use `bash_tool` for all scaffolding — `mkdir -p` all dirs, run
  `hugo new site site/ --format yaml`, write layouts/CSS via heredocs
- One bash call creates the entire directory tree
- Run `hugo new content/modules/NN-slug/index.md --kind modules` for each module

**Claude.ai chat (this environment)** — `bash_tool` runs on Claude's remote machine:
- Test: `bash_tool ls ~/projects` fails or shows Claude's container, not user's machine
- Action: Build everything on Claude's computer using `bash_tool`, then zip and deliver
- `mkdir -p` works freely on Claude's computer with full nested paths
- Package with `zip -r <topic>.zip <topic>/`
- Copy to `/mnt/user-data/outputs/<topic>.zip`
- Present with `present_files`
- Tell user: `unzip ai-tpm.zip -d ~/projects/` then `cd ~/projects/ai-tpm/site && hugo server -D`

**Why zip, not tar:** Zip is universally supported on macOS, Windows, and Linux
without additional tools. `unzip` is available by default on all platforms.
tar.gz requires additional steps on Windows.

### Tier 2: Hugo commands (inside scaffolding)

In Claude Code/Work environments, use `hugo new content/modules/NN-slug/index.md --kind modules`
to scaffold pages with correct frontmatter from archetypes.

In Claude.ai chat, write the frontmatter directly — don't rely on Hugo commands
since Hugo isn't installed on Claude's remote machine.

### Tier 3: LLM content (unique per curriculum)

All files that require actual thinking: AGENTS.md, README.md, glossary.md,
HOW-TO-VIEW-SITE.md, all module READMEs, VALIDATIONs, and exercises.

Write these using `bash_tool` heredocs on Claude's computer (no file count limit)
or directly via Filesystem tools if in Claude Code/Work.

---

## Progress reporting (required throughout Phase 3)

Content generation takes time. Report progress before and after every step:

```
Building your curriculum — 7 modules, this will take a few minutes.

[1/4] Creating folder structure and website...
✓  Folder structure created
✓  Hugo site scaffolded
✓  HOW-TO-VIEW-SITE.md written

[2/4] Writing shared files...
✓  AGENTS.md
✓  README.md
✓  glossary.md (N terms)

[3/4] Writing 7 modules...
  Module 1 of 7: [Title]...
✓  Module 1 of 7: [Title] — concepts, exercise, validation done

  Module 2 of 7: [Title]...
✓  Module 2 of 7: [Title] done
  [continue for each]

[4/4] Packaging and delivering...
✓  Packaged as ai-tpm.zip (N files)
```

Announce each module before writing it. Confirm after. Never go silent for
more than a few seconds.

---

## Phase 4: Deliver

Always end with the user seeing their site.

**Claude.ai chat:**
Present the zip file with `present_files`. Then say:

> **Your curriculum is ready.** Here's how to get started:
>
> 1. Remove the partial folder if one exists:
>    `rm -rf ~/projects/ai-tpm`
> 2. Extract the zip:
>    `unzip ai-tpm.zip -d ~/projects/`
> 3. Start the site:
>    `cd ~/projects/ai-tpm/site && hugo server -D`
> 4. Open: **http://localhost:1313**
>
> Full instructions are in `HOW-TO-VIEW-SITE.md`.

**Claude Code / Claude Work:**
The site is already on disk. Run `hugo server -D` automatically or instruct
the user to run it. The site should be visible before the conversation ends.

---

## Quality gates

- [ ] Hugo confirmed installed
- [ ] All 7 interview steps confirmed (genuine pause after each, not performative)
- [ ] Folder location confirmed
- [ ] Progress reported before and after each module
- [ ] Every new term explained before first use
- [ ] Every new term in `glossary.md`
- [ ] No AI-sounding prose
- [ ] Every module has a real reference URL
- [ ] Every exercise has TODO markers and a verification step
- [ ] Every VALIDATION.md has a scenario with "good answer covers"
- [ ] AGENTS.md has Rules 1–4
- [ ] HOW-TO-VIEW-SITE.md written in plain language
- [ ] User has the site URL (http://localhost:1313) before conversation ends

---

## Reference files

| File | Read when |
|---|---|
| `references/elicitation.md` | Phase 1 — before asking anything |
| `references/curriculum-design.md` | Phase 2 — before designing modules |
| `references/hugo-site.md` | Step 0 (Hugo install) + Phase 4 (launch) |
| `references/markdown-gotchas.md` | When writing any Hugo markdown content |
