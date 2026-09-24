# ADR-0004: Split Terraform state/execution strategy — local for Floci, HCP Terraform for the AWS milestone environment

**Status:** superseded by [ADR-0022](../0022-the-local-aws-environment.md) (consolidated 2026-09-24; kept as the record of how the decision evolved)
**Date:** 2026-09-20

## Context

`infra/environments/floci` needed a backend decision before its first `apply`. The obvious
default answer ("just use HCP Terraform's free tier for everything") turned out not to work
uniformly across this project's two environments, because they have different reachability and
lifetime characteristics:

- `environments/floci` (ADR-0002/ADR-0003): talks to Floci at `http://localhost:4566`, which
  only exists on whatever machine or CI job is currently running it. Both local dev and every
  GitHub Actions run get a *fresh* Floci instance — there is no long-lived Floci to reconcile
  state against across separate runs.
- `environments/aws-milestone`: talks to real AWS, per milestone, as one atomic
  provision-validate-destroy pass (per ADR-0002's "hybrid" approach), not a long-lived shared
  environment.

Also relevant: HCP Terraform's free tier runs plans/applies on HashiCorp's own cloud
infrastructure ("remote" execution mode) unless you pay for self-hosted Agents. Cloud-hosted
runners can reach the public internet (real AWS) but cannot reach `localhost:4566` on a laptop
or inside an isolated GitHub Actions job's network.

## Options considered

1. **HCP Terraform (free tier) for everything, one workspace family.**
   - Pros: one remote-state story to reason about; VCS-driven plan-on-PR/apply-on-merge with
     PR comments built in.
   - Cons: cannot actually execute against `environments/floci` — HCP's cloud runners can't
     reach `localhost:4566`. Non-starter for that environment, not just a stylistic choice.

2. **Local backend for everything.**
   - Pros: simplest, zero extra services, matches the fact that neither environment currently
     needs state to outlive a single machine/job.
   - Cons: gives up locking, remote plan/apply, and the "plan posted on PR" milestone item for
     whichever environment eventually does need persistence (loses the option value HCP
     Terraform gives for free).

3. **Split by environment: local backend for `floci`, HCP Terraform (free tier) for
   `aws-milestone`.**
   - Pros: matches each environment's actual reachability and lifetime; `aws-milestone` gets
     real remote state, locking, and VCS-triggered plan/apply with PR comments without any
     bootstrap chicken-and-egg problem (no need to hand-provision an S3 bucket first); `floci`
     stays simple, matching that its state is only ever meaningful within one ephemeral Floci
     instance's lifetime.
   - Cons: two backend configurations to maintain instead of one; contributors need to
     understand why they differ (mitigated by this ADR).

## Decision

Split strategy (Option 3): `environments/floci` keeps the local backend, run directly by the
Terraform CLI wherever Floci itself is running (locally now; a GitHub Actions job running
Floci as a service container later). `environments/aws-milestone` uses an HCP Terraform
(free tier) workspace, VCS-connected to this repo, with its working directory scoped to
`infra/environments/aws-milestone` and its trigger patterns scoped to that path plus
`infra/modules/**` (so unrelated repo changes don't kick off milestone runs).

No new repository is needed — HCP Terraform workspaces connect to a specific working directory
within an existing repo, not the whole repo, so this stays inside the current monorepo alongside
`/app`, `/adr`, `/pipelines`, etc.

## Rationale

The two environments don't share a lifetime or a network, so forcing them onto one backend
strategy would mean picking the worse fit for at least one of them. `floci`'s state is
disposable by design — every run gets a fresh emulator, so there's nothing durable to protect.
`aws-milestone`'s state is exactly the case remote backends exist for: a real,
internet-reachable target where you want locking and a durable plan/apply record, even if the
underlying infra itself is torn down right after. Splitting the strategy costs a small amount of
"two things to explain" but avoids adopting a self-hosted or paid-tier workaround
(self-hosted Agents) to solve a reachability problem that a same-service split solves for free.

## Consequences / trade-offs accepted

- Two backend configs to keep straight; this ADR is the reference for why they differ.
- The "plan posted on PR" milestone item is delivered two different ways depending on
  environment: a plain GitHub Actions step (capture `terraform plan` output, post as a PR
  comment) for `floci`, and HCP Terraform's built-in VCS integration for `aws-milestone`.
- If `environments/floci` ever needs state to persist across separate CI jobs (e.g. a PR-plan
  job and a days-later merge-apply job that must agree on the same state), this decision should
  be revisited — at that point a self-hosted backend (MinIO + Terraform's native S3 state
  locking, or the `pg` backend) becomes relevant, since HCP Terraform's free tier still can't
  reach a local/ephemeral Floci instance. Tracked as a Phase 2 stretch idea in
  `docs/milestones.md` rather than acted on now, since neither current environment actually
  needs cross-session state persistence today.
