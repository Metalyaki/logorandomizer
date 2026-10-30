---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
---

# Python and AI apps

## Python
- Dependencies and virtual environments with `uv` (or the tool the repo already uses). Pin versions in the lockfile.
- Format and lint with `ruff`; type hints everywhere and a type checker (mypy or pyright) in the checks.
- Validate external data with Pydantic models. Settings from environment variables through `pydantic-settings`, never hard coded.
- FastAPI: dependencies for auth and database sessions, response models for every endpoint, async endpoints only when the work is async.
- HTTP calls with explicit timeouts (`httpx` with `timeout=`), retries with backoff for idempotent calls only.
- Logging with the `logging` module, not `print`. No bare `except:`; catch specific exceptions and keep the cause.
- Tests with pytest and fixtures; no network in unit tests.

## AI and LLM features
- API keys only from the environment or a secret store. Never in code, notebooks, logs or test fixtures.
- Look up current model ids, parameters and SDK usage in the provider's documentation (docs.claude.com for Claude) instead of memory.
- Treat everything that reaches the model from users, documents, web pages or tools as untrusted: it can contain instructions (prompt injection). Keep system instructions separate and never let model output decide authorization.
- Validate model output before using it: parse structured output against a schema, never execute it as code, SQL or shell, and escape it before rendering as HTML.
- Give tools the least power they need, with confirmation for actions that change data or cost money.
- Set `max_tokens`, timeouts and retry limits; log token usage and cost per request; protect endpoints with rate limits.
- Keep personal data out of prompts unless the feature needs it, and out of logs always.
- Keep prompts in versioned files and add evaluation cases for important prompts, so changes can be tested.
