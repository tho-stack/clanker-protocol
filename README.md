# clanker-protocol

**One lead. Three clankers. Plan first, receipts always.**

An orchestration kit for [Claude Code](https://claude.com/claude-code): a mission-briefing skill (`/fablegoal`), two model-pinned subagents, and an OpenAI-Codex peer lane — so your session stops grinding through everything itself and starts running missions: interview → brief → plan gate → delegated execution → evidence-backed debrief.

## The roster

| Callsign | What it is | Sends |
|---|---|---|
| **The Lead** | your Claude Code session | decompose, dispatch, integrate, verify, talk to you |
| **deep-clanker** 🧠 | subagent pinned to Opus | architecture, complex debugging, algorithm design, tradeoffs |
| **cheap-clanker** 🔩 | subagent pinned to Sonnet | boilerplate, tests, formatting, simple edits, bulk mechanical work |
| **design-clanker** 🎨 | subagent pinned to the top-tier model, dispatched at max effort | code-based design & wow-craft: hero animations, 3D models, hand-built SVGs, textures, shaders, motion |
| **Codex** 🎭 | OpenAI Codex CLI in tmux | a cracked peer with a different perspective — design consults, second opinions, adversarial review, `$imagegen` for generated imagery |

## How a mission runs

```
you:    /fablegoal make the landing page load in under 1 second

claude: Recon's done, Commander. OPERATION SUBSECOND SAILFISH — four questions, then the plan.
        [The Prize] [The Terrain] [Tripwires] [Victory]      ← structured interview, real options

claude: 📜 MISSION BRIEF …
        | Task | Clanker | Why |                              ← delegation table
        🚀 Send it / 🔧 Adjust / 🧯 Stand down                 ← nothing dispatches before 🚀

you:    🚀

claude: (taskbar ticks task by task · every dispatch/return logged
         to fablegoal-progress-subsecond-sailfish.md)

claude: 🎖️ MISSION DEBRIEF — Shipped / Evidence / Casualties / Loose ends
```

Every mission leaves a **flight recorder** (`fablegoal-progress-<codename>.md`): timestamped dispatches, returns, gate decisions, verification evidence. Crash mid-mission? The next `/fablegoal` offers to resume from it.

## Install

```bash
git clone https://github.com/tho-stack/clanker-protocol && cd clanker-protocol
./install.sh          # copies skills + agents into ~/.claude (skips existing; -f overwrites)
```

Then paste the orchestration rules from [`CLAUDE-SNIPPET.md`](CLAUDE-SNIPPET.md) into your global `~/.claude/CLAUDE.md` (or a project `CLAUDE.md`).

Manual install: copy `skills/*` → `~/.claude/skills/`, `agents/*` → `~/.claude/agents/`.

## Requirements

- Claude Code with skills + custom subagents (any recent version)
- Optional, for the Codex lane: `tmux` + the [OpenAI Codex CLI](https://github.com/openai/codex) (`codex login`). Without it the roster degrades gracefully to the two clankers.

## What's in the box

| Path | What |
|---|---|
| `skills/fablegoal/` | the mission-briefing orchestration skill: Iron-Rule interview, brief, plan gate, taskbar + flight recorder, debrief |
| `skills/codex-tmux/` | drive a live, monitorable, **rescuable** Codex session in tmux — goals, reviews, research, second opinions, status bar |
| `skills/codex-adversarial-review/` | one-shot adversarial Codex review of a scoped diff (gpt-5.5 / xhigh, read-only) |
| `agents/deep-clanker.md` | Opus-pinned reasoning specialist — investigates deeply, returns a decision-ready conclusion |
| `agents/cheap-clanker.md` | Sonnet-pinned mechanical executor — exact scope, self-verifies, terse evidence |
| `agents/design-clanker.md` | top-tier-pinned design-craft specialist — the wow lane, reduced-motion/a11y floor built in |
| `CLAUDE-SNIPPET.md` | the always-on routing/protocol rules for your CLAUDE.md |

## Design notes

- **Interview before plan.** The skill's Iron Rule: arguments seed the briefing, they never replace it — backed by a rationalization table that keeps the model honest under "the goal is obviously clear" pressure.
- **TDD'd documentation.** Built the [superpowers writing-skills](https://github.com/obra/superpowers) way: baseline (no-skill) agent simulations first to capture real failure modes — baseline agents self-scoped constraints, never rendered the brief, and guessed the wrong model for grunt work — then the skill was written against those failures and re-simulated until every checkpoint flipped.
- **Evidence or it didn't happen.** No success claims without running the verification; debriefs carry *Casualties* and *Loose ends* sections on purpose.
- **Peer, not reviewer.** Codex gets consulted at design time and on high-stakes calls (in parallel with deep-clanker, double-blind), not just handed diffs at the end.

## License

MIT
