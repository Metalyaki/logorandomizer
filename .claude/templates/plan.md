# Plan NNNN: <title>

Spec: docs/specs/NNNN-<name>.md   ·   Branch: feature/NNNN-<name>   ·   Status: draft | approved | in progress | done

## Approach
One paragraph: the design in plain words and why it is the simplest one that meets the acceptance criteria.

## Changes by area
- **Domain**: entities, value objects, rules
- **Data**: tables, columns, indexes, migration name, backfill
- **API**: endpoints, DTOs, validation, authorization policy per endpoint
- **Web**: routes, components, services, state
- **Infra and config**: settings, secrets (names only), pipelines

## Threat model and security controls
Risk level and the risk assessment this plan follows (`docs/project/risk-assessment.md` or the spec's Security and privacy section).

| Threat or requirement | Control | Plan step | Test |
| --- | --- | --- | --- |
| SR1 <requirement> | <authorization policy, validation, rate limit, encryption, ...> | S2 | <test name> |

Secrets used (names only, never values) and where they live. Personal data flows and where they are logged (they should not be).

## API contract
| Method | Route | Auth | Request | Response | Errors |
| --- | --- | --- | --- | --- | --- |

## Test strategy
Which acceptance criteria are covered by unit, integration and end to end tests. Steps marked **(TF)** are built test first: the tester writes failing tests for the step before the implementer starts.

## Steps
Each step is small enough to build, test and commit on its own. Tag the owner, mark test first steps with (TF) and steps that may run in parallel with (parallel with Sx). Each step says when it is done.

- [ ] S1 [backend] (TF) <what>. Done when: <observable result, tests named>.
- [ ] S2 [backend] <what>. Done when: ...
- [ ] S3 [frontend] (parallel with S2) <what>. Done when: ...

## Risks
| Risk | Likelihood | Mitigation |
| --- | --- | --- |

## Decisions log
Every decision made during the work, with the reason. Append, never rewrite.
- YYYY-MM-DD: <decision> because <reason>.

## Progress log
Appended by the lead after each step.
- YYYY-MM-DD S1 done, commit <sha>. Notes: ...
