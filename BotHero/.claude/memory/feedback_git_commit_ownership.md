---
name: feedback-git-commit-ownership
description: Never run `git commit` in this repo — the user always does that themselves. Other git usage (status, diff, log, add/stage, branch, stash, etc.) doesn't need to be asked about.
metadata:
  type: feedback
---

Never run `git commit` (or anything that creates a commit on the user's behalf) in this repo. The user commits themselves, always.

Everything else git-related is pre-authorized — no need to ask before running git commands (status, diff, log, add/stage, branch, checkout, stash, fetch, pull, etc.).

**Why:** Stated directly: "Nunca hagas commit, eso lo voy a hacer yo. Fuera de eso, tenés permiso para usar git para lo que quieras sin preguntarme." They want full control over what lands in history and when, but don't want to be asked for routine git usage otherwise.

**How to apply:** Stage changes (`git add`) when it's useful to hand off a clean diff, but stop there and tell the user it's ready — don't follow through with `git commit` even if finishing the task would otherwise naturally end with one. Still generally avoid destructive/history-rewriting git operations (force-push, hard reset, rebase) without a clear reason tied to the current task, per normal judgment — the blanket "don't ask" is about routine/inspection commands, not a license to be careless. If the user explicitly asks in the moment for a commit to be made, that direct request overrides this standing rule.
