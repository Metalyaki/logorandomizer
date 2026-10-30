---
name: verify
description: Verify that the current changes really work. Runs the checks from .claude/team.json for every changed area and checks the changed behavior itself. Claude runs it before commits; use it whenever you are about to say something is done or fixed.
argument-hint: [full]
---

# Verify the changes

Mode: $ARGUMENTS (default quick; `full` runs everything that must pass before a pull request)

1. **Checks**: run `pwsh -NoProfile -File .claude/hooks/run-checks.ps1` in quick mode, or `pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set ship` in full mode. A check that already passed on the exact same files is reported as cached and not rerun.
2. **When something fails**: read the key lines, fix the cause (or hand it to the agent that owns the code), and run the checks again. Never report done while a check is red, and never weaken a test to get green.
3. **Behavior**: when it is cheap, check the changed behavior itself, not only the tests:
   - an endpoint: an integration test that calls it, or run the app and call it with `Invoke-RestMethod` or `curl` against localhost;
   - a page or component: open it with Playwright CLI (when installed), take a screenshot and look at it;
   - a script, job or CLI: run it once with sample input.
   Skip this when it is not feasible, and say so.
4. **Report** in a few lines: the check table (PASS, FAIL, SKIP), what behavior you verified and how, and what was not verified.
