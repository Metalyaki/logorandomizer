# Review guidelines

Used by Claude Code Review on pull requests (Team and Enterprise plans) and by the reviewer agents. Report only what you have verified in the code, with `file:line` and a concrete fix. Skip anything a formatter or linter catches.

## Always flag
- Endpoints without explicit authorization, and ids from the client used without an ownership check.
- SQL built from strings (`FromSqlRaw` or `ExecuteSqlRaw` with interpolation, `$wpdb` without `prepare`), command execution or file paths built from user input.
- `bypassSecurityTrust*`, `innerHTML`, `dangerouslySetInnerHTML` or unescaped WordPress output with user data.
- Secrets, tokens, connection strings with passwords, or personal data in code, config, tests or logs.
- Edits to EF Core migrations that were already merged, and new migrations that drop or rename columns without a data plan.
- Async misuse: `.Result`, `.Wait()`, `async void`, missing `await`, missing `CancellationToken` on I/O.
- Acceptance criteria from the linked spec in `docs/specs` that are not implemented or not tested.
- Tests that were weakened, skipped or deleted, and new logic without tests.
- New dependencies, and GitHub Actions that are not pinned to a commit SHA or that widen `permissions`.

## Severity
- **Blocking**: wrong behavior, security hole, data loss, broken build or tests, missing acceptance criterion.
- **Should fix**: a likely bug under realistic conditions, missing tests for risky logic.
- **Nit**: at most three per review, and only when they improve clarity.

## Ignore
- Formatting, import order and naming style that the formatters handle.
- Generated files: `**/Migrations/*.Designer.cs`, `*ModelSnapshot.cs`, lockfiles, `dist`, `bin`, `obj`.
- Changes in `docs/specs` and `docs/adr` beyond checking that they match the code.
