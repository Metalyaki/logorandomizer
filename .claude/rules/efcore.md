---
paths:
  - "**/Migrations/**"
  - "**/*DbContext*.cs"
  - "**/*Configuration.cs"
  - "**/Persistence/**"
  - "**/Infrastructure/**/*.cs"
  - "**/Data/**/*.cs"
---

# EF Core (10) and SQL Server

## Queries
- Read only queries use `AsNoTracking()` and project to DTOs with `Select`, so only the needed columns are loaded.
- Avoid N+1: load related data with projection or `Include`; use `AsSplitQuery()` when several collections would explode the row count.
- Every list endpoint is paginated with a stable `OrderBy`.
- Bulk changes with `ExecuteUpdateAsync` and `ExecuteDeleteAsync` instead of loading entities in a loop.
- Raw SQL only through `FromSql` or `SqlQuery` with interpolated parameters (they become parameters). Never `FromSqlRaw` or `ExecuteSqlRaw` with string concatenation or interpolation of user input.
- EF Core 10 has `LeftJoin` and `RightJoin` LINQ operators and named query filters (several filters per entity that can be switched off one by one); use them instead of workarounds.
- New query predicates need an index; add it in the entity configuration.

## Model
- Configuration in `IEntityTypeConfiguration<T>` classes, not attributes scattered over entities, unless the repo does otherwise.
- Concurrency tokens (`rowversion`) on entities edited by several users.
- Explicit lengths and precision for strings and decimals.
- Owned types or complex types for value objects.

## Migrations
- Create with `dotnet ef migrations add <PascalCaseName>` and read the generated code before committing: renames often come out as drop plus add, which loses data. Fix them with `RenameColumn` or a custom SQL step.
- Never edit a migration that is committed (a hook asks first); add a new one.
- Separate schema changes from data backfills; make backfills idempotent and safe to rerun.
- Large tables: think about locks and long running index builds; mention it in the plan.
- `dotnet ef migrations has-pending-model-changes` must report no changes before shipping.
- Production schema changes are deployed by the pipeline with an idempotent script (`dotnet ef migrations script --idempotent`) or a migration bundle, never with `dotnet ef database update` from a laptop.

## Tests
- Integration tests run against real SQL Server (Testcontainers when Docker is available), not the in memory provider, for anything that depends on SQL behavior.
