# Logo Randomizer

A small web app that makes a random logo on every click. Each logo has a two-word name such as "Bold Panda", a shape, and colors. You can step back to earlier logos and download the current one as an SVG file.

## Privacy

The app collects no data. It sets no cookies, uses no browser storage, loads nothing from other sites (no CDNs, fonts or analytics), and sends no requests except to its own origin. The page address never changes.

## Run it locally

You need Node.js and npm. All commands run in `src/web`.

```powershell
cd src/web
npm ci
npm start
```

Open `http://localhost:4200/`.

## Test, lint and build

Run these in `src/web`.

| Task | Command |
| --- | --- |
| Unit tests | `npm test -- --watch=false` |
| Lint | `npm run lint` |
| Production build | `npm run build` |
| End-to-end tests (Playwright) | `npm run e2e` |

The end-to-end tests run on Chromium, Firefox and WebKit. They serve the built app from `dist/web/browser`, so run `npm run build` before `npm run e2e` (and again after code changes). Install the browsers once:

```powershell
npx playwright install chromium firefox webkit
```

## Deploy

The site is a static build on Azure Static Web Apps. Setup, deploy, rollback and the owner release checklist are in [docs/deploy.md](docs/deploy.md).

## More

- Spec and plan: `docs/specs/0001-logo-randomizer.md` and `docs/specs/0001-logo-randomizer.plan.md`
- Changes: [CHANGELOG.md](CHANGELOG.md)
