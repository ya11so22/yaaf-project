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

### Continuous delivery (ADR-0008)

- [ ] `deploy/dev` and `deploy/milestone` kustomize overlays on the app's `app/kustomize` base,
      images pinned by digest
- [ ] `deploy.yml`, dev: on merge to `main`, start a throwaway Floci in the runner, apply the
      infra, deploy the overlay, wait for the rollout, smoke check the frontend
- [ ] `deploy.yml`, milestone: manual dispatch behind a GitHub Environment approval, using the
      `tofu-apply` role via OIDC and a digest input, with teardown afterwards
- [ ] Promotion documented and exercised: the digest proven in dev is the one deployed to milestone

### Real AWS and safety

- [ ] AWS Budgets + billing alarm, before anything touches real AWS
- [ ] `environments/aws-milestone` built (backend decision resolved, see the follow-up below) and
      OIDC federation working from Actions
- [ ] **Milestone:** one real, temporary AWS EKS deploy of the same manifests through the
      pipeline, including a negative test that a foreign repository cannot assume the roles;
      then torn down
- [ ] Threat model (STRIDE-style pass on pipeline and infra)
- [ ] Failure exercise + postmortem for Phase 1
- [ ] Phase 1 demo: README + short recording/GIF

## Phase 2 — Platform engineering layer

Not started. Scope (ADR-0008):

- [ ] Golden-path reusable workflow (`workflow_call`) extracted from `build.yml`, with per-service
      configuration
- [ ] GitOps (Argo CD) in a persistent cluster, with per-PR environments (a namespace per PR,
      torn down on close)
- [ ] Policy-as-code: `conftest` on plans (for example, no wildcard OIDC `sub`) and manifests
- [ ] Minimal observability (metrics stack and one alert) and DORA metrics from the pipeline
- [ ] Team access model: a bot identity for agents, enforceable required reviews, namespace-per-
      team RBAC
- [ ] Failure exercise + postmortem for Phase 2, and a demo

## Phase 3 — MLOps on `recommendationservice`

Not started: PR-triggered train/eval, metrics-gated promotion on merge, versioned model
artifacts.

## Phase 4 — Distributed tracing (optional/stretch)

Not started; explicitly non-blocking for calling the project "done" at Phase 3.

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
[ADR-0005](../adr/0005-opentofu-over-terraform.md)). Since `environments/aws-milestone` is not
built yet, pick an OpenTofu-compatible backend when that environment is built, rather than
deciding speculatively now.
