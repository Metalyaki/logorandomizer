# Risk assessment: <name>

Scope: project | phase | feature   ·   Date: YYYY-MM-DD   ·   Status: draft | approved   ·   Overall risk: High | Medium | Low

## 1. Assets and data classification
| Data or asset | Class | Stored where | Sent where | Logged? |
| --- | --- | --- | --- | --- |
| Customer name, email, address | personal | SQL Server (Azure, EU) | email provider | no |

Classes: public, internal, personal, sensitive personal (health, finances, identity numbers), secret (keys, tokens, passwords).

## 2. Entry points and trust boundaries
Who or what can send input, and how it is authenticated: anonymous visitors, customers, admins, webhooks, other services, uploaded files, scheduled jobs, AI model output.

## 3. Threats
STRIDE per entry point, plus abuse cases specific to this product.

| Id | Entry point | Threat | Likelihood | Impact | Control | Requirement |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | POST /api/bookings | Spam bookings by a bot (denial of service, cost) | High | Medium | Rate limit per IP and per account, CAPTCHA after N attempts | SR3 |

## 4. Security requirements
Testable, like acceptance criteria. The architect turns each into plan steps; the tester proves each with a test.
1. **SR1** Given <context>, when <attack or misuse>, then <safe outcome>.

## 5. Baseline controls
Authentication and session handling, authorization model, secrets management (`dotnet user-secrets` locally, Key Vault in production), transport security (HTTPS, HSTS), security headers, logging without personal data, dependency and secret scanning in CI, backups and restore test, least privilege for every identity.

## 6. Compliance
GDPR (purpose, legal basis, retention, deletion, export, data processor agreements, data location), PCI DSS scope when payments are involved (keep card data out of our systems with a hosted payment page), accessibility requirements where they apply.

## 7. Residual risks
Risks we accept, why, and who accepted them (the user approves this list).

## 8. Review triggers
When this assessment must be updated: new data types, new integrations, new roles, new AI capabilities, changes in hosting or authentication.
