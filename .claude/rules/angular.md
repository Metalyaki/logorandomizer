---
paths:
  - "**/angular.json"
  - "**/*.component.ts"
  - "**/*.component.html"
  - "**/*.component.scss"
  - "**/*.service.ts"
  - "**/*.routes.ts"
  - "**/app.config.ts"
  - "src/web/**"
---

# Angular (21 and 22)

Check the Angular version in `package.json` first. Use the Angular CLI MCP tools when available (`get_best_practices`, `search_documentation`, `find_examples`) instead of relying on memory, and `onpush_zoneless_migration` or `modernize` for migrations.

## Components
- Standalone components (the default; do not add `standalone: true`). Small components with one job.
- `ChangeDetectionStrategy.OnPush` everywhere. Angular 22 makes OnPush the default for new apps and renames the old default to `ChangeDetectionStrategy.Eager`.
- Signal APIs: `input()`, `input.required()`, `output()`, `model()`, `viewChild()`, `contentChild()`. Not the decorator versions in new code.
- `inject()` instead of constructor parameters in new code.
- Host bindings in the `host` object of the decorator, not `@HostBinding` and `@HostListener`.
- Built in control flow: `@if`, `@for` (always with a meaningful `track`), `@switch`, `@defer` for heavy content below the fold. Not `*ngIf` or `*ngFor` in new code.
- `class` and `style` bindings instead of `ngClass` and `ngStyle`. `NgOptimizedImage` for images.

## State and data
- Signals for local and shared state: `signal`, `computed`, `linkedSignal`. Use `effect` only for side effects that leave Angular (storage, logging), never to sync state.
- Zoneless: new apps since Angular 21 have no zone.js. Do not rely on zone triggered change detection; signals and the async pipe update the view.
- HTTP through typed services. `resource()` and `httpResource()` are stable in Angular 22 for reading data into signals; in Angular 21 they are experimental, so follow the repo. Use RxJS where streams fit, bridged with `toSignal`, and clean up with `takeUntilDestroyed`.
- Functional interceptors and guards (`HttpInterceptorFn`, `CanActivateFn`), `provideHttpClient(withInterceptors([...]))`.
- Lazy load routes with `loadComponent` and `loadChildren`.

## Forms
- Signal Forms are stable in Angular 22 and experimental in 21. In 21 and in existing code, keep strictly typed reactive forms. Never untyped forms.

## Security and accessibility
- Never `bypassSecurityTrust*` or `[innerHTML]` with user data. Rely on Angular's built in sanitizing.
- Guard authenticated and role restricted routes with functional guards, and use `canMatch` for lazy loaded areas so users without access never download that code. Guards are only UX: the API enforces authorization on every request.
- Treat API responses as untrusted input: type them as the API contract says, never render them as HTML, and never pass them to `window.location`, `window.open` or `router.navigateByUrl` without checking them against an allow list (open redirect). A role flag from the API only shapes the UI.
- The Content Security Policy is set by the server or host, without `unsafe-inline` in `script-src`. Angular adds inline styles; give them a nonce that the server generates for every response, through `ngCspNonce` on the root element or the `CSP_NONCE` token. Check the current CSP options with the Angular CLI MCP `search_documentation` before configuring it.
- Labels for every control, keyboard support, visible focus, semantic HTML first. Angular Aria (`@angular/aria`) provides accessible headless patterns; it is stable in 22.

## Tests
- Vitest is the default runner since Angular 21 (`ng test`); Karma still works in existing projects; Jest and Web Test Runner support is gone in 22.
- Test components through their public behavior (inputs, rendered DOM, outputs), not private methods.
