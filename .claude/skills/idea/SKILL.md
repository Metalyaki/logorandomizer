---
name: idea
description: Turn a rough idea into an approved spec and implementation plan, without writing any code. Use when the user runs /idea or wants an idea analyzed and designed before building it.
argument-hint: <the idea in a sentence or two>
disable-model-invocation: true
---

# From idea to approved plan

The idea: $ARGUMENTS

No production code is written in this workflow.

1. Delegate to the **analyst** with the idea. It writes the spec in `docs/specs`.
2. Ask the user the analyst's open questions with AskUserQuestion: up to four per call, each with the analyst's options and its recommendation first. Confirm the assumptions the same way.
3. Resume the analyst (SendMessage, so it keeps its context) with the answers. It updates the spec.
4. Show the user the spec summary and the acceptance criteria. **Stop and wait for approval.** On approval set `Status: approved` in the spec and record it: `pwsh -NoProfile -File .claude/hooks/approval.ps1 record <spec>`.
5. **Risk**: for medium or high risk run `/risk spec NNNN`. The security requirements land in the spec; the user approves them and accepts the residual risks.
6. Delegate to the **architect** with the spec path. It writes the plan (and an ADR when a real decision is made); every security requirement maps to a step and a test.
7. Show the user the approach, the steps with owners and (TF) marks, the threat model table, and the risks. Ask the architect's questions with AskUserQuestion. **Stop and wait for approval.** On approval set `Status: approved` in the plan and record both files: `pwsh -NoProfile -File .claude/hooks/approval.ps1 record <spec> <plan>` (the spec again, because step 5 may have added security requirements to it).
8. Commit the spec and plan on a branch `feature/NNNN-<name>`: `docs: spec and plan NNNN <name>`.
9. Run `/handoff` with Next: `/feature NNNN`, and tell the user to `/clear` and run `/feature NNNN` to build in a fresh session.
