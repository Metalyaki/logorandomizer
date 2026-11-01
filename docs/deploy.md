# Deploy

The site is a static Angular build served by Azure Static Web Apps (Free tier). The workflow `.github/workflows/web-deploy.yml` builds `src/web` (job `build`, no secrets) and then uploads the built artifact in a second job `deploy`, on every push to `main` that touches `src/web`, or by manual run. Only the `deploy` job runs in the GitHub environment `production`, so a required reviewer must approve each run and the token is only available there.

Nothing in this repository deploys from a developer machine. The commands below are for the owner.

## One-time setup

### 1. Create the Static Web App (PowerShell 7)

No GitHub token is needed: the resource is created empty and the workflow pushes the content.

```powershell
az login
$rg  = 'rg-logorandomizer'
$app = 'swa-logorandomizer'   # must be globally unique per region
az group create --name $rg --location westeurope
az staticwebapp create --name $app --resource-group $rg --location westeurope --sku Free
```

Show the site URL:

```powershell
az staticwebapp show --name $app --resource-group $rg --query "defaultHostname" -o tsv
```

### 2. Store the deployment token as an environment secret

Do not paste the token into chat, an issue or a file. Pipe it straight into GitHub:

```powershell
$repo = '<owner>/logorandomizer'
gh api -X PUT "repos/$repo/environments/production"
az staticwebapp secrets list --name $app --resource-group $rg --query "properties.apiKey" -o tsv |
  gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN --env production --repo $repo
```

### 3. Protect `production` and `main` (required)

Without these, code that failed CI can be deployed. Do both before the first deploy.

Environment `production` (Settings, Environments, `production`):

- Enable Required reviewers and add yourself (or the release approver). Without a reviewer the deploy runs unattended.
- Under Deployment branches and tags, select Selected branches and tags and add `main` only. This is required: it stops a manual run from any other branch from reaching the token.

Branch protection on `main` (Settings, Branches, rule or ruleset for `main`):

- Require a pull request before merging.
- Require status checks to pass before merging, and add the check `web` (job `web` of workflow `web-ci`, shown in the PR as `web-ci / web`). Enable Require branches to be up to date before merging.
- Block force pushes and do not allow bypassing.

The deploy workflow runs only on pushes to `main`, so with this rule every commit it deploys has passed `web-ci`. The `web` check runs when `src/web` or the CI workflow changes, the same paths that trigger the deploy.

### 4. Set the URL variable for the smoke check

```powershell
$swaHost = az staticwebapp show --name $app --resource-group $rg --query "defaultHostname" -o tsv
gh variable set SWA_URL --env production --repo $repo --body "https://$swaHost"
```

`SWA_URL` is not secret. It is used as the environment URL and by the smoke check, which asserts the Content-Security-Policy, `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer` headers, and that `http://` redirects to `https://`.

## Deploying

Merge to `main`, then approve the pending `web-deploy` run in the Actions tab. A failed smoke check fails the run but does not undo the upload: roll back (below).

## Rolling back

1. Preferred: revert the bad commit on `main` (`git revert <sha>`), push through a PR, approve the deploy run.
2. Faster: Actions tab, open the last good `web-deploy` run and re-run it (it rebuilds that commit). It needs the same reviewer approval.
3. If the token leaks: rotate it and update the secret.

```powershell
az staticwebapp secrets reset-api-key --name $app --resource-group $rg
# then repeat step 2 of the one-time setup
```

## Owner release checklist

Tick before announcing a release.

### Word list

- [ ] Read every word in `src/web/src/app/logo/words.ts`. Remove or replace any word that is offensive, or that is a trademark or brand name. Run `npm test -- --watch=false` in `src/web` afterwards (`words.spec.ts` checks format, duplicates and a minimum of 50 words).

### Look and fonts

- [ ] Open the deployed site on Windows, macOS and Linux. Press Randomize about 30 times on each.
- [ ] The name always fits on the plate and is not clipped, including long names.
- [ ] Text is readable against every background color.
- [ ] Check at a narrow window (about 320 px) and a wide one (1920 px).

### Deployed download (AC18)

- [ ] On the live site, press Download SVG. A file named after the logo (for example `bold-panda.svg`) is saved and opens in a browser or editor.
- [ ] DevTools Console shows no Content-Security-Policy violation while using all three buttons.
- [ ] DevTools Network, response headers of the page show the Content-Security-Policy, `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer`.

### Performance

- [ ] DevTools Performance panel: record one press of Randomize. A new logo is visible within 100 ms.
- [ ] Build in `src/web` with `npm run build`. The initial bundle is under 200 kB gzipped. For each initial file listed in the build output, compare the "Estimated transfer size" column, or gzip the files in `dist/web/browser` and add up the sizes.
