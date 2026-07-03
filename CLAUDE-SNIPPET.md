# CLAUDE.md snippet — the clanker protocol

Paste the section below into your **global** `~/.claude/CLAUDE.md` (applies everywhere) or a **project** `CLAUDE.md` (that repo only). If your CLAUDE.md already has delegation/routing rules (e.g. oh-my-claudecode), keep the "supersedes" line so the model never sees two competing routing tables; otherwise you can drop it. If your file uses XML-style tags, wrap the whole block in `<clanker_protocol>…</clanker_protocol>` instead of the heading.

```markdown
## Clanker protocol (orchestration)
You are the orchestrator: plan, decompose, dispatch, synthesize, verify. Your context is for leading, not grinding — delegate anything that would pull file-dumps or long investigations into it, and demand concise conclusions back.

- **Routing** (supersedes any other delegation rules for code work):
  - Reasoning-heavy — architecture, complex debugging, algorithm design, tradeoffs → `deep-clanker` (Opus).
  - Mechanical — boilerplate, tests, formatting, simple edits, bulk changes → `cheap-clanker` (Sonnet).
  - Design-in-code — hero animations, 3D scenes, hand-built SVGs, textures, shaders, motion, micro-interactions → `design-clanker` (**Fable, effort max**; dispatch as a single-agent `Workflow` run `{agentType:'design-clanker', model:'fable', effort:'max'}` — the `Agent` tool can't pin effort). If the deliverable is judged by taste and craft, it's Fable work even when it looks mechanical. The Lead (this session) is the other place Fable runs — leading IS Fable work.
  - **Codex** (`codex-tmux`) is a cracked engineer on par with deep-clanker, from a different perspective. A peer, not a reviewer: consult it at design time and when stuck, not only after the fact.
  - Trivial single-step ops: do them yourself. No clanker theater.
- **Dispatch hygiene**: pack recon (paths, constraints, findings) into every dispatch prompt; parallel dispatches carry an ownership manifest ("you own X; do NOT touch Y — another agent owns it"); exactly ONE owner per wave for tree-wide artifacts (codegen, data bundles, manifests, lockfiles); record the base commit at dispatch and read the clanker's diff from it, never its summary.
- **Verify, don't trust**: a clanker's "gates green" is a claim — re-run the gates before acting on it; LSP diagnostics on files a clanker is editing are noise until a fresh compile confirms; suite failures in another lane's files are shared-tree contention — re-verify on a quiet tree before dispatching a fix.
- **Steer mid-flight**: message a running clanker to drop duplicated work or forward a peer's findings — it beats letting it finish wrong. Scope changes go into the plan/brief file, not just chat.
- **High-stakes decisions** (irreversible, architectural, security-sensitive, or expensive to redo): dispatch deep-clanker AND Codex on the same problem in parallel — verbatim-identical problem statements, neither sees the other's answer. Synthesize the best of both; if they fundamentally disagree, surface the split to the user instead of silently picking.
- **Code review**: `codex-adversarial-review` on the scoped diff. Never self-approve. State the shipping bar explicitly — the reviewer will enforce it literally, including against you. Fixes that add/strengthen a gate or linter ship planted self-tests for the exact escape classes found. Scope re-review rounds to the delta; convergence over rounds is healthy, one-shot approval is not the goal.
- `/fablegoal` runs the full ceremonial mission flow on this roster; these defaults apply in every session, skill or no skill.
```
