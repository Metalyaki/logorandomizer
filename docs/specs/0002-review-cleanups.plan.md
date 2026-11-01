# Plan 0002: review cleanups (refactor, behavior must not change)
Branch: chore/review-cleanups (from feature/0001-logo-randomizer)   ·   Status: done   ·   Risk: Low (refactor of code that touches no risk trigger)
Approved: sha256:ce86bba400264a4e on 2026-11-01

## Goal
Resolve the three "Nice to have" findings of the 0001 reviews without changing any output. Same seed gives the same logo, the same SVG string, the same pixels.

## Out of scope
- HSTS header: separate decision (see the lead's explanation). If wanted, it becomes its own small step with `config.spec.ts` and a smoke check assertion.
- Merging the two character-width numbers (0.6 and 0.65). They serve different jobs (validation bound versus layout estimate); merging would change generated font sizes.

## Steps
- [x] S1 [tester] (TF) Characterization tests that pin current behavior: for seeds 1 to 200, a snapshot of `generateLogo` output and a hash of `toSvgString` output, stored as a committed fixture. Done when: tests pass on the unchanged code and fail if any field, coordinate, font size or SVG attribute changes.
- [x] S2 [frontend] `logo-generator.ts`: replace the literals in `Math.min(34, Math.floor(400 / (name.length * 0.65)))` with named constants. `34` becomes `Math.floor(MAX_FONT_SIZE)`; `400` becomes `TEXT_BOX_WIDTH`; `0.65` becomes `LAYOUT_CHAR_EM`, documented as the layout estimate, distinct from `AVG_CHAR_EM`. Done when: S1 tests and all existing tests pass unchanged.
- [x] S3 [frontend] One home for the plate geometry and font stack: export `PLATE_Y` (360), `PLATE_HEIGHT` (104), `TEXT_X` (256), `TEXT_Y` (412) and `FONT_STACK` from a single module (`logo.model.ts` or a new `logo-layout.ts`). `svg-export.ts` imports them; `logo-svg.ts` exposes them and `logo-svg.html` binds them with `[attr.*]`. Done when: S1 tests, the parity test over many seeds and the exact font stack test pass unchanged, no `innerHTML` or bypass calls, and e2e passes on three browsers.
- [x] S4 [frontend] `svg-download.ts`: use `inject(DOCUMENT)` instead of the global `document`, as plan 0001 S8 specified. Done when: `svg-download.spec.ts` passes without weakening any assertion and `e2e/download.spec.ts` passes on three browsers.
- [x] S5 [lead] Verify and review: `run-checks.ps1 -Set ship`, e2e on three browsers, then the reviewer (Low risk, no security review). Done when: no open Blocking, Critical or High findings. Update the 0001 plan's decisions log only if something unexpected came up.

## Test strategy
No new behavior, so no new acceptance criteria. S1 is the safety net: it is written first, committed green, and must stay green and unmodified through S2 to S4. No test may be changed to get green; if one must change, stop and ask.

## Decisions log
(empty)

## Progress log
(empty)
- 2026-11-01: Plan approved and committed (73014e2). Workflow test bed, no deploy, no Actions. Next: /feature 0002, S1.
- 2026-11-01: S1 done. 401 characterization tests (seeds 1-200) green on unchanged code; mutation checks fail as expected. Note: the 400 constant is hidden by the min(34) cap for these seeds, fontSize field itself is pinned.
- 2026-11-01: S2 done. Named constants in logo-generator.ts (MAX_FONT_SIZE reused); S1 tests and 548 tests green. Formatter also rewrapped two lines (no behavior change).
- 2026-11-01: S3 done. Plate geometry and FONT_STACK live in logo.model.ts; svg-export and logo-svg share them. 548 unit tests, lint and e2e (102 on 3 browsers) green.
- 2026-11-01: S4 done. svg-download uses inject(DOCUMENT); spec untouched; unit, lint, build, e2e (102, 3 browsers) green.
- 2026-11-01: S5 done. Ship checks green, e2e 102 on 3 browsers, reviewer: no Blocking/Should-fix. Nice to have left open: fixture/hash files are type-checked by the app tsconfig (exclude them), prettier flags the generated fixture.
- 2026-11-01: Done: S1-S5, plan done. Next: /ship.
