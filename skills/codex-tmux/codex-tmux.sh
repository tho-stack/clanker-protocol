#!/usr/bin/env bash
# codex-tmux.sh — drive an interactive Codex CLI session inside tmux from a headless agent.
# Gives the FULL interactive Codex (the /goal persistent loop, planning, MCP, image-gen, skills)
# while staying live-monitorable (capture-pane) and rescuable — unlike one-shot `codex exec`,
# which is opaque and has been observed to hang.
#
# Subcommands:
#   start   <session> <cwd> [sandbox=read-only] [model=gpt-5.5] [effort=xhigh]
#   send    <session> <text...>            # type one line + submit (separate Enter — the TUI nuance)
#   goal    <session> <cwd> <goal_file> [sandbox=workspace-write]   # set + run a long Codex /goal
#   review  <session> <cwd> <prompt_file> <out_file>                # run an adversarial review (read-only)
#   capture <session> [lines=60]           # snapshot the pane (monitor)
#   status  <session>                      # -> busy | idle | dead
#   wait    <session> [timeout=2400] [idle_confirms=3]             # block until the turn goes idle
#   waitfile <file> [timeout=2400]         # block until <file> exists & non-empty
#   rescue  <session> [nudge...]           # interrupt (Esc) a stuck turn; optionally send a nudge line
#   kill    <session>
#   list
set -uo pipefail

_pane() { tmux capture-pane -t "$1" -p 2>/dev/null; }
_alive() { tmux has-session -t "$1" 2>/dev/null; }

# The Codex TUI shows a status bar with the token budget ("… % left") once ready, and
# "esc to interrupt" while a turn is running. We key readiness/busyness off those.
_ready() { _pane "$1" | grep -q "% left"; }
_busy()  { _pane "$1" | grep -qiE "esc to interrupt|Working \(|Pursuing goal \("; }

# The live INPUT-BOX line = the LAST '›'/'>'-prefixed line. The conversation above uses •/◦/□/▸/└ markers
# and the status bar below has none, so the last '›' line is reliably the input box. When the box is EMPTY
# Codex shows a faint placeholder suggestion there ("Explain this codebase", etc.).
_last_input_line() { _pane "$1" | grep -E '^[[:space:]]*[›>]' | tail -1; }
# True while a just-typed prompt (matched by a literal signature = a leading slice of the text) is STILL
# sitting UNSENT in the input box. This is the DEFINITIVE "not submitted yet" signal — far more reliable
# than grepping the whole pane for a busy word (which can match stale scrollback or the typed text itself).
_input_pending() { _last_input_line "$1" | grep -qF -- "$2"; }

# Some codex builds show a BLOCKING "Update available" menu (1. Update now / 2. Skip / 3. Skip until
# next version) BEFORE the ready prompt — it stalls readiness detection and swallows the first message
# (a stray Enter can even pick "Update now"). Detect + dismiss it: navigate OFF "Update now" to "Skip"
# (one Down) and confirm. Never auto-update (that would disrupt a session). Gated on the prompt text so
# it is a no-op at the normal prompt.
_dismiss_startup_prompts() {
  local s="$1" p; p="$(_pane "$s")"
  if echo "$p" | grep -qi "Update available" && echo "$p" | grep -qiE "^\s*[›>]?\s*[0-9]\.\s*Skip"; then
    tmux send-keys -t "$s" Down; sleep 0.4; tmux send-keys -t "$s" Enter; sleep 1
    echo "  (codex-tmux: dismissed a startup 'Update available' prompt -> Skip)"
  fi
}

cmd_start() {
  local s="$1" cwd="$2" sandbox="${3:-read-only}" model="${4:-gpt-5.5}" effort="${5:-xhigh}"
  tmux kill-session -t "$s" 2>/dev/null
  tmux new-session -d -s "$s" -x 220 -y 50 -c "$cwd" || { echo "ERR: new-session failed"; return 1; }
  tmux send-keys -t "$s" -l "codex -m ${model} -c model_reasoning_effort=\"${effort}\" --sandbox ${sandbox} --cd \"${cwd}\""
  tmux send-keys -t "$s" Enter
  local i
  for i in $(seq 1 60); do
    _dismiss_startup_prompts "$s"        # auto-skip a blocking "Update available" menu if it appears
    _ready "$s" && { echo "READY: $s ($model $effort, $sandbox, $cwd)"; return 0; }
    sleep 1
  done
  echo "ERR: codex did not reach a ready prompt in 60s"; _pane "$s" | tail -8; return 1
}

# Submit one line of text and CONFIRM it actually went through. The TUI nuance (learned live): send the
# literal text, let it render, then a SEPARATE Enter to submit. A single quick `send-keys '...' Enter`,
# or an Enter that lands before a long prompt finished rendering, leaves the text sitting unsent in the
# input box (the goal-never-started bug). We confirm submission by checking the text LEFT the input box
# (definitive) rather than grepping for a busy word (which gave false positives).
cmd_send() {
  local s="$1"; shift; local text="$*"
  _alive "$s" || { echo "ERR: no session $s"; return 1; }
  # Signature = a leading slice of the literal text. While this appears on the input-box line, the prompt
  # is still UNSENT. (Kept verbatim incl. spaces/slashes so it matches the rendered box exactly.)
  local sig="${text:0:24}"
  # Clear any stale/partial input first — leftover text silently eats the new prompt.
  tmux send-keys -t "$s" C-u 2>/dev/null; sleep 0.3
  # Type the prompt literally (does NOT submit), then let the TUI fully render it (scale with length).
  tmux send-keys -t "$s" -l "$text"
  local w=$(( ${#text} / 350 + 2 )); [ "$w" -gt 7 ] && w=7; sleep "$w"
  # Submit + confirm. Retry Enter until the text LEAVES the box (submitted). Up to ~10 tries (~25s).
  local i
  for i in $(seq 1 10); do
    tmux send-keys -t "$s" Enter; sleep 1.6
    if ! _input_pending "$s" "$sig"; then
      # Box cleared -> the prompt was accepted. Give the turn a moment to spin up and report its state.
      sleep 1
      if _busy "$s"; then echo "SENT+SUBMITTED to $s (confirmed running): ${text:0:56}…"; return 0; fi
      sleep 2
      if ! _input_pending "$s" "$sig"; then echo "SENT to $s (box cleared, turn settling): ${text:0:56}…"; return 0; fi
    fi
    # still pending -> the Enter was dropped; loop and retry (the box keeps our text, so no duplication).
  done
  echo "WARN: could NOT confirm submit to $s after 10 tries — prompt still sitting in the input box."
  echo "  input box: $(_last_input_line "$s" | cut -c1-100)"
  echo "  retry:     codex-tmux.sh send $s \"<text>\"   (or: capture $s)"
  return 1
}

cmd_goal() {
  local s="$1" cwd="$2" gf="$3" sandbox="${4:-workspace-write}"
  [ -s "$gf" ] || { echo "ERR: goal file '$gf' missing/empty"; return 1; }
  cmd_start "$s" "$cwd" "$sandbox" || return 1
  # Natural-language trigger -> the codex-goal-ledger skill auto-detects + engages /goal.
  if ! cmd_send "$s" "Read the file ${gf} in full and SET THE GOAL TO exactly its contents, then execute that goal autonomously to its definition of done. Use the codex-goal-ledger skill: maintain a *-progress.md ledger, commit per milestone, self-verify each gate. Work NON-INTERACTIVELY — do not ask me questions; derive any missing session/goal metadata and proceed. Keep going until the goal is fully complete."; then
    echo "ERR: GOAL prompt did NOT submit in $s — it is NOT running. Inspect: codex-tmux.sh capture $s"; return 1
  fi
  echo "GOAL launched + CONFIRMED running in $s (cwd=$cwd, sandbox=$sandbox). Monitor: codex-tmux.sh progress $s ; the *-progress.md ledger in $cwd."
}

# IMPORTANT: a read-only Codex sandbox CANNOT write files (verified — it refuses + says so). So the
# consultative commands (review/research/ask) put their answer in the PANE; retrieve it with `harvest`
# (the model's final message is the last block of scrollback). Goals use workspace-write and DO write.

cmd_review() {
  local s="$1" cwd="$2" pf="$3"
  [ -s "$pf" ] || { echo "ERR: prompt file '$pf' missing/empty"; return 1; }
  cmd_start "$s" "$cwd" "read-only" || return 1
  if ! cmd_send "$s" "Read the file ${pf} in full and perform exactly that adversarial review now. Work autonomously; do not ask questions. The sandbox is READ-ONLY so you CANNOT write files — present your complete findings as your FINAL message, each: severity (blocker/major/minor/note), file:line, why it matters, recommended fix. End with the line REVIEW_DONE."; then
    echo "ERR: REVIEW prompt did NOT submit in $s. Inspect: codex-tmux.sh capture $s"; return 1
  fi
  echo "REVIEW launched + CONFIRMED in $s (read-only). When idle, retrieve: codex-tmux.sh harvest $s <out_file>"
}

# Research a topic/question (web search if available + repo/context reading). Output in the pane.
cmd_research() {
  local s="$1" cwd="$2" pf="$3"
  [ -s "$pf" ] || { echo "ERR: research prompt file '$pf' missing/empty"; return 1; }
  cmd_start "$s" "$cwd" "read-only" || return 1
  cmd_send "$s" "Read the file ${pf} in full and RESEARCH it thoroughly. Use web search if available and read any relevant files. Be rigorous: cite sources/files, separate fact from inference, flag uncertainty. The sandbox is READ-ONLY (no file writes) — present your full researched answer as your FINAL message. End with RESEARCH_DONE."
  echo "RESEARCH launched in $s (read-only). When idle: codex-tmux.sh harvest $s <out_file>"
}

# Quick consult — ask Codex for help / a second opinion on a decision, design, bug, or tradeoff.
# Inline question (short) OR a @file path. Output in the pane.
cmd_ask() {
  local s="$1" cwd="$2"; shift 2; local q="$*"
  [ -n "$q" ] || { echo "ERR: empty question"; return 1; }
  cmd_start "$s" "$cwd" "read-only" || return 1
  case "$q" in
    @*) cmd_send "$s" "Read the file ${q#@} and answer/advise on it. Read any relevant code first. Give your honest opinion + reasoning + a concrete recommendation; note risks + alternatives. Read-only sandbox (no writes) — answer as your FINAL message, ending with ANSWER_DONE.";;
    *)  cmd_send "$s" "Question for you (give your honest opinion + reasoning + a concrete recommendation; read any relevant files first; note risks/alternatives; read-only sandbox so no file writes; end with ANSWER_DONE): ${q}";;
  esac
  echo "ASK launched in $s (read-only). When idle: codex-tmux.sh harvest $s <out_file>  (or: capture $s)"
}

# Harvest the model's output from the pane scrollback into a file (for read-only review/research/ask,
# which cannot write files themselves). Grabs a generous scrollback window.
cmd_harvest() {
  local s="$1" out="$2"
  _alive "$s" || { echo "ERR: no session $s"; return 1; }
  tmux capture-pane -t "$s" -S -6000 -p 2>/dev/null | grep -vE "^\s*$" > "$out"
  echo "HARVESTED $(wc -l <"$out") lines -> $out  (the findings/answer are the last block; the top is the codex system preamble)"
}

cmd_capture() { _alive "$1" || { echo "(no session $1)"; return 1; }; _pane "$1" | grep -vE "^\s*$" | tail -"${2:-60}"; }

cmd_status() {
  _alive "$1" || { echo dead; return 0; }
  if _busy "$1"; then echo busy; return 0; fi
  # Not busy: distinguish a truly idle box (empty / showing a faint placeholder) from one with a prompt
  # SITTING UNSENT (the goal-never-started failure) — so `status` can catch a stuck launch.
  local line; line="$(_last_input_line "$1" | sed -E 's/^[[:space:]]*[›>][[:space:]]*//')"
  if [ -n "$line" ] && ! echo "$line" | grep -qiE '^(Explain this codebase|Summarize recent commits|Find and fix a bug|Write tests for|Use /skills|Ask Codex|Try |Message)'; then
    echo "input-pending"   # text is sitting in the input box UNSENT — re-submit (Enter) or resend
  else
    echo idle
  fi
}

cmd_wait() {
  local s="$1" timeout="${2:-2400}" need="${3:-3}" t=0 idle=0
  while [ "$t" -lt "$timeout" ]; do
    _alive "$s" || { echo "ENDED: session $s gone"; return 0; }
    if _busy "$s"; then idle=0; else idle=$((idle+1)); fi
    [ "$idle" -ge "$need" ] && { echo "IDLE: $s (turn finished)"; return 0; }
    sleep 5; t=$((t+5))
  done
  echo "TIMEOUT: $s still busy after ${timeout}s"; return 1
}

cmd_waitfile() {
  local f="$1" timeout="${2:-2400}" t=0
  while [ "$t" -lt "$timeout" ]; do [ -s "$f" ] && { echo "READY: $f"; return 0; }; sleep 5; t=$((t+5)); done
  echo "TIMEOUT: $f not written after ${timeout}s"; return 1
}

# Rescue a stuck/looping turn: Esc interrupts the current Codex turn (esc to interrupt). Then
# optionally send a corrective nudge line. If the session is dead, say so (caller restarts).
cmd_rescue() {
  local s="$1"; shift; local nudge="$*"
  _alive "$s" || { echo "DEAD: $s — restart with 'start' or 'goal'/'review'"; return 1; }
  tmux send-keys -t "$s" Escape; sleep 1; tmux send-keys -t "$s" Escape; sleep 1
  echo "INTERRUPTED $s. Pane:"; _pane "$s" | grep -vE "^\s*$" | tail -8
  if [ -n "$nudge" ]; then cmd_send "$s" "$nudge"; echo "NUDGED."; fi
}

# Compact one-line STATUS BAR parsed from the live pane — for a dashboard / to mirror into a
# Claude todo item. Extracts: state, the "Working (Xs)" timer, the "Tasks N/M" plan counter, the
# token budget, and the latest plan step / narration line.
cmd_progress() {
  local s="$1"
  if ! _alive "$s"; then echo "[$s] ● dead"; return 0; fi
  local p st elapsed tasks toks step
  p="$(_pane "$s")"
  if echo "$p" | grep -qiE "esc to interrupt|Working \("; then st="▶ working"; else st="✓ idle"; fi
  elapsed="$(echo "$p" | grep -oE "Working \([0-9hms ]+" | tail -1 | tr -d '(' )"
  tasks="$(echo "$p" | grep -oE "Tasks [0-9]+/[0-9]+" | tail -1)"
  toks="$(echo "$p" | grep -oE "[0-9]+% left" | tail -1)"
  # latest in-progress plan step (◦/□ marker) or the last narration bullet (•)
  step="$(echo "$p" | grep -E "^\s*[◦□•▸]" | grep -vE "esc to interrupt" | tail -1 | sed -E 's/^\s*[◦□•▸ ]+//' | cut -c1-90)"
  echo "[$s] ${st}${elapsed:+ · $elapsed}${tasks:+ · $tasks}${toks:+ · $toks}${step:+ · $step}"
}

# Print a status bar for ALL codex-* sessions (a mini dashboard).
cmd_dashboard() {
  local names; names="$(tmux ls -F '#{session_name}' 2>/dev/null | grep -iE '^(codex|cdx)')"
  [ -z "$names" ] && { echo "(no codex tmux sessions)"; return 0; }
  local n; while IFS= read -r n; do cmd_progress "$n"; done <<< "$names"
}

cmd_kill() { tmux kill-session -t "$1" 2>/dev/null && echo "killed $1" || echo "(no session $1)"; }
cmd_list() { tmux ls 2>/dev/null | grep -iE "codex|cdx" || echo "(no codex tmux sessions)"; }

sub="${1:-}"; shift || true
case "$sub" in
  start) cmd_start "$@";; send) cmd_send "$@";; goal) cmd_goal "$@";; review) cmd_review "$@";;
  research) cmd_research "$@";; ask) cmd_ask "$@";; harvest) cmd_harvest "$@";;
  capture) cmd_capture "$@";; status) cmd_status "$@";; progress) cmd_progress "$@";; dashboard|dash) cmd_dashboard "$@";;
  wait) cmd_wait "$@";; waitfile) cmd_waitfile "$@";; rescue) cmd_rescue "$@";; kill) cmd_kill "$@";; list) cmd_list "$@";;
  *) echo "usage: codex-tmux.sh {start|send|goal|review|research|ask|harvest|capture|status|progress|dashboard|wait|waitfile|rescue|kill|list} ..."; exit 2;;
esac
