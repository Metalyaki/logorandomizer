---
name: phase
description: Plan or build one phase of a phased project from docs/project/roadmap.md in a fresh session, with the phase's own spec, plan, risk check, tests and review. Use when the user runs /phase or wants to continue a phased project.
argument-hint: next | <phase number> | status
disable-model-invocation: true
---

# Run a phase

Argument: $ARGUMENTS (default `next`)

Read only what this phase needs: `docs/project/roadmap.md`, the latest entry of `docs/handoff.md`, the parts of the brief and risk assessment that apply to this phase, and the phase's spec and plan when they exist. Do not read the whole repository or the plans of earlier phases.

## status
Show the phases with their state and the Next line of the latest handoff, then stop.

## Pick the phase
`next` is the first unchecked phase in the roadmap; a number picks that phase. Say in one line: the phase, its goal, its risk level, and whether this session will plan or build it.

## A. Plan the phase (no approved spec and plan yet)
1. Create `feature/NNNN-<phase-name>` from the default branch.
2. The **analyst** writes the spec for exactly this phase's scope (from the roadmap and brief) with the next free number. Write `Spec: NNNN` into the phase's line in the roadmap.
3. Ask its open questions with AskUserQuestion and resume the analyst with the answers.
4. **Risk**: for medium or high risk run `/risk spec NNNN`; the security requirements land in the spec. For low risk the analyst's Security and privacy section is enough.
5. The **architect** writes the plan; every security requirement maps to a step and a test.
6. Show the summary and get **approval** for the spec and the plan. Set `Status: approved` in both and record them: `pwsh -NoProfile -File .claude/hooks/approval.ps1 record <spec> <plan>`.
7. Commit: `docs: spec and plan NNNN for phase N`.
8. Run `/handoff` with Next: `/phase N`. Tell the user to `/clear` and run `/phase N` to build in a fresh session. Stop here: building in this session would drag the whole planning conversation along.

## B. Build the phase (approved spec and plan)
Start with the approval check from `/feature` step 0.3 and handle CHANGED or NONE the same way. Then follow `/feature` from "3. Build" through "5. Review": test first steps, implement, verify, record and commit per step, then coverage tests and a review at the depth the risk level requires.

Session budget: after two or three steps, or when context passes about 60 percent, run `/handoff` and ask the user to `/clear` and run `/phase N` again. The plan and the handoff carry everything the next session needs.

## C. Close the phase
1. `pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set ship` must be green. The **docs** agent updates docs and the CHANGELOG when users will notice.
2. Tick the phase in the roadmap with the date. If the phase changed the attack surface (new data, integrations, roles or AI capabilities), update `docs/project/risk-assessment.md` through `/risk`.
3. Run `/handoff` with Next: `/ship`, then `/phase next`.
4. Tell the user: run `/ship` to open the pull request for this phase, then `/clear` and `/phase next`.
