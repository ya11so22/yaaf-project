# 2026-09-20: Branch protection on main; images public

**Phase:** Phase 1 — Commit to running app
**Related ADRs:** [ADR-0007](../../adr/archive/0007-ci-split-ghcr-and-floci-scope.md), [ADR-0008](../../adr/archive/0008-phase-reslice-cd-and-team-model.md), [ADR-0009](../../adr/0009-local-pre-gate.md)

## What happened

- Applied branch protection to `main` through the API: pull requests only, `build`, `infra` and
  `check` required, no force-pushes, no deletions, and `enforce_admins` on so it binds the owner
  (and the agents, who share the owner's identity). Approvals required is 0 because one identity
  cannot approve its own PR; required reviews wait for the Phase 2 bot identity (ADR-0008). "Require
  branches to be up to date" is off to avoid rebase churn.
- The owner made the 12 GHCR packages public by hand (no API exists for it). Verified without any
  credentials: GHCR issues an anonymous pull token for all 12 and lists their tags, and an
  unauthenticated `docker pull` of `frontend` worked. Each image carries one tag per commit that
  built it (the PR head and the merge commit).

## Why

The gates only mean something if merging requires them. Public images let Floci's k3s and the
milestone EKS pull without a pull secret, as ADR-0007 intended.

## Verification

Read the protection back from the API: PR required, admins bound, the three checks required, force
pushes and deletions off. Anonymous GHCR access checked per package as above.

## Slip worth noting

The first version of this PR's docs script failed partway (a text replacement did not match), so the
journal entry was not written and the README status was left half-updated, yet the commit and PR
went ahead because the steps were chained. Fixed in a follow-up commit on the same PR. Lesson: run
edit scripts and the commit as separate steps, and stop on the first failure.

## Next

Phase 1 CD (ADR-0008): `deploy/dev` and `deploy/milestone` kustomize overlays, then a `deploy.yml`.
