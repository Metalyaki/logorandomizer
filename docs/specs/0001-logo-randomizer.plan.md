# Plan 0001: Logo randomizer

Spec: docs/specs/0001-logo-randomizer.md   ·   Branch: feature/0001-logo-randomizer   ·   Status: approved
Approved: sha256:c645ca5294d9c997 on 2026-11-01

## Approach
A single page Angular 21 app (standalone, zoneless, OnPush, signals, no router) in `src/web`, served as static files from Azure Static Web Apps (SWA). All logic is pure TypeScript functions in `src/web/src/app/logo/`: a seedable PRNG, a generator that turns a seed into a plain `Logo` data object (background, shapes, colors, name), a capped history, an SVG string builder and a filename sanitizer. One root-provided signal store (`LogoStore`) holds the current logo and the history. The page renders the `Logo` object through an Angular template with attribute bindings only (never `innerHTML`); the download builds a separate standalone SVG string from the same `Logo` object, puts it in a `Blob` and clicks a temporary `<a download>` link. A parity test keeps the two renderings in step. Security headers and the CSP live in `src/web/public/staticwebapp.config.json`; a small local Node server (test only) serves the production build with exactly those headers, so the end to end tests run under the real CSP. This is the simplest design: no backend, no new runtime packages, no state library, no router, no animation library.

## Changes by area
- **Domain**: none on the server. Client-side model in `src/web/src/app/logo/logo.model.ts`:
  - `Logo { name: string; background: string; shapes: Shape[]; plate: string; textColor: string; fontSize: number }`, fixed `VIEW_BOX = '0 0 512 512'`.
  - `Shape` is a discriminated union: `circle` (cx, cy, r, fill), `rect` (x, y, width, height, rx, fill, rotate), `polygon` (points, fill). Numbers only, colors as `#rrggbb` hex. No seed is stored in the model (AC6: seeds are never shown or stored).
  - Rules: at least 3 distinct fill colors (AC4); name text sits on a solid `plate` rect and `textColor` is black or white, picked so contrast to `plate` is at least 4.5:1 (spec edge case); `fontSize` derived from name length so 25 characters fit the plate.
  - `logoKey(logo)` = `JSON.stringify(logo)`, used for equality (AC5, AC10).
  - `isValidLogo(logo)` checks the invariants above (spec edge case "generator returns an invalid result").
- **Data**: none. No database, no browser storage (AC22).
- **API**: none. No endpoints.
- **Web** (`src/web/src/app/`):
  - `logo/random.ts`: `createRng(seed: number): () => number` (mulberry32 or similar 32 bit generator); `SEED_SOURCE` injection token, default `() => Math.floor(Math.random() * 2 ** 32)`. Non-cryptographic by design (spec).
  - `logo/color.ts`: hex/HSL conversion, relative luminance, `contrastRatio(a, b)`, `pickTextColor(bg)`.
  - `logo/words.ts`: `export const WORDS: readonly string[]` (at least 50 capitalized English words, written by the developer). A TS module, so it is bundled and never fetched (AC9).
  - `logo/name.ts`: `generateName(rng): string` (2 words, one space).
  - `logo/logo-generator.ts`: `generateLogo(seed: number): Logo`; `isValidLogo`.
  - `logo/logo-history.ts`: pure immutable functions `push(history, logo, cap = 20)`, `back(history)`; type `History = { current: Logo; past: readonly Logo[] }`.
  - `logo/svg-export.ts`: `toSvgString(logo): string` (root `<svg xmlns="http://www.w3.org/2000/svg" viewBox=...>`, same elements as the template, XML-escaped text and attribute values as defense in depth); `toFileName(name): string` (AC15 rules).
  - `logo/svg-download.ts`: `SvgDownload` service, `download(logo)`: `Blob([svg], { type: 'image/svg+xml' })`, `URL.createObjectURL`, temporary anchor with `download` attribute appended to `document.body`, `click()`, removed, URL revoked in a `setTimeout(0)`. Wrapped in try/catch; failure leaves the page working (spec edge case). Uses `inject(DOCUMENT)`.
  - `logo/logo-store.ts`: `LogoStore` (`providedIn: 'root'`): `history = signal<History>`, `current = computed`, `canGoBack = computed`, `randomize()` (regenerates up to 5 times when `logoKey` equals the current one, AC5; keeps the current logo when the result is invalid or the generator throws), `previous()`.
  - `logo/logo-svg.ts` (+ `.html`): `LogoSvg` component, `logo = input.required<Logo>()`, renders `<svg role="img" [attr.aria-label]="'Logo: ' + name" viewBox="0 0 512 512">` with `@for` (track `$index`) and `@switch` over shape kinds, `[attr.*]` bindings only, `<text>` with `font-family="system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"`.
  - `app.ts` / `app.html` (root, created by the CLI): the three native `<button>` elements, the `LogoSvg`, and a visually hidden `<p aria-live="polite">Logo: {{ name }}</p>` live region present from first render. Focus rule: after `previous()`, if `canGoBack()` is false, focus Randomize via `viewChild`.
  - `src/web/src/styles.css`: all styles global (no component styles, see CSP decision), layout from 320 px to 1920 px, visible `:focus-visible` outline, button colors with at least 4.5:1 contrast, `.visually-hidden`, `noscript` message style. No animation or transition at all in v1, so AC21 holds by construction.
  - `src/web/src/index.html`: `lang="en"`, title, `<noscript>This app needs JavaScript</noscript>`, no external fonts or scripts, local SVG favicon.
- **Infra and config**:
  - `src/web/public/staticwebapp.config.json` with `globalHeaders`:
    - `Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`
    - `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`.
  - `angular.json`: production `optimization.styles.inlineCritical: false` (critical CSS inlining adds an inline `<style>` and an `onload` handler that the CSP blocks), initial budget tightened (see Risks), `outputHashing: all`.
  - `src/web/e2e/serve.mjs`: test-only static server on `127.0.0.1`, built on `node:http`, serves `dist/web/browser`, rejects path traversal, adds the headers read from `staticwebapp.config.json`.
  - `.github/workflows/web-ci.yml` (PR and push to main): `npm ci`, lint, unsafe-API grep, unit tests, build, `npm audit --audit-level=high`, Playwright e2e. `permissions: contents: read`, actions pinned by commit SHA.
  - `.github/workflows/web-deploy.yml` (push to main, GitHub environment `production` with required reviewer): builds and deploys `dist/web/browser` with `Azure/static-web-apps-deploy` (`skip_app_build: true`), then a header smoke check with `curl -sI` against the deployed URL.
  - Approved dev dependencies (2026-11-01), dev only, no new runtime packages beyond what the Angular 21 CLI generates: `vitest` and `jsdom` (unit tests, as generated by the CLI); `angular-eslint`, `eslint`, `typescript-eslint` (through `ng add angular-eslint`); `@playwright/test` (end-to-end tests); `@axe-core/playwright` (accessibility scan). Not approved: `@azure/static-web-apps-cli` or any static server package. Adding any other package needs the owner's OK.
  - Secret names: `AZURE_STATIC_WEB_APPS_API_TOKEN` (GitHub environment secret, `production`). Variable: `SWA_URL` (deployed URL for the smoke check, not secret).

## Threat model and security controls
Risk level: Low (spec, section Security and privacy). The CI and deploy workflows (S13, S14) are an infrastructure and CI change, which CLAUDE.md lists as a High trigger: those two steps get a security review and the reviewer on opus.

| Threat or requirement | Control | Plan step | Test |
| --- | --- | --- | --- |
| SR1 No user text anywhere; markup injection into the page | No inputs exist; SVG rendered by Angular template with `[attr.*]` bindings; no `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, `bypassSecurityTrust*` | S9, S10, S13 | CI step `unsafe-api-grep` fails on those tokens in `src/web/src`; reviewer check |
| SR2 Word list is trusted and well-formed (AC8, AC9) | Bundled TS module, validated by test; owner reviews for offensive or trademarked words before release | S3, S15 | `words.spec.ts`: every entry matches `^[A-Z][a-z]{1,11}$`, no duplicates, at least 50; e2e `privacy.spec.ts` no requests beyond own origin |
| SR3 Download filename cannot carry path or odd characters (AC15) | `toFileName` sanitizer, fallback `logo.svg` | S6 | `file-name.spec.ts`: "Bold Panda", empty, symbol-only, non-ASCII, `../../x`, over 40 characters, leading and trailing symbols |
| SR4 Downloaded SVG holds no active content (AC16) | String builder emits a fixed element set (`svg`, `rect`, `circle`, `polygon`, `text`, `g`); text and attributes XML-escaped | S6 | `svg-export.spec.ts`: 200 seeds parse with `DOMParser` (`image/svg+xml`) without `parsererror`; no `script`, `foreignObject`, `on*` attributes, `href`, `xlink:href`, `url(`; a hand-built logo named `<script>&"` is escaped |
| SR5 Memory bounded under button mashing (AC11) | History cap 20, oldest dropped | S5, S7 | `logo-history.spec.ts` cap test; `logo-store.spec.ts` 1000 presses keeps `past.length <= 20` |
| SR6 Restrictive CSP, no inline script, framing blocked | `staticwebapp.config.json` `globalHeaders`; `inlineCritical: false`; global styles only | S1, S11 | `config.spec.ts` (Playwright, Node only) asserts each directive; e2e `csp.spec.ts` sees zero `securitypolicyviolation` events and no CSP console errors while using all three buttons |
| SR7 MIME sniffing and referrer leaks | `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer` | S11, S14 | `config.spec.ts`; deploy smoke check `curl -sI` asserts both headers on the live site |
| SR8 HTTPS only | SWA serves HTTPS and redirects HTTP (platform default, confirmed by the S14 smoke check) | S14 | deploy smoke check: `http://` request answers with a redirect to `https://` |
| SR9 Privacy: no third-party requests, no storage, URL never changes (AC22) | No router, no fonts or CDNs, no analytics, no storage APIs used | S10, S12 | e2e `privacy.spec.ts`: all requests same origin; `document.cookie`, `localStorage`, `sessionStorage` empty; `indexedDB.databases()` empty where supported; `page.url()` unchanged |
| SR10 Download works under the CSP (AC18) | Same-origin `blob:` URL via anchor `download`; no `blob:` source needed in the CSP (to confirm in S12) | S8, S12 | e2e `download.spec.ts` runs against `serve.mjs` with the real headers in Chromium, Firefox and WebKit |
| SR11 Supply chain and CI permissions | Dev-only packages, `package-lock.json`, `npm ci`, `npm audit --audit-level=high`; actions pinned by SHA; `permissions: contents: read`; deploy token only in the `production` environment with a required reviewer | S1, S13, S14 | CI run green; security review of the workflow files |
| SR12 Predictable randomness | Accepted: nothing depends on it for security (spec) | S2 | none needed; decision logged |

Secrets: only `AZURE_STATIC_WEB_APPS_API_TOKEN`, a GitHub environment secret used by the deploy workflow. Nothing in the app or the repo. Personal data: none is processed, stored, sent or logged.

## API contract
None. The app has no endpoints.

## Test strategy
- **Unit (Vitest through `ng test`, jsdom)**: PRNG and color (S2), words and name (AC7, AC8, S3), generator (AC3 viewBox, AC4, AC6, text contrast, validity across 1000 seeds, S4), history (AC10, AC11, AC12, S5), SVG export and filename (AC14 content, AC15, AC16, S6), store (AC2, AC5 with a fixed seed sequence, invalid result and throwing generator keep the current logo, S7), download service (AC14 MIME, AC17 revoke and state unchanged, blocked download does not throw, S8, browser APIs spied at the edge).
- **Component (TestBed, real templates, query by role and text)**: `LogoSvg` (AC3 single inline `svg`, fixed `viewBox`, AC7 `<text>` and font stack, AC20 accessible name, parity with `toSvgString`, S9); `App` (AC1 states, AC2 no reload, AC10 same `outerHTML` after Previous, AC19 Enter and Space on native buttons and focus move to Randomize, AC20 live region text and `aria-live="polite"`, focus not moved, S10).
- **End to end (Playwright against `serve.mjs` with the production build and the real headers)**: AC13 reload, AC14 and AC15 download file name and content, AC17 state unchanged after download, AC18 download under CSP, AC21 no animation or transition under `reducedMotion: 'reduce'` (computed styles), AC22 network and storage, AC23 layout at 320x640 and 1920x1080 (no horizontal overflow, all four elements within the viewport width), SR6 no CSP violations.
- **Config**: `config.spec.ts` checks `staticwebapp.config.json` headers (S11).
- **Manual owner checks before release (S15)**: word list review, look and feel, name text fits on the plate on Windows, macOS and Linux fonts, AC18 and headers on the deployed site, performance budget (new logo within 100 ms in the DevTools Performance panel).
- Determinism: every unit test uses fixed seeds or a fake `SEED_SOURCE`; timers in S8 use Vitest fake timers.

## Steps
- [ ] S1 [frontend] Scaffold the Angular 21 workspace in `src/web` with the CLI (application name `web`, CSS, no SSR, no routing, zoneless default, Vitest default runner; check exact `ng new` flags with `ng new --help`). Add `npm` scripts `build`, `test`, `lint` (`ng add angular-eslint`), `e2e` (`playwright test`); install only the approved dev dependencies. Set `inlineCritical: false` and budgets in `angular.json`; clean `index.html` (lang, title, noscript, no external links); remove the CLI placeholder content; add `dist`, `node_modules`, `test-results`, `playwright-report` to `.gitignore`. Done when: `npm ci`, `npm run build`, `npm test -- --watch=false` and `npm run lint` pass in `src/web` with one smoke test of `App`.
- [ ] S2 [frontend] (TF) (parallel with S3, S5) PRNG and color utilities: `logo/random.ts`, `logo/color.ts` and specs. Done when: same seed gives the same sequence, values lie in [0, 1), `contrastRatio('#000000', '#ffffff')` is 21, `pickTextColor` reaches at least 4.5:1 for 1000 random backgrounds.
- [ ] S3 [frontend] (TF) (parallel with S2, S5) Word list and name: `logo/words.ts`, `logo/name.ts` and specs. Done when: `words.spec.ts` (AC8) and `name.spec.ts` (AC7 regex, both words from `WORDS`, same rng gives the same name) pass.
- [ ] S4 [frontend] (TF) Model and generator: `logo/logo.model.ts`, `logo/logo-generator.ts` and spec. Done when: for seeds 1 to 1000 every logo is valid, has at least 3 distinct fills (AC4), text contrast at least 4.5:1 and font size fits 25 characters; the same seed twice gives deep-equal logos (AC6); `isValidLogo` rejects broken logos.
- [ ] S5 [frontend] (TF) (parallel with S2, S3) History: `logo/logo-history.ts` and spec. Done when: tests for AC10 (back returns the earlier logo, the left one is dropped), AC11 (25 pushes leave 20 reachable, oldest dropped first, back on empty past is a no-op), AC12 (push after back keeps the logo that was current) pass.
- [ ] S6 [frontend] (TF) SVG export and filename: `logo/svg-export.ts` and specs `svg-export.spec.ts`, `file-name.spec.ts`. Done when: tests for AC14 (root `svg` with `xmlns`, same `viewBox`, all shapes, the name text), AC15 (all cases under SR3) and AC16 (all checks under SR4) pass.
- [ ] S7 [frontend] (TF) Store: `logo/logo-store.ts` and spec. Done when: tests pass for AC1 initial state (logo present, `canGoBack` false), AC2 randomize replaces the logo, AC5 (100 presses: no consecutive duplicates, at least 90 distinct, plus a fake seed source that repeats a seed still yields a different logo), AC10 to AC12 through the store, invalid or throwing generator keeps the current logo and does not throw, 1000 presses keep the cap.
- [ ] S8 [frontend] (TF) Download service: `logo/svg-download.ts` and spec. Done when: tests pass for Blob type `image/svg+xml` and content equal to `toSvgString`, anchor `download` equals `toFileName(name)`, anchor removed and URL revoked after the timer (AC17), store state unchanged, and a throwing `createObjectURL` or `click` is caught.
- [ ] S9 [frontend] (TF) `LogoSvg` component: `logo/logo-svg.ts`, `logo/logo-svg.html` and spec. Done when: tests pass for AC3 (one `svg`, `viewBox="0 0 512 512"`, `preserveAspectRatio` default, CSS width 100% and height auto), AC7 (`<text>` content and font stack), AC20 (`role="img"`, `aria-label="Logo: <name>"`), and parity: for 20 seeds the rendered element tags and attributes equal those of `toSvgString` parsed with `DOMParser` (Angular comment nodes ignored).
- [ ] S10 [frontend] (TF) App shell, styles and accessibility: `app.ts`, `app.html`, `styles.css`, `index.html` and `app.spec.ts`. Done when: tests pass for AC1, AC2, AC10 (same `outerHTML`), AC19 (Enter and Space on each button run the action, focus stays; focus moves to Randomize when Previous turns disabled), AC20 (live region text changes, `aria-live="polite"`, `document.activeElement` unchanged); Download calls `SvgDownload` with the current logo; no component `styles` or `styleUrl`; owner sees the page with `npm start`.
- [ ] S11 [devops] (parallel with S2 to S10) Security headers: `src/web/public/staticwebapp.config.json` and `src/web/e2e/config.spec.ts`. Done when: the config is copied into `dist/web/browser` by the build and `config.spec.ts` asserts every directive under SR6 and SR7, no `'unsafe-inline'` or `'unsafe-eval'` in `script-src`.
- [ ] S12 [frontend] End to end suite: `src/web/playwright.config.ts` (projects Chromium, Firefox, WebKit; `webServer` runs `node e2e/serve.mjs` on the built output), `src/web/e2e/serve.mjs`, specs `reload.spec.ts` (AC13), `download.spec.ts` (AC14, AC15, AC17, AC18 under CSP), `privacy.spec.ts` (AC22), `layout.spec.ts` (AC23), `motion.spec.ts` (AC21), `csp.spec.ts` (SR6, plus no console errors while using all buttons, AC3), `noscript.spec.ts` (context with JavaScript disabled shows "This app needs JavaScript"), and `a11y.spec.ts` (`@axe-core/playwright` scan with WCAG 2.2 AA tags, including button contrast, after load and after each button). Done when: `npm run e2e` passes on all three browsers locally and `serve.mjs` refuses `/../` paths.
- [ ] S13 [devops] (parallel with S2 to S12, after S1) CI: `.github/workflows/web-ci.yml` running lint, the unsafe-API grep, unit tests, build with budgets, `npm audit --audit-level=high`, and e2e (Playwright browsers installed in the job). Done when: the workflow passes on the feature branch PR, uses `permissions: contents: read` and SHA-pinned actions; security review has no open High findings.
- [ ] S14 [devops] Deploy (nothing deploys without the owner's explicit OK; needs the Azure resource and the token secret): `.github/workflows/web-deploy.yml` with the `production` environment and the header smoke check; `docs/deploy.md` with the one-time `az staticwebapp create` command (Free tier) the owner runs, and how to store the token as a `production` environment secret. Done when: a deploy from `main` succeeds after approval, the smoke check confirms CSP, `nosniff` and the HTTPS redirect, and the owner confirms AC18 on the live site.
- [ ] S15 [docs] `README.md` (what it is, run, test, e2e, deploy link), `CHANGELOG.md` entry, and an owner release checklist in `docs/deploy.md` (word list review, visual and font check, deployed AC18, performance). Done when: the docs agent's files are reviewed and the checklist is ticked by the owner.

## Risks
| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Angular injects `<style>` elements (component styles, CLI features) that `style-src 'self'` blocks, so the page renders unstyled | Medium | No component styles, `inlineCritical: false`; `csp.spec.ts` fails on any violation; if it cannot be met, stop and ask the owner before adding `'unsafe-inline'` to style-src |
| Template rendering and SVG string drift apart, so the download differs from the screen (AC14) | Medium | Parity test in S9 over many seeds |
| Revoking the object URL too early cancels the download in Firefox or Safari | Low | Revoke in `setTimeout(0)` after `click()` with the anchor attached; `download.spec.ts` on all three engines; if WebKit still fails, raise the delay and log the decision |
| Name text overflows its plate with wider system fonts | Medium | Font size from name length with a 0.65 em per character estimate and margin; owner visual check on three OSes |
| Angular budgets measure raw, not gzipped size, so the 200 kB gzipped rule is not checked directly (uncertain) | Low | Budget error at 500 kB raw initial as a proxy; the spec budget is checked by hand once in S15 |
| Angular 21 CLI flags, builder names and default file names (`app.ts` vs `app.component.ts`) recalled from memory | Medium | S1 checks with `ng new --help` and the Angular CLI MCP and follows what the CLI generates; deviations go in the decisions log |
| `indexedDB.databases()` missing in some engine, so AC22 cannot be checked there | Low | Check where supported; the app calls no storage API at all, and the unsafe-API grep can also include `localStorage`, `sessionStorage`, `indexedDB`, `document.cookie` |
| Three Playwright browsers slow down CI | Low | Small suite, cached Playwright browsers; the owner chose all three engines on every PR |

## Decisions log
- 2026-10-31: No router, so the URL never changes (AC22) and the bundle stays small.
- 2026-10-31: All styles global, no component styles, so a strict `style-src 'self'` CSP can work on a static host that cannot issue per-response nonces.
- 2026-10-31: No animation in v1, so AC21 and the WCAG 2.3.1 flash rule hold by construction.
- 2026-10-31: Word list as a TS module, not a fetched JSON file, so it is always in the bundle (AC9) and typed.
- 2026-10-31: Two renderers (Angular template for the page, string builder for the file) instead of serializing the live DOM, because the string builder is pure, testable and free of Angular comment nodes and attributes; a parity test guards drift.
- 2026-10-31: Non-cryptographic PRNG, as the spec allows; nothing depends on it for security.
- 2026-10-31: No ADR: no library, pattern or convention choice beyond the stack defaults in CLAUDE.md.
- 2026-11-01: Owner chose Vitest with jsdom as generated by the Angular 21 CLI for unit tests, because it is the Angular 21 default.
- 2026-11-01: Owner chose `angular-eslint` through `ng add` for linting, so `npm run lint` exists as CLAUDE.md expects.
- 2026-11-01: Owner chose `@playwright/test` with Chromium, Firefox and WebKit on every PR, because the spec supports all three engines.
- 2026-11-01: Owner chose `@axe-core/playwright` for a WCAG 2.2 AA scan including contrast.
- 2026-11-01: Owner chose `style-src 'self'` with global styles only. `'unsafe-inline'` needs a new owner decision.
- 2026-11-01: Owner chose an own test-only `e2e/serve.mjs` on `node:http` to serve the build with the real headers, so no static server or SWA CLI package is added.
- 2026-11-01: Owner chose a deploy workflow plus a documented `az staticwebapp create` command (no Bicep). Nothing deploys without the owner's explicit OK.

## Progress log
Appended by the lead after each step.
- 2026-11-01: Spec and plan approved and committed (0335481). Done: no code yet. Next: /feature 0001, starting with S1.
