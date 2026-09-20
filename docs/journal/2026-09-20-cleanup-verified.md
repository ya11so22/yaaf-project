# 2026-09-20: Cleanup workflow verified, delete count fixed

**Phase:** Phase 1 — Commit to running app
**Related ADRs:** [ADR-0007](../../adr/0007-ci-split-ghcr-and-floci-scope.md)

## What happened

Ran `cleanup.yml` by hand (`workflow_dispatch`) now that the 12 GHCR packages exist. All 12 prune
jobs succeeded. That confirms the two things that were unverified: GitHub accepts the nested package
name `yaaf-project/<service>`, and the built-in `GITHUB_TOKEN` (with `packages: write`) may manage
these packages.

Reading the job log showed a real gap: the action ran with `num-old-versions-to-delete: 1` (its
default). With "keep the newest 10", it would still delete only one old version per package per
weekly run, so retention would fall behind as soon as builds outpaced one per week. Set it to 100.

## Verification

The manual run above. It found nothing to delete (each package has 2 versions against a keep-10
policy), so the deletion path itself is not yet exercised. It can be tested safely only once a package
passes 10 versions, or deliberately by lowering the keep count for one package, which would delete
real images and is not worth doing without a reason.

## Next

Phase 1 continuous delivery. See the plan in the PR discussion and `docs/milestones.md`.
