# 2026-09-24: Reset, ADR consolidation, and the local AWS rebuilt

**Phase:** Phase 1 (environment), cross-cutting (decisions)
**Related ADRs:** [ADR-0021](../../adr/0021-project-purpose-scenario-and-scope.md), [ADR-0022](../../adr/0022-the-local-aws-environment.md),
[ADR-0023](../../adr/0023-build-and-delivery.md)

## What happened

The owner asked for three things: add floci-dash as an AWS-console-style dashboard; reset and clean up the repository
and consolidate the ADRs; and bring every tool up to date with clean start and stop scripts and a local AWS that can
run IaC, storage, EKS and website hosting.

**Decisions consolidated.** Seventeen ADRs had become chains of "amended by" notes. Three new ADRs state the current
answer: purpose and scope (0021), the local AWS (0022), build and delivery (0023). The sixteen they replace moved to
`adr/archive/` with a "superseded by" status, and every link in the repository was rewritten to the new paths. Current
decisions are listed in `adr/README.md`.

**Removed:** the smee.io webhook relay (unsigned, a community dependency, and `dev-up` rewrote the repository's webhook
on every start; Argo CD now polls every 60 s); the fragile interim `deploy.yml`; the unbuilt `aws-milestone`
environment; the empty `pipelines/`, `platform/`, `policy/` placeholders; the outdated gap analysis; the Google Cloud
tooling in the vendored app (106 files); floci-ui.

**The environment, rebuilt** (ADR-0022): three OpenTofu roots under `infra/environments/dev/` (bootstrap, foundation,
cluster) with state in an S3 bucket on Floci and native locking; the AWS provider moved to 6.x (6.66.0) with default
tags; a new `static-site` module (private S3 behind CloudFront with origin access control) serving a portal page;
floci-dash 0.4.0 pinned by digest; everything on loopback; rewritten `dev-up.ps1` and `dev-down.ps1` (with `-Reset`).
Floci 2.1.0, k3s v1.36.4 (EKS's newest version is 1.36), Argo CD, Traefik, Headlamp and the other providers were already
current. The old local state went to `~/yaaf-backup/pre-reset-2026-09-24`, and, with the owner's approval, the old
containers and volumes were deleted by the new `dev-down.ps1 -Reset`.

**Found while verifying:**
- `emailservice` restarted forever: it needs about 14 s to start under its 200m CPU limit, and its liveness probe
  kills it after 15 s. Fixed with a startup probe in `deploy/dev` ([guide](../guides/kubernetes-probes.md)); proved live
  by pausing Argo CD's auto-sync for the app, then restored. Reaches the running cluster when this branch merges.
- Floci's CloudFront drops the tags passed to `CreateDistributionWithTags` (proved with the AWS CLI), so the first
  re-apply changes the distribution. CI applies once more before its no-changes check, with a comment. No upstream
  issue exists yet.
- Floci 2.1.0 routes CloudFront viewer requests only by the generated domain; `FLOCI_SERVICES_CLOUDFRONT_DOMAIN_SUFFIX
  =cloudfront.localhost` makes that domain reachable from a browser. The docs on Floci's `main` branch describe newer
  behaviour than the pinned release.
- `dev-up`'s endpoint check first passed on a page that was Floci's landing page (HTTP 200); it now checks content.

**floci-dash and the Docker socket.** Built first without the socket, which disables only its in-browser EC2 terminal.
The owner chose to use the dashboard as intended, so the socket mount is now in `compose.yaml` and the trade-off is
recorded in ADR-0022. Applying it was stopped by Claude Code's safety check, so the owner applies it (see Next).

## Why

ADR-0021 to 0023 carry the reasoning. In short: the owner wanted a clean, current, realistic base to learn AWS on,
and a decision record a reader can follow without tracing amendment chains.

## Verification

- `dev-up.ps1` from nothing: bootstrap 4 resources, foundation 67, cluster 2; EKS node Ready on v1.36.4+k3s1; all Argo
  CD applications Synced; portal, floci-dash, Argo CD, Headlamp and the shop answered.
- Second run: bootstrap and cluster "No changes"; foundation converged once (the CloudFront tag bug), then a plan
  showed no changes.
- S3 locking: a planted lock object made `plan` fail with `PreconditionFailed`; removed, the plan ran.
- `-PlanOnly` on Windows PowerShell 5.1; both scripts parse on 5.1 and 7; `-Reset` removed every old container and
  volume, including the unlabelled cluster volume.
- The portal opened in a browser at its `cloudfront.localhost` address; floci-dash showed the `yaaf-dev` cluster
  ACTIVE on 1.36.
- `scripts/check`: fmt, the four script test suites, actionlint and gitleaks all passed. Provider lock files cover
  Windows, Linux and macOS.

## Learn

- Emulator bugs look like your own; prove them with the plain API before changing your code
  ([guide](../guides/local-aws-environment.md)).
- A liveness probe without a startup probe kills slow starters ([guide](../guides/kubernetes-probes.md)).
- State in S3 needs a bootstrap step, and locking is an S3 conditional write.

## Next

1. The owner applies the dashboard's socket mount: `docker compose -f infra/environments/dev/compose.yaml up -d floci-dash`
   (or `.\scripts\dev-up.ps1`), then tries the EC2 terminal on an instance launched from an image with bash.
2. Commit, push and open the PR for `chore/reset-and-refocus`; merge brings the emailservice fix to the cluster.
3. The owner decides on: deleting the old smee webhook on the repository; filing the Floci CloudFront tag bug (and the
   floci-dash origin check) upstream; accepting ADR-0020.
4. Optional: EC2 access the AWS way (imported key pair, SSH from `127.0.0.1/32`, SSM Run Command) with a guide.
