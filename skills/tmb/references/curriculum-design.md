# Curriculum Design Principles

These principles come from building real learning curricula. They are requirements,
not suggestions.

---

## Non-negotiable rules

### 1. Never make anything up

Every named concept, every claimed behavior, every mechanism must come from a real,
linkable source. If you're not certain something is accurate, say so and flag it for
the user to verify.

A curriculum with wrong information destroys trust faster than one with honest gaps.
A skeleton with clearly marked TODOs is better than confident hallucination.

### 2. References are mandatory, not nice-to-have

Every module's reading list must have:
- At least one primary source (official documentation, original paper, specification)
- At least one secondary source (tutorial, case study, blog post) with a specific URL
- Guidance on what to read: "read the Architecture section" not "see the official docs"

Vague pointers like "check the documentation" are not acceptable. If you don't have
a specific URL, write `[TODO: find URL]` explicitly rather than leaving a vague pointer.

### 3. Explain every term before using it

See Rule 1 in SKILL.md. This applies to every piece of written content in the
curriculum: module READMEs, VALIDATION.md files, exercise comments, AGENTS.md.

The rule: if someone new to this topic would have to look up a word to understand
a sentence, that sentence needs to explain the word first.

Do this once per term per module. After the first explanation, you can use the term
freely within that module. Don't re-explain across modules, but a brief reminder is
welcome if the term hasn't appeared in a while.

**What counts as a term that needs explaining:**
- Any acronym on first use, with the expansion and a plain-language gloss
- Any specialized noun — don't use it as though the reader already knows it
- Any verb used in a technical sense that differs from everyday meaning
- Any named pattern, method, or framework — explain what it *is* before naming it

**What doesn't need explaining:**
- Common general terms (file, document, measurement, formula)
- Terms the user confirmed familiarity with in the elicitation interview
- Terms already defined earlier in the same document

### 4. Maintain the glossary

See Rule 4 in SKILL.md. Every new term added to any module must also be added to
`glossary.md` at the repo root. The inline explanation (Rule 3) and the glossary
entry are both required — they serve different purposes. The inline explanation
helps the reader in the moment. The glossary lets someone look up a term later
without hunting through every module.

Add entries as you build, not in a batch at the end.

If the Hugo site is being built, the glossary also gets a page at
`content/glossary/index.md`. See `references/hugo-site.md` for the layout.

### 5. No AI-sounding prose

See Rule 2 in SKILL.md. Apply the prose check from SKILL.md to every piece of
writing. The short version: write like someone who has worked in this field and
knows what they're talking about is explaining it to a smart friend, not like a
product brochure or a textbook introduction.

### 6. No jargon as insider signaling

See Rule 3 in SKILL.md. Technical vocabulary is for precision, not credibility.
If a simpler word is equally accurate, use it.

---

## Real-world anchoring

Every concept must be connected to something the learner has already touched or can
immediately touch. Use the project or example they brought to the conversation as the
anchor throughout the curriculum.

**Pattern:** "In [your existing project or the running example], this problem shows up
as [specific thing]. [Concept] solves it by [mechanism]. Here's what that looks like."

Never introduce a concept in isolation. Always answer: where does this problem actually
show up in real work?

If the learner doesn't have an existing project, create a small, concrete running example
at the start of the curriculum and use it throughout every module. Keep it consistent —
switching examples between modules destroys the "these pieces connect" effect.

---

## Contrast is how understanding deepens

Every concept must be compared to its alternative:
- What does the alternative do instead?
- When would you choose the alternative?
- What's the honest cost of each choice?

The learner will encounter "why not X?" questions in interviews, presentations, and
peer conversations. Being able to answer fluently — including making an honest case
for the other side — is what separates credible knowledge from surface familiarity.

**Every module README must have a contrast section.** Not optional.

The contrast must be honest. If the alternative is genuinely better at something,
say so. A comparison where one option wins on every dimension is unconvincing and wrong.

---

## Exercises must be active

An exercise where the learner reads something and runs it unchanged is not an exercise.
It is a demonstration with extra steps.

Every exercise must have TODO markers at the learning points. The learner fills in
the logic, not the boilerplate. The boilerplate reduces setup friction; it doesn't do
the thinking.

See SKILL.md Phase 3 for the full exercise pattern, including the language-agnostic
approach (exercises are not automatically Python — use whatever format is simplest for
a newcomer to this specific topic).

---

## Build step by step — each module extends the last

The curriculum needs a spine: one project, one dataset, one running example that grows
across every module. Benefits:
- The learner sees how pieces connect in a real system, not in isolation
- Each module's exercise builds on the previous module's output
- The final state of the project is a demonstration of everything learned

If you can't thread a single project through all modules, design two or three examples
that each span a cluster of related modules. Don't let modules be completely disconnected.

---

## The expert/practitioner perspective

The learner needs to eventually be able to say:

> "I've worked through this. Here's what I found. Here's when I'd use this approach
> over the alternative. Here's where it gets complicated in practice."

That is different from "I've read about this." Exercises must produce real experience.
Blog post angles should be framed as trade-offs or findings, not as summaries.

---

## Module design patterns

### The question-first README

Every README opens with the question the module answers — not what the module teaches,
but the real problem it solves.

Good: "You understand that silica content affects how viscous lava is. But why does
more silica make an eruption explosive rather than just slower? What's actually happening
at the molecular level?"

Bad: "In this module, you will learn about silica polymerization in magmas."

The question creates a reason to keep reading. It makes the module's scope explicit.
If a concept doesn't help answer the question, it doesn't belong in this module.

### The tiered knowledge model

Mark every concept in AGENTS.md with one of these three labels:

- **Must know cold** — can explain with a concrete example, no hesitation, in under 90 seconds
- **Know the shape** — can give a one-sentence accurate description, knows where to look
- **Aware of** — knows it exists and roughly what it does

This keeps validation honest and prevents scope creep.

### Module sequencing

Order modules by dependency and payoff:

1. Start with "why does this exist?" — motivation before mechanism
2. Build the foundation everything else depends on
3. Show the application or technique that uses the foundation
4. Cover edge cases, exceptions, and operational realities
5. End with the bigger picture — how this connects to adjacent fields, or where the
   field is going

Don't sequence by how a textbook or course organizes the material. Sequence by how
a person actually builds understanding.

### The honest comparison table

Every module README with a contrast section should include a comparison table.
The table must have at least one row where the alternative wins. If you can't find
anything the alternative is better at, you haven't looked hard enough.

---

## Common design mistakes

**Depth without honesty about the alternative.** Knowing one approach deeply but not
being able to explain the alternative's actual strengths is a liability. Teach the
alternatives seriously.

**Exercises that fight the environment.** If setup takes 45 minutes before any
learning happens, setup becomes the lesson. Design for minimum friction to first insight.

**Validation that tests recall, not understanding.** "Name the three types of volcanic
rock" is a recall question. "A geologist describes a deposit as 'poorly sorted, angular
clasts in a fine matrix' — what kind of eruption produced it and why?" is an
understanding question. Design validation for the second type.

**Over-scoping to impress.** A curriculum that covers 15 topics adequately is less
useful than one that covers 7 topics well. When in doubt, cut a module and note what
was left out and why.

**Telling the learner what they're going to learn.** Show them the problem their
current knowledge can't solve, then solve it in the module.

**Forgetting the glossary.** Every time you introduce a term inline, check that it's
also in `glossary.md`. Do this as you build, not at the end — terms pile up fast.
