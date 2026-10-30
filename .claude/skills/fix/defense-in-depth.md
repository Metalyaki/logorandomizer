# Defense in depth

Read this after you have named the root cause of a bug that came from invalid data (an empty id, a wrong path, a value out of range, a null that should never be null), to decide whether one fix at the source is enough.

**Core idea:** a single check in one place can be bypassed by another code path, a refactor or a mock. A check at every layer the data passes through makes the bug structurally impossible instead of merely fixed.

## When to add layers in the same fix
The fix stays minimal and at the source. Add more layers in the same change only when the bug could:
- lose or corrupt data,
- cross a security, ownership or tenant boundary,
- act outside the app (files, databases, payments, email, external APIs).

Otherwise name the layers you would add under "what would have caught this earlier" in your report, and the lead decides.

## The four layers
1. **Entry: reject bad input at the boundary.** Request validation (data annotations, FluentValidation or an endpoint filter). Angular validators improve the form but never replace server validation.
2. **Domain: refuse invalid state.** Guards in constructors and methods, or a value object that cannot hold an invalid value.

   ```csharp
   public Booking(CustomerId customer, DateOnly day, int guests)
   {
       ArgumentOutOfRangeException.ThrowIfNegativeOrZero(guests);
       // ...
   }
   ```

3. **Environment: refuse dangerous operations in the wrong context.** Test setup that refuses a database that is not local or a test container, seeding that runs only in Development, a job that refuses production without an explicit flag.
4. **Instrumentation: leave evidence.** A structured log line with the relevant ids at the risky operation, so the next failure explains itself. No secrets or personal data in it.

## Apply it
1. Trace the data flow (see `root-cause-tracing.md`): where the bad value starts and every point it passes.
2. Pick the layers that apply. Not every bug needs all four.
3. Test each layer by bypassing the one before it: call the domain method directly with the bad value and check that it refuses, not only the endpoint.

---
Adapted from obra/superpowers, `skills/systematic-debugging/defense-in-depth.md` (MIT License, Copyright (c) 2025 Jesse Vincent). See `.claude/NOTICES.md`.
