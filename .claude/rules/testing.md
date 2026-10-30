---
paths:
  - "**/tests/**"
  - "**/test/**"
  - "**/*Tests/**"
  - "**/*.Tests/**"
  - "**/*.spec.ts"
  - "**/*.test.ts"
  - "**/*.spec.tsx"
  - "**/*.test.tsx"
  - "**/e2e/**"
  - "**/test_*.py"
  - "**/*_test.py"
---

# Tests

## General
- One behavior per test, Arrange Act Assert, names that read as a sentence about behavior (`Booking_is_rejected_when_slot_is_taken`).
- Deterministic: no real network, no sleeps, no dependency on test order, the clock or random values. Inject `TimeProvider` and use `FakeTimeProvider` in .NET; fake timers in JavaScript. To fix a flaky test or a test that waits, follow `.claude/skills/fix/condition-based-waiting.md`.
- Mock only at the edges of the system (HTTP, email, payment, clock). Inside the system use the real classes.
- Assert on outcomes the user or caller can see, not on internal calls.
- A test that fails because of a real bug stays in place until the bug is fixed. Never weaken, skip or delete a test to get green.
- Test data: builders or factories with sensible defaults; only the values that matter for the test are visible in it.

## .NET
- Follow the repo's framework (xUnit, NUnit or MSTest). xUnit v3 and Microsoft.Testing.Platform are the current direction on .NET 10.
- Integration tests through the real HTTP pipeline with `WebApplicationFactory<Program>`; replace authentication with a test scheme and cover anonymous, wrong user, wrong role and right role.
- SQL Server behavior is tested against real SQL Server (Testcontainers when Docker is available), not the in memory provider.

## Frontend
- Angular: Vitest through `ng test` (the default since Angular 21), TestBed with the component's real template; query the DOM by role and text.
- React: Testing Library with user events; query by role, label and text.
- End to end: Playwright with role based locators (`getByRole`, `getByLabel`), web first assertions (`expect(locator).toBeVisible()`), no fixed waits, and each test sets up its own data.

## Python
- pytest with fixtures and `tmp_path`; `respx` or `pytest-httpx` for HTTP.
