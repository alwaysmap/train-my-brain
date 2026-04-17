# Elicitation: Interview Guide

## How to run the interview

The interview has exactly **7 steps**. Before asking step 1, tell the user this:

> "Before I build anything, I want to make sure I understand what you're actually
> trying to do. I'll ask you 7 short questions — it'll take about 5 minutes.
> I'll check my understanding after each one before moving on."

Then for every step — **two exchanges, not one:**

**Exchange A — the question:**
1. Show the step number and total: **"Step N of 7"**
2. Ask the question (use `ask_user_input` for multiple choice)
3. Wait for the answer

**Exchange B — the reflection (a separate message, nothing else in it):**
4. Reflect back what you heard in your own words — not a paraphrase, but a
   restatement of what it *means* for the curriculum
5. End the message there. Do NOT ask the next question in the same message.
6. Wait for genuine confirmation: "yes", "exactly", "that's right", or a correction
7. Only after confirmation, move to the next step

**Why this matters:** Asking "Does that sound right?" and then immediately asking
Step N+1 in the same message is performative. The user can't actually correct you
without interrupting a question that's already been asked. The reflection must be
a real pause — two separate exchanges per step, every time.

If their answer is vague, say what you'd assume and ask if that's right rather than
asking them to clarify in the abstract. "I'd treat that as [interpretation] — is that
about right?" is better than "Could you be more specific?"

Use the `ask_user_input` tool for multiple-choice questions. Keep the tone conversational —
this should feel like a good first meeting with a mentor, not a form.

---

## Step 1 of 7: The real goal

**Ask:**
> "When you're done with this, how will you know it worked? What's the thing you'll be
> able to do — or the conversation you'll be able to have — that you can't have today?"

**Reflect back examples:**

- Answer: "Get a job at a company working in this field" →
  Reflect: "So the measure of success is getting through a hiring process — which means
  being able to answer technical questions confidently, discuss trade-offs with experts,
  and talk about real problems from experience, not just reading. Does that sound right?"
  [STOP — wait for confirmation before Step 2]

- Answer: "Be able to advise clients on this" →
  Reflect: "So you need to be credible enough in a customer conversation to give
  recommendations people will trust — not just recite what the textbook says, but have
  an informed view on when each approach makes sense and when it doesn't. Is that the mark?"
  [STOP — wait for confirmation before Step 2]

- Answer: "I just want to understand this better" →
  Reflect: "That's honest, but it makes it hard to know when we're done. If you had
  to pick one situation where you'd use this knowledge, what would it be? I'll treat
  that as the anchor."
  [STOP — wait for confirmation before Step 2]

- Answer: "I want to learn about the chemical reactions in volcanoes" →
  Reflect: "So you want to understand what's actually happening chemically — why
  different lavas behave differently, what drives an explosive eruption vs. a slow
  lava flow, how gases interact with the magma. Is the goal to understand it deeply
  for yourself, or is there something specific you want to do with that understanding?"
  [STOP — wait for confirmation before Step 2]

**Interpret for curriculum design:**

- Job/career goal → Breadth for context, depth for credibility. Validation = interview practice.
- Advisory/consulting goal → Trade-off articulation is primary. Know the weaknesses.
- Build a specific thing → Narrow sharply. Depth over breadth. Validation = working output.
- Certification → Map to exam objectives. Validation = practice questions per domain.
- Pure curiosity → Depth over breadth. Validation = can explain it without notes.

---

## Step 2 of 7: How they'll be tested

**Ask (use ask_user_input, multi-select):**
> "How do you expect to actually be tested on this? Pick everything that applies."

Options:
- Job interview (technical questions, whiteboard problems)
- Customer or stakeholder conversation
- Code review or pair programming session
- Certification exam
- Writing (blog posts, documentation, proposals)
- No external test — I just want to feel confident

**Reflect back examples:**

- "Interview + customer conversation" →
  Reflect: "So you need to answer technical questions under pressure *and* explain
  things clearly to people who aren't deep in the weeds. I'll make sure each module
  has both a 'explain the mechanism' question and a 'explain this to a non-technical
  stakeholder' version."
  [STOP — wait for confirmation before Step 3]

- "Just want to feel confident" →
  Reflect: "No external test, but you want the knowledge to actually stick. I'll keep
  the hands-on exercises central and add reflection questions so you're processing
  what you learned rather than just running through it."
  [STOP — wait for confirmation before Step 3]

**Interpret for curriculum design:**

- Interview → Every VALIDATION.md needs a practiced answer with "good answer covers."
- Customer conversation → Exercises include "explain this without jargon" moments.
- Code review → Every exercise produces runnable output. Validation includes "walk me through this."
- Certification → Add practice questions mapped to exam objectives.
- Writing → "What to write on your blog" section required in every README.
- Just confidence → Reduce oral weight, increase hands-on and reflection weight.

---

## Step 3 of 7: Starting point

**Ask:**
> "How would you honestly describe your current knowledge of [topic]? No judgment —
> it just helps me figure out where to start."

**Reflect back examples:**

- "I've touched it a bit but don't really understand it" →
  Reflect: "So you've had some exposure but you're filling gaps in the 'why does this
  work this way' understanding. I'll start from foundations without spending time on
  things obvious from your existing experience."
  [STOP — wait for confirmation before Step 4]

- "I know a related field well but not this specific one" →
  Reflect: "That's a great starting point — understanding the contrast is half the
  curriculum. I'll lean heavily on 'here's how this differs from what you know.'"
  [STOP — wait for confirmation before Step 4]

- "Completely new to this whole area" →
  Reflect: "Starting from scratch. The first module or two will feel slower, but
  they're load-bearing — everything else builds on them."
  [STOP — wait for confirmation before Step 4]

**Interpret for curriculum design:**

- Existing exposure → Start with "why isn't what you already know enough for this?"
- Knows something adjacent → Lead with contrasts, use prior knowledge as the anchor.
- Complete beginner → First principles. Do not assume any domain vocabulary.

---

## Step 4 of 7: Depth vs. breadth

**Ask (use ask_user_input, single-select):**
> "For this goal, is it more important to know a lot of things at a surface level,
> or to know fewer things really well?"

Options:
- **Wide map** — I want to understand the whole landscape, know what exists and roughly why
- **Deep dives** — I want to master specific things well enough to build with them or defend them
- **Somewhere in the middle** — Broad enough to have a conversation, deep enough not to get caught out

**Reflect back — then STOP:**

- Wide map → "The priority is navigating the full picture — understanding what all
  the pieces are and how they relate — rather than being an expert on any one of them."
  [STOP]

- Deep dives → "You'd rather have real working knowledge of a smaller set of things.
  Fewer modules, each one going further."
  [STOP]

- Middle → "Broad enough to hold a conversation without getting caught out, but not
  so surface-level you can't go a layer deeper when someone pushes. I'll flag
  'must know cold' vs 'know the shape of' throughout."
  [STOP]

**Interpret:** Mark every concept in AGENTS.md as `must-know-cold`, `know-the-shape`,
or `aware-of`. Calibrate the ratio based on this answer.

---

## Step 5 of 7: Validation preference

**Ask (use ask_user_input, multi-select):**
> "When you finish a module, how do you want to check that it actually stuck?"

Options:
- Answer questions out loud without looking at notes
- Complete an exercise that produces something real
- Write a short blog post or explanation for someone else
- Walk through a key question or scenario
- All of the above — I want every module to feel solid

**Reflect back — then STOP:**

- "Questions + exercise" → "Bar for 'done': explain it out loud and show real work."
  [STOP]
- "All of the above" → "Full validation suite. Takes more time per module but
  the knowledge sticks better."
  [STOP]

---

## Step 6 of 7: Time and environment

**Ask:**
> "Two quick practical questions: How much time do you realistically have —
> a few weeks or a few months? And what tools do you already have set up?"

**Reflect back — then STOP:**

- "A few weeks, have some tools" → "Tight timeline — I'll cut to highest-leverage
  modules. Exercises start from something real right away."
  [STOP]

- "A few months, starting from scratch" → "Enough time for real depth. First exercise
  will include setup, but explained step by step."
  [STOP]

---

## Step 7 of 7: A fun one

**Ask:**
> "Last one, and it's a bit different — what color makes you happy?
> Just the first one that comes to mind."

Free text. Accept anything. Acknowledge warmly and move on — no deep reflection needed.

> "Good to know — [color]. I'll use that for the site theme."
> [STOP — wait for the user to respond or just continue]

**Color → HSLA hue:**

| Color | Hue (H) |
|---|---|
| red, scarlet, crimson | 0–10 |
| orange, amber, rust | 25–35 |
| yellow, gold, sunshine | 50–65 |
| yellow-green, lime | 80–100 |
| green, forest, emerald | 115–140 |
| mint, seafoam, teal | 150–190 |
| sky, cerulean | 200–210 |
| blue, cobalt, navy | 215–240 |
| indigo, periwinkle | 245–260 |
| purple, violet, lavender | 265–285 |
| magenta, pink, rose | 295–345 |
| neutral (white, grey, black) | use 220 |

Store the hue number. Use it in `site/hugo.yaml` as `params.hue`.

---

## After step 7: summary + folder location

**Summary:**

> "Here's what I'm building:
>
> **Goal:** [one sentence]
> **How you'll be tested:** [from Step 2]
> **Starting point:** [from Step 3]
> **Depth vs. breadth:** [from Step 4]
> **Validation:** [from Step 5]
> **Timeline + tools:** [from Step 6]
> **Site theme:** [color] → hue [N]°
>
> Any corrections?"

Wait for confirmation. Then ask folder location:

> "One last thing — where on your computer would you like to save this?
> I'll create a folder there."

- Say "folder" — not "repository", "repo", or "directory"
- Don't mention git unless the user does
- Default: `~/Documents/learning/<topic-slug>/`
- Confirm back with the exact path before building

---

## Anti-patterns to avoid

**Don't accept vague goals.** Keep asking until something is specific enough to design for.

**Don't over-interview.** 7 steps is the limit. If you can infer something, don't ask.

**Don't design while interviewing.** Finish all 7 steps and the summary before
proposing any module structure.

**Don't ask the next question in the same message as the reflection.** This is the
most important rule in this document. Two exchanges per step. Every time.

**Don't use technical vocabulary for non-technical users.** "Folder" not "repo."
"Website" not "Hugo site." "Save the files" not "commit."
