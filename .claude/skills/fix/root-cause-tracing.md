# Root cause tracing

Read this when an error shows up deep in the call stack, when a bad value arrives and you cannot see where it came from, or when something breaks during a test run and you do not know which test causes it.

**Core rule:** trace backwards through the call chain until you find where the bad value was created, and fix it there. Where the error appears is usually only where the bad value finally did damage.

## The trace
1. **Symptom.** Write down exactly what failed and where.
2. **Immediate cause.** The line that throws or misbehaves, and the value that made it fail.
3. **Who called it, with what.** Walk up the stack one frame at a time and note the value passed in at each frame.
4. **Keep going until the value is created**, not just passed along: a default, a mapping, a query, a configuration binding, a test setup that runs in the wrong order.
5. **Original trigger.** That is where the fix goes. Check whether other callers can reach the same trigger.

Example:
- **Symptom:** the confirmation email shows a total of 0.
- **Immediate cause:** `EmailBuilder` sums `order.Lines`, which is empty.
- **Called by** `OrderConfirmedHandler`, which got the order from `OrderRepository.GetAsync(id)`.
- **Created in** `GetAsync`: `FindAsync(id)` loads the order without its lines, and lazy loading is off.
- **Fix** the query (`Include(o => o.Lines)` or a projection). An empty check in `EmailBuilder` would only hide the bug, and every other caller of `GetAsync` would still get an order without lines.

## When reading is not enough, instrument
Log **before** the suspicious operation, not after it fails, with the inputs, the context and the stack. Mark the line so it is easy to find, and remove it before you commit.

```csharp
// DEBUG(temp): remove before commit
Console.Error.WriteLine($"DEBUG GetAsync id={id} lines={order.Lines.Count}{Environment.NewLine}{Environment.StackTrace}");
```

```ts
// DEBUG(temp): remove before commit
console.error('DEBUG total', { orderId, lines: order.lines.length, stack: new Error().stack });
```

- Use the plainest output channel. A logger may be filtered by level or category. In tests write to the test output (xUnit `ITestOutputHelper`, NUnit `TestContext.Out`, MSTest `TestContext.WriteLine`). If the runner still hides it, append to a file in the temp folder and read that.
- Include what can differ between runs: ids, the current directory, the environment name, the culture, the time.
- Then read the stacks: which test or caller, which line, and what the failing cases have in common.

## Which test causes it?
When something appears or breaks only in the full test run:
- Suspect shared state first: static fields and caches, a shared database or container, the clock, the current culture, environment variables, files at a fixed path, test order.
- Bisect: run half of the tests, then half of that half, until one test (or one pair) reproduces it.
  - .NET: `dotnet test --list-tests` shows the names. `dotnet test --filter "FullyQualifiedName~Bookings"` runs a subset on VSTest; on Microsoft.Testing.Platform use the framework's own filter options (xUnit v3: `--filter-namespace`, `--filter-class`).
  - Vitest: run one file with `npx vitest run <file>`; `--sequence.shuffle` exposes order dependence.
- When it used to work, `git bisect run <test command>` finds the commit that broke it.

## Rules
- Do not fix only where the error appears while you can still trace one level further up.
- If the trace dead ends (third party code, no symbols), say so in the report, fix at the last point you control, and comment why.
- After the fix at the source, read `defense-in-depth.md` next to this file to decide whether more layers are warranted.

---
Adapted from obra/superpowers, `skills/systematic-debugging/root-cause-tracing.md` (MIT License, Copyright (c) 2025 Jesse Vincent). See `.claude/NOTICES.md`.
