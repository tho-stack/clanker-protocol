---
name: codex-tmux
description: Drive an interactive OpenAI Codex CLI session inside tmux from this (headless) Claude session — delegate a long-running Codex /goal, run a gpt-5.5/xhigh adversarial review, research a topic, ask Codex for a second opinion, rescue a stuck turn, and surface its live progress as a status bar / todo item. Use to hand work to Codex (content/data/art/balance goals, parallel implementation, independent review, research, consults) while keeping it live-monitorable + rescuable — instead of the opaque one-shot `codex exec` (which has hung 70+ min). Triggers: "set a codex goal", "launch the codex goal", "codex adversarial review", "review/research/ask codex", "rescue the codex session", "what is codex doing", "show codex progress".
metadata:
  short-description: Run + monitor + rescue interactive Codex via tmux
---

# Codex-in-tmux driver

`codex exec` (headless, one-shot) is opaque and has hung for 70+ min with no output. Running the
**interactive** Codex CLI inside a detached **tmux** session instead gives the FULL interactive Codex
(persistent **`/goal`** loop, planning, MCP, `$imagegen`, all skills) while staying **live-monitorable**
(`capture-pane`/`progress`) and **rescuable** (Esc + nudge). Drive it all through the helper:

```
~/.claude/skills/codex-tmux/codex-tmux.sh <subcommand> ...
```

| cmd | purpose |
|---|---|
| `goal <session> <cwd> <goal_file> [sandbox=workspace-write]` | start codex (write) + `set the goal to:` the file → the persistent goal loop (commits to its branch) |
| `review <session> <cwd> <prompt_file>` | adversarial review (read-only); findings land in the **pane** → `harvest` |
| `research <session> <cwd> <prompt_file>` | research a topic (web + files, read-only); answer in the pane → `harvest` |
| `ask <session> <cwd> <question \| @file>` | quick second opinion / help (read-only); answer in the pane |
| `harvest <session> <out_file>` | dump pane scrollback to a file (retrieve a read-only command's answer) |
| `progress <session>` | one-line **status bar** (state · timer · Tasks N/M · token% · current step) |
| `dashboard` | `progress` for ALL codex sessions |
| `status <session>` | `busy` \| `idle` \| `dead` |
| `wait <session> [timeout]` / `waitfile <file>` | block until idle / until a file appears |
| `rescue <session> [nudge…]` | Esc-interrupt a stuck turn; optionally redirect it |
| `start`/`send`/`capture`/`kill`/`list` | primitives |

## Hard-won learnings (do NOT relearn these)

1. **Submit needs a SEPARATE Enter.** `send-keys '<text>' Enter` leaves the text sitting in the TUI input
   box. The driver's `send` does: literal text → pause → a separate `Enter`. (Don't "fix" this.)
2. **Read-only Codex CANNOT write files.** It refuses and says so ("the sandbox blocked writing …; I won't
   print … because that would be false"). So `review`/`research`/`ask` put the answer in the **pane** → use
   `harvest <session> <file>` to retrieve it. Only `goal` (workspace-write) writes/commits.
3. **`set the goal to: …` auto-engages** a goal-ledger skill on the Codex side if one is installed
   (optional) → `/goal` + a `*-progress.md` ledger + the persistent loop; without it, the goal prompt's
   inline ledger instructions still apply.
4. **Goals must be isolated.** Run them in a **git worktree** off `main` with `node_modules` symlinked, so
   Codex's build/tests work and its commits land on a throwaway branch you merge — never on the live tree.
5. **`codex exec` is one-shot**; the tmux interactive loop is the real persistent "boulder never stops" goal.
   Reach for tmux for anything long-running or that needs the goal feature.
6. **Least-privilege sandbox.** `read-only` for review/research/ask; `workspace-write` for goals (writes
   confined to the cwd worktree + temp). Only `danger-full-access` if a goal truly needs sibling-repo reads
   or network — and say why.
7. **The TUI status bar carries the truth:** `… esc to interrupt` / `Working (Xs)` = busy; `… % left` =
   ready/token budget; `Tasks N/M` = the plan. `progress` parses these.
8. **Always independently verify Codex's gates yourself before merging** — a sibling agent once faked a gate;
   evaluate findings as a peer and push back with evidence.
9. **Don't double-drive.** The user may run a goal in their own interactive Codex; one content lane at a time.
10. **Startup "Update available" menu blocks launch.** A new codex build can show a blocking update menu
    (1. Update now / 2. Skip / 3. Skip until next version) BEFORE the ready prompt — it stalls
    `_ready` detection and can swallow the first message (a stray Enter may even pick "Update now").
    `cmd_start` now auto-dismisses it (navigates to "Skip" + Enter, never auto-updates). A long-running
    goal session keeps running on its already-loaded binary even if codex is upgraded mid-flight; only
    NEW launches use the new version.

## Workflow — GOAL (long-running content/data/art/balance)

```bash
S=~/.claude/skills/codex-tmux/codex-tmux.sh
git worktree add ../<repo>-goal-<slug> -b goal/<slug> main
ln -s <repo>/node_modules ../<repo>-goal-<slug>/node_modules   # if the project needs it
cat > /tmp/goal-<slug>.md <<'EOF'
<full /goal text: milestones, isolation rules, definition-of-done>
EOF
"$S" goal codex-goal-<slug> ../<repo>-goal-<slug> /tmp/goal-<slug>.md
```
Then **don't block** — re-check on your wake-ups with `"$S" progress codex-goal-<slug>` and the worktree's
`*-progress.md`. When done: independently verify + merge the branch to main, `"$S" kill …`, `git worktree remove --force`.

## Workflow — REVIEW / RESEARCH / ASK (read-only → harvest)

```bash
"$S" review  codex-rev-<x>  <repo>  /tmp/review-<x>.md     # then, when idle:
"$S" harvest codex-rev-<x>  /tmp/review-out-<x>.md ; cat /tmp/review-out-<x>.md
"$S" research codex-res-<x> <repo>  /tmp/research-<x>.md
"$S" ask     codex-ask-<x>  <repo>  "Is approach A or B better for X, and why?"   # or  @/tmp/q.md
```
For reviews, reuse the project-focus hook from the `codex-adversarial-review` skill. To get notified when one
finishes, launch a `run_in_background` Bash watch: `"$S" wait codex-rev-<x>` (exits when the turn goes idle).

## Workflow — RESCUE a stuck turn

```bash
"$S" progress codex-goal-<slug>          # busy a long time with no plan movement?
"$S" rescue   codex-goal-<slug>          # Esc-interrupt, show the pane
"$S" rescue   codex-goal-<slug> "Stop — you're stuck on X. Do Y instead, then continue the goal."
```
`status` = `dead` → the session ended; restart. Rescue beats a headless hang: you always see what it's doing.

## Showing progress (status bar / todo list)

Three surfaces — use them together:

- **Status bar:** `"$S" progress <session>` → `[s] ▶ working · 4m12s · Tasks 3/7 · 88% left · <current step>`.
  `"$S" dashboard` does this for every codex session at once.
- **Claude todo list (recommended for long goals):** when you launch a goal/review, also `TaskCreate` a
  task like "Codex goal: <name> (tmux <session>)"; on each wake-up run `progress <session>` and `TaskUpdate`
  that task's `activeForm`/description with the status bar line. Codex then shows up in the same todo list as
  your own work. Mark it completed when the goal's ledger/gates are done and you've merged.
- **Live watch (for the user):** `tmux attach -t <session>` shows Codex working in real time (Ctrl-b d to
  detach). Mention this when the user wants to watch directly.
