# Session handoffs

Newest first. Written by `/handoff` at the end of a session so the next session can start cheaply with `/clear`. Keep at most ten entries; older ones are removed (git history keeps them).

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
