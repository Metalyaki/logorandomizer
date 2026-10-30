---
name: team-init
description: Adapt the dev team setup to this repository. Checks the machine and the hooks, detects the stack, brings the checks to a green baseline, fills in CLAUDE.md and .claude/team.json, and recommends plugins and MCP servers. Use once per repository after copying the setup in, or when the stack changes, or when the user runs /team-init.
disable-model-invocation: true
---

# Set up the dev team for this repository

Work through the steps, keep a task list, and ask before writing anything.

## 1. Machine check
Run these and show one table (tool, version, status). Missing tools are fine when the stack does not need them.
- `pwsh --version` (7.4 or newer is required for the hooks), `git --version`, `gh auth status`, `docker version --format '{{.Server.Version}}'`
- Stack tools as relevant: `dotnet --list-sdks`, `node --version`, `npm --version`, `python --version`, `uv --version`, `php --version`, `composer --version`, `az version`, `azd version`, `actionlint --version`
- Security tools: `gitleaks version` (secret scan before every pull request; install with `winget install --id Gitleaks.Gitleaks`)
- PowerShell policy: `pwsh -NoProfile -Command "Get-ExecutionPolicy -List; $ExecutionContext.SessionState.LanguageMode"`. A MachinePolicy or UserPolicy of AllSigned, or a language mode other than FullLanguage, means IT must sign or allow list `.claude/hooks/*.ps1` (see README, Troubleshooting).

## 2. Hook self test
Run `pwsh -NoProfile -File .claude/hooks/tests/run-tests.ps1`. Every test must pass. If one fails, stop and show the failure.

## 3. Detect the stack
Look for, and note versions where possible:
- .NET: `*.sln`, `*.slnx`, `*.csproj` (TargetFramework), `global.json` (SDK, test runner), `Directory.Packages.props`, test frameworks (xUnit, NUnit, MSTest), EF Core and its migrations folder, Testcontainers.
- JavaScript: every `package.json` (scripts `build`, `test`, `lint`, `e2e`), `angular.json` and the Angular version, `next.config.*`, Vite, the test runner (Vitest, Karma, Jest), Playwright, prettier, eslint.
- Python: `pyproject.toml`, `requirements*.txt`, `uv.lock`, pytest, ruff, mypy; AI SDKs (anthropic, openai, langchain).
- WordPress and PHP: `composer.json`, `wp-content`, `style.css` with a Theme Name header, `theme.json`, `phpcs.xml`, PHPUnit, `.wp-env.json`.
- Infrastructure: `Dockerfile*`, compose files, `*.bicep`, `azure.yaml`, `*.tf`, `.github/workflows`.

**No code yet** (a new repository with only the team setup): say so and keep this run short. Keep `team.json` as it is, because checks for folders that do not exist yet skip themselves. Skip steps 4, 6 and 7; the kickoff or the first spec fills in Product and Stack. Run step 5 (it turns off `actionlint` until the first workflow exists). In step 9 the setup becomes the first commit on the default branch, since there is nothing to branch from yet. In the summary, say that `/team-init` runs again once the first code exists; `/start` reminds the user.

## 4. Propose `.claude/team.json` changes
Use the profiles in `profiles.md` next to this file. Adjust paths (`cwd`, `when`) to the real folders, the test folder names in `scopes.tester`, and turn on `web-lint` only when a lint script exists. Remove checks for stacks that are not in the repository. If `dotnet build` would find more than one solution or project at the root, put the solution path in the dotnet commands.
Show the proposed changes as a short diff and ask for approval with AskUserQuestion. Then write them (the protect hook asks the user once more).

## 5. Green baseline
Every branch after the setup should start from green checks, so a problem that already exists never surfaces in the middle of a feature.
- Run `pwsh -NoProfile -File .claude/hooks/run-checks.ps1 -Set ship -NoCache` and show the PASS, FAIL and SKIP table.
- Sort every failure:
  - **Formatting** (`dotnet-format`, prettier): fix it now with the tool the check uses. Otherwise the format hook rewrites unrelated lines inside the first feature commit that touches the file.
  - **Build or tests**: stop and show the key lines. The user decides whether `/fix` comes first.
  - **Vulnerable packages** (`dotnet-vulnerable`, `npm-audit`): do not upgrade here, because every upgrade needs its own approval. Record the advisory and recommend `/deps security only` as the first task after the setup is merged.
  - **A check with nothing to check yet**, for example `actionlint` without `.github/workflows`: propose `"enabled": false` for it in `team.json`, to be turned back on when the first workflow is added.
- Show the fixes as a short diff and ask for approval with AskUserQuestion. They become their own commit (`style:` or `chore:`), separate from the setup files.
- Run the ship checks again and keep anything still red, with the reason, for the summary.
- If the user is already on a feature branch, say so: the baseline belongs on `chore/dev-team-setup`, and that branch should be merged before the first feature branch starts. Otherwise every branch carries the same fix and the push order becomes a question.

## 6. Fill in CLAUDE.md
- **Product**: ask the user for two or three sentences.
- **Stack**: the detected frameworks and versions.
- **Repository layout**: only what is not obvious from the tree.
- **Commands**: the same commands that are in `team.json`.
Keep the file under 200 lines. Ask for approval before writing.

## 7. Recommend plugins and MCP servers
Give the user the commands to run themselves (plugins are personal installs), only for the stacks found. The language server plugins come first: they let agents jump to definitions instead of reading many files, which saves a lot of usage.
- Always: `/plugin install microsoft-docs@claude-plugins-official` is optional when `.mcp.json` already has `microsoft-learn`; keep one of the two.
- .NET: `/plugin install csharp-lsp@claude-plugins-official` (needs `dotnet tool install --global csharp-ls`); `/plugin marketplace add dotnet/skills`, then `/plugin install dotnet-test@dotnet-agent-skills` and others from that marketplace as needed (dotnet-data, dotnet-aspnetcore, dotnet-upgrade, dotnet-diag).
- TypeScript: `/plugin install typescript-lsp@claude-plugins-official` (needs `npm install --global typescript-language-server typescript`).
- Python: `/plugin install pyright-lsp@claude-plugins-official`. PHP: `/plugin install php-lsp@claude-plugins-official`.
- Browser checks: `npm install --global @playwright/cli`, then `playwright-cli install --skills`.
- Frontend, for a new product without a design system or a redesign the user wants: `/plugin install frontend-design@claude-plugins-official`. In an app with a design system the frontend agent keeps to its tokens and components.
- Optional, costs extra usage: `/plugin install security-guidance@claude-plugins-official`.
For `.mcp.json`: keep `angular-cli` only in Angular repositories. On macOS or Linux replace `"command": "cmd", "args": ["/c", "npx", ...]` with `"command": "npx", "args": [...]`.

## 8. Usage and security settings
- The project settings start sessions on Sonnet (`"model": "sonnet"`) and show a status line with context and plan usage. Explain both in one line each.
- Recommend turning on GitHub secret scanning with push protection, Dependabot alerts and branch protection on the default branch (the devops agent can prepare a checklist).
- If the repository is a phased project, check that `docs/project/` exists or suggest `/kickoff`.

## 9. Git hygiene
Make sure `.gitignore` contains `.claude/settings.local.json`, `CLAUDE.local.md` and `.claude/agent-memory-local/`. Commit the setup on a `chore/dev-team-setup` branch after the user approves, with the baseline fixes from step 5 as a separate commit. Recommend merging that branch before the first feature branch starts. In a repository without commits, commit the setup directly as the first commit on the default branch (`chore: add dev team setup`).

## 10. Summary
A checklist of what was done, the baseline result (green, or what is still red and why), what the user still has to do (installs, plugins, IT approvals), and how to start: say what you want or `continue` (the `start` skill guides from there), or type `/dev <request>`; `/deps security only` comes first when step 5 found a vulnerable package.
