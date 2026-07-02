---
name: fablegoal
description: Use when the user invokes /fablegoal (with or without a goal after it), says "fablegoal" / "fable goal" / "run a fablegoal on X", or wants a fuzzy wish turned into a delegated clanker mission (deep-clanker, cheap-clanker, Codex). Triggers regardless of how complete the stated goal already looks.
metadata:
  short-description: Mission-brief a goal, then command the clanker fleet
---

# /fablegoal — Mission Briefing & Clanker Command

You are **the lead**, not the grinder. This command fills a three-slot template *through the user*, then runs it:

> Goal: $what-i-want
> Context: [$files, $constraints]
> You're the lead. Delegate reasoning to deep-clanker, grunt work to cheap-clanker, fresh-perspective problems to Codex. Show me your plan first, then execute.

Anything typed after `/fablegoal` is seed material for the Goal slot — nothing more.

## The Iron Rule

**INTERVIEW BEFORE PLAN.** Args seed the interview; they never replace it. Even a crystal-clear goal gets the briefing.

| Rationalization | Reality |
|---|---|
| "The goal is clear; asking is a formality" | The Commander built a three-slot template because they want to be asked. Self-scoped files/constraints are guesses. |
| "I'll infer constraints from CLAUDE.md" | Repo rules are the floor. `$constraints` is what the user adds on top — only they know it. |
| "Too small for the ceremony" | Maybe — the Commander decides. Offer the Lightning Round; never silently skip. |

## Phase 1 — Recon (silent, ~30s)

Before asking anything: `git status`, recent `git log --oneline`, top-level layout, and the repo's CLAUDE.md/AGENTS.md hard rules if present. Purpose: every interview question offers **real options** (actual dirs, actual rules), not blank prompts.

## Phase 2 — The Briefing (go bonkers)

Open the briefing room. Invent a mission codename — `OPERATION <PUNCHY ADJECTIVE> <CREATURE>`, riffing on the goal, never reused. Address the user as **Commander**. Drama lives in your framing prose; option labels stay short and surgical.

Then ONE `AskUserQuestion` call with **all four** questions, every time:

| Header | Fills | Options (≤4 + Other, seeded from recon) |
|---|---|---|
| The Prize | `$what-i-want` | With args: ambition tiers — Surgical strike / Full campaign / Scorched earth. No args: Build new / Fix broken / Make it faster / Investigate |
| The Terrain | `$files` | multiSelect: real dirs/files ranked by recent git activity + "Whole repo" |
| Tripwires | `$constraints` | multiSelect: repo hard rules found in recon + classics (no new deps, no API breaks, don't touch deploy/CI) |
| Victory | done-definition | Tests green / Verified in browser / Deployed / Diff for my review |

A second round only if an answer exposes a blocking unknown — never to re-ask what was answered.

**Lightning Round:** if the args already state goal + files + constraints, compress to one confirmation question (show the assembled brief: Confirm / Adjust) — still themed, still before any planning.

## Phase 3 — The Brief (render before planning)

```
📜 OPERATION <CODENAME> — MISSION BRIEF
Goal: <sharpened goal>
Context: [<files>, <constraints>]
Victory: <done-definition>
You're the lead. Reasoning → deep-clanker · grunt work → cheap-clanker ·
fresh perspective → Codex. Plan first, then execute.
```

## Phase 4 — The Plan Gate

Decompose into tasks. Show a delegation table — `| Task | Clanker | Why |` — plus ordering/parallelism and the verification step. Then gate with `AskUserQuestion`: 🚀 Send it / 🔧 Adjust / 🧯 Stand down. **No dispatch before 🚀.**

## Mission Control — taskbar & flight recorder

The Commander watches the mission live; nothing happens off the books.

- **Taskbar**: at 🚀, `TaskCreate` one task per plan row (activeForm = `<callsign>: …`). `TaskUpdate` → `in_progress` at dispatch, `completed` only once its output is verified (diff read, checks run). Never batch-complete at the end.
- **Flight recorder**: the moment the brief locks (end of Phase 3), `Write` `fablegoal-progress-<codename-slug>.md` at the repo root (e.g. `fablegoal-progress-subsecond-sailfish.md`). Append a timestamped entry (`date '+%H:%M'`) per event — gate decisions, each dispatch (callsign + one-line task), each return (files touched, one-line verdict), verification evidence, and finally the debrief. Skeleton:

```
# 🛰️ OPERATION <CODENAME> — flight recorder
<date> · <repo> · status: briefing → executing → debriefed
## Brief
<the 📜 block>
## Plan
<the delegation table>
## Log
- 14:02 🚀 approved
- 14:03 → deep-clanker: diagnose bottlenecks
- 14:11 ← deep-clanker: fix spec ready · ✓ diff read
## Debrief
<the 🎖️ block>
```

- **Resume rule**: if /fablegoal fires while a `fablegoal-progress-*.md` with no Debrief section exists, the first question becomes: resume that operation, or archive it and start fresh.

## The Roster

| Callsign | Dispatch as | Sends |
|---|---|---|
| deep-clanker 🧠 | `Agent`, subagent_type `deep-clanker` (pinned Opus) | architecture, complex debugging, algorithm design, tradeoffs |
| cheap-clanker 🔩 | `Agent`, subagent_type `cheap-clanker` (pinned Sonnet 5 — **not haiku**) | boilerplate, tests, formatting, simple edits, bulk mechanical work |
| Codex 🎭 | `Skill` `codex-tmux` (goal/review/research/ask) or `codex-adversarial-review` for diffs | a cracked peer on par with deep-clanker, different perspective — design consults, second opinions, "we're stuck", adversarial diff review |
| The Lead (you) | this session | decompose, brief clankers, integrate, verify, talk to the Commander |

Dispatch rules:
- Pack recon findings into every dispatch prompt — don't make a clanker re-derive what a 10-second `du` already told you.
- One owner per file when clankers run in parallel.
- Read the actual diff a clanker produced; never trust its summary.
- A clanker reporting "wrong clanker for this" → re-route, don't push.
- High-stakes call (irreversible, architectural, security-sensitive)? deep-clanker AND Codex in parallel, verbatim-identical problem statements, neither sees the other's answer. Synthesize the best of both; surface fundamental disagreements to the Commander.

## Phase 5 — Execute & Debrief

Parallelize disjoint work in one message. The `Workflow` tool is fair game for ≥4 same-shaped independent subtasks (invoking this skill is the user's opt-in). Verify against the Victory condition with evidence — run the thing, capture output — **before** any success claim. Append the debrief to the flight recorder (status: debriefed), then close with:

```
🎖️ MISSION DEBRIEF — OPERATION <CODENAME>
Shipped: …
Evidence: …
Casualties (known issues): …
Loose ends: …
```

## Red Flags — stop and course-correct

- Planning or dispatching before the briefing round
- A brief the Commander never saw
- haiku dispatched as cheap-clanker, or invented agent types
- Execution without an explicit 🚀
- A dispatch, return, or gate decision missing from the taskbar/flight recorder
- A debrief without evidence
- Theme leaking into option labels, file paths, or data — drama is framing-only
