# Spec 0001: Logo randomizer

Status: approved
Approved: sha256:3da59a83ded149ca on 2026-10-30
Owner: repo owner (metalyaki)   ·   Date: 2026-10-30

## Problem
People who want a quick, playful logo idea have no zero-effort way to get one. This app shows a randomly generated, colorful logo (an emblem plus a made-up name) and a button that generates a new one. It is a small, fun tool, not a design product.

## Users
Anonymous visitors. There are no accounts and no roles.

## User stories
- As a visitor, I want to press one button and see a new random logo with a name, so that I can have fun and find one I like.
- As a visitor, I want to go back to a logo I just saw, so that I do not lose one I liked.
- As a visitor, I want to download the logo as an SVG file, so that I can keep it.
- As a keyboard or screen reader user, I want to use every button without a mouse, so that I am not excluded.

## Acceptance criteria
Logo and randomize
1. **AC1** Given the page has loaded, when nothing has been pressed, then one logo with its name is shown, the "Randomize" and "Download SVG" buttons are enabled, and the "Previous" button is disabled.
2. **AC2** Given a logo is shown, when the user presses Randomize, then the logo and its name are replaced by new ones without a page reload.
3. **AC3** Given any generated logo, when it is inspected, then it is a single inline SVG element that renders without errors, has a fixed `viewBox` and scales to its container without distortion.
4. **AC4** Given any generated logo, when its fills are counted, then it uses at least 3 distinct colors.
5. **AC5** Given 100 consecutive presses of Randomize, when the generated logos (emblem and name together) are compared, then no two consecutive logos are identical, and at least 90 of the 100 are distinct.
6. **AC6** Given the generator receives the same seed twice, when it generates, then the emblem and the name are identical both times. (Makes tests deterministic; seeds are never shown or stored.)

Name
7. **AC7** Given any generated logo, when its name is read, then it consists of 2 words taken from the bundled local word list, separated by one space, matches `^[A-Z][a-z]{1,11} [A-Z][a-z]{1,11}$`, and is shown inside the SVG as `<text>` with a system font stack (no web fonts).
8. **AC8** Given the word list file, when it is tested, then every entry matches `^[A-Z][a-z]{1,11}$`, there are no duplicates, and there are at least 50 entries. (Review for offensive words is a manual owner check before release, see Assumptions.)
9. **AC9** Given the app is running, when a name is generated, then no user text is used anywhere and the word list is loaded from the app's own bundle or origin.

Previous
10. **AC10** Given the user has pressed Randomize once, when they press Previous, then the earlier logo and name are shown exactly as before (same markup) and the one just left is not kept.
11. **AC11** Given the user has pressed Randomize 25 times, when they press Previous repeatedly, then at most 20 earlier logos can be reached (history cap 20, oldest dropped first) and Previous becomes disabled after the last one.
12. **AC12** Given the user pressed Previous, when they press Randomize, then a new logo is generated and the history keeps the logo that was current before the press.
13. **AC13** Given a history exists, when the page is reloaded, then a fresh logo is shown and Previous is disabled (history lives in memory only).

Download
14. **AC14** Given a logo is shown, when the user presses Download SVG, then the browser downloads one file whose content is the displayed logo as a standalone SVG (root `<svg>` with `xmlns`, the same `viewBox`, the emblem and the name text) and whose MIME type is `image/svg+xml`.
15. **AC15** Given a logo named "Bold Panda", when it is downloaded, then the filename is `bold-panda.svg`. The filename is the name lowercased, with every run of characters outside `a-z0-9` replaced by one `-`, trimmed of leading and trailing `-`, limited to 40 characters before `.svg`; if that leaves nothing, the filename is `logo.svg`.
16. **AC16** Given any generated logo, when its downloaded file is parsed as XML, then it parses without errors and contains no `<script>`, `<foreignObject>`, event handler attributes (`on*`), `href` or `url(...)` references to external resources.
17. **AC17** Given a download was started, when it finishes, then the temporary object URL has been revoked, and the logo, the history and the button states are unchanged.
18. **AC18** Given the deployed site with its Content-Security-Policy, when Download SVG is pressed, then the download still works.

Accessibility, privacy and layout
19. **AC19** Given a keyboard user, when they tab to Randomize, Previous or Download SVG and press Enter or Space, then the action runs and focus stays on that button (if Previous becomes disabled, focus moves to Randomize).
20. **AC20** Given a screen reader user, when a logo changes (by Randomize or Previous), then the logo has an accessible name that includes its name (for example "Logo: Bold Panda") and the change is announced politely (`aria-live="polite"`), without moving focus.
21. **AC21** Given the user's system has "reduce motion" enabled, when a logo changes, then no animation or transition plays.
22. **AC22** Given the app is loaded and used (randomize, previous, download), when network traffic and browser storage are observed, then all requests go to the app's own origin (no third-party fonts, CDNs, analytics or trackers), nothing is written to cookies, localStorage, sessionStorage or IndexedDB, and the URL never changes.
23. **AC23** Given a viewport from 320 px to 1920 px wide, when the page is shown, then the logo, name and all three buttons are fully visible without horizontal scrolling.

## Out of scope
Accounts, a backend, saving anything in the browser, user-supplied text or images, logo editing, sharing or links (nothing goes in the URL), PNG export, copy to clipboard, a "Next" (redo) button, payments.

## Edge cases and error handling
- Rapid repeated presses (button held or mashed): each press shows a valid logo, with no crash and no stale or half-drawn logo; history never exceeds the cap.
- Previous when no history, or Download with no logo: not possible, because the button is disabled or a logo always exists.
- Generator returns an invalid result (should never happen): the previous logo stays visible and no unhandled error appears in the console.
- Download blocked or failing (browser setting): no crash, no console error left unhandled; the page keeps working.
- JavaScript disabled: a plain message "This app needs JavaScript" is shown.
- Any animation must not flash more than 3 times per second (WCAG 2.3.1).
- Color contrast: the buttons and their labels meet 4.5:1 regardless of the logo colors. Name text on the logo must stay readable (at least 4.5:1 against its own background inside the SVG).

## Security and privacy
Risk level: Low. Front-end only, no endpoints, no personal data, no secrets, no stored data, no new runtime packages beyond what Angular needs. The download adds no risk trigger: there is no upload, no user input and no server; the file is built in the browser from our own generated data only.
- **Data**: none collected, stored, sent or logged. The generated logo, name and history are held in memory and lost on reload. Class: public.
- **Who may do what**: everyone can do everything; there are no roles.
- **Abuse cases**: no user input is rendered or put into the file or filename. The word list is trusted, bundled content, validated by AC8, and the filename is still sanitized (AC15) as defense in depth. The SVG is bound through Angular templates; never use `innerHTML` or `bypassSecurityTrust*`. The download SVG is built as a string/Blob from generated values only, and AC16 checks it contains no active content. Randomness uses a non-cryptographic generator, which is fine because nothing depends on it for security. The history cap (AC11) bounds memory use.
- **Hosting hygiene**: the static site is served over HTTPS only, with a restrictive Content-Security-Policy (`default-src 'self'`, no inline script) and `X-Content-Type-Options: nosniff`. AC18 confirms the download works under it.
- **GDPR**: not applicable, because no personal data is processed and there are no cookies, so no consent banner is needed. This changes if analytics are added later.

## Non functional requirements
- Accessibility: WCAG 2.2 AA (AC19 to AC21, contrast, visible focus indicator).
- Performance: new logo visible within 100 ms of the press on a mid-range laptop; initial load under 200 kB gzipped.
- Browser support: the latest two versions of Chrome, Edge, Firefox and Safari.
- Localization: English only in v1.

## Test plan (summary)
- Unit: generator (AC3 to AC9 with seeds), word list validation (AC8), filename sanitizer including empty, long, symbol-only and non-ASCII names (AC15), history logic with cap (AC10 to AC12), SVG string builder (AC14, AC16).
- Component: button states and focus (AC1, AC19), announcements (AC20), reduce motion (AC21).
- End to end (browser): download content and filename (AC14, AC15, AC17), storage and network observation (AC22), reload (AC13), layout at 320 and 1920 px (AC23), download under the deployed CSP (AC18).

## Assumptions
1. The UI is English only (no sv/en switch).
2. "Colorful" means the checkable rules in AC4 and AC5; taste is not tested. The look is chosen by the developer within those rules and reviewed by the owner.
3. The emblem is generated from random choices (shapes, colors, layout) in the browser with a seedable pseudo random generator.
4. The static site is hosted on Azure Static Web Apps, with security headers set in its config.
5. No analytics or cookies. Adding either later needs a new spec and a GDPR review.
6. One page, one logo at a time.
7. No brand or design guide exists.
8. Performance budget (100 ms, 200 kB gzipped) and browser list are my proposals; they stand unless corrected.
9. New: the name is drawn as SVG `<text>` with a generic system font stack, so the downloaded file may look slightly different on other machines (no font is embedded and no web font is loaded).
10. New: the name is two capitalized words from a bundled list of English words written by the developer; the owner reviews the list for offensive or trademarked terms before release.
11. New: the history cap is 20 logos (my number).

## Open questions
None. Previous answers: logo = emblem plus random made-up name from a local word list; download SVG only; Previous button with in-memory capped history; no sharing and nothing in the URL.
