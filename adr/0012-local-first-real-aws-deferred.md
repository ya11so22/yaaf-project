# ADR-0012: Local and free first; real AWS deferred until local options are exhausted

**Status:** accepted (amends [ADR-0008](0008-phase-reslice-cd-and-team-model.md) and [ADR-0010](0010-us-market-positioning-and-ai-phases.md) on Phase 1; reaffirms [ADR-0002](0002-aws-emulation-strategy.md))
**Date:** 2026-09-20

## Context

ADR-0008 and ADR-0010 made one real-AWS deploy, with a budget alarm, a negative trust test and
evidence, a required end of Phase 1. The owner has restated the standing constraint: the project
stays free, and local simulation of live services (Floci with EKS, a self-hosted stack, `act`) is
preferred until real AWS is absolutely necessary. The project is also not driven by a job-search
timeline; only the project's own quality sets the order of work.

## Decision

1. **Phase 1 ends locally.** It ends with CD to `dev` (a throwaway Floci with EKS on a GitHub-hosted
   runner, and the persistent local Floci cluster), rollback, a threat model, a simple failure
   exercise and a demo. No AWS account or spend is needed for it.
2. **Real AWS is a later, optional milestone**, taken only after local options are exhausted:
   Phases 1 and 2 done locally, and a named question that only real AWS can answer. The budget
   alarm, the `aws-milestone` environment, the real-AWS deploy with evidence and the negative
   OIDC trust test all move under it. The gap analysis already lists IAM trust conditions as
   unproven until then; that stays true and is stated openly rather than hidden.
3. **Phase 2 and later are built against local infrastructure too**: observability, GitOps,
   policy-as-code and LLM serving run on the local or runner-hosted cluster with self-hosted tools.
4. **Order of work is by dependency, not by dates.** ADR-0010's "revisit after Phase 2" stands as a
   scope check, not a deadline.
5. ADR-0011's milestone-state decision (local state, one atomic job) stays as the design for
   the deferred milestone.

## Consequences / trade-offs accepted

- The project no longer demonstrates a real EKS deploy until later; its claims about real-AWS
  behaviour are limited to what Floci can show, and the docs must say so.
- Floci fidelity gaps (no IAM trust enforcement, one node per node group, no k8s version mapping)
  cap what can be proven locally, so some hardening work stays unproven.
- Cost stays at zero: GitHub Actions minutes on a public repo and local Docker.
