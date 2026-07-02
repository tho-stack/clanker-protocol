---
name: codex-adversarial-review
description: Run an adversarial OpenAI Codex review (challenge the implementation approach, design choices, tradeoffs, and assumptions — not just hunt defects) over a scoped git diff, pinned to gpt-5.5 / xhigh reasoning, read-only. Use when the user asks for a "codex adversarial review", "adversarial review", "challenge review", a Codex review of a branch/diff/commit, or a review after a milestone/phase. This is the model-invocable replacement for the `/codex:adversarial-review` plugin command (that command is disable-model-invocation, so Claude cannot call it).
---

# Codex Adversarial Review (gpt-5.5 / xhigh)

Runs OpenAI Codex (codex-cli) as an independent adversarial reviewer. **Review-only — never let it edit.**
Treat Codex as a peer, not an authority: evaluate every finding critically and push back (with evidence)
where you disagree (it has a knowledge cutoff).

## Non-negotiable invocation settings

ALWAYS pin these — the whole point of this skill is the model/effort guarantee:

- `-m gpt-5.5`
- `-c model_reasoning_effort="xhigh"`
- `--sandbox read-only` (a review must not modify the tree)
- `--skip-git-repo-check`
- append `2>/dev/null` (suppress thinking-token stderr)

If `codex --version` fails or any `codex` run exits non-zero, STOP and tell the user (likely needs `codex login`).

## Steps

1. **Scope the review.** Default to the current branch vs its base:
   - `BASE` = the base the user named, else `main` (else the repo default branch).
   - If `HEAD` is the default branch with uncommitted work, review the working tree instead.
   - Sanity-check there's something to review: `git status --short`; `git diff --shortstat <BASE>...HEAD`
     (count untracked files too). If genuinely empty, say so and stop.

2. **Run Codex** (capture to a file — reviews are long). Pipe the diff on stdin so Codex sees the exact
   change set even under read-only sandbox; it can still read full files for context:

   ```bash
   git diff "$BASE"...HEAD > /tmp/cx-scope.diff
   codex exec -m gpt-5.5 -c model_reasoning_effort="xhigh" --sandbox read-only --skip-git-repo-check \
     "ADVERSARIAL REVIEW — review only, do NOT propose to make edits. The unified diff to review is on stdin; read the surrounding files for context. CHALLENGE the chosen implementation APPROACH, DESIGN choices, tradeoffs, and ASSUMPTIONS (where does this fail under real-world conditions?) in addition to finding correctness bugs. <ADD PROJECT FOCUS HERE>. Report concrete findings, each with: severity (blocker/major/minor/note), file:line, why it matters, and a recommended fix. Be skeptical — assume a subtle bug exists." \
     < /tmp/cx-scope.diff > /tmp/cx-adversarial-review.md 2>/dev/null
   echo "exit $?"
   ```
   (For a single commit, scope with `--commit`-style `git show <sha>` instead; for working tree, diff
   `HEAD` + list untracked files in the prompt.)

3. **Read `/tmp/cx-adversarial-review.md` and surface the findings to the user** — don't bury them.

4. **Act on it (separate from the review):** evaluate each finding, then fix the confirmed/actionable
   ones, re-run the project's gates (tests/typecheck/lint), and report. Disagree with evidence where
   Codex is wrong.

## Project focus hooks

Replace `<ADD PROJECT FOCUS HERE>` with the quality bar that matters for *your* project, e.g.:
"This module must stay dependency-free (stdlib only); flag any figure that can't be reproduced from the
model, and anything that weakens the site's auth gate." Re-run the review after **every milestone/phase**,
not only at the end.
