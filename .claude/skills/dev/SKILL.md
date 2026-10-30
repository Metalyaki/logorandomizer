---
name: dev
description: Triage any development request. Assess its risk, pick the right lane (trivial, small, bug, feature, project, refactor, spike, upgrade, infra, docs, question) and run that lane's flow with the team. Use when the user runs /dev.
argument-hint: <what you want done>
disable-model-invocation: true
---

# Triage and run

Request: $ARGUMENTS

You are the tech lead. Your first line to the user is:
`Risk: <High | Medium | Low> (<triggers>). Lane: <lane>, because <one reason>. Next: <first action>.`

Use the risk triggers from CLAUDE.md. A request with any trigger is never trivial, and the risk level decides the security work (see CLAUDE.md). If the request is ambiguous and the lanes differ a lot in cost, ask with AskUserQuestion and offer the two or three likely lanes, your pick first. Otherwise start right away.

## Branch rule (every lane that changes files)
Never commit on a protected branch (`guard.protectedBranches` in `.claude/team.json`). Create a branch first: `fix/<name>`, `feature/NNNN-<name>`, `chore/<name>`, `refactor/<name>`, `spike/<name>`.

## Lanes

**trivial**: low risk only. A typo, a text change, one obvious line.
You edit it yourself, run `/verify`, commit (`chore:` or `fix:`), report in two lines.

**small**: low or medium risk, a clear change in about three files or fewer, no new concepts, no schema change.
1. You implement it yourself, with tests for the changed behavior. Spawning implementers for a small change costs more than it saves.
2. The **reviewer** reviews the diff (independence: you wrote the code). For medium risk the **security** agent reviews in parallel.
3. `/verify`, then commit.

**bug**: something is broken. Run `/fix`.

**feature**: new behavior, many files, a schema change, high risk, or unclear scope. Run `/feature`; start with `/idea` when the idea is still fuzzy.

**project**: a new product or a change too large for one spec. Run `/kickoff` (plans the whole project in `docs/project`), then `/phase next` for each phase in fresh sessions.

**refactor**: structure changes, behavior must not.
1. The **architect** writes a short refactor plan from `.claude/templates/plan.md` (target structure, invariants, small steps) as `docs/specs/refactor-<name>.plan.md`.
2. The **tester** writes characterization tests that pass on the current code and pin the behavior.
3. The owner works through the steps; tests stay green and unchanged after every step; commit per step.
4. The **reviewer** checks that behavior did not change (security too when the code handles any risk trigger).

**spike**: a question to answer or a prototype to learn from.
Agree a time box with the user. Use Explore and the architect. Write the findings to `docs/spikes/YYYY-MM-DD-<topic>.md` or an ADR. Prototype code only on a `spike/` branch that is never merged.

**upgrade**: packages or framework versions. Run `/deps`.

**infra**: CI, Docker, Bicep, Terraform, deploy configuration. Always at least medium risk.
devops implements and validates; security and reviewer review; `/verify`. Nothing is deployed from the session.

**docs**: README, guides, API docs, changelog. The docs agent writes; you check the result against the code.

**question**: about the code, a design or a tradeoff. Answer directly; use the Explore agent for wide searches. No files change.

## Always
- Keep the user posted with a task list for anything with more than two steps.
- Approval gates from CLAUDE.md apply in every lane.
- Finish with what changed, how it was verified, and the next step. When the task is done, suggest `/handoff` and `/clear` before the next unrelated task.
