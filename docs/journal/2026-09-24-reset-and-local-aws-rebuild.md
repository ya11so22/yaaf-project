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
recorded in ADR-0022. Claude Code's safety check stopped Claude applying it; the owner applied it, and the terminal was then
tested over its WebSocket.

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

## Part 2: the PR, EC2 access, and IAM evidence

- **PR #26** opened from `chore/reset-and-refocus`; all checks passed on GitHub, including the new infra smoke test
  (2m56s). The old smee webhook was deleted from the repository with the owner's approval.
- **EC2 workstation, three ways in** (ADR-0022 item 8): new `modules/ec2-instance` and a workstation in the foundation
  root; `dev-up` creates a dedicated key, `~/.ssh/floci-dev`, once, waits for sshd's banner and prints all three
  commands. Tested: SSH with the exact printed command from Windows PowerShell (key only; password login refused), SSM Run
  Command (`Success` with output), and the web terminal (a command ran as root over the WebSocket). Destroy and re-create
  are clean and the plan then shows no changes. `aws ssm start-session` is unsupported by Floci 2.1.0.
- **Found:** SSH and security-group ports are published on `0.0.0.0` and `[::]` with no setting to change it (confirmed with
  `netstat`); IMDSv2-required is not enforced (a token-less request returned 200); Floci cannot read IAM instance-profile
  tags (`ListInstanceProfileTags` unsupported), so that resource gets a narrow `ignore_changes` with a comment.
- **Upstream findings investigated** (owner's item 3): the CloudFront tag bug is a key mismatch in the source (stored under
  `distribution/<id>`, read under the ARN), present on `main`; floci-dash's terminal WebSocket accepts a foreign `Origin`
  (tested); no existing issues found. Drafts only, none filed
  ([findings](../research/2026-09-24-floci-upstream-findings.md)).
- **IAM question answered with a drill** (owner's item 4): `scripts/drills/iam-trust.sh` shows enforcement, permission
  boundaries and IRSA trust working on Floci, and reproduces the forged-GitHub-token gap. ADR-0020 was revised: real AWS is
  now needed only for GitHub's own issuer ([guide](../guides/iam-policies-and-trust.md)).
- **Pipeline relevance** (asked mid-session): kept. It is the delivery half (ADR-0023) and still feeds the 12 image pins in
  `deploy/dev`. The one leftover: no workflow uses AWS, so the ECR module and the OIDC roles are emulated but unused by CI.

## Learn

- Three ways into an instance, and why AWS prefers SSM ([guide](../guides/reaching-an-ec2-instance.md)).
- Identity policy, permissions boundary and trust policy are three different documents ([guide](../guides/iam-policies-and-trust.md)).
- A green check on a claim is only as good as the test: the forged token succeeding is the emulator, not the design.

## Next

1. Decide ADR-0020 (now much smaller), and whether to keep or remove the ECR module and the unused OIDC roles.
2. File, or not, the upstream findings (Floci issues; floci-dash privately).
3. Optionally apply the firewall rule from the EC2 guide, in an elevated PowerShell.
4. Close Phase 1: threat model, pre-merge deploy check, demo; then the requirements document.
