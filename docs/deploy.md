# Deploy

The site is a static Angular build served by Azure Static Web Apps (Free tier). The workflow `.github/workflows/web-deploy.yml` builds `src/web` and uploads `src/web/dist/web/browser` on every push to `main` that touches `src/web`, or by manual run. The job runs in the GitHub environment `production`, so a required reviewer must approve each run.

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

### 3. Require a reviewer on `production`

In GitHub: Settings, Environments, `production`, enable Required reviewers and add yourself (or the release approver). Optionally restrict Deployment branches to `main`. Without a reviewer the deploy runs unattended.

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

Extended by S15. Tick before announcing a release.

- [ ] Word list reviewed for offensive or trademarked words
- [ ] Visual and font check on the deployed site
- [ ] Deployed download check (AC18)
- [ ] Performance check
