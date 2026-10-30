---
name: ship
description: Prepare a finished branch for a pull request with full checks, review status, migration and secret checks, changelog and PR description, and push only after the user approves. Use when the user runs /ship.
argument-hint: [draft]
disable-model-invocation: true
---

# Ship the current branch

1. **Branch**: confirm the branch is not protected and the working tree is clean. If it is not clean, ask whether to commit the rest.
2. **Up to date**: `git fetch`, then check that the default branch is an ancestor of HEAD. If not, ask the user whether to rebase or merge, and do it only after approval.
3. **Checks**: `pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set ship`. Stop and report if anything fails.
4. **Review**: if no review at the depth the risk level requires ran since the last code commit, run `/team-review` now. No confirmed Blocking, Critical or High finding may stay open, and every security requirement in the spec must have a passing test.
5. **Migrations**: list new EF Core migrations in the diff. Check that the model and migrations agree (`dotnet ef migrations has-pending-model-changes`), read each new migration for data loss (dropped or renamed columns, type changes) and note anything that needs a backfill or a maintenance window.
6. **Secrets**: the `secrets-scan` check (gitleaks) in step 3 scans every commit on the branch. When gitleaks is not installed it is skipped: then scan `git diff <default branch>...HEAD` yourself for keys, tokens, connection strings with passwords and private keys, and tell the user to install gitleaks.
7. **Changelog**: when users will notice the change, the **docs** agent adds an entry under Unreleased in `CHANGELOG.md`.
8. **PR description** with these sections: Summary, Linked spec, Changes, How it was tested (with the check results), Screenshots needed (list them), Migration notes, Configuration and rollout, Risks and rollback.
9. **Ask before pushing** with AskUserQuestion: push and open a PR / push and open a draft PR / do not push. Use a draft when the argument is `draft`.
10. After approval: `git push -u origin <branch>`, then `gh pr create` with the title and the description (`--draft` when chosen). Without `gh`, give the user the PR text to paste.
11. Tell the user the PR link. On the Team plan with Code Review enabled, Claude reviews the PR on GitHub automatically, guided by `REVIEW.md`.
