# Architecture track

The design side of this project, in AWS's terms ([ADR-0017](../../adr/0017-well-architected-architecture-track.md)).
It sits beside the running system and the ADRs: what should be built and why, reviewed against the
[AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html)
(six pillars: operational excellence, security, reliability, performance efficiency, cost optimization,
sustainability) and the lenses that apply.

## The scenario

A **fictional** customer, so the work can show the method as an architect would run it: a mid-size retailer
moving its storefront from on-premises to AWS. Card payments are in scope, there are availability and RTO/RPO
targets, a budget, and a small team. The requirements and assumptions are written down first
(`00-requirements.md`, not started), and every design choice traces back to one.

## Evidence labels

Every claim in this track carries one of three labels. Nothing here is presented as production-proven.

| Label | Meaning |
|---|---|
| **designed** | Reasoned and written down, not built. |
| **verified on Floci** | Built and run on the local emulator. Floci proves that tested SDK and IaC scenarios work, not that real AWS behaves the same way; its known gaps are listed in `infra/README.md`. |
| **verified on real AWS** | Run on real AWS. None yet; real AWS is deferred by [ADR-0012](../../adr/0012-local-first-real-aws-deferred.md). |

## Contents and state

| Artifact | What it is | State |
|---|---|---|
| `00-requirements.md` | The scenario, business drivers, constraints, NFRs (availability, RTO/RPO, compliance), assumptions | not started |
| `01-views.md` | Context, containers, AWS deployment, delivery flow, data flow, trust boundaries, as diagrams in code | not started |
| `02-well-architected-review.md` | The review against all six pillars and the Container Build, DevOps and Financial Services Industry lenses, with a findings register (risk level, evidence, where it was verified, remediation and milestone). Review v1 now, v2 after Phase 2 | not started |
| `03-reliability-and-dr.md` | RTO/RPO tiers (backup and restore, pilot light, warm standby, active-active), multi-AZ and multi-region options, cost per tier, the failure exercises so far | not started |
| `04-cost-model.md` | Pricing estimates at several sizes, the levers, and what each ADR trade-off costs | not started |
| `05-migration-options.md` | The 7 Rs applied to the scenario, a recommended path and why | not started |
| `06-security-and-compliance.md` | The threat model, and a control mapping for card-payment handling (a mapping, not a certification) | not started |
| `07-ai-architecture.md` | Bedrock against self-hosted serving on EKS, a RAG design; the Generative AI lens | not started |
| `08-governance.md` | Multi-account layout and guardrails | not started |
| `customer/` | A one-page executive summary, the review readout, discovery questions | not started |
| `../interview/` | Each decision mapped to a pillar, its alternatives and what would change on real AWS; a story bank drawn only from things that happened here, with links | not started |

## How it connects to the rest

- Decisions live in [`/adr`](../../adr); the review points at them as evidence instead of repeating them.
- The failure exercises live in [`docs/postmortems/`](../postmortems).
- Progress against phases is in [`docs/milestones.md`](../milestones.md).
