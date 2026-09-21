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

Image identity and scope settled in [ADR-0011](../adr/0011-cd-image-identity-scope-and-state.md):
content-hash image tags, and 10 services plus `redis-cart` without the load generator. Real AWS is
deferred by [ADR-0012](../adr/0012-local-first-real-aws-deferred.md).

- [x] Spike: a throwaway Floci with EKS starts, and a GHCR image rolls out, on a GitHub-hosted
      runner (2026-09-20, about 1m50s end to end; multi-service and frontend checks still open)
- [x] `build.yml` publishes a `content-<hash>` tag per service beside the SHA tag, and skips services
      whose tag already exists (2026-09-21: 12 built, then 12 skipped on a re-run). The hash is the
      git tree of the build context, which every service keeps self-contained (amends ADR-0007)
- [x] `deploy/dev` kustomize overlay on the app's `app/kustomize` base (10 services and `redis-cart`,
      no load generator), with `render-manifests.sh` pinning each service to its content tag; tested
      (2026-09-21) and every rendered tag confirmed on GHCR. A `milestone` overlay waits for real
      AWS (ADR-0012)
- [x] `deploy.yml`, dev: start a throwaway Floci in the runner, apply the infra, render and deploy
      the overlay, wait for every rollout, smoke check the frontend (2026-09-21, PR run green in
      about 2m43s: 11 rollouts, frontend answers). Runs on merge to `main` once merged
Superseded by [ADR-0013](../adr/0013-gitops-with-argo-cd-on-long-lived-aws.md): pull-based GitOps
with Argo CD, on the long-lived local AWS. The push-based `deploy.yml` above worked and is replaced
by the steps below. Build and test each step against the local Floci before pushing.

- [x] Long-lived AWS operated by one command: `restart: unless-stopped` and pinned images in compose,
      `scripts/dev-up.ps1` (health check, repair, `tofu apply`, kubeconfig), the `kubectl` IAM key as
      an OpenTofu resource, a login entry via `-Register` (ADR-0014). Repair path tested (cluster
      recreated clean in about 19s); the full apply run and a real restart are to be confirmed
- [x] GitHub App bot identity (manual, owner): `BOT_APP_ID` and `BOT_APP_PRIVATE_KEY` set as
      repository secrets (2026-09-21), scoped to this repository
- [x] `argocd` module in `infra/modules/` and a `floci-cluster` root: chart 10.9.2 (Argo CD v3.5.3),
      Helm provider 3.3.0, and an `Application` for `deploy/dev`; `dev-up.ps1 -Revision <branch>`
      applies it. Validated and planned; the apply on the long-lived Floci is to be confirmed
- [x] Image pins committed in `deploy/dev`, written by `bump-images.sh` (tested, with a `--verify`
      mode that checks each tag is on GHCR); replaces render-time pinning
- [ ] Argo CD is triggered by a GitHub webhook relayed through smee.io, not by polling (ADR-0015): a relay
      Deployment in the cluster, and the webhook registered by `dev-up.ps1`. Written and planned, to be
      applied and confirmed with a real delivery. smee cannot preserve the webhook signature, so no shared
      secret is set; the real-AWS route (API Gateway or a load balancer in front of Argo) restores it
- [ ] Ingress instead of port-forwards (ADR-0016): a Floci ALB (listener on `127.0.0.1:8080`) in front of
      Traefik (Argo CD, chart 41.6.0), with Ingress objects for `argocd.localhost`, `headlamp.localhost` and
      `shop.localhost`. Spike proved the data path (HTTP 200 through the ALB to the frontend); the ALB module
      and Traefik are written and planned, to be applied and confirmed in a browser
- [x] Bump workflow (`bump-images.yml`, `bump-pr.sh` with a dry-run test): after a successful build on
      `main`, opens or updates one PR as the GitHub App bot and enables auto-merge. Confirmed end to end
      on 2026-09-21 (see the journal entry): an app change produced a one-line bot PR whose required
      checks ran and which auto-merged, and Argo CD rolled out the one changed service
- [x] Argo CD syncs `dev` on the long-lived cluster: `Synced` and `Healthy` (confirmed 2026-09-21).
      The first apply failed because Helm cannot create an `Application` in the release that
      installs its CRD; the module now uses a second release (`argocd-apps`)
- [x] Headlamp, a read-only web UI for the cluster, deployed by Argo CD from its Helm chart
      (2026-09-21; the chart's default `cluster-admin` binding replaced by a read-only
      `headlamp-viewer` role from git that excludes secrets)
- [ ] CI verifies CD on a throwaway Floci: apply, install Argo, sync the PR's commit, wait Healthy
      (replaces `deploy.yml`)
- [x] Rollback drill (2026-09-21, see the postmortem): a pin-only revert healed the cluster in 48 s but was
      undone 78 s later by the bump workflow; reverting the source recovered it durably (2 min 7 s from
      opening the revert to healthy). Rollback is reverting the source (ADR-0013)
- [ ] Promotion documented: the image proven in dev is the one a later milestone deploy would use
      (the milestone itself is deferred with real AWS, ADR-0012)

### Phase 1 close-out (local, free; ADR-0012)

- [ ] Threat model (STRIDE-style pass on pipeline and infra)
- [x] A simple failure exercise for Phase 1 (a bad image, recovered by rollback) and its postmortem:
      [`docs/postmortems/2026-09-21-phase1-bad-emailservice.md`](postmortems/2026-09-21-phase1-bad-emailservice.md)
- [ ] Phase 1 demo: README + short recording/GIF, from a local or runner-hosted cluster

### Real AWS (deferred, optional; ADR-0012)

Not started, and not before local options are exhausted. Free and local first.

- [ ] AWS Budgets + billing alarm, before anything touches real AWS
- [ ] `environments/aws-milestone` built (local state, ADR-0011) and OIDC federation working from
      Actions
- [ ] One real, temporary AWS EKS deploy of the same manifests through the pipeline, with a negative
      test that a foreign repository cannot assume the roles; then torn down, with evidence kept
      (logs, screenshots, teardown, a cost note)

## Phase 2 — Operate it (reliability and platform)

Not started. Scope (ADR-0010):

- [ ] Observability: a metrics stack and dashboards for the deployed app
- [ ] SLOs and alerts on them, and an incident drill with a written postmortem
- [ ] DORA metrics from the pipeline
- [ ] Per-PR environments get one host each on the ingress from Phase 1 (`pr-<n>.localhost`)
- [ ] Per-PR environments on the Argo CD from Phase 1 (an `ApplicationSet` with the pull-request
      generator, a namespace per PR, torn down on close)
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
