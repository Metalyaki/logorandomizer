# Security checklists per type of software

Read only the sections that match the scope. Every item is a control to confirm, or a requirement to add with a test. Sections: Common baseline, Authentication and accounts, Web API, Single page app, Server rendered sites and Next.js, WordPress and WooCommerce, E-commerce and payments, Personal data and GDPR, File uploads and documents, AI and LLM features, Integrations, webhooks and scheduled jobs, Infrastructure, CI/CD and cloud, Scripts, desktop and internal tools.

## Common baseline
Applies to everything.
- [ ] Secrets only in `dotnet user-secrets` or a gitignored `.env` locally and in Key Vault (or the platform's secret store) in production; nothing in code, config files, tests, logs, prompts or CI output.
- [ ] Least privilege for every identity: database users, managed identities, API tokens, GitHub tokens.
- [ ] All input validated at the boundary (type, length, range, format, allow lists); output encoded for its context.
- [ ] Errors: generic messages to users, details only in logs; no stack traces in production.
- [ ] Logging of security events (sign in, failed sign in, permission denied, admin actions) without personal data or secrets; clock in UTC.
- [ ] Dependencies: known and maintained packages only, lockfile committed, vulnerability audit in CI, new packages approved by the user.
- [ ] Transport: HTTPS only, HSTS, modern TLS.
- [ ] Backups exist, are encrypted, and a restore has been tested.
- [ ] Tests: at least one negative test per security requirement (the attack fails).

## Authentication and accounts
Threats: credential stuffing, brute force, session theft, account enumeration, weak reset flows.
- [ ] Use a proven identity platform (Microsoft Entra ID, Entra External ID, ASP.NET Core Identity) instead of custom crypto.
- [ ] Passwords hashed by the framework; MFA available, required for admins.
- [ ] Rate limiting and lockout on sign in, reset and verification endpoints; same response for unknown and known accounts.
- [ ] Reset and verification tokens are single use, short lived and random.
- [ ] Tokens: validate issuer, audience, lifetime and algorithm; short access token lifetime; refresh tokens rotated.
- [ ] Cookies: `Secure`, `HttpOnly`, `SameSite=Lax` or `Strict`; CSRF protection wherever cookies authenticate.
- [ ] Sign out invalidates the session server side.

## Web API
Threats: broken object level authorization (IDOR), broken function level authorization, mass assignment, injection, excessive data exposure, SSRF, resource exhaustion.
- [ ] Fallback policy requires authentication; every endpoint has an explicit policy; anonymous endpoints are listed and justified.
- [ ] Ownership check for every id that comes from the client (resource based authorization).
- [ ] Request DTOs contain only fields the caller may set; response DTOs contain only fields the caller may see.
- [ ] Parameterized queries only; no raw SQL with interpolation; no shell commands with user input; file paths never built from user input.
- [ ] Outbound calls to user supplied URLs are blocked or restricted to an allow list (SSRF).
- [ ] Pagination limits, request size limits, timeouts and rate limits on expensive or public endpoints.
- [ ] CORS limited to known origins; security headers set.
- [ ] ProblemDetails without internal details.
Tests: anonymous, wrong user, wrong role and right role for each endpoint; oversized and malformed input.

## Single page app
Threats: XSS, token theft, sensitive data in the browser, open redirects.
- [ ] No `innerHTML`, `bypassSecurityTrust*` or `dangerouslySetInnerHTML` with user data; rely on framework sanitizing.
- [ ] Tokens not in `localStorage` when avoidable (prefer a backend for frontend with HttpOnly cookies); never in URLs.
- [ ] No secrets or API keys in the frontend bundle or environment files; everything in the bundle is public.
- [ ] Content Security Policy that blocks inline scripts where feasible.
- [ ] Route guards are a convenience only; the API enforces authorization.
- [ ] Redirect targets validated against an allow list.

## Server rendered sites and Next.js
- [ ] Server Actions and route handlers validate input and check authentication and authorization in every one; they are public endpoints.
- [ ] Only `NEXT_PUBLIC_` variables reach the browser, and they hold no secrets.
- [ ] Caching never mixes user specific data between users (check `"use cache"` scopes and CDN rules).
- [ ] `next/image` remote patterns restricted; `proxy.ts` (formerly middleware) is not the only authorization layer.

## WordPress and WooCommerce
Threats: vulnerable plugins, privilege escalation, CSRF in admin actions, SQL injection, XSS in themes, brute force on wp-login.
- [ ] Every plugin and theme maintained, from a trusted source, updated; remove what is unused.
- [ ] Every form, AJAX and REST action checks a nonce and `current_user_can`; REST routes have a real `permission_callback`.
- [ ] Sanitize input early, escape output late; `$wpdb->prepare` for every query with variables.
- [ ] Admin accounts with MFA and unique usernames; login rate limiting; XML-RPC disabled when not needed.
- [ ] `wp-config.php` secrets and salts outside git; `DISALLOW_FILE_EDIT` true; debug output off in production.
- [ ] WooCommerce: hosted payment pages or the payment provider's fields, never raw card data; order and customer data access limited by role; HPOS compatible APIs.
- [ ] Backups and a staging site for updates; never test on the live site.

## E-commerce and payments
Threats: card data exposure, price or quantity tampering, coupon abuse, fake orders, webhook spoofing, refund fraud.
- [ ] Card data never touches our servers: hosted checkout or provider elements (keeps PCI DSS scope minimal).
- [ ] Prices, discounts, shipping and totals computed server side from trusted data; client values ignored.
- [ ] Payment webhooks verified by signature, idempotent, and the order state machine rejects invalid transitions.
- [ ] Coupon and gift card codes are random, rate limited and single use where intended.
- [ ] Order confirmation only after the provider confirms payment.
- [ ] Refunds and order edits limited to authorized roles and logged.

## Personal data and GDPR
- [ ] Data map: what personal data, why (purpose and legal basis), where stored, who can access, how long kept.
- [ ] Collect the minimum; no personal data in logs, analytics events, error reports, prompts or test fixtures.
- [ ] Deletion and export are possible per person; retention is enforced by a job, not by hand.
- [ ] Processors (email, payment, analytics, AI providers) have agreements; data stays in the EU or has a legal transfer basis.
- [ ] Encryption in transit everywhere and at rest for databases and backups; sensitive fields get extra protection.
- [ ] Access to personal data is logged for admin and support tools.

## File uploads and documents
- [ ] Allow list of file types checked by content, not only extension; size limits; file count limits.
- [ ] Stored outside the web root (Blob Storage) with generated names; served with `Content-Disposition` and correct content type.
- [ ] Malware scanning for files other users will download.
- [ ] Images encoded again on the server; archives never extracted without limits (zip bombs, path traversal).
- [ ] Access to stored files is authorized per request (short lived SAS links, not public containers).

## AI and LLM features
Threats: prompt injection (direct and through documents, web pages, emails or tool results), data leakage, excessive agency, insecure output handling, unbounded cost, model output treated as truth.
- [ ] API keys server side only, in Key Vault; never in the frontend.
- [ ] Untrusted content is clearly separated from instructions; the model's output never decides authorization.
- [ ] Tools get the least power needed; actions that change data, send messages or spend money need confirmation or a strict allow list.
- [ ] Output validated against a schema before use; never executed as code, SQL or shell; escaped before rendering.
- [ ] Retrieval only returns documents the current user may see (authorization before retrieval, not after).
- [ ] Personal data kept out of prompts unless needed; prompts and outputs logged without personal data; provider data retention settings checked.
- [ ] `max_tokens`, timeouts, per user rate limits and spend alerts.
- [ ] Evaluation cases for important prompts, including injection attempts, run before prompt changes ship.

## Integrations, webhooks and scheduled jobs
- [ ] Inbound webhooks verified (signature or mutual TLS), replay protected (timestamp, idempotency key) and rate limited.
- [ ] Outbound calls use timeouts, retries with backoff for idempotent operations only, and circuit breaking.
- [ ] Credentials per integration with least privilege, rotated, stored in Key Vault.
- [ ] Jobs are idempotent, log their runs without personal data, and alert on failure.
- [ ] Data from partners is validated like user input.

## Infrastructure, CI/CD and cloud
- [ ] GitHub: branch protection on main, required reviews and checks, secret scanning with push protection, Dependabot alerts.
- [ ] Actions pinned to commit SHAs; `permissions:` least privilege; OIDC to Azure; no secrets printed; no untrusted code in `pull_request_target`.
- [ ] Azure: managed identities, least privilege role assignments, Key Vault references, private endpoints or firewalls for data services, diagnostic logs on, Defender for Cloud recommendations reviewed.
- [ ] Production changes only through the pipeline with environment approvals; nobody deploys from a laptop.
- [ ] Containers: non root, minimal base images, no secrets in layers, image scanning.

## Scripts, desktop and internal tools
Threats: stored credentials, overly broad permissions, destructive operations, unsafe input from files.
- [ ] Credentials from Windows Credential Manager, `SecretManagement`, Key Vault or environment, never in the script.
- [ ] Destructive operations have a dry run mode and a confirmation; logs record who ran what.
- [ ] Input files validated; paths resolved and checked before deleting or overwriting.
- [ ] Internal and admin tools require authentication and authorization like public ones; internal network is not a security boundary.
