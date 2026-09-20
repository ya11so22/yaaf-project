# ADR-0008: Phases end in a running app; named environments; push-based CD; team model

**Status:** accepted (phases 2 to 4 amended by [ADR-0010](0010-us-market-positioning-and-ai-phases.md))
**Date:** 2026-09-20

## Context

After building the Phase 1 infrastructure modules and the CI pipelines (ADR-0006, ADR-0007), the
project was reviewed against the original brief and against what live infrastructure looks like
(`docs/live-infra-gap-analysis.md`). Findings:

- CI builds and pushes images, but **nothing deploys them**: the cluster contains only system
  namespaces. The project mirrors how infrastructure is *built and changed* well, and how it is
  *run* poorly.
- The two environments (`environments/floci`, `environments/aws-milestone`) were never named or
  connected by a promotion path.
- The team model was implicit. The intent: the "app team" is a handful of Claude agents that
  change `app/src` and open PRs (the realistic pipeline trigger, and the reason environments
  and access management matter); the project owner is the DevOps engineer who owns infra and
  pipelines. This is simulated, and the docs should say so.
- GitHub-hosted runners cannot reach the local Floci cluster (same constraint as ADR-0004), so
  "deploy on merge into the local cluster" is not directly possible.

## Options considered

**Phasing**
1. **Keep the phases as written** (Phase 1 = IaC + Actions, with no deploy). Rejected: Phase 1
   would end with a registry full of images and an empty cluster.
2. **Re-slice so each phase is demoable from commit to running app** (chosen).

**How CD reaches a cluster**
- **(a) Push-based from Actions.** On merge, a job starts a throwaway Floci in the runner,
  applies the infra, deploys the manifests and smoke-tests them. The real-AWS milestone gets a
  manual, approval-gated deploy of the same image digest through the OIDC role (ADR-0006).
  Uses Actions features (environments, approvals, OIDC, promotion), stays free, needs no bot
  identity. Cost: the "dev" deployment is a test that vanishes after the run.
- **(b) GitOps pull (Argo CD) in the persistent local cluster.** Works behind NAT and is a real
  platform pattern, but adds Argo to the IaC, needs bot commits to bump images, and is only live
  while the local machine is up.
- **(c) A local deploy script.** Simplest, but not CD.

## Decision

1. **Phases**
   - **Phase 1, commit to running app:** finish and prove CI on GitHub; add minimal CD; budget
     alarm; OIDC; one real-AWS milestone deploy of the same manifests; threat model; demo.
   - **Phase 2, platform layer:** golden-path reusable workflow; GitOps (Argo CD) with per-PR
     environments; policy-as-code; DORA metrics with minimal observability (metrics stack and
     one alert); team access model (bot identity for agents, namespace-per-team RBAC).
   - **Phase 3, MLOps** on `recommendationservice`, unchanged.
   - **Phase 4, tracing**, optional and unchanged.
2. **Environments.** `dev` is Floci (`infra/environments/floci`); `milestone` is real AWS
   (`infra/environments/aws-milestone`). Directory names are kept to avoid churn. The same image
   *digest* is deployed to both; promotion means "the digest proven in dev is deployed to
   milestone". There is no production environment.
3. **CD in Phase 1 is option (a).** Dev: throwaway Floci in the runner, apply infra, deploy,
   wait for rollout, smoke check. Milestone: `workflow_dispatch` with a GitHub Environment
   approval, the `tofu-apply` role via OIDC, the digest as an input, teardown afterwards.
   Option (b) arrives in Phase 2, where per-PR environments genuinely need a persistent cluster.
4. **Manifests are deployed with kustomize** (`kubectl apply -k`), pinning images by digest with
   `kustomize edit set image`. Overlays for `dev` and `milestone` live under `deploy/`, built on
   the app's own `app/kustomize` base. Helm can be reconsidered if a use case needs it.
5. **Team model.** App team = Claude agents; platform = the DevOps engineer. Intake is GitHub
   Issues, with `ready-for-agent` marking work an agent can pick up. Through Phase 1 everything
   uses one GitHub identity; the resulting limits (no enforceable reviews, no demonstrable
   permission boundaries) are documented. A bot identity and namespace RBAC arrive in Phase 2.
6. **Observability** is minimal and lands in Phase 2 with DORA metrics; tracing stays Phase 4.

## Rationale

A project meant to show DevOps ability should end each phase with something running and
demoable. Push-based CD from Actions is the smallest step that closes the deploy gap while
staying free and exercising the skills Phase 1 is about. GitOps is the better fit for
ephemeral PR environments, so it waits for the phase that needs it.

## Consequences / trade-offs accepted

- The Phase 1 dev deployment is a test, not a persistent environment. The local cluster remains a
  sandbox for manual `kubectl apply -k`.
- Phase 1 grows: deploy overlays, a deploy workflow, and a gated milestone dispatch.
- With a single identity, branch-protection reviews cannot be required until a second identity
  exists (Phase 2). CODEOWNERS records intent meanwhile.
- The emulator proves manifests deploy, not that they behave on real EKS; the milestone deploy
  exists for that reason (ADR-0002).
- Revisit the CD choice if the dev throwaway deploy proves too slow or heavy on runners.
