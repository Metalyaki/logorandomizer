---
name: fix
description: Fix a bug the disciplined way. Reproduce it with a failing test, find the root cause, make the smallest fix, verify and review. Use when the user reports a bug, an error, a crash, a failing test or wrong behavior, or runs /fix.
argument-hint: <bug description, error message or GitHub issue number>
---

# Fix a bug

Bug: $ARGUMENTS

## 0. Risk
Say the risk level in one line (triggers from CLAUDE.md). A security vulnerability is always High: treat the report as confidential (no details in public issues or commit messages until it is fixed), and plan a variant search.

## 1. Understand
- When the input is an issue number and `gh` is available, read it with `gh issue view <n> --comments`.
- Restate the bug in two lines: expected, actual, where. If facts are missing that decide where to look (which environment, which steps, since when), ask once with AskUserQuestion.
- If you are on a protected branch, create `fix/<short-name>`.

## 2. Locate
Find the code involved. Use the Explore agent when it takes a wide search; read directly when the location is obvious.

## 3. Reproduce
The **tester** in reproduce mode writes the smallest failing test that shows the bug, and confirms it fails with the reported symptom.
When an automated test is not feasible (a pure environment or styling issue), write down exact manual reproduction steps instead and say so to the user.

## 4. Root cause and fix
The **debugger** gets the failing test, the bug summary and what you found. It finds the root cause with evidence and makes the smallest fix at the source.
For a truly trivial cause that is obvious from the code (a typo, a wrong constant), you may fix it yourself, but still only after the failing test exists.

## 5. Verify
The reproduction test passes, `/verify` is green for the area, and nothing else regressed.

## 6. Review
The **reviewer** does a focused pass on the diff. Add the **security** agent for medium or high risk, and always for a vulnerability: it checks the fix and searches the codebase for the same pattern elsewhere (variant analysis). Fix confirmed findings.

## 7. Commit and report
Commit `fix(<area>): <summary>` with a body that states the root cause, the fix and the regression test.
Tell the user: the root cause, the fix, the test that now guards it, and whether similar bugs may exist elsewhere (the debugger's last point). Offer `/ship` if they want a pull request.
