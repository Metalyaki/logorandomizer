---
name: kickoff
description: Start a new product or a large change as a phased project. Produces an approved brief, risk assessment, architecture and roadmap of phases in docs/project, so every phase can then run in its own fresh session with /phase. Use when the user runs /kickoff.
argument-hint: <the project idea>
disable-model-invocation: true
---

# Project kickoff

Idea: $ARGUMENTS

This session plans; it writes no production code. The documents carry the knowledge to later sessions, not this conversation, so keep it focused and end it with a handoff.

1. **Intake.** Ask the user, in one AskUserQuestion call with up to four questions, what you cannot infer: who the users are, which data is involved (personal data, payments, health or other sensitive data), hosting and integrations, and what the first release must contain. Put your recommendation first.
2. **Brief.** Delegate to the **analyst** (spawn it with model `opus` for a new product, because the brief shapes everything). It writes `docs/project/brief.md`. Ask its open questions, resume it with the answers, and get the user's **approval**.
3. **Risk assessment.** Run `/risk project`. The **security** agent writes `docs/project/risk-assessment.md`. Show the risk level, the security requirements and the residual risks, and get **approval**, including explicit acceptance of each residual risk.
4. **Architecture and roadmap.** Delegate to the **architect**. It writes `docs/project/architecture.md`, ADRs for the big decisions, and `docs/project/roadmap.md`. Each phase fits one spec and one plan, delivers something testable, takes one to three sessions, and names the security requirements it covers. Security foundations (authentication, secrets, logging, CI checks) come first. Get **approval**.
5. **Project guide.** If the Product and Stack sections of CLAUDE.md are empty, fill them in briefly (the protect hook asks the user). Never put phase details into CLAUDE.md: it is loaded into every session and every agent.
6. **Commit** on `chore/kickoff-<name>`: `docs: project kickoff <name>`.
7. **Handoff.** Run `/handoff` with Next: `/phase next`.
8. Tell the user: "Planning is done. Run /clear (it costs nothing) and then /phase next to start phase 1 in a fresh session."
