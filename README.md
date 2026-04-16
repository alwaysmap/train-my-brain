# Train My Brain

A Claude plugin that builds structured, hands-on learning curricula. It interviews you about your goal, designs a curriculum, and creates a GitHub repo with real exercises, oral validation, and an optional Hugo site.

**Not theoretical.** Every module produces working exercises and tested understanding.

## Quick Start

1. Upload `train-my-brain.zip` through the Cowork plugin settings (Customize → Personal plugins → +)
2. Start a new session and type `/tmb` or describe what you want to learn

## The `/tmb` command

`/tmb` starts a 6-step interview that takes about 5 minutes. It covers:

1. What you're trying to be able to do (not "what you want to learn")
2. How you'll be tested on this knowledge in the real world
3. Where you're starting from
4. Depth vs. breadth trade-off for your goal
5. How you prefer to validate that things stuck
6. Timeline and tools you already have

After the interview, Claude designs the curriculum, then builds a GitHub repo with:

- Module READMEs that open with the problem the module solves (not "in this module you will learn")
- Exercises with `TODO` markers — not passive demos, but active learning
- `VALIDATION.md` per module — oral questions, code challenges, and one interview question to practice
- `AGENTS.md` — instructions for any AI agent helping you work through the curriculum
- An optional Hugo site for publishing the curriculum content

## Commands

| Command | What it does |
|---|---|
| `/tmb` | Start a new curriculum — runs the interview then builds everything |

## Requirements

- Claude Desktop with Cowork mode (Pro or Max subscription)

## About

Built by [Dylan Thomas](https://bitsby.me) · Part of the [alwaysmap](https://github.com/alwaysmap) toolkit
