---
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/*.props"
  - "**/*.targets"
  - "**/*.slnx"
  - "**/*.sln"
  - "**/appsettings*.json"
  - "**/Program.cs"
---

# C# and ASP.NET Core (.NET 10, C# 14)

Follow what the repository already does first; these rules fill the gaps. Check the TargetFramework and use only features it supports.

## Language
- Nullable reference types on; treat warnings as errors where the repo does. No `!` to silence a warning without a comment.
- File scoped namespaces, `var` when the type is obvious, records for DTOs and value objects, `required` members for mandatory properties, primary constructors for simple dependency injection, collection expressions, pattern matching.
- C# 14 adds the `field` keyword for property backing fields, extension members and null conditional assignment (`a?.B = c`). Use them where they make code clearer, not everywhere.

## Async and time
- Async all the way: no `.Result`, `.Wait()` or `async void` (except event handlers). Pass `CancellationToken` through every I/O call.
- Use `TimeProvider` (inject it) instead of `DateTime.Now` or `DateTimeOffset.UtcNow`, so tests can use `FakeTimeProvider`. Store times as UTC `DateTimeOffset`.

## Web APIs
- Follow the existing style (controllers or minimal APIs). In minimal APIs return `TypedResults` and group endpoints with `MapGroup`.
- Authorization: a fallback policy that requires an authenticated user, a named policy per endpoint group, and resource based authorization for ownership checks. `AllowAnonymous` only with a reason.
- Validation at the boundary: .NET 10 minimal APIs have built in validation (`builder.Services.AddValidation()` with data annotations); otherwise use the validator the repo already uses.
- Errors: `AddProblemDetails()` and ProblemDetails responses; never return exception messages or stack traces to clients.
- OpenAPI: the built in `AddOpenApi()` and `MapOpenApi()` (OpenAPI 3.1 by default in .NET 10).
- Outbound HTTP through `IHttpClientFactory` with typed clients and a resilience handler (`AddStandardResilienceHandler`), with timeouts.
- Rate limiting (`AddRateLimiter`) on login, password reset and expensive public endpoints.
- Caching with `HybridCache` when caching is needed.

## Configuration and secrets
- Options pattern with validation: `AddOptions<T>().BindConfiguration(...).ValidateDataAnnotations().ValidateOnStart()`.
- Local secrets in `dotnet user-secrets`, production secrets in Key Vault through `DefaultAzureCredential` and managed identity. Never secrets in `appsettings*.json`.

## Logging and diagnostics
- Structured logging with message templates (`logger.LogInformation("Order {OrderId} paid", id)`), never string interpolation in log calls; `LoggerMessage` source generators on hot paths.
- No personal data, tokens or secrets in logs. Health checks for dependencies (`AddHealthChecks`).

## Dependencies
- Central package management (`Directory.Packages.props`) when the repo has it. Ask before adding a package.
