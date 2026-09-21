# 2026-09-21: Content-hash image tags

**Phase:** Phase 1, continuous delivery
**Related ADRs:** [ADR-0011](../../adr/0011-cd-image-identity-scope-and-state.md), amends [ADR-0007](../../adr/0007-ci-split-ghcr-and-floci-scope.md)

## What happened

Images are now also tagged `content-<12 hex>`, the git tree hash of the service's build context
(`.github/scripts/content-tag.sh`, six unit tests, wired into `scripts/check` and the `changes`
job). The SHA tag stays for traceability; both tags point at one manifest, so the cleanup job's
version count is unaffected. Before building, the image job checks whether the content tag already
exists on GHCR and, if so, skips the build, scan and push.

## Why

ADR-0011: with path-filtered builds, most services have no image for a given commit, so a deploy
needs an identifier that is stable while content is unchanged. A tree hash needs no custom hashing
and covers exactly what the image is built from, because every context is self-contained. Skipping
existing tags keeps a tag from moving to a non-reproducible rebuild, which is what makes rollback to
a recorded tag trustworthy.

## Verification

The PR changes `build.yml`, so all 12 services built once (14 jobs green) and published their
content tags. Re-running the same workflow skipped the build and push steps for all 12, with
"already exists; skipping" in each job. A PR-built image is also reused after merge when the content
is unchanged.

## Next

The `deploy/` kustomize overlays, resolving each service to its content tag, then `deploy.yml` for
dev (absorbing the runner spike's steps) and a rollback drill.
