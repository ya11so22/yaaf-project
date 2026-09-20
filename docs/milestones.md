# Milestones

Tracks progress against the "done" bar from the project brief: each phase is independently
demoable on its own (README + short recording/GIF), not just a step toward something bigger.
Updated as work lands — see `docs/journal/` for the narrative behind each checked item.

## Phase 1 — AWS IaC + GitHub Actions foundation

- [x] Floci running locally (2026-09-16)
- [x] VPC OpenTofu module + `environments/floci` root config, applied and verified against
      Floci (2026-09-16 module, applied 2026-09-20)
- [x] EKS-equivalent cluster module `modules/eks-cluster` (ADR-0003) — written, `tofu validate`/`plan`
      clean (2026-09-20), pending `tofu apply` against Floci
- [ ] ECR-equivalent registry module
- [ ] IAM module
- [ ] GitHub Actions: build + push each of the 11 `/app` services on change only (path-filtered)
- [ ] GitHub Actions: `tofu plan` on PR against Floci, plan output posted as a PR comment
- [ ] GitHub Actions: `tofu apply` on merge
- [ ] AWS Budgets + billing alarm (before anything ever touches real AWS)
- [ ] OIDC federation to AWS wired up in GitHub Actions
- [ ] **Milestone:** one real, temporary AWS EKS deploy validating the pipeline end-to-end, then
      torn down
- [ ] Threat model (STRIDE-style pass on pipeline + infra) — brief calls for this during Phase 1
- [ ] Phase 1 demo: README + short recording/GIF

## Phase 2 — Platform engineering layer

Not started. See root `README.md` for scope (golden-path workflow, policy-as-code, ephemeral PR
environments, DORA metrics instrumentation).

## Phase 3 — MLOps on `recommendationservice`

Not started.

## Phase 4 — Distributed tracing (optional/stretch)

Not started; explicitly non-blocking for calling the project "done" at Phase 3.

## Standing goals (not phase-scoped)

- [ ] One piece of external validation (Floci upstream contribution, or a public write-up of one
      hard problem hit along the way)
- [ ] Deliberate failure exercise + postmortem at the end of each phase (see
      `docs/postmortems/`)

## Phase 2 stretch candidate: self-hosted OpenTofu state backend

Not committed, not scheduled — a candidate to revisit when Phase 2's platform layer takes
shape. Running a self-hosted remote-state backend (MinIO + native S3 state locking, or the `pg`
backend) is its own demonstrable platform-engineering skill, distinct from pointing at a managed
SaaS. See [ADR-0004](../adr/0004-tfstate-backend-strategy.md)'s consequences section for why
this isn't needed yet: neither `environments/floci` nor `environments/aws-milestone` currently
needs state to persist across separate jobs/sessions.

## Open follow-up: aws-milestone backend needs revisiting post-OpenTofu

ADR-0004 picked HCP Terraform for `environments/aws-milestone`, but HCP Terraform's remote
execution only runs HashiCorp's own Terraform binary, not OpenTofu (see
[ADR-0005](../adr/0005-opentofu-over-terraform.md)). Since `environments/aws-milestone` isn't
built yet, this isn't urgent — pick an OpenTofu-compatible backend (self-hosted, or an
OpenTofu-native managed option) when that environment is actually built, rather than deciding
speculatively now.
