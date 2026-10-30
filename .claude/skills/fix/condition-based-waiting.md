# Condition based waiting

Read this when a test is flaky, passes alone but fails in the suite or in CI, times out under load, or contains `Thread.Sleep`, `Task.Delay`, `setTimeout`, `page.waitForTimeout` or a retry loop with a fixed wait.

**Core rule:** wait for the condition you care about, not for a guess about how long it takes. A fixed delay is a race: too short on a busy CI machine, wasted time everywhere else.

## Pick the pattern
| Situation | Do this |
| --- | --- |
| The code depends on time (expiry, schedules, retries, timeouts) | .NET: inject `TimeProvider`, use `FakeTimeProvider` and `Advance(...)`. Vitest: `vi.useFakeTimers()` and `await vi.advanceTimersByTimeAsync(ms)`. |
| You hold the task or promise | Await it. Never `.Result`, `.Wait()` or a sleep before reading the result. |
| Background work can signal completion (hosted service, channel, event) | Let the test double complete a `TaskCompletionSource` and await it with a timeout (`WaitAsync(TimeSpan)`). |
| Only the outcome is observable (a row in the database, a file, a message) | Poll with a timeout and a clear message (helper below). |
| Angular component test | `await fixture.whenStable()` after the change. In zoneless apps `fakeAsync` and `tick` do not apply; use Vitest fake timers. For HTTP, `HttpTestingController` with `expectOne(...)` and `flush(...)` is synchronous, so nothing to wait for. |
| Playwright | Web first assertions retry by themselves: `await expect(page.getByRole('alert')).toHaveText('Saved')`. For a value, `await expect.poll(() => countBookings()).toBe(3)`. For a request, start `page.waitForResponse(...)` before the click and await it after. |
| Anything else async in Vitest | `await vi.waitFor(() => expect(store.items()).toHaveLength(5), { timeout: 2000 })` |

## Polling helper (.NET)
```csharp
static async Task<T> WaitForAsync<T>(Func<Task<T?>> probe, string what, TimeSpan? timeout = null) where T : class
{
    var limit = timeout ?? TimeSpan.FromSeconds(5);
    var deadline = DateTime.UtcNow + limit;
    while (true)
    {
        var result = await probe();      // fresh state on every attempt
        if (result is not null) return result;
        if (DateTime.UtcNow > deadline)
            throw new TimeoutException($"Timed out after {limit.TotalSeconds} s waiting for {what}.");
        await Task.Delay(20);            // poll interval, not a guess about timing
    }
}

// var booking = await WaitForAsync(
//     () => db.Bookings.AsNoTracking().SingleOrDefaultAsync(b => b.Reference == reference),
//     "the booking row");
```

## Common mistakes
- **Polling every millisecond:** burns CPU and starves the code under test. 10 to 50 ms is enough.
- **No timeout:** the test hangs instead of failing with a message that says what it waited for.
- **Stale data:** reading state once before the loop, or reading a tracked EF Core entity. Read fresh inside the loop.
- **`waitForTimeout` "to be safe" in Playwright:** remove it and assert on what the user would see.

## When a fixed delay is right
Only when the test is about timing itself (debounce, throttle, backoff). First wait for the triggering condition, base the delay on the known interval, and comment why. Fake timers are still better than real time.

```ts
search.set('tub');                        // first: the trigger
await vi.advanceTimersByTimeAsync(300);   // the debounce is 300 ms by design
expect(api.search).toHaveBeenCalledOnce();
```

---
Adapted from obra/superpowers, `skills/systematic-debugging/condition-based-waiting.md` (MIT License, Copyright (c) 2025 Jesse Vincent). See `.claude/NOTICES.md`.
