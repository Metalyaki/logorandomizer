# Check and formatter profiles for .claude/team.json

Copy the entries that match the repository into `quality.checks` and `format`, then fix paths. Every check needs a unique `name`. Fields: `when` (globs of changed files that trigger the check), `run` (one command), `cwd` (folder, default the project root), `on` (any of `stop`, `subagent`, `verify`, `ship`), `agents` (which subagents run it on `subagent`), `requires` (skip when this tool is missing), `failOn` (regex on the output that means failure even with exit code 0), `enabled`.

## .NET with one solution at the root
The default `team.json` already contains `dotnet-build`, `dotnet-test`, `dotnet-format` and `dotnet-vulnerable`. With several solutions or projects at the root, name the solution:
```json
{ "name": "dotnet-build", "when": ["**/*.cs", "**/*.csproj", "**/*.props", "**/*.slnx"], "run": "dotnet build MyApp.slnx --nologo -v q", "on": ["stop", "subagent", "verify", "ship"], "agents": ["backend", "debugger"], "requires": "dotnet" }
```
When `global.json` opts into Microsoft.Testing.Platform, keep `dotnet test --no-build`; it works in both modes.

## Angular app in a subfolder
The default `team.json` assumes `src/web`. Change `when` and `cwd` together:
```json
{ "name": "web-build", "when": ["client/**"], "run": "npm run build -- --configuration development", "cwd": "client", "on": ["stop", "subagent", "verify"], "agents": ["frontend", "debugger"], "requires": "npm" }
```

## Next.js or React with Vite
```json
{ "name": "web-typecheck", "when": ["**/*.{ts,tsx}"], "run": "npx tsc --noEmit", "on": ["stop", "subagent", "verify"], "agents": ["frontend", "debugger"], "requires": "npx" },
{ "name": "web-test", "when": ["**/*.{ts,tsx,js,jsx}"], "run": "npm test -- --run", "on": ["stop", "verify", "ship"], "requires": "npm" },
{ "name": "web-lint", "when": ["**/*.{ts,tsx,js,jsx}"], "run": "npm run lint", "on": ["verify", "ship"], "requires": "npm" },
{ "name": "web-build", "when": ["**/*.{ts,tsx,js,jsx,css}", "next.config.*", "package.json"], "run": "npm run build", "on": ["ship"], "requires": "npm" }
```
Use `npm test -- --run` for Vitest; for Jest use `npm test -- --watchAll=false`.

## Node API
```json
{ "name": "node-test", "when": ["src/**", "test/**", "package.json"], "run": "npm test", "on": ["stop", "verify", "ship"], "requires": "npm" },
{ "name": "node-typecheck", "when": ["**/*.ts"], "run": "npx tsc --noEmit", "on": ["stop", "subagent", "verify"], "agents": ["backend", "debugger"], "requires": "npx" }
```

## Python (uv, pytest, ruff, mypy)
```json
{ "name": "py-lint", "when": ["**/*.py", "pyproject.toml"], "run": "uv run ruff check .", "on": ["stop", "subagent", "verify", "ship"], "agents": ["backend", "debugger"], "requires": "uv" },
{ "name": "py-types", "when": ["**/*.py"], "run": "uv run mypy .", "on": ["verify", "ship"], "requires": "uv" },
{ "name": "py-test", "when": ["**/*.py", "pyproject.toml"], "run": "uv run pytest -q", "on": ["stop", "verify", "ship"], "requires": "uv" },
{ "name": "py-audit", "when": ["pyproject.toml", "uv.lock", "requirements*.txt"], "run": "uvx pip-audit", "on": ["ship"], "requires": "uvx" }
```
Formatter: `{ "when": ["**/*.py"], "run": "ruff format --quiet {file}", "requires": "ruff" }` (in the default list).

## WordPress theme or plugin
```json
{ "name": "php-lint", "when": ["**/*.php"], "run": "php vendor/bin/phpcs -q --report=summary", "on": ["stop", "subagent", "verify", "ship"], "agents": ["backend", "frontend", "debugger"], "requires": "php" },
{ "name": "php-test", "when": ["**/*.php", "phpunit.xml*"], "run": "php vendor/bin/phpunit", "on": ["stop", "verify", "ship"], "requires": "php" },
{ "name": "composer-audit", "when": ["composer.json", "composer.lock"], "run": "composer audit", "on": ["ship"], "requires": "composer" },
{ "name": "wp-blocks-build", "when": ["src/**/*.js", "src/**/*.scss", "block.json"], "run": "npm run build", "on": ["verify", "ship"], "requires": "npm" }
```
Turn on the `phpcbf` formatter entry in `format` when `vendor/bin/phpcbf` exists. For local WordPress, prefer `wp-env` (Docker) over a shared server.

## Infrastructure
```json
{ "name": "bicep-build", "when": ["**/*.bicep", "**/*.bicepparam"], "run": "az bicep build --file infra/main.bicep --stdout", "on": ["stop", "subagent", "verify", "ship"], "agents": ["devops"], "requires": "az" },
{ "name": "terraform-validate", "when": ["**/*.tf"], "run": "terraform validate", "cwd": "infra", "on": ["stop", "subagent", "verify", "ship"], "agents": ["devops"], "requires": "terraform" },
{ "name": "docker-build", "when": ["**/Dockerfile*", ".dockerignore"], "run": "docker build -q -t local/check .", "on": ["ship"], "requires": "docker" }
```
The default `team.json` already contains `actionlint` for workflows (skipped when actionlint is not installed: `winget install rhysd.actionlint`).

## Scopes to review per repository
- `scopes.tester`: add the repository's real test folder names when they differ (for example `src/web/src/**/*.spec.ts` is covered, a folder named `IntegrationTests` without a dot is covered by `**/*Tests/**`).
- `scopes.devops`: add folders that hold pipeline or infrastructure code.
- `protect.generated`: remove `**/dist/**` when the repository commits built files on purpose (some WordPress themes do).
