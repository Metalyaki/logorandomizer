# Spec NNNN: <title>

Status: draft | approved | done
Owner: <who asked for it>   ·   Date: YYYY-MM-DD

## Problem
Two or three sentences: what hurts today, for whom, and why it matters now.

## Users
Who is affected and in which role (customer, admin, support, integration).

## User stories
- As a <role>, I want <capability>, so that <benefit>.

## Acceptance criteria
Numbered, each one testable and independent.
1. **AC1** Given <context>, when <action>, then <observable result>.
2. **AC2** ...

## Out of scope
What this deliberately does not do.

## Edge cases and error handling
Empty and maximum inputs, invalid data, missing permissions, concurrency, partial failure, timeouts.

## Security and privacy
Risk level: High | Medium | Low, because <triggers from CLAUDE.md>.
- **Data**: which data this touches and its class (public, internal, personal, sensitive personal, secret); where it is stored, sent and logged.
- **Who may do what**: roles and ownership rules.
- **Abuse cases**: how someone could misuse this (for example scraping, spam, guessing ids, oversized uploads, prompt injection).
- **Security requirements** (filled in by the security agent for medium and high risk), testable like acceptance criteria:
  1. **SR1** Given <context>, when <attack or misuse>, then <safe outcome>.
- **GDPR** (when personal data is involved): purpose, legal basis, retention, deletion and export.

## Non functional requirements
Only the ones that apply: performance targets, accessibility (WCAG 2.2 AA), localization (sv, en), privacy and GDPR (which personal data, retention), audit logging, browser support.

## Assumptions
What the analyst assumed. Each one must be confirmed or corrected by the user before approval.

## Open questions
For the user. Phrase each as a choice with options where possible, so the lead can ask with AskUserQuestion.
1. ...
