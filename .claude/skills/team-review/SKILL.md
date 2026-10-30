---
name: team-review
description: Review the current changes with the reviewer and security agents in parallel, verify their findings and offer the fixes. Use before committing to the default branch, before a pull request, or when the user asks for a review of what changed.
argument-hint: [base branch, commit range or path]
---

# Team review

Scope: $ARGUMENTS (default: the default branch compared to HEAD, plus uncommitted changes)

1. Determine the scope and show `git diff --stat` for it. If there is nothing to review, say so and stop.
2. Run the **reviewer** and **security** agents in parallel on that scope. Give both the base, and the spec and plan paths when they exist. For a high risk change, spawn the reviewer with model `opus`.
3. For a large or risky diff, offer the built in `/code-review` as an extra, independent pass. It costs more usage; ask first.
4. Merge the findings into one list ordered by severity, without duplicates. Read the code for every Blocking, Critical and High finding yourself and mark it confirmed or rejected (with a one line reason).
5. Show the user a table: severity, `file:line`, finding, proposed fix, source agent.
6. Ask with AskUserQuestion: fix all confirmed Blocking, Critical and High findings / let me pick / no fixes now.
7. Send each fix to the agent that owns that code (backend, frontend, devops or docs). Then review again, focused on what changed. Stop after three rounds and ask the user if blockers remain.
