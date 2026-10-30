---
name: new-skill
description: Create or change a skill, agent or rule for this dev team, and prove it changes Claude's behavior before trusting it. Use when the user runs /new-skill.
argument-hint: <what Claude should do differently, or the path of the skill, agent or rule to change>
disable-model-invocation: true
---

# Create or change a team skill, agent or rule

Request: $ARGUMENTS

Guidance for Claude is code for behavior: watch it fail first, write the smallest thing that fixes what you saw, then close the loopholes. If you never saw Claude get it wrong without the guidance, you do not know that the guidance teaches the right thing. This applies to changes of existing files too.

Keep a task list with one item per step below.

## 0. Pick the right home
Choose the lightest place that works, and say which one and why in one line:
- **Something a script can check** (a forbidden command, a file nobody may write, a format) goes into a hook or `.claude/team.json`, not prose. Prose is for judgment.
- **A fact or convention of this repository** goes into one short line in CLAUDE.md, or into a stack rule in `.claude/rules/<stack>.md`, which loads only for files matching its `paths:`.
- **A role with its own context and tools** is an agent in `.claude/agents/<name>.md`.
- **A repeatable workflow or technique** is a skill in `.claude/skills/<name>/SKILL.md`. Material over about 100 lines goes into a file next to it, linked from the skill with the condition for reading it (like `risk/checklists.md` and the references in `fix/`).
- **A one off** needs no skill. Just do it.

Changing an existing file beats adding a near duplicate.

## 1. RED: the baseline without the guidance
1. Write two or three short scenarios that tempt the failure.
   - For a rule Claude must keep under pressure, combine pressures: time ("the demo starts in ten minutes"), sunk cost ("we already spent two hours on this"), authority ("the senior developer said to skip it"), exhaustion, and pragmatism ("it is only a small change").
   - For a technique, a realistic task where it applies, plus one variation with an edge case.
2. Run each scenario in a fresh general purpose subagent on the model the guidance will run on, with no draft in place. Give it realistic context and a task, not a quiz.
3. Record what it did and its rationalizations, word for word.

If the baseline already does the right thing, stop and tell the user: there is nothing to write.

## 2. GREEN: the smallest guidance that fixes what you saw
Draft in the scratchpad, not under `.claude/`, so the draft does not load while you test. Match the form to the failure you recorded:

| Baseline failure | Form that works | Form that backfires |
| --- | --- | --- |
| Knows the rule, breaks it under pressure | A clear prohibition, the recorded rationalizations each with its answer, and red flags to notice | Soft words ("prefer", "consider") |
| Does the job, but the output has the wrong shape | A recipe: what the output is, its parts, in order | A list of things not to do |
| Leaves out a required part | A required slot in the template it fills in | A reminder in prose near the template |
| Should behave differently in some situations | A condition on something observable ("when a test uses `Task.Delay`, ...") | A rule plus exceptions |

No nuance clauses such as "unless it matters": they reopen the negotiation. A real exception becomes its own condition.

Run the same scenarios again with the draft given to the subagent as its instructions. It must now comply.

## 3. REFACTOR: close the loopholes
- A new rationalization appeared? Add an explicit answer and run again, until the scenarios pass.
- Wording that shapes behavior: compare it with a no guidance control, at least five runs per variant, and read every result yourself. Five different interpretations in five runs mean the wording is not binding yet; tighten the form before adding words.
- Pure reference material (facts, commands, checklists) needs one retrieval scenario, not pressure runs.

Each run costs usage. Keep scenarios short and stop at the first clean pass that meets the bar above.

## 4. Write it in place
Writing under `.claude/` asks for approval through the protect hook. That is expected.
- **Frontmatter** between `---` lines with `name:` (lowercase letters, digits and hyphens, the same as the folder or file name) and `description:`. Quote any value that contains `: ` or ` #`; the self test rejects it otherwise. Rules have only `paths:`.
- **Description**: says when to use it, in the third person, with the words a user or agent would search for (symptoms, commands, file types). It never summarizes the workflow: an agent that reads a summary follows the summary and skips the body.
- **Workflow skills** the user starts by name get `disable-model-invocation: true` and an `argument-hint`.
- **Agents** follow the other agent files: `model`, `tools` for read only roles, and a "Report back" section that asks for under 20 lines. A new read only agent also needs an entry in `guard.readOnlyAgents` and in `scopes` in `.claude/team.json`; a new writing agent needs its `scopes` entry.
- **Content**: one excellent example beats several mediocre ones. No stories about how a bug was found once. Plain words, short. CLAUDE.md stays under 150 lines.

## 5. Verify and finish
1. Run `pwsh -NoProfile -File .claude/hooks/tests/run-tests.ps1`. It must end with `Failed: 0`.
2. Run one scenario once more against the installed file in a fresh subagent.
3. Update the README (What is in the box, Daily use) when users will notice the change.
4. Commit on `chore/<name>`: `chore(team): add <name> skill` (or agent, or rule), with a body that names the baseline failure it fixes.
5. Tell the user: the failure you saw, what the guidance changed, and which scenarios now pass.

---
Adapted from obra/superpowers, `skills/writing-skills/SKILL.md` (MIT License, Copyright (c) 2025 Jesse Vincent). See `.claude/NOTICES.md`.
