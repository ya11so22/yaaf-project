# ADR-0007: Split CI into build and infra pipelines; images live on GHCR; Floci only validates infra

**Status:** superseded by [ADR-0023](../0023-build-and-delivery.md) (consolidated 2026-09-24; kept as the record of how the decision evolved)
**Date:** 2026-09-20

## Context

The first `build.yml` (2026-09-20) started a fresh Floci in every per-service job, created the
ECR repositories with `tofu apply -target`, then built and pushed. Two problems: the registry
was destroyed with the runner, so no image survived a run, and the Floci/`tofu` overhead ran up
to 12 times per PR for a step that only needed *a place to push*. ADR-0002 said Floci is used
for "all GitHub Actions CI runs"; that is right for infrastructure validation but wrong for
image builds.

Project framing: the "app team" is a handful of Claude agents opening PRs, and the DevOps
engineer (the project owner) owns infra and pipelines. Agent PRs from same-repo branches are
the realistic pipeline trigger.

Facts gathered: the repo was private (no branch protection, capped Actions minutes, private
GHCR packages); every Dockerfile builds only from its own folder; the history contains no
secrets; `tofu plan` on a fresh state needs no Floci (53 resources across the four modules).

## Decision

Two pipelines with different jobs.

**Build (`build.yml`)** — no Floci, no `tofu`, no AWS:
- A script finds changed services (diffing from the merge-base). Auto-discovers services by
  folder, so adding one needs no workflow edit. Builds all 12 `app/src` services, including
  `loadgenerator` and `shoppingassistantservice`, although the brief says 11; deployment scope
  is a Phase 2 decision.
- Each service builds for `linux/amd64` only (every target is amd64), with the Actions cache
  scoped per service, is scanned by Trivy (report-only, SARIF to the Security tab), and is
  pushed to `ghcr.io/ya11so22/yaaf-project/<service>:<sha>`. SHA tags only, no moving tags.
  Same-repo PRs and `main` push; fork PRs build only.
- One always-running `build` job is the required check, so PRs that touch no service still
  report it. Superseded PR runs are cancelled; runs on `main` are not.
- A weekly job keeps the last 10 versions per package (GHCR has no lifecycle policy).

**Infra (`infra.yml`)** — for changes under `infra/**`:
- `fmt`, `validate` and `plan` run without Floci; the plan is posted as one sticky PR comment.
- A Floci smoke test does a full apply of `environments/floci`, requires a no-changes re-plan
  (idempotency), then destroys (teardown, which ADR-0003 depends on). 15-minute timeout.
- On merge the smoke test re-runs on `main` as a health signal. A real apply exists only as a
  manual, environment-gated dispatch for `aws-milestone`, added when that environment exists.
- One always-running `infra` job is the required check.

## Options considered

1. **Keep per-job Floci and ECR for builds.** Rejected: images vanish, repeated overhead, and
   it proves nothing an infra job does not.
2. **Real AWS ECR for images.** Rejected for now: real AWS earlier than ADR-0002 intends, and
   ongoing cost, for a project meant to stay free.
3. **GHCR (chosen).** Persistent, free for a public repo, authenticated with `GITHUB_TOKEN`,
   no AWS in the build path.

## Rationale

The registry's job is to keep images; Floci's job is to prove the IaC. Coupling them made both
worse. Splitting keeps the distinctive claim (every infra change is applied to a fresh emulated
AWS before merge, real AWS only at milestones) without paying for it on every app PR.

## Consequences / trade-offs accepted

- GHCR does not enforce tag immutability or scan on push; the SHA-only convention and the
  Trivy step stand in for them. Scanning is report-only because the upstream demo app has known
  findings; tighten once the baseline is triaged.
- **Floci proves the code applies, not that it is secure** (ADR-0006: it does not enforce IAM
  trust conditions). The smoke test claims no more than that.
- The ECR module and the `ecr-push` role from ADR-0006 stay as tested IaC but are unused by the
  pipelines. Revisit removing them if the AWS milestone also pulls from GHCR.
- GHCR packages start private; making them public is a manual, irreversible step per package
  after the first push. Public images let Floci's k3s and the milestone EKS pull without a
  pull secret.
- Third-party actions are pinned to commit SHAs. `trivy-action` is pinned at v0.36.0, past the
  patched version of GHSA-9p44-j4g5-cfx5.
- Repo settings decided with this ADR: the repository goes public; workflows from all outside
  collaborators need approval; SHA pinning is enforced; `main` requires PRs and the `build` and
  `infra` checks, and blocks force pushes. Required reviews wait for a second human account.
  `CODEOWNERS` records intent: platform paths are owned by the DevOps engineer.
