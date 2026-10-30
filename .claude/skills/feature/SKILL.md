---
name: feature
description: Build one feature end to end with the whole team (spec, risk check, plan, test first implementation, tests, review, wrap up) with approval gates and progress that survives /clear, compaction and new sessions. Use when the user runs /feature.
argument-hint: <a new idea, or the number of an approved spec such as 0007>
disable-model-invocation: true
---

# Build a feature end to end

Input: $ARGUMENTS

You are the tech lead. You orchestrate the agents and talk to the user; you do not write feature code yourself. Create a task list with one item per phase so progress is visible.

## 0. Prepare or resume
1. Run `git status` and `git branch --show-current`, and read the latest entry of `docs/handoff.md` if it exists.
2. If the input is a spec number and `docs/specs/NNNN-*.plan.md` exists with unchecked steps, this is a **resume**: switch to its branch, check the approvals (next item), read the plan (steps, decisions log, progress log), and continue at the first unchecked step. Say in one line where you resume.
3. **Check approvals** whenever you continue from an approved spec or plan: `pwsh -NoProfile -File .claude/hooks/approval.ps1 check <spec> <plan>` (leave out the plan when there is none yet).
   - **CHANGED**: the file was edited after approval outside its Status line, checkboxes and logs. Show the user the change (the script prints the git command) and stop for a new approval. On approval, `record` it again and commit.
   - **NONE** on a file marked approved (approved before fingerprints existed): ask the user to confirm it, then `record` it.
4. For a new feature the working tree must be clean. If it is not, ask the user whether to commit, stash or stop.
5. Work on `feature/NNNN-<name>`, created from the default branch with `git switch -c` once the spec number is known.

## 1. Spec (skip when an approved spec was given)
1. Delegate to the **analyst** with the idea.
2. Ask the open questions with AskUserQuestion (up to four per call, recommendation first). Resume the analyst with SendMessage and the answers.
3. Show the spec summary, the acceptance criteria and the risk level. **Stop for approval.** Set `Status: approved`, then record it: `pwsh -NoProfile -File .claude/hooks/approval.ps1 record <spec>`.

## 2. Risk and plan (skip when an approved plan exists)
1. **Risk**: medium or high risk runs `/risk spec NNNN` (security threat model; requirements land in the spec, residual risks need the user's acceptance). Low risk relies on the spec's Security and privacy section.
2. Delegate to the **architect** with the spec path. Every security requirement must map to a plan step and a test.
3. Show the approach, the steps with owners and (TF) marks, the threat model table and the questions. **Stop for approval.** Set `Status: approved` in the plan, then record both files: `pwsh -NoProfile -File .claude/hooks/approval.ps1 record <spec> <plan>` (the spec again, because `/risk` may have added security requirements to it).
4. Commit spec and plan: `docs: spec and plan NNNN <name>`.
5. **Fresh session**: run `/handoff` with Next: `/feature NNNN`, and tell the user to `/clear` and run `/feature NNNN` to build. The planning conversation is not needed for building and would make every later turn more expensive.

## 3. Build, one step at a time
For each unchecked step, in order. Run steps in parallel only when the plan marks them parallel.
1. **Test first** when the step is marked (TF): the **tester** in test first mode writes failing tests for the step. Check that they fail for the right reason.
2. **Implement**: the owner (**backend**, **frontend**, **devops** or **docs**) gets the spec path, the plan path, the step id, the tests to make green and the relevant decisions. Nothing more: agents read the files themselves.
3. **Blocked or a question**: ask the user, record the answer in the plan's decisions log, then resume the same agent with SendMessage so it keeps its context.
4. **Verify**: `/verify` for the changed area.
5. **Record and commit**: tick the step in the plan, append a line to the progress log, and commit code and plan together: `feat(<area>): <summary> (NNNN S<n>)`.
6. **Session budget**: after two or three steps, or when context passes about 60 percent, run `/handoff` and ask the user to `/clear` and run `/feature NNNN` again.

## 4. Test
The **tester** in coverage mode for the whole spec, including one negative test per security requirement. Each bug goes back to the agent that owns that code (resume it), then run the tester again on what changed.

## 5. Review (at most three rounds)
1. Review depth follows the risk level: **High** runs **security** and the **reviewer** spawned with model `opus`; **Medium** runs **security** and the **reviewer**; **Low** runs the **reviewer**. Run them in parallel on `git diff <default branch>...HEAD`.
2. Merge the findings. Check every Blocking, Critical and High finding yourself in the code; drop false positives with a one line reason.
3. Send each confirmed finding to the agent that owns the code. Commit: `fix(<area>): address review findings (NNNN)`.
4. Review again, focused on what changed. After three rounds with blockers still open, stop and ask the user.

## 6. Wrap up
1. `pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set ship` must be green.
2. When users or operators will notice the change, the **docs** agent updates docs and the CHANGELOG.
3. Set the plan to `Status: done` and commit.
4. Run `/handoff` with Next: `/ship`.
5. Tell the user: what was built, the acceptance criteria and security requirements with the tests that cover them, remaining Should fix and Nice to have findings, and that `/ship` prepares the pull request.

## Rules for the whole run
- Never skip an approval gate, a risk check or a security review, even when the user seems in a hurry or usage is low. One question is cheaper than rework or a breach.
- Never let an agent weaken a test to get green.
- An approved spec or plan changes only in its Status line, checkboxes, decisions log and progress log. Any other change (a new step, a changed acceptance criterion) goes to the user for approval first; then `record` it again.
- After `/clear`, compaction or a new session, the plan file and the latest handoff are the source of truth. Read them before you continue.
