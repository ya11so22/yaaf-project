# Milestones

Tracks progress against the "done" bar from the project brief: each phase is independently
demoable on its own (README + short recording/GIF), not just a step toward something bigger.
As of [ADR-0008](../adr/0008-phase-reslice-cd-and-team-model.md) each phase ends with a running
app, from commit to deployment. Updated as work lands: see `docs/journal/` for the narrative
behind each checked item, and `docs/live-infra-gap-analysis.md` for how this compares to live
infrastructure.

## Phase 1 — Commit to running app (IaC, CI, minimal CD)

### Infrastructure (OpenTofu, against Floci)

- [x] Floci running locally, via `compose.yaml` with persistent storage (2026-09-16, reworked
      2026-09-20)
- [x] `modules/vpc`: applied and verified against Floci
- [x] `modules/eks-cluster` (ADR-0003): applied; `kubectl` reaches the cluster on the pinned
      Kubernetes version
- [x] `modules/ecr`: applied; an image push and an in-cluster pull verified
- [x] `modules/github-oidc` (ADR-0006): applied against Floci; the trust conditions can only be
      proven on real AWS

### Pipelines (GitHub Actions)

- [x] `build.yml`: path-filtered per-service builds to GHCR with cache, Trivy (report-only) and an
      always-running `build` gate: written, linted, change detection unit-tested (ADR-0007)
- [x] `infra.yml`: `fmt`/`validate`/`plan` without Floci, sticky plan comment, Floci smoke test
      (apply, no-diff re-plan, destroy), `infra` gate: written and linted
- [x] Local pre-gate: `scripts/check`, a pre-commit hook and `check.yml` sharing one script
      (ADR-0009). Each check proven against a planted fault, and `check` passes on a runner
- [x] `cleanup.yml` (weekly GHCR retention): verified by a manual run (2026-09-20). The package name
      `yaaf-project/<service>` is accepted and the built-in token can manage the packages. The
      action's default of deleting 1 old version per run was raised to 100. Deletion itself is
      untested until a package exceeds 10 versions.
- [x] **First real run on GitHub** (PR #1, 2026-09-20): `build` and `infra` green, 12 images pushed
      to GHCR, Trivy results in code scanning, plan comment posted, Floci smoke test passed (apply,
      no-diff re-plan, destroy). A later PR confirmed the gates report green when nothing relevant
      changed.

### Repository (agreed sequence, see ADR-0007)

- [x] Email in the commits rewritten to the GitHub noreply address and force-pushed; history
      re-scanned with gitleaks (56 commits including the pre-rewrite copies, no leaks) (2026-09-20)
- [x] Repository made public; SHA pinning enforced; workflows from all outside contributors need
      approval; default workflow token read-only (2026-09-20)
- [x] The branch landed on `main` through PR #1 with a merge commit (2026-09-20)
- [x] Branch protection on `main` (2026-09-20): PR-only, applies to admins, `build`, `infra` and
      `check` required, no force-push or deletion; required reviews stay off until a second
      identity exists (Phase 2)
- [x] The 12 GHCR packages made public by hand; verified with anonymous pulls (2026-09-20)

### Continuous delivery (ADR-0008, ADR-0010)

Design settled in [ADR-0011](../adr/0011-cd-image-identity-scope-and-state.md): content-hash image
tags, the 11 base services without the load generator, and a milestone that holds local state in one
atomic job with a saved, encrypted plan. Implementation has not started.

- [ ] Spike: a throwaway Floci with EKS starts, and a deploy completes, on a GitHub-hosted runner
      (unproven; ADR-0008 assumes it, and the dev deploy depends on it)
- [ ] `build.yml` computes and publishes a content-hash tag per service, hash inputs including
      shared build files (amends ADR-0007's SHA tags)
- [ ] `deploy/dev` and `deploy/milestone` kustomize overlays on the app's `app/kustomize` base,
      images pinned by digest
- [ ] `deploy.yml`, dev: on merge to `main`, start a throwaway Floci in the runner, apply the
      infra, deploy the overlay, wait for the rollout, smoke check the frontend
- [ ] Rollback: redeploy the previous digest, exercised in a drill
- [ ] `deploy.yml`, milestone: manual dispatch behind a GitHub Environment approval, using the
      `tofu-apply` role via OIDC and a digest input, with teardown afterwards; plan saved, approved,
      then that saved plan applied
- [ ] Promotion documented and exercised: the digest proven in dev is the one deployed to milestone

### Real AWS and safety

- [ ] AWS Budgets + billing alarm, before anything touches real AWS
- [ ] `environments/aws-milestone` built (local state, ADR-0011) and
      OIDC federation working from Actions
- [ ] **Milestone:** one real, temporary AWS EKS deploy of the same manifests through the
      pipeline, including a negative test that a foreign repository cannot assume the roles;
      then torn down, with evidence kept (logs, screenshots, teardown, a cost note)
- [ ] Threat model (STRIDE-style pass on pipeline and infra)
- [ ] A simple failure exercise for Phase 1 (a bad digest, recovered by rollback) and a short
      postmortem
- [ ] Phase 1 demo: README + short recording/GIF

## Phase 2 — Operate it (reliability and platform)

Not started. Scope (ADR-0010):

- [ ] Observability: a metrics stack and dashboards for the deployed app
- [ ] SLOs and alerts on them, and an incident drill with a written postmortem
- [ ] DORA metrics from the pipeline
- [ ] GitOps (Argo CD) in a persistent cluster, with per-PR environments (a namespace per PR,
      torn down on close)
- [ ] Policy-as-code: `conftest` on plans (for example, no wildcard OIDC `sub`) and manifests, and
      an IaC security scan
- [ ] Golden-path reusable workflow (`workflow_call`) extracted from `build.yml`, with per-service
      configuration
- [ ] Team access model: a bot identity for agents, enforceable required reviews, namespace-per-
      team RBAC
- [ ] Failure exercise + postmortem for Phase 2, and a demo

## Phase 3 — AI serving on the platform (LLMOps)

Not started. Scope (ADR-0010): an open-weight model server on the cluster (CPU-friendly small
model, so it stays free), model versions promoted through an evaluation gate in CI with canary and
rollback, latency, cost and token metrics with alerts, and autoscaling. Built on Phase 1 and 2's
delivery and observability; a short GPU run at the milestone is the fallback if CPU inference cannot
show autoscaling and latency alerts.

## Phase 4 — Classic MLOps

Not started. Scope (ADR-0010): a real recommendation model for `recommendationservice` (the current
service is not a real ML system), with training and evaluation on PR, a registry, metrics-gated
promotion and drift monitoring, on Phase 3's platform.

## Optional stretch

Distributed tracing (OpenTelemetry) across all five languages; non-blocking for calling the project
done.

## Standing goals (not phase-scoped)

- [ ] One piece of external validation (Floci upstream contribution, or a public write-up of one
      hard problem hit along the way). The Floci findings in the journal are candidates.
- [ ] Deliberate failure exercise + postmortem at the end of each phase (see `docs/postmortems/`)

## Phase 2 stretch candidate: self-hosted OpenTofu state backend

Not committed, not scheduled: a candidate to revisit when Phase 2's platform layer takes shape.
Running a self-hosted remote-state backend (MinIO + native S3 state locking, or the `pg` backend)
is its own demonstrable platform-engineering skill, distinct from pointing at a managed SaaS. See
[ADR-0004](../adr/0004-tfstate-backend-strategy.md).

## Open follow-up: aws-milestone backend needs revisiting post-OpenTofu

ADR-0004 picked HCP Terraform for `environments/aws-milestone`, but HCP Terraform's remote
execution only runs HashiCorp's own Terraform binary, not OpenTofu (see
[ADR-0005](../adr/0005-opentofu-over-terraform.md)). Resolved for the milestone by
[ADR-0011](../adr/0011-cd-image-identity-scope-and-state.md): local state inside one atomic
job. A remote backend remains only as the Phase 2 stretch above.
