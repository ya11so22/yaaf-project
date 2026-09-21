# 2026-09-21: The dev overlay and manifest rendering

**Phase:** Phase 1, continuous delivery
**Related ADRs:** [ADR-0011](../../adr/0011-cd-image-identity-scope-and-state.md)

## What happened

`deploy/dev/kustomization.yaml` builds on Online Boutique's own `app/kustomize/base` plus its
`without-loadgenerator` component. `.github/scripts/render-manifests.sh <overlay> [rev]` writes a
throwaway kustomization beside the overlay, pins each service to `ghcr.io/ya11so22/yaaf-project/
<service>:content-<hash>` with the `images:` transformer, and prints the manifests with
`kubectl kustomize`. Rendering at an earlier revision reproduces that deploy, which is the rollback
path. A test checks the rendered output, and `scripts/check` runs it when kubectl is installed.

## Why

ADR-0011. Keeping the overlay static and pinning at render time avoids bot commits to bump images
(a Phase 2 concern) while still making each deploy reproducible from a revision.

## Findings

- ADR-0011 said "11 base services"; the base has 11 workloads including the load generator, so it is
  10 services plus `redis-cart`. The ADR is corrected.
- The scratch directory cannot live inside the overlay (kustomize reports a cycle), so it sits
  beside it and is git-ignored.
- All 10 rendered tags exist on GHCR, since PR #8's build published them.

## Verification

`scripts/check` passes with the four render assertions (no upstream registry images, no load
generator, 10 pinned services, 11 deployments); the tags were checked with `docker manifest inspect`.

## Next

`deploy.yml` for dev: start Floci on a runner, apply the environment, render, apply, wait for the
rollouts, smoke check the frontend; then a rollback drill.
