---
name: risk
description: Run a risk assessment and threat model for a project, phase, feature, spec, plan or change, and turn the risks into testable security requirements. Use at project kickoff, for every medium or high risk feature before its plan is approved, when a change touches authentication, payments, personal data, secrets, uploads, AI tools or infrastructure, or when the user runs /risk.
argument-hint: [project | phase N | spec NNNN | plan NNNN | a description of the change]
---

# Risk assessment

Scope: $ARGUMENTS (default: the active plan, or the uncommitted change when there is no plan)

Security and privacy are the team's first priority. This assessment decides how much security work the scope needs, and its requirements are not optional.

1. **Classify quickly yourself** (two lines): which software types are involved (web API, single page app, WordPress or WooCommerce, e-commerce and payments, personal data, AI and LLM, integrations and jobs, infrastructure and CI, scripts and desktop tools) and which risk triggers from CLAUDE.md apply. That gives the risk level.
2. **Low risk**: write the Security and privacy section of the spec yourself (or a two line note in the plan) using the Common baseline in `checklists.md` next to this file, then stop. No agent needed.
3. **Medium or high risk**: delegate to the **security** agent in threat model mode. Give it the scope, the documents to read (brief, spec or plan) and the names of the matching sections of `checklists.md`, so it reads only those.
4. Show the user, in a short table: risk level, the security requirements (one line each), and the residual risks. **Ask for approval** of the requirements and for explicit acceptance of each residual risk.
5. Make sure the requirements land where they will be built and tested: in the spec (Security and privacy), the plan (Threat model and security controls, one control per step, one test per requirement) or `docs/project/risk-assessment.md` for a project.
6. Note in the decisions log what was accepted and by whom.

Update the assessment whenever the scope gains new data types, integrations, roles, AI capabilities, or changes hosting or authentication.
