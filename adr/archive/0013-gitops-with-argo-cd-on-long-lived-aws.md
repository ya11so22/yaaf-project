# ADR-0013: GitOps with Argo CD, on a long-lived local "AWS"

**Status:** superseded by [ADR-0023](../0023-build-and-delivery.md) (consolidated 2026-09-24; kept as the record of how the decision evolved)
**Date:** 2026-09-21

## Context

ADR-0008 chose push-based CD (a workflow applies manifests to a throwaway Floci on the runner) and
deferred Argo CD to Phase 2, on two grounds: it needs bot commits to bump images, and a local
cluster is only live while the machine is up. That push-based `deploy.yml` now exists and works
(about 2m43s, all rollouts, frontend answering). Two things changed since:

- The owner wants a "smarter" delivery system: pull-based GitOps with drift correction and a
  rollback that is a git operation.
- The owner's model of Floci is a **long-lived** baseline, standing in for the AWS account itself,
  with OpenTofu provisioning everything on top of it. Argo's pull model needs no inbound access,
  so "only live while the machine is up" is acceptable for a project that is not a live service.

## Decision

1. **Terminology.** **AWS** means the cloud layer: IAM, VPC, ECR, EKS and the like. In this project
   it is backed by a long-lived local Floci; real AWS (ADR-0012) is a later second backend for the
   same layer. Docs say "AWS" for that layer and name the thing when it matters: the **EKS
   cluster** (k3s inside Floci), a **workload** running in it, or the **emulator** when talking
   about Floci's own behaviour and limits. An **environment** is what OpenTofu provisions on top
   of AWS, and `dev` is the only one for now.
2. **Who does what.**
   - OpenTofu provisions on AWS: VPC, EKS, ECR, IAM (`infra/environments/floci`), and, in a second
     root that needs the cluster to exist (`infra/environments/floci-cluster`), Argo CD itself
     (pinned Helm chart) plus one `Application` that points at this repository.
   - Argo CD in the cluster reconciles workloads from git (`deploy/`), with automated sync, prune
     and self-heal. Nothing pushes workloads into the cluster.
   - CI builds images and records what should run in git; it does not touch the cluster.
3. **Image pins live in git.** `deploy/dev/kustomization.yaml` carries the content-hash tags
   (ADR-0011) in an `images:` block. A script computes them, and a workflow opens a PR bumping them
   after each build. Render-time pinning is retired. **Rollback is reverting the source change, not the pin:**
   pins are derived from the source, and the bump workflow recomputes them after every build on `main`, so a
   pin-only revert is undone within about a minute (observed in the Phase 1 failure exercise, see
   `docs/postmortems/2026-09-21-phase1-bad-emailservice.md`). Reverting the source returns the content tag to
   its earlier value, which is already built, so nothing is rebuilt and the bump workflow then re-pins to it.
4. **A bot identity.** PRs created with the default `GITHUB_TOKEN` do not trigger workflows, so the
   required checks would never report and the bump PR could never merge. The bump workflow
   therefore uses a GitHub App (free) as a bot identity, which is also the bot identity ADR-0008
   scheduled for Phase 2.
5. **Same repository**, under `deploy/`. Bump commits touch only `deploy/`, which triggers no
   image builds. The Application is created by OpenTofu at bootstrap rather than kept in git,
   because the revision it tracks differs by environment (a branch when trying a change, a
   commit SHA in CI). It moves into git as an `ApplicationSet` with per-PR environments in
   Phase 2.
6. **Verification in CI stays on a throwaway Floci.** GitHub-hosted runners cannot reach the
   long-lived local one, so the CD test becomes: apply the environment, install Argo, point it at
   the PR's commit, and wait for `Synced` and `Healthy`. The existing push-based `deploy.yml` is
   replaced by it.
7. **Milestone and later phases.** The real-AWS milestone (deferred) reuses the same modules and
   Argo setup. Per-PR environments (an `ApplicationSet` with the pull-request generator) stay in
   Phase 2.

8. **A read-only cluster dashboard.** Headlamp (`kubernetes-sigs`, Apache-2.0) is deployed by Argo CD
   from its official Helm chart, pinned, in its own namespace. It is chosen because the Kubernetes
   Dashboard was archived in January 2026 and points to it. The chart binds its service account to
   `cluster-admin` by default; it is bound instead to a `headlamp-viewer` ClusterRole kept in
   `deploy/headlamp-rbac` and deployed by Argo CD. The built-in `view` role was tried first and is
   too narrow (no nodes, no custom resources: the dashboard reported "forbidden"). `headlamp-viewer`
   grants read access to the core resources it shows, listed one by one so secrets, pod exec and node
   proxy are excluded, and to every other API group, since secrets exist only in the core group. It is reached through the ingress (ADR-0016), with no login: Headlamp
   serves every visitor as its own read-only service account (`unsafeUseServiceAccountToken`). A token login
   cannot survive a cluster reset, since the new cluster has new signing keys and every old token stops
   validating, so a login would have to be redone after each one. Headlamp labels the option unsafe because
   anyone who can reach the UI gets that account's access; here that account is read-only without secrets,
   and the only way in is the loopback-only ALB. It must not be reused where others can reach the UI.

## Options considered

- **Keep push-based CD** (ADR-0008): works, but it is a script, not reconciliation: no drift
  correction, no health model, and rollback needs a workflow run.
- **Argo CD Image Updater** with git write-back: the pins update without a workflow, but it adds a
  component and needs its own git credentials; the bot-PR route reuses the bot identity we need
  anyway.
- **A config-management plugin running `render-manifests.sh` inside Argo:** no commits, but
  non-standard, and it hides the desired state from git.
- **A separate config repository:** cleaner history in real organisations; costs portfolio
  legibility here.
- **A self-hosted runner on the owner's machine, so CI could reach the long-lived Floci:** free,
  but on a public repository it lets pull-request code run on the owner's machine. Rejected.

## Consequences / trade-offs accepted

- The long-lived cluster is only as reliable as Floci: after a restart the k3s node can come back
  NotReady (a recorded Floci finding) and the cluster may need recreating. That is tolerable
  because OpenTofu recreates the cluster and Argo restores the workloads from git.
- Setting up a GitHub App is manual work on the owner's side, and its private key becomes a
  repository secret to protect. It is scoped to this repository.
- Argo adds about seven pods to a single k3s node.
- Until the bump workflow exists, the pins in `deploy/dev` are updated by running the script by
  hand.
- The threat model must cover the new trust path: the bot can change what runs in the cluster, so
  its permissions are limited to pull requests on `deploy/`, and branch protection still gates
  merge.
