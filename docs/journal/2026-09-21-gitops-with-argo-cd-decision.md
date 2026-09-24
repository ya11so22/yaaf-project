# 2026-09-21: Decision: GitOps with Argo CD on a long-lived "AWS"

**Phase:** Phase 1, continuous delivery (design)
**Related ADRs:** [ADR-0013](../../adr/archive/0013-gitops-with-argo-cd-on-long-lived-aws.md), supersedes item 3 of [ADR-0008](../../adr/archive/0008-phase-reslice-cd-and-team-model.md)

## What happened

The three stacked PRs (#8 content tags, #9 dev overlay, #10 push-based `deploy.yml`) were merged in
reverse order so each landed in its own base. Reviewing the result, two observations: the deploy
workflow's two failures were both in shell embedded in YAML, which a local run would have caught, and
the owner wanted a pull-based system (Argo CD) instead of a push script. The owner also set the
model: the Floci base infrastructure is long-lived and stands in for AWS, with OpenTofu provisioning
everything on top, and the docs should call that layer "AWS" so it is not confused with what runs in
the EKS cluster.

ADR-0013 records the architecture: OpenTofu installs Argo CD, Argo reconciles `deploy/` from git,
image pins are committed and bumped by a bot PR, rollback is a revert, and CI verifies on a throwaway
Floci. The glossary, milestones, README and ADR-0008's status were updated to match.

## Why

See ADR-0013. In short: reconciliation, drift correction and git-native rollback are the pattern US
platform roles ask about, and the pull model works from a machine behind NAT.

## Verification

Documentation only. The milestones now say each step is built and tested against the local Floci
before pushing, which is the working practice going forward.

## Next

The GitHub App bot identity (manual, owner), then the `argocd` OpenTofu module tested on the local
Floci.
