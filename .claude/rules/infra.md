---
paths:
  - ".github/**"
  - "**/Dockerfile*"
  - "**/*.dockerfile"
  - "**/docker-compose*.y*ml"
  - "**/compose*.y*ml"
  - "**/*.bicep"
  - "**/*.bicepparam"
  - "**/*.tf"
  - "infra/**"
  - "azure.yaml"
---

# CI/CD and infrastructure

## GitHub Actions
- Pin third party actions to a full commit SHA with the version in a comment (`uses: owner/action@<sha> # v4.2.0`). Keep them current with Dependabot (`package-ecosystem: github-actions`).
- `permissions:` at the top of every workflow, starting from `contents: read`; grant more per job only where needed.
- Azure login with OIDC (`azure/login` with a federated credential), no stored client secrets.
- Never check out and run pull request code in `pull_request_target` workflows.
- Do not echo secrets; pass them through `env` to the step that needs them.
- `concurrency` groups to cancel superseded runs, caching for NuGet and npm, and timeouts on jobs.
- Production deploys need a GitHub environment with required reviewers.

## Docker
- Multi stage builds; final image from a runtime or chiseled base with a specific tag; run as non root (`USER $APP_UID` in .NET images).
- `.dockerignore` excludes `bin`, `obj`, `node_modules`, `.git`, `.env*` and secrets.
- No secrets in build args or layers; use BuildKit secrets.
- A health check, and only the ports the app needs.

## Azure (Bicep and azd)
- Modules per resource group or concern; parameters with `@secure()` for secrets; no secrets in outputs.
- Managed identities and role assignments with the least privilege; Key Vault references for app settings.
- Network: private endpoints or service firewalls for databases and storage when the app allows it.
- Tags and a naming convention on every resource.
- Validate with `az bicep build` and preview with `az deployment group what-if`. Never deploy from a Claude session.

## Terraform
- Remote state with locking; `terraform fmt`, `validate` and `plan`; apply only from the pipeline.
