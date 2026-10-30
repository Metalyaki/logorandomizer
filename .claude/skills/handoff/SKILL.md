---
name: handoff
description: Write a short handoff for the next session into docs/handoff.md and the active plan, so work continues after /clear without the old conversation. Use at the end of every working session, before /clear, when switching tasks, when context passes about 60 percent, or when the user runs /handoff.
argument-hint: [what the next session should do, if you want to steer it]
---

# Handoff

1. Collect facts with cheap commands only: `git branch --show-current`, `git rev-parse --short HEAD`, `git status --short`, and `pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set stop` (it prints only failures).
2. Add a new entry at the top of `docs/handoff.md` (create the file from `.claude/templates/handoff.md` when it is missing), with the template's fields: working on, done this session, state, decisions, open questions, watch out, and the exact command to continue. Keep it under 15 lines and factual. Never include secrets, tokens or personal data.
3. Keep at most ten entries; delete the older ones.
4. When a plan is active, tick the finished steps and append the same Done and Next lines to its progress log.
5. On a work branch (not protected), commit the handoff and the plan with `docs: handoff <short summary>`, together with finished work whose checks are green. When checks are red, commit only the docs and say so in the entry.
6. Tell the user in two lines what is saved, then: "Run /clear (it costs nothing), then `<Next command>`."

When the user gave an argument ($ARGUMENTS), use it for the Next line.
