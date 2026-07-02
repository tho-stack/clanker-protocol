#!/usr/bin/env bash
# clanker-protocol installer — copies skills + agents into ~/.claude (or $CLAUDE_DIR).
# Non-destructive by default: existing files are skipped. Re-run with -f to overwrite.
set -euo pipefail

DEST="${CLAUDE_DIR:-$HOME/.claude}"
FORCE=0; [ "${1:-}" = "-f" ] && FORCE=1
HERE="$(cd "$(dirname "$0")" && pwd)"

copy() { # src dst
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ "$FORCE" -ne 1 ]; then
    echo "SKIP (exists): $dst    (re-run with -f to overwrite)"
    return 0
  fi
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  echo "installed: $dst"
}

for s in fablegoal codex-tmux codex-adversarial-review; do
  copy "$HERE/skills/$s" "$DEST/skills/$s"
done
for a in deep-clanker cheap-clanker design-clanker; do
  copy "$HERE/agents/$a.md" "$DEST/agents/$a.md"
done
chmod +x "$DEST/skills/codex-tmux/codex-tmux.sh" 2>/dev/null || true

echo
echo "Done. Two follow-ups:"
echo "  1. Paste the orchestration rules into your CLAUDE.md:  see $HERE/CLAUDE-SNIPPET.md"
echo "  2. Optional Codex lane: install tmux + the OpenAI codex CLI, then 'codex login'."
echo "Restart your Claude Code session (or start a new one) to pick up the skills/agents."
