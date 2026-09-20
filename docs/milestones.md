# Milestones

Tracks progress against the "done" bar from the project brief: each phase is independently
demoable on its own (README + short recording/GIF), not just a step toward something bigger.
Updated as work lands — see `docs/journal/` for the narrative behind each checked item.

## Phase 1 — AWS IaC + GitHub Actions foundation

- [x] Floci running locally (2026-09-16)
- [x] VPC OpenTofu module + `environments/floci` root config, applied and verified against
      Floci (2026-09-16 module, applied 2026-09-20)
- [x] EKS-equivalent cluster module `modules/eks-cluster` (ADR-0003) — written, `tofu validate`/`plan`
      clean, applied against Floci and `kubectl` verified (2026-09-20)
- [x] ECR-equivalent registry module `modules/ecr` — written, `tofu validate`/`plan` clean,
      applied against Floci and an image push/pull verified (2026-09-20)
- [x] IAM module `modules/github-oidc` (ADR-0006) — written, `tofu validate`/`plan` clean
      (2026-09-20), pending `tofu apply` against Floci; trust conditions can only be proven on
      real AWS
- [x] GitHub Actions: path-filtered per-service image builds to GHCR, with cache, Trivy
      (report-only) and an always-running `build` gate — `build.yml` written, linted, change
      detection unit-tested (2026-09-21); pending its first run on GitHub (ADR-0007)
- [x] GitHub Actions: `infra.yml` — `fmt`/`validate`/`plan` without Floci, sticky plan comment
      on PRs, Floci smoke test (apply, no-diff re-plan, destroy), `infra` gate — written and
      linted (2026-09-21); pending its first run on GitHub
- [ ] Re-run the Floci smoke test on merge to `main`; the real apply becomes a manual,
      environment-gated dispatch for `aws-milestone`, added when that environment exists
      (replaces "`tofu apply` on merge": applying to a throwaway Floci discards the result)
- [ ] Weekly GHCR cleanup (`cleanup.yml`) — written; verify the package-name format with a
      manual dispatch once images exist
- [ ] Repository made public (email in history rewritten to the GitHub noreply address first),
      Actions settings applied (approval for outside collaborators, SHA pinning enforced)
- [ ] First PR into `main`: `build` and `infra` checks green, 12 images on GHCR
- [ ] Branch protection on `main` (PR-only, `build` + `infra` required, no force-push), then the
      12 GHCR packages made public by hand
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
