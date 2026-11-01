# Session handoffs

Newest first. Written by `/handoff` at the end of a session so the next session can start cheaply with `/clear`. Keep at most ten entries; older ones are removed (git history keeps them).

## 2026-11-01 | feature/0001-logo-randomizer | d136e18
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md, Status: done)
- **Done this session**: S14 (deploy workflow, docs/deploy.md), S15 (README, CHANGELOG, owner checklist), coverage pass (every AC and SR mapped to a passing test), two review rounds (security plus reviewer on opus): no open Blocking, Critical or High; ship checks green
- **State**: 147 unit tests, 102 e2e tests, lint, build and audit green; uncommitted: .claude/agent-memory/ only; no git remote yet
- **Decisions**: deploy split into build job (no secrets) and deploy job (`production`); web-ci runs on every PR so a required check never blocks docs-only PRs; S7 MAX_ATTEMPTS is 20 not 5; HSTS header not added
- **Open questions**: add an HSTS header (Low)? Create a private GitHub repo and push?
- **Watch out**: nothing has deployed; before the first deploy the owner sets branch protection on main (required check `web-ci / web`), the `production` environment (required reviewer, main only), secret `AZURE_STATIC_WEB_APPS_API_TOKEN`, variable `SWA_URL`; web-ci and web-deploy are unproven until a PR and a deploy run; owner release checklist in docs/deploy.md is unticked (word list, fonts, deployed AC18, performance)
- **Next**: `/ship`

## 2026-11-01 | feature/0001-logo-randomizer | 62a749e
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: S12 e2e suite (playwright.config.ts, e2e/serve.mjs, 9 spec files, 96 tests green on Chromium, Firefox, WebKit), committed 62a749e; web-ci.yml installs all three browsers
- **State**: build, 147 unit tests, e2e, lint and audit green; uncommitted: .claude/agent-memory/ (untracked agent notes)
- **Decisions**: removed `<base href="/">` from index.html (violated CSP base-uri 'none'; no router); no `blob:` needed in CSP (SR10 confirmed); noscript spec checks innerHTML, not visibility
- **Open questions**: none
- **Watch out**: S14 is High risk (CI/deploy): security review plus reviewer on opus; deploy token only in `production` environment with required reviewer; smoke check asserts nosniff, Referrer-Policy and HTTP to HTTPS redirect. web-ci.yml is unproven until a PR runs it. Deploy and push need the user's approval (check `git remote -v` first)
- **Next**: `/feature 0001` for S14 (devops), then S15 (docs)

## 2026-11-01 | feature/0001-logo-randomizer | efbc48d
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: S11 (staticwebapp.config.json headers, e2e/config.spec.ts, 7 tests) and S13 (web-ci.yml, dependabot.yml) committed 0604fb9 and efbc48d; S13 security reviewed, no High, 3 findings fixed; plan ticked (12 of 15 steps)
- **State**: build, 147 unit tests, lint and audit green; uncommitted: .claude/agent-memory/ (untracked agent notes)
- **Decisions**: devops agent cannot write under src/web (hook scope), so src/web steps go to frontend; config.spec.ts uses __dirname, so no "type": "module" in package.json
- **Open questions**: none
- **Watch out**: S12 must set playwright testDir 'e2e' (else Playwright also picks up Vitest specs), change the CI install line to chromium firefox webkit, and refuse `/../` in serve.mjs; CI stays red until S12 lands and is unproven until a PR runs it; no git remote yet, ask before any push; S14 is high risk (security plus reviewer on opus, deploys need the owner's OK); run team-init once src/web has real content (CLAUDE.md still says FILL IN)
- **Next**: `/feature 0001` for S12 (frontend), then S14, S15

## 2026-11-01 | feature/0001-logo-randomizer | 2a73ae8
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: S10 (app shell, styles, a11y) test first and implemented; committed 2a73ae8; plan ticked and progress log updated (10 of 15 steps)
- **State**: build, 147 tests, lint and audit green; uncommitted: .claude/agent-memory/ (untracked agent notes)
- **Decisions**: App is OnPush with global styles.css only; live region text is "New logo: {name}"; buttons Randomize, Previous, Download SVG; focus moves to Randomize when Previous disables
- **Open questions**: none
- **Watch out**: page not yet seen in a browser and button contrast not measured (S12 axe covers it); jsdom cannot test real Enter/Space, so S12 must; no git remote yet, ask before any push; S13 and S14 are high risk (security plus reviewer on opus); start tester and implementer in the same turn; run team-init once src/web has real content (CLAUDE.md still says FILL IN)
- **Next**: `/feature 0001`, then S11 and S13 in parallel (devops), then S12

## 2026-11-01 | feature/0001-logo-randomizer | 0cb3d40
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: S8 (svg-download.ts: SvgDownload) and S9 (logo-svg.ts/.html: LogoSvg) test first and implemented; committed 0d42f72 and 0cb3d40; plan ticked and progress log updated (9 of 15 steps)
- **State**: build, 127 tests, lint and audit green; uncommitted: .claude/agent-memory/ (untracked agent notes)
- **Decisions**: LogoSvg sizes the svg with `[style.width]`/`[style.height]` bindings (CSSOM, CSP safe); name is bound with `[textContent]` because prettier adds whitespace around `{{ }}` inside `<text>` and breaks parity with toSvgString; do not change back to interpolation
- **Open questions**: none
- **Watch out**: no git remote yet, ask before any push; S13 and S14 are high risk (security plus reviewer on opus); the stop gate goes red between test-first and implementation (and while an implementer is mid-write), so start tester and implementer in the same turn and wait for the implementer; run team-init once src/web has real content (CLAUDE.md still says FILL IN)
- **Next**: `/feature 0001`, then S10 (app shell, styles, a11y); S11 and S13 may run in parallel

## 2026-11-01 | feature/0001-logo-randomizer | d57290a
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: S6 (svg-export.ts: toSvgString, toFileName) and S7 (logo-store.ts: LogoStore, GENERATE_LOGO token) test first and implemented; committed d57290a; plan ticked, decisions and progress logs updated (7 of 15 steps)
- **State**: build, 109 tests, lint and audit green; uncommitted: .claude/agent-memory/ (untracked agent notes)
- **Decisions**: Angular Vitest builder rejects vi.mock on relative imports, so the store injects a GENERATE_LOGO token (default generateLogo) and specs override it through TestBed; test seam only, no plan change
- **Open questions**: none
- **Watch out**: no git remote yet, ask before any push; S13 and S14 are high risk (security plus reviewer on opus); never use vi.mock on relative imports in specs; the stop gate stays red between test-first and implementation, so start tester and implementer in the same turn; a subagent's Write can report success without the file landing, check it exists; run team-init once src/web has real content (CLAUDE.md still says FILL IN)
- **Next**: `/feature 0001`, then S8 (download service), S9 and S10 (S11 and S13 may run in parallel)

## 2026-11-01 | feature/0001-logo-randomizer | 33b469a
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: S4 test first and implemented (logo-generator.ts: generateLogo, isValidLogo, logoKey); committed 33b469a; plan ticked and progress log updated (5 of 15 steps)
- **State**: build, 72 tests, lint and audit green; uncommitted: .claude/agent-memory/ (untracked agent notes)
- **Decisions**: shape coordinates bounded to -512..1024 by the implementer (plan gave none); fontSize max 34 for 25 chars at 0.6em glyph width; logoKey is JSON.stringify(logo)
- **Open questions**: none
- **Watch out**: no git remote yet, ask before any push; S13 and S14 are high risk (security plus reviewer on opus); the stop gate stays red between test-first and implementation, so run the tester and the implementer in the same turn and wait for the implementer; run team-init once src/web has real content (CLAUDE.md still says FILL IN)
- **Next**: `/feature 0001`, then S6 and S7 (S8 to S10 follow; S11 and S13 may run in parallel)

## 2026-11-01 | feature/0001-logo-randomizer | 2623887
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: S2, S3, S5 test first and implemented (random, color, words, name, logo-history), plus the types in logo.model.ts (part of S4); committed 2623887; plan ticked and progress log updated
- **State**: build, 40 tests, lint and audit green; uncommitted: .claude/agent-memory/ (untracked agent notes)
- **Decisions**: contrastRatio rounds to 10 decimals (black on white is exactly 21); History is an interface (eslint rule); Polygon.points is a string; WORDS has 66 words, owner reviews in S15
- **Open questions**: none
- **Watch out**: S4 still needs logoKey, isValidLogo and generateLogo; no git remote yet, ask before any push; S13 and S14 are high risk (security plus reviewer on opus); the stop gate stays red between test-first and implementation, so run the tester and the implementer in the same turn; run team-init once src/web has real content (CLAUDE.md still says FILL IN)
- **Next**: `/feature 0001`, then S4 (generator), then S6 and S7 (S8 to S10 follow; S11 and S13 may run in parallel)

## 2026-11-01 | feature/0001-logo-randomizer | f386f90
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: S1 Angular 21 scaffold in src/web (CLI 21, Vitest, angular-eslint, Playwright and axe-core as dev packages), committed f386f90; plan ticked and progress log updated
- **State**: build, test, lint and npm audit green; uncommitted: .claude/agent-memory/ (untracked agent notes)
- **Decisions**: CLI 21 because Node 22.20 is too old for CLI 22; removed unused @angular/router, @angular/forms and .vscode/mcp.json; npm installs approved by the owner (subagents are blocked from installing, so the lead runs them with the owner's OK)
- **Open questions**: none
- **Watch out**: do not run the hook gate while a subagent runs `npm ci` (false build failures); no git remote yet, ask before any push; S13 and S14 are high risk (security plus reviewer on opus); run team-init again once src/web has real content (CLAUDE.md still says FILL IN)
- **Next**: `/feature 0001`, then S2 (parallel steps S2 to S10 with S11 and S13 are allowed by the plan)

## 2026-11-01 | feature/0001-logo-randomizer | 0335481
- **Working on**: spec 0001, a random SVG logo generator in Angular 21 (plan: docs/specs/0001-logo-randomizer.plan.md)
- **Done this session**: team setup committed on main (de860d1); spec and plan approved and recorded; spec and plan committed on the feature branch
- **State**: checks green (nothing to check yet, no code); uncommitted: .claude/agent-memory/ (architect notes, untracked)
- **Decisions**: Angular only, no backend; Vitest, angular-eslint, Playwright (3 browsers) and axe-core as dev packages; style-src 'self'; own e2e/serve.mjs; deploy workflow plus documented az command, no deploy without the owner's OK
- **Open questions**: none
- **Watch out**: no git remote yet (ask before any push, propose a private GitHub repo); S13 and S14 are high risk (CI, deploy): security plus reviewer on opus; team-init should run again once src/web exists (CLAUDE.md still says FILL IN)
- **Next**: `/feature 0001` then S1, the Angular skeleton in src/web
